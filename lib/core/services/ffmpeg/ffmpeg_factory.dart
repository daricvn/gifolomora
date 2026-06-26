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

  /// Returns gifsicle binary path if it exists next to the app executable.
  static String? resolveGifsicle() {
    if (!Platform.isWindows && !Platform.isLinux) return null;
    final path = FfmpegProcessBackend.resolveBin('gifsicle');
    return File(path).existsSync() ? path : null;
  }
}
