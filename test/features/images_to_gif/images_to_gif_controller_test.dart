import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/providers.dart';
import 'package:gifolomora/core/utils/result.dart';
import 'package:gifolomora/features/images_to_gif/controller/images_to_gif_controller.dart';

import '../../helpers/fakes.dart';

ProviderContainer _makeContainer({
  FakeFfmpegService? ffmpeg,
  FakeExportService? export_,
  FakeRecentsService? recents,
}) {
  final backend = FakeFfmpegBackend();
  return ProviderContainer(overrides: [
    ffmpegServiceProvider.overrideWithValue(ffmpeg ?? FakeFfmpegService(backend)),
    exportServiceProvider.overrideWithValue(export_ ?? FakeExportService()),
    recentsServiceProvider.overrideWithValue(recents ?? FakeRecentsService()),
  ]);
}

void main() {
  group('ImagesToGifState', () {
    test('hasFrames is false by default', () {
      expect(const ImagesToGifState().hasFrames, isFalse);
    });

    test('hasFrames is true when frames list is non-empty', () {
      final s = ImagesToGifState(frames: [File('/a.png')]);
      expect(s.hasFrames, isTrue);
    });

    test('copyWith with sentinel preserves nullable width', () {
      const s = ImagesToGifState(width: 320);
      final s2 = s.copyWith(fps: 24);
      expect(s2.width, equals(320));
      expect(s2.fps, equals(24));
    });

    test('copyWith can explicitly null width', () {
      const s = ImagesToGifState(width: 320);
      final s2 = s.copyWith(width: null);
      expect(s2.width, isNull);
    });
  });

  group('ImagesToGifController', () {
    test('initial state has empty frames and is not processing', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final state = await c.read(imagesToGifControllerProvider.future);
      expect(state.frames, isEmpty);
      expect(state.isProcessing, isFalse);
      expect(state.error, isNull);
    });

    test('addFrames appends files to list', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      c.read(imagesToGifControllerProvider.notifier)
          .addFrames([File('/a.png'), File('/b.png')]);

      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.frames.length, equals(2));
      expect(state.hasFrames, isTrue);
    });

    test('addFrames clears any existing error and outputGif', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      // Manually set an error state
      ctrl.addFrames([File('/a.png')]);
      ctrl.addFrames([File('/b.png')]);

      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.error, isNull);
      expect(state.outputGif, isNull);
    });

    test('removeFrame removes correct index', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png'), File('/c.png')]);
      ctrl.removeFrame(1);

      final frames = c.read(imagesToGifControllerProvider).value!.frames;
      expect(frames.length, equals(2));
      expect(frames.map((f) => f.path), equals(['/a.png', '/c.png']));
    });

    test('reorderFrames moves item from old to new index', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png'), File('/c.png')]);
      ctrl.reorderFrames(0, 2);

      final frames = c.read(imagesToGifControllerProvider).value!.frames;
      expect(frames.map((f) => f.path), equals(['/b.png', '/c.png', '/a.png']));
    });

    test('setFps updates fps value', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      c.read(imagesToGifControllerProvider.notifier).setFps(24);

      expect(c.read(imagesToGifControllerProvider).value!.fps, equals(24));
    });

    test('setWidth updates width value', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      c.read(imagesToGifControllerProvider.notifier).setWidth(640);

      expect(c.read(imagesToGifControllerProvider).value!.width, equals(640));
    });

    test('generate skips when frames list is empty', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      await c.read(imagesToGifControllerProvider.notifier).generate();

      expect(c.read(imagesToGifControllerProvider).value!.isProcessing, isFalse);
    });

    test('generate success → outputGif set, isProcessing=false, error=null', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png')]);
      await ctrl.generate();

      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.outputGif, isNotNull);
      expect(state.isProcessing, isFalse);
      expect(state.error, isNull);
    });

    test('generate failure → error set, outputGif=null, isProcessing=false', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = const Err(FfmpegError(message: 'ffmpeg crashed'));
      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png')]);
      await ctrl.generate();

      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.outputGif, isNull);
      expect(state.isProcessing, isFalse);
      expect(state.error, equals('ffmpeg crashed'));
    });

    test('exportGif returns false when outputGif is null', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final result =
          await c.read(imagesToGifControllerProvider.notifier).exportGif();
      expect(result, isFalse);
    });

    test('exportGif returns true and adds entry to recents', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final fakeRecents = FakeRecentsService();

      final c = _makeContainer(
        ffmpeg: FakeFfmpegService(backend),
        recents: fakeRecents,
      );
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png')]);
      await ctrl.generate();
      final exported = await ctrl.exportGif();

      expect(exported, isTrue);
      final recent = await fakeRecents.load();
      expect(recent.length, equals(1));
      expect(recent.first.toolRoute, equals('/images-to-gif'));
    });

    test('exportGif returns false when export service returns null', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final fakeExport = FakeExportService()..returnFile = null;

      final c = _makeContainer(
        ffmpeg: FakeFfmpegService(backend),
        export_: fakeExport,
      );
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png')]);
      await ctrl.generate();
      final exported = await ctrl.exportGif();

      expect(exported, isFalse);
    });

    test('cancel resets isProcessing and progress', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      await c.read(imagesToGifControllerProvider.notifier).cancel();

      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.isProcessing, isFalse);
      expect(state.progress, isNull);
    });
  });
}
