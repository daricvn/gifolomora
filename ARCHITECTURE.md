# Gifolomora — Architecture

> Cross-platform glassmorphism GIF editor & maker.
> **Targets:** Android + Windows desktop (Linux fallback Phase 5).
> **Stack:** Flutter · Riverpod (manual providers, no codegen) · go_router · custom glass widgets · dual-backend FFmpeg · media_kit · window_manager.

---

## Startup chain

```
main.dart → bootstrap.dart → ProviderScope → GifolomoraApp (MaterialApp.router)
```

`bootstrap.dart` performs, in order:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `MediaKit.ensureInitialized()` — required before any `Player` (video preview)
3. **Windows only:** `windowManager.ensureInitialized()` + hidden native title bar
   (`TitleBarStyle.hidden`, 1280×720, min 800×560) so the custom glass title bar can render
4. `TempFileService().sweepStale()` — clears leftover job dirs from previous runs
5. `runApp(ProviderScope(child: GifolomoraApp()))`

---

## Layer structure

```
lib/
  main.dart
  app/
    app.dart        # MaterialApp.router + theme binding
    bootstrap.dart  # binding + MediaKit + window_manager + temp sweep + ProviderScope
  router/
    app_router.dart # GoRouter, all routes + fade/slide page transitions
  core/
    theme/          # AppColors, AppGradients, AppTheme — dark only, no light variant
    widgets/
      glass/        # GlassContainer (BackdropFilter primitive) → GlassCard/Button/AppBar
      common/       # GradientScaffold (animated blob bg), ProgressOverlay, SectionHeader,
                    # EmptyState, AppToast (snackbar helper), Entrance (one-shot fade+slide-up,
                    # staggers home sections on first build)
    services/
      ffmpeg/       # backend interface + 2 impls + factory + service + command/progress/encoder models
                    # + DrawTextSpec model (absolute-px text layer for multi-item overlay)
      gif/          # GifLzw — variable-width LZW encoder used by GifOptimizer
      gif_optimizer.dart  # pure-Dart GIF optimizer — no gifsicle; works on all platforms
      files/        # TempFileService, ExportService, MediaProbeService
      permissions/  # PermissionService (Android scoped storage)
      settings/     # SettingsService + AppSettings (shared_preferences)
      recents/      # RecentsService + RecentExport (last 10 exports, shared_preferences)
      providers.dart# all Riverpod providers (manual) + SettingsNotifier + RecentsNotifier
    utils/          # Result<T,E>, logger, FontResolver (system font paths for drawtext), FontRegistry (bundled custom fonts)
  features/
    home/           # view/ + widgets/ (HomeHero, FeaturedToolCard, ToolCard, RecentsStrip)
                    # + data/tool_catalog.dart (drives the grid)
    _shared/
      widgets/      # FileDropZone, MediaPreview, OptionSlider, ExportBottomSheet,
                    # TextOverlayControls (TextFormatCard, TextLayersPanel, showTextColorWheel —
                    #   shared between Text Overlay screen and Video Studio)
    <tool>/         # view/ + controller/ (+ widgets/) per tool — 7 tools (Video Studio owns widgets/video_trim_slider.dart)
    about/          # static about screen
    settings/       # default-quality sliders + clear-history
```

> **No `_shared/controller/process_controller.dart`.** Earlier plans called for a shared
> `ProcessController` base; it was never built. Each tool controller extends
> `AsyncNotifier<XxxState>` directly with its own immutable state class (`copyWith` + sentinel
> for nullable fields).

---

## Dual-backend FFmpeg (critical constraint)

`ffmpeg_kit_flutter` (Arthenica) was retired April 2025 and never supported desktop.
Windows is now **all-in on an in-process DLL** — no `ffmpeg.exe` anywhere (PLAN.md §9 decision #2,
revisited). `FfmpegProcessBackend` still exists as source but is unreachable on Windows unless
`gm_shim.dll` fails to load at startup (a dev-machine-without-the-DLL-built situation).

| Platform | Backend | Notes |
|---|---|---|
| Android / iOS | `ffmpeg_kit_flutter_new` community fork (4.2.1) | `FFmpegKit` + statistics callback |
| Windows | `FfmpegDllBackend` — `gm_shim.dll` via `dart:ffi` | in-process, no subprocess at all |
| Linux (Phase 5, unbuilt) | `dart:io Process` + bundled binaries | parse `-progress pipe:1` `out_time_ms` |

```
FfmpegBackend (abstract interface)
  ├── FfmpegKitBackend       → Android/iOS
  ├── FfmpegDllBackend       → Windows (gm_shim.dll, dart:ffi)
  └── FfmpegProcessBackend   → Linux / Windows dev-fallback only
FfmpegFactory.create()  picks impl at runtime via Platform.*
VideoEncoder            → platformCandidates() returns ordered hw+sw encoder list for editVideo fallback
FfmpegService           → high-level API; receives backend + temp
```

### gm_shim.dll (Windows in-process FFmpeg)

`windows/ffmpeg_shim/` — a C shim wrapping vendored, patched FFmpeg `fftools` sources
(from the abandoned ffmpeg-kit project) into one DLL, built by `scripts/build_ffmpeg_shim.ps1`
against MSYS2's clang toolchain (GCC hit a codegen bug — `operand type mismatch for 'shr'` — across
many unrelated files; clang builds clean). GPLv3 build (`--enable-gpl --enable-version3
--enable-libx264 --enable-libvpx --enable-libaom --enable-libopus --enable-libfreetype
--enable-zlib --enable-avdevice --enable-ffmpeg`); see `assets/licenses/` + the About screen for
attribution/license text copied verbatim from FFmpeg's own source tree.

> **Build-config gaps bite silently, not loudly.** The underlying FFmpeg core (not `gm_shim.c`
> itself) is configured with a minimal, hand-picked `--enable-*` list rather than a "full" build,
> so a codec/filter/library nobody thought to enable simply isn't there — `gm_execute` still
> returns a clean `rc` either way, so this looks identical to an app-level bug until you capture
> the real FFmpeg log (`-report`, not the 8KB `gm_get_logs` buffer — see below) and read the exact
> error text. Two hit in production so far, both root-caused this way: (1) no `zlib` → no `png`
> encoder → `videoEditToGif`'s palette-bake pass (which writes a real `palette.png` file) failed
> every video→GIF edit-bake with rc=1 ("Automatic encoder selection failed"); first worked around
> at the Dart level by writing the intermediate as `.bmp` instead, later fixed properly by
> rebuilding with `--enable-zlib` (now in the flags above) and reverting `ffmpeg_command.dart`'s
> `videoEditToGif` back to the `palette.png` intermediate. (2) no `libfreetype` → no `drawtext`
> filter → *every* text-overlay job (GIF or
> video, any encoder candidate) failed with "No such filter: 'drawtext'"; unlike (1) there's no
> app-level workaround — text overlay needs the filter compiled in — so this one required rebuilding
> FFmpeg with `--enable-libfreetype` and relinking `gm_shim.dll` (now reflected in the flags above).
> `gm_shim.c`'s own log callback also ignores `av_log`'s level parameter, so a verbose demuxer (e.g.
> MOV atom trace) can fill the 8KB capture buffer before a real error line is ever written — another
> reason `-report`'s unbounded file, not `FfmpegError.stderr`, is the reliable way to diagnose a
> new rc=1. See PLAN.md §6 for the full incident writeup and the regression tests it named.

- **C ABI** (`gm_shim.h`): `gm_execute(session_id, argv)`, `gm_cancel(session_id)`, `gm_probe`,
  `gm_supports_encoder`, `gm_get_logs`. Sessions are identified by a caller-allocated id
  (`GmSessionIds`, a global counter in `gm_shim_ffi.dart` shared by every consumer — exports and
  the screen recorder both draw from it, so ids never collide between a concurrent export job and
  a recording segment).
- **Crash safety:** `AddVectoredExceptionHandler` + per-thread `longjmp` (not MSVC `__try/__except`
  — mingw GCC lacks it, and clang wasn't switched to it since VEH was already proven). A crashed
  session returns `rc = GM_ERR_CRASH (-1000)`, exposed as `gmCrashExitCode` in Dart; the caller gets
  a clean `Err(FfmpegError)` instead of taking the whole app down.
- **Cancellation:** `gm_cancel()` sets a per-session flag; fftools' own loop notices it and exits
  with `rc = 255` (its own cancellation sentinel, not `0` — confirmed against the real DLL). Dart
  side: `gmCancelledExitCode = 255`, handled explicitly in `FfmpegDllBackend.run()` for UX parity
  with the old process backend's cancel behavior.
- **Progress:** no OS pipe in-process, so `-progress pipe:1` args are rewritten to a temp file path
  and tailed by a 150ms `Timer.periodic` (`FfmpegDllBackend._rewriteProgressArg`/`tailOnce`) instead
  of parsing subprocess stdout.
- **Concurrency:** `FfmpegJobPool` (semaphore, default `maxConcurrent: 2`) throttles concurrent
  `gm_execute` calls; each call runs via `Isolate.run` so a blocking native call never stalls the
  Dart UI isolate.
- **Dart FFI layer:** `lib/core/services/ffmpeg/gm_shim_ffi.dart` — shared bindings (`GmShim` class,
  `GmExecResult`, isolate-run helpers) used by both `FfmpegDllBackend` and the screen recorder's
  `GmShimRecorderEngine`.
- **No exe fallback at runtime:** `FfmpegDllBackend.tryResolvePath()` looks for `gm_shim.dll` next
  to `Platform.resolvedExecutable`; if missing/unloadable, `FfmpegFactory` falls through to
  `FfmpegProcessBackend` (which then needs `ffmpeg.exe`/`ffprobe.exe` that no longer ship — this
  path exists for source-level platform coverage, not a supported Windows runtime state).

### Backend interface

```dart
abstract interface class FfmpegBackend {
  Future<Result<File, FfmpegError>> run(
    List<String> args,
    String outputPath, {
    void Function(FfmpegProgress)? onProgress,
    int? totalFrames,   // images→gif: frames done / total
    int? totalMs,       // video/gif jobs: out_time_ms vs known total
  });
  Future<MediaInfo?> probe(String inputPath);
  Future<void> cancel();
  void dispose();
}
```

`FfmpegCommand` builds all arg lists / filter graphs. `FfmpegProgress` is the progress model.

**GIF-source commands:** `imagesToGif`, `videoToGif`, `resize`, `cropGif`, `textOverlay`,
`textOverlayMulti`, `reverseGif`, `changeSpeed` — single-purpose ops retained for non-Studio tools.
`textOverlayMulti` accepts `List<DrawTextSpec>` (absolute px coords, per-item color/stroke) and
chains multiple `drawtext` segments; used by the Text Overlay tool's multi-layer export and by
Video Studio's GIF pipeline.

**Composite commands (Video Studio):**
- `videoEdit` — crop · resize · speed · trim · text · audio in one pass; selects encoder from `VideoEncoder.platformCandidates()`. Accepts `List<DrawTextSpec>? textSpecs` (multi-layer, positioned before crop/scale so text transforms with content).
- `videoStreamCopy` — no-op fast path: stream-copy when no edits.
- `videoEditToGif` — bakes video layers (crop · fps · resize · speed · cut) → GIF in two passes (palette pass → render pass) sharing one filter chain; two passes stream instead of FIFO-buffering every frame in RAM like a one-pass split graph. Palette pass writes its intermediate as `.bmp` with an explicit `-c:v bmp`, not `.png` — our FFmpeg build has no `zlib`/png encoder (see the build-config-gaps note above). `-ss`/`-t` are input options; with cuts, `-t` = last keep-range end so decode stops there instead of source EOF.
- `gifEdit` — applies crop · fps · resize · speed · text · trim · loop · boomerang to an existing GIF; `boomerang` appends a reversed stream via `concat=n=2` for ping-pong. `startMs`/`durationMs` emit `-ss`/`-t` as **input** options (before `-i`) — placed after `-i` they'd bind to the output and truncate the write instead of the read, silently chopping boomerang's reversed half.
- `buildConcatFileContent` — generates concat demuxer file listing frames at a given fps.

### Text overlay models

`DrawTextSpec` (in `ffmpeg_command.dart`) — absolute-pixel text layer passed to `textOverlayMulti`
and `videoEdit`. Fields: `text`, `fontFile`, `x`, `y`, `fontSize`, `fontColorHex` (RRGGBB),
`strokeColorHex` (RRGGBB), `strokeWidth` (0 = none). Built from `TextItem` via
`FfmpegService._specsFromItems(items, mediaInfo)`.

`TextItem` (in `features/text_overlay/model/text_item.dart`) — UI layer model. Stores normalized
position (`nx`/`ny` in [0,1)), `fontSize` (media px), hex colors, `strokeWidth`, `TextStyleKind`.
Shared by the Text Overlay tool and Video Studio. Static helpers convert between normalized/pixel/
display-scale spaces.

`TextStyleKind` enum: `regular | bold | italic | boldItalic` — drives `FontResolver.fileForStyle()`
and the Flutter `FontLoader` preview registration.

`TextFont` enum: `system | dancingScript | sourceCodePro | lobsterTwo | caveat` — per-layer typeface.
`system` uses `FontResolver` (platform fonts); the rest are bundled `assets/fonts/` (Regular+Bold)
managed by `FontRegistry.ensureLoaded()`, which materializes each to the app-support dir (ffmpeg
`fontfile=`) and registers a `FontLoader` family (preview). `FontRegistry.pathFor/familyFor(font,
style)` resolve both; italic styles fall back to upright (no italic faces bundled).

### FfmpegService high-level API

All methods return `Result<File, FfmpegError>`; output is written to a per-job temp dir and
**not** cleaned on success — it lives there until `ExportService` copies it out, then the caller
invokes `cleanCurrentJob()`.

```dart
// Single-tool ops
imagesToGif({ frames, fps, width, onProgress })
videoToGif({ input, start, duration, fps, width, onProgress, totalMs })
probe(File)                       // → MediaInfo?
resizeGif({ input, width, height, ... })
cropGif({ input, x, y, cropWidth, cropHeight, ... })
optimizeGif({ input, colors, lossy, loopCount, frameDrop })
            // delegates to GifOptimizer (pure-Dart); frameDrop 0/2/3/4
textOverlay({ input, text, fontFile, fontSize, fontColor, position, ... })
textOverlayMulti({ input, items, mediaInfo, ... })
            // items: List<TextItem> → resolved to DrawTextSpec[] via _specsFromItems()
reverseGif({ input, ... })
changeSpeed({ input, factor, ... })

// Video Studio composite ops
editVideo({ input, cropX/Y/W/H, scaleW/H, speedFactor, hasAudio, volume,
            encoderCandidates, startMs, durationMs, overlayItems, mediaInfo, ... })
            // overlayItems: List<TextItem>? — baked before crop/scale; encoder fallback loop
bakeVideoToGif({ input, cropX/Y/W/H, scaleW, speedFactor, fps, startMs, durationMs, ... })
editGif({ input, cropX/Y/W/H, scaleW, speedFactor, startMs, durationMs,
          overlayText, fps, loopCount, boomerang, ... })
cleanJobAt(String jobDir)         // frees an arbitrary temp dir (e.g. baked-GIF source)
```

Windows resolves `gm_shim.dll` (+ 25 companion FFmpeg/codec/freetype DLLs) relative to
`Platform.resolvedExecutable` at runtime (`FfmpegDllBackend.tryResolvePath`). During dev they must
sit next to the built exe (`build\windows\x64\runner\Debug\`); `scripts/setup_windows_dev.ps1`
copies the full required set after clean builds and errors out listing whatever's missing. The set
comes from a release bundle or a local `scripts/build_ffmpeg_shim.ps1` + GPL FFmpeg build — none of
it is in git (`assets/bin/windows/` is git-ignored for both `*.exe` and `*.dll`).

---

## GifOptimizer

Pure-Dart GIF optimizer (`lib/core/services/gif_optimizer.dart`). Replaces gifsicle — no external
binary, works on all platforms. Entire pipeline runs in an `Isolate`.

**Pipeline:**
1. `img.GifDecoder().decodeFrame()` (raw per-rect frames) + manual disposal-aware compositing onto our own canvas — **not** `image`'s `decodeGif()`/`decode()`, which mis-composites sub-rect `disposal=1` frames lacking a local color table (floods the frame with index 0 instead of copying the previous canvas; pre-optimized GIFs with 1×1 duplicate-frame placeholders come out as a solid-color flash). Disposal 1 (leave)/2 (clear rect)/3 (restore previous snapshot) handled explicitly.
2. `OctreeQuantizer` trains one global palette across all frames (`colors` 2–256 entries, reserving 2 slots below the caller's budget for transparency — staying clear of the next power-of-two avoids doubling the GCT and widening every LZW code by a bit)
3. Nearest-color search (RGB memo cache, 5-bit quantized key) and lossy candidate ranking both use **redmean** — a luma-weighted RGB distance (compuphase.com/cmetric.htm) that approximates perceptual distance without a colorspace conversion, since the eye is far more sensitive to green than plain squared-RGB assumes. The lossy *budget gate* stays raw squared-RGB (its scale is `lossy²`); only the ranking of in-budget candidates uses redmean.
4. Sticker-class detection: scan for any pixel that goes from drawn to transparent-and-revealing-nothing-new — a genuinely transparent background whose opaque region moves/shrinks needs erasure, which `disposal=1` can never do (only reveal, never erase) and would otherwise leave permanent ghost trails that accumulate across loop iterations. Detected GIFs fall back to standalone `disposal=2` frames (only exact-duplicate consecutive frames merge — no inter-frame diff savings, but correct).
5. Normal mode: inter-frame transparency diff against a running **displayed canvas** (`disposal=1` leave-in-place):
   - Pixel transparent if canvas already shows the correct index (lossless), or if the current true color is within `lossy²` squared-RGB distance of the displayed color
   - Canvas updated only on redraw → displayed error bounded to `lossy` budget every frame (no ghosting drift)
   - Lossy pixels pick from a sorted-by-redmean-error candidate list of in-budget palette indices (not just nearest) so the LZW encoder can snap to whichever candidate extends its current dictionary match — gifsicle `--lossy`-style run extension
6. Per-frame bounding-box crop — only the changed pixel region written in each Image Descriptor
7. Custom GIF writer + `GifLzw.encode` (`lib/core/services/gif/gif_lzw.dart`) — spec-correct variable-width LZW

**Parameters:** `colors` 2–256, `lossy` 0–200 (0 = lossless diff; higher = more transparency, smaller file), `loopCount` (null = preserve source NETSCAPE2.0 count), `frameDrop` 0/2/3/4 (0 = keep all; N = drop 1 of every N frames, folding its duration into the previous kept frame so total playback time is unchanged; frame 0 always kept).

---

## Glass design system

`GlassContainer` is the **only** `BackdropFilter` primitive. All glass surfaces compose from it.

```dart
GlassContainer        // blur + fill + border + shadow; RepaintBoundary built-in
  └── GlassCard       // + tap ripple + top-edge sheen gradient
  └── GlassButton     // primary (gradient fill) or ghost (GlassContainer) variant
  └── GlassAppBar     // PreferredSizeWidget; blurred nav bar.
                      //   On Windows: wraps in DragToMoveArea + adds min/max/close controls
```

Key parameters on `GlassContainer`:
- `blur` — nullable; defaults to σ=18 (Windows/desktop) / σ=12 (Android/iOS), gated on `Platform`
- `opacity` — white fill alpha (default 0.10)

**Performance rules:**
- Cap blur surfaces to ~3–6 visible per screen
- Never use `BackdropFilter` inside scrolling lists — semi-opaque fill only
- `RepaintBoundary` is built into `GlassContainer`; don't double-wrap

### Palette

| Token | Value | Use |
|---|---|---|
| Font | `Inter` (Regular/Medium/SemiBold/Bold) | app-wide `fontFamily`, bundled `assets/fonts/` |
| `bg0` | `#0B0F1A` | near-black navy, scaffold base |
| `bg1` | `#141B2E` | gradient end |
| `accentA` | `#6D5DF6` | violet — primary/buttons |
| `accentB` | `#00C2FF` | cyan |
| `accentC` | `#FF5CAA` | magenta pop |
| `glassTint` | `#14FFFFFF` | ~8% white fill |
| `glassStroke` | `#33FFFFFF` | ~20% white border |
| `textHi` | `#F2F4FF` | primary text |
| `textLo` | `#9AA3C0` | secondary text |

### GradientScaffold

Wraps every screen. Provides:
- Static diagonal gradient (`bg0→bg1`)
- 3 animated radial blobs (violet/cyan/magenta) on an 8-second `AnimationController` loop
- `extendBodyBehindAppBar: true` so the glass app bar floats over the blobs

---

## State management

Riverpod with **manual providers — no codegen.** All providers live in
`lib/core/services/providers.dart` as plain `Provider<T>` / `AsyncNotifierProvider`. There are no
`@riverpod` annotations and no `.g.dart` files; `build_runner` is not part of the build.

Service providers: `ffmpegBackendProvider`, `tempFileServiceProvider`, `ffmpegServiceProvider`,
`exportServiceProvider`, `permissionServiceProvider`, `settingsServiceProvider`,
`recentsServiceProvider`.

State notifiers:
- `settingsProvider` (`SettingsNotifier`) — default fps/width/colors/lossy from shared_preferences
- `recentsProvider` (`RecentsNotifier`) — last 10 exports; every tool calls `.add()` after a
  successful export, surfaced in the home `RecentsStrip`

Each tool feature has its own `AsyncNotifier<XxxState>` holding input file(s), tool-specific
options, last generated preview/output, `FfmpegProgress?`, processing flag, and error string.

---

## Tool catalog & screen skeleton

`tool_catalog.dart` defines 7 tools in two categories driving the home layout:

| Category | Tools | Home treatment |
|---|---|---|
| `create` | Video Studio, Images → GIF | large featured cards (`FeaturedToolCard`) |
| `refine` | Resize, Crop, Text Overlay, Optimize, Effects | compact grid (`ToolCard`) |

Video Studio handles both video **and** GIF source files in one screen:
- `EditStage.video` — non-destructive layers (crop/resize/speed/trim/text/volume); `makeGif()` bakes them → GIF.
- `EditStage.gif` — `applyEdits()` bakes GIF edits (+ fps/loopCount/boomerang/optimize) into a temp and pushes a history entry; `undo()`/`redo()` navigates the `_GifVersion` stack (each entry owns its temp dir).
- `StudioTool` enum: `crop | resize | speed | trim | text | optimize | properties` — drives the dock panel. `trim` is available on both video and GIF stages (GIF trim maps to `gifEdit`'s `startMs`/`durationMs`).
- **Compare button** — hold-to-peek: while held, preview swaps to `state.inputFile` (original, pre-edit) with speed/volume/crop/trim/text all neutralized and an "ORIGINAL" chip shown; releases back to the live edited preview.
- GIF preview playback (`VideoPreview` in `_shared/widgets/video_preview.dart`) decodes the GIF itself via `ui.instantiateImageCodec` into a frame array + cumulative-duration index, driven by its own `Timer.periodic` ticker — **not** handed to `Image.file`'s free-running loop — so trim/seek are real operations (binary-search frame lookup, position clamps to `[trimStart, trimEnd)`) instead of riding the widget's own loop.
- Multi-item text overlay (`textItems: List<TextItem>`, up to 20) is shared with the Text Overlay tool. Draggable in the preview canvas; `TextFormatCard`/`TextLayersPanel` from `text_overlay_controls.dart`. Font files resolved per `TextStyleKind` (regular/bold/italic/boldItalic), registered with Flutter `FontLoader` for preview fidelity.
- GIF pipeline order: `textOverlayMulti` → `editGif` → `optimizeGif` (text bakes first against source dimensions so later crop/scale transforms the texted frames).
- `applyVideoEdits()` — bakes current video edits into a temp and swaps in as live preview; sets `editsApplied` so export skips re-encoding. Frees the prior baked temp on supersede.
- `exportVideo()` — edits video (encoder fallback); `exportGif()` — runs GIF pipeline + save; `discardGif()` returns to video stage.
- `VideoStudioState.volume` — audio gain 0–2.0; baked into encode's audio filter; ignored for GIF.

Routes: `/video-studio`, `/images-to-gif`, `/resize`, `/crop`, `/text-overlay`, `/optimize`,
`/effects`, `/screen-record`, plus `/settings` and `/about`. All non-home routes use a fade +
4%-slide transition. The recording indicator is **not** a route — see Screen Record below.

Every tool screen shares the 4-step skeleton:

```
[1 Pick] → [2 Options] → [3 Preview] → [4 Export]
```

- **Pick:** `FileDropZone` — drag-drop on Windows; tap → `file_picker` on both
- **Options:** glass card of `OptionSlider`s / chips; live value display
- **Preview:** `MediaPreview` runs FFmpeg on a **downscaled short sample** only
  (video preview uses `media_kit` `Player`/`Video`)
- **Export:** `ExportBottomSheet` → full-quality job → `ProgressOverlay` (glass, % + cancel) →
  `file_picker.saveFile()` → user picks location → success `AppToast` + recents entry

---

## Screen Record (Windows only)

`lib/features/screen_record/` + `lib/core/services/record/`. Records the full virtual desktop
(one selected monitor) into a temp video, then hands off to Video Studio. Moving parts:

- **Capture:** `FfmpegCommand.screenCapture` — `gdigrab` device via `gm_shim.dll`, `libx264
  -preset ultrafast`, physical-px offset/size (even-clamped). Mic (optional) joins the same
  in-process call via `dshow`. `ScreenRecorderService` owns a `RecorderEngine` (interface:
  `execute(sessionId, argv)`, `cancel(sessionId)`; real impl `GmShimRecorderEngine` wraps `GmShim`,
  same one `FfmpegDllBackend` uses) instead of `dart:io Process` — recording is still open-ended/
  session-controlled, not job-shaped, so it doesn't go through `FfmpegBackend.run()`/`FfmpegJobPool`
  either. Segment-per-pause/resume (ffmpeg has no pause), graceful stop via `gm_cancel(sessionId)`
  (fftools exits that session with `rc=255`, its own cancellation sentinel — not treated as an
  error since `_expectingExit` short-circuits the exit handler first), MKV segments (crash-safe, no
  moov atom to lose), concat-demuxer stream-copy to remux/join, 10-minute cap enforced both via
  `-t` per segment and a 500ms Dart tick. If `gm_shim.dll` can't be resolved at startup,
  `ScreenRecorderService(engine: null)` surfaces a clean error on `start()` instead of recording —
  there is no exe fallback.
- **System audio:** no WASAPI input exists for ffmpeg on Windows, so `windows/runner/
  audio_loopback.cpp` captures the default render device's loopback stream to WAV per segment
  (aligned with each video segment), muxed in at finalize (`FfmpegCommand.muxAudio`, `amix` when
  mic is also on). Exposed over the `gifolomora/native_window` MethodChannel
  (`NativeWindowChannel`), which also carries the recording-indicator show/update/hide calls and
  `getDefaultDeviceName` (audio-toggle subtitle labels).
- **Monitor enumeration:** `screen_retriever` (pinned to `^0.1.9` — `window_manager 0.3.9` caps it
  there). Its bundled Windows plugin hardcodes every `Display.id` to `0`, so `RecordTarget`
  identifies monitors by the raw Win32 device name (`\\.\DISPLAY1`, from `Display.name`) instead.
  `RecordTarget.fromDisplay` converts screen_retriever's logical px to gdigrab's physical px
  (`× scaleFactor`) using `visiblePosition`/`size` as the monitor-position/size proxy (the plugin
  only exposes the work-area position, not the raw monitor rect — a taskbar on that monitor's
  top/left edge introduces a small offset error).
- **Settings:** `RecordSettingsService` (`shared_preferences`) — audio toggles, the three
  `hotkey_manager` `HotKey`s (persisted via its own `toJson`/`fromJson`), last-used monitor name.
- **Hotkeys:** `HotkeyService` wraps `hotkey_manager`'s global instance. `RecordController` tracks
  a set of active "scopes" (`home`, `record`) plus "currently recording"; hotkeys are registered
  system-wide only while at least one of those is true — never app-wide from other tools.
- **Recording indicator:** native-drawn, not Flutter. `windows/runner/recording_indicator.cpp`
  creates a `WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_TOOLWINDOW` popup window
  sized to the **entire recorded monitor** (not a small pill) — no background fill (per-pixel
  alpha via `UpdateLayeredWindow` + a manually built premultiplied-ARGB DIB section that a
  `Gdiplus::Bitmap` draws directly into; `pptDst`/`psize` passed explicitly on every call —
  relying on `nullptr`/"keep current" left the layered surface never actually established, a
  window that reported successful creation yet stayed fully blank), and `WS_EX_TRANSPARENT`
  makes every mouse event pass straight through it to whatever's underneath. It draws a pulsing
  red/amber border traced a few px inside the monitor's edges (stays inbound — flush with the
  outer edge risks 1px clipping by the monitor/DWM boundary) plus a status dot + elapsed/audio
  text in the top-left corner (own `SetTimer`-driven ~30fps loop; frozen + amber while paused;
  text outline-drawn — four 1px-offset dark copies under white fill — for legibility with no
  background). Positioned/sized in **physical** px (`RecordTarget.physicalX/Y/W/H` directly — no
  DPI conversion needed since Win32 window coordinates are already physical for a DPI-aware
  process). It is also excluded from capture (`SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)`)
  so it never appears in the recording. Because it's click-through and buttonless, the recording
  is controlled by the global hotkeys **and** the Screen Record screen's Pause/Stop buttons — the
  main app window is never resized/morphed and stays exactly as the user left it throughout.
  `RecordController.stopRecording()` hides the indicator in a `finally`, even if finalize
  (concat/mux) throws.
- **Handoff:** `stopRecording()` calls `appRouter.go('/video-studio', extra: file)` directly
  (no `BuildContext` needed — `appRouter` is the app's single `GoRouter` instance); Video Studio
  already accepted an optional `initialFile` before this feature existed, so no studio-side change
  was needed.
- **Gating:** `ToolEntry.windowsOnly` hides the home-screen card and the router redirects both
  routes to `/` off-Windows.

---

## Export flow (locked decision)

Export is always **user-driven**: the full job writes to a temp job dir via `TempFileService`,
then `ExportService` calls `file_picker.saveFile()`. No silent gallery writes. Applies to both
platforms. After the copy, `FfmpegService.cleanCurrentJob()` removes the temp dir.

---

## Web marketing site

`web/gifolomora-intro-web/` — standalone Vite/React marketing page. **Not part of the Flutter build.**
Separate `package.json`; the `web/` directory is untracked (`??` in git status).

---

## Platform specifics

### Android
- `minSdk = 24` hard-coded in `android/app/build.gradle.kts` (not `flutter.minSdkVersion`)
- `packagingOptions { jniLibs { useLegacyPackaging = true } }` for media_kit native libs
- `file_picker` copies to cache — pass the cache path to FFmpeg, never the `content://` URI
- `permission_handler` for scoped storage

### Windows
- Developer Mode required for Flutter symlinks (`start ms-settings:developers`)
- `gm_shim.dll` + companion DLLs in `assets/bin/windows/` (git-ignored), resolved at runtime near
  `Platform.resolvedExecutable`; copied to build output by `scripts/setup_windows_dev.ps1`. No
  `ffmpeg.exe`/`ffprobe.exe` ship or exist anywhere in the bundle.
- `window_manager` for the custom glass title bar (native bar hidden in `bootstrap.dart`;
  `GlassAppBar` adds `DragToMoveArea` + min/max/close controls)
- `media_kit` for video preview (chosen over `video_player` — more Windows-stable)
- `gifolomora/native_window` MethodChannel (`windows/runner/flutter_window.cpp` +
  `audio_loopback.cpp/.h`): overlay capture-exclusion, WASAPI loopback capture, default
  input/output device names — see Screen Record above

---

## Key package versions

| Package | Version | Role |
|---|---|---|
| `flutter_riverpod` | 2.6.1 | state (manual providers) |
| `go_router` | 14.6.3 | routing |
| `ffmpeg_kit_flutter_new` | 4.2.1 | Android FFmpeg backend |
| `file_picker` | 8.1.2 | pick + saveFile dialog |
| `permission_handler` | 11.3.1 | Android scoped storage |
| `media_kit` (+ `_video`, `_libs_video`) | 1.1.10 / 1.2.4 / 1.0.4 | video preview |
| `window_manager` | 0.3.9 | Windows custom title bar + Screen Record overlay morph |
| `screen_retriever` | 0.1.9 (pinned by `window_manager`) | Screen Record monitor enumeration |
| `hotkey_manager` | 0.2.3 | Screen Record global hotkeys |
| `shared_preferences` | 2.3.0 | settings + recents persist |
| `path_provider` + `path` | 2.1.4 / — | temp dirs, path joins |
| `image` | 4.0.0 | GifOptimizer — raw-frame `GifDecoder`/`decodeFrame` (not `decodeGif`) + OctreeQuantizer |
| `desktop_drop` | 0.4.4 | drag-and-drop file acceptance (Windows/macOS/Linux) |
| `flutter_colorpicker` | — | HSV/hue-wheel color picker used in `text_overlay_controls.dart` |
| `package_info_plus` | 8.0.0 | app version / build metadata |
| `ffi` | 2.1.3 | Windows `dart:ffi` bindings to `gm_shim.dll` |
| gm_shim.dll + FFmpeg 6.0 libs (Windows) | bundled, self-built | in-process FFmpeg (GPLv3); no ffmpeg.exe/ffprobe.exe |

Dev deps of note: `msix` 3.16.7 (MSIX packaging via `scripts/build_msix_release.ps1`),
`flutter_launcher_icons` 0.14.3 (generates `.ico` / adaptive icon).
