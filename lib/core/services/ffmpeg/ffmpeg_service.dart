import 'dart:io';
import 'package:path/path.dart' as p;
import '../files/temp_file_service.dart';
import '../gif_optimizer.dart';
import '../../utils/logger.dart';
import '../../utils/result.dart';
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
      return Err(FfmpegError(message: e.toString()));
    }
  }

  Future<MediaInfo?> probe(File file) => _backend.probe(file.path);

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
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
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
    List<String>? encoderCandidates,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
    int? startMs,
    int? durationMs,
    String? overlayText,
    String? overlayFontFile,
    int overlayFontSize = 36,
    String overlayFontColor = 'white',
    String overlayPosition = 'center',
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;

    final hasText = overlayText != null && overlayText.isNotEmpty && overlayFontFile != null;
    final hasTrim = (startMs != null && startMs > 0) || (durationMs != null && durationMs > 0);
    final isNoOp = cropX == null &&
        scaleW == null &&
        (speedFactor - 1.0).abs() < 0.001 &&
        !hasText &&
        !hasTrim;

    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'mp4');

      if (isNoOp) {
        final args = FfmpegCommand.videoStreamCopy(
          inputPath: input.path,
          outputPath: outputPath,
        );
        return await _backend.run(args, outputPath,
            onProgress: onProgress, totalMs: totalMs);
      }

      final candidates =
          encoderCandidates ?? VideoEncoder.platformCandidates();

      final effectiveTotalMs = durationMs != null && durationMs > 0
          ? durationMs
          : (totalMs != null && (speedFactor - 1.0).abs() > 0.001
              ? (totalMs / speedFactor).round()
              : totalMs);

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
          startMs: startMs,
          durationMs: durationMs,
          drawText: overlayText,
          drawTextFont: overlayFontFile,
          drawTextSize: overlayFontSize,
          drawTextColor: overlayFontColor,
          drawTextPosition: overlayPosition,
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

  /// Bakes the current video edits (crop · resize · speed · trim) into a GIF.
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
  }) async {
    final jobDir = await _temp.createJobDir();
    _currentJobDir = jobDir;
    try {
      final outputPath = await _temp.tempOutputPath(jobDir, 'gif');
      final args = FfmpegCommand.videoEditToGif(
        inputPath: input.path,
        outputPath: outputPath,
        cropX: cropX,
        cropY: cropY,
        cropW: cropW,
        cropH: cropH,
        scaleW: scaleW,
        speedFactor: speedFactor,
        fps: fps,
        startMs: startMs,
        durationMs: durationMs,
      );
      final effectiveTotalMs = durationMs != null && durationMs > 0
          ? durationMs
          : (totalMs != null && (speedFactor - 1.0).abs() > 0.001
              ? (totalMs / speedFactor).round()
              : totalMs);
      return await _backend.run(args, outputPath,
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
    String? overlayText,
    String? overlayFontFile,
    int overlayFontSize = 36,
    String overlayFontColor = 'white',
    String overlayPosition = 'center',
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
        drawText: overlayText,
        drawTextFont: overlayFontFile,
        drawTextSize: overlayFontSize,
        drawTextColor: overlayFontColor,
        drawTextPosition: overlayPosition,
      );
      final effectiveTotalMs =
          totalMs != null && (speedFactor - 1.0).abs() > 0.001
              ? (totalMs / speedFactor).round()
              : totalMs;
      return await _backend.run(args, outputPath,
          onProgress: onProgress, totalMs: effectiveTotalMs);
    } catch (e) {
      await _temp.cleanJob(jobDir);
      _currentJobDir = null;
      return Err(FfmpegError(message: e.toString()));
    }
  }

  /// Deletes an arbitrary job dir (used to free a baked-GIF source).
  Future<void> cleanJobAt(String jobDir) => _temp.cleanJob(jobDir);

  Future<void> cancel() => _backend.cancel();

  void dispose() => _backend.dispose();
}
