class FfmpegProgress {
  const FfmpegProgress({
    required this.fraction,
    this.framesDone,
    this.timeMs,
  });

  final double fraction; // 0.0–1.0
  final int? framesDone;
  final int? timeMs;

  /// Parses one `-progress` key=value line (`frame=`, `out_time_ms=`, …) --
  /// same format whether it arrives over the process backend's stdout pipe
  /// or tailed from a file (the DLL backend, which has no stdout of its own
  /// to pipe progress through).
  static void parseProgressLine(
    String line,
    int? totalFrames,
    int? totalMs,
    void Function(FfmpegProgress)? onProgress,
  ) {
    if (onProgress == null) return;
    if (line.startsWith('frame=')) {
      final frames = int.tryParse(line.substring('frame='.length).trim()) ?? 0;
      if (totalFrames == null || totalFrames <= 0) return;
      final fraction = (frames / totalFrames).clamp(0.0, 1.0);
      onProgress(FfmpegProgress(fraction: fraction, framesDone: frames));
    } else if (line.startsWith('out_time_ms=')) {
      final timeMs = int.tryParse(line.substring('out_time_ms='.length).trim()) ?? 0;
      // out_time_ms is in microseconds in some ffmpeg versions — divide by 1000
      final timeMillis = timeMs ~/ 1000;
      if (totalMs == null || totalMs <= 0) return;
      final fraction = (timeMillis / totalMs).clamp(0.0, 1.0);
      onProgress(FfmpegProgress(fraction: fraction, timeMs: timeMillis));
    }
  }
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
    this.hasAudio = false,
  });

  final int durationMs;
  final int width;
  final int height;
  final double? fps;
  final bool hasAudio;
}
