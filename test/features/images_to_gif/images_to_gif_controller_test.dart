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

/// FfmpegService with per-step result overrides for pipeline tests.
class _StepwiseFfmpegService extends FakeFfmpegService {
  _StepwiseFfmpegService(super.backend);

  Result<File, FfmpegError>? textOverlayResult;
  Result<File, FfmpegError>? optimizeResult;
  bool textOverlayCalled = false;
  bool optimizeCalled = false;

  @override
  Future<Result<File, FfmpegError>> textOverlay({
    required File input,
    required String text,
    required String fontFile,
    int fontSize = 36,
    String fontColor = 'white',
    String position = 'center',
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    textOverlayCalled = true;
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return textOverlayResult ?? fakeBackend.nextResult;
  }

  @override
  Future<Result<File, FfmpegError>> optimizeGif({
    required File input,
    int colors = 128,
    int lossy = 40,
    int? loopCount,
    int frameDrop = 0,
    bool localPalettes = false,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    optimizeCalled = true;
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return optimizeResult ?? fakeBackend.nextResult;
  }
}

/// Controller override that forces overlayFontFile to a fixed value.
class _FixedFontController extends ImagesToGifController {
  _FixedFontController(this._fontFile);
  final String? _fontFile;

  @override
  Future<ImagesToGifState> build() async =>
      ImagesToGifState(overlayFontFile: _fontFile);
}

ProviderContainer _makeStepwiseContainer({
  required _StepwiseFfmpegService ffmpeg,
  String? fontFile = '/fake/font.ttf',
  FakeExportService? export_,
  FakeRecentsService? recents,
}) {
  return ProviderContainer(overrides: [
    imagesToGifControllerProvider
        .overrideWith(() => _FixedFontController(fontFile)),
    ffmpegServiceProvider.overrideWithValue(ffmpeg),
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

    // canGenerate
    test('canGenerate is false with empty frames', () {
      expect(const ImagesToGifState().canGenerate, isFalse);
    });

    test('canGenerate is false with exactly 1 frame', () {
      final s = ImagesToGifState(frames: [File('/a.png')]);
      expect(s.canGenerate, isFalse);
    });

    test('canGenerate is true with exactly 2 frames', () {
      final s = ImagesToGifState(frames: [File('/a.png'), File('/b.png')]);
      expect(s.canGenerate, isTrue);
    });

    test('canGenerate is true with many frames', () {
      final s = ImagesToGifState(
          frames: List.generate(10, (i) => File('/frame_$i.png')));
      expect(s.canGenerate, isTrue);
    });

    // hasText
    test('hasText is false for empty string', () {
      expect(const ImagesToGifState(overlayText: '').hasText, isFalse);
    });

    test('hasText is false for whitespace-only string', () {
      expect(const ImagesToGifState(overlayText: '   ').hasText, isFalse);
    });

    test('hasText is true for non-empty text', () {
      expect(const ImagesToGifState(overlayText: 'Hello').hasText, isTrue);
    });

    test('hasText is true for text with surrounding whitespace', () {
      expect(const ImagesToGifState(overlayText: '  Hi  ').hasText, isTrue);
    });

    // defaults
    test('default fps is 15', () {
      expect(const ImagesToGifState().fps, equals(15));
    });

    test('default overlayPosition is center', () {
      expect(const ImagesToGifState().overlayPosition, equals('center'));
    });

    test('default overlayFontSize is 36', () {
      expect(const ImagesToGifState().overlayFontSize, equals(36));
    });

    test('default overlayFontColor is white', () {
      expect(const ImagesToGifState().overlayFontColor, equals('white'));
    });

    test('default doOptimize is false', () {
      expect(const ImagesToGifState().doOptimize, isFalse);
    });

    test('default optimizeColors is 128', () {
      expect(const ImagesToGifState().optimizeColors, equals(128));
    });

    test('default optimizeLossy is 40', () {
      expect(const ImagesToGifState().optimizeLossy, equals(40));
    });

    // copyWith sentinels for other nullable fields
    test('copyWith preserves overlayFontFile via sentinel', () {
      const s = ImagesToGifState(overlayFontFile: '/fake/font.ttf');
      final s2 = s.copyWith(fps: 24);
      expect(s2.overlayFontFile, equals('/fake/font.ttf'));
    });

    test('copyWith can null overlayFontFile', () {
      const s = ImagesToGifState(overlayFontFile: '/fake/font.ttf');
      final s2 = s.copyWith(overlayFontFile: null);
      expect(s2.overlayFontFile, isNull);
    });

    test('copyWith preserves outputGif via sentinel', () {
      final s = ImagesToGifState(outputGif: File('/out.gif'));
      final s2 = s.copyWith(fps: 10);
      expect(s2.outputGif?.path, equals('/out.gif'));
    });

    test('copyWith can null outputGif', () {
      final s = ImagesToGifState(outputGif: File('/out.gif'));
      final s2 = s.copyWith(outputGif: null);
      expect(s2.outputGif, isNull);
    });

    test('copyWith preserves error via sentinel', () {
      const s = ImagesToGifState(error: 'boom');
      final s2 = s.copyWith(fps: 10);
      expect(s2.error, equals('boom'));
    });

    test('copyWith can null error', () {
      const s = ImagesToGifState(error: 'boom');
      final s2 = s.copyWith(error: null);
      expect(s2.error, isNull);
    });

    test('copyWith preserves progress via sentinel', () {
      const p = FfmpegProgress(fraction: 0.5);
      const s = ImagesToGifState(progress: p);
      final s2 = s.copyWith(fps: 10);
      expect(s2.progress?.fraction, equals(0.5));
    });

    test('copyWith can null progress', () {
      const s = ImagesToGifState(progress: FfmpegProgress(fraction: 0.5));
      final s2 = s.copyWith(progress: null);
      expect(s2.progress, isNull);
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

    test('generate skips when only 1 frame (requires at least 2)', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png')]);
      await ctrl.generate();

      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.outputGif, isNull);
      expect(state.isProcessing, isFalse);
    });

    test('generate success → outputGif set, isProcessing=false, error=null', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
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
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
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
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
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
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
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

    // ── Setters ────────────────────────────────────────────────────────────

    test('setOverlayText updates text and clears outputGif', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      await ctrl.generate();
      // outputGif is now set; changing text must clear it
      ctrl.setOverlayText('caption');

      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.overlayText, equals('caption'));
      expect(state.outputGif, isNull);
      expect(state.error, isNull);
    });

    test('setOverlayPosition updates position', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      c.read(imagesToGifControllerProvider.notifier).setOverlayPosition('top');

      expect(
          c.read(imagesToGifControllerProvider).value!.overlayPosition,
          equals('top'));
    });

    test('setOverlayFontSize updates font size', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      c.read(imagesToGifControllerProvider.notifier).setOverlayFontSize(64);

      expect(
          c.read(imagesToGifControllerProvider).value!.overlayFontSize,
          equals(64));
    });

    test('setOverlayFontColor updates font color', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      c.read(imagesToGifControllerProvider.notifier).setOverlayFontColor('red');

      expect(
          c.read(imagesToGifControllerProvider).value!.overlayFontColor,
          equals('red'));
    });

    test('setDoOptimize enables optimization flag', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      c.read(imagesToGifControllerProvider.notifier).setDoOptimize(true);

      expect(c.read(imagesToGifControllerProvider).value!.doOptimize, isTrue);
    });

    test('setDoOptimize disables optimization flag', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.setDoOptimize(true);
      ctrl.setDoOptimize(false);

      expect(c.read(imagesToGifControllerProvider).value!.doOptimize, isFalse);
    });

    test('setOptimizeColors updates colors', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      c.read(imagesToGifControllerProvider.notifier).setOptimizeColors(64);

      expect(
          c.read(imagesToGifControllerProvider).value!.optimizeColors,
          equals(64));
    });

    test('setOptimizeLossy updates lossy', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      c.read(imagesToGifControllerProvider.notifier).setOptimizeLossy(20);

      expect(
          c.read(imagesToGifControllerProvider).value!.optimizeLossy,
          equals(20));
    });

    test('setWidth to null clears width', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.setWidth(480);
      ctrl.setWidth(null);

      expect(c.read(imagesToGifControllerProvider).value!.width, isNull);
    });

    test('setFps clears previous outputGif', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      await ctrl.generate();
      expect(c.read(imagesToGifControllerProvider).value!.outputGif, isNotNull);

      ctrl.setFps(10);
      expect(c.read(imagesToGifControllerProvider).value!.outputGif, isNull);
    });

    // ── Frame operations edge cases ────────────────────────────────────────

    test('addFrames accumulates across multiple calls', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png')]);
      ctrl.addFrames([File('/b.png'), File('/c.png')]);

      final frames = c.read(imagesToGifControllerProvider).value!.frames;
      expect(frames.length, equals(3));
      expect(frames.map((f) => f.path),
          equals(['/a.png', '/b.png', '/c.png']));
    });

    test('removeFrame at index 0 removes first element', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png'), File('/c.png')]);
      ctrl.removeFrame(0);

      final frames = c.read(imagesToGifControllerProvider).value!.frames;
      expect(frames.map((f) => f.path), equals(['/b.png', '/c.png']));
    });

    test('removeFrame at last index removes last element', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png'), File('/c.png')]);
      ctrl.removeFrame(2);

      final frames = c.read(imagesToGifControllerProvider).value!.frames;
      expect(frames.map((f) => f.path), equals(['/a.png', '/b.png']));
    });

    test('reorderFrames last to first', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png'), File('/c.png')]);
      ctrl.reorderFrames(2, 0);

      final frames = c.read(imagesToGifControllerProvider).value!.frames;
      expect(frames.map((f) => f.path),
          equals(['/c.png', '/a.png', '/b.png']));
    });

    test('clearFrames empties frames and resets processing state', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      await ctrl.generate();
      ctrl.clearFrames();

      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.frames, isEmpty);
      expect(state.outputGif, isNull);
      expect(state.error, isNull);
      expect(state.isProcessing, isFalse);
    });

    // ── Generate pipeline ──────────────────────────────────────────────────

    test('generate with text overlay calls text step and succeeds', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final stepwise = _StepwiseFfmpegService(backend);
      final c = _makeStepwiseContainer(ffmpeg: stepwise);
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      ctrl.setOverlayText('Hello');
      await ctrl.generate();

      expect(stepwise.textOverlayCalled, isTrue);
      expect(
          c.read(imagesToGifControllerProvider).value!.outputGif, isNotNull);
    });

    test('generate skips text overlay when text is whitespace-only', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final stepwise = _StepwiseFfmpegService(backend);
      final c = _makeStepwiseContainer(ffmpeg: stepwise);
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      ctrl.setOverlayText('   ');
      await ctrl.generate();

      expect(stepwise.textOverlayCalled, isFalse);
      expect(
          c.read(imagesToGifControllerProvider).value!.outputGif, isNotNull);
    });

    test('generate skips text overlay when overlayFontFile is null', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final stepwise = _StepwiseFfmpegService(backend);
      // fontFile = null → text step must be skipped even with text set
      final c = _makeStepwiseContainer(ffmpeg: stepwise, fontFile: null);
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      ctrl.setOverlayText('Hello');
      await ctrl.generate();

      expect(stepwise.textOverlayCalled, isFalse);
      expect(
          c.read(imagesToGifControllerProvider).value!.outputGif, isNotNull);
    });

    test('generate text overlay failure sets error with prefix', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final stepwise = _StepwiseFfmpegService(backend)
        ..textOverlayResult =
            const Err(FfmpegError(message: 'font not found'));
      final c = _makeStepwiseContainer(ffmpeg: stepwise);
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      ctrl.setOverlayText('Hello');
      await ctrl.generate();

      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.outputGif, isNull);
      expect(state.error, equals('Text overlay: font not found'));
      expect(state.isProcessing, isFalse);
    });

    test('generate with optimize enabled calls optimize step', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final stepwise = _StepwiseFfmpegService(backend);
      final c = _makeStepwiseContainer(ffmpeg: stepwise);
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      ctrl.setDoOptimize(true);
      await ctrl.generate();

      expect(stepwise.optimizeCalled, isTrue);
      expect(
          c.read(imagesToGifControllerProvider).value!.outputGif, isNotNull);
    });

    test('generate optimize failure sets error with prefix', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final stepwise = _StepwiseFfmpegService(backend)
        ..optimizeResult =
            const Err(FfmpegError(message: 'optimizer failed'));
      final c = _makeStepwiseContainer(ffmpeg: stepwise);
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      ctrl.setDoOptimize(true);
      await ctrl.generate();

      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.outputGif, isNull);
      expect(state.error, equals('Optimize: optimizer failed'));
      expect(state.isProcessing, isFalse);
    });

    test('generate with all three steps (base + text + optimize) succeeds',
        () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final stepwise = _StepwiseFfmpegService(backend);
      final c = _makeStepwiseContainer(ffmpeg: stepwise);
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      ctrl.setOverlayText('Hi');
      ctrl.setDoOptimize(true);
      await ctrl.generate();

      expect(stepwise.textOverlayCalled, isTrue);
      expect(stepwise.optimizeCalled, isTrue);
      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.outputGif, isNotNull);
      expect(state.error, isNull);
      expect(state.isProcessing, isFalse);
    });

    test('generate clears previous outputGif before running', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/first.gif'));
      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      await ctrl.generate();
      expect(
          c.read(imagesToGifControllerProvider).value!.outputGif, isNotNull);

      // Second generate — outputGif must be null during processing
      final captured = <File?>[];
      final sub = c.listen(imagesToGifControllerProvider, (_, next) {
        captured.add(next.valueOrNull?.outputGif);
      });
      backend.nextResult = Ok(File('/fake/second.gif'));
      await ctrl.generate();
      sub.close();

      // First captured state is the "isProcessing=true" one — outputGif null
      expect(captured.first, isNull);
    });

    test('generate fires progress callback', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final progressSeen = <FfmpegProgress?>[];
      final sub = c.listen(imagesToGifControllerProvider, (_, next) {
        progressSeen.add(next.valueOrNull?.progress);
      });

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      await ctrl.generate();
      sub.close();

      expect(progressSeen, contains(isNotNull));
    });

    test('cancel when not processing is safe (no-op)', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      // Should not throw
      await c.read(imagesToGifControllerProvider.notifier).cancel();

      final state = c.read(imagesToGifControllerProvider).value!;
      expect(state.isProcessing, isFalse);
    });

    // ── Export edge cases ──────────────────────────────────────────────────

    test('exportGif does not add to recents when save returns null', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      final fakeExport = FakeExportService()..returnFile = null;
      final fakeRecents = FakeRecentsService();
      final c = _makeContainer(
        ffmpeg: FakeFfmpegService(backend),
        export_: fakeExport,
        recents: fakeRecents,
      );
      addTearDown(c.dispose);
      await c.read(imagesToGifControllerProvider.future);

      final ctrl = c.read(imagesToGifControllerProvider.notifier);
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      await ctrl.generate();
      await ctrl.exportGif();

      final recent = await fakeRecents.load();
      expect(recent, isEmpty);
    });

    test('exportGif recent entry has correct toolName', () async {
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
      ctrl.addFrames([File('/a.png'), File('/b.png')]);
      await ctrl.generate();
      await ctrl.exportGif();

      final recent = await fakeRecents.load();
      expect(recent.first.toolName, equals('Images → GIF'));
    });
  });
}
