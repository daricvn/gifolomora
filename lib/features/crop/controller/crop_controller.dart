import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/files/export_service.dart';
import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';

class CropState {
  const CropState({
    this.inputFile,
    this.mediaInfo,
    this.cropNormalized = const Rect.fromLTWH(0, 0, 1, 1),
    this.outputGif,
    this.progress,
    this.isProcessing = false,
    this.isProbing = false,
    this.error,
  });

  final File? inputFile;
  final MediaInfo? mediaInfo;
  final Rect cropNormalized; // each coord in 0..1
  final File? outputGif;
  final FfmpegProgress? progress;
  final bool isProcessing;
  final bool isProbing;
  final String? error;

  bool get hasInput => inputFile != null;
  bool get hasValidMedia => inputFile != null && mediaInfo != null;
  int get imageWidth => mediaInfo?.width ?? 0;
  int get imageHeight => mediaInfo?.height ?? 0;

  int get cropX => (cropNormalized.left * imageWidth).round();
  int get cropY => (cropNormalized.top * imageHeight).round();
  int get cropW => (cropNormalized.width * imageWidth).clamp(2, imageWidth).round();
  int get cropH => (cropNormalized.height * imageHeight).clamp(2, imageHeight).round();

  CropState copyWith({
    Object? inputFile = _s,
    Object? mediaInfo = _s,
    Rect? cropNormalized,
    Object? outputGif = _s,
    Object? progress = _s,
    bool? isProcessing,
    bool? isProbing,
    Object? error = _s,
  }) {
    return CropState(
      inputFile: identical(inputFile, _s) ? this.inputFile : inputFile as File?,
      mediaInfo: identical(mediaInfo, _s) ? this.mediaInfo : mediaInfo as MediaInfo?,
      cropNormalized: cropNormalized ?? this.cropNormalized,
      outputGif: identical(outputGif, _s) ? this.outputGif : outputGif as File?,
      progress: identical(progress, _s) ? this.progress : progress as FfmpegProgress?,
      isProcessing: isProcessing ?? this.isProcessing,
      isProbing: isProbing ?? this.isProbing,
      error: identical(error, _s) ? this.error : error as String?,
    );
  }

  static const _s = Object();
}

class CropController extends AsyncNotifier<CropState> {
  @override
  Future<CropState> build() async => const CropState();

  FfmpegService get _ffmpeg => ref.read(ffmpegServiceProvider);
  ExportService get _export => ref.read(exportServiceProvider);

  Future<void> setInput(File file) async {
    state = AsyncData(CropState(inputFile: file, isProbing: true));
    final info = await _ffmpeg.probe(file);
    state = AsyncData(CropState(
      inputFile: file,
      mediaInfo: info,
      cropNormalized: const Rect.fromLTWH(0, 0, 1, 1),
      error: info == null ? 'Could not read GIF metadata' : null,
    ));
  }

  void setCrop(Rect normalized) {
    final s = state.valueOrNull ?? const CropState();
    state = AsyncData(s.copyWith(cropNormalized: normalized, outputGif: null, error: null));
  }

  void resetCrop() {
    final s = state.valueOrNull ?? const CropState();
    state = AsyncData(s.copyWith(
      cropNormalized: const Rect.fromLTWH(0, 0, 1, 1),
      outputGif: null,
    ));
  }

  Future<void> generate() async {
    final s = state.valueOrNull;
    if (s == null || !s.hasValidMedia || s.isProcessing || s.imageWidth == 0) return;

    state = AsyncData(s.copyWith(
      isProcessing: true, progress: null, error: null, outputGif: null));

    final result = await _ffmpeg.cropGif(
      input: s.inputFile!,
      x: s.cropX,
      y: s.cropY,
      cropWidth: s.cropW,
      cropHeight: s.cropH,
      totalMs: s.mediaInfo?.durationMs,
      onProgress: (p) {
        final cur = state.valueOrNull;
        if (cur != null) state = AsyncData(cur.copyWith(progress: p));
      },
    );

    final cur = state.valueOrNull ?? const CropState();
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
            toolName: 'Crop GIF',
            toolRoute: '/crop',
            timestamp: DateTime.now(),
          ));
    }
    return saved != null;
  }

  Future<void> cancel() async {
    await _ffmpeg.cancel();
    await _ffmpeg.cleanCurrentJob();
    final s = state.valueOrNull ?? const CropState();
    state = AsyncData(s.copyWith(isProcessing: false, progress: null));
  }

  void clear() {
    _ffmpeg.cleanCurrentJob();
    state = const AsyncData(CropState());
  }
}

final cropControllerProvider =
    AsyncNotifierProvider<CropController, CropState>(
  CropController.new,
);
