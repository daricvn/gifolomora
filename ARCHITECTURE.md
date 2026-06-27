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
      ffmpeg/       # backend interface + 2 impls + factory + service + command/progress models
      files/        # TempFileService, ExportService, MediaProbeService
      permissions/  # PermissionService (Android scoped storage)
      settings/     # SettingsService + AppSettings (shared_preferences)
      recents/      # RecentsService + RecentExport (last 10 exports, shared_preferences)
      providers.dart# all Riverpod providers (manual) + SettingsNotifier + RecentsNotifier
    utils/          # Result<T,E>, logger, FontResolver (system font paths for drawtext)
  features/
    home/           # view/ + widgets/ (HomeHero, FeaturedToolCard, ToolCard, RecentsStrip)
                    # + data/tool_catalog.dart (drives the grid)
    _shared/
      widgets/      # FileDropZone, MediaPreview, OptionSlider, ExportBottomSheet
    <tool>/         # view/ + controller/ (+ widgets/) per tool — 7 tools total
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
FfmpegFactory.resolveGifsicle()  → gifsicle path if present next to executable, else null
FfmpegService           → high-level API; receives backend + temp + optional gifsicle path
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

`FfmpegCommand` builds all arg lists / filter graphs (palettegen/paletteuse, crop, drawtext,
reverse, setpts, gifsicle fallback). `FfmpegProgress` is the progress model.

### FfmpegService high-level API

All methods return `Result<File, FfmpegError>`; output is written to a per-job temp dir and
**not** cleaned on success — it lives there until `ExportService` copies it out, then the caller
invokes `cleanCurrentJob()`.

```dart
imagesToGif({ frames, fps, width, onProgress })
videoToGif({ input, start, duration, fps, width, onProgress, totalMs })
probe(File)                       // → MediaInfo?
resizeGif({ input, width, height, ... })
cropGif({ input, x, y, cropWidth, cropHeight, ... })
optimizeGif({ input, colors, lossy, ... })   // gifsicle if present, else ffmpeg palette
textOverlay({ input, text, fontFile, fontSize, fontColor, position, ... })
reverseGif({ input, ... })
changeSpeed({ input, factor, ... })
```

Windows binaries (`ffmpeg.exe`, `ffprobe.exe`, optional `gifsicle.exe`) are resolved relative to
`Platform.resolvedExecutable` at runtime (`FfmpegProcessBackend.resolveBin`). During dev they must
sit next to the built exe (`build\windows\x64\runner\Debug\`); `scripts/setup_windows_dev.ps1`
copies them after clean builds. Always quote paths passed to `Process`.

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
| `create` | Video → GIF, Images → GIF | large featured cards (`FeaturedToolCard`) |
| `refine` | Resize, Crop, Text Overlay, Optimize, Effects | compact grid (`ToolCard`) |

Routes: `/video-to-gif`, `/images-to-gif`, `/resize`, `/crop`, `/text-overlay`, `/optimize`,
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
| `go_router` | 14.8.1 | routing |
| `ffmpeg_kit_flutter_new` | 4.2.1 | Android FFmpeg backend |
| `file_picker` | 8.3.7 | pick + saveFile dialog |
| `permission_handler` | 11.4.0 | Android scoped storage |
| `media_kit` (+ `_video`, `_libs_video`) | 1.2.6 / 1.3.1 / 1.0.7 | video preview |
| `window_manager` | 0.3.9 | Windows custom title bar |
| `shared_preferences` | 2.5.5 | settings + recents persist |
| `path_provider` + `path` | 2.1.6 / — | temp dirs, path joins |
| ffmpeg / ffprobe (Windows) | 8.1.1 | bundled binaries |
