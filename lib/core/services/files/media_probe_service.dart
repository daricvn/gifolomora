import 'dart:io';
import '../ffmpeg/ffmpeg_backend.dart';
import '../ffmpeg/ffmpeg_progress.dart';

class MediaProbeService {
  MediaProbeService(this._backend);

  final FfmpegBackend _backend;

  Future<MediaInfo?> probe(File file) => _backend.probe(file.path);

  /// Returns image dimensions by reading file headers via the `image` package.
  /// Used as a fallback when ffprobe is unavailable.
  // ignore: unused_element
  Future<(int, int)?> _imageDims(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length < 8) return null;
      // PNG: 8-byte magic, then IHDR (width at offset 16, height at 20)
      if (bytes[0] == 0x89 && bytes[1] == 0x50) {
        if (bytes.length < 24) return null;
        final w = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
        final h = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
        return (w, h);
      }
      // JPEG: SOI + find SOFn marker for dimensions
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        int i = 2;
        while (i < bytes.length - 9) {
          if (bytes[i] != 0xFF) break;
          final marker = bytes[i + 1];
          final len = (bytes[i + 2] << 8) | bytes[i + 3];
          if (marker >= 0xC0 && marker <= 0xC3) {
            final h = (bytes[i + 5] << 8) | bytes[i + 6];
            final w = (bytes[i + 7] << 8) | bytes[i + 8];
            return (w, h);
          }
          i += 2 + len;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
