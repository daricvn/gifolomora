import 'dart:io';
import 'ffmpeg_backend.dart';
import 'ffmpeg_kit_backend.dart';
import 'ffmpeg_process_backend.dart';

abstract final class FfmpegFactory {
  static FfmpegBackend create() {
    if (Platform.isAndroid || Platform.isIOS) {
      return FfmpegKitBackend();
    }
    return FfmpegProcessBackend(
      ffmpegPath: FfmpegProcessBackend.resolveBin('ffmpeg'),
      ffprobePath: FfmpegProcessBackend.resolveBin('ffprobe'),
    );
  }
}
