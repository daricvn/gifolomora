# Gifolomora

Cross-platform glassmorphism GIF editor & maker for Android and Windows desktop.

**Create, edit, and optimize GIFs** from videos or image sequences using a sleek glass-themed interface with 7 specialized tools.

## Features

- **Video Studio** — Composite editor for video layers (crop, resize, speed, trim, text overlay). Export to video or GIF.
- **Images → GIF** — Create GIFs from image sequences with frame rate and scale control.
- **Resize** — Scale GIFs to custom dimensions.
- **Crop** — Trim GIF content by region.
- **Text Overlay** — Add custom text to GIFs with font and position control.
- **Optimize** — Reduce file size via palette quantization and inter-frame transparency. Pure-Dart implementation (no external binary).
- **Effects** — Speed adjustment and frame reversal.

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
- **Windows (dev only):** FFmpeg + FFprobe binaries next to your built runner (see [Setup](#setup))

### Installation

```bash
flutter pub get
dart run build_runner build  # if adding @riverpod annotations (not currently used)
```

### Setup (Windows Development)

The Windows build uses bundled FFmpeg/FFprobe binaries. For local development:

```bash
# PowerShell
.\scripts\setup_windows_dev.ps1
```

This copies `ffmpeg.exe` and `ffprobe.exe` from `assets/bin/windows/` to the debug runner directory after a clean build.

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
  - **Windows/Linux:** Native `Process` + bundled binaries with progress parsing
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
