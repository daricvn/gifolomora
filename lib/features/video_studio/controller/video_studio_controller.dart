import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/files/export_service.dart';
import '../../../core/services/ffmpeg/ffmpeg_progress.dart';
import '../../../core/services/ffmpeg/ffmpeg_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';
import '../../../core/utils/font_resolver.dart';
import '../../../core/utils/result.dart';

/// Which artifact the studio is currently editing.
enum EditStage { video, gif }

/// The tool whose editor panel is open in the dock.
enum StudioTool { crop, resize, speed, trim, text, optimize, properties }

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
    this.overlayText = '',
    this.overlayPosition = 'center',
    this.overlayFontSize = 36,
    this.overlayFontColor = 'white',
    this.overlayFontFile,
    this.doOptimize = false,
    this.optimizeColors = 200,
    this.optimizeLossy = 20,
    this.fps = 16,
    this.loopCount = 0,
    this.boomerang = false,
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

  /// Trim in/out points (ms). Both 0 = no trim (full duration).
  final int trimStartMs;
  final int trimEndMs;

  /// Text overlay layer.
  final String overlayText;
  final String overlayPosition;
  final int overlayFontSize;
  final String overlayFontColor;
  final String? overlayFontFile;

  final bool doOptimize;
  final int optimizeColors;
  final int optimizeLossy;

  /// Output-GIF properties. [fps] is baked at make-GIF time (frames can't be
  /// added later). [loopCount] 0 = infinite. [boomerang] appends a reversed
  /// copy at export for a seamless ping-pong loop.
  final int fps;
  final int loopCount;
  final bool boomerang;

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

  bool get hasText => overlayText.trim().isNotEmpty;

  /// True when at least one layer would change the output.
  bool get hasEdits =>
      !isCropFull ||
      targetWidth != null ||
      (speedFactor - 1.0).abs() >= 0.001 ||
      hasText;

  VideoStudioState copyWith({
    Object? inputFile = _s,
    EditStage? stage,
    Object? sourceFile = _s,
    Object? sourceInfo = _s,
    Rect? cropNormalized,
    Object? targetWidth = _s,
    double? speedFactor,
    int? trimStartMs,
    int? trimEndMs,
    String? overlayText,
    String? overlayPosition,
    int? overlayFontSize,
    String? overlayFontColor,
    Object? overlayFontFile = _s,
    bool? doOptimize,
    int? optimizeColors,
    int? optimizeLossy,
    int? fps,
    int? loopCount,
    bool? boomerang,
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
      trimStartMs: trimStartMs ?? this.trimStartMs,
      trimEndMs: trimEndMs ?? this.trimEndMs,
      overlayText: overlayText ?? this.overlayText,
      overlayPosition: overlayPosition ?? this.overlayPosition,
      overlayFontSize: overlayFontSize ?? this.overlayFontSize,
      overlayFontColor: overlayFontColor ?? this.overlayFontColor,
      overlayFontFile: identical(overlayFontFile, _s)
          ? this.overlayFontFile
          : overlayFontFile as String?,
      doOptimize: doOptimize ?? this.doOptimize,
      optimizeColors: optimizeColors ?? this.optimizeColors,
      optimizeLossy: optimizeLossy ?? this.optimizeLossy,
      fps: fps ?? this.fps,
      loopCount: loopCount ?? this.loopCount,
      boomerang: boomerang ?? this.boomerang,
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

  @override
  Future<VideoStudioState> build() async {
    _ffmpeg = ref.read(ffmpegServiceProvider);
    _export = ref.read(exportServiceProvider);
    // App close / provider disposal → free every temp the session still owns.
    ref.onDispose(() {
      _ffmpeg.cleanCurrentJob();
      _clearHistory();
    });
    return VideoStudioState(overlayFontFile: FontResolver.resolve());
  }

  /// Undo/redo history of GIF versions for the current session. Each entry is a
  /// restorable state snapshot plus the temp job dir it owns. The first entry is
  /// the base GIF (baked from video, or the user's loaded GIF with no owned dir);
  /// every "Apply" pushes a new entry. The whole stack — and every owned temp
  /// dir — is freed when the source changes (setInput / makeGif / discardGif),
  /// on reset (clear), and on dispose (app close).
  final List<_GifVersion> _history = [];
  int _cursor = -1;

  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor >= 0 && _cursor < _history.length - 1;

  /// Appends [snapshot] as the new current version, branching off [_cursor].
  /// Any redo tail is dropped and its owned temps freed.
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
  bool undo() => canUndo && _restore(_cursor - 1);

  /// Steps forward to the next applied GIF version.
  bool redo() => canRedo && _restore(_cursor + 1);

  // ── Input ──────────────────────────────────────────────────────────────

  Future<void> setInput(File file) async {
    _ffmpeg.cleanCurrentJob();
    _clearHistory();
    state = AsyncData(VideoStudioState(
      inputFile: file,
      isProbing: true,
      overlayFontFile: FontResolver.resolve(),
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
      overlayFontFile: FontResolver.resolve(),
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
    state = AsyncData(s.copyWith(speedFactor: factor, error: null));
  }

  void setTrimStart(int ms) {
    final s = state.valueOrNull ?? const VideoStudioState();
    final max = s.effectiveTrimEndMs > 1000 ? s.effectiveTrimEndMs - 1000 : 0;
    state = AsyncData(s.copyWith(
        trimStartMs: ms.clamp(0, max), error: null));
  }

  void setTrimEnd(int ms) {
    final s = state.valueOrNull ?? const VideoStudioState();
    final min = s.trimStartMs + 1000;
    final max = s.sourceDurationMs > 0 ? s.sourceDurationMs : ms;
    state = AsyncData(s.copyWith(
        trimEndMs: ms.clamp(min, max), error: null));
  }

  void resetTrim() {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(trimStartMs: 0, trimEndMs: 0, error: null));
  }

  void setOverlayText(String text) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(overlayText: text, error: null));
  }

  void setOverlayPosition(String position) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(overlayPosition: position, error: null));
  }

  void setOverlayFontSize(int size) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(overlayFontSize: size, error: null));
  }

  void setOverlayFontColor(String color) {
    final s = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(s.copyWith(overlayFontColor: color, error: null));
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
    state = AsyncData(s.copyWith(boomerang: v, error: null));
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

  void _onProgress(FfmpegProgress p) {
    final cur = state.valueOrNull;
    if (cur != null) state = AsyncData(cur.copyWith(progress: p));
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
    final result = await _ffmpeg.bakeVideoToGif(
      input: s.sourceFile!,
      cropX: c.x,
      cropY: c.y,
      cropW: c.w,
      cropH: c.h,
      scaleW: s.targetWidth,
      speedFactor: s.speedFactor,
      fps: s.fps,
      totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
      startMs: t.startMs,
      durationMs: t.durationMs,
      onProgress: _onProgress,
    );

    return await result.fold(
      ok: (gif) async {
        // Re-baking from video starts a fresh GIF session: drop the old stack.
        _clearHistory();
        final ginfo = await _ffmpeg.probe(gif);
        final baked = VideoStudioState(
          inputFile: s.inputFile,
          stage: EditStage.gif,
          sourceFile: gif,
          sourceInfo: ginfo,
          activeTool: StudioTool.crop,
          overlayFontFile: s.overlayFontFile,
          overlayText: s.overlayText,
          overlayPosition: s.overlayPosition,
          overlayFontSize: s.overlayFontSize,
          overlayFontColor: s.overlayFontColor,
          doOptimize: s.doOptimize,
          optimizeColors: s.optimizeColors,
          optimizeLossy: s.optimizeLossy,
          fps: s.fps,
          loopCount: s.loopCount,
          boomerang: s.boomerang,
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
    final info = await _ffmpeg.probe(input);
    state = AsyncData(VideoStudioState(
      inputFile: input,
      stage: EditStage.video,
      sourceFile: input,
      sourceInfo: info,
      activeTool: StudioTool.crop,
      overlayFontFile: s?.overlayFontFile ?? FontResolver.resolve(),
      overlayText: s?.overlayText ?? '',
      overlayPosition: s?.overlayPosition ?? 'center',
      overlayFontSize: s?.overlayFontSize ?? 36,
      overlayFontColor: s?.overlayFontColor ?? 'white',
      fps: s?.fps ?? 16,
      loopCount: s?.loopCount ?? 0,
      boomerang: s?.boomerang ?? false,
    ));
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<bool> exportVideo() async {
    final s = state.valueOrNull;
    if (s == null || s.sourceFile == null || s.isProcessing || s.isGif) {
      return false;
    }
    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, activeTool: null));

    final c = _cropPixels(s);
    final t = _trimParams(s);
    final text = s.overlayText.trim();
    final result = await _ffmpeg.editVideo(
      input: s.sourceFile!,
      cropX: c.x,
      cropY: c.y,
      cropW: c.w,
      cropH: c.h,
      scaleW: s.targetWidth,
      speedFactor: s.speedFactor,
      hasAudio: s.hasAudio,
      totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
      startMs: t.startMs,
      durationMs: t.durationMs,
      overlayText: text.isNotEmpty ? text : null,
      overlayFontFile: text.isNotEmpty ? s.overlayFontFile : null,
      overlayFontSize: s.overlayFontSize,
      overlayFontColor: s.overlayFontColor,
      overlayPosition: s.overlayPosition,
      onProgress: _onProgress,
    );

    return _saveResult(result, isGif: false);
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

    final text = s.overlayText.trim();

    // FPS only re-times when it differs from the GIF's current rate (a baked
    // GIF already carries the chosen fps, so an untouched export skips this).
    final srcFps = s.sourceInfo?.fps;
    final fpsChanged = srcFps != null && (s.fps - srcFps).abs() >= 0.5;

    // Boomerang always needs a re-encode; a non-infinite loop needs one too
    // unless the optimizer pass will stamp the loop count for us.
    final needsEdit = s.hasEdits ||
        s.boomerang ||
        fpsChanged ||
        (s.loopCount != 0 && !s.doOptimize);

    // Fast path: nothing to apply → save the baked GIF directly.
    if (!needsEdit && !s.doOptimize) {
      final saved =
          await _export.saveGif(s.sourceFile!, defaultName: 'studio.gif');
      if (saved != null) await _addRecent(saved);
      return saved != null;
    }

    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, activeTool: null));

    File workingFile = s.sourceFile!;

    // Step 1: apply spatial edits + text + boomerang + loop count (if any).
    if (needsEdit) {
      final c = _cropPixels(s);
      final editResult = await _ffmpeg.editGif(
        input: workingFile,
        cropX: c.x,
        cropY: c.y,
        cropW: c.w,
        cropH: c.h,
        scaleW: s.targetWidth,
        speedFactor: s.speedFactor,
        totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
        overlayText: text.isNotEmpty ? text : null,
        overlayFontFile: text.isNotEmpty ? s.overlayFontFile : null,
        overlayFontSize: s.overlayFontSize,
        overlayFontColor: s.overlayFontColor,
        overlayPosition: s.overlayPosition,
        fps: fpsChanged ? s.fps : null,
        loopCount: s.loopCount,
        boomerang: s.boomerang,
        onProgress: s.doOptimize ? null : _onProgress,
      );
      bool failed = false;
      await editResult.fold(
        ok: (f) async { workingFile = f; },
        err: (e) async {
          final cur = state.valueOrNull ?? const VideoStudioState();
          state = AsyncData(cur.copyWith(
              isProcessing: false, progress: null, error: e.message));
          failed = true;
        },
      );
      if (failed) return false;
    }

    // Step 2: optimize (if enabled).
    if (s.doOptimize) {
      final optResult = await _ffmpeg.optimizeGif(
        input: workingFile,
        colors: s.optimizeColors,
        lossy: s.optimizeLossy,
        loopCount: s.loopCount,
        onProgress: _onProgress,
        totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
      );
      bool failed = false;
      await optResult.fold(
        ok: (f) async { workingFile = f; },
        err: (e) async {
          final cur = state.valueOrNull ?? const VideoStudioState();
          state = AsyncData(cur.copyWith(
              isProcessing: false, progress: null, error: e.message));
          failed = true;
        },
      );
      if (failed) return false;
    }

    final cur = state.valueOrNull ?? const VideoStudioState();
    state = AsyncData(cur.copyWith(isProcessing: false, progress: null));
    final saved =
        await _export.saveGif(workingFile, defaultName: 'studio.gif');
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

    final text = s.overlayText.trim();
    final srcFps = s.sourceInfo?.fps;
    final fpsChanged = srcFps != null && (s.fps - srcFps).abs() >= 0.5;
    final needsEdit = s.hasEdits ||
        s.boomerang ||
        fpsChanged ||
        (s.loopCount != 0 && !s.doOptimize);

    // Nothing pending → don't burn an ffmpeg pass.
    if (!needsEdit && !s.doOptimize) return false;

    state = AsyncData(s.copyWith(
        isProcessing: true, progress: null, error: null, activeTool: null));

    File workingFile = s.sourceFile!;
    String? intermediateDir; // editGif output to free if optimize re-encodes.

    // Step 1: spatial edits + text + fps + loop + boomerang.
    if (needsEdit) {
      final c = _cropPixels(s);
      final editResult = await _ffmpeg.editGif(
        input: workingFile,
        cropX: c.x,
        cropY: c.y,
        cropW: c.w,
        cropH: c.h,
        scaleW: s.targetWidth,
        speedFactor: s.speedFactor,
        totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
        overlayText: text.isNotEmpty ? text : null,
        overlayFontFile: text.isNotEmpty ? s.overlayFontFile : null,
        overlayFontSize: s.overlayFontSize,
        overlayFontColor: s.overlayFontColor,
        overlayPosition: s.overlayPosition,
        fps: fpsChanged ? s.fps : null,
        loopCount: s.loopCount,
        boomerang: s.boomerang,
        onProgress: s.doOptimize ? null : _onProgress,
      );
      bool failed = false;
      await editResult.fold(
        ok: (f) async { workingFile = f; },
        err: (e) async {
          final cur = state.valueOrNull ?? const VideoStudioState();
          state = AsyncData(cur.copyWith(
              isProcessing: false, progress: null, error: e.message));
          failed = true;
        },
      );
      if (failed) return false;
    }

    // Step 2: optimize (if enabled).
    if (s.doOptimize) {
      if (needsEdit) intermediateDir = workingFile.parent.path;
      final optResult = await _ffmpeg.optimizeGif(
        input: workingFile,
        colors: s.optimizeColors,
        lossy: s.optimizeLossy,
        loopCount: s.loopCount,
        onProgress: _onProgress,
        totalMs: s.sourceDurationMs > 0 ? s.sourceDurationMs : null,
      );
      bool failed = false;
      await optResult.fold(
        ok: (f) async { workingFile = f; },
        err: (e) async {
          final cur = state.valueOrNull ?? const VideoStudioState();
          state = AsyncData(cur.copyWith(
              isProcessing: false, progress: null, error: e.message));
          failed = true;
        },
      );
      if (failed) return false;
    }

    // Swap the baked temp in as the new live source. The previous version is
    // kept in history (undo target); only the throwaway editGif temp is freed.
    final newDir = workingFile.parent.path;
    if (intermediateDir != null && intermediateDir != newDir) {
      await _ffmpeg.cleanJobAt(intermediateDir);
    }

    final ginfo = await _ffmpeg.probe(workingFile);
    final applied = VideoStudioState(
      inputFile: s.inputFile,
      stage: EditStage.gif,
      sourceFile: workingFile,
      sourceInfo: ginfo,
      activeTool: s.activeTool,
      overlayFontFile: s.overlayFontFile,
      // Text/crop/resize/speed/trim baked → defaults; loop is restamped
      // idempotently so it stays selected, boomerang is now in the frames.
      overlayPosition: s.overlayPosition,
      overlayFontSize: s.overlayFontSize,
      overlayFontColor: s.overlayFontColor,
      optimizeColors: s.optimizeColors,
      optimizeLossy: s.optimizeLossy,
      fps: s.fps,
      loopCount: s.loopCount,
      boomerang: false,
      editsApplied: true,
    );
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
    state = AsyncData(VideoStudioState(overlayFontFile: FontResolver.resolve()));
  }
}

final videoStudioControllerProvider =
    AsyncNotifierProvider<VideoStudioController, VideoStudioState>(
  VideoStudioController.new,
);
