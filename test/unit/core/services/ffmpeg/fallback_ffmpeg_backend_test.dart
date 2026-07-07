import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/fallback_ffmpeg_backend.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_backend.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_dll_backend.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/utils/result.dart';

/// A backend whose behavior for run()/cancel() is fully scripted by the
/// test -- unlike the shared FakeFfmpegBackend, this one can hang forever
/// to exercise the watchdog path.
class _ScriptedBackend implements FfmpegBackend {
  Future<Result<File, FfmpegError>> Function()? onRun;
  int runCount = 0;
  int cancelCount = 0;
  final _hangCompleter = Completer<Result<File, FfmpegError>>();

  @override
  Future<Result<File, FfmpegError>> run(
    List<String> args,
    String outputPath, {
    void Function(FfmpegProgress)? onProgress,
    int? totalFrames,
    int? totalMs,
  }) async {
    runCount++;
    if (onRun != null) return onRun!();
    return _hangCompleter.future; // never completes unless test does so
  }

  int probeCount = 0;
  int supportsEncoderCount = 0;

  @override
  Future<MediaInfo?> probe(String inputPath) async {
    probeCount++;
    return null;
  }

  @override
  Future<bool> supportsEncoder(String encoderName) async {
    supportsEncoderCount++;
    return false;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  void dispose() {}
}

void main() {
  group('FallbackFfmpegBackend', () {
    test('delegates to primary when healthy', () async {
      final primary = _ScriptedBackend()
        ..onRun = () async => Ok(File('/primary/out.gif'));
      final fallback = _ScriptedBackend();
      final backend = FallbackFfmpegBackend(primary: primary, fallback: fallback);

      final result = await backend.run(['-y'], '/out.gif');

      expect(result, isA<Ok<File, FfmpegError>>());
      expect(primary.runCount, equals(1));
      expect(fallback.runCount, equals(0));
      expect(backend.isPoisoned, isFalse);
    });

    test('poisons on a crash exit code and routes subsequent jobs to fallback', () async {
      final primary = _ScriptedBackend()
        ..onRun = () async => const Err(FfmpegError(
              message: 'engine fault',
              exitCode: FfmpegDllBackend.crashExitCode,
            ));
      final fallback = _ScriptedBackend()
        ..onRun = () async => Ok(File('/fallback/out.gif'));
      final backend = FallbackFfmpegBackend(primary: primary, fallback: fallback);

      final firstResult = await backend.run(['-y'], '/out.gif');
      expect(firstResult, isA<Err<File, FfmpegError>>());
      expect(backend.isPoisoned, isTrue);
      expect(primary.runCount, equals(1));

      final secondResult = await backend.run(['-y'], '/out2.gif');
      expect(secondResult, isA<Ok<File, FfmpegError>>());
      expect(primary.runCount, equals(1)); // not called again
      expect(fallback.runCount, equals(1));
    });

    test('a non-crash error does not poison', () async {
      final primary = _ScriptedBackend()
        ..onRun = () async => const Err(FfmpegError(message: 'bad input', exitCode: 1));
      final fallback = _ScriptedBackend();
      final backend = FallbackFfmpegBackend(primary: primary, fallback: fallback);

      final result = await backend.run(['-y'], '/out.gif');
      expect(result, isA<Err<File, FfmpegError>>());
      expect(backend.isPoisoned, isFalse);

      await backend.run(['-y'], '/out2.gif');
      expect(primary.runCount, equals(2));
      expect(fallback.runCount, equals(0));
    });

    test('cancel() on a hung session poisons after the watchdog window and unblocks run()',
        () async {
      final primary = _ScriptedBackend(); // run() hangs forever (no onRun set)
      final fallback = _ScriptedBackend();
      final backend = FallbackFfmpegBackend(
        primary: primary,
        fallback: fallback,
        watchdogDuration: const Duration(milliseconds: 50),
      );

      final runFuture = backend.run(['-y'], '/out.gif');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await backend.cancel();

      final result = await runFuture; // must not hang forever
      expect(result, isA<Err<File, FfmpegError>>());
      expect(backend.isPoisoned, isTrue);
      expect(primary.cancelCount, equals(1));
    });

    test('cancel() with no in-flight run() is a no-op beyond delegating', () async {
      final primary = _ScriptedBackend();
      final fallback = _ScriptedBackend();
      final backend = FallbackFfmpegBackend(primary: primary, fallback: fallback);

      await backend.cancel();
      expect(primary.cancelCount, equals(1));
      expect(backend.isPoisoned, isFalse);
    });

    test('probe/supportsEncoder route to fallback once poisoned', () async {
      final primary = _ScriptedBackend()
        ..onRun = () async => const Err(FfmpegError(
              message: 'engine fault',
              exitCode: FfmpegDllBackend.crashExitCode,
            ));
      final fallback = _ScriptedBackend();
      final backend = FallbackFfmpegBackend(primary: primary, fallback: fallback);

      await backend.run(['-y'], '/out.gif'); // poisons
      expect(backend.isPoisoned, isTrue);

      await backend.probe('/some/file.mp4');
      await backend.supportsEncoder('libx264');

      expect(fallback.probeCount, equals(1));
      expect(fallback.supportsEncoderCount, equals(1));
      expect(primary.probeCount, equals(0));
      expect(primary.supportsEncoderCount, equals(0));
    });
  });
}
