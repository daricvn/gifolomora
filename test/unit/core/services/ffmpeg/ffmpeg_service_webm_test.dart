import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/utils/result.dart';

import '../../../../helpers/fakes.dart';

void main() {
  group('FfmpegService.supportsAv1', () {
    test('caches result — backend probed only once across repeated calls', () async {
      final backend = FakeFfmpegBackend()..nextSupportsEncoder = true;
      final service = FakeFfmpegService(backend);

      final a = await service.supportsAv1();
      final b = await service.supportsAv1();
      final c = await service.supportsAv1();

      expect(a, isTrue);
      expect(b, isTrue);
      expect(c, isTrue);
      expect(backend.supportsEncoderCallCount, equals(1));
      expect(backend.lastSupportsEncoderArg, equals('libaom-av1'));
    });

    test('false result also cached (no repeated probing on unsupported platform)',
        () async {
      final backend = FakeFfmpegBackend()..nextSupportsEncoder = false;
      final service = FakeFfmpegService(backend);

      expect(await service.supportsAv1(), isFalse);
      expect(await service.supportsAv1(), isFalse);
      expect(backend.supportsEncoderCallCount, equals(1));
    });
  });

  group('FfmpegService.convertToWebm', () {
    test('success returns backend output file', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/job/output.webm'));
      final service = FakeFfmpegService(backend);

      final result = await service.convertToWebm(
        input: File('/input.mp4'),
        crf: 32,
        cpuUsed: 4,
      );

      expect(result.isOk, isTrue);
      expect(result.value.path, equals('/fake/job/output.webm'));
    });

    test('backend error propagates as Err', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = const Err(FfmpegError(message: 'encode failed'));
      final service = FakeFfmpegService(backend);

      final result = await service.convertToWebm(
        input: File('/input.mp4'),
        crf: 32,
        cpuUsed: 4,
      );

      expect(result.isErr, isTrue);
      expect(result.error.message, equals('encode failed'));
    });

    test('progress callback forwarded from backend.run', () async {
      final backend = FakeFfmpegBackend();
      final service = FakeFfmpegService(backend);
      var lastFraction = -1.0;

      await service.convertToWebm(
        input: File('/input.mp4'),
        crf: 32,
        cpuUsed: 4,
        onProgress: (p) => lastFraction = p.fraction,
      );

      expect(lastFraction, equals(1.0));
    });
  });

  group('FfmpegService.editVideo — webm isNoOp guard', () {
    test('webm:true with no crop/scale/speed/text/trim/cut still runs a real encode (no stream-copy)',
        () async {
      final backend = FakeFfmpegBackend();
      final service = FakeFfmpegService(backend);

      await service.editVideo(
        input: File('/input.mp4'),
        hasAudio: true,
        webm: true,
      );

      // isNoOp forced false by webm:true — must hit the VP9 encode branch,
      // never the '-c copy' stream-copy shortcut.
      expect(backend.lastRunArgs, isNot(contains('copy')));
      expect(backend.lastRunArgs, contains('libvpx-vp9'));
    });

    test('identical options with webm:false takes the stream-copy no-op path (regression guard)',
        () async {
      final backend = FakeFfmpegBackend();
      final service = FakeFfmpegService(backend);

      await service.editVideo(
        input: File('/input.mp4'),
        hasAudio: true,
        webm: false,
      );

      expect(backend.lastRunArgs, contains('copy'));
      expect(backend.lastRunArgs, isNot(contains('libvpx-vp9')));
    });
  });
}
