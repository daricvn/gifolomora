// The poison switch from PLAN.md §3: delegates to `primary` (the DLL
// backend) until it reports a fault, then permanently -- for the rest of
// this app session -- delegates to `fallback` (the exe backend), logging
// loudly. A missing DLL never reaches here at all (FfmpegFactory only wraps
// FfmpegDllBackend when it loaded successfully); this only handles faults
// that happen *during* use: a caught native crash, or a session that never
// returns after cancel() (the one capability genuinely traded away versus
// Process.kill()).
import 'dart:async';
import 'dart:io';

import '../../utils/logger.dart';
import '../../utils/result.dart';
import 'ffmpeg_backend.dart';
import 'ffmpeg_dll_backend.dart';
import 'ffmpeg_progress.dart';

class FallbackFfmpegBackend implements FfmpegBackend {
  FallbackFfmpegBackend({
    required this.primary,
    required this.fallback,
    this.watchdogDuration = const Duration(seconds: 10),
  });

  final FfmpegBackend primary;
  final FfmpegBackend fallback;
  final Duration watchdogDuration;

  static const _tag = 'FallbackFfmpegBackend';

  bool _poisoned = false;
  bool get isPoisoned => _poisoned;

  // Concurrent run()s are reachable (shared singleton behind the job pool,
  // cap 2), so track every pending run's watchdog signal, not just the last.
  final Set<Completer<Result<File, FfmpegError>>> _watchdogSignals =
      <Completer<Result<File, FfmpegError>>>{};

  void _poison(String reason) {
    if (_poisoned) return;
    _poisoned = true;
    Log.e(_tag,
        'poisoned ($reason) -- every job for the rest of this app session now runs via the exe fallback');
  }

  @override
  Future<Result<File, FfmpegError>> run(
    List<String> args,
    String outputPath, {
    void Function(FfmpegProgress)? onProgress,
    int? totalFrames,
    int? totalMs,
  }) async {
    if (_poisoned) {
      return fallback.run(args, outputPath,
          onProgress: onProgress, totalFrames: totalFrames, totalMs: totalMs);
    }

    final watchdog = Completer<Result<File, FfmpegError>>();
    _watchdogSignals.add(watchdog);
    try {
      final primaryFuture = primary.run(args, outputPath,
          onProgress: onProgress, totalFrames: totalFrames, totalMs: totalMs);
      final result = await Future.any([primaryFuture, watchdog.future]);
      // ponytail: primaryFuture winning the race must retire watchdog too --
      // otherwise cancel()'s pending Future.delayed still fires later, finds
      // watchdog un-completed, and poisons a backend that never actually hung.
      if (!watchdog.isCompleted) watchdog.complete(result);

      if (result is Err<File, FfmpegError> &&
          result.error.exitCode == FfmpegDllBackend.crashExitCode) {
        _poison('native crash caught by the DLL backend\'s guard: ${result.error.message}');
      }
      return result;
    } finally {
      _watchdogSignals.remove(watchdog);
    }
  }

  @override
  Future<void> cancel() async {
    if (_poisoned) {
      return fallback.cancel();
    }

    await primary.cancel();

    // A truly hung native call can't be killed (TerminateThread would
    // corrupt the heap). Give it watchdogDuration to honor the cancel; if
    // it doesn't, leak that isolate/thread, poison, and unblock the
    // caller's run() with a cancellation result instead of hanging forever.
    // Snapshot: run()s may finish (and remove themselves) meanwhile.
    for (final signal in List.of(_watchdogSignals)) {
      if (signal.isCompleted) continue;
      unawaited(Future.delayed(watchdogDuration, () {
        if (signal.isCompleted) return;
        _poison('session did not stop within ${watchdogDuration.inSeconds}s of cancel()');
        signal.complete(const Err(FfmpegError(message: 'Cancelled (watchdog fallback)')));
      }));
    }
  }

  // probe/supportsEncoder always go through `primary` (gm_shim), even once
  // poisoned: no ffprobe.exe/ffmpeg.exe is bundled anymore (setup_windows_dev.ps1),
  // so `fallback` can't serve these calls -- they'd always fail with "system
  // cannot find the file specified". A crash caught during run() doesn't
  // corrupt gm_probe/gm_supports_encoder, so this stays safe post-poison.
  @override
  Future<MediaInfo?> probe(String inputPath) => primary.probe(inputPath);

  @override
  Future<bool> supportsEncoder(String encoderName) =>
      primary.supportsEncoder(encoderName);

  @override
  void dispose() {
    primary.dispose();
    fallback.dispose();
  }
}
