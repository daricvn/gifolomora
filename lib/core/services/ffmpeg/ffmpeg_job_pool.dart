import 'dart:async';
import 'dart:collection';

/// Caps how many `gm_execute` sessions run concurrently. FFmpeg is
/// internally multithreaded, so more parallel encodes mostly fight over
/// cores/RAM rather than help -- default 2 (PLAN.md §4).
class FfmpegJobPool {
  FfmpegJobPool({this.maxConcurrent = 2});

  final int maxConcurrent;

  int _running = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  Future<T> run<T>(Future<T> Function() job) async {
    // Re-check after every wake: a new caller can slip in during the
    // waiter's microtask gap and take the freed slot first.
    while (_running >= maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _running++;
    try {
      return await job();
    } finally {
      _running--;
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      }
    }
  }
}
