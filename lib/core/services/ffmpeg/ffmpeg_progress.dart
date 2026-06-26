class FfmpegProgress {
  const FfmpegProgress({
    required this.fraction,
    this.framesDone,
    this.timeMs,
  });

  final double fraction; // 0.0–1.0
  final int? framesDone;
  final int? timeMs;
}

class FfmpegError {
  const FfmpegError({required this.message, this.exitCode, this.stderr});

  final String message;
  final int? exitCode;
  final String? stderr;

  @override
  String toString() => 'FfmpegError(exit=$exitCode): $message';
}

class MediaInfo {
  const MediaInfo({
    required this.durationMs,
    required this.width,
    required this.height,
    this.fps,
  });

  final int durationMs;
  final int width;
  final int height;
  final double? fps;
}
