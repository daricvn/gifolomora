#ifndef GM_SHIM_H
#define GM_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GM_EXPORT __declspec(dllexport)

/* Return codes for gm_execute, on top of ffmpeg's own exit codes (>=0). */
#define GM_ERR_CRASH    -1000  /* native crash caught by the VEH guard */
#define GM_ERR_UNKNOWN  -1001

/* Blocking. Runs one ffmpeg command. argv[0] IS required -- it must be a
 * placeholder program-name element (any string; fftools' option parser
 * skips it, same convention as main(argc,argv)); real options start at
 * argv[1]. Safe to call concurrently from different threads with different
 * session_id values. */
GM_EXPORT int gm_execute(int64_t session_id, int argc, char **argv);

/* Requests graceful cancellation of a running session (checked by fftools'
 * own cancellation points). Safe to call from any thread. */
GM_EXPORT void gm_cancel(int64_t session_id);

typedef struct {
    int64_t duration_ms;
    int32_t width;
    int32_t height;
    double fps;
    int32_t has_audio; /* 0/1 */
} GmMediaInfo;

/* Pure libav, no fftools globals involved -- thread-safe, callable
 * concurrently with gm_execute or other gm_probe calls. Returns 0 on
 * success, a negative AVERROR on failure. */
GM_EXPORT int gm_probe(const char *path, GmMediaInfo *out);

/* avcodec_find_encoder_by_name() != NULL. Thread-safe. */
GM_EXPORT int gm_supports_encoder(const char *name);

/* Drains up to cap-1 bytes of this session's captured log lines into buf
 * (NUL-terminated) and clears them. Returns the number of bytes written.
 * Call after gm_execute returns -- the session's log slot is freed at that
 * point, so this must run before the next gm_execute reuses the id. */
GM_EXPORT int gm_get_logs(int64_t session_id, char *buf, int32_t cap);

#ifdef __cplusplus
}
#endif

#endif /* GM_SHIM_H */
