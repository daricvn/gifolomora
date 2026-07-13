import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/files/export_service.dart';
import '../../../core/services/ffmpeg/ffmpeg_command.dart' show CutSegment;
import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';
import '../../../core/utils/font_registry.dart';
import '../../../core/utils/font_resolver.dart';
import '../../../core/utils/result.dart';
import '../../text_overlay/model/text_item.dart';

/// Which artifact the studio is currently editing.
enum EditStage { video, gif }

/// Export Video's format choice (PLAN.md §8). WebM always uses the §1
/// defaults (CRF 32, cpu-used 4, Opus 128k) — no quality knobs on the format
/// page; a slider can join later if asked. [original] copies the source file
/// as-is (no re-encode, keeps container/codec) — only offered while the video
/// is untouched ([VideoStudioState.hasComparableEdit] false).
enum ExportVideoFormat { mp4, webm, original }

/// Auto FPS cap for a video→GIF conversion, tuned by output length so long
/// clips don't bloat: <15s→21, 15–20s→16, 20–25s→15, 25–30s→12, 30–40s→8.
int maxGifFpsFor(int durationMs) {
  final s = durationMs / 1000;
  if (s < 15) return 21;
  if (s < 20) return 16;
  if (s < 25) return 15;
  if (s < 30) return 12;
  return 8;
}

/// Auto width cap for a video→GIF conversion, tuned by output length so long
/// clips don't bloat: <15s→1280, 15–25s→1080, 25–40s→800.
int maxGifWidthFor(int durationMs) {
  final s = durationMs / 1000;
  if (s <= 15) return 1280;
  if (s <= 25) return 1080;
  return 800;
}

/// The tool whose editor panel is open in the dock.
enum StudioTool { crop, resize, speed, trim, cut, text, gif, optimize, properties, webm }

class VideoStudioState {
  const VideoStudioState({
    this.inputFile,
    this.stage = EditStage.video,
    this.sourceFile,
    this.sourceInfo,
    this.cropNormalized = const Rect.fromLTWH(0, 0, 1, 1),
    this.targetWidth,
    this.speedFactor = 1.0,
    this.trimStartMs = 0,
    this.trimEndMs = 0,
    this.cutSegments = const [],
    this.textItems = const [],
    this.selectedTextId,
    this.fontFiles = const {},
    this.fontFamilies = const {},
    this.forceOriginalGifWidth = false,
    this.doOptimize = false,
    this.optimizeColors = 246,
    this.optimizeLossy = 15,
    this.optimizeFrameDrop = 0,
    this.optimizeLocalPalettes = false,
    this.fps = 16,
    this.loopCount = 0,
    this.boomerang = false,
    this.smoothLoop = false,
    this.smoothLoopCrossfadeMs = 1000,
    this.volume = 1.0,
    this.activeTool = StudioTool.crop,
    this.progress,
    this.isProcessing = false,
    this.isProbing = false,
    this.error,
    this.editsApplied = false,
  });

  /// The original picked video. Retained so "back to video" can rebuild.
  final File? inputFile;

  /// Whether the live source is the video or a baked GIF.
  final EditStage stage;

  /// The file currently previewed and edited (video or baked gif).
  final File? sourceFile;
  final MediaInfo? sourceInfo;

  /// Layers applied on top of [sourceFile] (non-destructive until export).
  final Rect cropNormalized;
  final int? targetWidth;
  final double speedFactor;

  /// User override to skip the auto width cap and keep the GIF at source/
  /// resize width. Only takes effect under 25s — see [forceOriginalGifWidthActive].
  final bool forceOriginalGifWidth;

  /// Trim in/out points (ms). Both 0 = no trim (full duration).
  final int trimStartMs;
  final int trimEndMs;

  /// Segments (absolute source ms) marked for removal. Empty = no cuts.
  /// Always sorted by startMs. Each segment lies within [trimStartMs, effectiveTrimEndMs].
  final List<CutSegment> cutSegments;

  /// Multi-item text overlay layers (shared model with the Text Overlay tool).
  /// Baked by [FfmpegService.textOverlayMulti] at apply/export. [selectedTextId]
  /// is the item being edited/dragged. [fontFiles] feeds ffmpeg per style;
  /// [fontFamilies] are the Flutter-registered families so the preview renders
  /// the same typeface.
  final List<TextItem> textItems;
  final String? selectedTextId;
  final Map<TextStyleKind, String> fontFiles;
  final Map<TextStyleKind, String> fontFamilies;

  final bool doOptimize;
  final int optimizeColors;
  final int optimizeLossy;
  final int optimizeFrameDrop; // 0 = keep all; 2/3/4 = remove 1 of every N
  final bool optimizeLocalPalettes; // lossless per-frame color tables

  /// Output-GIF properties. [fps] is baked at make-GIF time (frames can't be
  /// added later). [loopCount] 0 = infinite. [boomerang] appends a reversed
  /// copy at export for a seamless ping-pong loop.
  final int fps;
  final int loopCount;
  final bool boomerang;

  /// Crossfades the last [smoothLoopCrossfadeMs] into the first
  /// [smoothLoopCrossfadeMs], then drops that same span from the front, so
  /// the loop point has no jump cut. Works on both stages: GIF-stage
  /// mutually exclusive with [boomerang] (both replace the tail of the
  /// filter graph); video-stage also crossfades the audio track (acrossfade)
  /// when the source has one.
  final bool smoothLoop;

  /// Crossfade span for [smoothLoop], 500–1000ms in 100ms steps.
  final int smoothLoopCrossfadeMs;

  /// Audio volume multiplier for video export (1.0 = 100%, range 0–2.0). Baked
  /// into the encode's audio filter at apply/export; ignored for GIF (no audio).
  final double volume;

  final StudioTool? activeTool;
  final FfmpegProgress? progress;
  final bool isProcessing;
  final bool isProbing;
  final String? error;

  /// True after [applyEdits] with no subsequent option changes — Export can
  /// skip re-encoding and save [sourceFile] directly.
  final bool editsApplied;

  bool get hasInput => sourceFile != null;
  bool get isGif => stage == EditStage.gif;
  int get sourceWidth => sourceInfo?.width ?? 0;
  int get sourceHeight => sourceInfo?.height ?? 0;
  bool get hasAudio => sourceInfo?.hasAudio ?? false;
  int get sourceDurationMs => sourceInfo?.durationMs ?? 0;

  bool get isCropFull =>
      cropNormalized.left == 0 &&
      cropNormalized.top == 0 &&
      cropNormalized.right == 1 &&
      cropNormalized.bottom == 1;

  bool get hasTrim =>
      trimStartMs > 0 ||
      (trimEndMs > 0 && trimEndMs < sourceDurationMs);

  int get effectiveTrimEndMs =>
      trimEndMs > 0 ? trimEndMs : sourceDurationMs;

  int get trimDurationMs =>
      sourceDurationMs > 0
          ? (effectiveTrimEndMs - trimStartMs).clamp(0, sourceDurationMs)
          : 0;

  bool get hasCut => cutSegments.isNotEmpty;

  /// True when [startMs, endMs] lies entirely within one existing cut segment
  /// — marking it would be a no-op, so the UI disables "Mark for removal".
  bool isFullyCovered(int startMs, int endMs) => cutSegments
      .any((e) => e.startMs <= startMs && e.endMs >= endMs);

  /// Sum of cut durations overlapping the trim window.
  int get cutDurationMs {
    final lo = trimStartMs;
    final hi = effectiveTrimEndMs;
    return cutSegments.fold(0, (sum, s) {
      final start = s.startMs.clamp(lo, hi);
      final end = s.endMs.clamp(lo, hi);
      return sum + (end - start).clamp(0, hi - lo);
    });
  }

  /// Output duration after cuts are applied (ms).
  int get cutOutputMs {
    final total = trimDurationMs;
    return (total - cutDurationMs).clamp(0, total > 0 ? total : 0);
  }

  /// Effective output duration for GIF conversion (ms).
  int get effectiveOutputMs {
    if (hasCut) return cutOutputMs;
    if (hasTrim) return trimDurationMs;
    return sourceDurationMs;
  }

  /// Auto FPS cap for the current trim/cut selection — see [maxGifFpsFor].
  int get maxGifFps => maxGifFpsFor(effectiveOutputMs);

  /// Auto width cap for the current trim/cut selection — see [maxGifWidthFor].
  int get maxGifWidth => maxGifWidthFor(effectiveOutputMs);

  /// Frame width the GIF bake would produce before the cap: resize wins, else
  /// crop width, else source width.
  int get gifOutputWidth {
    if (targetWidth != null) return targetWidth!;
    if (!isCropFull) return (cropNormalized.width * sourceWidth).round();
    return sourceWidth;
  }

  /// True when the bake would downscale to [maxGifWidth].
  bool get gifWidthCapped => gifOutputWidth > maxGifWidth;

  /// Whether the "keep original width" checkbox should appear enabled — only
  /// offered under 25s, and only when the cap would actually kick in.
  bool get canForceOriginalGifWidth =>
      effectiveOutputMs < 25000 && gifWidthCapped;

  /// [forceOriginalGifWidth] only takes effect under 25s — at/after 25s the
  /// cap always applies, even if the checkbox is left checked (disabled).
  bool get forceOriginalGifWidthActive =>
      forceOriginalGifWidth && effectiveOutputMs < 25000;

  /// The keep ranges: complement of cutSegments within [trimStartMs, effectiveTrimEndMs].
  /// Used by the ffmpeg layer. Single-element list (full window) when no cuts.
  List<CutSegment> get keepRanges {
    final lo = trimStartMs;
    final hi = effectiveTrimEndMs;
    if (cutSegments.isEmpty) {
      return [(startMs: lo, endMs: hi)];
    }
    final sorted = [...cutSegments]..sort((a, b) => a.startMs.compareTo(b.startMs));
    final keeps = <CutSegment>[];
    var cur = lo;
    for (final seg in sorted) {
      final sStart = seg.startMs.clamp(lo, hi);
      final sEnd = seg.endMs.clamp(lo, hi);
      if (sStart > cur) keeps.add((startMs: cur, endMs: sStart));
      if (sEnd > cur) cur = sEnd;
    }
    if (cur < hi) keeps.add((startMs: cur, endMs: hi));
    return keeps;
  }

  /// Any text layer carrying non-blank text — the text bake runs only then.
  bool get hasText => textItems.any((i) => i.text.trim().isNotEmpty);
  bool get canAddText => textItems.length < 20;
  bool get fontReady => fontFiles.containsKey(TextStyleKind.regular);
  TextItem? get selectedText => selectedTextId == null
      ? null
      : textItems.where((i) => i.id == selectedTextId).firstOrNull;

  /// Audio gain that would change the output. Only meaningful with audio.
  bool get hasVolumeChange => hasAudio && (volume - 1.0).abs() >= 0.01;

  /// True when a geometry layer would change the output. Text is handled by a
  /// separate textOverlayMulti pass, so it is gated independently ([hasText]).
  bool get hasEdits =>
      !isCropFull ||
      targetWidth != null ||
      (speedFactor - 1.0).abs() >= 0.001;

  /// GIF stage: whether a re-encode is needed on top of doOptimize/text (fps
  /// retiming, boomerang, or a geometry/speed edit).
  bool get needsGifEdit {
    final srcFps = sourceInfo?.fps;
    final fpsChanged = srcFps != null && (fps - srcFps).abs() >= 0.5;
    return hasEdits || hasTrim || boomerang || smoothLoop || fpsChanged || (loopCount != 0 && !doOptimize);
  }

  /// UX gate: Smooth Loop only offered when the trimmed/cut target duration
  /// exceeds 3s — not just the raw source (a trim can shrink the effective
  /// GIF well under the source length).
  bool get canSmoothLoop => effectiveOutputMs / speedFactor > 3000;

  /// Hard safety floor: the post-speed/post-trim effective duration must
  /// leave the crossfade's `mid` segment with real frames (>100ms), else the
  /// filter graph's `concat` would run on an empty stream. Scales with the
  /// user-adjustable [smoothLoopCrossfadeMs].
  bool get smoothLoopValid =>
      effectiveOutputMs / speedFactor > 2 * smoothLoopCrossfadeMs + 100;

  /// Whether Apply/Export would actually do anything beyond a straight save.
  /// `editsApplied` short-circuits this: right after a bake, fields like
  /// loopCount are intentionally left at their (non-default) baked value with
  /// no separate "already applied" marker of their own — without this guard
  /// a nonzero loopCount would read as pending forever, since it never
  /// resets. Any setter clears editsApplied, so real new edits still count.
  bool get hasPendingApply =>
      !editsApplied &&
      (isGif
          ? (needsGifEdit || doOptimize || hasText)
          : (hasEdits ||
              hasTrim ||
              hasText ||
              hasVolumeChange ||
              hasCut ||
              smoothLoop));

  /// Whether the preview currently differs from the original — the gate for
  /// the Compare button. Unlike [hasPendingApply], not suppressed by
  /// [editsApplied]: a bake resets the live edit fields to default but
  /// `sourceFile` is still the baked (changed) result, so there is still
  /// something to compare against `inputFile`.
  bool get hasComparableEdit =>
      editsApplied ||
      (isGif
          ? (needsGifEdit || doOptimize || hasText)
          : (hasEdits || hasTrim || hasText || hasVolumeChange || hasCut || smoothLoop));

  /// Lowercased source extension for the save-as-is "Original" export card;
  /// null when the video has edits (card hidden) or the file has no
  /// extension. p.extension looks at the basename only, so a dotted
  /// directory (`C:\v2.0\clip`) can't fake one.
  String? get originalExportExt {
    final path = sourceFile?.path;
    if (path == null || hasComparableEdit) return null;
    final ext = p.extension(path);
    return ext.length > 1 ? ext.substring(1).toLowerCase() : null;
  }

  /// Whether [tool]'s panel currently carries a non-default edit — drives the
  /// dot indicator on the tool selector.
  bool isToolEdited(StudioTool tool) {
    switch (tool) {
      case StudioTool.crop:
        return !isCropFull;
      case StudioTool.resize:
        return targetWidth != null;
      case StudioTool.speed:
        return (speedFactor - 1.0).abs() >= 0.001;
      case StudioTool.trim:
        return hasTrim;
      case StudioTool.cut:
        return hasCut;
      case StudioTool.text:
        return hasText;
      case StudioTool.gif:
        return fps != 16 || forceOriginalGifWidth;
      case StudioTool.optimize:
        return doOptimize;
      case StudioTool.properties:
        return isGif
            ? (loopCount != 0 || boomerang || smoothLoop)
            : (hasVolumeChange || smoothLoop);
      case StudioTool.webm:
        return false;
    }
  }

  VideoStudioState copyWith({
    Object? inputFile = _s,
    EditStage? stage,
    Object? sourceFile = _s,
    Object? sourceInfo = _s,
    Rect? cropNormalized,
    Object? targetWidth = _s,
    double? speedFactor,
    bool? forceOriginalGifWidth,
    int? trimStartMs,
    int? trimEndMs,
    List<CutSegment>? cutSegments,
    List<TextItem>? textItems,
    Object? selectedTextId = _s,
    Map<TextStyleKind, String>? fontFiles,
    Map<TextStyleKind, String>? fontFamilies,
    bool? doOptimize,
    int? optimizeColors,
    int? optimizeLossy,
    int? optimizeFrameDrop,
    bool? optimizeLocalPalettes,
    int? fps,
    int? loopCount,
    bool? boomerang,
    bool? smoothLoop,
    int? smoothLoopCrossfadeMs,
    double? volume,
    Object? activeTool = _s,
    Object? progress = _s,
    bool? isProcessing,
    bool? isProbing,
    Object? error = _s,
    // Defaults to false — cleared on any option change. Pass editsApplied:
    // true explicitly only to preserve an already-applied state (undo/redo,
    // setActiveTool).
    bool editsApplied = false,
  }) {
    return VideoStudioState(
      inputFile:
          identical(inputFile, _s) ? this.inputFile : inputFile as File?,
      stage: stage ?? this.stage,
      sourceFile:
          identical(sourceFile, _s) ? this.sourceFile : sourceFile as File?,
      sourceInfo: identical(sourceInfo, _s)
          ? this.sourceInfo
          : sourceInfo as MediaInfo?,
      cropNormalized: cropNormalized ?? this.cropNormalized,
      targetWidth:
          identical(targetWidth, _s) ? this.targetWidth : targetWidth as int?,
      speedFactor: speedFactor ?? this.speedFactor,
      forceOriginalGifWidth: forceOriginalGifWidth ?? this.forceOriginalGifWidth,
      trimStartMs: trimStartMs ?? this.trimStartMs,
      trimEndMs: trimEndMs ?? this.trimEndMs,
      cutSegments: cutSegments ?? this.cutSegments,
      textItems: textItems ?? this.textItems,
      selectedTextId: identical(selectedTextId, _s)
          ? this.selectedTextId
          : selectedTextId as String?,
      fontFiles: fontFiles ?? this.fontFiles,
      fontFamilies: fontFamilies ?? this.fontFamilies,
      doOptimize: doOptimize ?? this.doOptimize,
      optimizeColors: optimizeColors ?? this.optimizeColors,
      optimizeLossy: optimizeLossy ?? this.optimizeLossy,
      optimizeFrameDrop: optimizeFrameDrop ?? this.optimizeFrameDrop,
      optimizeLocalPalettes: optimizeLocalPalettes ?? this.optimizeLocalPalettes,
      fps: fps ?? this.fps,
      loopCount: loopCount ?? this.loopCount,
      boomerang: boomerang ?? this.boomerang,
      smoothLoop: smoothLoop ?? this.smoothLoop,
      smoothLoopCrossfadeMs: smoothLoopCrossfadeMs ?? this.smoothLoopCrossfadeMs,
      volume: volume ?? this.volume,
      activeTool: identical(activeTool, _s)
          ? this.activeTool
          : activeTool as StudioTool?,
      progress:
          identical(progress, _s) ? this.progress : progress as FfmpegProgress?,
      isProcessing: isProcessing ?? this.isProcessing,
      isProbing: isProbing ?? this.isProbing,
      error: identical(error, _s) ? this.error : error as String?,
      editsApplied: editsApplied,
    );
  }

  static const _s = Object();
}

/// One entry in the Video Studio GIF undo/redo history: a restorable state
/// snapshot plus the temp job dir it owns ([ownedDir] null = the user's own
/// loaded file, which must never be deleted).
class _GifVersion {
  const _GifVersion({required this.state, this.ownedDir});
  final VideoStudioState state;
  final String? ownedDir;
}

class VideoStudioController extends AsyncNotifier<VideoStudioState> {
  // Cache services at build time so they remain accessible in onDispose
  // (ref is already marked disposed when the callback fires).
  late final FfmpegService _ffmpeg;
  late final ExportService _export;

  // Resolved once at build, then carried through every state transition.
  Map<TextStyleKind, String> _fontFiles = const {};
  Map<TextStyleKind, String> _fontFamilies = const {};
  var _nextTextId = 0;

  static const _prefExportFormat = 'studio_export_format';
  ExportVideoFormat _lastExportFormat = ExportVideoFormat.mp4;
  ExportVideoFormat get lastExportFormat => _lastExportFormat;

  Future<void> setLastExportFormat(ExportVideoFormat format) async {
    _lastExportFormat = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefExportFormat, format.index);
  }

  /// Temp dir owning the last applied-video bake (video stage has no undo
  /// history, so it is tracked separately from [_history]). Freed when
  /// superseded (re-apply, makeGif, discardGif, setInput, clear, dispose).
  /// Null = the live source is the user's own file, which must never be deleted.
  String? _appliedVideoDir;

  void _freeAppliedVideo() {
    final d = _appliedVideoDir;
    _appliedVideoDir = null;
    if (d != null) _ffmpeg.cleanJobAt(d);
  }

  @override
  Future<VideoStudioState> build() async {
    _ffmpeg = ref.read(ffmpegServiceProvider);
    _export = ref.read(exportServiceProvider);
    // App close / provider disposal → free every temp the session still owns.
    ref.onDispose(() {
      _ffmpeg.cleanCurrentJob();
      _clearHistory();
      _freeAppliedVideo();
    });
    final prefs = await SharedPreferences.getInstance();
    _lastExportFormat = ExportVideoFormat
        .values[(prefs.getInt(_prefExportFormat) ?? 0)
            .clamp(0, ExportVideoFormat.values.length - 1)];
    await FontRegistry.ensureLoaded();
    final fonts = <TextStyleKind, String>{};
    for (final style in TextStyleKind.values) {
      final path = FontResolver.fileForStyle(style);
      if (path != null) fonts[style] = path;
    }
    _fontFiles = fonts;
    _fontFamilies = await _loadFontFamilies(fonts);
    return VideoStudioState(
        fontFiles: _fontFiles, fontFamilies: _fontFamilies);
  }

  // Registers each resolved font with Flutter so the preview draws the same
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

  /// Undo/redo history of GIF versions for the current session. Each entry is a
  /// restorable state snapshot plus the temp job dir it owns. The first entry is
  /// the base GIF (baked from video, or the user's loaded GIF with no owned dir);
  /// every "Apply" pushes a new entry. The whole stack — and every owned temp
  /// dir — is freed when the source changes (setInput / makeGif / discardGif),
  /// on reset (clear), and on dispose (app close).
  final List<_GifVersion> _history = [];
  int _cursor = -1;

  // ponytail: caps disk usage from repeated Apply during one session (each
  // version owns a full baked-GIF temp dir); raise if undo depth complaints.
  static const _maxHistory = 20;

  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor >= 0 && _cursor < _history.length - 1;

  /// Appends [snapshot] as the new current version, branching off [_cursor].
  /// Any redo tail is dropped and its owned temps freed. Oldest entry is
  /// evicted once [_maxHistory] is exceeded.
  void _pushVersion(VideoStudioState snapshot, {String? ownedDir}) {
    for (var i = _history.length - 1; i > _cursor; i--) {
      final d = _history[i].ownedDir;
      if (d != null) _ffmpeg.cleanJobAt(d);
    }
    if (_cursor + 1 < _history.length) {
      _history.removeRange(_cursor + 1, _history.length);
    }
    _history.add(_GifVersion(state: snapshot, ownedDir: ownedDir));
    _cursor = _history.length - 1;
    if (_history.length > _maxHistory) {
      final evicted = _history.removeAt(0);
      if (evicted.ownedDir != null) _ffmpeg.cleanJobAt(evicted.ownedDir!);
      _cursor--;
    }
  }

  /// Empties the history and frees every temp dir it owns.
  void _clearHistory() {
    for (final v in _history) {
      if (v.ownedDir != null) _ffmpeg.cleanJobAt(v.ownedDir!);
    }
    _history.clear();
    _cursor = -1;
  }

  /// Restores the GIF version at [target] as the live preview source.
  bool _restore(int target) {
    if (target < 0 || target >= _history.length) return false;
    _cursor = target;
    final v = _history[_cursor].state;
    state = AsyncData(v.copyWith(
        isProcessing: false,
        progress: null,
        error: null,
        editsApplied: v.editsApplied));
    return true;
  }

  /// Steps back to the previously applied GIF version.
  bool undo() =>
      state.valueOrNull?.isProcessing != true && canUndo && _restore(_cursor - 1);

  /// Steps forward to the next applied GIF version.
  bool redo() =>
      state.valueOrNull?.isProcessing != true && canRedo && _restore(_cursor + 1);

  // ── Input ──────────────────────────────────────────────────────────────

  Future<void> setInput(File file) async {
    // Guards the cold-start race: the caller (VideoStudioScreen) reads this
    // provider and calls setInput one frame later, while build()'s font-load
    // await may still be pending. Riverpod's AsyncNotifier applies build()'s
    // eventual return value to `state` unconditionally when it resolves —
    // even if `state` was already reassigned in the meantime — so without
    // this await, build()'s stale default state (sourceFile: null) would
    // clobber the just-loaded video a moment after it appeared (the "loads,
    // flashes, then reverts to the picker" symptom). Awaiting `future` first
    // lets that resolution land before we touch state, so nothing overwrites
    // us afterward.
    await future;
    _ffmpeg.cleanCurrentJob();
    _clearHistory();
    _freeAppliedVideo();
    state = AsyncData(VideoStudioState(
      inputFile: file,
      isProbing: true,
      fontFiles: _fontFiles,
      fontFamilies: _fontFamilies,
    ));
    final info = await _ffmpeg.probe(file);
    final isGif = file.path.toLowerCase().endsWith('.gif');
    final loaded = VideoStudioState(
      inputFile: file,
      stage: isGif ? EditStage.gif : EditStage.video,
      sourceFile: file,
      sourceInfo: info,
      // Seed FPS from a loaded GIF so the slider shows its real rate (and an
      // untouched export skips re-timing). Video keeps the 15 fps GIF default.
      fps: isGif && info?.fps != null
          ? info!.fps!.round().clamp(5, 30)
          : 16,
      activeTool: StudioTool.crop,
      fontFiles: _fontFiles,
      fontFamilies: _fontFamilies,
    );
    state = AsyncData(loaded);
    // A loaded GIF is the base version; its file is the user's own (not owned).
    if (isGif) _pushVersion(loaded, ownedDir: null);
  }

  // ── Tool / layer edits ───────────────────────────────────────────────────

  void setActiveTool(StudioTool? tool) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(activeTool: tool, error: null, editsApplied: s.editsApplied));
  }

  void setCrop(Rect normalized) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(cropNormalized: normalized, error: null));
  }

  void resetCrop() => setCrop(const Rect.fromLTWH(0, 0, 1, 1));

  void setResize(int? width) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(targetWidth: width, error: null));
  }

  void setSpeed(double factor) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(_disableSmoothLoopIfInvalid(
        s.copyWith(speedFactor: factor.clamp(0.1, 10.0), error: null)));
  }

  void setTrimStart(int ms) {
    final s = state.valueOrNull ?? const VideoStudioState();
    final max = s.effectiveTrimEndMs > 1000 ? s.effectiveTrimEndMs - 1000 : 0;
    final newStart = ms.clamp(0, max);
    final clipped = _clipSegments(s.cutSegments, newStart, s.effectiveTrimEndMs);
    state = AsyncData(_disableSmoothLoopIfInvalid(s.copyWith(
        trimStartMs: newStart, cutSegments: clipped, error: null)));
  }

  void setTrimEnd(int ms) {
    final s = state.valueOrNull ?? const VideoStudioState();
    final min = s.trimStartMs + 1000;
    final max = s.sourceDurationMs > 0 ? s.sourceDurationMs : ms;
    final newEnd = ms.clamp(min, max);
    final clipped = _clipSegments(s.cutSegments, s.trimStartMs, newEnd);
    state = AsyncData(_disableSmoothLoopIfInvalid(s.copyWith(
        trimEndMs: newEnd, cutSegments: clipped, error: null)));
  }

  /// Smooth Loop's crossfade needs a real `mid` segment, and the feature is
  /// only offered past the 3s UX gate — if the user drags speed/trim/cut
  /// into either unsafe zone after enabling it, turn it back off rather than
  /// let a broken filter graph reach ffmpeg or leave a switch on that the UI
  /// would otherwise disable.
  VideoStudioState _disableSmoothLoopIfInvalid(VideoStudioState s) =>
      s.smoothLoop && (!s.smoothLoopValid || !s.canSmoothLoop)
          ? s.copyWith(smoothLoop: false)
          : s;

  void resetTrim() {
    final s = state.valueOrNull ?? const VideoStudioState();
    final clipped = _clipSegments(s.cutSegments, 0, s.sourceDurationMs);
    state = AsyncData(s.copyWith(
        trimStartMs: 0, trimEndMs: 0, cutSegments: clipped, error: null));
  }

  /// Clips each segment to [lo, hi]; drops segments fully outside the window.
  List<CutSegment> _clipSegments(List<CutSegment> segs, int lo, int hi) {
    return segs
        .map((s) => (
              startMs: s.startMs.clamp(lo, hi),
              endMs: s.endMs.clamp(lo, hi),
            ))
        .where((s) => s.endMs - s.startMs > 0)
        .toList();
  }

  // ── Cut segments ─────────────────────────────────────────────────────────────

  /// Adds a cut segment. Clamps to trim window; any existing segment it
  /// overlaps gets merged into the new one. Rejects segments that would leave
  /// < 1s of output (also rejects a segment fully swallowed by an existing
  /// one, per [VideoStudioState.isFullyCovered] gating the UI). Returns false
  /// on rejection.
  bool addCutSegment(int startMs, int endMs) {
    final s = state.valueOrNull;
    if (s == null) return false;
    final lo = s.trimStartMs;
    final hi = s.effectiveTrimEndMs;
    var cStart = startMs.clamp(lo, hi);
    var cEnd = endMs.clamp(lo, hi);
    if (cEnd - cStart <= 0) return false;

    final overlapping = <CutSegment>[];
    final untouched = <CutSegment>[];
    for (final e in s.cutSegments) {
      if (cStart < e.endMs && cEnd > e.startMs) {
        overlapping.add(e);
      } else {
        untouched.add(e);
      }
    }
    for (final e in overlapping) {
      if (e.startMs < cStart) cStart = e.startMs;
      if (e.endMs > cEnd) cEnd = e.endMs;
    }

    final newSegs = [...untouched, (startMs: cStart, endMs: cEnd)]
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    final newCutDurationMs =
        newSegs.fold(0, (sum, seg) => sum + (seg.endMs - seg.startMs));
    if (s.trimDurationMs - newCutDurationMs < 1000) return false;

    state = AsyncData(
        _disableSmoothLoopIfInvalid(s.copyWith(cutSegments: newSegs, error: null)));
    return true;
  }

  void removeCutSegment(CutSegment seg) {
    final s = state.valueOrNull;
    if (s == null) return;
    final newSegs = s.cutSegments.where((e) => e != seg).toList();
    state = AsyncData(s.copyWith(cutSegments: newSegs, error: null));
  }

  void resetCut() {
    final s = state.valueOrNull;
    if (s == null) return;
    state = AsyncData(s.copyWith(cutSegments: const [], error: null));
  }

  // ── Text overlay layers (shared model with the Text Overlay tool) ──────────

  void addText() {
    final s = state.valueOrNull ?? const VideoStudioState();
    if (!s.canAddText) return;
    final item = TextItem(
      id: 'item_${_nextTextId++}',
      text: 'Text',
      nx: 0.4,
      ny: 0.4,
    );
    state = AsyncData(s.copyWith(
      textItems: [...s.textItems, item],
      selectedTextId: item.id,
      error: null,
    ));
  }

  void removeText(String id) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(
      textItems: s.textItems.where((i) => i.id != id).toList(),
      selectedTextId: s.selectedTextId == id ? null : s.selectedTextId,
      error: null,
    ));
  }

  void selectText(String? id) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(selectedTextId: id, error: null));
  }

  void updateSelectedText({
    String? text,
    TextStyleKind? style,
    int? fontSize,
    String? fontColor,
    String? strokeColor,
    int? strokeWidth,
    TextFont? font,
  }) {
    final s = state.valueOrNull ?? const VideoStudioState();
    final sel = s.selectedText;
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
      textItems: s.textItems.map((i) => i.id == sel.id ? updated : i).toList(),
      error: null,
    ));
  }

  void moveSelectedText(double nx, double ny) {
    final s = state.valueOrNull ?? const VideoStudioState();
    final sel = s.selectedText;
    if (sel == null) return;
    state = AsyncData(s.copyWith(
      textItems: s.textItems
          .map((i) => i.id == sel.id ? i.copyWith(nx: nx, ny: ny) : i)
          .toList(),
      error: null,
    ));
  }

  void setForceOriginalGifWidth(bool v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(forceOriginalGifWidth: v, error: null));
  }

  void setDoOptimize(bool v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(doOptimize: v, error: null));
  }

  void setOptimizeColors(int v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(optimizeColors: v, error: null));
  }

  void setOptimizeLossy(int v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(optimizeLossy: v, error: null));
  }

  void setOptimizeFrameDrop(int v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(optimizeFrameDrop: v, error: null));
  }

  void setOptimizeLocalPalettes(bool v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(optimizeLocalPalettes: v, error: null));
  }

  void setFps(int v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(fps: v.clamp(1, 60), error: null));
  }

  void setLoopCount(int v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(loopCount: v < 0 ? 0 : v, error: null));
  }

  void setBoomerang(bool v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(
        boomerang: v, smoothLoop: v ? false : s.smoothLoop, error: null));
  }

  void setSmoothLoop(bool v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(
        smoothLoop: v, boomerang: v ? false : s.boomerang, error: null));
  }

  void setSmoothLoopCrossfadeMs(int v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    final clamped = v.clamp(500, 1000);
    final rounded = clamped - (clamped % 100);
    state = AsyncData(_disableSmoothLoopIfInvalid(
        s.copyWith(smoothLoopCrossfadeMs: rounded, error: null)));
  }

  void setVolume(double v) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(volume: v.clamp(0.0, 2.0), error: null));
  }

  // ── Pixel-space layer resolution ─────────────────────────────────────────

  ({int? x, int? y, int? w, int? h}) _cropPixels(VideoStudioState s) {
    final info = s.sourceInfo;
    if (s.isCropFull || info == null) {
      return (x: null, y: null, w: null, h: null);
    }
    return (
      x: (s.cropNormalized.left * info.width).round(),
      y: (s.cropNormalized.top * info.height).round(),
      w: (s.cropNormalized.width * info.width).round(),
      h: (s.cropNormalized.height * info.height).round(),
    );
  }

  ({int? startMs, int? durationMs}) _trimParams(VideoStudioState s) {
    if (!s.hasTrim) return (startMs: null, durationMs: null);
    return (
      startMs: s.trimStartMs > 0 ? s.trimStartMs : null,
      durationMs: s.trimDurationMs > 0 ? s.trimDurationMs : null,
    );
  }

  DateTime _lastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);

  // ponytail: ffmpeg's -progress pipe can fire tens of times/sec; each hit
  // rebuilds this whole 3500-line screen since the view watches the full
  // state. Throttling at this single funnel (all export/bake paths route
  // through it) caps rebuilds to ~10/sec without touching every call site
  // or splitting the view into scoped Consumers.
  void _onProgress(FfmpegProgress p) {
    final cur = state.valueOrNull;
    if (cur == null) return;
    final now = DateTime.now();
    if (now.difference(_lastProgressEmit).inMilliseconds < 100 &&
        p.fraction < 1.0) {
      return;
    }
    _lastProgressEmit = now;
    state = AsyncData(cur.copyWith(progress: p));
  }

  List<CutSegment> _capRanges(List<CutSegment> ranges, int maxMs) {
    final result = <CutSegment>[];
    var remaining = maxMs;
    for (final r in ranges) {
      if (remaining <= 0) break;
      final len = r.endMs - r.startMs;
      if (len <= remaining) {
        result.add(r);
        remaining -= len;
      } else {
        result.add((startMs: r.startMs, endMs: r.startMs + remaining));
        break;
      }
    }
    return result;
  }

  // ── Make GIF (bake video layers → gif, switch stage) ──────────────────────

  Future<bool> makeGif() async {
    final s = state.valueOrNull;
    if (s == null || s.sourceFile == null || s.isProcessing || s.isGif) {
      return false;
    }
    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, activeTool: null));

    final c = _cropPixels(s);
    final t = _trimParams(s);
    const maxGifMs = 40000;
    List<CutSegment>? kr;
    int? capDurationMs;
    int? capOutputMs;
    if (s.hasCut) {
      kr = _capRanges(s.keepRanges, maxGifMs);
      capOutputMs = s.cutOutputMs.clamp(0, maxGifMs);
    } else {
      capDurationMs = (t.durationMs ?? (s.sourceDurationMs > 0 ? s.sourceDurationMs : maxGifMs)).clamp(0, maxGifMs);
    }
    final result = await _ffmpeg.bakeVideoToGif(
      input: s.sourceFile!,
      cropX: c.x,
      cropY: c.y,
      cropW: c.w,
      cropH: c.h,
      scaleW: (s.gifWidthCapped && !s.forceOriginalGifWidthActive)
          ? s.maxGifWidth
          : s.targetWidth,
      speedFactor: s.speedFactor,
      fps: s.fps > s.maxGifFps ? s.maxGifFps : s.fps,
      totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
      startMs: s.hasCut ? null : t.startMs,
      durationMs: capDurationMs,
      keepRanges: kr,
      keepRangesOutputMs: capOutputMs,
      onProgress: _onProgress,
    );

    return await result.fold(
      ok: (gif) async {
        // Re-baking from video starts a fresh GIF session: drop the old stack
        // and free the applied-video temp the bake just consumed.
        _clearHistory();
        _freeAppliedVideo();
        final ginfo = await _ffmpeg.probe(gif);
        final baked = VideoStudioState(
          inputFile: s.inputFile,
          stage: EditStage.gif,
          sourceFile: gif,
          sourceInfo: ginfo,
          activeTool: StudioTool.crop,
          fontFiles: _fontFiles,
          fontFamilies: _fontFamilies,
          textItems: s.textItems,
          doOptimize: s.doOptimize,
          optimizeColors: s.optimizeColors,
          optimizeLossy: s.optimizeLossy,
          optimizeFrameDrop: s.optimizeFrameDrop,
          optimizeLocalPalettes: s.optimizeLocalPalettes,
          fps: s.fps,
          loopCount: s.loopCount,
          boomerang: s.boomerang,
          // Unused while editing the gif (no audio), carried through so
          // discardGif can restore it if the user goes back to the video.
          volume: s.volume,
        );
        state = AsyncData(baked);
        _pushVersion(baked, ownedDir: gif.parent.path);
        return true;
      },
      err: (e) async {
        final cur = state.valueOrNull ?? const VideoStudioState();
        state = AsyncData(cur.copyWith(
            isProcessing: false, progress: null, error: e.message));
        return false;
      },
    );
  }

  /// Discards the baked GIF and returns to editing the original video.
  Future<void> discardGif() async {
    final s = state.valueOrNull;
    final input = s?.inputFile;
    if (input == null) return;
    _clearHistory();
    _freeAppliedVideo();
    final info = await _ffmpeg.probe(input);
    state = AsyncData(VideoStudioState(
      inputFile: input,
      stage: EditStage.video,
      sourceFile: input,
      sourceInfo: info,
      activeTool: StudioTool.crop,
      fontFiles: _fontFiles,
      fontFamilies: _fontFamilies,
      fps: s?.fps ?? 16,
      loopCount: s?.loopCount ?? 0,
      boomerang: s?.boomerang ?? false,
      volume: s?.volume ?? 1.0,
    ));
  }

  /// Bakes any pending GIF edits, converts to WebM, and switches the studio
  /// into the video-editing flow with that WebM as the new source. One-way —
  /// there is no "back to GIF" from here, mirroring how video-stage has no
  /// "back to WebM".
  Future<bool> makeWebm() async {
    final s = state.valueOrNull;
    if (s == null || s.sourceFile == null || s.isProcessing || !s.isGif) {
      return false;
    }
    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, activeTool: null));

    final (workingFile, editDir) = await _runGifPipeline(s, s.sourceFile!);
    if (workingFile == null) return false;

    final workingDir = workingFile.parent.path;
    if (editDir != null && editDir != workingDir) {
      await _ffmpeg.cleanJobAt(editDir);
    }

    final result = await _ffmpeg.convertToWebm(
      input: workingFile,
      crf: 32,
      cpuUsed: 4,
      totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
      onProgress: _onProgress,
    );

    return await result.fold(
      ok: (webm) async {
        // workingFile is either the history-owned sourceFile (untouched — no
        // pending edits) or a fresh pipeline temp never registered in
        // history; clearHistory frees the former, the explicit cleanJobAt
        // below frees the latter.
        final ownedByHistory = workingFile.path == s.sourceFile!.path;
        _clearHistory();
        _freeAppliedVideo();
        if (!ownedByHistory) await _ffmpeg.cleanJobAt(workingDir);
        final info = await _ffmpeg.probe(webm);
        _appliedVideoDir = webm.parent.path;
        state = AsyncData(VideoStudioState(
          inputFile: webm,
          stage: EditStage.video,
          sourceFile: webm,
          sourceInfo: info,
          activeTool: StudioTool.crop,
          fontFiles: _fontFiles,
          fontFamilies: _fontFamilies,
          volume: s.volume,
        ));
        return true;
      },
      err: (e) async {
        if (workingFile.path != s.sourceFile!.path) {
          await _ffmpeg.cleanJobAt(workingDir);
        }
        final cur = state.valueOrNull ?? const VideoStudioState();
        state = AsyncData(cur.copyWith(
            isProcessing: false, progress: null, error: e.message));
        return false;
      },
    );
  }

  // ── GIF render pipeline ───────────────────────────────────────────────────

  /// Runs editGif → optimizeGif for [s] starting from [workingFile].
  /// Returns `(result, editDir)`: result is null on error (state already
  /// updated); editDir is the editGif temp dir when both steps ran so the
  /// caller can free it if needed.
  Future<(File?, String?)> _runGifPipeline(
      VideoStudioState s, File workingFile) async {
    final needsEdit = s.needsGifEdit;
    final needsText = s.hasText && s.fontReady && s.sourceInfo != null;
    String? editDir;
    // Frees a temp produced by an earlier step once a later step supersedes it.
    String? priorDir;

    // Text bakes first, against the source-gif dimensions the preview drags
    // over; later geometry edits then scale/crop the texted frames.
    if (needsText) {
      final items = s.textItems.where((i) => i.text.trim().isNotEmpty).toList();
      final result = await _ffmpeg.textOverlayMulti(
        input: workingFile,
        items: items,
        mediaInfo: s.sourceInfo!,
        totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
        onProgress: (needsEdit || s.doOptimize) ? null : _onProgress,
      );
      File? next;
      await result.fold(
        ok: (f) async { next = f; },
        err: (e) async {
          final cur = state.valueOrNull ?? const VideoStudioState();
          state = AsyncData(cur.copyWith(
              isProcessing: false, progress: null, error: e.message));
        },
      );
      if (next == null) return (null, null);
      priorDir = next!.parent.path;
      workingFile = next!;
    }

    if (needsEdit) {
      final c = _cropPixels(s);
      final t = _trimParams(s);
      final srcFps = s.sourceInfo?.fps;
      final fpsChanged = srcFps != null && (s.fps - srcFps).abs() >= 0.5;
      final result = await _ffmpeg.editGif(
        input: workingFile,
        cropX: c.x,
        cropY: c.y,
        cropW: c.w,
        cropH: c.h,
        scaleW: s.targetWidth,
        speedFactor: s.speedFactor,
        startMs: t.startMs,
        durationMs:
            s.smoothLoop ? (t.durationMs ?? s.sourceDurationMs) : t.durationMs,
        totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
        fps: fpsChanged
            ? s.fps
            : (s.smoothLoop ? (srcFps?.round() ?? s.fps) : null),
        loopCount: s.loopCount,
        boomerang: s.boomerang,
        smoothLoop: s.smoothLoop,
        crossfadeMs: s.smoothLoopCrossfadeMs,
        onProgress: s.doOptimize ? null : _onProgress,
      );
      File? next;
      await result.fold(
        ok: (f) async { next = f; },
        err: (e) async {
          final cur = state.valueOrNull ?? const VideoStudioState();
          state = AsyncData(cur.copyWith(
              isProcessing: false, progress: null, error: e.message));
        },
      );
      if (next == null) {
        if (priorDir != null) await _ffmpeg.cleanJobAt(priorDir);
        return (null, null);
      }
      // The intermediate text-only gif is now superseded — free it.
      if (priorDir != null) await _ffmpeg.cleanJobAt(priorDir);
      priorDir = next!.parent.path;
      workingFile = next!;
    }

    if (s.doOptimize) {
      if (needsEdit || needsText) editDir = priorDir;
      final result = await _ffmpeg.optimizeGif(
        input: workingFile,
        colors: s.optimizeColors,
        lossy: s.optimizeLossy,
        frameDrop: s.optimizeFrameDrop,
        localPalettes: s.optimizeLocalPalettes,
        loopCount: s.loopCount,
        onProgress: _onProgress,
      );
      File? next;
      await result.fold(
        ok: (f) async { next = f; },
        err: (e) async {
          final cur = state.valueOrNull ?? const VideoStudioState();
          state = AsyncData(cur.copyWith(
              isProcessing: false, progress: null, error: e.message));
        },
      );
      if (next == null) {
        if (priorDir != null) await _ffmpeg.cleanJobAt(priorDir);
        return (null, null);
      }
      workingFile = next!;
    }

    return (workingFile, editDir);
  }

  // ── Export ────────────────────────────────────────────────────────────────

  /// Bakes the current video edits (crop · resize · speed · trim · text) into a
  /// temp video and swaps it in as the live preview source — without saving.
  /// Baked layers are reset afterward (and [editsApplied] set) so a later Export
  /// saves the baked file directly instead of re-encoding.
  ///
  /// Returns false (no-op) when there is nothing to bake.
  Future<bool> applyVideoEdits() async {
    final s = state.valueOrNull;
    if (s == null || s.sourceFile == null || s.isProcessing || s.isGif) {
      return false;
    }

    // Nothing pending → don't burn an encode.
    if (!s.hasPendingApply) return false;

    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, activeTool: null));

    final c = _cropPixels(s);
    final t = _trimParams(s);
    final kr = s.hasCut ? s.keepRanges : null;
    final result = await _ffmpeg.editVideo(
      input: s.sourceFile!,
      cropX: c.x,
      cropY: c.y,
      cropW: c.w,
      cropH: c.h,
      scaleW: s.targetWidth,
      speedFactor: s.speedFactor,
      hasAudio: s.hasAudio,
      volume: s.volume,
      totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
      startMs: s.hasCut ? null : t.startMs,
      durationMs: s.hasCut ? null : t.durationMs,
      overlayItems: s.hasText ? s.textItems : null,
      mediaInfo: s.sourceInfo,
      keepRanges: kr,
      keepRangesOutputMs: s.hasCut ? s.cutOutputMs : null,
      smoothLoop: s.smoothLoop,
      crossfadeMs: s.smoothLoopCrossfadeMs,
      loopDurationMs: s.smoothLoop ? s.effectiveOutputMs : null,
      onProgress: _onProgress,
    );

    File? baked;
    await result.fold(
      ok: (f) async { baked = f; },
      err: (e) async {
        final cur = state.valueOrNull ?? const VideoStudioState();
        state = AsyncData(cur.copyWith(
            isProcessing: false, progress: null, error: e.message));
      },
    );
    if (baked == null) return false;

    // Previous applied temp is superseded; free it (never the user's own file).
    _freeAppliedVideo();
    _appliedVideoDir = baked!.parent.path;

    final info = await _ffmpeg.probe(baked!);
    state = AsyncData(VideoStudioState(
      inputFile: s.inputFile,
      stage: EditStage.video,
      sourceFile: baked,
      sourceInfo: info,
      activeTool: s.activeTool,
      fontFiles: _fontFiles,
      fontFamilies: _fontFamilies,
      // Crop/resize/speed/trim/text are now baked into the frames → reset so a
      // later Export does not double-apply them.
      fps: s.fps,
      loopCount: s.loopCount,
      boomerang: s.boomerang,
      editsApplied: true,
    ));
    return true;
  }

  Future<bool> exportVideo(
      {ExportVideoFormat format = ExportVideoFormat.mp4}) async {
    final s = state.valueOrNull;
    if (s == null || s.sourceFile == null || s.isProcessing || s.isGif) {
      return false;
    }

    // Untouched source → straight file copy, keeping container/codec. The UI
    // only offers this while hasComparableEdit is false, so nothing is lost.
    if (format == ExportVideoFormat.original) {
      final ext = s.originalExportExt ?? 'mp4';
      final saved = await _export.saveVideo(s.sourceFile!,
          defaultName: 'studio.$ext', extension: ext);
      if (saved != null) await _addRecent(saved);
      return saved != null;
    }

    final webm = format == ExportVideoFormat.webm;

    // Apply ran and nothing changed since → sourceFile is already the fully
    // baked (h264) frames. MP4 saves it as-is; WebM still needs its own
    // encode pass over those baked frames — exactly the converter tool's op
    // (PLAN.md §8), so it reuses convertToWebm rather than editVideo.
    if (s.editsApplied) {
      if (!webm) {
        final saved =
            await _export.saveVideo(s.sourceFile!, defaultName: 'studio.mp4');
        if (saved != null) await _addRecent(saved);
        return saved != null;
      }
      state = AsyncData(s.copyWith(
          isProcessing: true, progress: null, error: null, activeTool: null));
      final result = await _ffmpeg.convertToWebm(
        input: s.sourceFile!,
        crf: 32,
        cpuUsed: 4,
        keepAudio: s.hasAudio,
        totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
        onProgress: _onProgress,
      );
      return _saveWebmResult(result);
    }

    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, activeTool: null));

    final c = _cropPixels(s);
    final t = _trimParams(s);
    final kr = s.hasCut ? s.keepRanges : null;
    // Text overlay layers bake into the encode (drawtext before crop/scale) so
    // they scale/crop with the content, matching the live preview. WebM only
    // admits VP8/VP9/AV1 (never stream-copy from h264), so editVideo always
    // runs a real encode when webm is true — see its isNoOp guard.
    final result = await _ffmpeg.editVideo(
      input: s.sourceFile!,
      cropX: c.x,
      cropY: c.y,
      cropW: c.w,
      cropH: c.h,
      scaleW: s.targetWidth,
      speedFactor: s.speedFactor,
      hasAudio: s.hasAudio,
      volume: s.volume,
      totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
      startMs: s.hasCut ? null : t.startMs,
      durationMs: s.hasCut ? null : t.durationMs,
      overlayItems: s.hasText ? s.textItems : null,
      mediaInfo: s.sourceInfo,
      keepRanges: kr,
      keepRangesOutputMs: s.hasCut ? s.cutOutputMs : null,
      smoothLoop: s.smoothLoop,
      crossfadeMs: s.smoothLoopCrossfadeMs,
      loopDurationMs: s.smoothLoop ? s.effectiveOutputMs : null,
      onProgress: _onProgress,
      webm: webm,
    );

    return webm ? _saveWebmResult(result) : _saveResult(result, isGif: false);
  }

  Future<bool> _saveWebmResult(Result<File, FfmpegError> result) async {
    final cur = state.valueOrNull ?? const VideoStudioState();
    return await result.fold(
      ok: (file) async {
        state = AsyncData(cur.copyWith(isProcessing: false, progress: null));
        final saved =
            await _export.saveWebm(file, defaultName: 'studio.webm');
        if (saved != null) {
          await _ffmpeg.cleanJobAt(file.parent.path);
          await _addRecent(saved);
        }
        return saved != null;
      },
      err: (e) async {
        state = AsyncData(cur.copyWith(
            isProcessing: false, progress: null, error: e.message));
        return false;
      },
    );
  }

  Future<bool> exportGif() async {
    final s = state.valueOrNull;
    if (s == null || s.sourceFile == null || s.isProcessing || !s.isGif) {
      return false;
    }

    // Apply was called and no options changed since — save the baked file as-is.
    if (s.editsApplied) {
      final saved =
          await _export.saveGif(s.sourceFile!, defaultName: 'studio.gif');
      if (saved != null) await _addRecent(saved);
      return saved != null;
    }

    // Fast path: nothing to apply → save the baked GIF directly.
    if (!s.hasPendingApply) {
      final saved =
          await _export.saveGif(s.sourceFile!, defaultName: 'studio.gif');
      if (saved != null) await _addRecent(saved);
      return saved != null;
    }

    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, activeTool: null));

    final (workingFile, _) = await _runGifPipeline(s, s.sourceFile!);
    if (workingFile == null) return false;

    final cur = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(cur.copyWith(isProcessing: false, progress: null));
    final saved = await _export.saveGif(workingFile, defaultName: 'studio.gif');
    if (saved != null) {
      await _ffmpeg.cleanCurrentJob();
      await _addRecent(saved);
    }
    return saved != null;
  }

  /// Bakes the current GIF edits (crop · resize · speed · text · fps · loop ·
  /// boomerang · optimize) into a temp GIF and swaps it in as the live preview
  /// source — without saving. Lets the user see fps/loop/boomerang/etc applied.
  /// Baked layers are reset afterward so a later Export does not double-apply.
  ///
  /// Returns false (no-op) when there is nothing to bake.
  Future<bool> applyEdits() async {
    final s = state.valueOrNull;
    if (s == null || s.sourceFile == null || s.isProcessing || !s.isGif) {
      return false;
    }

    // Nothing pending → don't burn an ffmpeg pass.
    if (!s.hasPendingApply) return false;

    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, activeTool: null));

    final (workingFile, editDir) = await _runGifPipeline(s, s.sourceFile!);
    if (workingFile == null) return false;

    // Swap the baked temp in as the new live source. The previous version is
    // kept in history (undo target); only the throwaway editGif temp is freed.
    final newDir = workingFile.parent.path;
    if (editDir != null && editDir != newDir) {
      await _ffmpeg.cleanJobAt(editDir);
    }

    final ginfo = await _ffmpeg.probe(workingFile);
    final applied = VideoStudioState(
      inputFile: s.inputFile,
      stage: EditStage.gif,
      sourceFile: workingFile,
      sourceInfo: ginfo,
      activeTool: s.activeTool,
      fontFiles: _fontFiles,
      fontFamilies: _fontFamilies,
      // Text/crop/resize/speed baked into frames → textItems reset to []; loop
      // is restamped idempotently so it stays selected, boomerang now baked.
      optimizeColors: s.optimizeColors,
      optimizeLossy: s.optimizeLossy,
      optimizeFrameDrop: s.optimizeFrameDrop,
      optimizeLocalPalettes: s.optimizeLocalPalettes,
      fps: s.fps,
      loopCount: s.loopCount,
      boomerang: false,
      smoothLoop: false,
      editsApplied: true,
    );
    // Re-snapshot the current history entry with the pre-apply editing state
    // `s` (parent source + the pending crop/resize/speed/trim/cut/text/boomerang
    // layers). Undo then returns those layers to the panels over the parent
    // source — not the post-bake reset state — so a reverted version can be
    // tweaked and re-applied to reproduce this result. ownedDir is unchanged:
    // `s` previews the same parent file the entry already owns.
    if (_cursor >= 0) {
      _history[_cursor] =
          _GifVersion(state: s, ownedDir: _history[_cursor].ownedDir);
    }
    state = AsyncData(applied);
    _pushVersion(applied, ownedDir: newDir);
    return true;
  }

  Future<bool> _saveResult(Result<File, FfmpegError> result,
      {required bool isGif}) async {
    final cur = state.valueOrNull ?? const VideoStudioState();
    return await result.fold(
      ok: (File file) async {
        state = AsyncData(cur.copyWith(isProcessing: false, progress: null));
        final saved = isGif
            ? await _export.saveGif(file, defaultName: 'studio.gif')
            : await _export.saveVideo(file, defaultName: 'studio.mp4');
        if (saved != null) {
          await _ffmpeg.cleanCurrentJob();
          await _addRecent(saved);
        }
        return saved != null;
      },
      err: (e) async {
        state = AsyncData(cur.copyWith(
            isProcessing: false, progress: null, error: e.message));
        return false;
      },
    );
  }

  Future<void> _addRecent(File saved) async {
    await ref.read(recentsProvider.notifier).add(RecentExport(
          path: saved.path,
          toolName: 'Video Studio',
          toolRoute: '/video-studio',
          timestamp: DateTime.now(),
        ));
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> cancel() async {
    await _ffmpeg.cancel();
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(isProcessing: false, progress: null));
  }

  void clear() {
    _ffmpeg.cleanCurrentJob();
    _clearHistory();
    _freeAppliedVideo();
    state = AsyncData(VideoStudioState(
        fontFiles: _fontFiles, fontFamilies: _fontFamilies));
  }
}

final videoStudioControllerProvider =
    AsyncNotifierProvider<VideoStudioController, VideoStudioState>(
  VideoStudioController.new,
);
