# Gifolomora

Cross-platform glassmorphism GIF editor & maker for Android and Windows desktop.

**Create, edit, and optimize GIFs** from videos or image sequences using a sleek glass-themed interface with 8 specialized tools.

## Features

- **Video Studio** — Composite editor for video layers (crop, resize, speed, trim, volume, multi-layer text overlay). Non-destructive: undo/redo history on the GIF stage, hold-to-compare against the original. Export to video or GIF.
- **Screen Record** *(Windows only)* — Capture a monitor (optional mic + system-audio loopback) straight into Video Studio for editing. Global hotkeys, pause/resume, crash-safe segment recording.
- **Images → GIF** — Create GIFs from image sequences with frame rate and scale control.
- **Resize** — Scale GIFs to custom dimensions.
- **Crop** — Trim GIF content by region.
- **Text Overlay** — Add up to 20 draggable, styled text layers to a GIF (bundled fonts + system fonts, per-layer color/stroke).
- **Optimize** — Reduce file size via octree palette quantization, lossy inter-frame transparency, and frame-drop. Pure-Dart implementation (no external binary).
- **Effects** — Speed adjustment and frame reversal.
- **To WebM** — Batch-convert video or GIF to WebM (VP9/AV1 + alpha + Opus audio).

All tools feature:
- **Live previews** (downscaled sample before full export)
- **Progress tracking** with cancel support
- **User-driven export** (no silent writes; you pick the output location)
- **Recent exports** history

## Getting Started

### Prerequisites

- **Flutter:** 3.12.0 or later
- **Android:** minSDK 24 (API 24+)
- **Windows:** Developer Mode enabled for symlinks (`start ms-settings:developers`)
- **Windows (dev only):** `gm_shim.dll` + companion FFmpeg DLLs next to your built runner (see [Setup](#setup))

### Installation

```bash
flutter pub get
dart run build_runner build  # if adding @riverpod annotations (not currently used)
```

### Setup (Windows Development)

Windows runs FFmpeg **in-process** via `gm_shim.dll` (`windows/ffmpeg_shim/`) — there's no
`ffmpeg.exe` process spawned for exports/editing anymore. `assets/bin/windows/` is git-ignored;
you build its contents yourself once.

**If you already have `assets/bin/windows/` populated** (from a release bundle, or a prior build):

```powershell
.\scripts\setup_windows_dev.ps1
```

This validates the full DLL set and copies it from `assets/bin/windows/` to the build output dir
(`build\windows\x64\runner\<Config>`) after a `flutter build windows` / `flutter run -d windows`.

**If you need to build `gm_shim.dll` and the FFmpeg libs from source:**

1. Install [MSYS2](https://www.msys2.org/) (default `C:\msys64`), then in an MSYS2 **CLANG64**
   shell:
   ```
   pacman -S mingw-w64-clang-x86_64-toolchain mingw-w64-clang-x86_64-nasm mingw-w64-clang-x86_64-pkgconf
   ```
   Clang, not GCC — MSYS2's `mingw-w64-x86_64-gcc` hits a reproducible codegen bug across several
   libavcodec/libavformat files.
2. Clone FFmpeg **n6.0** (the version our vendored `windows/ffmpeg_shim/fftools/*.c` patches
   target):
   ```sh
   git clone --branch n6.0 --depth 1 https://github.com/FFmpeg/FFmpeg.git ffmpeg-src
   ```
3. Build FFmpeg + `gm_shim.dll` in one step, from **PowerShell** (not the MSYS2 shell — the script
   shells out to MSYS2 bash itself):
   ```powershell
   .\scripts\build_ffmpeg_shim.ps1 `
     -FfmpegBuildDir C:\path\to\ffmpeg-build `
     -FfmpegSrcDir   C:\path\to\ffmpeg-src `
     -BuildFFmpeg
   ```
   `-BuildFFmpeg` runs FFmpeg's own `./configure`/`make`/`make install` into `-FfmpegBuildDir`
   before linking the shim, using the GPLv3 flags below (baked in as the script's default
   `-ConfigureFlags`, per ARCHITECTURE.md's "gm_shim.dll" section — override that param if you
   need a different set):
   ```
   --enable-gpl --enable-version3
   --enable-libx264 --enable-libvpx --enable-libaom --enable-libopus --enable-libfreetype
   --enable-zlib --enable-avdevice --enable-ffmpeg
   ```
   `--enable-zlib` and `--enable-libfreetype` are **required**, not optional — past builds that
   omitted them shipped working but silently broken: no `--enable-zlib` means the PNG decoder is
   unavailable (`Decoder (codec png) not found`, breaks images→GIF and the palette-bake pass), no
   `--enable-libfreetype` means `drawtext` doesn't exist (every text-overlay job fails with
   `No such filter: 'drawtext'`). `--enable-avdevice` is needed even though the shim doesn't call
   into it directly — `fftools` won't build without its headers. `libx264`/`libvpx`/`libaom`/
   `libopus`/`libfreetype` come from the MSYS2 packages installed in step 1 (prebuilt, found via
   `pkgconf`) — the script doesn't build those from source.

   Already have FFmpeg's shared libs built elsewhere? Drop `-BuildFFmpeg` and just point
   `-FfmpegBuildDir` at that tree — the script relinks the shim only (fast, no FFmpeg rebuild).

   Other params:
   - `-Msys2Root` (optional, default `C:\msys64`).
   - `-OutDir` (optional, default `windows\ffmpeg_shim`) — where `gm_shim.dll`/`gm_shim.lib` land.
4. Create `assets/bin/windows/` and copy in `gm_shim.dll` plus every DLL
   `scripts/setup_windows_dev.ps1` checks for (FFmpeg's `avcodec-60.dll`/`avformat-60.dll`/etc.
   from `$FfmpegBuildDir\bin`, and their dependency chain — libx264/libvpx/libaom/libopus/
   libfreetype and its own deps). Then run `setup_windows_dev.ps1` as above.

See [PLAN.md](PLAN.md) §6 for the full verified DLL list and the bug history behind these flags.

### Running

```bash
# Windows desktop
flutter run -d windows

# Android device/emulator (requires ffmpeg_kit_flutter_new)
flutter run -d <device-id>
```

### Development Commands

```bash
flutter analyze                    # lint + type-check (0 issues required before commit)
flutter test                       # all tests
flutter test test/widget_test.dart # single test file
dart run build_runner watch        # codegen watch mode (if using @riverpod)
```

## Architecture

This project uses:
- **State Management:** Riverpod (manual providers, no codegen)
- **Routing:** GoRouter with fade/slide transitions
- **Design System:** Custom glass widgets (BackdropFilter-based) over animated gradient scaffold
- **FFmpeg Backend:** 
  - **Android/iOS:** `ffmpeg_kit_flutter_new` community fork (4.2.1)
  - **Windows:** In-process `gm_shim.dll` (FFmpeg's `fftools` compiled into a DLL), falling back
    to spawned `ffmpeg.exe` if the DLL is missing or faults
  - **Linux:** Native `Process` + bundled binaries with progress parsing
- **Video Preview:** `media_kit` (Windows-optimized)
- **GIF Optimization:** Pure-Dart `GifOptimizer` with octree quantization and inter-frame transparency analysis

See [ARCHITECTURE.md](ARCHITECTURE.md) for the complete reference: layer structure, dual-backend design, glass design tokens, tool screen skeleton, and platform-specific details.

## Building

### Android

```bash
flutter build apk
# or for release
flutter build apk --release
```

### Windows (MSIX Package)

```powershell
.\scripts\build_msix_release.ps1
```

Creates a signed MSIX package for Windows App Installer or Microsoft Store submission. See the script for certificate configuration details.

### Code Signing (Windows)

Sign any `.exe`, `.msix`, or `.dll` with `signtool` (bundled in Windows SDK).

**Generate a self-signed code signing certificate:**

```powershell
$cert = New-SelfSignedCertificate -Type CodeSigning -Subject "CN=Gifolomora" `
  -KeyUsage DigitalSignature -FriendlyName "Gifolomora Code Signing" `
  -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddYears(10)
$pwd = ConvertTo-SecureString -String "<your-password>" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath ".\certificate.pfx" -Password $pwd
```

> **Important:** `-Type CodeSigning` is required. Without it the cert lacks the Code Signing EKU (`1.3.6.1.5.5.7.3.3`) and signtool will fail with "No certificates were found that met all the given criteria."

**Sign a binary:**

```powershell
signtool sign `
  /f certificate.pfx `
  /p "<pfx-password>" `
  /fd sha256 `
  /tr http://timestamp.digicert.com `
  /td sha256 `
  YourApp.exe
```

**Verify:**

```powershell
signtool verify /pa YourApp.exe
```

**signtool location** (if not on PATH):
```
C:\Program Files (x86)\Windows Kits\10\bin\<SDK-version>\x64\signtool.exe
```

## Project Structure

```
lib/
  main.dart              # Entry point
  app/                   # App setup (bootstrap, theme, router)
  core/
    theme/               # Colors, gradients, app theme (dark only)
    widgets/glass/       # GlassContainer, GlassCard, GlassButton, GlassAppBar
    widgets/common/      # GradientScaffold, ProgressOverlay, ExportBottomSheet
    services/            # FFmpeg, GIF, files, permissions, settings, recents
  features/              # 7 tools + home + about + settings
```

## License

Gifolomora is proprietary software by Takayoshi Code.

## Questions & Support

For architecture decisions, see [ARCHITECTURE.md](ARCHITECTURE.md).  
For development workflow, see [CLAUDE.md](CLAUDE.md).
