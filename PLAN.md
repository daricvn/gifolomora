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

1. **SEH guard in the shim.** `gm_execute` body wrapped in `__try/__except(EXCEPTION_EXECUTE_HANDLER)`
   → access violations, illegal instructions, div-by-zero inside FFmpeg return an error code
   instead of terminating the process. Catches the dominant crash class. *Does not catch:*
   `__fastfail` (heap-corruption fast-fail), some stack-overflow states. Documented limit.
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

**Screen recorder stays on `ffmpeg.exe` (decision, not deferral):**
- Highest crash-risk workload in the app (gdigrab + dshow drivers, up to 10 min continuous). A
  DLL crash mid-recording would lose the app *and* the recording session state; today a dead
  process still leaves playable MKV segments and the app alive to recover them
  (`screen_recorder_service.dart:235` already handles unexpected exit + `recoverPartial()`).
- Gains nothing from DLL: it's a single open-ended session — no parallelism need; cleanup is
  already handled (`cleanupOnShutdown`, `onWindowClose`).
- Cost is near zero: the *shared* FFmpeg build ships a thin `ffmpeg.exe` (~300 KB) that links
  the same DLLs we bundle anyway (§6). No duplicate 90 MB static exe.

The user-cited *cleanup* benefit still lands: all job-shaped work becomes in-process, so a
force-killed app can no longer orphan job ffmpeg processes; the one remaining exe use
(recording) already has kill-on-shutdown handling.

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

New contents of `assets/bin/windows/` (git-ignored, same as today):

```
avcodec-62.dll avformat-62.dll avutil-60.dll avfilter-11.dll avdevice-62.dll
swscale-9.dll swresample-6.dll          ← from the GPL shared build (§5)
ffmpeg.exe                              ← thin exe from the SAME shared build (recorder)
ffmpeg_shim.dll                         ← ours (fftools + patches + SEH + exports)
```

(`ffprobe.exe` dropped — probe goes through `gm_probe`. Version numbers per chosen FFmpeg release.)

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

- **Phase 0 — Spike (go/no-go gate).** Build the shim with one export (`gm_execute`), run one
  real `videoToGif` argv through FFI from a scratch Dart script. Prove: (a) success path,
  (b) error path returns instead of exiting the process, (c) SEH catches a forced AV,
  (d) two sessions run concurrently on two threads without corrupting each other,
  (e) chosen GPL shared build lists every component from §5's verify item. **If (b) or (d) fail
  after porting the ffmpeg-kit patches, stop and re-plan** (fallback plan: process pool of exe
  workers gets the parallelism/cleanup goals with zero crash risk — smaller win, zero native work).
- **Phase 1 — Backend.** `FfmpegDllBackend` (run/probe/supportsEncoder/cancel/dispose), progress
  file tailing, log-ring → `FfmpegError.stderr`, `FfmpegJobPool`. Unit-testable behind the
  existing interface; existing fakes/tests untouched.
- **Phase 2 — Wiring + safeguards.** Factory + `FallbackFfmpegBackend` + poison + watchdog.
  No encoder or arg-builder changes — GPL build keeps `libx264` everywhere (§5).
- **Phase 3 — Bundling + compliance.** Shared-build DLLs + thin exe in `assets/bin/windows/`;
  update both scripts; MSIX build; verify packaged app runs on a machine without dev tooling.
  About-screen FFmpeg section + bundled GPL/LGPL texts + source links (§5) land in the same
  release as the binaries they describe. **Blocked by the §5 hard gate: repo public with a
  GPL-compatible LICENSE before this release ships.**
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
device listing (still exe — regression-check only). Export flow + temp cleanup + recents.
Error surfaces: a failing job shows a real stderr-derived message, not a blank.

**Android:** binaries unchanged — regression-check only (one export per tool on a real device).
About screen shows the FFmpeg notice on both platforms.

---

## 9. Open decisions (owner: you)

1. ~~License route~~ — **decided: GPL** (app will be open source under a GPL-compatible
   license). Binaries stay GPL on both platforms; obligations in §5. **Your remaining action:
   pick the app's LICENSE (GPLv3 recommended) and make the repo public before the Phase-3
   release.**
2. **Recorder on exe** (recommended, §3) vs. all-in on DLL.
3. **Pool size default 2** — fine, or expose in Settings?

## 10. Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| ffmpeg-kit fftools patches don't port cleanly to current FFmpeg + mingw | Medium | Phase-0 gate; pin FFmpeg version the patches target; fallback plan named in §7 |
| SEH misses a crash class (fast-fail) → app dies | Low | Accepted residual; recorder (worst risk) stays out-of-process; document |
| Hung native session can't be killed | Low | Watchdog: leak thread + poison + exe fallback |
| Heap corruption *after* a caught SEH fault | Low | Poison switch stops using the DLL immediately |
| GPL shared build missing a needed component | Low | Phase-0 verify ("full" builds carry all of §5's list); custom MSYS2 build script as fallback |
| App ships before repo is public / LICENSE committed → GPL violation | Medium | §5 hard gate blocks Phase 3; release checklist entry in `build_msix_release.ps1` |
| Two backends drift (exe fallback rots) | Low | Fallback shares all arg builders; Phase-4 matrix runs once with DLL force-disabled |
