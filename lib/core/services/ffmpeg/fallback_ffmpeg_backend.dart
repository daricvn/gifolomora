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

  Completer<Result<File, FfmpegError>>? _watchdogSignal;

  FfmpegBackend get _active => _poisoned ? fallback : primary;

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
    _watchdogSignal = watchdog;
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
      _watchdogSignal = null;
    }
  }

  @override
  Future<void> cancel() async {
    if (_poisoned) {
      return fallback.cancel();
    }

    await primary.cancel();

    final signal = _watchdogSignal;
    if (signal == null || signal.isCompleted) return;

    // A truly hung native call can't be killed (TerminateThread would
    // corrupt the heap). Give it watchdogDuration to honor the cancel; if
    // it doesn't, leak that isolate/thread, poison, and unblock the
    // caller's run() with a cancellation result instead of hanging forever.
    unawaited(Future.delayed(watchdogDuration, () {
      if (signal.isCompleted) return;
      _poison('session did not stop within ${watchdogDuration.inSeconds}s of cancel()');
      signal.complete(const Err(FfmpegError(message: 'Cancelled (watchdog fallback)')));
    }));
  }

  @override
  Future<MediaInfo?> probe(String inputPath) => _active.probe(inputPath);

  @override
  Future<bool> supportsEncoder(String encoderName) => _active.supportsEncoder(encoderName);

  @override
  void dispose() {
    primary.dispose();
    fallback.dispose();
  }
}
