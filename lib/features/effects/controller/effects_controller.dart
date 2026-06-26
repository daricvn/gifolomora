import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/files/export_service.dart';
import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';

enum EffectMode { reverse, speed }

class EffectsState {
  const EffectsState({
    this.inputFile,
    this.mediaInfo,
    this.mode = EffectMode.reverse,
    this.speedFactor = 1.5,
    this.outputGif,
    this.progress,
    this.isProcessing = false,
    this.isProbing = false,
    this.error,
  });

  final File? inputFile;
  final MediaInfo? mediaInfo;
  final EffectMode mode;
  final double speedFactor;
  final File? outputGif;
  final FfmpegProgress? progress;
  final bool isProcessing;
  final bool isProbing;
  final String? error;

  bool get hasInput => inputFile != null;
  int get originalWidth => mediaInfo?.width ?? 0;
  int get originalHeight => mediaInfo?.height ?? 0;

  EffectsState copyWith({
    Object? inputFile = _s,
    Object? mediaInfo = _s,
    EffectMode? mode,
    double? speedFactor,
    Object? outputGif = _s,
    Object? progress = _s,
    bool? isProcessing,
    bool? isProbing,
    Object? error = _s,
  }) {
    return EffectsState(
      inputFile: identical(inputFile, _s) ? this.inputFile : inputFile as File?,
      mediaInfo: identical(mediaInfo, _s) ? this.mediaInfo : mediaInfo as MediaInfo?,
      mode: mode ?? this.mode,
      speedFactor: speedFactor ?? this.speedFactor,
      outputGif: identical(outputGif, _s) ? this.outputGif : outputGif as File?,
      progress: identical(progress, _s) ? this.progress : progress as FfmpegProgress?,
      isProcessing: isProcessing ?? this.isProcessing,
      isProbing: isProbing ?? this.isProbing,
      error: identical(error, _s) ? this.error : error as String?,
    );
  }

  static const _s = Object();
}

class EffectsController extends AsyncNotifier<EffectsState> {
  @override
  Future<EffectsState> build() async => const EffectsState();

  FfmpegService get _ffmpeg => ref.read(ffmpegServiceProvider);
  ExportService get _export => ref.read(exportServiceProvider);

  Future<void> setInput(File file) async {
    state = AsyncData(EffectsState(inputFile: file, isProbing: true));
    final info = await _ffmpeg.probe(file);
    state = AsyncData(EffectsState(inputFile: file, mediaInfo: info));
  }

  void setMode(EffectMode mode) {
    final s = state.valueOrNull ?? const EffectsState();
    state = AsyncData(s.copyWith(mode: mode, outputGif: null, error: null));
  }

  void setSpeedFactor(double factor) {
    final s = state.valueOrNull ?? const EffectsState();
    state = AsyncData(s.copyWith(speedFactor: factor, outputGif: null, error: null));
  }

  Future<void> generate() async {
    final s = state.valueOrNull;
    if (s == null || s.inputFile == null || s.isProcessing) return;

    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, outputGif: null));

    final result = switch (s.mode) {
      EffectMode.reverse => await _ffmpeg.reverseGif(
          input: s.inputFile!,
          totalMs: s.mediaInfo?.durationMs,
          onProgress: (p) {
            final cur = state.valueOrNull;
            if (cur != null) state = AsyncData(cur.copyWith(progress: p));
          },
        ),
      EffectMode.speed => await _ffmpeg.changeSpeed(
          input: s.inputFile!,
          factor: s.speedFactor,
          totalMs: s.mediaInfo?.durationMs,
          onProgress: (p) {
            final cur = state.valueOrNull;
            if (cur != null) state = AsyncData(cur.copyWith(progress: p));
          },
        ),
    };

    final cur = state.valueOrNull ?? const EffectsState();
    result.fold(
      ok: (file) => state = AsyncData(
          cur.copyWith(outputGif: file, isProcessing: false, progress: null)),
      err: (err) => state = AsyncData(
          cur.copyWith(isProcessing: false, progress: null, error: err.message)),
    );
  }

  Future<bool> exportGif() async {
    final s = state.valueOrNull;
    if (s?.outputGif == null) return false;
    final saved = await _export.saveGif(s!.outputGif!);
    if (saved != null) {
      await _ffmpeg.cleanCurrentJob();
      await ref.read(recentsProvider.notifier).add(RecentExport(
            path: saved.path,
            toolName: 'Effects',
            toolRoute: '/effects',
            timestamp: DateTime.now(),
          ));
    }
    return saved != null;
  }

  Future<void> cancel() async {
    await _ffmpeg.cancel();
    await _ffmpeg.cleanCurrentJob();
    final s = state.valueOrNull ?? const EffectsState();
    state = AsyncData(s.copyWith(isProcessing: false, progress: null));
  }

  void clear() {
    _ffmpeg.cleanCurrentJob();
    state = const AsyncData(EffectsState());
  }
}

final effectsControllerProvider =
    AsyncNotifierProvider<EffectsController, EffectsState>(
  EffectsController.new,
);
