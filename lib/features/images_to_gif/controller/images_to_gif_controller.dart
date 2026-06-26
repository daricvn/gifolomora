import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/files/export_service.dart';
import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';

class ImagesToGifState {
  const ImagesToGifState({
    this.frames = const [],
    this.fps = 15,
    this.width,
    this.outputGif,
    this.progress,
    this.isProcessing = false,
    this.error,
  });

  final List<File> frames;
  final int fps;
  final int? width;         // null = keep original
  final File? outputGif;   // last generated gif in temp
  final FfmpegProgress? progress;
  final bool isProcessing;
  final String? error;

  bool get hasFrames => frames.isNotEmpty;

  ImagesToGifState copyWith({
    List<File>? frames,
    int? fps,
    Object? width = _sentinel,
    Object? outputGif = _sentinel,
    Object? progress = _sentinel,
    bool? isProcessing,
    Object? error = _sentinel,
  }) {
    return ImagesToGifState(
      frames: frames ?? this.frames,
      fps: fps ?? this.fps,
      width: identical(width, _sentinel) ? this.width : width as int?,
      outputGif: identical(outputGif, _sentinel) ? this.outputGif : outputGif as File?,
      progress: identical(progress, _sentinel) ? this.progress : progress as FfmpegProgress?,
      isProcessing: isProcessing ?? this.isProcessing,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

class ImagesToGifController extends AsyncNotifier<ImagesToGifState> {
  @override
  Future<ImagesToGifState> build() async => const ImagesToGifState();

  FfmpegService get _ffmpeg => ref.read(ffmpegServiceProvider);
  ExportService get _export => ref.read(exportServiceProvider);

  void addFrames(List<File> files) {
    final current = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(current.copyWith(
      frames: [...current.frames, ...files],
      outputGif: null,
      error: null,
    ));
  }

  void removeFrame(int index) {
    final current = state.valueOrNull ?? const ImagesToGifState();
    final newFrames = List<File>.from(current.frames)..removeAt(index);
    state = AsyncData(current.copyWith(frames: newFrames, outputGif: null));
  }

  void reorderFrames(int oldIndex, int newIndex) {
    final current = state.valueOrNull ?? const ImagesToGifState();
    final frames = List<File>.from(current.frames);
    final item = frames.removeAt(oldIndex);
    frames.insert(newIndex, item);
    state = AsyncData(current.copyWith(frames: frames, outputGif: null));
  }

  void setFps(int fps) {
    final current = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(current.copyWith(fps: fps, outputGif: null));
  }

  void setWidth(int? width) {
    final current = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(current.copyWith(width: width, outputGif: null));
  }

  void clearFrames() {
    _ffmpeg.cleanCurrentJob();
    state = const AsyncData(ImagesToGifState());
  }

  Future<void> generate() async {
    final current = state.valueOrNull;
    if (current == null || current.frames.isEmpty) return;
    if (current.isProcessing) return;

    state = AsyncData(current.copyWith(
      isProcessing: true,
      progress: null,
      error: null,
      outputGif: null,
    ));

    final result = await _ffmpeg.imagesToGif(
      frames: current.frames,
      fps: current.fps,
      width: current.width,
      onProgress: (p) {
        final s = state.valueOrNull;
        if (s != null) {
          state = AsyncData(s.copyWith(progress: p));
        }
      },
    );

    final s = state.valueOrNull ?? const ImagesToGifState();
    result.fold(
      ok: (file) => state = AsyncData(s.copyWith(
        outputGif: file,
        isProcessing: false,
        progress: null,
      )),
      err: (err) => state = AsyncData(s.copyWith(
        isProcessing: false,
        progress: null,
        error: err.message,
      )),
    );
  }

  Future<bool> exportGif() async {
    final current = state.valueOrNull;
    if (current?.outputGif == null) return false;

    final saved = await _export.saveGif(current!.outputGif!);
    if (saved != null) {
      await _ffmpeg.cleanCurrentJob();
      await ref.read(recentsProvider.notifier).add(RecentExport(
            path: saved.path,
            toolName: 'Images → GIF',
            toolRoute: '/images-to-gif',
            timestamp: DateTime.now(),
          ));
    }
    return saved != null;
  }

  Future<void> cancel() async {
    await _ffmpeg.cancel();
    await _ffmpeg.cleanCurrentJob();
    final s = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(s.copyWith(isProcessing: false, progress: null));
  }
}

final imagesToGifControllerProvider =
    AsyncNotifierProvider<ImagesToGifController, ImagesToGifState>(
  ImagesToGifController.new,
);
