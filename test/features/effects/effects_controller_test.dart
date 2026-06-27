import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/providers.dart';
import 'package:gifolomora/core/utils/result.dart';
import 'package:gifolomora/features/effects/controller/effects_controller.dart';

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
  group('EffectsState', () {
    test('defaults: reverse mode, speedFactor=1.5', () {
      const s = EffectsState();
      expect(s.mode, equals(EffectMode.reverse));
      expect(s.speedFactor, equals(1.5));
    });

    test('copyWith updates mode without touching speedFactor', () {
      const s = EffectsState(speedFactor: 2.0);
      final s2 = s.copyWith(mode: EffectMode.speed);
      expect(s2.mode, equals(EffectMode.speed));
      expect(s2.speedFactor, equals(2.0));
    });

    test('hasInput is false without inputFile', () {
      expect(const EffectsState().hasInput, isFalse);
    });

    test('hasInput is true with inputFile', () {
      expect(EffectsState(inputFile: File('/f.gif')).hasInput, isTrue);
    });
  });

  group('EffectsController', () {
    test('initial state is empty and not processing', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final state = await c.read(effectsControllerProvider.future);
      expect(state.hasInput, isFalse);
      expect(state.isProcessing, isFalse);
    });

    test('setInput probes file and stores mediaInfo', () async {
      final backend = FakeFfmpegBackend();
      backend.nextProbeResult =
          const MediaInfo(durationMs: 3000, width: 320, height: 240);

      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(effectsControllerProvider.future);

      await c.read(effectsControllerProvider.notifier).setInput(File('/f.gif'));

      final state = c.read(effectsControllerProvider).value!;
      expect(state.hasInput, isTrue);
      expect(state.mediaInfo?.width, equals(320));
      expect(state.isProbing, isFalse);
    });

    test('setMode switches mode and clears outputGif', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(effectsControllerProvider.future);

      c.read(effectsControllerProvider.notifier).setMode(EffectMode.speed);

      final state = c.read(effectsControllerProvider).value!;
      expect(state.mode, equals(EffectMode.speed));
      expect(state.outputGif, isNull);
    });

    test('setSpeedFactor updates factor', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(effectsControllerProvider.future);

      c.read(effectsControllerProvider.notifier).setSpeedFactor(3.0);

      expect(c.read(effectsControllerProvider).value!.speedFactor, equals(3.0));
    });

    test('generate (reverse mode) success → outputGif set', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/reversed.gif'));
      backend.nextProbeResult =
          const MediaInfo(durationMs: 1000, width: 480, height: 270);

      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(effectsControllerProvider.future);

      final ctrl = c.read(effectsControllerProvider.notifier);
      await ctrl.setInput(File('/input.gif'));
      ctrl.setMode(EffectMode.reverse);
      await ctrl.generate();

      final state = c.read(effectsControllerProvider).value!;
      expect(state.outputGif, isNotNull);
      expect(state.isProcessing, isFalse);
      expect(state.error, isNull);
    });

    test('generate (speed mode) success → outputGif set', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/speed.gif'));
      backend.nextProbeResult =
          const MediaInfo(durationMs: 1000, width: 480, height: 270);

      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(effectsControllerProvider.future);

      final ctrl = c.read(effectsControllerProvider.notifier);
      await ctrl.setInput(File('/input.gif'));
      ctrl.setMode(EffectMode.speed);
      ctrl.setSpeedFactor(2.0);
      await ctrl.generate();

      final state = c.read(effectsControllerProvider).value!;
      expect(state.outputGif, isNotNull);
      expect(state.isProcessing, isFalse);
    });

    test('generate failure → error message set', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = const Err(FfmpegError(message: 'reverse failed'));
      backend.nextProbeResult =
          const MediaInfo(durationMs: 1000, width: 480, height: 270);

      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(effectsControllerProvider.future);

      final ctrl = c.read(effectsControllerProvider.notifier);
      await ctrl.setInput(File('/input.gif'));
      await ctrl.generate();

      final state = c.read(effectsControllerProvider).value!;
      expect(state.error, equals('reverse failed'));
      expect(state.isProcessing, isFalse);
    });

    test('generate skips when no inputFile', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(effectsControllerProvider.future);

      await c.read(effectsControllerProvider.notifier).generate();

      expect(c.read(effectsControllerProvider).value!.isProcessing, isFalse);
    });

    test('cancel resets isProcessing and progress', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(effectsControllerProvider.future);

      await c.read(effectsControllerProvider.notifier).cancel();

      final state = c.read(effectsControllerProvider).value!;
      expect(state.isProcessing, isFalse);
      expect(state.progress, isNull);
    });

    test('clear resets to empty state', () async {
      final backend = FakeFfmpegBackend();
      backend.nextProbeResult =
          const MediaInfo(durationMs: 1000, width: 480, height: 270);

      final c = _makeContainer(ffmpeg: FakeFfmpegService(backend));
      addTearDown(c.dispose);
      await c.read(effectsControllerProvider.future);

      final ctrl = c.read(effectsControllerProvider.notifier);
      await ctrl.setInput(File('/input.gif'));
      ctrl.clear();

      expect(c.read(effectsControllerProvider).value!.hasInput, isFalse);
    });
  });
}
