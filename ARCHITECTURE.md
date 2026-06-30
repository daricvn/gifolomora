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
                    # EmptyState, AppToast (snackbar helper)
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
The app uses **two backends behind one interface** — UI and features never touch raw process args:

| Platform | Backend | Notes |
|---|---|---|
| Android / iOS | `ffmpeg_kit_flutter_new` community fork (4.2.1) | `FFmpegKit` + statistics callback |
| Windows / Linux | `dart:io Process` + bundled binaries | parse `-progress pipe:1` `out_time_ms` |

```
FfmpegBackend (abstract interface)
  ├── FfmpegKitBackend       → Android/iOS
  └── FfmpegProcessBackend   → Windows/Linux
FfmpegFactory.create()  picks impl at runtime via Platform.*
VideoEncoder            → platformCandidates() returns ordered hw+sw encoder list for editVideo fallback
FfmpegService           → high-level API; receives backend + temp
```

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
- `videoEditToGif` — bakes video layers (crop · fps · resize · speed · text) → GIF palette in one pass.
- `gifEdit` — applies crop · fps · resize · speed · text · loop · boomerang to an existing GIF; `boomerang` appends a reversed stream via `concat=n=2` for ping-pong.
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
editGif({ input, cropX/Y/W/H, scaleW, speedFactor, overlayText, fps,
          loopCount, boomerang, ... })
cleanJobAt(String jobDir)         // frees an arbitrary temp dir (e.g. baked-GIF source)
```

Windows binaries (`ffmpeg.exe`, `ffprobe.exe`) are resolved relative to
`Platform.resolvedExecutable` at runtime (`FfmpegProcessBackend.resolveBin`). During dev they must
sit next to the built exe (`build\windows\x64\runner\Debug\`); `scripts/setup_windows_dev.ps1`
copies them after clean builds. Always quote paths passed to `Process`.

---

## GifOptimizer

Pure-Dart GIF optimizer (`lib/core/services/gif_optimizer.dart`). Replaces gifsicle — no external
binary, works on all platforms. Entire pipeline runs in an `Isolate`.

**Pipeline:**
1. `image.decodeGif` → per-frame RGBA composited frames
2. `OctreeQuantizer` trains one global palette across all frames (`colors` 2–256 entries, capped at 254 to reserve a transparency slot)
3. Exhaustive nearest-color search with RGB memo cache (avoids octree tree-walk dead-ends)
4. Inter-frame transparency diff against a running **displayed canvas** (`disposal=1 leave-in-place`):
   - Pixel transparent if canvas already shows the correct index (lossless), or if the current true color is within `lossy²` squared-RGB distance of the displayed color
   - Canvas updated only on redraw → displayed error bounded to `lossy` budget every frame (no ghosting drift)
5. Per-frame bounding-box crop — only the changed pixel region written in each Image Descriptor
6. Custom GIF writer + `GifLzw.encode` (`lib/core/services/gif/gif_lzw.dart`) — spec-correct variable-width LZW

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
- `StudioTool` enum: `crop | resize | speed | trim | text | optimize | properties` — drives the dock panel.
- Multi-item text overlay (`textItems: List<TextItem>`, up to 20) is shared with the Text Overlay tool. Draggable in the preview canvas; `TextFormatCard`/`TextLayersPanel` from `text_overlay_controls.dart`. Font files resolved per `TextStyleKind` (regular/bold/italic/boldItalic), registered with Flutter `FontLoader` for preview fidelity.
- GIF pipeline order: `textOverlayMulti` → `editGif` → `optimizeGif` (text bakes first against source dimensions so later crop/scale transforms the texted frames).
- `applyVideoEdits()` — bakes current video edits into a temp and swaps in as live preview; sets `editsApplied` so export skips re-encoding. Frees the prior baked temp on supersede.
- `exportVideo()` — edits video (encoder fallback); `exportGif()` — runs GIF pipeline + save; `discardGif()` returns to video stage.
- `VideoStudioState.volume` — audio gain 0–2.0; baked into encode's audio filter; ignored for GIF.

Routes: `/video-studio`, `/images-to-gif`, `/resize`, `/crop`, `/text-overlay`, `/optimize`,
`/effects`, plus `/settings` and `/about`. All non-home routes use a fade + 4%-slide transition.

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
- Binaries in `assets/bin/windows/` (git-ignored), resolved at runtime near
  `Platform.resolvedExecutable`; copied to build output by `scripts/setup_windows_dev.ps1`
- `window_manager` for the custom glass title bar (native bar hidden in `bootstrap.dart`;
  `GlassAppBar` adds `DragToMoveArea` + min/max/close controls)
- `media_kit` for video preview (chosen over `video_player` — more Windows-stable)

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
| `window_manager` | 0.3.9 | Windows custom title bar |
| `shared_preferences` | 2.3.0 | settings + recents persist |
| `path_provider` + `path` | 2.1.4 / — | temp dirs, path joins |
| `image` | 4.0.0 | GifOptimizer — GIF decode + OctreeQuantizer |
| `desktop_drop` | 0.4.4 | drag-and-drop file acceptance (Windows/macOS/Linux) |
| `flutter_colorpicker` | — | HSV/hue-wheel color picker used in `text_overlay_controls.dart` |
| `package_info_plus` | 8.0.0 | app version / build metadata |
| ffmpeg / ffprobe (Windows) | bundled | bundled binaries (resolved at runtime) |

Dev deps of note: `msix` 3.16.7 (MSIX packaging via `scripts/build_msix_release.ps1`),
`flutter_launcher_icons` 0.14.3 (generates `.ico` / adaptive icon).
