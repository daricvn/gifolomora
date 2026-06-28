import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/files/export_service.dart';
import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';
import '../../../core/utils/font_resolver.dart';

class ImagesToGifState {
  const ImagesToGifState({
    this.frames = const [],
    this.fps = 15,
    this.width,
    // text overlay
    this.overlayText = '',
    this.overlayPosition = 'center',
    this.overlayFontSize = 36,
    this.overlayFontColor = 'white',
    this.overlayFontFile,
    // optimize
    this.doOptimize = false,
    this.optimizeColors = 128,
    this.optimizeLossy = 40,
    this.outputGif,
    this.progress,
    this.isProcessing = false,
    this.error,
  });

  final List<File> frames;
  final int fps;
  final int? width;

  final String overlayText;
  final String overlayPosition;
  final int overlayFontSize;
  final String overlayFontColor;
  final String? overlayFontFile;

  final bool doOptimize;
  final int optimizeColors;
  final int optimizeLossy;

  final File? outputGif;
  final FfmpegProgress? progress;
  final bool isProcessing;
  final String? error;

  bool get hasFrames => frames.isNotEmpty;
  bool get canGenerate => frames.length >= 2;
  bool get hasText => overlayText.trim().isNotEmpty;

  ImagesToGifState copyWith({
    List<File>? frames,
    int? fps,
    Object? width = _sentinel,
    String? overlayText,
    String? overlayPosition,
    int? overlayFontSize,
    String? overlayFontColor,
    Object? overlayFontFile = _sentinel,
    bool? doOptimize,
    int? optimizeColors,
    int? optimizeLossy,
    Object? outputGif = _sentinel,
    Object? progress = _sentinel,
    bool? isProcessing,
    Object? error = _sentinel,
  }) {
    return ImagesToGifState(
      frames: frames ?? this.frames,
      fps: fps ?? this.fps,
      width: identical(width, _sentinel) ? this.width : width as int?,
      overlayText: overlayText ?? this.overlayText,
      overlayPosition: overlayPosition ?? this.overlayPosition,
      overlayFontSize: overlayFontSize ?? this.overlayFontSize,
      overlayFontColor: overlayFontColor ?? this.overlayFontColor,
      overlayFontFile: identical(overlayFontFile, _sentinel)
          ? this.overlayFontFile
          : overlayFontFile as String?,
      doOptimize: doOptimize ?? this.doOptimize,
      optimizeColors: optimizeColors ?? this.optimizeColors,
      optimizeLossy: optimizeLossy ?? this.optimizeLossy,
      outputGif:
          identical(outputGif, _sentinel) ? this.outputGif : outputGif as File?,
      progress: identical(progress, _sentinel)
          ? this.progress
          : progress as FfmpegProgress?,
      isProcessing: isProcessing ?? this.isProcessing,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

class ImagesToGifController extends AsyncNotifier<ImagesToGifState> {
  @override
  Future<ImagesToGifState> build() async =>
      ImagesToGifState(overlayFontFile: FontResolver.resolve());

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

  void setOverlayText(String text) {
    final s = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(s.copyWith(overlayText: text, outputGif: null, error: null));
  }

  void setOverlayPosition(String position) {
    final s = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(
        s.copyWith(overlayPosition: position, outputGif: null, error: null));
  }

  void setOverlayFontSize(int size) {
    final s = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(
        s.copyWith(overlayFontSize: size, outputGif: null, error: null));
  }

  void setOverlayFontColor(String color) {
    final s = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(
        s.copyWith(overlayFontColor: color, outputGif: null, error: null));
  }

  void setDoOptimize(bool value) {
    final s = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(s.copyWith(doOptimize: value, outputGif: null));
  }

  void setOptimizeColors(int colors) {
    final s = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(s.copyWith(optimizeColors: colors, outputGif: null));
  }

  void setOptimizeLossy(int lossy) {
    final s = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(s.copyWith(optimizeLossy: lossy, outputGif: null));
  }

  void clearFrames() {
    _ffmpeg.cleanCurrentJob();
    state = AsyncData(
        ImagesToGifState(overlayFontFile: FontResolver.resolve()));
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

    void onProgress(FfmpegProgress p) {
      final s = state.valueOrNull;
      if (s != null) state = AsyncData(s.copyWith(progress: p));
    }

    // Step 1: base GIF from frames
    final baseResult = await _ffmpeg.imagesToGif(
      frames: current.frames,
      fps: current.fps,
      width: current.width,
      onProgress: onProgress,
    );

    if (baseResult.isErr) {
      final s = state.valueOrNull ?? const ImagesToGifState();
      state = AsyncData(s.copyWith(
          isProcessing: false,
          progress: null,
          error: baseResult.error.message));
      return;
    }

    File gif = baseResult.value;

    // Step 2: optional text overlay
    final text = current.overlayText.trim();
    if (text.isNotEmpty && current.overlayFontFile != null) {
      final textResult = await _ffmpeg.textOverlay(
        input: gif,
        text: text,
        fontFile: current.overlayFontFile!,
        fontSize: current.overlayFontSize,
        fontColor: current.overlayFontColor,
        position: current.overlayPosition,
        onProgress: onProgress,
      );
      if (textResult.isErr) {
        final s = state.valueOrNull ?? const ImagesToGifState();
        state = AsyncData(s.copyWith(
            isProcessing: false,
            progress: null,
            error: 'Text overlay: ${textResult.error.message}'));
        return;
      }
      gif = textResult.value;
    }

    // Step 3: optional optimize
    if (current.doOptimize) {
      final optResult = await _ffmpeg.optimizeGif(
        input: gif,
        colors: current.optimizeColors,
        lossy: current.optimizeLossy,
        onProgress: onProgress,
      );
      if (optResult.isErr) {
        final s = state.valueOrNull ?? const ImagesToGifState();
        state = AsyncData(s.copyWith(
            isProcessing: false,
            progress: null,
            error: 'Optimize: ${optResult.error.message}'));
        return;
      }
      gif = optResult.value;
    }

    final s = state.valueOrNull ?? const ImagesToGifState();
    state = AsyncData(
        s.copyWith(outputGif: gif, isProcessing: false, progress: null));
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
