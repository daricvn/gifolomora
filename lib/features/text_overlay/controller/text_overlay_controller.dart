import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/files/export_service.dart';
import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';
import '../../../core/utils/font_registry.dart';
import '../../../core/utils/font_resolver.dart';
import '../model/text_item.dart';

class TextOverlayState {
  const TextOverlayState({
    this.inputFile,
    this.mediaInfo,
    this.isProbing = false,
    this.items = const [],
    this.selectedId,
    this.outputGif,
    this.progress,
    this.isProcessing = false,
    this.error,
    this.fontFiles = const {},
    this.fontFamilies = const {},
  });

  final File? inputFile;
  final MediaInfo? mediaInfo;
  final bool isProbing;
  final List<TextItem> items;
  final String? selectedId;
  final File? outputGif;
  final FfmpegProgress? progress;
  final bool isProcessing;
  final String? error;
  final Map<TextStyleKind, String> fontFiles;
  // Flutter font family registered per style so the preview renders the same
  // typeface ffmpeg uses. Empty if FontLoader unavailable (e.g. headless test).
  final Map<TextStyleKind, String> fontFamilies;

  bool get hasInput => inputFile != null;
  TextItem? get selected =>
      selectedId == null ? null : items.where((i) => i.id == selectedId).firstOrNull;
  bool get canAdd => items.length < 20;
  bool get fontReady => fontFiles.containsKey(TextStyleKind.regular);
  bool get canGenerate =>
      hasInput &&
      items.isNotEmpty &&
      items.every((i) => i.text.trim().isNotEmpty) &&
      fontReady;

  TextOverlayState copyWith({
    Object? inputFile = _s,
    Object? mediaInfo = _s,
    bool? isProbing,
    List<TextItem>? items,
    Object? selectedId = _s,
    Object? outputGif = _s,
    Object? progress = _s,
    bool? isProcessing,
    Object? error = _s,
    Map<TextStyleKind, String>? fontFiles,
    Map<TextStyleKind, String>? fontFamilies,
  }) =>
      TextOverlayState(
        inputFile:
            identical(inputFile, _s) ? this.inputFile : inputFile as File?,
        mediaInfo:
            identical(mediaInfo, _s) ? this.mediaInfo : mediaInfo as MediaInfo?,
        isProbing: isProbing ?? this.isProbing,
        items: items ?? this.items,
        selectedId:
            identical(selectedId, _s) ? this.selectedId : selectedId as String?,
        outputGif:
            identical(outputGif, _s) ? this.outputGif : outputGif as File?,
        progress:
            identical(progress, _s) ? this.progress : progress as FfmpegProgress?,
        isProcessing: isProcessing ?? this.isProcessing,
        error: identical(error, _s) ? this.error : error as String?,
        fontFiles: fontFiles ?? this.fontFiles,
        fontFamilies: fontFamilies ?? this.fontFamilies,
      );

  static const _s = Object();
}

class TextOverlayController extends AsyncNotifier<TextOverlayState> {
  var _nextItemId = 0;

  @override
  Future<TextOverlayState> build() async {
    await FontRegistry.ensureLoaded();
    final fonts = <TextStyleKind, String>{};
    for (final style in TextStyleKind.values) {
      final path = FontResolver.fileForStyle(style);
      if (path != null) fonts[style] = path;
    }
    final families = await _loadFontFamilies(fonts);
    return TextOverlayState(fontFiles: fonts, fontFamilies: families);
  }

  // Registers each resolved font file with Flutter so the preview draws the same
  // typeface ffmpeg renders. Per-font try/catch: a headless test has no engine
  // FontLoader, and the ffmpeg path still works off fontFiles.
  Future<Map<TextStyleKind, String>> _loadFontFamilies(
      Map<TextStyleKind, String> files) async {
    final families = <TextStyleKind, String>{};
    for (final entry in files.entries) {
      final family = 'overlay_${entry.key.name}';
      try {
        final bytes = await File(entry.value).readAsBytes();
        final loader = FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
        families[entry.key] = family;
      } catch (_) {
        // preview falls back to the default font for this style
      }
    }
    return families;
  }

  FfmpegService get _ffmpeg => ref.read(ffmpegServiceProvider);
  ExportService get _export => ref.read(exportServiceProvider);

  Future<void> setInput(File file) async {
    final s = state.valueOrNull ?? const TextOverlayState();
    state = AsyncData(s.copyWith(inputFile: file, isProbing: true));
    final info = await _ffmpeg.probe(file);
    state = AsyncData(s.copyWith(
      inputFile: file,
      mediaInfo: info,
      isProbing: false,
      outputGif: null,
    ));
  }

  void addText() {
    final s = state.requireValue;
    if (!s.canAdd) return;
    final item = TextItem(
      id: 'item_${_nextItemId++}',
      text: 'Text',
      nx: 0.4,
      ny: 0.4,
    );
    state = AsyncData(s.copyWith(
      items: [...s.items, item],
      selectedId: item.id,
      outputGif: null,
      error: null,
    ));
  }

  void removeText(String id) {
    final s = state.requireValue;
    state = AsyncData(s.copyWith(
      items: s.items.where((i) => i.id != id).toList(),
      selectedId: s.selectedId == id ? null : s.selectedId,
      outputGif: null,
      error: null,
    ));
  }

  void select(String? id) {
    final s = state.requireValue;
    state = AsyncData(s.copyWith(selectedId: id));
  }

  void updateSelected({
    String? text,
    TextStyleKind? style,
    int? fontSize,
    String? fontColor,
    String? strokeColor,
    int? strokeWidth,
    TextFont? font,
  }) {
    final s = state.requireValue;
    final sel = s.selected;
    if (sel == null) return;
    final updated = sel.copyWith(
      text: text,
      style: style,
      fontSize: fontSize,
      fontColor: fontColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      font: font,
    );
    state = AsyncData(s.copyWith(
      items: s.items.map((i) => i.id == sel.id ? updated : i).toList(),
      outputGif: null,
      error: null,
    ));
  }

  void moveSelected(double nx, double ny) {
    final s = state.requireValue;
    final sel = s.selected;
    if (sel == null) return;
    state = AsyncData(s.copyWith(
      items: s.items
          .map((i) => i.id == sel.id ? i.copyWith(nx: nx, ny: ny) : i)
          .toList(),
      outputGif: null,
      error: null,
    ));
  }

  Future<void> generate() async {
    final s = state.requireValue;
    if (!s.canGenerate || s.isProcessing) return;

    state = AsyncData(s.copyWith(
      isProcessing: true,
      progress: null,
      error: null,
      outputGif: null,
    ));

    final result = await _ffmpeg.textOverlayMulti(
      input: s.inputFile!,
      items: s.items,
      mediaInfo: s.mediaInfo!,
      totalMs: s.mediaInfo?.durationMs,
      onProgress: (p) {
        final cur = state.valueOrNull;
        if (cur != null) state = AsyncData(cur.copyWith(progress: p));
      },
    );

    final cur = state.valueOrNull ??
        TextOverlayState(fontFiles: s.fontFiles, fontFamilies: s.fontFamilies);
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
    final cur = state.valueOrNull;
    state = AsyncData(TextOverlayState(
      fontFiles: cur?.fontFiles ?? const {},
      fontFamilies: cur?.fontFamilies ?? const {},
    ));
  }
}

final textOverlayControllerProvider =
    AsyncNotifierProvider<TextOverlayController, TextOverlayState>(
  TextOverlayController.new,
);
