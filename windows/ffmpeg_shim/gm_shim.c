/*
 * gm_shim.c -- Windows in-process FFmpeg entry point.
 *
 * Wraps fftools' patched ffmpeg_execute() (vendored from ffmpeg-kit, see
 * fftools/) with:
 *   - a per-thread session id, consumed by fftools' own cancelRequested()
 *     cancellation checks (already wired into fftools_ffmpeg.c)
 *   - a crash guard. mingw GCC has no MSVC __try/__except, so instead of
 *     PLAN.md's original SEH sketch this uses AddVectoredExceptionHandler +
 *     per-thread longjmp, which catches the same fault classes (access
 *     violation, illegal instruction, divide-by-zero) without needing
 *     compiler-specific exception keywords.
 */

#include <windows.h>
#include <setjmp.h>
#include <stdatomic.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>

#include "gm_shim.h"

extern int ffmpeg_execute(int argc, char **argv);

/* Storage for symbols fftools_ffmpeg.c/fftools_opt_common.c declare
 * `extern` and expect the embedding layer (us) to define -- this is the
 * same integration surface ffmpeg-kit's own ffmpegkit.c/FFmpegKitConfig.cpp
 * fill in for Android/Linux. */
__thread long globalSessionId = 0;
volatile int handleSIGINT = 0;
volatile int handleSIGTERM = 0;

/* --- per-thread crash guard ------------------------------------------- */

static __thread jmp_buf gm_recover_point;
static __thread volatile int gm_guard_active = 0;

static LONG WINAPI gm_crash_filter(EXCEPTION_POINTERS *ep) {
    DWORD code = ep->ExceptionRecord->ExceptionCode;
    if (!gm_guard_active) {
        return EXCEPTION_CONTINUE_SEARCH;
    }
    switch (code) {
        case EXCEPTION_ACCESS_VIOLATION:
        case EXCEPTION_ILLEGAL_INSTRUCTION:
        case EXCEPTION_INT_DIVIDE_BY_ZERO:
        case EXCEPTION_STACK_OVERFLOW:
        case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:
            longjmp(gm_recover_point, (int)code);
    }
    return EXCEPTION_CONTINUE_SEARCH;
}

void ffmpegkit_log_callback_function(void *ptr, int level, const char *format, va_list vargs);

static void gm_install_handler_once(void) {
    static LONG installed = 0;
    if (InterlockedCompareExchange(&installed, 1, 0) == 0) {
        AddVectoredExceptionHandler(1, gm_crash_filter);
        /* Installs our callback as the *default* av_log sink for every
         * session (matches ffmpeg-kit's own FFmpegKitConfig::init() /
         * ffmpegkit_JNI_init() -- a global call, not a per-session one).
         * Without this, av_log_default_callback stays active and logs go
         * straight to the console instead of into gm_get_logs' per-session
         * buffer. fftools' own -report path (log_callback_report) still
         * layers on top of this via ffmpegkit_log_callback_function. */
        av_log_set_callback(ffmpegkit_log_callback_function);
    }
}

/* --- per-session state: cancellation + log capture -----------------------
 * Small fixed-size table; sessions are short-lived and the pool cap
 * (FfmpegJobPool, Dart side) keeps concurrent sessions well under this.
 *
 * Lifecycle: gm_execute() registers a slot at start and leaves it alive
 * (holding cancellation state + captured logs) after it returns; the caller
 * is expected to call gm_get_logs() exactly once per session afterwards,
 * which drains the buffer and frees the slot. A caller that never drains
 * leaks one slot permanently -- acceptable for Phase 1 (FfmpegDllBackend
 * always drains for FfmpegError.stderr parity); revisit if that contract
 * turns out to be easy to violate accidentally. */

#define GM_MAX_SESSIONS 64
#define GM_LOG_BUF_SIZE 8192

typedef struct {
    _Atomic long session_id;   /* 0 == free slot */
    _Atomic int cancelled;
    CRITICAL_SECTION log_lock;
    char log_buf[GM_LOG_BUF_SIZE];
    size_t log_len;
} GmSessionSlot;

static GmSessionSlot gm_sessions[GM_MAX_SESSIONS];
static LONG gm_sessions_init_done = 0;

static void gm_sessions_init_once(void) {
    if (InterlockedCompareExchange(&gm_sessions_init_done, 1, 0) == 0) {
        for (int i = 0; i < GM_MAX_SESSIONS; i++) {
            InitializeCriticalSection(&gm_sessions[i].log_lock);
        }
    }
}

static GmSessionSlot *gm_session_find(long session_id) {
    for (int i = 0; i < GM_MAX_SESSIONS; i++) {
        if (atomic_load(&gm_sessions[i].session_id) == session_id) {
            return &gm_sessions[i];
        }
    }
    return NULL;
}

static void gm_session_register(long session_id) {
    gm_sessions_init_once();
    for (int i = 0; i < GM_MAX_SESSIONS; i++) {
        long expected = 0;
        if (atomic_compare_exchange_strong(&gm_sessions[i].session_id, &expected, session_id)) {
            atomic_store(&gm_sessions[i].cancelled, 0);
            gm_sessions[i].log_len = 0;
            return;
        }
    }
    /* Table full: cancellation/log capture for this session silently
     * becomes a no-op. Cannot happen while FfmpegJobPool caps concurrency
     * well below GM_MAX_SESSIONS and callers drain logs promptly. */
}

int cancelRequested(long session_id) {
    GmSessionSlot *slot = gm_session_find(session_id);
    return slot ? atomic_load(&slot->cancelled) : 0;
}

static void gm_mark_cancelled(long id) {
    GmSessionSlot *slot = gm_session_find(id);
    if (slot) atomic_store(&slot->cancelled, 1);
}

GM_EXPORT void gm_cancel(int64_t session_id) {
    gm_mark_cancelled((long)session_id);
}

/* Called by fftools_ffmpeg.c's cancel_operation() for non-zero session ids. */
void cancelSession(long sessionId) {
    gm_mark_cancelled(sessionId);
}

/* fftools_opt_common.c's only caller of show_help_default_ffprobe() is the
 * ffprobe-specific help topic, which the ffmpeg tool build never reaches;
 * still required to satisfy the link since we don't vendor fftools_ffprobe.c. */
void show_help_default_ffprobe(const char *opt, const char *arg) {
    (void)opt;
    (void)arg;
}

/* Log capture: append into the current thread's session slot (globalSessionId
 * is set by gm_execute before calling into fftools). Best-effort -- if this
 * thread has no active session (e.g. a log line from an internal libav
 * worker thread that never called gm_execute) the line is dropped. */
void ffmpegkit_log_callback_function(void *ptr, int level, const char *format, va_list vargs) {
    (void)ptr;
    (void)level;
    char line[1024];
    int n = vsnprintf(line, sizeof(line), format, vargs);
    if (n <= 0) return;
    if ((size_t)n > sizeof(line) - 1) n = sizeof(line) - 1;

    GmSessionSlot *slot = gm_session_find(globalSessionId);
    if (!slot) return;

    EnterCriticalSection(&slot->log_lock);
    size_t space = GM_LOG_BUF_SIZE - 1 - slot->log_len;
    size_t copy = (size_t)n < space ? (size_t)n : space;
    if (copy > 0) {
        memcpy(slot->log_buf + slot->log_len, line, copy);
        slot->log_len += copy;
    }
    LeaveCriticalSection(&slot->log_lock);
}

GM_EXPORT int gm_get_logs(int64_t session_id, char *buf, int32_t cap) {
    if (cap <= 0) return 0;
    GmSessionSlot *slot = gm_session_find((long)session_id);
    if (!slot) { buf[0] = 0; return 0; }

    EnterCriticalSection(&slot->log_lock);
    size_t n = slot->log_len;
    size_t copy = n < (size_t)(cap - 1) ? n : (size_t)(cap - 1);
    memcpy(buf, slot->log_buf, copy);
    buf[copy] = 0;
    LeaveCriticalSection(&slot->log_lock);

    /* Drain: free the slot for reuse. */
    atomic_store(&slot->session_id, 0);
    return (int)copy;
}

/* --- entry point --------------------------------------------------------*/

GM_EXPORT int gm_execute(int64_t session_id, int argc, char **argv) {
    gm_install_handler_once();

    long id = (long)session_id;
    globalSessionId = id;
    gm_session_register(id);

    int rc;
    int crash_code = setjmp(gm_recover_point);
    if (crash_code != 0) {
        gm_guard_active = 0;
        return GM_ERR_CRASH;
    }

    gm_guard_active = 1;
    rc = ffmpeg_execute(argc, argv);
    gm_guard_active = 0;

    return rc;
}

/* --- probe / encoder query ------------------------------------------------
 * Pure libav, no fftools globals -- no session id, no crash guard needed
 * (avformat_open_input on a garbage file returns an error, it doesn't crash;
 * unlike gm_execute this never runs untrusted CLI option parsing). */

GM_EXPORT int gm_probe(const char *path, GmMediaInfo *out) {
    memset(out, 0, sizeof(*out));

    AVFormatContext *fmt = NULL;
    int ret = avformat_open_input(&fmt, path, NULL, NULL);
    if (ret < 0) return ret;

    ret = avformat_find_stream_info(fmt, NULL);
    if (ret < 0) {
        avformat_close_input(&fmt);
        return ret;
    }

    int video_idx = -1;
    int has_audio = 0;
    for (unsigned i = 0; i < fmt->nb_streams; i++) {
        AVStream *st = fmt->streams[i];
        if (st->codecpar->codec_type == AVMEDIA_TYPE_VIDEO && video_idx < 0) {
            video_idx = (int)i;
        } else if (st->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            has_audio = 1;
        }
    }

    if (video_idx < 0) {
        avformat_close_input(&fmt);
        return AVERROR_STREAM_NOT_FOUND;
    }

    AVStream *vst = fmt->streams[video_idx];
    int64_t duration = fmt->duration != AV_NOPTS_VALUE ? fmt->duration : vst->duration;
    AVRational time_base = fmt->duration != AV_NOPTS_VALUE ? AV_TIME_BASE_Q : vst->time_base;

    out->duration_ms = duration != AV_NOPTS_VALUE
        ? av_rescale_q(duration, time_base, (AVRational){1, 1000})
        : 0;
    out->width = vst->codecpar->width;
    out->height = vst->codecpar->height;
    out->fps = vst->avg_frame_rate.den ? av_q2d(vst->avg_frame_rate)
             : vst->r_frame_rate.den ? av_q2d(vst->r_frame_rate) : 0.0;
    out->has_audio = has_audio;

    avformat_close_input(&fmt);
    return 0;
}

GM_EXPORT int gm_supports_encoder(const char *name) {
    return avcodec_find_encoder_by_name(name) != NULL;
}
