import 'dart:io';
import 'ffmpeg_progress.dart';
import '../../utils/result.dart';

abstract interface class FfmpegBackend {
  Future<Result<File, FfmpegError>> run(
    List<String> args,
    String outputPath, {
    void Function(FfmpegProgress)? onProgress,
    int? totalFrames,
    int? totalMs,
  });

  Future<MediaInfo?> probe(String inputPath);
  Future<void> cancel();
  void dispose();
}
