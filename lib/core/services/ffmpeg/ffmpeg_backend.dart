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

  /// One-shot check: does this ffmpeg build list [encoderName] under
  /// `-encoders`? Used to gate the AV1 codec chip (libaom-av1 is absent from
  /// upstream ffmpeg-kit Android builds).
  Future<bool> supportsEncoder(String encoderName);

  Future<void> cancel();
  void dispose();
}
