import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/providers.dart';
import 'package:gifolomora/features/video_studio/controller/video_studio_controller.dart';

import '../../helpers/fakes.dart';

ProviderContainer _makeContainer() {
  final b = FakeFfmpegBackend()
    ..nextProbeResult = const MediaInfo(durationMs: 10000, width: 320, height: 240);
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
  group('VideoStudio Cut — addCutSegment', () {
    test('1. add segment within window → length 1, sorted', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      final ok = ctrl.addCutSegment(2000, 4000);

      expect(ok, isTrue);
      expect(_state(c).cutSegments.length, equals(1));
      expect(_state(c).cutSegments.first, equals((startMs: 2000, endMs: 4000)));
      expect(_state(c).hasCut, isTrue);
    });

    test('2. add overlapping segment → false, list unchanged', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.addCutSegment(2000, 5000);
      final ok = ctrl.addCutSegment(3000, 6000); // overlaps [2000,5000]

      expect(ok, isFalse);
      expect(_state(c).cutSegments.length, equals(1));
    });

    test('3. boundary-touching segments 1000–2000 then 2000–3000 → both accepted', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      final ok1 = ctrl.addCutSegment(1000, 2000);
      final ok2 = ctrl.addCutSegment(2000, 3000);

      expect(ok1, isTrue);
      expect(ok2, isTrue);
      expect(_state(c).cutSegments.length, equals(2));
    });

    test('4. add segment leaving < 1s kept → false', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      // source is 10000 ms; cut 0–9500 leaves 500 ms → reject
      final ok = ctrl.addCutSegment(0, 9500);

      expect(ok, isFalse);
      expect(_state(c).cutSegments, isEmpty);
    });

    test('5. segments added out of order → list sorted by startMs', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.addCutSegment(6000, 7000);
      ctrl.addCutSegment(1000, 2000);
      ctrl.addCutSegment(3000, 4000);

      final segs = _state(c).cutSegments;
      expect(segs.length, equals(3));
      expect(segs[0].startMs, equals(1000));
      expect(segs[1].startMs, equals(3000));
      expect(segs[2].startMs, equals(6000));
    });
  });

  group('VideoStudio Cut — removeCutSegment', () {
    test('6. removeCutSegment removes the right segment', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.addCutSegment(1000, 2000);
      ctrl.addCutSegment(5000, 6000);

      final seg = _state(c).cutSegments.first; // [1000,2000]
      ctrl.removeCutSegment(seg);

      final segs = _state(c).cutSegments;
      expect(segs.length, equals(1));
      expect(segs.first, equals((startMs: 5000, endMs: 6000)));
    });
  });

  group('VideoStudio Cut — cutOutputMs', () {
    test('7. cutOutputMs == trimDurationMs - sum of cut durations', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      // No trim; trimDurationMs = sourceDurationMs = 10000.
      ctrl.addCutSegment(2000, 4000); // 2000 ms cut
      ctrl.addCutSegment(6000, 7000); // 1000 ms cut

      final s = _state(c);
      expect(s.cutDurationMs, equals(3000));
      expect(s.cutOutputMs, equals(7000)); // 10000 - 3000
    });
  });

  group('VideoStudio Cut — trim reconciliation', () {
    test('8a. segment fully outside new trim window → dropped', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      // Add segment at [1000, 2000], then shrink trim start past it.
      ctrl.addCutSegment(1000, 2000);
      expect(_state(c).cutSegments.length, equals(1));

      ctrl.setTrimStart(3000); // segment [1000,2000] is now fully before window

      expect(_state(c).cutSegments, isEmpty);
    });

    test('8b. segment straddling new trimStart → clipped to window edge, kept', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      // Segment spans [1000, 3000]; then we move trim start to 2500.
      ctrl.addCutSegment(1000, 3000);
      expect(_state(c).cutSegments.length, equals(1));

      ctrl.setTrimStart(2500); // clips [1000,3000] → [2500,3000]

      final segs = _state(c).cutSegments;
      expect(segs.length, equals(1));
      expect(segs.first.startMs, equals(2500));
      expect(segs.first.endMs, equals(3000));
    });

    test('8c. segment fully inside new window → untouched', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.addCutSegment(4000, 6000);
      ctrl.setTrimStart(1000); // window [1000,10000]; segment [4000,6000] fully inside

      final segs = _state(c).cutSegments;
      expect(segs.length, equals(1));
      expect(segs.first, equals((startMs: 4000, endMs: 6000)));
    });
  });

  group('VideoStudio Cut — keepRanges', () {
    test('9. keepRanges = correct complement within trim window', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      // No trim → window [0, 10000].
      ctrl.addCutSegment(3000, 5000);

      final ranges = _state(c).keepRanges;
      expect(ranges, equals([
        (startMs: 0, endMs: 3000),
        (startMs: 5000, endMs: 10000),
      ]));
    });

    test('keepRanges empty cutSegments → single range covering full window', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await _loadVideo(c);

      final ranges = _state(c).keepRanges;
      expect(ranges, equals([(startMs: 0, endMs: 10000)]));
    });

    test('resetCut clears all segments', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      ctrl.addCutSegment(1000, 2000);
      ctrl.addCutSegment(5000, 6000);
      expect(_state(c).hasCut, isTrue);

      ctrl.resetCut();

      expect(_state(c).cutSegments, isEmpty);
      expect(_state(c).hasCut, isFalse);
    });
  });
}
