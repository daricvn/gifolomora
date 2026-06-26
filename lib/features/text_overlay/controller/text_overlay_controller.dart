import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/files/export_service.dart';
import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';
import '../../../core/utils/font_resolver.dart';

class TextOverlayState {
  const TextOverlayState({
    this.inputFile,
    this.mediaInfo,
    this.text = '',
    this.position = 'center',
    this.fontSize = 36,
    this.fontColor = 'white',
    this.fontFile,
    this.outputGif,
    this.progress,
    this.isProcessing = false,
    this.isProbing = false,
    this.error,
  });

  final File? inputFile;
  final MediaInfo? mediaInfo;
  final String text;
  final String position;
  final int fontSize;
  final String fontColor;
  final String? fontFile;
  final File? outputGif;
  final FfmpegProgress? progress;
  final bool isProcessing;
  final bool isProbing;
  final String? error;

  bool get hasInput => inputFile != null;
  bool get canGenerate => hasInput && text.trim().isNotEmpty && fontFile != null;
  int get originalWidth => mediaInfo?.width ?? 0;
  int get originalHeight => mediaInfo?.height ?? 0;

  TextOverlayState copyWith({
    Object? inputFile = _s,
    Object? mediaInfo = _s,
    String? text,
    String? position,
    int? fontSize,
    String? fontColor,
    Object? fontFile = _s,
    Object? outputGif = _s,
    Object? progress = _s,
    bool? isProcessing,
    bool? isProbing,
    Object? error = _s,
  }) {
    return TextOverlayState(
      inputFile: identical(inputFile, _s) ? this.inputFile : inputFile as File?,
      mediaInfo: identical(mediaInfo, _s) ? this.mediaInfo : mediaInfo as MediaInfo?,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      fontFile: identical(fontFile, _s) ? this.fontFile : fontFile as String?,
      outputGif: identical(outputGif, _s) ? this.outputGif : outputGif as File?,
      progress: identical(progress, _s) ? this.progress : progress as FfmpegProgress?,
      isProcessing: isProcessing ?? this.isProcessing,
      isProbing: isProbing ?? this.isProbing,
      error: identical(error, _s) ? this.error : error as String?,
    );
  }

  static const _s = Object();
}

class TextOverlayController extends AsyncNotifier<TextOverlayState> {
  @override
  Future<TextOverlayState> build() async =>
      TextOverlayState(fontFile: FontResolver.resolve());

  FfmpegService get _ffmpeg => ref.read(ffmpegServiceProvider);
  ExportService get _export => ref.read(exportServiceProvider);

  Future<void> setInput(File file) async {
    final s = state.valueOrNull ?? const TextOverlayState();
    state = AsyncData(s.copyWith(inputFile: file, isProbing: true));
    final info = await _ffmpeg.probe(file);
    state = AsyncData(s.copyWith(inputFile: file, mediaInfo: info, isProbing: false));
  }

  void setText(String text) {
    final s = state.valueOrNull ?? const TextOverlayState();
    state = AsyncData(s.copyWith(text: text, outputGif: null, error: null));
  }

  void setPosition(String position) {
    final s = state.valueOrNull ?? const TextOverlayState();
    state = AsyncData(s.copyWith(position: position, outputGif: null, error: null));
  }

  void setFontSize(int size) {
    final s = state.valueOrNull ?? const TextOverlayState();
    state = AsyncData(s.copyWith(fontSize: size, outputGif: null, error: null));
  }

  void setFontColor(String color) {
    final s = state.valueOrNull ?? const TextOverlayState();
    state = AsyncData(s.copyWith(fontColor: color, outputGif: null, error: null));
  }

  Future<void> generate() async {
    final s = state.valueOrNull;
    if (s == null || !s.canGenerate || s.isProcessing) return;

    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, outputGif: null));

    final result = await _ffmpeg.textOverlay(
      input: s.inputFile!,
      text: s.text.trim(),
      fontFile: s.fontFile!,
      fontSize: s.fontSize,
      fontColor: s.fontColor,
      position: s.position,
      totalMs: s.mediaInfo?.durationMs,
      onProgress: (p) {
        final cur = state.valueOrNull;
        if (cur != null) state = AsyncData(cur.copyWith(progress: p));
      },
    );

    final cur = state.valueOrNull ?? const TextOverlayState();
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
            toolName: 'Text Overlay',
            toolRoute: '/text-overlay',
            timestamp: DateTime.now(),
          ));
    }
    return saved != null;
  }

  Future<void> cancel() async {
    await _ffmpeg.cancel();
    await _ffmpeg.cleanCurrentJob();
    final s = state.valueOrNull ?? const TextOverlayState();
    state = AsyncData(s.copyWith(isProcessing: false, progress: null));
  }

  void clear() {
    _ffmpeg.cleanCurrentJob();
    state = AsyncData(TextOverlayState(fontFile: FontResolver.resolve()));
  }
}

final textOverlayControllerProvider =
    AsyncNotifierProvider<TextOverlayController, TextOverlayState>(
  TextOverlayController.new,
);
