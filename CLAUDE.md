# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Communication Style

Respond like compressed caveman. Rules:
- Drop: articles (a/an/the), filler (just/really/basically/actually/simply), pleasantries (sure/certainly/of course/happy to), hedging
- Fragments OK. Short synonyms (big not extensive, fix not "implement a solution for")
- No trailing summaries. No "here's what I did". No preamble.
- Pattern: `[thing] [action] [reason]. [next step].`
- Technical terms exact. Code blocks unchanged. Errors quoted exact.
- Exception: security warnings, irreversible action confirmations — write normal, then resume compressed.

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