import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/files/export_service.dart';
import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';

class ResizeState {
  const ResizeState({
    this.inputFile,
    this.mediaInfo,
    this.width,
    this.outputGif,
    this.progress,
    this.isProcessing = false,
    this.isProbing = false,
    this.error,
  });

  final File? inputFile;
  final MediaInfo? mediaInfo;
  final int? width; // null = original
  final File? outputGif;
  final FfmpegProgress? progress;
  final bool isProcessing;
  final bool isProbing;
  final String? error;

  bool get hasInput => inputFile != null;
  int get originalWidth => mediaInfo?.width ?? 0;
  int get originalHeight => mediaInfo?.height ?? 0;

  ResizeState copyWith({
    Object? inputFile = _s,
    Object? mediaInfo = _s,
    Object? width = _s,
    Object? outputGif = _s,
    Object? progress = _s,
    bool? isProcessing,
    bool? isProbing,
    Object? error = _s,
  }) {
    return ResizeState(
      inputFile: identical(inputFile, _s) ? this.inputFile : inputFile as File?,
      mediaInfo: identical(mediaInfo, _s) ? this.mediaInfo : mediaInfo as MediaInfo?,
      width: identical(width, _s) ? this.width : width as int?,
      outputGif: identical(outputGif, _s) ? this.outputGif : outputGif as File?,
      progress: identical(progress, _s) ? this.progress : progress as FfmpegProgress?,
      isProcessing: isProcessing ?? this.isProcessing,
      isProbing: isProbing ?? this.isProbing,
      error: identical(error, _s) ? this.error : error as String?,
    );
  }

  static const _s = Object();
}

class ResizeController extends AsyncNotifier<ResizeState> {
  @override
  Future<ResizeState> build() async => const ResizeState();

  FfmpegService get _ffmpeg => ref.read(ffmpegServiceProvider);
  ExportService get _export => ref.read(exportServiceProvider);

  Future<void> setInput(File file) async {
    state = AsyncData(ResizeState(inputFile: file, isProbing: true));
    final info = await _ffmpeg.probe(file);
    state = AsyncData(ResizeState(
      inputFile: file,
      mediaInfo: info,
      width: info?.width,
    ));
  }

  void setWidth(int? width) {
    final s = state.valueOrNull ?? const ResizeState();
    state = AsyncData(s.copyWith(width: width, outputGif: null, error: null));
  }

  Future<void> generate() async {
    final s = state.valueOrNull;
    if (s == null || s.inputFile == null || s.isProcessing) return;

    state = AsyncData(s.copyWith(
      isProcessing: true, progress: null, error: null, outputGif: null));

    final result = await _ffmpeg.resizeGif(
      input: s.inputFile!,
      width: s.width,
      totalMs: s.mediaInfo?.durationMs,
      onProgress: (p) {
        final cur = state.valueOrNull;
        if (cur != null) state = AsyncData(cur.copyWith(progress: p));
      },
    );

    final cur = state.valueOrNull ?? const ResizeState();
    result.fold(
      ok: (file) => state = AsyncData(cur.copyWith(
        outputGif: file, isProcessing: false, progress: null)),
      err: (err) => state = AsyncData(cur.copyWith(
        isProcessing: false, progress: null, error: err.message)),
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
            toolName: 'Resize GIF',
            toolRoute: '/resize',
            timestamp: DateTime.now(),
          ));
    }
    return saved != null;
  }

  Future<void> cancel() async {
    await _ffmpeg.cancel();
    await _ffmpeg.cleanCurrentJob();
    final s = state.valueOrNull ?? const ResizeState();
    state = AsyncData(s.copyWith(isProcessing: false, progress: null));
  }

  void clear() {
    _ffmpeg.cleanCurrentJob();
    state = const AsyncData(ResizeState());
  }
}

final resizeControllerProvider =
    AsyncNotifierProvider<ResizeController, ResizeState>(
  ResizeController.new,
);
