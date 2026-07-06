import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/features/text_overlay/model/text_item.dart';
import 'package:gifolomora/features/video_studio/controller/video_studio_controller.dart';

void main() {
  // ── hasInput / isGif ──────────────────────────────────────────────────────
  group('VideoStudioState — hasInput / isGif', () {
    test('hasInput false when sourceFile null', () {
      const s = VideoStudioState();
      expect(s.hasInput, isFalse);
    });

    test('hasInput true when sourceFile set', () {
      final s = VideoStudioState(sourceFile: File('/test.gif'));
      expect(s.hasInput, isTrue);
    });

    test('isGif false in video stage', () {
      const s = VideoStudioState(stage: EditStage.video);
      expect(s.isGif, isFalse);
    });

    test('isGif true in gif stage', () {
      const s = VideoStudioState(stage: EditStage.gif);
      expect(s.isGif, isTrue);
    });
  });

  // ── source dimensions ─────────────────────────────────────────────────────
  group('VideoStudioState — source dimensions when sourceInfo null', () {
    test('sourceWidth defaults to 0', () {
      const s = VideoStudioState();
      expect(s.sourceWidth, equals(0));
    });

    test('sourceHeight defaults to 0', () {
      const s = VideoStudioState();
      expect(s.sourceHeight, equals(0));
    });

    test('hasAudio defaults to false', () {
      const s = VideoStudioState();
      expect(s.hasAudio, isFalse);
    });

    test('sourceDurationMs defaults to 0', () {
      const s = VideoStudioState();
      expect(s.sourceDurationMs, equals(0));
    });
  });

  group('VideoStudioState — source dimensions from sourceInfo', () {
    const info = MediaInfo(
      durationMs: 4000,
      width: 640,
      height: 480,
      hasAudio: true,
    );

    test('sourceWidth from sourceInfo', () {
      const s = VideoStudioState(sourceInfo: info);
      expect(s.sourceWidth, equals(640));
    });

    test('sourceHeight from sourceInfo', () {
      const s = VideoStudioState(sourceInfo: info);
      expect(s.sourceHeight, equals(480));
    });

    test('hasAudio true from sourceInfo', () {
      const s = VideoStudioState(sourceInfo: info);
      expect(s.hasAudio, isTrue);
    });

    test('sourceDurationMs from sourceInfo', () {
      const s = VideoStudioState(sourceInfo: info);
      expect(s.sourceDurationMs, equals(4000));
    });
  });

  // ── isCropFull ────────────────────────────────────────────────────────────
  group('VideoStudioState — isCropFull', () {
    test('true at default crop (0,0,1,1)', () {
      const s = VideoStudioState();
      expect(s.isCropFull, isTrue);
    });

    test('false when left non-zero', () {
      final s = VideoStudioState(
        cropNormalized: const Rect.fromLTWH(0.1, 0, 0.9, 1),
      );
      expect(s.isCropFull, isFalse);
    });

    test('false when top non-zero', () {
      final s = VideoStudioState(
        cropNormalized: const Rect.fromLTWH(0, 0.1, 1, 0.9),
      );
      expect(s.isCropFull, isFalse);
    });

    test('false when right < 1', () {
      final s = VideoStudioState(
        cropNormalized: const Rect.fromLTRB(0, 0, 0.8, 1),
      );
      expect(s.isCropFull, isFalse);
    });

    test('false when bottom < 1', () {
      final s = VideoStudioState(
        cropNormalized: const Rect.fromLTRB(0, 0, 1, 0.75),
      );
      expect(s.isCropFull, isFalse);
    });
  });

  // ── hasEdits ──────────────────────────────────────────────────────────────
  group('VideoStudioState — hasEdits', () {
    test('false at all defaults', () {
      const s = VideoStudioState();
      expect(s.hasEdits, isFalse);
    });

    test('true when crop not full', () {
      final s = VideoStudioState(
        cropNormalized: const Rect.fromLTWH(0.1, 0, 0.9, 1),
      );
      expect(s.hasEdits, isTrue);
    });

    test('true when targetWidth set', () {
      const s = VideoStudioState(targetWidth: 480);
      expect(s.hasEdits, isTrue);
    });

    test('true when speedFactor != 1.0', () {
      const s = VideoStudioState(speedFactor: 2.0);
      expect(s.hasEdits, isTrue);
    });

    test('false when speedFactor difference < 0.001 from 1.0', () {
      const s = VideoStudioState(speedFactor: 1.0009);
      expect(s.hasEdits, isFalse);
    });
  });

  // ── hasTrim / effectiveTrimEndMs / trimDurationMs ─────────────────────────
  group('VideoStudioState — trim', () {
    test('hasTrim false when trimStart and trimEnd both 0', () {
      const s = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 5000, width: 320, height: 240),
      );
      expect(s.hasTrim, isFalse);
    });

    test('hasTrim true when trimStart > 0', () {
      const s = VideoStudioState(
        trimStartMs: 500,
        sourceInfo: MediaInfo(durationMs: 5000, width: 320, height: 240),
      );
      expect(s.hasTrim, isTrue);
    });

    test('hasTrim true when trimEnd is set and less than sourceDuration', () {
      const s = VideoStudioState(
        trimEndMs: 3000,
        sourceInfo: MediaInfo(durationMs: 5000, width: 320, height: 240),
      );
      expect(s.hasTrim, isTrue);
    });

    test('hasTrim false when trimEnd equals sourceDurationMs', () {
      const s = VideoStudioState(
        trimEndMs: 5000,
        sourceInfo: MediaInfo(durationMs: 5000, width: 320, height: 240),
      );
      expect(s.hasTrim, isFalse);
    });

    test('effectiveTrimEndMs equals sourceDurationMs when trimEndMs is 0', () {
      const s = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 8000, width: 320, height: 240),
      );
      expect(s.effectiveTrimEndMs, equals(8000));
    });

    test('effectiveTrimEndMs equals trimEndMs when nonzero', () {
      const s = VideoStudioState(
        trimEndMs: 4000,
        sourceInfo: MediaInfo(durationMs: 8000, width: 320, height: 240),
      );
      expect(s.effectiveTrimEndMs, equals(4000));
    });

    test('trimDurationMs = effectiveTrimEnd - trimStart', () {
      const s = VideoStudioState(
        trimStartMs: 1000,
        trimEndMs: 4000,
        sourceInfo: MediaInfo(durationMs: 8000, width: 320, height: 240),
      );
      expect(s.trimDurationMs, equals(3000));
    });

    test('trimDurationMs 0 when sourceDurationMs is 0', () {
      const s = VideoStudioState();
      expect(s.trimDurationMs, equals(0));
    });

    test('trimDurationMs clamped to sourceDurationMs', () {
      // trimStart=0, trimEnd=0 → effectiveTrimEnd=sourceDuration → duration-0 = duration
      const s = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 2000, width: 320, height: 240),
      );
      expect(s.trimDurationMs, equals(2000));
    });
  });

  // ── hasText / canAddText ──────────────────────────────────────────────────
  group('VideoStudioState — text', () {
    test('hasText false when textItems empty', () {
      const s = VideoStudioState();
      expect(s.hasText, isFalse);
    });

    test('hasText false when all text items are whitespace-only', () {
      final s = VideoStudioState(textItems: [
        const TextItem(id: '1', text: '   ', nx: 0.1, ny: 0.2),
        const TextItem(id: '2', text: '\t\n', nx: 0.3, ny: 0.4),
      ]);
      expect(s.hasText, isFalse);
    });

    test('hasText false when all items have empty string', () {
      final s = VideoStudioState(textItems: [
        const TextItem(id: '1', text: '', nx: 0.1, ny: 0.2),
      ]);
      expect(s.hasText, isFalse);
    });

    test('hasText true when at least one item has non-blank text', () {
      final s = VideoStudioState(textItems: [
        const TextItem(id: '1', text: '  ', nx: 0.1, ny: 0.2),
        const TextItem(id: '2', text: 'Hello', nx: 0.3, ny: 0.4),
      ]);
      expect(s.hasText, isTrue);
    });

    test('canAddText true when fewer than 20 items', () {
      const s = VideoStudioState();
      expect(s.canAddText, isTrue);
    });

    test('canAddText true at 19 items', () {
      final items = List.generate(
        19,
        (i) => TextItem(id: '$i', text: 'T', nx: 0.1, ny: 0.1),
      );
      final s = VideoStudioState(textItems: items);
      expect(s.canAddText, isTrue);
    });

    test('canAddText false at exactly 20 items', () {
      final items = List.generate(
        20,
        (i) => TextItem(id: '$i', text: 'T', nx: 0.1, ny: 0.1),
      );
      final s = VideoStudioState(textItems: items);
      expect(s.canAddText, isFalse);
    });
  });

  // ── fontReady ─────────────────────────────────────────────────────────────
  group('VideoStudioState — fontReady', () {
    test('false when fontFiles empty', () {
      const s = VideoStudioState();
      expect(s.fontReady, isFalse);
    });

    test('false when fontFiles has only non-regular keys', () {
      final s = VideoStudioState(
        fontFiles: {TextStyleKind.bold: '/fonts/bold.ttf'},
      );
      expect(s.fontReady, isFalse);
    });

    test('true when regular key present', () {
      final s = VideoStudioState(
        fontFiles: {TextStyleKind.regular: '/fonts/regular.ttf'},
      );
      expect(s.fontReady, isTrue);
    });
  });

  // ── hasVolumeChange ───────────────────────────────────────────────────────
  group('VideoStudioState — hasVolumeChange', () {
    test('false at default volume 1.0 with audio', () {
      const s = VideoStudioState(
        volume: 1.0,
        sourceInfo: MediaInfo(durationMs: 1000, width: 320, height: 240, hasAudio: true),
      );
      expect(s.hasVolumeChange, isFalse);
    });

    test('false when volume differs but no audio', () {
      const s = VideoStudioState(
        volume: 1.5,
        sourceInfo: MediaInfo(durationMs: 1000, width: 320, height: 240),
      );
      expect(s.hasVolumeChange, isFalse);
    });

    test('false when no sourceInfo regardless of volume', () {
      const s = VideoStudioState(volume: 0.5);
      expect(s.hasVolumeChange, isFalse);
    });

    test('true when volume 1.5 and has audio', () {
      const s = VideoStudioState(
        volume: 1.5,
        sourceInfo: MediaInfo(durationMs: 1000, width: 320, height: 240, hasAudio: true),
      );
      expect(s.hasVolumeChange, isTrue);
    });

    test('true when volume 0.0 and has audio', () {
      const s = VideoStudioState(
        volume: 0.0,
        sourceInfo: MediaInfo(durationMs: 1000, width: 320, height: 240, hasAudio: true),
      );
      expect(s.hasVolumeChange, isTrue);
    });
  });

  // ── selectedText ──────────────────────────────────────────────────────────
  group('VideoStudioState — selectedText', () {
    test('null when selectedTextId null', () {
      final s = VideoStudioState(textItems: [
        const TextItem(id: 'a', text: 'Hi', nx: 0.1, ny: 0.1),
      ]);
      expect(s.selectedText, isNull);
    });

    test('returns matching item by id', () {
      const item = TextItem(id: 'b', text: 'World', nx: 0.2, ny: 0.3);
      final s = VideoStudioState(
        textItems: [
          const TextItem(id: 'a', text: 'Other', nx: 0.0, ny: 0.0),
          item,
        ],
        selectedTextId: 'b',
      );
      expect(s.selectedText, same(item));
    });

    test('null when selectedTextId not found in textItems', () {
      final s = VideoStudioState(
        textItems: [const TextItem(id: 'x', text: 'T', nx: 0.1, ny: 0.1)],
        selectedTextId: 'nonexistent',
      );
      expect(s.selectedText, isNull);
    });
  });

  // ── hasPendingApply / isToolEdited ────────────────────────────────────────
  group('VideoStudioState — hasPendingApply', () {
    test('video stage: false at defaults', () {
      const s = VideoStudioState(stage: EditStage.video);
      expect(s.hasPendingApply, isFalse);
    });

    test('video stage: true when speed changed', () {
      const s = VideoStudioState(stage: EditStage.video, speedFactor: 2.0);
      expect(s.hasPendingApply, isTrue);
    });

    test('gif stage: false at defaults', () {
      const s = VideoStudioState(stage: EditStage.gif);
      expect(s.hasPendingApply, isFalse);
    });

    test('gif stage: true when doOptimize set', () {
      const s = VideoStudioState(stage: EditStage.gif, doOptimize: true);
      expect(s.hasPendingApply, isTrue);
    });

    test('gif stage: true when boomerang set (needsGifEdit)', () {
      const s = VideoStudioState(stage: EditStage.gif, boomerang: true);
      expect(s.hasPendingApply, isTrue);
    });
  });

  group('VideoStudioState — hasComparableEdit', () {
    test('video stage: false at defaults', () {
      const s = VideoStudioState(stage: EditStage.video);
      expect(s.hasComparableEdit, isFalse);
    });

    test('video stage: true when speed changed', () {
      const s = VideoStudioState(stage: EditStage.video, speedFactor: 2.0);
      expect(s.hasComparableEdit, isTrue);
    });

    test('gif stage: false at defaults', () {
      const s = VideoStudioState(stage: EditStage.gif);
      expect(s.hasComparableEdit, isFalse);
    });

    test('gif stage: true when doOptimize set', () {
      const s = VideoStudioState(stage: EditStage.gif, doOptimize: true);
      expect(s.hasComparableEdit, isTrue);
    });

    // The whole reason this getter exists separately from hasPendingApply:
    // a bake resets the live edit fields (so hasPendingApply goes false) but
    // sourceFile is still the baked/changed result — still comparable.
    test('true when editsApplied even with all edit fields back at default', () {
      const s = VideoStudioState(stage: EditStage.video, editsApplied: true);
      expect(s.hasPendingApply, isFalse);
      expect(s.hasComparableEdit, isTrue);
    });

    test('gif stage: true when editsApplied even at default fields', () {
      const s = VideoStudioState(stage: EditStage.gif, editsApplied: true);
      expect(s.hasComparableEdit, isTrue);
    });
  });

  group('VideoStudioState — isToolEdited', () {
    test('crop: true when not full', () {
      final s = VideoStudioState(
        cropNormalized: const Rect.fromLTWH(0.1, 0, 0.9, 1),
      );
      expect(s.isToolEdited(StudioTool.crop), isTrue);
    });

    test('resize: true when targetWidth set', () {
      const s = VideoStudioState(targetWidth: 480);
      expect(s.isToolEdited(StudioTool.resize), isTrue);
    });

    test('properties: video uses hasVolumeChange', () {
      const s = VideoStudioState(
        stage: EditStage.video,
        volume: 1.5,
        sourceInfo: MediaInfo(durationMs: 1000, width: 320, height: 240, hasAudio: true),
      );
      expect(s.isToolEdited(StudioTool.properties), isTrue);
    });

    test('properties: gif uses loopCount/boomerang', () {
      const s = VideoStudioState(stage: EditStage.gif, boomerang: true);
      expect(s.isToolEdited(StudioTool.properties), isTrue);
    });

    test('false at all defaults for every tool', () {
      const s = VideoStudioState();
      for (final t in StudioTool.values) {
        expect(s.isToolEdited(t), isFalse, reason: '$t should be unedited at defaults');
      }
    });
  });

  // ── copyWith ──────────────────────────────────────────────────────────────
  group('VideoStudioState — copyWith', () {
    test('preserves unset fields', () {
      const s = VideoStudioState(fps: 24, loopCount: 3, boomerang: true);
      final s2 = s.copyWith(fps: 15);
      expect(s2.fps, equals(15));
      expect(s2.loopCount, equals(3));
      expect(s2.boomerang, isTrue);
    });

    test('editsApplied defaults to false when not passed', () {
      const applied = VideoStudioState(editsApplied: true);
      final reset = applied.copyWith(fps: 12);
      expect(reset.editsApplied, isFalse);
    });

    test('editsApplied: true is preserved when explicitly passed', () {
      const s = VideoStudioState();
      final applied = s.copyWith(editsApplied: true);
      expect(applied.editsApplied, isTrue);
    });

    test('null-sentinel clears nullable fields', () {
      final s = VideoStudioState(
        sourceFile: File('/foo.gif'),
        targetWidth: 320,
        selectedTextId: 'abc',
      );
      final cleared = s.copyWith(sourceFile: null, targetWidth: null, selectedTextId: null);
      expect(cleared.sourceFile, isNull);
      expect(cleared.targetWidth, isNull);
      expect(cleared.selectedTextId, isNull);
    });
  });

  group('GIF width cap', () {
    test('maxGifWidthFor thresholds', () {
      expect(maxGifWidthFor(14999), equals(1280));
      expect(maxGifWidthFor(15000), equals(1280));
      expect(maxGifWidthFor(24999), equals(1080));
      expect(maxGifWidthFor(25000), equals(1080));
      expect(maxGifWidthFor(40000), equals(800));
    });

    const hdInfo = MediaInfo(durationMs: 240000, width: 1920, height: 1080);

    test('capped: HD source, 40s output', () {
      const s = VideoStudioState(sourceInfo: hdInfo);
      expect(s.gifOutputWidth, equals(1920));
      expect(s.gifWidthCapped, isTrue);
      expect(s.maxGifWidth, equals(800));
    });

    test('not capped: source narrower than cap', () {
      const s = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 240000, width: 640, height: 360),
      );
      expect(s.gifWidthCapped, isFalse);
    });

    test('resize wins over source width', () {
      const s = VideoStudioState(sourceInfo: hdInfo, targetWidth: 480);
      expect(s.gifOutputWidth, equals(480));
      expect(s.gifWidthCapped, isFalse);
    });

    test('crop width counts toward cap', () {
      const s = VideoStudioState(
        sourceInfo: hdInfo,
        cropNormalized: Rect.fromLTWH(0, 0, 0.25, 1),
      );
      expect(s.gifOutputWidth, equals(480));
      expect(s.gifWidthCapped, isFalse);
    });

    test('short trim raises cap to 1280', () {
      const s = VideoStudioState(sourceInfo: hdInfo, trimStartMs: 0, trimEndMs: 10000);
      expect(s.maxGifWidth, equals(1280));
      expect(s.gifWidthCapped, isTrue);
    });
  });

  // ── smoothLoop ────────────────────────────────────────────────────────────
  group('VideoStudioState — smoothLoop', () {
    test('canSmoothLoop false at/under 3s source', () {
      const s = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 3000, width: 320, height: 240),
      );
      expect(s.canSmoothLoop, isFalse);
    });

    test('canSmoothLoop true over 3s source', () {
      const s = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 3001, width: 320, height: 240),
      );
      expect(s.canSmoothLoop, isTrue);
    });

    test('canSmoothLoop false when trim shrinks target under 3s '
        'even though raw source is longer', () {
      const s = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 20000, width: 320, height: 240),
        trimStartMs: 0,
        trimEndMs: 2000,
      );
      expect(s.canSmoothLoop, isFalse);
    });

    test('canSmoothLoop true when trim keeps target over 3s', () {
      const s = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 20000, width: 320, height: 240),
        trimStartMs: 0,
        trimEndMs: 6000,
      );
      expect(s.canSmoothLoop, isTrue);
    });

    test('smoothLoopValid true when effective/speed duration > 2100ms '
        '(default 1000ms crossfade floor)', () {
      const s = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 6000, width: 320, height: 240),
      );
      expect(s.smoothLoopValid, isTrue);
    });

    test('smoothLoopValid false when speed shrinks duration below floor', () {
      const s = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 6000, width: 320, height: 240),
        speedFactor: 4.0, // 6000/4 = 1500ms < 2100
      );
      expect(s.smoothLoopValid, isFalse);
    });

    test('smoothLoopCrossfadeMs defaults to 1000', () {
      const s = VideoStudioState();
      expect(s.smoothLoopCrossfadeMs, equals(1000));
    });

    test('smoothLoopValid floor scales down with a smaller crossfade', () {
      // floor = 2*crossfade+100; at 1000ms floor=2100 (invalid @ 1600ms);
      // at 500ms floor=1100 (valid @ 1600ms).
      const wide = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 1600, width: 320, height: 240),
      );
      expect(wide.smoothLoopValid, isFalse);

      const narrow = VideoStudioState(
        sourceInfo: MediaInfo(durationMs: 1600, width: 320, height: 240),
        smoothLoopCrossfadeMs: 500,
      );
      expect(narrow.smoothLoopValid, isTrue);
    });

    test('copyWith preserves smoothLoopCrossfadeMs', () {
      const s = VideoStudioState(smoothLoopCrossfadeMs: 700);
      final s2 = s.copyWith(fps: 20);
      expect(s2.smoothLoopCrossfadeMs, equals(700));
    });

    test('needsGifEdit true when smoothLoop set', () {
      const s = VideoStudioState(stage: EditStage.gif, smoothLoop: true);
      expect(s.needsGifEdit, isTrue);
    });

    test('isToolEdited(properties) true when smoothLoop set on gif stage', () {
      const s = VideoStudioState(stage: EditStage.gif, smoothLoop: true);
      expect(s.isToolEdited(StudioTool.properties), isTrue);
    });

    test('copyWith preserves smoothLoop', () {
      const s = VideoStudioState(smoothLoop: true);
      final s2 = s.copyWith(fps: 20);
      expect(s2.smoothLoop, isTrue);
    });
  });
}
