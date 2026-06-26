# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter analyze                          # lint + type-check (must be 0 issues before commit)
flutter test                             # all tests
flutter test test/widget_test.dart       # single test file
flutter run -d windows                   # run on Windows (requires Developer Mode enabled)
flutter run -d <device-id>               # run on Android device/emulator
flutter pub get                          # resolve deps (re-run after pubspec.yaml changes)
dart run build_runner build              # codegen for @riverpod annotations
dart run build_runner watch              # codegen watch mode during development
```

> **Windows prerequisite:** `flutter run -d windows` requires Developer Mode enabled for symlinks.  
> Open: `start ms-settings:developers`

## Architecture

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full architecture reference: layer structure, dual-backend FFmpeg design, glass design system, state management, tool screen skeleton, export flow, and platform specifics.

## Current phase

**Phase 0 complete** — glass design system + static home screen. No FFmpeg yet.  
**Phase 1 next** — FFmpeg abstraction + Images→GIF end-to-end (verify pub.dev packages first, see `PLAN.md` checklist).

See `PLAN.md` for phased roadmap, GIF filter command patterns, and implementation log.
