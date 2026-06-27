# PLAN — Video Studio (crop · resize · speed)

> Add video → video editing (crop, resize, speed) alongside the existing GIF tools.
> **Goal:** performant + premium. One unified screen, one encode pass, live preview, no
> intermediate encodes.

Legend: ☐ todo · ☑ done · ⚠ verify before building.
Claims below are tagged **[confirmed file:line]** or **[verify]**. Don't re-investigate confirmed.

---

## Locked decisions

| Decision | Choice | Why |
|---|---|---|
| UX surface | **Unified "Video Studio"** — one screen; crop+resize+speed chained in ONE ffmpeg pass | Fewest encodes, no duplicated controllers |
| Output | **H.264 / AAC in `.mp4`** | Universal playback, small files |
| Encoder | **HW when available, SW fallback.** Win: `h264_nvenc`→`h264_qsv`→`h264_amf`→`libx264`. Android: `h264_mediacodec`→`libx264` | |
| Preview | **No encode until export** — media_kit player + Flutter overlay | crop = draggable rect; resize = label only; speed = `player.setRate()` |
| Catalog placement | **Reuse `create` category** (NOT a new `edit` category) | `home_screen` only renders `create`/`refine`; a 3rd enum value renders nowhere unless home_screen changes. [confirmed tool_catalog.dart:5-11, home filters createTools/refineTools] |
| Existing GIF tools | **Untouched** | additive; GIF path stays palettegen/paletteuse |

GIF crop/resize/effects controllers, commands, export stay exactly as-is.

---

## ⚠ Verify FIRST

1. **☑ Android/iOS H.264 — RESOLVED, no pubspec change.** Local path-override package depends on
   `com.antonkarpenko:ffmpeg-kit-full-gpl:2.1.0` [confirmed packages/ffmpeg_kit_flutter_new/android/build.gradle:54;
   ios podspec default_subspec 'full-gpl']. **full-gpl bundles `libx264`; ffmpeg-kit android always
   compiles `h264_mediacodec`.** Both present. Prefer `h264_mediacodec` (HW, faster); `libx264`
   guaranteed fallback. The "swap the variant" branch is dead — delete it.
   - Sanity-only at runtime: `FFmpegKit.execute('-encoders')` once on a real device.
2. **☑→confirm Windows H.264.** Binaries = gyan.dev builds [confirmed scripts/setup_windows_dev.ps1:13];
   ship `libx264`. gyan full builds also compile `h264_nvenc/qsv/amf` (runtime-gated by GPU). Confirm
   once: `ffmpeg.exe -encoders | grep -E 'libx264|h264_nvenc|h264_qsv|h264_amf'`.
3. **⚠ HW present ≠ usable.** `h264_nvenc` in the binary still fails with no NVIDIA GPU. **Must
   try-and-fallback at encode time**, not just parse `-encoders`. Probe order resolves to `libx264`
   on any machine.
4. **⚠ media_kit `setRate` audio pitch.** Confirm preview pitch at non-1× matches exported `atempo`
   closely. Player API already proven in `_VideoSection` [video_to_gif_screen.dart:263]; `setRate`
   is the only new call.

---

## Performance & premium principles

- **Single encode pass.** One chain `crop → scale → setpts` (+ `atempo` audio). Never an
  intermediate file.
- **Preview is free.** No ffmpeg while editing. Crop = Flutter overlay; resize = dim readout;
  speed = `player.setRate(factor)`. ffmpeg runs only on Export.
- **Stream-copy no-op.** crop=full, resize=source, speed=1.0 → `-c copy` (instant remux).
- **Even dimensions.** H.264 needs w/h divisible by 2. Round in Dart or append
  `scale=trunc(iw/2)*2:trunc(ih/2)*2`.
- **Keep blur surfaces ≤3–6** over the live player (don't stack `BackdropFilter` on video).

---

## Architecture changes (all additive)

### 1. `MediaInfo` + probe — **audio detection (NEW, blocks videoEdit)**
- ☐ `MediaInfo` [confirmed ffmpeg_progress.dart:24-36] has NO `hasAudio`. Add `bool hasAudio`.
- ☐ Set it in **both** `probe()` impls (`FfmpegProcessBackend` via ffprobe, `FfmpegKitBackend` via
  its probe) — detect an audio stream. `editVideo` needs this to choose `-c:a aac` vs `-an`.

### 2. Command layer — `ffmpeg_command.dart`
- ☐ `videoEdit({inputPath, outputPath, crop?, scaleW?, scaleH?, speedFactor, encoder, hasAudio})`
  → full arg list, single `-vf`/`-filter_complex`:
  - video: `crop=w:h:x:y` → `scale=w:h:flags=lanczos` → `setpts=(1/factor)*PTS` (+ even-dim guard)
  - audio (factor≠1.0): `atempo` chain, each link 0.5–2.0 (4× = `atempo=2.0,atempo=2.0`)
  - encoder args: libx264 → `-c:v libx264 -preset fast -crf 20`; HW use own RC (`-c:v h264_nvenc -cq 23`, etc.)
  - `-c:a aac -b:a 160k` if `hasAudio` else `-an`
  - keep `-progress pipe:1` [pattern confirmed across all commands ffmpeg_command.dart]
- ☐ `videoStreamCopy({inputPath, outputPath})` → `-y -i in -c copy out` for the no-op path.
- Note: existing `changeSpeed` [ffmpeg_command.dart:152] is GIF-only (palettegen, silent). New
  command is separate.

### 3. Encoder resolution — new `video_encoder.dart` (or in `FfmpegFactory`)
- ☐ `Future<List<String>> resolveH264Candidates(backend)` — parse `-encoders` once, cache, return
  ordered candidates. Win: `[h264_nvenc, h264_qsv, h264_amf, libx264]`. Android: `[h264_mediacodec, libx264]`.
- Service tries each in order, falls back on non-zero exit (item 3).

### 4. Service layer — `ffmpeg_service.dart`
- ☐ `editVideo({input, crop?, width?, height?, speedFactor, onProgress, totalMs}) → Result<File,FfmpegError>`.
  Mirror existing method shape **exactly** [confirmed ffmpeg_service.dart pattern]:
  `createJobDir()` → `_currentJobDir = jobDir` → `tempOutputPath(jobDir, 'mp4')` → loop encoder
  candidates calling `_backend.run(...)` → on all-Err `cleanJob` + null `_currentJobDir`.
  Output ext **`mp4`** (param controls it [ffmpeg_service.dart:35]).
- ☐ No-op (crop full + resize source + speed 1.0) → `videoStreamCopy` instead of re-encode.
- ☐ Progress: output duration = input/factor → scale `totalMs` by `1/factor`.
- Export still uses `cleanCurrentJob()` [ffmpeg_service.dart:58] after copy-out.

### 5. Export — `export_service.dart`
- ☐ `saveVideo(File, {defaultName='edited.mp4'})` mirroring `saveGif` [confirmed export_service.dart:7]
  — `FileType.custom`, `allowedExtensions:['mp4']`.

### 6. Preview widget — new `video_preview.dart` in `features/_shared/widgets/`
- ☐ Mirror `_VideoSection` [video_to_gif_screen.dart:263-551]: `Player`+`VideoController`, open
  `Media(file)`, listen position/playing, dispose in `dispose()`. Loop the **source** file.
- ☐ Add `speedRate` → `player.setRate`; `cropRect` (normalized) → crop overlay.
- ☐ **Crop overlay is NOT drop-in.** `crop_overlay.dart` [crop_overlay.dart:145] paints its own
  `Image.file` background. For video: reuse the painter + gesture/normalized-Rect math
  [crop_overlay.dart:43-129], drop the `Image.file`, stack the painter over the `Video` widget,
  match its aspect-fit letterboxing to `_imageRect`.

### 7. Feature module — `features/video_studio/`
- ☐ `controller/video_studio_controller.dart` — `AsyncNotifier<VideoStudioState>` (immutable +
  `copyWith` + `_s` sentinel; repo pattern — manual providers, no codegen). State: `inputFile`,
  `mediaInfo`, `cropNormalized` (default full), `targetWidth?`, `speedFactor` (1.0), `outputFile`,
  `progress`, `isProcessing`, `isProbing`, `error`. Methods: `setInput/probe`, `setCrop`, `setResize`,
  `setSpeed`, `generate` (one `editVideo`, no-op→stream copy), `exportVideo`, `cancel`, `clear`.
  Register provider in `providers.dart`.
- ☐ `view/video_studio_screen.dart` — preview is live (no generate-before-export step):
  Pick → [crop overlay + resize chips + speed slider over live player] → Export.
  `recents.add(RecentExport(toolName:'Video Studio', toolRoute:'/video-studio'))`.

### 8. Catalog + router
- ☐ `tool_catalog.dart` — add `ToolEntry` with `category: ToolCategory.create` (decision above).
  Copy must say *video in → video out*, distinct from GIF tools.
- ☐ `app_router.dart` — add `/video-studio` via existing `_slide` + `const VideoStudioScreen()`
  [confirmed app_router.dart:14,49].

### 9. Android encoder note
- ☐ For `h264_mediacodec`, some clips need `-pix_fmt nv12` + even dims; add the flag only if a real
  device clip requires it.

---

## Build order

| Step | Deliverable | Gate |
|---|---|---|
| V0 | Run `-encoders` Win + real Android; confirm `libx264`/`h264_mediacodec`/HW | items 2–3 sane (1 resolved) |
| V1 | `MediaInfo.hasAudio` + probe; `videoEdit` cmd + `resolveH264Candidates` + `editVideo` (crop+resize+speed, 1 pass, fallback loop) | `flutter analyze` 0; encode test clip on Windows, play result |
| V2 | `saveVideo` + `video_preview.dart` (player, setRate, crop overlay over Video) | preview plays; crop drags; speed changes live |
| V3 | `video_studio` controller + screen + catalog + route | Windows e2e: pick → edit → export `.mp4` opens in player |
| V4 | Stream-copy no-op + even-dim guard + forced HW-fallback verified | no-edit export instant; forced fallback yields valid mp4 |
| V5 | Android device pass (`h264_mediacodec`, `atempo`, scoped-storage save) | device export plays, A/V in sync |

Each step: `flutter analyze` 0 before commit. Capture `flutter test` baseline before V1; diff after
each step — no GIF-tool regressions.

---

## Open risks

- **A/V sync at non-1×.** `setpts` (video) + `atempo` (audio) must use consistent factors; verify
  lip-sync on speech.
- **`atempo` quality** degrades outside 0.5–2×; chain links, cap UI slider (e.g. 0.25×–4×).
- **HW RC ≠ libx264** at same nominal quality; pick per-encoder rate-control, don't reuse `-crf` on nvenc/qsv/amf.
- **`-encoders` present ≠ runtime works** (no GPU/driver) — encode-time fallback loop is the real guarantee.

---