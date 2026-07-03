import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/providers.dart';
import 'package:gifolomora/features/video_studio/controller/video_studio_controller.dart';

import '../../helpers/fakes.dart';

ProviderContainer _makeContainer({int durationMs = 10000}) {
  final b = FakeFfmpegBackend()
    ..nextProbeResult = MediaInfo(durationMs: durationMs, width: 320, height: 240);
  return ProviderContainer(overrides: [
    ffmpegServiceProvider.overrideWithValue(FakeFfmpegService(b)),
    exportServiceProvider.overrideWithValue(FakeExportService()),
    recentsServiceProvider.overrideWithValue(FakeRecentsService()),
  ]);
}

VideoStudioState _state(ProviderContainer c) =>
    c.read(videoStudioControllerProvider).value!;

Future<VideoStudioController> _loadVideo(ProviderContainer c) async {
  await c.read(videoStudioControllerProvider.future);
  final ctrl = c.read(videoStudioControllerProvider.notifier);
  await ctrl.setInput(File('/input.mp4'));
  return ctrl;
}

void main() {
  group('VideoStudio Trim — setTrimStart', () {
    test('1. valid value → trimStartMs set, hasTrim true, tool marked edited', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.setTrimStart(2000);

      final s = _state(c);
      expect(s.trimStartMs, equals(2000));
      expect(s.hasTrim, isTrue);
      expect(s.isToolEdited(StudioTool.trim), isTrue);
    });

    test('2. negative value → clamped to 0', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.setTrimStart(-500);

      expect(_state(c).trimStartMs, equals(0));
    });

    test('3. value exceeding max → clamped to effectiveTrimEndMs - 1000', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      // source is 10000 ms, no trimEnd set → effectiveTrimEndMs = 10000.
      ctrl.setTrimStart(50000);

      expect(_state(c).trimStartMs, equals(9000));
    });

    test('4. boundary value == effectiveTrimEndMs - 1000 → accepted exactly', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.setTrimStart(9000);

      expect(_state(c).trimStartMs, equals(9000));
    });

    test('5. moving start past existing cut segment end → segment dropped', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.addCutSegment(500, 1500);
      ctrl.setTrimStart(2000);

      expect(_state(c).cutSegments, isEmpty);
    });
  });

  group('VideoStudio Trim — setTrimEnd', () {
    test('6. valid value → trimEndMs set, hasTrim true', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.setTrimEnd(8000);

      final s = _state(c);
      expect(s.trimEndMs, equals(8000));
      expect(s.hasTrim, isTrue);
    });

    test('7. value below trimStartMs + 1000 → clamped up to min', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.setTrimStart(3000);
      ctrl.setTrimEnd(3200); // below 3000 + 1000 min

      expect(_state(c).trimEndMs, equals(4000));
    });

    test('8. value above sourceDurationMs → clamped down to sourceDurationMs', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.setTrimEnd(999999);

      expect(_state(c).trimEndMs, equals(10000));
    });

    test('9. boundary value == trimStartMs + 1000 → accepted exactly', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.setTrimStart(3000);
      ctrl.setTrimEnd(4000);

      expect(_state(c).trimEndMs, equals(4000));
    });

    test('10. trimEndMs set equal to sourceDurationMs → hasTrim stays false', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.setTrimEnd(10000); // == sourceDurationMs, not "< sourceDurationMs"

      final s = _state(c);
      expect(s.trimEndMs, equals(10000));
      expect(s.hasTrim, isFalse);
    });

    test('11. shrinking end past existing cut segment start → segment clipped to new end', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.addCutSegment(7000, 9000);
      ctrl.setTrimEnd(8000); // clips [7000,9000] → [7000,8000]

      final segs = _state(c).cutSegments;
      expect(segs.length, equals(1));
      expect(segs.first, equals((startMs: 7000, endMs: 8000)));
    });
  });

  group('VideoStudio Trim — resetTrim', () {
    test('12. resets trimStartMs and trimEndMs to 0 → hasTrim false, tool not edited', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.setTrimStart(2000);
      ctrl.setTrimEnd(8000);
      expect(_state(c).hasTrim, isTrue);

      ctrl.resetTrim();

      final s = _state(c);
      expect(s.trimStartMs, equals(0));
      expect(s.trimEndMs, equals(0));
      expect(s.hasTrim, isFalse);
      expect(s.isToolEdited(StudioTool.trim), isFalse);
    });

    test('13. widening window back does not restore segments already clipped', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.addCutSegment(1000, 3000);
      ctrl.setTrimStart(2000); // clips segment to [2000,3000]
      expect(_state(c).cutSegments.first, equals((startMs: 2000, endMs: 3000)));

      ctrl.resetTrim(); // window widens back to full [0,10000]

      // Segment stays clipped — resetTrim only re-clips to the new (wider)
      // window, it never restores data that a prior narrower clip discarded.
      expect(_state(c).cutSegments.first, equals((startMs: 2000, endMs: 3000)));
    });
  });

  group('VideoStudio Trim — derived getters', () {
    test('14. effectiveTrimEndMs falls back to sourceDurationMs when trimEndMs unset', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      expect(_state(c).effectiveTrimEndMs, equals(10000));

      ctrl.setTrimEnd(6000);

      expect(_state(c).effectiveTrimEndMs, equals(6000));
    });

    test('15. trimDurationMs reflects the active [trimStart, effectiveTrimEnd] window', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.setTrimStart(2000);
      ctrl.setTrimEnd(7000);

      expect(_state(c).trimDurationMs, equals(5000));
    });

    test('16. cutOutputMs combines trim window with cuts inside it', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.setTrimStart(1000);
      ctrl.setTrimEnd(9000); // window = 8000 ms
      ctrl.addCutSegment(3000, 4000); // 1000 ms cut inside window

      final s = _state(c);
      expect(s.trimDurationMs, equals(8000));
      expect(s.cutOutputMs, equals(7000));
    });
  });
}
