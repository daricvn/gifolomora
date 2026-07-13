# Bugfix Plan — 2026-07-13 source scan

Findings from full-source bug scan (see conversation for evidence; every item was
confirmed by code reading, none runtime-tested yet). This plan delegates fixes to
`caveman:cavecrew-builder` sub-agents (surgical, 1–2 file scope each), grouped so no
two tasks touch the same file — all tasks in a batch can run in parallel.

> Note: older code comments reference "PLAN.md §3/§4/§8/§9" (the ffmpeg-shim design
> doc that previously lived here). Those sections are gone; do not renumber or
> "fix" those comment references as part of this work.

## Baseline (capture BEFORE any task starts)

- `flutter analyze` → currently **1 issue**: `unused_element` `_active` at
  `lib/core/services/ffmpeg/fallback_ffmpeg_backend.dart:36` (T5 deletes it; target after all tasks: 0).
- `flutter test` → record pass/fail counts + failing test names before starting; re-run after each batch and diff.
- Working tree is already dirty (settings feature + throttle + async tailOnce, uncommitted).
  Tasks below EDIT some of those dirty files — do not revert unrelated hunks.

## Batch 1 — independent builder tasks (parallel)

### T1. Progress parser emits fraction 0 when total unknown
- File: `lib/core/services/ffmpeg/ffmpeg_progress.dart`
- Fix: in `parseProgressLine`, do not call `onProgress` in the `frame=` branch when
  `totalFrames == null || totalFrames <= 0`, and do not call it in the `out_time_ms=`
  branch when `totalMs == null || totalMs <= 0`. Keep parsing otherwise unchanged.
- Why: all video paths pass only `totalMs`; the `frame=` line (first in each ffmpeg
  progress block) emits `fraction: 0`, and the new 100ms throttle in
  `video_studio_controller._onProgress` admits that 0 and drops the real fraction
  arriving microseconds later → progress bar pinned at 0 / bouncing. Mirror bug for
  `imagesToGif` (passes only `totalFrames`).
- Accept: exporting in Video Studio shows monotonically rising progress; images→GIF too.

### T2. Recorder: cap-timer drops finalized recording; double-stop; unhandled segment future; loopback leaks
- Files: `lib/core/services/record/screen_recorder_service.dart`,
  `lib/features/screen_record/controller/record_controller.dart`
- Fixes (all four, one agent):
  1. **stop() single-flight**: guard `stop()` so a second call while
     `finalizing`/already-stopping awaits/returns the first call's future instead of
     running `_finalize()` twice concurrently (hotkey mash, timer+click).
  2. **Cap ownership → controller**: in `RecordController._listenToService`'s existing
     500ms `_elapsedTicker`, when `s.isRecording && _recorder.elapsed.inSeconds >= kMaxRecordSeconds`,
     call `stopRecording()` (idempotent thanks to fix 1). Remove the service's own
     `_capTimer` stop-call path (keep `-t remaining` on the ffmpeg command as hard
     backstop — its rc=0 "unexpected exit" path already routes to recovery via `errors$`).
     This makes the 10-minute cap surface the file (navigation to `/video-studio`)
     instead of silently finalizing into a temp dir that gets wiped on exit.
  3. **Segment future error handler**: `future.then(...)` at the `_engine.execute`
     call site gets an `onError` that logs and routes through the same bookkeeping as
     `_onSegmentExit` (status → idle, error event) so a throw can't leave status stuck
     `recording` + an unhandled async exception.
  4. **Loopback stop**: `discard()` and `cleanupOnShutdown()` must stop system-audio
     loopback (same guard as `_stopCurrentSegment`: `if (_audio.captureSystemAudio && _loopback != null) await _loopback.stop();`)
     before deleting/leaving the job dir.
- Accept: `flutter analyze` clean; existing recorder tests still pass; manual: record
  past pause/discard with system audio on — no wav writer left running.

### T3. VideoPreview: lazy-gif memory spike + small leaks
- File: `lib/features/_shared/widgets/video_preview.dart`
- Fixes:
  1. In `_seekLazyFrame`'s forward-decode `while (_gifLazyCursor <= idx)` loop, evict
     inside the loop (drop and dispose frames `< _gifLazyCursor - _kGifLazyWindow`,
     never disposing `previousShown` or the just-decoded target) so a long forward
     scrub holds at most the window, not cursor→idx frames (multi-GB spike today).
  2. `_openFile` gif branch: cancel `_positionSub`/`_completedSub`/`_playingSub`
     (video branch already does; gif branch leaves stale player events fighting the
     gif ticker after a video→gif source swap).
  3. `_disposeGifFrames`: dispose `_gifLazyShown` when it is not contained in
     `_gifLazyCache` (orphaned by a codec restart) before nulling it.
- Accept: scrub far forward on a large lazy GIF without RAM ballooning (observe via
  Task Manager); no "disposed image" assertions in debug console during swaps.

### T4. DLL backend: final tail pass can no-op; progress-file delete races open handle
- File: `lib/core/services/ffmpeg/ffmpeg_dll_backend.dart`
- Fix: replace the `tailing` bool with an in-flight `Future<void>?`. Timer tick: skip
  if in flight. Final catch-up after `_pool.run` completes: `await` the in-flight
  future if any, then run one guaranteed full pass. In the `finally`, await any
  in-flight pass before `deleteSync` so the delete can't race an open
  `RandomAccessFile` on Windows.
- Accept: exports still stream progress; no `gifolomora_progress_*.txt` left in %TEMP%
  after an export completes.

### T5. Job pool overshoot + fallback watchdog single-slot + dead `_active`
- Files: `lib/core/services/ffmpeg/ffmpeg_job_pool.dart`,
  `lib/core/services/ffmpeg/fallback_ffmpeg_backend.dart`
- Fixes:
  1. Pool: replace the single pre-check with a `while (_running >= maxConcurrent)`
     re-check loop around the waiter await, so a queue-jumping caller can't push
     `_running` past the cap (today: finisher decrements, wakes waiter; new caller
     slips in before the waiter's microtask resumes → 3 concurrent sessions).
  2. Fallback: `_watchdogSignal` single field → `Set<Completer<...>>` of pending run
     signals; `run()` adds/removes its own completer; `cancel()` snapshots and arms
     the watchdog for every pending signal. (Concurrent runs are reachable: WebM batch
     converter + any other tool share the singleton backend, pool cap is 2.)
  3. Delete the unused `_active` getter (the `flutter analyze` warning).
- Accept: `flutter analyze` → 0 issues; a unit test for the pool (3 quick jobs,
  `maxConcurrent: 2`, assert observed concurrency ≤ 2 including the wake race) —
  builder writes one small test file if none exists for the pool.

### T6. FfmpegService.videoToGif bookkeeping + images→GIF pipeline dir orphans
- Files: `lib/core/services/ffmpeg/ffmpeg_service.dart`,
  `lib/features/images_to_gif/controller/images_to_gif_controller.dart`
- Fixes:
  1. `videoToGif`: set `_currentJobDir = jobDir` after `createJobDir()` and clean the
     dir + null the slot in the catch, matching every sibling method (currently no
     callers, but the trap is 2 lines from biting the next caller).
  2. `images_to_gif_controller.generate()`: after step 2 (`textOverlay`) succeeds,
     `cleanJobAt(previousGif.parent.path)` for the step-1 dir (holds the BMP copies of
     every frame — the big one); after step 3 (`optimizeGif`) succeeds, same for the
     step-2 dir. Mirror the `priorDir` pattern in
     `video_studio_controller._runGifPipeline`. Never clean the dir of the file that
     ends up in `outputGif`.
- Accept: after a generate with text+optimize enabled, exactly one
  `gifolomora_jobs/<id>` dir remains for that flow (the one holding `outputGif`).

### T7. Small leaks: optimizer ReceivePort, job-dir id collision
- Files: `lib/core/services/gif_optimizer.dart`,
  `lib/core/services/files/temp_file_service.dart`
- Fixes:
  1. `gif_optimizer.dart optimize()`: move `progressSub?.cancel()` + `progressPort?.close()`
     into a `finally` so an isolate throw can't leak the port.
  2. `temp_file_service.dart createJobDir()`: make ids collision-proof — append a
     static monotonically increasing counter to the microsecond id
     (`'${micros}_${_seq++}'`) so two same-microsecond calls can't share a dir.
- Accept: `flutter analyze` clean; two rapid job creations get distinct dirs.

### T7b. makeWebm error path leaks pipeline temp
- File: `lib/features/video_studio/controller/video_studio_controller.dart`
- Fix: `makeWebm()` err fold: free the pipeline temp (`workingDir`) when it is not
  history-owned (`workingFile.path != s.sourceFile!.path`) before returning false.
  (Own task: builder caps at 2 files, and this file also carries unrelated
  uncommitted work — smallest possible diff.)
- Accept: failed WebM conversion leaves no extra `gifolomora_jobs/<id>` dir behind.

## Deferred (not in this plan)

- **Concat-list `\'` escaping vs apostrophe in %TEMP% path** (`ffmpeg_command.dart:715`,
  `:761`): correctness depends on av_get_token unescape semantics — needs a runtime
  test with a quote-bearing path before touching. Do not "fix" blind.
- **`copyFrames` sync image decode on UI isolate** (`temp_file_service.dart:52`):
  perf refactor (move to `Isolate.run`), separate change with its own verification.
- **Exit log unbounded append** (`app.dart`): diagnostic file, intentionally simple.

## Batch 2 — gate + review (after ALL Batch-1 tasks land)

1. `flutter analyze` → must be **0 issues** (baseline was 1; T5 removes it).
2. `flutter test` → diff against baseline counts; any new failure = the task that
   caused it gets reverted and re-done, not patched forward.
3. `caveman:cavecrew-reviewer` on the full diff (`git diff` of every touched file) —
   one severity-tagged line per finding; fix CRITICAL/HIGH before proceeding.
4. Manual smoke (user, on device): one Video Studio export (progress bar rises), one
   images→GIF with text+optimize, one screen-record → pause → discard with system
   audio, one 10-minute-cap recording if patience allows (or temporarily lower
   `kMaxRecordSeconds` locally to test the cap path — revert before commit).

## Rules for every builder task

- Touch ONLY the files named in the task. The tree carries unrelated uncommitted work
  (settings feature, pubspec bump) — leave it.
- No new dependencies. No refactors beyond the named fix. Match surrounding style.
- Each task's prompt includes the finding's file:line evidence from the scan.
- Report back: diff summary + `flutter analyze` result for the touched files.

## Rollback

Everything is working-tree-only until the user commits. Per-task rollback:
`git checkout -- <file>` for that task's files (careful: `ffmpeg_dll_backend.dart` and
`video_studio_controller.dart` ALSO carry pre-existing uncommitted work — revert via
targeted edit, not file checkout, for those two).
