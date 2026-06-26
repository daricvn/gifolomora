import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/files/export_service.dart';
import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';

class VideoToGifState {
  const VideoToGifState({
    this.inputFile,
    this.mediaInfo,
    this.startMs = 0,
    this.endMs = 0,
    this.fps = 15,
    this.width,
    this.outputGif,
    this.progress,
    this.isProcessing = false,
    this.isProbing = false,
    this.error,
  });

  final File? inputFile;
  final MediaInfo? mediaInfo;
  final int startMs;
  final int endMs; // 0 = full video end
  final int fps;
  final int? width;
  final File? outputGif;
  final FfmpegProgress? progress;
  final bool isProcessing;
  final bool isProbing;
  final String? error;

  bool get hasInput => inputFile != null;
  int get totalMs => mediaInfo?.durationMs ?? 0;
  int get effectiveEndMs => endMs > 0 ? endMs : totalMs;
  int get trimDurationMs => totalMs > 0 ? (effectiveEndMs - startMs).clamp(0, totalMs) : 0;

  VideoToGifState copyWith({
    Object? inputFile = _s,
    Object? mediaInfo = _s,
    int? startMs,
    int? endMs,
    int? fps,
    Object? width = _s,
    Object? outputGif = _s,
    Object? progress = _s,
    bool? isProcessing,
    bool? isProbing,
    Object? error = _s,
  }) {
    return VideoToGifState(
      inputFile: identical(inputFile, _s) ? this.inputFile : inputFile as File?,
      mediaInfo: identical(mediaInfo, _s) ? this.mediaInfo : mediaInfo as MediaInfo?,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      fps: fps ?? this.fps,
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

class VideoToGifController extends AsyncNotifier<VideoToGifState> {
  @override
  Future<VideoToGifState> build() async => const VideoToGifState();

  FfmpegService get _ffmpeg => ref.read(ffmpegServiceProvider);
  ExportService get _export => ref.read(exportServiceProvider);

  Future<void> setInput(File file) async {
    state = AsyncData(VideoToGifState(inputFile: file, isProbing: true));
    final info = await _ffmpeg.probe(file);
    state = AsyncData(VideoToGifState(
      inputFile: file,
      mediaInfo: info,
      startMs: 0,
      endMs: info?.durationMs ?? 0,
      error: info == null ? 'Could not read video metadata' : null,
    ));
  }

  void setStart(int ms) {
    final s = state.valueOrNull ?? const VideoToGifState();
    final max = s.effectiveEndMs > 1000 ? s.effectiveEndMs - 1000 : 0;
    state = AsyncData(s.copyWith(startMs: ms.clamp(0, max), outputGif: null, error: null));
  }

  void setEnd(int ms) {
    final s = state.valueOrNull ?? const VideoToGifState();
    final min = s.startMs + 1000;
    state = AsyncData(s.copyWith(endMs: ms.clamp(min, s.totalMs), outputGif: null, error: null));
  }

  void setFps(int fps) {
    final s = state.valueOrNull ?? const VideoToGifState();
    state = AsyncData(s.copyWith(fps: fps, outputGif: null));
  }

  void setWidth(int? width) {
    final s = state.valueOrNull ?? const VideoToGifState();
    state = AsyncData(s.copyWith(width: width, outputGif: null));
  }

  Future<void> generate() async {
    final s = state.valueOrNull;
    if (s == null || s.inputFile == null || s.isProcessing) return;

    state = AsyncData(s.copyWith(
      isProcessing: true, progress: null, error: null, outputGif: null));

    final start = s.startMs > 0 ? Duration(milliseconds: s.startMs) : null;
    final duration = s.effectiveEndMs < s.totalMs
        ? Duration(milliseconds: s.trimDurationMs)
        : null;
    final progressTotalMs = s.trimDurationMs > 0 ? s.trimDurationMs : s.totalMs;

    final result = await _ffmpeg.videoToGif(
      input: s.inputFile!,
      start: start,
      duration: duration,
      fps: s.fps,
      width: s.width,
      totalMs: progressTotalMs > 0 ? progressTotalMs : null,
      onProgress: (p) {
        final cur = state.valueOrNull;
        if (cur != null) state = AsyncData(cur.copyWith(progress: p));
      },
    );

    final cur = state.valueOrNull ?? const VideoToGifState();
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
            toolName: 'Video → GIF',
            toolRoute: '/video-to-gif',
            timestamp: DateTime.now(),
          ));
    }
    return saved != null;
  }

  Future<void> cancel() async {
    await _ffmpeg.cancel();
    await _ffmpeg.cleanCurrentJob();
    final s = state.valueOrNull ?? const VideoToGifState();
    state = AsyncData(s.copyWith(isProcessing: false, progress: null));
  }

  void clear() {
    _ffmpeg.cleanCurrentJob();
    state = const AsyncData(VideoToGifState());
  }
}

final videoToGifControllerProvider =
    AsyncNotifierProvider<VideoToGifController, VideoToGifState>(
  VideoToGifController.new,
);
