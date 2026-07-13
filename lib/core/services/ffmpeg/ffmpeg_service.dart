import 'dart:io';
import 'package:path/path.dart' as p;
import '../files/temp_file_service.dart';
import '../gif_optimizer.dart';
import '../../utils/font_registry.dart';
import '../../utils/font_resolver.dart';
import '../../utils/logger.dart';
import '../../utils/result.dart';
import '../../../features/text_overlay/model/text_item.dart';
import 'ffmpeg_backend.dart';
import 'ffmpeg_command.dart';
import 'ffmpeg_progress.dart';
import 'video_encoder.dart';

class FfmpegService {
  FfmpegService(this._backend, this._temp);

  static const _tag = 'FfmpegService';

  final FfmpegBackend _backend;
  final TempFileService _temp;

  String? _currentJobDir;

  Future<Result<File, FfmpegError>> imagesToGif({
    required List<File> frames,
    int fps = 15,
    int? width,
    void Function(FfmpegProgress)? onProgress,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final copied = await _temp.copyFrames(frames, jobDir);
      final concatPath = p.join(jobDir, 'concat.txt');
      final concatContent = FfmpegCommand.buildConcatFileContent(copied, fps);
      await File(concatPath).writeAsString(concatContent);

      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      final args = FfmpegCommand.imagesToGif(
        concatFilePath: concatPath,
        outputPath: outputPath,
        width: width,
      );

      return await _backend.run(
        args,
        outputPath,
        onProgress: onProgress,
        totalFrames: frames.length,
      );
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
    // jobDir NOT cleaned on success — output.gif lives there until export copies it.
    // Caller must invoke cleanCurrentJob() after export or cancel.
  }

  /// Deletes the temp job directory from the last imagesToGif / videoToGif call.
  Future<void> cleanCurrentJob() async {
    final dir = _currentJobDir;
    _currentJobDir = null;
    if (dir != null) await _temp.cleanJob(dir);
  }

  Future<Result<File, FfmpegError>> videoToGif({
    required File input,
    Duration? start,
    Duration? duration,
    int fps = 15,
    int? width,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      final args = FfmpegCommand.videoToGif(
        inputPath: input.path,
        outputPath: outputPath,
        fps: fps,
        width: width,
        start: start,
        duration: duration,
      );
      return await _backend.run(
        args,
        outputPath,
        onProgress: onProgress,
        totalMs: totalMs,
      );
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  Future<MediaInfo?> probe(File file) => _backend.probe(file.path);

  bool? _supportsAv1;

  /// One-time cached probe: does this platform's ffmpeg build carry
  /// libaom-av1? Upstream ffmpeg-kit Android builds never bundled it (dav1d
  /// is decode-only), so the AV1 chip stays hidden there.
  Future<bool> supportsAv1() async =>
      _supportsAv1 ??= await _backend.supportsEncoder('libaom-av1');

  Future<Result<File, FfmpegError>> resizeGif({
    required File input,
    int? width,
    int? height,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      final args = FfmpegCommand.resize(
        inputPath: input.path,
        outputPath: outputPath,
        width: width,
        height: height,
      );
      return await _backend.run(args, outputPath, onProgress: onProgress, totalMs: totalMs);
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  Future<Result<File, FfmpegError>> cropGif({
    required File input,
    required int x,
    required int y,
    required int cropWidth,
    required int cropHeight,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      final args = FfmpegCommand.cropGif(
        inputPath: input.path,
        outputPath: outputPath,
        x: x,
        y: y,
        cropWidth: cropWidth,
        cropHeight: cropHeight,
      );
      return await _backend.run(args, outputPath, onProgress: onProgress, totalMs: totalMs);
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  Future<Result<File, FfmpegError>> optimizeGif({
    required File input,
    int colors = 128,
    int lossy = 40,
    int? loopCount,
    int frameDrop = 0,
    bool localPalettes = false,
    void Function(FfmpegProgress)? onProgress,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      await GifOptimizer.optimize(
        input,
        File(outputPath),
        colors: colors,
        lossy: lossy,
        loopCount: loopCount,
        frameDrop: frameDrop,
        localPalettes: localPalettes,
        onProgress: onProgress == null
            ? null
            : (f) => onProgress(FfmpegProgress(fraction: f)),
      );
      return Ok(File(outputPath));
    } catch (e) {
      Log.e(_tag, 'GifOptimizer failed: $e');
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  Future<Result<File, FfmpegError>> textOverlay({
    required File input,
    required String text,
    required String fontFile,
    int fontSize = 36,
    String fontColor = 'white',
    String position = 'center',
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      final args = FfmpegCommand.textOverlay(
        inputPath: input.path,
        outputPath: outputPath,
        text: text,
        fontFile: fontFile,
        fontSize: fontSize,
        fontColor: fontColor,
        position: position,
      );
      return await _backend.run(args, outputPath, onProgress: onProgress, totalMs: totalMs);
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  /// Maps text layers to ffmpeg draw specs: normalized positions → source px
  /// (against [mediaInfo] dims), font resolved per style. Shared by the GIF
  /// [textOverlayMulti] bake and the video [editVideo] bake.
  static List<DrawTextSpec> _specsFromItems(
      List<TextItem> items, MediaInfo mediaInfo) {
    final mw = mediaInfo.width.toDouble();
    final mh = mediaInfo.height.toDouble();
    return items
        .map((item) => DrawTextSpec(
              text: item.text.trim(),
              fontFile: FontRegistry.pathFor(item.font, item.style) ??
                  FontResolver.fileForStyle(item.style) ??
                  '',
              x: TextItem.pxX(item.nx, mw),
              y: TextItem.pxY(item.ny, mh),
              fontSize: item.fontSize,
              fontColorHex: item.fontColor,
              strokeColorHex: item.strokeColor,
              strokeWidth: item.strokeWidth,
            ))
        .toList();
  }

  Future<Result<File, FfmpegError>> textOverlayMulti({
    required File input,
    required List<TextItem> items,
    required MediaInfo mediaInfo,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      final specs = _specsFromItems(items, mediaInfo);
      final args = FfmpegCommand.textOverlayMulti(
        inputPath: input.path,
        outputPath: outputPath,
        specs: specs,
      );
      return await _backend.run(args, outputPath,
          onProgress: onProgress, totalMs: totalMs);
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  Future<Result<File, FfmpegError>> reverseGif({
    required File input,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      final args = FfmpegCommand.reverseGif(
        inputPath: input.path,
        outputPath: outputPath,
      );
      return await _backend.run(args, outputPath, onProgress: onProgress, totalMs: totalMs);
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  Future<Result<File, FfmpegError>> changeSpeed({
    required File input,
    required double factor,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      final args = FfmpegCommand.changeSpeed(
        inputPath: input.path,
        outputPath: outputPath,
        factor: factor,
      );
      return await _backend.run(args, outputPath, onProgress: onProgress, totalMs: totalMs);
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  Future<Result<File, FfmpegError>> editVideo({
    required File input,
    int? cropX,
    int? cropY,
    int? cropW,
    int? cropH,
    int? scaleW,
    int? scaleH,
    double speedFactor = 1.0,
    bool hasAudio = false,
    double volume = 1.0,
    List<String>? encoderCandidates,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
    int? startMs,
    int? durationMs,
    List<TextItem>? overlayItems,
    MediaInfo? mediaInfo,
    List<CutSegment>? keepRanges,
    int? keepRangesOutputMs,
    bool smoothLoop = false,
    int crossfadeMs = 1000,
    int? loopDurationMs,
    // WebM export (§8 of PLAN.md). WebM only admits VP8/VP9/AV1, so an h264
    // source can never stream-copy — the no-op fast path is skipped entirely
    // and every WebM export runs a real (single-candidate, VP9) encode.
    bool webm = false,
    int webmCrf = 32,
    int webmCpuUsed = 4,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;

    final items =
        overlayItems?.where((i) => i.text.trim().isNotEmpty).toList() ??
            const <TextItem>[];
    final hasText = items.isNotEmpty && mediaInfo != null;
    final textSpecs = hasText ? _specsFromItems(items, mediaInfo) : null;
    final hasTrim = (startMs != null && startMs > 0) || (durationMs != null && durationMs > 0);
    final volumeChanged = hasAudio && (volume - 1.0).abs() >= 0.01;
    final hasCutRanges = keepRanges != null && keepRanges.length >= 2;
    final isNoOp = !webm &&
        cropX == null &&
        scaleW == null &&
        (speedFactor - 1.0).abs() < 0.001 &&
        !hasText &&
        !hasTrim &&
        !volumeChanged &&
        !hasCutRanges &&
        !smoothLoop;

    try {
      final outputPath = await _temp.tempOutputPath(jobDir, webm ? 'webm' : 'mp4');

      if (isNoOp) {
        final args = FfmpegCommand.videoStreamCopy(
          inputPath: input.path,
          outputPath: outputPath,
        );
        return await _backend.run(args, outputPath,
            onProgress: onProgress, totalMs: totalMs);
      }

      var effectiveTotalMs = keepRangesOutputMs ??
          (durationMs != null && durationMs > 0
              ? durationMs
              : (totalMs != null && (speedFactor - 1.0).abs() > 0.001
                  ? (totalMs / speedFactor).round()
                  : totalMs));
      if (smoothLoop && effectiveTotalMs != null) {
        effectiveTotalMs =
            (effectiveTotalMs - crossfadeMs).clamp(1, effectiveTotalMs);
      }

      if (webm) {
        final args = FfmpegCommand.videoEdit(
          inputPath: input.path,
          outputPath: outputPath,
          cropX: cropX,
          cropY: cropY,
          cropW: cropW,
          cropH: cropH,
          scaleW: scaleW,
          scaleH: scaleH,
          speedFactor: speedFactor,
          hasAudio: hasAudio,
          volume: volume,
          startMs: startMs,
          durationMs: durationMs,
          textSpecs: textSpecs,
          keepRanges: keepRanges,
          smoothLoop: smoothLoop,
          crossfadeMs: crossfadeMs,
          loopDurationMs: loopDurationMs,
          webm: true,
          webmCrf: webmCrf,
          webmCpuUsed: webmCpuUsed,
          webmThreads: Platform.numberOfProcessors,
        );
        return await _backend.run(args, outputPath,
            onProgress: onProgress, totalMs: effectiveTotalMs);
      }

      final candidates =
          encoderCandidates ?? VideoEncoder.platformCandidates();

      for (int i = 0; i < candidates.length; i++) {
        final encoder = candidates[i];
        final args = FfmpegCommand.videoEdit(
          inputPath: input.path,
          outputPath: outputPath,
          cropX: cropX,
          cropY: cropY,
          cropW: cropW,
          cropH: cropH,
          scaleW: scaleW,
          scaleH: scaleH,
          speedFactor: speedFactor,
          encoder: encoder,
          hasAudio: hasAudio,
          volume: volume,
          startMs: startMs,
          durationMs: durationMs,
          textSpecs: textSpecs,
          keepRanges: keepRanges,
          smoothLoop: smoothLoop,
          crossfadeMs: crossfadeMs,
          loopDurationMs: loopDurationMs,
        );
        final result = await _backend.run(
          args,
          outputPath,
          onProgress: onProgress,
          totalMs: effectiveTotalMs,
        );
        if (result.isOk || i == candidates.length - 1) return result;
        Log.d(_tag, 'Encoder $encoder failed, trying next candidate');
      }

      return Err(const FfmpegError(message: 'All encoders failed'));
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  /// Bakes the current video edits (crop · resize · speed · trim · cut) into a GIF.
  /// The job dir is kept (output gif is the new editing source); the caller
  /// owns its cleanup via [cleanJobAt].
  Future<Result<File, FfmpegError>> bakeVideoToGif({
    required File input,
    int? cropX,
    int? cropY,
    int? cropW,
    int? cropH,
    int? scaleW,
    double speedFactor = 1.0,
    int fps = 15,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
    int? startMs,
    int? durationMs,
    List<CutSegment>? keepRanges,
    int? keepRangesOutputMs,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      final palettePath = p.join(jobDir, 'palette.png');
      final cmds = FfmpegCommand.videoEditToGif(
        inputPath: input.path,
        outputPath: outputPath,
        palettePath: palettePath,
        cropX: cropX,
        cropY: cropY,
        cropW: cropW,
        cropH: cropH,
        scaleW: scaleW,
        speedFactor: speedFactor,
        fps: fps,
        startMs: startMs,
        durationMs: durationMs,
        keepRanges: keepRanges,
      );
      // Two passes: palette first (no progress — palettegen emits one frame at
      // EOF, so ffmpeg's progress stream is meaningless), then the render pass
      // drives the progress bar.
      final palette = await _backend.run(cmds.palettePass, palettePath);
      if (palette.isErr) return Err(palette.error);
      final effectiveTotalMs = keepRangesOutputMs ??
          (durationMs != null && durationMs > 0
              ? durationMs
              : (totalMs != null && (speedFactor - 1.0).abs() > 0.001
                  ? (totalMs / speedFactor).round()
                  : totalMs));
      return await _backend.run(cmds.renderPass, outputPath,
          onProgress: onProgress, totalMs: effectiveTotalMs);
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  /// Applies crop · resize · speed · text to an existing GIF in one pass.
  Future<Result<File, FfmpegError>> editGif({
    required File input,
    int? cropX,
    int? cropY,
    int? cropW,
    int? cropH,
    int? scaleW,
    double speedFactor = 1.0,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
    int? startMs,
    int? durationMs,
    String? overlayText,
    String? overlayFontFile,
    int overlayFontSize = 36,
    String overlayFontColor = 'white',
    String overlayPosition = 'center',
    int? fps,
    int loopCount = 0,
    bool boomerang = false,
    bool smoothLoop = false,
    int crossfadeMs = 1000,
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      final args = FfmpegCommand.gifEdit(
        inputPath: input.path,
        outputPath: outputPath,
        cropX: cropX,
        cropY: cropY,
        cropW: cropW,
        cropH: cropH,
        scaleW: scaleW,
        speedFactor: speedFactor,
        startMs: startMs,
        durationMs: durationMs,
        drawText: overlayText,
        drawTextFont: overlayFontFile,
        drawTextSize: overlayFontSize,
        drawTextColor: overlayFontColor,
        drawTextPosition: overlayPosition,
        fps: fps,
        loopCount: loopCount,
        boomerang: boomerang,
        smoothLoop: smoothLoop,
        crossfadeMs: crossfadeMs,
      );
      final baseMs = durationMs != null && durationMs > 0 ? durationMs : totalMs;
      var effectiveTotalMs =
          baseMs != null && (speedFactor - 1.0).abs() > 0.001
              ? (baseMs / speedFactor).round()
              : baseMs;
      if (smoothLoop && effectiveTotalMs != null) {
        effectiveTotalMs =
            (effectiveTotalMs - crossfadeMs).clamp(1, effectiveTotalMs);
      }
      return await _backend.run(args, outputPath,
          onProgress: onProgress, totalMs: effectiveTotalMs);
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  /// Converts video or GIF to WebM. Each call gets its own job dir — does
  /// NOT touch [_currentJobDir]: a batch run owns several outputs live at
  /// once (the single-slot cleanCurrentJob model doesn't fit), so the caller
  /// tracks and frees each output's dir itself via [cleanJobAt].
  Future<Result<File, FfmpegError>> convertToWebm({
    required File input,
    required int crf,
    required int cpuUsed,
    bool av1 = false,
    int? maxWidth,
    bool keepAudio = false,
    bool alpha = false,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    final jobDir = await _temp.createJobDir();
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'webm');
      final args = FfmpegCommand.toWebm(
        inputPath: input.path,
        outputPath: outputPath,
        crf: crf,
        cpuUsed: cpuUsed,
        av1: av1,
        maxWidth: maxWidth,
        keepAudio: keepAudio,
        alpha: alpha,
        threads: Platform.numberOfProcessors,
      );
      return await _backend.run(args, outputPath,
          onProgress: onProgress, totalMs: totalMs);
    } catch (e) {
      await _temp.cleanJob(jobDir);
      return Err(FfmpegError(message: e.toString()));
    }
  }

  /// Deletes an arbitrary job dir (used to free a baked-GIF source). Clears
  /// [_currentJobDir] too when it points at the same dir, else a later
  /// cleanCurrentJob() re-deletes an already-gone directory.
  Future<void> cleanJobAt(String jobDir) {
    if (jobDir == _currentJobDir) _currentJobDir = null;
    return _temp.cleanJob(jobDir);
  }

  Future<void> cancel() => _backend.cancel();

  void dispose() => _backend.dispose();
}
