import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/files/export_service.dart';
import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';

class OptimizeState {
  const OptimizeState({
    this.inputFile,
    this.mediaInfo,
    this.colors = 128,
    this.lossy = 40,
    this.frameDrop = 0,
    this.outputGif,
    this.progress,
    this.isProcessing = false,
    this.isProbing = false,
    this.error,
  });

  final File? inputFile;
  final MediaInfo? mediaInfo;
  final int colors;
  final int lossy;
  final int frameDrop; // 0 = keep all; 2/3/4 = remove 1 of every N frames
  final File? outputGif;
  final FfmpegProgress? progress;
  final bool isProcessing;
  final bool isProbing;
  final String? error;

  bool get hasInput => inputFile != null;
  int get originalWidth => mediaInfo?.width ?? 0;
  int get originalHeight => mediaInfo?.height ?? 0;

  OptimizeState copyWith({
    Object? inputFile = _s,
    Object? mediaInfo = _s,
    int? colors,
    int? lossy,
    int? frameDrop,
    Object? outputGif = _s,
    Object? progress = _s,
    bool? isProcessing,
    bool? isProbing,
    Object? error = _s,
  }) {
    return OptimizeState(
      inputFile: identical(inputFile, _s) ? this.inputFile : inputFile as File?,
      mediaInfo: identical(mediaInfo, _s) ? this.mediaInfo : mediaInfo as MediaInfo?,
      colors: colors ?? this.colors,
      lossy: lossy ?? this.lossy,
      frameDrop: frameDrop ?? this.frameDrop,
      outputGif: identical(outputGif, _s) ? this.outputGif : outputGif as File?,
      progress: identical(progress, _s) ? this.progress : progress as FfmpegProgress?,
      isProcessing: isProcessing ?? this.isProcessing,
      isProbing: isProbing ?? this.isProbing,
      error: identical(error, _s) ? this.error : error as String?,
    );
  }

  static const _s = Object();
}

class OptimizeController extends AsyncNotifier<OptimizeState> {
  @override
  Future<OptimizeState> build() async => const OptimizeState();

  FfmpegService get _ffmpeg => ref.read(ffmpegServiceProvider);
  ExportService get _export => ref.read(exportServiceProvider);

  Future<void> setInput(File file) async {
    state = AsyncData(OptimizeState(inputFile: file, isProbing: true));
    final info = await _ffmpeg.probe(file);
    state = AsyncData(OptimizeState(inputFile: file, mediaInfo: info));
  }

  void setColors(int colors) {
    final s = state.valueOrNull ?? const OptimizeState();
    state = AsyncData(s.copyWith(colors: colors, outputGif: null, error: null));
  }

  void setLossy(int lossy) {
    final s = state.valueOrNull ?? const OptimizeState();
    state = AsyncData(s.copyWith(lossy: lossy, outputGif: null, error: null));
  }

  void setFrameDrop(int frameDrop) {
    final s = state.valueOrNull ?? const OptimizeState();
    state =
        AsyncData(s.copyWith(frameDrop: frameDrop, outputGif: null, error: null));
  }

  Future<void> generate() async {
    final s = state.valueOrNull;
    if (s == null || s.inputFile == null || s.isProcessing) return;

    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, outputGif: null));

    final result = await _ffmpeg.optimizeGif(
      input: s.inputFile!,
      colors: s.colors,
      lossy: s.lossy,
      frameDrop: s.frameDrop,
    );

    final cur = state.valueOrNull ?? const OptimizeState();
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
            toolName: 'Optimize GIF',
            toolRoute: '/optimize',
            timestamp: DateTime.now(),
          ));
    }
    return saved != null;
  }

  Future<void> cancel() async {
    await _ffmpeg.cancel();
    await _ffmpeg.cleanCurrentJob();
    final s = state.valueOrNull ?? const OptimizeState();
    state = AsyncData(s.copyWith(isProcessing: false, progress: null));
  }

  void clear() {
    _ffmpeg.cleanCurrentJob();
    state = const AsyncData(OptimizeState());
  }
}

final optimizeControllerProvider =
    AsyncNotifierProvider<OptimizeController, OptimizeState>(
  OptimizeController.new,
);
