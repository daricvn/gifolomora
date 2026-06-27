import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/providers.dart';
import 'package:gifolomora/core/utils/result.dart';
import 'package:gifolomora/features/crop/controller/crop_controller.dart';

import '../../helpers/fakes.dart';

ProviderContainer _makeContainer({FakeFfmpegService? ffmpeg}) {
  final backend = FakeFfmpegBackend();
  return ProviderContainer(overrides: [
    ffmpegServiceProvider.overrideWithValue(ffmpeg ?? FakeFfmpegService(backend)),
    exportServiceProvider.overrideWithValue(FakeExportService()),
    recentsServiceProvider.overrideWithValue(FakeRecentsService()),
  ]);
}

void main() {
  group('CropState', () {
    test('default cropNormalized is full frame (0,0,1,1)', () {
      const s = CropState();
      expect(s.cropNormalized, equals(const Rect.fromLTWH(0, 0, 1, 1)));
    });

    test('cropX/Y/W/H denormalize against mediaInfo dimensions', () {
      const s = CropState(
        mediaInfo: MediaInfo(durationMs: 1000, width: 400, height: 200),
        cropNormalized: Rect.fromLTWH(0.25, 0.5, 0.5, 0.5),
      );
      expect(s.cropX, equals(100));
      expect(s.cropY, equals(100));
      expect(s.cropW, equals(200));
      expect(s.cropH, equals(100));
    });

    test('cropW and cropH are clamped to minimum 2', () {
      const s = CropState(
        mediaInfo: MediaInfo(durationMs: 1000, width: 100, height: 100),
        cropNormalized: Rect.fromLTWH(0, 0, 0, 0),
      );
      expect(s.cropW, equals(2));
      expect(s.cropH, equals(2));
    });

    test('imageWidth/imageHeight return 0 without mediaInfo', () {
      const s = CropState();
      expect(s.imageWidth, equals(0));
      expect(s.imageHeight, equals(0));
    });

    test('hasValidMedia requires both inputFile and mediaInfo', () {
      expect(const CropState().hasValidMedia, isFalse);
      expect(
        CropState(inputFile: File('/f.gif')).hasValidMedia,
        isFalse,
      );
    });

    test('hasInput only requires inputFile', () {
      expect(CropState(inputFile: File('/f.gif')).hasInput, isTrue);
    });
  });

  group('CropController', () {
    test('initial state is empty', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final state = await c.read(cropControllerProvider.future);
      expect(state.hasInput, isFalse);
      expect(state.isProcessing, isFalse);
    });

    test('setInput with successful probe stores mediaInfo', () async {
      final backend = FakeFfmpegBackend();
      backend.nextProbeResult =
          const MediaInfo(durationMs: 2000, width: 480, height: 270);

      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(cropControllerProvider.future);

      await c.read(cropControllerProvider.notifier).setInput(File('/input.gif'));

      final state = c.read(cropControllerProvider).value!;
      expect(state.hasInput, isTrue);
      expect(state.mediaInfo?.width, equals(480));
      expect(state.mediaInfo?.height, equals(270));
      expect(state.isProbing, isFalse);
    });

    test('setInput with null probe sets error', () async {
      final backend = FakeFfmpegBackend();
      backend.nextProbeResult = null;

      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(cropControllerProvider.future);

      await c.read(cropControllerProvider.notifier).setInput(File('/bad.gif'));

      final state = c.read(cropControllerProvider).value!;
      expect(state.error, isNotNull);
      expect(state.error, contains('metadata'));
    });

    test('setCrop updates cropNormalized', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(cropControllerProvider.future);

      const newCrop = Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
      c.read(cropControllerProvider.notifier).setCrop(newCrop);

      expect(c.read(cropControllerProvider).value!.cropNormalized, equals(newCrop));
    });

    test('resetCrop restores full-frame rect', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(cropControllerProvider.future);

      final ctrl = c.read(cropControllerProvider.notifier);
      ctrl.setCrop(const Rect.fromLTWH(0.1, 0.1, 0.5, 0.5));
      ctrl.resetCrop();

      expect(
        c.read(cropControllerProvider).value!.cropNormalized,
        equals(const Rect.fromLTWH(0, 0, 1, 1)),
      );
    });

    test('generate success → outputGif set, isProcessing=false', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/cropped.gif'));
      backend.nextProbeResult =
          const MediaInfo(durationMs: 1000, width: 480, height: 270);

      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(cropControllerProvider.future);

      final ctrl = c.read(cropControllerProvider.notifier);
      await ctrl.setInput(File('/input.gif'));
      await ctrl.generate();

      final state = c.read(cropControllerProvider).value!;
      expect(state.outputGif, isNotNull);
      expect(state.isProcessing, isFalse);
      expect(state.error, isNull);
    });

    test('generate failure → error set, isProcessing=false', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = const Err(FfmpegError(message: 'crop failed'));
      backend.nextProbeResult =
          const MediaInfo(durationMs: 1000, width: 480, height: 270);

      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(cropControllerProvider.future);

      final ctrl = c.read(cropControllerProvider.notifier);
      await ctrl.setInput(File('/input.gif'));
      await ctrl.generate();

      final state = c.read(cropControllerProvider).value!;
      expect(state.error, equals('crop failed'));
      expect(state.isProcessing, isFalse);
    });

    test('generate skips when no valid media', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(cropControllerProvider.future);

      await c.read(cropControllerProvider.notifier).generate();

      expect(c.read(cropControllerProvider).value!.isProcessing, isFalse);
    });

    test('clear resets state to empty', () async {
      final backend = FakeFfmpegBackend();
      backend.nextProbeResult =
          const MediaInfo(durationMs: 1000, width: 480, height: 270);

      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(cropControllerProvider.future);

      final ctrl = c.read(cropControllerProvider.notifier);
      await ctrl.setInput(File('/input.gif'));
      ctrl.clear();

      expect(c.read(cropControllerProvider).value!.hasInput, isFalse);
    });
  });
}
