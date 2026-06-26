import 'dart:io';
import 'package:path/path.dart' as p;
import '../files/temp_file_service.dart';
import '../../utils/logger.dart';
import '../../utils/result.dart';
import 'ffmpeg_backend.dart';
import 'ffmpeg_command.dart';
import 'ffmpeg_progress.dart';

class FfmpegService {
  FfmpegService(this._backend, this._temp, {this.gifsicleePath});

  static const _tag = 'FfmpegService';

  final FfmpegBackend _backend;
  final TempFileService _temp;
  final String? gifsicleePath;

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
      if (gifsicleePath != null) {
        final result = await Process.run(
          gifsicleePath!,
          ['-O3', '--lossy=$lossy', '--colors', '$colors', input.path, '-o', outputPath],
        );
        if (result.exitCode == 0) return Ok(File(outputPath));
        Log.e(_tag, 'gifsicle failed (${result.exitCode}), falling back to ffmpeg');
      }
      final args = FfmpegCommand.optimizeGifFfmpeg(
        inputPath: input.path,
        outputPath: outputPath,
        colors: colors,
      );
      return await _backend.run(args, outputPath, onProgress: onProgress, totalMs: totalMs);
    } catch (e) {
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

  Future<void> cancel() => _backend.cancel();

  void dispose() => _backend.dispose();
}
