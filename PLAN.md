# PLAN — Screen Record (Windows)

> Record the entire screen (up to 10 minutes) into a temp video, with optional system/mic
> audio, global hotkeys, monitor selection, and an on-screen pulsing "Recording" indicator.
> **Windows only.** On stop, the recording opens in Video Studio, pre-selected.

---

## 1. Summary

Add a **Screen Record** tool. The user picks a monitor (picker when more than one monitor;
read-only card when there is only one), toggles system-audio / mic capture (persisted across
sessions), and presses Record (or a global hotkey). ffmpeg's `gdigrab` device — already
bundled on Windows — captures the full monitor; mic audio joins the same ffmpeg process via
`dshow`; system audio is captured by a small WASAPI-loopback module in the native runner and
muxed in at finalize. While recording, the app window morphs into a tiny always-on-top
overlay showing a pulsing red dot + "Recording" text and elapsed time. Stop (button or
hotkey) finalizes the file and **switches to Video Studio with the recorded video selected**,
where the existing trim/crop/text/GIF-bake/export flow takes over.

**Key reuse:** bundled `ffmpeg.exe` + `FfmpegProcessBackend.resolveBin`, `TempFileService`
job dirs, `FfmpegCommand` for arg building, `window_manager` (already a dependency) for the
overlay morph, Video Studio as the post-record editor (no new preview/export UI needed).

---

## 2. Scope & locked decisions

| Decision | Choice | Rationale |
|---|---|---|
| Capture engine | ffmpeg `gdigrab` (bundled binary) | Zero new native code for video; works on every Windows version; cursor captured via `draw_mouse=1`. |
| Recording format | H.264 `.mkv` segments → remux to `.mp4` on stop | MKV is crash-safe (no moov atom to lose); remux is a stream-copy, near-instant. |
| Pause | Segment-per-resume, concat on stop | ffmpeg has no pause; stop segment + start new one is the standard approach. Concat demuxer with `-c copy` joins losslessly. |
| Max duration | 600 s of *recorded* time (pauses excluded), enforced in service + `-t` per segment as belt-and-braces | Requirement. |
| Frame rate | 30 fps fixed (v1) | Good default for GIF-destined capture; option chip can come later. |
| Mic audio | Optional toggle; captured via `dshow` input in the **same** ffmpeg process | In-process mux → no sync work. Default **off**. |
| System audio | Optional toggle; native WASAPI-loopback module (C++ in runner) writes WAV per segment, muxed at finalize | ffmpeg has no native WASAPI/loopback input on Windows; the dshow route needs a third-party filter install (non-starter for MSIX). Default **off**. |
| Audio toggles persistence | `shared_preferences` via `RecordSettingsService`, saved across sessions | Requirement. |
| Storage | `TempFileService.createJobDir()` — same temp root as every other job | Requirement ("temporary folder") + existing sweep semantics. |
| After stop | **Switch to Video Studio with the recorded video selected** | Requirement. Route gains `extra: File`; studio controller runs its normal "file picked" path on arrival. |
| Monitor picker | **> 1 monitor** → selectable list; exactly 1 → same card rendered read-only | Confirmed. |
| Hotkey scope | Global hotkeys registered **only while on the home screen or the Screen Record screen** (and during recording) | Confirmed ("main screen or recording screen only"). Never held app-wide from other tools. |
| Encoder | `libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p` (+ `-c:a aac` when mic on) | Real-time-safe on any CPU at 1080p/1440p 30 fps. HW encoders are a later optimization — capture must never drop frames because an HW encoder is missing. |
| Platform gating | Tool card hidden off-Windows; route guarded | Requirement. |

---

## 3. UX flows

### 3.1 Recording screen (`/screen-record`)

Follows the house 4-step skeleton, adapted (no file pick — the "input" is a monitor):

```
[1 Monitor] → [2 Options] → [3 Record] → (overlay) → [4 Video Studio, file selected]
```

- **Monitor card** — one glass card per display: monitor name/index, resolution, primary
  badge, and a proportional mini-rectangle sketch of the virtual desktop layout with the
  selected monitor highlighted. Single monitor: same card, selection disabled (read-only).
- **Audio card** — two glass switches: **System audio** and **Microphone**. Values load
  from and save to `RecordSettingsService` immediately on toggle (persist across sessions).
  Mic row shows the default input device name; system-audio row shows the default output
  device name. If no mic device exists, the mic switch is disabled with a hint.
- **Hotkey strip** — read-only chips showing the current start/pause/stop hotkeys with an
  "edit" affordance opening the hotkey recorder fields.
- **Record button** — big primary `GlassButton`. Disabled states: already recording,
  monitor enumeration failed.
- **Duration note** — "Max 10:00" caption.

### 3.2 While recording — the overlay

On start, the **main window itself** morphs into the indicator (no second window — Flutter
desktop is single-window; `desktop_multi_window` is avoidable complexity):

1. Save current window bounds.
2. Resize to a small pill (~200×56), frameless (title bar already hidden app-wide),
   `setAlwaysOnTop(true)`, positioned top-right of the **selected** monitor with a margin.
3. Set `WDA_EXCLUDEFROMCAPTURE` on the window (MethodChannel into the existing Win32
   runner) so the indicator does **not** appear in the recording (Win10 2004+; older
   builds: it simply appears — acceptable degradation).
4. Overlay contents: red dot + "Recording" label, both driven by one
   `AnimationController(repeat: reverse)` fading opacity 0.35 → 1.0 over ~1.2 s
   (the required slow fade-in/fade-out pulse), plus elapsed `mm:ss / 10:00`, small
   mic/speaker icons when the respective audio capture is on, and pause/resume + stop
   icon buttons.
5. Paused state: pulse stops, dot turns amber, label "Paused".

On stop: restore saved bounds, clear always-on-top + capture-exclusion, then
`context.go('/video-studio', extra: recordedFile)` — Video Studio opens with the recording
already selected as its input, same as if the user had dropped the file in.

The overlay keeps its buttons clickable (drag-to-move via `DragToMoveArea`), so the mouse
is a first-class way to pause/stop — hotkeys are the hands-off path, not the only path.

### 3.3 Hotkeys

- Three configurable **global** hotkeys (work while the app is an overlay or unfocused):
  **Start** (default `Alt+Shift+R`), **Pause/Resume** (`Alt+Shift+P`), **Stop** (`Alt+Shift+S`).
  Defaults avoid `Ctrl+Shift+R`-style combos that browsers/IDEs rely on, since a global
  hotkey steals the combo system-wide while registered.
- **Scope (confirmed):** registered while the **home screen** or the **Screen Record
  screen** is active, and for the whole duration of a live recording; unregistered
  everywhere else. Start pressed on the home screen → navigate to `/screen-record` and
  immediately begin recording with the saved monitor selection (fallback: primary) and
  saved audio toggles.
- Capture UI: "press keys to assign" recorder chip; conflict check between the three;
  registration failure (combo taken by another app) surfaces an `AppToast` and reverts.
- Persisted in `RecordSettingsService` (see §4.6).

---

## 4. Technical design

### 4.1 Capture command (`FfmpegCommand.screenCapture`)

Video only:

```
ffmpeg -f gdigrab -framerate 30 -offset_x <X> -offset_y <Y> -video_size <W>x<H>
       -draw_mouse 1 -i desktop
       -c:v libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p
       -t <remaining_seconds> <jobDir>/seg_000.mkv
```

With mic enabled, a second input joins the same process (in-process mux, no sync step):

```
       -f dshow -i audio="<mic device name>" -c:a aac -b:a 160k
```

- `offset_x/offset_y/video_size` select one monitor out of the virtual desktop
  (negative offsets valid for monitors left/above primary).
- `W`/`H` clamped **down to even** — `yuv420p` requires even dimensions.
- `-t` = `600 − alreadyRecordedSeconds` so even a hung Dart timer can't exceed the cap.
- Mic device name discovered via `ffmpeg -list_devices true -f dshow -i dummy`
  (stderr parse, cached per session).
- Concat on stop: `ffmpeg -f concat -safe 0 -i list.txt -c copy output.mp4`
  (single segment still gets remuxed mkv→mp4 — same code path, stream-copy, instant).

### 4.2 System audio — WASAPI loopback (native module)

ffmpeg on Windows cannot capture system output audio by itself: there is no WASAPI input
device, and the usual dshow answer (`virtual-audio-capturer`) is a third-party DirectShow
filter requiring system-wide registration — unacceptable inside an MSIX app. "Stereo Mix"
is disabled or absent on most machines. So:

- **`windows/runner/audio_loopback.cpp/.h`** (~200 lines): WASAPI loopback capture of the
  default render device (`IAudioClient` with `AUDCLNT_STREAMFLAGS_LOOPBACK`), writing
  48 kHz float WAV to a given path. Exposed over the same `gifolomora/native_window`
  MethodChannel: `startLoopback(path)`, `stopLoopback()` → returns actual captured
  duration in ms.
- **Segment-aligned:** the service starts/stops the loopback WAV in lockstep with each
  video segment (`seg_000.wav` beside `seg_000.mkv`), so pause/resume needs no audio
  surgery — WAVs concat with the same list mechanism (`-f concat` on wav, or a single
  `amix`-free `concat` filter at finalize).
- **Finalize mux:** `ffmpeg -i video.mp4 -i sys.wav [-filter_complex amix] -c:v copy -c:a aac out.mp4`.
  With mic **and** system audio enabled, mic (already inside the mkv) and the loopback WAV
  are mixed with `amix=inputs=2` at finalize; video stream stays `-c copy` throughout.
- **Sync:** loopback start and ffmpeg's first captured frame won't align perfectly
  (process spawn vs. native call latency, tens of ms). The service timestamps both starts
  and applies the delta via `-itsoffset` at mux time. Good enough for screen capture;
  flagged as the item to verify hardest in phase 4.
- **Silence handling:** WASAPI loopback delivers no packets while the system plays nothing;
  the writer must insert silence for the gaps (standard loopback chore, handled in the
  module) or the WAV drifts short.

### 4.3 `ScreenRecorderService` — `lib/core/services/record/screen_recorder_service.dart`

Owns the ffmpeg `Process` directly. It does **not** go through `FfmpegBackend.run()`:
that API is job-shaped (run → progress → Result<File>), while recording is open-ended and
stdin-controlled. It reuses `FfmpegProcessBackend.resolveBin('ffmpeg')` for the binary path.

```dart
enum RecordStatus { idle, recording, paused, finalizing }

class ScreenRecorderService {
  Future<void> start(RecordTarget monitor, RecordAudio audio); // job dir + segment 0 (+ loopback wav)
  Future<void> pause();    // graceful-stop current segment (+ loopback stop)
  Future<void> resume();   // spawns next segment (seg_001.*)
  Future<File>  stop();    // graceful-stop, concat + audio mux → output.mp4
  Future<void> discard();  // kill + cleanJob

  Duration get elapsed;    // sum of finished segment durations + live segment stopwatch
  Stream<RecordStatus> get status$;
}
```

- **Graceful stop:** write `q\n` to the process stdin, await exit (5 s timeout), then
  `Process.kill()` fallback. `q` makes ffmpeg finalize the container properly; MKV means
  even a hard kill leaves a playable file.
- **10-minute cap:** 500 ms tick; when `elapsed >= 600s`, auto-`stop()`. The overlay
  reflects this as a normal stop (navigates to Video Studio).
- **Elapsed accounting:** stopwatch per live segment + accumulated total; pauses add nothing.
- **Failure surface:** ffmpeg exiting non-zero mid-segment (disk full, gdigrab error)
  flips status to `idle` with an error the controller shows via `AppToast`; finished
  earlier segments are still concat-able, so a partial recording is offered, not lost.
- Job dir is cleaned by the existing flow: Video Studio's temp-ownership +
  `sweepStale()` on next launch. `discard()` cleans immediately.

### 4.4 Monitor enumeration — `screen_retriever` (new dep)

- `screenRetriever.getAllDisplays()` → id, name, position, size, scaleFactor.
- **DPI trap:** `screen_retriever` reports *logical* coordinates; `gdigrab` wants *physical*
  pixels. Convert: `physical = logical × scaleFactor` for offset and size. The Flutter
  Windows runner is per-monitor-DPI-aware, so scale factors are per-display and must be
  applied per-display. This is the most likely source of "recorded the wrong region" bugs —
  unit-test the mapping (`RecordTarget.fromDisplay`) with mixed-DPI fixtures.
- `RecordTarget` model: `{displayId, label, physicalX, physicalY, physicalW, physicalH, isPrimary}`.

### 4.5 Overlay & capture exclusion

- Window morph via existing `window_manager`: `getBounds`/`setBounds`, `setAlwaysOnTop`,
  `setResizable(false)` during overlay; all restored on stop (wrapped in `try/finally` so a
  recorder crash never strands the user in a 200×56 window).
- MethodChannel `gifolomora/native_window` in `windows/runner/flutter_window.cpp`:
  `setExcludeFromCapture(bool)` → `SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE | WDA_NONE)`
  (~20 lines), plus the `startLoopback`/`stopLoopback` methods from §4.2. Exclusion failure
  (pre-2004 Windows) is non-fatal: indicator just shows up in the recording.
- Overlay route `/recording-overlay` (no transition, no `GradientScaffold` — it must be a
  tiny legible pill, not a glass art piece; solid dark rounded container, 1 blur max).

### 4.6 Settings & controller

**`RecordSettingsService`** (`lib/core/services/record/record_settings_service.dart`) —
`shared_preferences`-backed, mirroring `RecentsService`'s self-persistence pattern
(`lib/core/services/settings/` is currently empty; ARCHITECTURE.md describes a
`SettingsService` that hasn't been built — not blocking on it):

```dart
class RecordSettings {
  final bool captureSystemAudio;   // persisted, default false
  final bool captureMic;           // persisted, default false
  final RecordHotkeys hotkeys;     // three modifier+key pairs, persisted
  final String? lastDisplayId;     // persisted — used by home-screen hotkey start
}
```

**`RecordController extends AsyncNotifier<RecordState>`**
(`lib/features/screen_record/controller/record_controller.dart`) per house pattern:

```dart
class RecordState {
  final List<RecordTarget> monitors;
  final RecordTarget? selected;
  final RecordStatus status;
  final Duration elapsed;          // ticked for overlay + cap display
  final RecordSettings settings;
  final String? error;
}
```

Orchestrates: enumeration on build, settings load/save, service start/pause/resume/stop,
window morph calls, hotkey (un)registration, and the final Video Studio handoff.

**`HotkeyService`** (`lib/core/services/record/hotkey_service.dart`) — wraps
`hotkey_manager`; register/unregister the three `HotKey`s; Windows-guarded. Home screen and
Screen Record screen both mount/unmount registration (via the controller), per the confirmed
scope.

### 4.7 Video Studio handoff (requirement)

After `stop()` finalizes `output.mp4`, the app **switches to Video Studio with the recording
selected**: `/video-studio` route gains an optional `extra: File`; on arrival the studio
controller runs its existing "file picked" initialization with that file (probe, preview,
`EditStage.video`). One small change in `app_router.dart` + the studio controller's init —
also useful later for "open recent in studio". Temp ownership transfers to the normal studio
flow; the recording job dir is cleaned like any picked-file job.

### 4.8 Platform gating

- `ToolEntry` gains `windowsOnly: bool` (default false); `createTools` getter filters on
  `Platform.isWindows`. Screen Record joins the **create** category (it's a source entry
  point → featured card).
- All record services/providers constructed lazily by the screen — nothing recording-related
  runs at bootstrap on any platform.

---

## 5. Files

**New**
```
lib/core/services/record/screen_recorder_service.dart   # process/segment state machine
lib/core/services/record/record_target.dart             # monitor model + DPI mapping
lib/core/services/record/record_settings_service.dart   # audio toggles + hotkeys + last monitor (shared_preferences)
lib/core/services/record/hotkey_service.dart            # global hotkey registration
lib/features/screen_record/controller/record_controller.dart
lib/features/screen_record/view/screen_record_screen.dart
lib/features/screen_record/view/recording_overlay.dart  # pulsing pill
lib/features/screen_record/widgets/monitor_card.dart
lib/features/screen_record/widgets/audio_options_card.dart
lib/features/screen_record/widgets/hotkey_recorder_field.dart
windows/runner/audio_loopback.cpp / .h                  # WASAPI loopback → WAV
test/screen_recorder_service_test.dart                  # segment/elapsed/cap math
test/record_target_test.dart                            # DPI + even-dimension mapping
test/ffmpeg_capture_command_test.dart                   # arg-list golden tests (video / +mic / mux / concat)
test/record_settings_service_test.dart                  # persistence round-trip
```

**Modified**
```
pubspec.yaml                          # + screen_retriever, hotkey_manager
lib/core/services/ffmpeg/ffmpeg_command.dart   # screenCapture(), concatSegments(), muxAudio()
lib/core/services/providers.dart      # recorder/settings/hotkey providers
lib/features/home/data/tool_catalog.dart       # entry + windowsOnly gating
lib/features/home/view/…              # hotkey registration while home is active
lib/router/app_router.dart            # /screen-record, /recording-overlay, studio `extra`
lib/features/video_studio/controller/…         # accept initial file
windows/runner/flutter_window.cpp (+.h, CMakeLists)  # native_window channel: capture-exclusion + loopback
ARCHITECTURE.md                       # recorder section once built
```

**New dependencies** (both leanflutter, same org as `window_manager`):
- `screen_retriever ^0.2.0` — display enumeration
- `hotkey_manager ^0.2.3` — global hotkeys (Windows)

---

## 6. Implementation phases

1. **Capture core** — `FfmpegCommand.screenCapture`/`concatSegments`, `RecordTarget` DPI
   mapping, `ScreenRecorderService` with start/stop only (video, no audio). Tests for arg
   lists, even-dim clamp, cap math. Manual check: record primary monitor 10 s, file plays.
2. **Recording screen** — route, tool card (gated), monitor enumeration + picker/read-only
   card, record/stop buttons, elapsed display. Recording works end-to-end from UI.
3. **Overlay** — window morph + restore, pulsing indicator, `native_window` channel with
   `WDA_EXCLUDEFROMCAPTURE`, stop/pause buttons on the pill. Pause/resume segmenting +
   concat finalize.
4. **Audio** — `RecordSettingsService` + audio toggles UI (persisted); mic via dshow
   (device discovery + arg wiring); WASAPI loopback module + segment-aligned WAV +
   finalize mux/`amix`; sync verification (`-itsoffset` delta). Riskiest phase — budgeted
   accordingly.
5. **Hotkeys** — `HotkeyService`, defaults, recorder UI, persistence, lifecycle
   (home + record screens + live recording; home-screen start uses saved monitor/audio).
6. **Handoff + polish** — Video Studio `extra` file selection, 10-min auto-stop UX, error
   toasts, `flutter analyze` clean, ARCHITECTURE.md update.

Each phase ships working. Phases 1–2 retire the gdigrab/DPI risk; phase 4 retires the
audio risk and can degrade gracefully (mic-only) if loopback proves flaky.

---

## 7. Improvements added beyond the request

- **Capture-exclusion of the indicator** (`WDA_EXCLUDEFROMCAPTURE`) — the required pulsing
  overlay would otherwise be burned into every recording made on that monitor.
- **Clickable overlay** (pause/stop buttons + drag) — hotkeys shouldn't be the only way out.
- **Crash-safe segments** (MKV) — a crash at minute 9 loses seconds, not the recording.
- **Scoped hotkey registration** — global combos held only where confirmed (home + record
  screens + live recording), never app-wide from other tools.
- **Partial-recording rescue** — encoder dying mid-run still offers the completed segments.
- **Last-used monitor remembered** — makes the home-screen start hotkey deterministic.

## 8. Open questions & concerns

1. **System-audio risk (biggest item)** — WASAPI loopback module is the one genuinely new
   native component. Sync (`-itsoffset` delta) and silence-gap insertion are the two known
   chores; both are well-trodden but need real-hardware verification. Fallback if it
   misbehaves: ship v1 with mic-only audio and a disabled system-audio switch ("coming
   soon"), since the video pipeline doesn't depend on it.
2. **Mic device selection** — v1 uses the system default input device (name shown on the
   toggle row). A device dropdown is a cheap follow-up if users ask.
3. **Audio in GIF exports** — audio is only meaningful for Video Studio's *video* export;
   the GIF path discards it (already how the studio works — no change needed).
4. **Crash recovery** — segments from a crashed session live in temp for ≤ 1 h
   (`sweepStale`). A "recover last recording?" prompt on next launch is a cheap follow-up;
   skipped in v1.
5. **`ddagrab`/hardware encoders** — Desktop Duplication capture + HW encode would cut CPU
   use markedly, but depends on the bundled ffmpeg build and GPU; gdigrab+x264-ultrafast is
   the always-works baseline. Revisit only if capture at 1440p+ measurably stutters.
6. **Disk** — 10 min of 1440p30 ultrafast H.264 ≈ 1–2 GB in temp. No guard in v1 beyond
   surfacing the ffmpeg "disk full" failure; a free-space preflight check is a candidate
   for phase 6.
7. **ARCHITECTURE.md drift** — it documents `SettingsService`/settings screen that don't
   exist in `lib/` (empty dirs). This plan doesn't depend on them (§4.6), but the doc
   should be corrected regardless.
