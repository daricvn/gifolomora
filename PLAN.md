# PLAN — Windows FFmpeg: bundled `ffmpeg.exe` → in-process `ffmpeg` DLL

> Goal: replace the spawned `ffmpeg.exe` on Windows with an in-process FFmpeg DLL invoked over
> `dart:ffi`, keeping **every existing feature working**, enabling **async + parallel** jobs, with
> **safeguards so a native crash does not take down the app**.
>
> Non-goals: Android/iOS backend (`FfmpegKitBackend`) untouched — binaries included (GPL build
> stays; compliant once app source is public, §5). Linux stays on the process backend (can adopt
> the same shim later). No UI changes except the About-screen license section (§5).

---

## 1. Current state (confirmed in code)

| What | Where |
|---|---|
| Process backend: `Process.start(ffmpeg.exe)` + `-progress pipe:1` stdout parsing, stderr capture into `FfmpegError.stderr` | `lib/core/services/ffmpeg/ffmpeg_process_backend.dart:45` |
| Probe: `Process.run(ffprobe.exe, -print_format json)` | `ffmpeg_process_backend.dart:116` |
| Encoder gate: `Process.run(ffmpeg, -encoders)` → `supportsEncoder()` (AV1 chip) | `ffmpeg_process_backend.dart:179` |
| Cancel: single `_current` process, `kill()` | `ffmpeg_process_backend.dart:188` |
| Factory: `Platform.isAndroid/isIOS ? FfmpegKitBackend : FfmpegProcessBackend` | `ffmpeg_factory.dart:8` |
| Screen recorder owns its own `Process` (open-ended gdigrab capture, stdin `q` graceful stop, segment-per-pause, dshow device listing, concat/mux finalize) | `lib/core/services/record/screen_recorder_service.dart:188,132,356` |
| Binaries resolved next to `Platform.resolvedExecutable`; copied by `scripts/setup_windows_dev.ps1`; packaged by `scripts/build_msix_release.ps1` | `ffmpeg_process_backend.dart:27` |
| One shared backend instance app-wide; only one job runs at a time today (single `_current`, single `_currentJobDir`) | `providers.dart`, `ffmpeg_service.dart:23` |
| GPL encoder in use: `libx264` (videoEdit software fallback + screen capture) | `ffmpeg_command.dart:659,698`, `video_encoder.dart:8` |

---

## 2. Core design decision — what "use ffmpeg.dll" means

Three ways to consume FFmpeg as a DLL; we pick **(C)**:

- **(A) Raw libav\* FFI (avformat/avcodec/avfilter direct):** would mean reimplementing every
  pipeline (palettegen/paletteuse two-pass, drawtext chains, concat demuxer, amix, boomerang
  concat…) in Dart/C against the libav API. That is rewriting `ffmpeg.c`. Rejected — months of
  work, every `FfmpegCommand` arg builder discarded, highest regression risk.
- **(B) Prebuilt "ffmpeg CLI as a lib" from a maintained project:** none exists for Windows.
  `ffmpeg-kit` (which did exactly this for mobile) was retired April 2025 and never shipped
  Windows. Rejected as a dependency, **adopted as a source of patches** (LGPL, forkable).
- **(C) Thin C shim DLL embedding patched `fftools`** (the ffmpeg-kit approach, ported):
  compile FFmpeg's own CLI layer (`fftools/ffmpeg*.c`) into `ffmpeg_shim.dll`, exporting a
  `run(argv)`-style entry. **All existing `FfmpegCommand` arg builders keep working unchanged** —
  the shim executes the same argv the exe received. Links against the standard shared FFmpeg
  DLLs (`avcodec-*.dll`, `avformat-*.dll`, …).

Why (C) is optimal: zero changes above the backend interface, full feature parity by
construction (same CLI semantics), and the parallelism/cancellation problems are already solved
in ffmpeg-kit's vendored patches (see §4).

### Required fftools patches (vendor from ffmpeg-kit, port to Windows)

1. **No `exit()`:** fftools calls `exit_program()` on any error — in-process that kills the app.
   Patch replaces it with `longjmp` back to the entry point returning an error code
   (ffmpeg-kit's `fftools_ffmpeg.c` pattern).
2. **Global-state reset + thread-local globals:** fftools globals (`nb_input_files`,
   `received_sigterm`, option contexts…) get `__thread` storage so **concurrent sessions on
   separate threads don't corrupt each other** — this is precisely how ffmpeg-kit supports
   concurrent sessions. Plus a `var_cleanup()` reset at entry.
3. **Per-session cancel:** exported `cancel(session_id)` sets the session's
   `received_sigterm`-equivalent → ffmpeg's own **graceful** shutdown path runs (trailer written,
   file closed). Strictly better than today's `Process.kill()` which can leave truncated output.
4. **Log capture:** `av_log_set_callback` routes logs into a per-session ring buffer so
   `FfmpegError.stderr` parity is kept (error surfaces + encoder-fallback diagnostics).
   **[Found in Phase 1]** the vendored `fftools_opt_common.c`'s `log_callback_report` only
   forwards to `ffmpegkit_log_callback_function` when fftools' own `-report` CLI flag is active
   — it is *not* installed as the default sink. ffmpeg-kit's own Android/Linux wrapper calls
   `av_log_set_callback(ffmpegkit_log_callback_function)` itself, once, at library init (not
   per-session) — `gm_shim.c` now does the same, in `gm_install_handler_once()`. Without it,
   logs went straight to the console via `av_log_default_callback` and `gm_get_logs` always
   returned empty.
5. **[Found in Phase 0, Windows-only] Disable `prepare_app_arguments()`'s argv override.**
   fftools' `cmdutils.c` has a `HAVE_COMMANDLINETOARGVW && defined(_WIN32)` path that replaces
   whatever `argc`/`argv` the caller passed to `split_commandline()`/`parse_options()` with the
   **host process's own** `GetCommandLineW()` — correct for a standalone `ffmpeg.exe`, fatal for
   in-process embedding (every session would see the same, empty, host-process argv instead of
   its own job argv). Forced off (`#if 0 && HAVE_COMMANDLINETOARGVW...`) in the vendored copy.
   Not in ffmpeg-kit's own patch list because ffmpeg-kit never shipped Windows.

### Shim exports (C ABI)

```c
int  gm_execute(int64_t session_id, int argc, char** argv);  // blocking; SEH-wrapped
void gm_cancel(int64_t session_id);                          // graceful stop
int  gm_probe(const char* path, GmMediaInfo* out);           // pure libav, no fftools
int  gm_supports_encoder(const char* name);                  // avcodec_find_encoder_by_name
int  gm_get_logs(int64_t session_id, char* buf, int cap);    // ring buffer drain
```

`gm_probe` / `gm_supports_encoder` use the libav API directly (`avformat_open_input` +
`find_stream_info` → duration/width/height/fps/hasAudio; ~100 lines of C). No globals → fully
thread-safe, fully parallel, and **`ffprobe.exe` is no longer needed by the backend**. Replaces
the JSON round-trip in `_parseProbeJson`.

---

## 3. Crash-safety reality check (the honest part)

**Dart isolates do not isolate native crashes.** An access violation inside the DLL kills the
whole process regardless of which isolate called it. The only *perfect* isolation is a separate
process — which is what we're moving away from. So the safeguard budget is spent on three layers:

1. **Crash guard in the shim.** `gm_execute` body wrapped in a guard that catches access
   violations, illegal instructions, and div-by-zero inside FFmpeg and returns an error code
   instead of terminating the process. **Implementation deviates from the sketch above:**
   `mingw`'s GCC has no `__try`/`__except` (MSVC-only keywords; confirmed in Phase 0, not
   available even with `-fms-extensions`). Used instead: `AddVectoredExceptionHandler` +
   per-thread `longjmp` to a `setjmp` point in `gm_execute` — same fault classes caught, proven
   working standalone and against the real compiled `gm_shim.dll` (forced-AV test, Phase 0).
   *Does not catch:* `__fastfail` (heap-corruption fast-fail), some stack-overflow states.
   Documented limit, unchanged from the original sketch.
2. **Poison + automatic exe fallback.** After any SEH-caught crash the process heap may be
   suspect. The Dart backend marks itself **poisoned**: the failed job returns `FfmpegError`
   ("engine fault, retried via fallback"), and *all* subsequent jobs in this app session route to
   the retained `FfmpegProcessBackend` (exe). One crash = degraded to today's behavior, never a
   dead app.
3. **Hung-job watchdog.** In-process, a truly hung native call can't be killed
   (`TerminateThread` = corruption). After `cancel()` a session gets N seconds (default 10) to
   return; if it doesn't: leak that thread, mark poisoned, fall back to exe. Bounded damage —
   one leaked thread + its memory, app keeps running. (Today's exe equivalent: `kill()` always
   works — this is the one capability we genuinely trade away; the fallback caps the cost.)

**[Superseded] Screen recorder stays on `ffmpeg.exe` — reverted, now all-in on the DLL.** The
reasoning below was the original call; the user explicitly overrode it (no exe anywhere, not
even as the crash-safety fallback for regular export jobs) after Phase 3 bundling was done and
`ffmpeg.exe` was no longer needed by anything else. Ported and verified:

- `ScreenRecorderService` no longer owns a `Process` — a new `RecorderEngine` interface
  (`gm_execute`/`gm_cancel` via `GmShim`, `lib/core/services/ffmpeg/gm_shim_ffi.dart`) replaces
  it. `GmShimRecorderEngine` is the real implementation; fakeable in tests like
  `LoopbackController` already was.
- Segment lifecycle: `Process.start` → `engine.execute(sessionId, argv)` (runs in an isolate,
  same as `FfmpegDllBackend`); stdin `"q"` graceful-stop → `engine.cancel(sessionId)` (fftools'
  own `cancelRequested()` path); `Process.kill()` fallback on timeout → **no equivalent**, a
  hung segment is leaked (documented, same tradeoff as `FallbackFfmpegBackend`'s watchdog was).
  stdout/stderr pipe-draining is gone entirely — no OS pipe in-process, `gm_shim`'s own log ring
  buffer replaces it.
- **New finding, confirmed against a real gdigrab capture:** a `gm_cancel()`-stopped session
  exits with **rc 255**, not 0 — fftools' own sentinel
  (`exit_program((received_nb_signals || cancelRequested(...)) ? 255 : main_ffmpeg_return_code)`
  in `fftools_ffmpeg.c`). `ScreenRecorderService` doesn't need to branch on this (its
  `_expectingExit` flag already short-circuits deliberate-cancel exits before they'd be treated
  as crashes), but `FfmpegDllBackend.run()` now maps `gmCancelledExitCode` (255) to a clean
  `Err(FfmpegError(message: 'Cancelled'))`, matching the old process backend's UX instead of
  surfacing "FFmpeg exited with code 255".
- Real integration tests (`test/unit/core/services/record/gm_shim_recorder_engine_test.dart`,
  gated on `GM_SHIM_DLL_PATH` like the others): a real 2s gdigrab capture through `gm_execute`
  produces a playable file; `gm_cancel()` stops a 30s-`-t` capture in under 1s. This was
  PLAN.md's own highest-flagged crash-risk workload — tested for real, not just via the fake.
- `FfmpegFactory` no longer wraps `FfmpegDllBackend` in `FallbackFfmpegBackend` on Windows — it
  returns the DLL backend directly. `FallbackFfmpegBackend` itself is untouched/still tested but
  unused; `FfmpegProcessBackend` only comes into play if `gm_shim.dll` can't be found/loaded at
  all (dev machine without the DLL built), not as a mid-session crash fallback.
- `assets/bin/windows/ffmpeg.exe` and `ffprobe.exe` deleted; `setup_windows_dev.ps1` no longer
  copies or requires them.
- **Deviation from the original zero-parallelism-benefit reasoning:** unchanged and still true
  — the recorder gains nothing from the DLL architecturally (still one open-ended session, no
  concurrency need). This was accepted as the cost of removing the exe dependency entirely, not
  a benefit of the port itself.

---

## 4. Concurrency & scheduling

- **`FfmpegDllBackend implements FfmpegBackend`** — same interface, so `FfmpegService`,
  controllers, and tests need **no changes**. Internally each `run()` allocates a session id,
  executes `gm_execute` inside `Isolate.run(...)` (blocking FFI call on that isolate's worker
  thread — UI isolate never blocks), and completes with `Result<File, FfmpegError>` exactly as
  today.
- **`FfmpegJobPool`** (small Dart semaphore inside the backend): caps concurrent `gm_execute`
  sessions. Default **2** (FFmpeg is internally multithreaded; more parallel encodes mostly
  fight over cores + RAM). Probes bypass the pool (cheap, thread-safe).
- **Cancellation:** `cancel()` keeps its current contract (cancel active work) by cancelling all
  live sessions. Per-session handles exist internally, so a future interface extension
  (returning a job handle) is trivial — not done now, nothing needs it yet.
- **`FfmpegService._currentJobDir`** stays as-is (one *export* job at a time is a UI-flow fact,
  not a backend limit). Parallel capacity is immediately used by: probe-during-encode, preview
  jobs while an export runs, and any future batch feature.

### Progress reporting

`-progress pipe:1` has no meaning in-process (stdout is the app's). Swap: backend rewrites the
trailing `-progress pipe:1` pair (already appended by every `FfmpegCommand` builder) to
`-progress <jobDir>/progress.txt`, then **tails that file** (poll ~150 ms). Format is identical
key=value lines (`frame=`, `out_time_ms=`, `progress=end`) — the existing
`_parseProgressLine` logic moves to a shared helper and is reused verbatim. fftools flushes the
progress AVIO each report interval, so file tailing is reliable. No fftools patch needed for
progress.

---

## 5. Licensing (decided: GPL — app will be open source)

The app ships under a GPL-compatible open-source license, so the GPL FFmpeg builds stay on
both platforms — **no encoder changes anywhere**:

- Windows keeps `libx264` (`ffmpeg_command.dart:659,698`, `video_encoder.dart:8`) and bundles a
  GPL **shared** build (gyan.dev `release-full-shared` or BtbN `win64-gpl-shared` — DLLs +
  import libs + headers + thin exe in one archive).
- Android keeps `ffmpeg-kit-full-gpl:2.1.0` (`packages/ffmpeg_kit_flutter_new/android/build.gradle:54`)
  unchanged. Today's in-process GPL linking becomes compliant the moment the app source is
  public under a compatible license.
- Combined-work consequence: distributed binaries carry GPL terms regardless of the app's own
  license choice (own code under MIT/Apache is fine; the shipped combination must satisfy GPL).

**Hard gate before any public release:** repo public **with a GPL-compatible `LICENSE` file
committed** (GPLv3 is the friction-free pick; MIT/Apache-2.0 also work). "Source-available",
non-commercial terms, or a missing LICENSE are *not* GPL-compatible — bundling `libx264` would
then be a violation. This gate blocks Phase 3, not the engineering phases.

Remaining obligations (cheap once the repo is public, both platforms):

1. **Attribution notice** — About screen (`lib/features/about/view/about_screen.dart`) gains an
   "Open-source licenses" / FFmpeg section: *"This software uses code of FFmpeg
   (https://ffmpeg.org) licensed under the GPLv2 or later"* + no implied endorsement, FFmpeg
   name/logo not used as product branding.
2. **License texts** — bundle GPL + LGPL texts and FFmpeg copyright notices (asset shown from
   the About screen; also a `THIRD_PARTY_LICENSES` file in the install/MSIX payload).
3. **Corresponding source links**, kept release-accurate: Windows — the exact build release's
   matching source tarball (gyan/BtbN publish them); Android — the ffmpeg-kit fork's source tag
   for `2.1.0`. The shim's source is covered automatically — it lives in the public app repo.
4. **Release checklist entry** — `build_msix_release.ps1` gets a comment block: verify notice
   text, license assets, and source links match the bundled binary versions before shipping.

**Verify item (phase 0):** chosen GPL shared build lists `libx264`, `libvpx`, `libaom`,
`libopus`, `gdigrab`, `dshow` under its enabled components ("full" builds carry all of these —
light check, expected to pass).

---

## 6. Bundling & build changes

**[Phase 3, verified]** Actual contents of `assets/bin/windows/` (git-ignored, same as today) —
built from FFmpeg **n6.0** (the version our vendored fftools patches target) via clang/MSYS2,
`--enable-gpl --enable-version3 --enable-libx264 --enable-libvpx --enable-libaom --enable-libopus
--enable-libfreetype --enable-zlib`:

```
avcodec-60.dll avformat-60.dll avutil-58.dll avfilter-9.dll avdevice-60.dll
swscale-7.dll swresample-4.dll          ← core FFmpeg libs (GPL build)
libx264-165.dll libvpx-1.dll            ← dynamically linked, NOT statically baked in --
libaom.dll libopus-0.dll                  discovered via `ldd`/`objdump -p`, not anticipated
                                           by the original sketch below
libwinpthread-1.dll                     ← clang/mingw runtime dep of the above 4, also not
                                           anticipated originally
libfreetype-6.dll libharfbuzz-0.dll     ← drawtext filter's dependency chain
libpng16-16.dll zlib1.dll libbz2-1.dll    (`--enable-libfreetype`, added after the initial
libbrotlidec.dll libbrotlicommon.dll      Phase 3 build shipped WITHOUT it and every
libglib-2.0-0.dll libgraphite2.dll        text-overlay job failed with "No such filter:
libc++.dll libintl-8.dll libpcre2-8-0.dll  'drawtext'" -- see gm_shim.dll bug log below)
libiconv-2.dll
gm_shim.dll                             ← ours (fftools + patches + guard + exports)
```

(No `ffmpeg.exe` — recorder moved onto the DLL too, see §3's "Superseded" note; older
text below that still mentions a bundled exe predates that decision.)

(`ffprobe.exe` dropped — probe goes through `gm_probe`, confirmed working in Phase 1.
No prebuilt GPL **shared** package exists anywhere for the exact n6.0 tag — gyan.dev/BtbN only
keep recent nightlies/majors — so this build is produced from source via
`scripts/build_ffmpeg_shim.ps1`'s pipeline, same as `gm_shim.dll` itself, not downloaded.
`libx264`/`libvpx`/`libaom`/`libopus`/`libfreetype` come from MSYS2's own
`mingw-w64-clang-x86_64-*` packages — prebuilt, no need to build those from source too.

**Post-launch bug + fix:** the first shipped build omitted `--enable-libfreetype`. Two
consequences, both hit in production and root-caused via a real-DLL harness (`gm_execute` +
`-report`, not guesswork): (1) the palette-bake pass (`videoEditToGif`'s two-pass GIF export)
wrote its intermediate as `.png` — this build also lacked `zlib`, so `image2`'s default png
encoder couldn't be auto-selected, failing every video→GIF edit-bake with rc=1 ("Automatic
encoder selection failed"). Worked around at first by switching the intermediate to `.bmp` +
explicit `-c:v bmp` (zero codec deps, lossless RGBA round-trip) — no rebuild needed for this half.
**Superseded:** rebuilt FFmpeg with `--enable-zlib` (§6 flags list) and relinked `gm_shim.dll`;
`videoEditToGif`'s palette pass reverted to the plain `palette.png` intermediate with no `-c:v`
override (auto-selects the now-available png encoder), matching the pre-bug design.
(2) `drawtext` itself wasn't compiled in (needs `libfreetype`), so *any* text-overlay job
(GIF or video) failed on every encoder candidate identically with "No such filter: 'drawtext'"
— unlike (1), no app-level workaround exists; fixed by rebuilding FFmpeg with
`--enable-libfreetype` and relinking `gm_shim.dll`. Regression tests: `ffmpeg_command_test.dart`
(palette pass has no `-c:v` override, still writes `palette.png`) and `ffmpeg_dll_backend_test.dart`
(real drawtext job against the compiled DLL, gated on `GM_SHIM_DLL_PATH`).)

Original sketch (kept for context, superseded by the verified list above):

```
avcodec-62.dll avformat-62.dll avutil-60.dll avfilter-11.dll avdevice-62.dll
swscale-9.dll swresample-6.dll          ← from the GPL shared build (§5)
ffmpeg.exe                              ← thin exe from the SAME shared build (recorder)
ffmpeg_shim.dll                         ← ours (fftools + patches + SEH + exports)
```

- **Shim build:** `windows/ffmpeg_shim/` — vendored `fftools/*.c` for the pinned FFmpeg version
  + ffmpeg-kit patch port + `gm_*.c`. Built with **MSYS2/mingw-w64** (fftools needs FFmpeg's
  generated `config.h` and gcc-isms; mingw's `__thread` matches the patches; C-ABI DLL links
  fine into the MSVC app). New `scripts/build_ffmpeg_shim.ps1` drives it; produced DLL is a
  committed **release artifact**, not built per-dev — devs download the bundle like they
  download ffmpeg.exe today (`setup_windows_dev.ps1` error message updated with the new list).
- `scripts/setup_windows_dev.ps1` and `scripts/build_msix_release.ps1`: copy the new file set.
- `FfmpegProcessBackend.resolveBin` unchanged (still resolves next to
  `Platform.resolvedExecutable`); `FfmpegDllBackend` resolves `ffmpeg_shim.dll` the same way and
  `DynamicLibrary.open`s it (the libav DLLs sit beside it → normal Windows DLL search finds them).

### Factory wiring

```dart
// ffmpeg_factory.dart
static FfmpegBackend create() {
  if (Platform.isAndroid || Platform.isIOS) return FfmpegKitBackend();
  if (Platform.isWindows) {
    final dll = FfmpegDllBackend.tryLoad();      // null if shim/DLLs missing or load fails
    if (dll != null) return FallbackFfmpegBackend(primary: dll, fallback: _processBackend());
  }
  return _processBackend();                      // Linux + any Windows load failure
}
```

`FallbackFfmpegBackend` is the poison switch from §3: delegates to `primary` until it reports a
fault, then permanently (per app session) delegates to `fallback`, logging loudly. Missing DLLs
= silent exe fallback → **the app can never be *more* broken than it is today.**

---

## 7. Phases & gates

**Baseline first (before any change):** record `flutter analyze` (expect 0) and full
`flutter test` pass/fail counts + names. All later "no regression" claims diff against this.

- **Phase 0 — Spike (go/no-go gate). [DONE — GO.]** Built the shim with one export
  (`gm_execute`), ran real argv (lavfi → mpeg4) through a C test harness (FFI-shaped: `LoadLibraryA`
  + `GetProcAddress`, same call surface Dart FFI uses). Results:
  (a) success path ✓ — real output file produced; (b) error path (missing input) returns
  `rc=1`, process stays alive, next call still works ✓; (c) crash guard catches a forced AV
  inside the real compiled `gm_shim.dll` (`rc=GM_ERR_CRASH`, process alive, next session still
  runs) ✓; (d) two sessions on two threads (ids 101/102) ran concurrently, both completed with
  correct independent output files, no corruption ✓; (e) not verified — the Phase 0 FFmpeg build
  is a minimal LGPL build (no `libx264`/GPL libs) built purely to validate the shim mechanics
  cheaply; §5's GPL-component verify is deferred to Phase 3 when the real bundled build is chosen.
  **Findings/deviations, carried into §2/§3 above:**
  - Toolchain is **clang** (MSYS2 `CLANG64`/`mingw-w64-clang-x86_64-toolchain`), not GCC. The
    MSYS2 `mingw-w64-x86_64-gcc` (16.1.0) toolchain hit a reproducible codegen bug (`operand type
    mismatch for 'shr'`) across many unrelated FFmpeg source files — a compiler defect, not
    something to patch around. clang built FFmpeg 6.0 clean with zero errors and, as a bonus,
    supports real `__try`/`__except` if a future revision wants that instead of the VEH guard.
  - Crash guard is `AddVectoredExceptionHandler` + `longjmp`, not `__try/__except` (§3).
  - New required patch: disable `prepare_app_arguments()`'s Windows `GetCommandLineW()` override
    (§2 item 5) — without it every session silently parsed the host process's own (empty) argv
    instead of its job argv, the "usage" banner on every call was the tell.
  - FFmpeg 6.0 build needs `--enable-avdevice` even though the shim doesn't use it directly:
    `fftools_ffmpeg.c` unconditionally `#include`s `libavdevice/avdevice.h`.
  - Cancellation latency not yet characterized: a cancel fired 300ms into a 2s/50-frame job
    didn't visibly interrupt it (job ran to natural completion) — likely a cancellation
    check-point granularity question, not a correctness bug (`cancelRequested()` wiring itself
    compiles and links correctly). Revisit with a longer job in Phase 1/4.
  - No fallback plan needed — (b) and (d), the two stop-and-replan triggers, both passed.
- **Phase 1 — Backend. [DONE]** `FfmpegDllBackend` (`lib/core/services/ffmpeg/ffmpeg_dll_backend.dart`):
  run/probe/supportsEncoder/cancel/dispose behind the unchanged `FfmpegBackend` interface,
  `FfmpegJobPool` (`ffmpeg_job_pool.dart`, default cap 2), progress-file tailing (shared
  `FfmpegProgress.parseProgressLine` helper, used by both backends now), log capture via
  `gm_get_logs` → `FfmpegError.stderr`. Native side gained `gm_probe`, `gm_supports_encoder`,
  `gm_get_logs` (all from PLAN §2's export list) plus the always-on `av_log_set_callback`
  install needed to make log capture actually fire (see §2 item 4 finding). Existing
  `FfmpegProcessBackend`/tests untouched. Every FFI call (`gm_execute`, `gm_probe`,
  `gm_supports_encoder`) runs inside `Isolate.run` — plain data only crosses the isolate
  boundary, all `Pointer`s are allocated and freed inside the spawned isolate.
  Tests: `ffmpeg_job_pool_test.dart`, `ffmpeg_progress_test.dart` (parseProgressLine), and a
  real-DLL integration suite (`ffmpeg_dll_backend_test.dart`, gated on `GM_SHIM_DLL_PATH` env
  var since the toolchain isn't assumed present everywhere yet) covering success/error/probe/
  supportsEncoder/concurrency against the actual compiled `gm_shim.dll` — all passing.
- **Phase 2 — Wiring + safeguards. [DONE]** `FfmpegFactory.create()` wraps `FfmpegDllBackend` in
  `FallbackFfmpegBackend` on Windows when `FfmpegDllBackend.tryResolvePath()` finds a loadable
  DLL; missing/unloadable DLL silently falls back to the exe backend, unchanged from today.
  `FallbackFfmpegBackend` (`fallback_ffmpeg_backend.dart`): poisons (permanently, for the app
  session) when a job's `FfmpegError.exitCode == FfmpegDllBackend.crashExitCode`; `cancel()`
  starts a watchdog that, if the primary hasn't honored the cancel within `watchdogDuration`
  (default 10s), poisons and unblocks the caller's `run()` with a `Cancelled` result instead of
  hanging forever (the leaked isolate/thread is the accepted cost, per §3). No encoder or
  arg-builder changes — GPL build keeps `libx264` everywhere (§5), unaffected by any of this.
  Tests: `fallback_ffmpeg_backend_test.dart` (healthy passthrough, crash → poison → subsequent
  jobs route to fallback, non-crash error does *not* poison, hung-cancel watchdog unblocks
  `run()` and poisons, probe/supportsEncoder route to fallback once poisoned) — all passing.
  Full suite (`flutter test`): 595 passed, 0 failed, 0 analyze issues, no regressions.
- **Phase 3 — Bundling + compliance. [In progress — gate cleared, engineering mostly done.]**
  §5 hard gate cleared: LICENSE (GPLv3) committed, repo made public (user-confirmed). Done:
  real GPL production FFmpeg 6.0 built (§6, verified list) with `libx264`/`libvpx`/`libaom`/
  `libopus` all confirmed via `gm_supports_encoder` + a real `libx264` encode through
  `gm_execute`; `gm_shim.dll` rebuilt and re-tested against this GPL build (same 5-test
  integration suite, all passing); `scripts/setup_windows_dev.ps1` copies the full verified
  file set (`gm_shim.dll` + all companion DLLs now hard-required — no `ffmpeg.exe` bundled or
  built at all, superseded by §3's "recorder all-in on DLL" decision); `build_msix_release.ps1`
  gained the §5 release
  checklist comment block. About-screen "Open-source licenses" card added
  (`lib/features/about/view/about_screen.dart`, `license_viewer_screen.dart`) with the required
  attribution text, linking to three bundled texts under `assets/licenses/`: `FFMPEG_NOTICE.txt`
  (short attribution, authored for this app) and `FFMPEG_GPLv3.txt`/`FFMPEG_LGPLv2.1.txt`
  (copied verbatim from the FFmpeg source tree's own `COPYING.GPLv3`/`COPYING.LGPLv2.1` — not
  retyped from memory, to avoid any risk of an inaccurate legal text).
  **[Done]** `flutter build windows --release` succeeded; `setup_windows_dev.ps1 -Config Release`
  copied the full verified bundle into `build\windows\x64\runner\Release\`; the packaged
  `gifolomora.exe` launched and stayed alive (no immediate crash from `FfmpegFactory.create()`
  loading `gm_shim.dll` in the real packaged layout, not just via `flutter test`'s
  `GM_SHIM_DLL_PATH` env var).
  **Still open:** actual MSIX packaging (`dart run msix:create`, the last step of
  `build_msix_release.ps1`) not run this session — unrelated to the FFmpeg work and low-risk,
  but not verified; testing on a genuinely clean machine (no dev tooling at all) wasn't possible
  from this environment. Corresponding-source link in `FFMPEG_NOTICE.txt` is a placeholder
  pointing at "the project's source repository" — fill in the real repo URL. The license card's
  copy should get one human read-through before shipping (not legal advice).
- **Phase 4 — Hardening + verification.** Full manual matrix (§8), crash-injection test (feed a
  deliberately corrupt file / bad argv; confirm: error surfaced, app alive, next job runs via
  fallback), cancel-during-encode test, parallel probe+encode test, 10-min recording test.
- **Deferred (explicit non-goal):** recorder → DLL; Linux → shim; per-job handles in the
  `FfmpegBackend` interface; parallel *export* UI.

---

## 8. Feature-parity checklist (must all pass on Windows before merge)

Every `FfmpegService` op via DLL: `imagesToGif`, `videoToGif`, `resizeGif`, `cropGif`,
`textOverlay`, `textOverlayMulti` (multi-layer + custom fonts via `fontfile=`), `reverseGif`,
`changeSpeed`, `editVideo` (encoder fallback loop exercises log capture), `videoStreamCopy`,
`bakeVideoToGif` (two-pass palette), `editGif` (incl. boomerang + trim), WebM export (VP9 + AV1
+ alpha + opus audio), `probe` on mp4/gif/webm, `supportsAv1` gate, progress % + cancel in
`ProgressOverlay`, `optimizeGif` (pure Dart — unaffected, regression-check only).
Screen record: start/pause/resume/stop, mic + system audio mux, cap, crash recovery, dshow
device listing (now all-in on the DLL backend via `RecorderEngine` — real gdigrab capture +
cancel verified in Phase 3, full manual matrix still pending). Export flow + temp cleanup + recents.
Error surfaces: a failing job shows a real stderr-derived message, not a blank.

**Android:** binaries unchanged — regression-check only (one export per tool on a real device).
About screen shows the FFmpeg notice on both platforms.

---

## 9. Open decisions (owner: you)

1. ~~License route~~ — **done: GPLv3 LICENSE committed, repo made public** (user-confirmed).
   §5 hard gate cleared, Phase 3 unblocked.
2. ~~Recorder on exe vs. all-in on DLL~~ — **decided: all-in on DLL.** User overrode the
   original recommendation after Phase 3 bundling landed and `ffmpeg.exe` had no other
   consumer left. Ported and verified (§3).
3. **Pool size default 2** — fine, or expose in Settings?

## 10. Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| ffmpeg-kit fftools patches don't port cleanly to current FFmpeg + mingw | **Resolved (Phase 0)** | Ported clean once on clang; see §7 findings. Two new Windows-only issues found and fixed: `prepare_app_arguments()` argv override (§2.5), `--enable-avdevice` header dependency |
| mingw **GCC** toolchain miscompiles FFmpeg 6.0 | **Confirmed, mitigated** | Reproducible `shr` codegen bug across many files in MSYS2's GCC 16.1.0; switched to clang (`mingw-w64-clang-x86_64-toolchain`), clean build. Pin clang as the required shim toolchain, not GCC |
| Crash guard misses a crash class (fast-fail) → app dies | Low | Accepted residual; recorder (worst risk) stays out-of-process; document. (Guard is VEH+longjmp, not `__try/__except` — see §3) |
| Hung native session can't be killed | Low | Watchdog: leak thread + poison + exe fallback |
| Heap corruption *after* a caught crash | Low | Poison switch stops using the DLL immediately |
| GPL shared build missing a needed component | **Resolved (Phase 3)** | Real GPL build done with libx264/libvpx/libaom/libopus/gdigrab/dshow all confirmed present and working (real libx264 encode succeeded) |
| App ships before repo is public / LICENSE committed → GPL violation | **Resolved** | §5 gate cleared: LICENSE committed, repo public (user-confirmed) |
| Dynamically-linked GPL codec libs (libx264/libvpx/libaom/libopus) + their libwinpthread-1.dll dependency weren't in the original bundle list | **Found + fixed (Phase 3)** | `ldd`/`objdump -p` on the built DLLs surfaced them; added to §6's verified list and `setup_windows_dev.ps1` |
| Two backends drift (exe fallback rots) | Low | Fallback shares all arg builders; Phase-4 matrix runs once with DLL force-disabled |
| Cancellation latency/check-point granularity unverified under real load | Low | Phase 0 saw a 300ms cancel not interrupt a 2s job; re-test with longer/real-codec jobs in Phase 1 or 4 |
