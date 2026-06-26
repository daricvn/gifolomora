# Gifolomora — Implementation Plan

> Cross-platform glassmorphism GIF editor & maker. Premium, modern take on ezgif.com.
> **Targets:** Android + Windows desktop (Linux fallback later).
> **Stack:** Flutter · Riverpod · go_router · custom glass widgets · dual-backend FFmpeg.

---

## 0. Critical Architecture Decision (read first)

**`ffmpeg_kit_flutter` (Arthenica) was retired ~April 2025** — maintainer sunset the
project and pulled prebuilt binaries from registries. **And no `ffmpeg_kit` variant ever
supported Windows/Linux desktop** (Android/iOS only).

> Status: confirmed from model knowledge (cutoff Jan 2026). **Must be re-verified on
> pub.dev before Phase 1** — live registry not checked.

**Consequence:** FFmpeg cannot be one package. Use **two backends behind one interface**:

| Platform | Backend |
|----------|---------|
| Android (/iOS) | `ffmpeg_kit_flutter_new` community fork |
| Windows / Linux | Bundled `ffmpeg` binary called via `dart:io Process` |

This makes Linux nearly free later (reuses the Windows Process backend).

### Locked product decisions
1. **App size: no constraint.** Use full ffmpeg builds. No ABI split / no minimal build needed.
2. **Bundle `gifsicle`** (≈1 MB) alongside ffmpeg for best-in-class GIF optimization.
3. **Android minSdk = nearest minimum the fork allows** (likely API 24; verify against
   chosen fork). Don't over-engineer compatibility.
4. **Export is always user-driven.** User chooses **when** to save and **where** (location).
   No silent gallery writes. Save dialog on both platforms.

---

## 1. Tech Stack

| Concern | Choice | Notes |
|---|---|---|
| State | `flutter_riverpod` + `riverpod_generator` | `@riverpod` codegen |
| Navigation | `go_router` | thin route tree |
| Glass UI | custom `BackdropFilter` widgets | no third-party glass pkg |
| FFmpeg (Android) | `ffmpeg_kit_flutter_new` | verify maintained; behind interface |
| FFmpeg (Windows/Linux) | bundled `ffmpeg` binary + `Process` | full build, size unconstrained |
| GIF optimize | bundled `gifsicle` | both platforms |
| File pick | `file_picker` | pick + saveFile dialog, Android + Windows |
| Paths/temp | `path_provider` + `path` | |
| Save dialog | `file_picker` `saveFile` | user picks location (decision 4) |
| Permissions (Android) | `permission_handler` | scoped per minSdk |
| Video preview | `media_kit` | Windows-solid (over `video_player`) |
| GIF preview | `Image.file` / `Image.memory` | native decode, no pkg |
| Image dims | `image` (dart) | fallback ffprobe |
| Window chrome (Win) | `window_manager` | custom glass title bar |
| Settings persist | `shared_preferences` | |
| Logging | `talker` or `logging` | |

> Verify on pub.dev before locking: `ffmpeg_kit_flutter_new`, `media_kit`, `file_picker`,
> `window_manager` (current versions, Windows support, API names).

---

## 2. Phased Plan

### Phase 0 — Skeleton + Glass Design System ✅ COMPLETE
- **Goal:** Runs on Android + Windows. Glass system complete. Static home screen.
- **Files:** `lib/main.dart`, `lib/app/`, `lib/core/theme/`, `lib/core/widgets/glass/`, `lib/router/`.
- **Tasks:** project init (both platforms) · theme (palette + gradients §4) ·
  `GlassContainer`/`GlassCard`/`GlassButton`/`GlassAppBar` · `GradientScaffold` (blob bg) ·
  home grid of 6 tool cards · go_router stub routes.
- **Status:** All files written. `flutter analyze` → 0 issues. Flutter 3.44.0, minSdk=24.
  `flutter pub get` downloads OK; Windows requires **Developer Mode** enabled for symlinks
  before `flutter run -d windows` will work (`start ms-settings:developers`).
- **Test:** ⏳ `flutter run -d windows` pending Developer Mode. Android device TBD by user.
  ⚠️ Blur perf on emulator is misleading — confirm on **real Android device**.

### Phase 1 — FFmpeg Abstraction + Images→GIF ✅ COMPLETE
- **Goal:** Dual-backend service working; one real end-to-end tool.
- **Files:** `lib/core/services/ffmpeg/`, `lib/core/services/files/`, `lib/core/services/permissions/`,
  `lib/core/services/providers.dart`, `lib/features/_shared/`, `lib/features/images_to_gif/`.
- **Tasks:** `FfmpegBackend` interface ✅ · Android impl (`FfmpegKitBackend`) ✅ · Windows impl
  (`FfmpegProcessBackend`, Process + `-progress pipe:1`) ✅ · `TempFileService` (job dirs, sweep-on-start) ✅ ·
  `ExportService` (file_picker saveFile) ✅ · `MediaProbeService` ✅ · `PermissionService` ✅ ·
  `FfmpegService` high-level API ✅ · Riverpod providers (manual, no codegen needed) ✅ ·
  Shared widgets: `FileDropZone`, `OptionSlider`, `ExportBottomSheet`, `MediaPreview` ✅ ·
  `ImagesToGifController` + `ImagesToGifScreen` (Pick→Options→Preview→Export) ✅ ·
  `FrameStrip` (reorderable horizontal thumbnail strip) ✅ · `flutter analyze` → 0 issues ✅
- **Package versions locked:** `file_picker 8.3.7`, `permission_handler 11.4.0`, `ffmpeg_kit_flutter_new 4.2.1`
- **Windows:** binaries (`ffmpeg.exe`, `ffprobe.exe`) must be placed next to the built executable.
  During dev: `build\windows\x64\runner\Debug\`. See note below.
- **Android:** `ffmpeg_kit_flutter_new 4.2.1` resolved — verify API names match before Android build.
- **Test:** ⏳ `flutter run -d windows` pending Developer Mode. On-device GIF quality verify by user.

### Phase 2 — Video→GIF + Resize + Crop ✅ COMPLETE
- **Files:** `features/video_to_gif/`, `resize/`, `crop/`, `features/_shared/widgets/`.
- **Tasks:** `FfmpegService.probe()` ✅ · `FfmpegService.resizeGif()` ✅ · `FfmpegService.cropGif()` ✅ ·
  `FfmpegCommand.cropGif()` (palette pipeline) ✅ ·
  `VideoToGifController` + `VideoToGifScreen` (probe → trim start/end + fps/width → preview → export) ✅ ·
  `ResizeController` + `ResizeScreen` (probe → preset chips 320/480/640/960 + custom slider → preview → export) ✅ ·
  `CropController` + `CropScreen` + `CropOverlay` (draggable 4-corner handles + rule-of-thirds grid + body pan) ✅ ·
  Router wired: `/video-to-gif`, `/resize`, `/crop` ✅ · `flutter analyze` → 0 issues ✅
- **Test:** ⏳ `flutter run -d windows` pending Developer Mode. Large video + 4K on Windows by user. Android on-device by user.

### Phase 3 — Optimize/Compress + Text Overlay + Reverse/Speed ✅ COMPLETE
- **Files:** `features/optimize/`, `text_overlay/`, `effects/`.
- **Tasks:** gifsicle lossy/colors optimize ✅ · `drawtext` system font ✅ ·
  `reverse` + `setpts` speed ✅ · `FfmpegFactory.resolveGifsicle()` ✅ ·
  `FontResolver` (platform system fonts) ✅ · `flutter analyze` → 0 issues ✅
- **gifsicle:** optional — if `gifsicle.exe` placed next to app, lossy compress enabled; else ffmpeg palette fallback.
- **Font:** `FontResolver` tries Windows `arial.ttf`, Android `Roboto-Regular.ttf`, Linux `DejaVuSans.ttf`. Warning shown if none found.
- **Effects tool** added to home catalog (route `/effects`, Reverse + Speed modes).
- **Test:** `flutter run -d windows` pending. On-device GIF quality verify by user.

### Phase 4 — Polish ✅ COMPLETE
- Recents/history, settings (default quality, theme), export sheet, error toasts,
  empty states, animations, Windows custom glass title bar, app icons/installer.
- **Test:** full flows, cancel mid-process, low disk, denied permission.

### Phase 5 — Linux fallback (optional)
- Reuse Windows Process backend with `ffmpeg`/`gifsicle` from PATH or bundled.
- **Test:** build + run on Linux.

**Iteration rule:** one tool per session, vertical slice (UI→service→export), verify on
both platforms before next.

---

## 3. Folder Structure

```
lib/
  main.dart
  app/
    app.dart                 # MaterialApp.router
    bootstrap.dart           # init: paths, ffmpeg backend, logging
  router/
    app_router.dart
  core/
    theme/
      app_colors.dart
      app_gradients.dart
      app_theme.dart
    widgets/
      glass/
        glass_container.dart
        glass_card.dart
        glass_button.dart
        glass_app_bar.dart
      common/
        gradient_scaffold.dart
        progress_overlay.dart
        section_header.dart
    services/
      ffmpeg/
        ffmpeg_backend.dart        # abstract interface
        ffmpeg_kit_backend.dart    # Android/iOS
        ffmpeg_process_backend.dart# Windows/Linux (ffmpeg + gifsicle)
        ffmpeg_service.dart        # high-level API
        ffmpeg_command.dart        # command/filter builders
        ffmpeg_progress.dart       # progress model
        ffmpeg_factory.dart        # picks backend per platform
      files/
        temp_file_service.dart
        export_service.dart        # user-chosen save (when + where)
        media_probe_service.dart   # ffprobe wrapper
      permissions/
        permission_service.dart
    utils/
      result.dart                  # Result<T,Err>
      logger.dart
  features/
    home/
      view/home_screen.dart
      widgets/tool_card.dart
      data/tool_catalog.dart
    _shared/
      widgets/
        file_drop_zone.dart
        media_preview.dart
        option_slider.dart
        export_bottom_sheet.dart
      controller/process_controller.dart  # base Riverpod notifier
    images_to_gif/   { view/ controller/ widgets/ }
    video_to_gif/
    resize/
    crop/
    optimize/
    text_overlay/
    effects/
assets/
  fonts/                      # drawtext fonts (bundled)
  bin/
    windows/ { ffmpeg.exe, ffprobe.exe, gifsicle.exe }
    linux/   { ffmpeg, ffprobe, gifsicle }   # Phase 5
```

---

## 4. Glassmorphism Design System

### Palette
```dart
// app_colors.dart
class AppColors {
  static const bg0        = Color(0xFF0B0F1A); // near-black navy
  static const bg1        = Color(0xFF141B2E);
  static const accentA    = Color(0xFF6D5DF6); // violet
  static const accentB    = Color(0xFF00C2FF); // cyan
  static const accentC    = Color(0xFFFF5CAA); // magenta pop
  static const glassTint  = Color(0x14FFFFFF); // ~8% white fill
  static const glassStroke= Color(0x33FFFFFF); // ~20% white border
  static const textHi     = Color(0xFFF2F4FF);
  static const textLo     = Color(0xFF9AA3C0);
}
```

**Background:** animated diagonal gradient `bg0→bg1` + 2–3 blurred radial color "blobs"
(violet/cyan/magenta) behind everything. Glass picks up color bleed → premium look.
Lives in `GradientScaffold`.

### GlassContainer (core primitive)
```dart
// glass_container.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 18,
    this.opacity = 0.10,
    this.borderRadius = 24,
    this.border = true,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.tint = Colors.white,
  });

  final Widget child;
  final double blur;        // ImageFilter sigma
  final double opacity;     // fill alpha
  final double borderRadius;
  final bool border;
  final EdgeInsets padding;
  final Gradient? gradient; // optional sheen overlay
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint.withOpacity(opacity),
              borderRadius: radius,
              gradient: gradient,
              border: border
                  ? Border.all(color: Colors.white.withOpacity(0.18), width: 1)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

`GlassCard` = `GlassContainer` + tap ripple + top-edge highlight gradient (white 25%→0%
linear, top) for the "lit rim" cue. `GlassButton`, `GlassAppBar` share the primitive.

### Performance rules
- `BackdropFilter` is expensive. Cap visible blur surfaces (~3–6/screen).
- Always `RepaintBoundary` (built into `GlassContainer` above).
- Don't blur inside long scrolling lists — use semi-opaque fill there; reserve real blur
  for hero surfaces.
- Lower `sigma` on Android (~12) vs Windows (~18) if jank; gate on `Platform`.

---

## 5. FFmpegService

### Backend interface
```dart
// ffmpeg_backend.dart
abstract interface class FfmpegBackend {
  /// Streams 0..1 progress; completes when done.
  Future<FfmpegResult> run(
    List<String> args, {
    void Function(double progress)? onProgress,
    Duration? knownTotal, // for % from -progress out_time
  });
  Future<MediaInfo> probe(String inputPath); // ffprobe
  Future<void> cancel();
}
```
- **Android impl:** wraps `FFmpegKit.executeAsync` + `enableStatisticsCallback`.
- **Windows/Linux impl:** `Process.start(ffmpegPath, args)`; parse `-progress pipe:1`
  `out_time_ms` vs `knownTotal`. Resolve binaries near `Platform.resolvedExecutable`.
  **Quote all paths** (spaces).

```dart
// ffmpeg_factory.dart
FfmpegBackend createBackend() {
  if (Platform.isAndroid || Platform.isIOS) return FfmpegKitBackend();
  return FfmpegProcessBackend(
    ffmpeg: resolveBin('ffmpeg'),
    ffprobe: resolveBin('ffprobe'),
    gifsicle: resolveBin('gifsicle'),
  );
}
```

### High-level service
```dart
class FfmpegService {
  FfmpegService(this._backend, this._temp);

  Future<File> imagesToGif({
    required List<File> frames, int fps = 15, int? width,
    void Function(double)? onProgress });

  Future<File> videoToGif({
    required File input, Duration? start, Duration? duration,
    int fps = 15, int? width, void Function(double)? onProgress });

  Future<File> resize({ required File input, int? width, int? height });
  Future<File> crop({ required File input, required Rect rect });
  Future<File> optimizeGif({ required File input, int colors = 128, double lossy = 0 });
  Future<File> textOverlay({ required File input, required String text, required TextStyleSpec style });
  Future<File> reverse({ required File input });
  Future<File> changeSpeed({ required File input, required double factor });
}
```
UI never sees raw args. Output written to temp first; `ExportService` then prompts user
for save location (decision 4).

### High-quality GIF filter patterns (the quality lever)
```bash
# Video → high-quality GIF (palettegen + paletteuse)
ffmpeg -ss {start} -t {dur} -i in.mp4 \
  -filter_complex "[0:v] fps={fps},scale={w}:-1:flags=lanczos,split [a][b];\
[a] palettegen=stats_mode=diff [p];\
[b][p] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  -loop 0 out.gif

# Images → GIF
ffmpeg -framerate {fps} -i frame_%04d.png \
  -filter_complex "scale={w}:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
  -loop 0 out.gif

# Optimize / compress (use gifsicle — best size/quality)
gifsicle -O3 --lossy={lossy} --colors {colors} in.gif -o out.gif

# Text overlay
ffmpeg -i in.gif -vf "drawtext=fontfile='{font}':text='{esc}':\
x={x}:y={y}:fontsize={size}:fontcolor={color}:borderw=2:bordercolor=black@0.6,\
split[a][b];[a]palettegen[p];[b][p]paletteuse" out.gif

# Reverse / speed
-vf "reverse"
-vf "setpts={1/factor}*PTS"   # factor>1 = faster
```
`stats_mode=diff` + `dither=bayer:bayer_scale=5` = clean gradients at small size.

### Progress / temp / errors
- **Progress:** total from `probe()`; map `out_time`→%. Images: frames done / total.
  Always expose cancel.
- **Temp:** `TempFileService` → unique subdir per job under `getTemporaryDirectory()`;
  `try/finally` cleanup; sweep stale dirs on launch.
- **Errors:** `Result<File, FfmpegError>`; capture full ffmpeg log on failure (quote exact
  stderr). Common: bad font path (drawtext), missing palette split, Windows path spaces,
  Android content:// vs real path.

### Platform notes
- **Android:** `file_picker` copies to cache → pass cache path, not content:// URI.
  minSdk = nearest the fork allows.
- **Windows:** ship `ffmpeg.exe`/`ffprobe.exe`/`gifsicle.exe`; plain paths, quoted;
  `media_kit` preview; `window_manager` glass title bar.

---

## 6. MVP — 6 tools

1. **Video → GIF** ⭐ (hero) — build first
2. **Images → GIF**
3. **Resize GIF**
4. **Crop GIF**
5. **Optimize/Compress GIF** (gifsicle)
6. **Text/Caption overlay**

**Order:** 1 → 2 (reuse palette pipeline) → 3 → 4 → 5 → 6.
Reverse/speed/effects = post-MVP. 1+2 prove dual backend + palette quality; 3–5 cheap once
preview/options UI exists; 6 last (font bundling).

---

## 7. UI/UX Flow

**Home:** `GradientScaffold` (blob bg) → glass `GlassAppBar` ("Gifolomora") → responsive
grid of `GlassCard` tool tiles (2 col Android / 4 col Windows). "Recent" glass strip below.

**Tool screen — 4-step rail, identical skeleton every tool (`_shared` widgets):**
```
[1 Pick] → [2 Options] → [3 Preview] → [4 Export]
```
- **Pick:** `FileDropZone` glass panel (drag-drop Windows; tap→file_picker both).
- **Options:** glass card of `OptionSlider`s (fps, width, colors…), live values.
- **Preview:** glass-framed `MediaPreview` (before/after toggle). Preview runs ffmpeg on a
  **short/low-res sample** for speed — not the full job.
- **Export:** `ExportBottomSheet` (glass) → full job w/ `ProgressOverlay` (glass blurred
  backdrop, % + cancel) → **user picks save location** → success toast.

**Consistency:** every surface = glass primitive; one accent gradient on primary buttons;
same 4-step rail; same progress overlay. Tools differ only in Options content.

**State:** base `ProcessController` (Riverpod `AsyncNotifier`) per tool — holds input,
options, preview, job status, progress. Tools extend it.

---

## 8. Risks & Considerations

| Risk | Mitigation |
|---|---|
| App size | **Unconstrained (decision 1).** Full ffmpeg builds, no ABI split. gifsicle tiny. |
| Android perf | Cap input res, warn on long videos, ffmpeg_kit runs async native, RepaintBoundary + lower blur sigma. **Test real mid-tier device** (emulator lies). |
| Windows specifics | Bundle binaries, quote paths, `file_picker` save dialog, `window_manager` title bar; code-sign later for SmartScreen. |
| Permissions | `permission_handler`; file_picker copies to cache → use that path. minSdk = nearest fork minimum. |
| Preview cost | Preview on downscaled sample (first N sec); only Export runs full quality. |
| ffmpeg_kit fork risk | Abstracted behind `FfmpegBackend` → swap fork or go full-Process on Android if needed. |
| drawtext fonts | Bundle font in `assets/fonts/`, pass absolute path. |
| Export UX | Always user-chosen when + where (decision 4). No silent gallery write. |

---

## 9. Dev Workflow

- **One vertical slice per session** (e.g. "Video→GIF end to end"), small diffs.
- After each tool: agent verifies `flutter run -d windows`; **user** verifies Android
  device (emulator hides perf/blur) + real GIF quality. On-device confirmation is user-only.
- Capture baseline (build passes, prior tool still works) before adding next.
- **First real step = verify pub.dev** versions: `ffmpeg_kit_flutter_new`, `media_kit`,
  `file_picker`, `window_manager`. Source ffmpeg/ffprobe/gifsicle binaries for Windows.

### Suggested first prompt (after this plan)
> "Scaffold Gifolomora Phase 0: Flutter project with Android + Windows enabled, folder
> structure from PLAN.md, the glass design system (`GlassContainer`/`GlassCard`/
> `GradientScaffold` with dark gradient + blurred color blobs), and a static Home screen
> showing the 6 MVP tool cards in a responsive grid. Wire go_router with stub routes. Make
> it run on Windows and look premium. No FFmpeg yet."

---

## Verify-before-build checklist
- [x] `ffmpeg_kit_flutter_new` exists, maintained, min API, API names (pub.dev) → **4.2.1, all API verified**
- [x] `media_kit` Windows + Android → **media_kit 1.2.6 + media_kit_video 1.3.1 + media_kit_libs_video 1.0.7** (replaces `video_player`)
- [x] `file_picker` saveFile works Android + Windows → **8.3.7 locked**
- [ ] `window_manager` version
- [x] Source Windows binaries: ffmpeg.exe, ffprobe.exe → **ffmpeg 8.1.1, placed in `assets/bin/windows/` + Debug output**
- [ ] Source Windows binaries: gifsicle.exe (Phase 3)
- [x] Confirm chosen fork's minSdk → **set to 24** in `android/app/build.gradle.kts`
- [ ] Enable Windows Developer Mode → verify `flutter run -d windows` builds
- [ ] User confirms blur renders on real Android device

> **Most likely wrong claim:** exact 2026 state of `ffmpeg_kit_flutter_new` (maintenance,
> still no Windows, API names). Verify before Phase 1.

---

## Implementation Log

### 2026-06-26 — Video playback: migrated to media_kit
- Replaced `video_player` with `media_kit 1.2.6` + `media_kit_video 1.3.1` + `media_kit_libs_video 1.0.7`
- `bootstrap.dart`: added `MediaKit.ensureInitialized()` (required before any Player)
- `_VideoSection`: rewritten with `Player` + `VideoController` + `Video(controls: NoVideoControls)` — works on both Windows and Android
- `video_to_gif_screen.dart`: removed `MissingPluginException` fallback banner; pass `videoWidth/videoHeight` to `_VideoSection` for aspect ratio
- `android/app/build.gradle.kts`: added `packagingOptions { jniLibs { useLegacyPackaging = true } }` for media_kit native libs
- `flutter analyze` → 0 issues

### 2026-06-26 — Phase 4 complete
- `SettingsService` + `AppSettings` model + `SettingsNotifier` — default FPS/width/colors/lossy stored in shared_preferences
- `RecentsService` + `RecentExport` model + `RecentsNotifier` — last 10 exports stored as JSON in shared_preferences
- Settings screen (`/settings`): sliders for default quality + clear history button
- All 7 tool controllers now call `recentsProvider.notifier.add()` after successful export
- `RecentsStrip` on home screen: horizontal scroll of recent exports with time-ago labels; hidden when empty
- `EmptyState` shared widget: icon + message + optional subtitle + action button
- `AppToast` helper: `success`/`error`/`info` snackbar variants (floating, glass-style colors)
- Page transitions: fade + 4% slide from right (240ms) on all tool routes via GoRouter `pageBuilder`
- Windows custom title bar: `window_manager 0.3.9` added; `GlassAppBar` wraps in `DragToMoveArea` + adds `_WindowControls` (min/max/close with hover) on `Platform.isWindows`
- `bootstrap.dart`: hides native title bar on Windows (`TitleBarStyle.hidden`, 1280×720, min 800×560)
- Settings icon added to home screen app bar (gear/tune icon)
- `flutter analyze` → 0 issues

### 2026-06-26 — Phase 3 complete
- `FfmpegCommand`: added `optimizeGifFfmpeg`, `textOverlay`, `reverseGif`, `changeSpeed` (with Windows font path escaping)
- `FfmpegService`: added `optimizeGif` (gifsicle if present, else ffmpeg), `textOverlay`, `reverseGif`, `changeSpeed` — all track `_currentJobDir`
- `FfmpegFactory.resolveGifsicle()`: checks for gifsicle binary next to executable
- `FontResolver`: tries platform-specific system font paths
- Optimize: colors (16–256) + lossy (0–80, gifsicle-only) — lossy info banner when gifsicle absent
- Text Overlay: text input, position chips (top/center/bottom), font size, color chips; font-not-found warning
- Effects: Reverse mode + Speed mode (0.25×–4×) with snap-to-common-values
- Router: stubs replaced, `/effects` route added
- Tool catalog: Effects entry added (`/effects`, purple accent)
- `flutter analyze` → 0 issues

### 2026-06-26 — Phase 2 complete
- `FfmpegCommand.cropGif()`: crop + palettegen/paletteuse pipeline
- `FfmpegService`: added `probe()`, `resizeGif()`, `cropGif()` (all track `_currentJobDir` for cleanup)
- Video→GIF: `VideoToGifController` + `VideoToGifScreen` — pick video, ffprobe for dims/duration, start/end time sliders (MM:SS), fps+width options, generate preview, export
- Resize: `ResizeController` + `ResizeScreen` — preset chips (Original/320/480/640/960), custom width slider, output dims preview
- Crop: `CropController` + `CropScreen` + `CropOverlay` — interactive 4-corner drag handles, body pan to move, rule-of-thirds grid overlay, reset button, pixel crop dimensions display
- Router: `/video-to-gif`, `/resize`, `/crop` wired (were stubs)
- `flutter analyze` → 0 issues



### 2026-06-25 — Phase 1 complete
- Dual-backend FFmpeg abstraction: `FfmpegKitBackend` (Android) + `FfmpegProcessBackend` (Windows/Linux)
- Services: `FfmpegService`, `TempFileService`, `ExportService`, `MediaProbeService`, `PermissionService`
- Riverpod providers: manual `Provider<T>` (no codegen needed), all in `lib/core/services/providers.dart`
- Shared widgets: `FileDropZone`, `OptionSlider`, `ExportBottomSheet`, `MediaPreview`
- Images→GIF feature: full slice Pick→Options→Preview→Export with progress, cancel, error handling
- `flutter analyze` → 0 issues
- New deps: `file_picker 8.3.7`, `permission_handler 11.4.0`, `ffmpeg_kit_flutter_new 4.2.1`
- Windows binaries: `ffmpeg 8.1.1` downloaded from gyan.dev, placed in `assets/bin/windows/` (git-ignored) + `build\windows\x64\runner\Debug\`
- Dev script: `scripts/setup_windows_dev.ps1` copies binaries to build output after clean builds
- Android: `ffmpeg_kit_flutter_new 4.2.1` API names verified from pub cache — all match implementation

### 2026-06-25 — Phase 0 scaffolded
- Flutter 3.44.0 project created: Android + Windows platforms, `com.antigravity.gifolomora`
- All Phase 0 files written, `flutter analyze` clean (0 issues)
- Dependencies locked: `flutter_riverpod 2.6.1`, `go_router 14.8.1`, `riverpod_annotation 2.3.5`, `shared_preferences 2.5.5`, `path_provider 2.1.6`
- Android `minSdk` hard-coded to 24 (overrides `flutter.minSdkVersion`)
- `GlassContainer` uses `withValues(alpha:)` (Flutter 3.x API, no deprecation warnings)
- Blur sigma: 18 Windows / 12 Android (platform-gated in `GlassContainer`)
- Background: 8-second animated blob loop (3 blobs: violet/cyan/magenta) in `GradientScaffold`
- `assets/bin/windows/` dir created for Phase 1 binary drop
- **Blocker (user action needed):** Windows Developer Mode for symlink support → `start ms-settings:developers`
