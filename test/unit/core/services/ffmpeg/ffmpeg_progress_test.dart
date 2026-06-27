import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';

void main() {
  group('FfmpegProgress', () {
    test('stores fraction and optional fields', () {
      const p = FfmpegProgress(fraction: 0.75, framesDone: 10, timeMs: 3000);
      expect(p.fraction, equals(0.75));
      expect(p.framesDone, equals(10));
      expect(p.timeMs, equals(3000));
    });

    test('optional fields default to null', () {
      const p = FfmpegProgress(fraction: 0.5);
      expect(p.framesDone, isNull);
      expect(p.timeMs, isNull);
    });
  });

  group('FfmpegError', () {
    test('toString includes exit code and message', () {
      const e = FfmpegError(message: 'failed', exitCode: 1);
      expect(e.toString(), equals('FfmpegError(exit=1): failed'));
    });

    test('toString with null exitCode', () {
      const e = FfmpegError(message: 'no code');
      expect(e.toString(), equals('FfmpegError(exit=null): no code'));
    });

    test('stderr is stored but not part of toString', () {
      const e = FfmpegError(message: 'fail', exitCode: 2, stderr: 'panic');
      expect(e.stderr, equals('panic'));
      expect(e.toString(), isNot(contains('panic')));
    });
  });

  group('MediaInfo', () {
    test('stores all required fields', () {
      const m = MediaInfo(durationMs: 2000, width: 480, height: 270, fps: 15.0);
      expect(m.durationMs, equals(2000));
      expect(m.width, equals(480));
      expect(m.height, equals(270));
      expect(m.fps, equals(15.0));
    });

    test('fps is nullable', () {
      const m = MediaInfo(durationMs: 1000, width: 320, height: 240);
      expect(m.fps, isNull);
    });
  });
}
