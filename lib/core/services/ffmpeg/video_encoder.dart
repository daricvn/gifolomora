import 'dart:io';

abstract final class VideoEncoder {
  static List<String> platformCandidates() {
    if (Platform.isAndroid || Platform.isIOS) {
      return ['h264_mediacodec', 'libx264'];
    }
    return ['h264_nvenc', 'h264_qsv', 'h264_amf', 'libx264'];
  }
}
