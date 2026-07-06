import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/providers.dart';
import 'package:gifolomora/core/utils/result.dart';
import 'package:gifolomora/features/video_studio/controller/video_studio_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

VideoStudioState _state(ProviderContainer c) =>
    c.read(videoStudioControllerProvider).value!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('VideoStudio — Apply / Export (video stage)', () {
    late FakeFfmpegBackend backend;
    late FakeExportService export;
    late ProviderContainer c;

    Future<VideoStudioController> loadVideo() async {
      await c.read(videoStudioControllerProvider.future);
      final ctrl = c.read(videoStudioControllerProvider.notifier);
      await ctrl.setInput(File('/input.mp4'));
      return ctrl;
    }

    setUp(() {
      backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.mp4'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 1000, width: 320, height: 240);
      export = FakeExportService();
      c = ProviderContainer(overrides: [
        ffmpegServiceProvider.overrideWithValue(FakeFfmpegService(backend)),
        exportServiceProvider.overrideWithValue(export),
        recentsServiceProvider.overrideWithValue(FakeRecentsService()),
      ]);
    });

    tearDown(() => c.dispose());

    test('applyVideoEdits with nothing pending returns false', () async {
      final ctrl = await loadVideo();
      final ok = await ctrl.applyVideoEdits();
      expect(ok, isFalse);
      expect(_state(c).editsApplied, isFalse);
    });

    test('applyVideoEdits bakes edits, swaps preview, sets editsApplied',
        () async {
      final ctrl = await loadVideo();
      ctrl.setResize(160); // targetWidth set → hasEdits

      final ok = await ctrl.applyVideoEdits();

      expect(ok, isTrue);
      expect(_state(c).editsApplied, isTrue);
      expect(_state(c).sourceFile!.path, equals('/fake/output.mp4'));
      // Baked → layers reset so a later export does not double-apply.
      expect(_state(c).targetWidth, isNull);
    });

    test('Export after Apply saves the baked file without re-encoding',
        () async {
      final ctrl = await loadVideo();
      ctrl.setResize(160);
      await ctrl.applyVideoEdits();
      final runsAfterApply = backend.runCount;

      final ok = await ctrl.exportVideo();

      expect(ok, isTrue);
      // Saved the already-baked source, no new encode pass.
      expect(export.savedVideoSource!.path, equals('/fake/output.mp4'));
      expect(backend.runCount, equals(runsAfterApply));
    });

    test('changing an option after Apply clears editsApplied (re-encodes)',
        () async {
      final ctrl = await loadVideo();
      ctrl.setResize(160);
      await ctrl.applyVideoEdits();
      expect(_state(c).editsApplied, isTrue);

      ctrl.setSpeed(2.0); // any option change clears the applied flag
      expect(_state(c).editsApplied, isFalse);
    });

    test('apply with cut segment is not a no-op (encode runs, editsApplied set)',
        () async {
      // Source must be long enough that cut leaves ≥ 1000ms kept.
      backend.nextProbeResult =
          const MediaInfo(durationMs: 5000, width: 320, height: 240);
      final ctrl = await loadVideo();

      // Cut 1000ms from a 5000ms source → 4000ms kept ≥ 1000ms.
      final ok = ctrl.addCutSegment(1000, 2000);
      expect(ok, isTrue);
      expect(_state(c).hasCut, isTrue);

      final runsBefore = backend.runCount;
      final applied = await ctrl.applyVideoEdits();

      expect(applied, isTrue);
      expect(_state(c).editsApplied, isTrue);
      expect(backend.runCount, greaterThan(runsBefore));
    });
  });
}
