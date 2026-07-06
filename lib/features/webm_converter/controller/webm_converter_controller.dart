import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/files/export_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';

enum WebmItemStatus { queued, converting, done, error }

/// Speed chip → cpu-used. VP9 and AV1 use different scales at the same UX
/// labels (PLAN.md §1/§6): AV1 is slower per step, so its cpu-used values
/// sit higher for a comparable wall-clock feel.
enum WebmSpeed {
  fast,
  balanced,
  best;

  int cpuUsed(bool av1) => av1
      ? switch (this) {
          WebmSpeed.fast => 8,
          WebmSpeed.balanced => 6,
          WebmSpeed.best => 4,
        }
      : switch (this) {
          WebmSpeed.fast => 5,
          WebmSpeed.balanced => 4,
          WebmSpeed.best => 2,
        };
}

class WebmItem {
  const WebmItem({
    required this.id,
    required this.source,
    required this.sourceBytes,
    this.info,
    this.status = WebmItemStatus.queued,
    this.output,
    this.outputBytes,
    this.progressFraction = 0,
    this.error,
  });

  final String id;
  final File source;
  final int sourceBytes;
  final MediaInfo? info;
  final WebmItemStatus status;
  final File? output;
  final int? outputBytes;
  final double progressFraction;
  final String? error;

  bool get isGif => source.path.toLowerCase().endsWith('.gif');
  bool get isProbing => info == null;

  String get sizeDeltaLabel {
    if (outputBytes == null) return '';
    final from = _fmtBytes(sourceBytes);
    final to = _fmtBytes(outputBytes!);
    final pct = sourceBytes > 0
        ? (100 - (outputBytes! / sourceBytes * 100)).round()
        : 0;
    return '$from → $to · ${pct >= 0 ? '−$pct%' : '+${-pct}%'}';
  }

  static String _fmtBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  WebmItem copyWith({
    Object? info = _s,
    WebmItemStatus? status,
    Object? output = _s,
    Object? outputBytes = _s,
    double? progressFraction,
    Object? error = _s,
  }) {
    return WebmItem(
      id: id,
      source: source,
      sourceBytes: sourceBytes,
      info: identical(info, _s) ? this.info : info as MediaInfo?,
      status: status ?? this.status,
      output: identical(output, _s) ? this.output : output as File?,
      outputBytes:
          identical(outputBytes, _s) ? this.outputBytes : outputBytes as int?,
      progressFraction: progressFraction ?? this.progressFraction,
      error: identical(error, _s) ? this.error : error as String?,
    );
  }

  static const _s = Object();
}

class WebmConverterState {
  const WebmConverterState({
    this.items = const [],
    this.crf = 32,
    this.speed = WebmSpeed.balanced,
    this.av1 = false,
    this.maxWidth,
    this.alpha = false,
    this.av1Supported = false,
    this.isProcessing = false,
    this.currentIndex = -1,
    this.error,
  });

  final List<WebmItem> items;
  final int crf; // 18–45
  final WebmSpeed speed;
  final bool av1;
  final int? maxWidth; // null = Original
  final bool alpha; // gif transparency; forces vp9 when true
  final bool av1Supported; // gated behind FfmpegService.supportsAv1()
  final bool isProcessing;
  final int currentIndex;
  final String? error;

  bool get isBatch => items.length > 1;
  bool get hasAnyGif => items.any((i) => i.isGif);
  int get doneCount => items.where((i) => i.status == WebmItemStatus.done).length;
  int get errorCount => items.where((i) => i.status == WebmItemStatus.error).length;
  bool get allDone => items.isNotEmpty &&
      items.every((i) => i.status == WebmItemStatus.done || i.status == WebmItemStatus.error);
  bool get hasDone => items.any((i) => i.status == WebmItemStatus.done);
  bool get canConvert => items.isNotEmpty &&
      items.any((i) => i.status == WebmItemStatus.queued) &&
      !isProcessing;

  double get overallProgress {
    if (items.isEmpty) return 0;
    final cur = currentIndex >= 0 && currentIndex < items.length
        ? items[currentIndex].progressFraction
        : 0.0;
    return ((doneCount + errorCount + cur) / items.length).clamp(0.0, 1.0);
  }

  WebmConverterState copyWith({
    List<WebmItem>? items,
    int? crf,
    WebmSpeed? speed,
    bool? av1,
    Object? maxWidth = _s,
    bool? alpha,
    bool? av1Supported,
    bool? isProcessing,
    int? currentIndex,
    Object? error = _s,
  }) {
    return WebmConverterState(
      items: items ?? this.items,
      crf: crf ?? this.crf,
      speed: speed ?? this.speed,
      av1: av1 ?? this.av1,
      maxWidth: identical(maxWidth, _s) ? this.maxWidth : maxWidth as int?,
      alpha: alpha ?? this.alpha,
      av1Supported: av1Supported ?? this.av1Supported,
      isProcessing: isProcessing ?? this.isProcessing,
      currentIndex: currentIndex ?? this.currentIndex,
      error: identical(error, _s) ? this.error : error as String?,
    );
  }

  static const _s = Object();
}

class WebmConverterController extends AsyncNotifier<WebmConverterState> {
  static const _maxItems = 20;
  static const _prefCrf = 'webm_crf';
  static const _prefSpeed = 'webm_speed';
  static const _prefAv1 = 'webm_av1';
  static const _prefMaxWidth = 'webm_max_width';
  static const _prefAlpha = 'webm_alpha';

  late final FfmpegService _ffmpeg;
  late final ExportService _export;
  var _nextId = 0;
  bool _cancelRequested = false;
  String? _currentId;

  FfmpegService get ffmpegService => _ffmpeg;

  @override
  Future<WebmConverterState> build() async {
    _ffmpeg = ref.read(ffmpegServiceProvider);
    _export = ref.read(exportServiceProvider);
    ref.onDispose(() {
      final s = state.valueOrNull;
      if (s == null) return;
      for (final i in s.items) {
        final out = i.output;
        if (out != null) _ffmpeg.cleanJobAt(out.parent.path);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    final av1Supported = await _ffmpeg.supportsAv1();
    return WebmConverterState(
      crf: prefs.getInt(_prefCrf) ?? 32,
      speed: WebmSpeed
          .values[(prefs.getInt(_prefSpeed) ?? WebmSpeed.balanced.index)
              .clamp(0, WebmSpeed.values.length - 1)],
      av1: (prefs.getBool(_prefAv1) ?? false) && av1Supported,
      maxWidth: prefs.getInt(_prefMaxWidth) == 0 ? null : prefs.getInt(_prefMaxWidth),
      alpha: prefs.getBool(_prefAlpha) ?? false,
      av1Supported: av1Supported,
    );
  }

  Future<void> _persist() async {
    final s = state.valueOrNull;
    if (s == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefCrf, s.crf);
    await prefs.setInt(_prefSpeed, s.speed.index);
    await prefs.setBool(_prefAv1, s.av1);
    await prefs.setInt(_prefMaxWidth, s.maxWidth ?? 0);
    await prefs.setBool(_prefAlpha, s.alpha);
  }

  /// Frees any `done` item's output and resets it to `queued` — the options
  /// card is live, so a knob change after conversion must not silently leave
  /// a stale output around under the new settings.
  List<WebmItem> _resetDoneOutputs(List<WebmItem> items) {
    var changed = false;
    final result = items.map((i) {
      if (i.status != WebmItemStatus.done) return i;
      final out = i.output;
      if (out != null) _ffmpeg.cleanJobAt(out.parent.path);
      changed = true;
      return i.copyWith(
          status: WebmItemStatus.queued,
          output: null,
          outputBytes: null,
          progressFraction: 0);
    }).toList();
    return changed ? result : items;
  }

  void _updateItem(String id, WebmItem Function(WebmItem) update) {
    final s = state.valueOrNull;
    if (s == null) return;
    state = AsyncData(s.copyWith(
        items: s.items.map((i) => i.id == id ? update(i) : i).toList()));
  }

  /// Returns the number of files rejected by the 20-item cap.
  Future<int> addFiles(List<File> files) async {
    final s = state.valueOrNull ?? const WebmConverterState();
    final room = _maxItems - s.items.length;
    final accepted = files.take(room < 0 ? 0 : room).toList();
    final rejected = files.length - accepted.length;
    if (accepted.isEmpty) return rejected;

    final newItems = accepted
        .map((f) => WebmItem(
              id: 'item_${_nextId++}',
              source: f,
              sourceBytes: f.lengthSync(),
            ))
        .toList();
    state = AsyncData(s.copyWith(items: [...s.items, ...newItems]));

    for (final item in newItems) {
      final info = await _ffmpeg.probe(item.source);
      _updateItem(item.id, (i) => i.copyWith(info: info));
    }
    return rejected;
  }

  void removeItem(String id) {
    final s = state.valueOrNull;
    if (s == null) return;
    final item = s.items.firstWhere((i) => i.id == id, orElse: () => s.items.first);
    final out = item.output;
    if (out != null) _ffmpeg.cleanJobAt(out.parent.path);
    state = AsyncData(
        s.copyWith(items: s.items.where((i) => i.id != id).toList()));
  }

  void clear() {
    final s = state.valueOrNull;
    if (s != null) {
      for (final i in s.items) {
        final out = i.output;
        if (out != null) _ffmpeg.cleanJobAt(out.parent.path);
      }
    }
    state = AsyncData((s ?? const WebmConverterState()).copyWith(
        items: const [], isProcessing: false, currentIndex: -1, error: null));
  }

  void setCrf(int v) {
    final s = state.valueOrNull ?? const WebmConverterState();
    state = AsyncData(
        s.copyWith(crf: v.clamp(18, 45), items: _resetDoneOutputs(s.items)));
    _persist();
  }

  void setSpeed(WebmSpeed v) {
    final s = state.valueOrNull ?? const WebmConverterState();
    state = AsyncData(s.copyWith(speed: v, items: _resetDoneOutputs(s.items)));
    _persist();
  }

  void setAv1(bool v) {
    final s = state.valueOrNull ?? const WebmConverterState();
    if (v && (!s.av1Supported || s.alpha)) return;
    state = AsyncData(s.copyWith(av1: v, items: _resetDoneOutputs(s.items)));
    _persist();
  }

  void setMaxWidth(int? v) {
    final s = state.valueOrNull ?? const WebmConverterState();
    state =
        AsyncData(s.copyWith(maxWidth: v, items: _resetDoneOutputs(s.items)));
    _persist();
  }

  /// Turning transparency on forces VP9 (AV1 has no alpha — PLAN.md §1).
  void setAlpha(bool v) {
    final s = state.valueOrNull ?? const WebmConverterState();
    state = AsyncData(s.copyWith(
      alpha: v,
      av1: v ? false : s.av1,
      items: _resetDoneOutputs(s.items),
    ));
    _persist();
  }

  Future<void> convertAll() async {
    final s0 = state.valueOrNull;
    if (s0 == null || s0.isProcessing) return;
    _cancelRequested = false;
    final ids = s0.items
        .where((i) => i.status == WebmItemStatus.queued)
        .map((i) => i.id)
        .toList();
    if (ids.isEmpty) return;

    final crf = s0.crf;
    final maxWidth = s0.maxWidth;
    final alphaOn = s0.alpha;
    final av1 = s0.av1 && s0.av1Supported && !alphaOn;
    final speed = s0.speed;

    state = AsyncData(s0.copyWith(isProcessing: true, error: null));

    for (final id in ids) {
      if (_cancelRequested) break;
      final s = state.valueOrNull;
      if (s == null) break;
      final idx = s.items.indexWhere((i) => i.id == id);
      if (idx == -1) continue;
      final item = s.items[idx];

      state = AsyncData(s.copyWith(currentIndex: idx));
      _currentId = id;
      _updateItem(id,
          (i) => i.copyWith(status: WebmItemStatus.converting, progressFraction: 0));

      final itemAlpha = alphaOn && item.isGif;
      final result = await _ffmpeg.convertToWebm(
        input: item.source,
        crf: crf,
        cpuUsed: speed.cpuUsed(av1),
        av1: av1,
        maxWidth: maxWidth,
        keepAudio: !item.isGif && (item.info?.hasAudio ?? false),
        alpha: itemAlpha,
        totalMs: item.info?.durationMs,
        onProgress: (p) =>
            _updateItem(id, (i) => i.copyWith(progressFraction: p.fraction)),
      );
      _currentId = null;

      await result.fold(
        ok: (file) async {
          final bytes = await file.length();
          _updateItem(
              id,
              (i) => i.copyWith(
                  status: WebmItemStatus.done,
                  output: file,
                  outputBytes: bytes,
                  progressFraction: 1));
        },
        err: (e) async {
          _updateItem(
              id,
              (i) => i.copyWith(
                  status: WebmItemStatus.error, error: e.message, progressFraction: 0));
        },
      );
    }

    final fin = state.valueOrNull;
    if (fin != null) {
      state = AsyncData(fin.copyWith(isProcessing: false, currentIndex: -1));
    }
  }

  /// Cancels the in-flight item back to `queued` (Convert resumes exactly
  /// where it stopped) — remaining `done` items are untouched.
  Future<void> cancel() async {
    _cancelRequested = true;
    await _ffmpeg.cancel();
    final id = _currentId;
    if (id != null) {
      _updateItem(
          id, (i) => i.copyWith(status: WebmItemStatus.queued, progressFraction: 0));
      _currentId = null;
    }
    final s = state.valueOrNull;
    if (s != null) {
      state = AsyncData(s.copyWith(isProcessing: false, currentIndex: -1));
    }
  }

  Future<bool> exportSingle() async {
    final s = state.valueOrNull;
    if (s == null || s.items.length != 1) return false;
    final item = s.items.first;
    if (item.output == null) return false;
    final defaultName =
        '${_baseName(item.source)}.webm';
    final saved = await _export.saveWebm(item.output!, defaultName: defaultName);
    if (saved != null) {
      _ffmpeg.cleanJobAt(item.output!.parent.path);
      await ref.read(recentsProvider.notifier).add(RecentExport(
            path: saved.path,
            toolName: 'To WebM',
            toolRoute: '/to-webm',
            timestamp: DateTime.now(),
          ));
      removeItem(item.id);
    }
    return saved != null;
  }

  /// Returns the number of files saved, or null if the user cancelled.
  Future<int?> exportBatch() async {
    final s = state.valueOrNull;
    if (s == null) return null;
    final done = s.items.where((i) => i.status == WebmItemStatus.done).toList();
    if (done.isEmpty) return null;
    final entries = done
        .map((i) => MapEntry(i.output!, _baseName(i.source)))
        .toList();
    final dir = await _export.saveWebmBatch(entries);
    if (dir == null) return null;
    for (final i in done) {
      _ffmpeg.cleanJobAt(i.output!.parent.path);
      await ref.read(recentsProvider.notifier).add(RecentExport(
            path: dir.path,
            toolName: 'To WebM',
            toolRoute: '/to-webm',
            timestamp: DateTime.now(),
          ));
    }
    final doneIds = done.map((i) => i.id).toSet();
    final cur = state.valueOrNull;
    if (cur != null) {
      state = AsyncData(cur.copyWith(
          items: cur.items.where((i) => !doneIds.contains(i.id)).toList()));
    }
    return done.length;
  }

  String _baseName(File f) {
    final name = f.path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}

final webmConverterControllerProvider =
    AsyncNotifierProvider<WebmConverterController, WebmConverterState>(
  WebmConverterController.new,
);
