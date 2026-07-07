// Real gm_shim.dll integration test for the recorder's gdigrab path -- this
// is the highest crash-risk workload PLAN.md flags (gdigrab + dshow driver
// interaction), so it gets a real-capture check, not just the
// FakeRecorderEngine unit tests in screen_recorder_service_test.dart.
// Gated the same way as ffmpeg_dll_backend_test.dart: point GM_SHIM_DLL_PATH
// at a built gm_shim.dll (with its companion DLLs on PATH) to run this
// locally; skipped by default.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_command.dart';
import 'package:gifolomora/core/services/record/screen_recorder_service.dart';
import 'package:path/path.dart' as p;

void main() {
  final dllPath = Platform.environment['GM_SHIM_DLL_PATH'];
  final shouldRun = Platform.isWindows && dllPath != null && File(dllPath).existsSync();

  test(
    'a real 2s gdigrab capture through gm_execute produces a playable segment',
    () async {
      final engine = GmShimRecorderEngine(dllPath!);
      final outPath = p.join(Directory.systemTemp.path, 'gm_recorder_real_test.mkv');
      addTearDown(() {
        final f = File(outPath);
        if (f.existsSync()) f.deleteSync();
      });

      final args = FfmpegCommand.screenCapture(
        outputPath: outPath,
        offsetX: 0,
        offsetY: 0,
        width: 320,
        height: 240,
        durationSeconds: 2,
      );

      final result = await engine.execute(90001, ['ffmpeg', ...args]);

      expect(result.rc, equals(0), reason: result.logs);
      expect(File(outPath).existsSync(), isTrue);
      expect(File(outPath).lengthSync(), greaterThan(0));
    },
    skip: shouldRun ? false : 'GM_SHIM_DLL_PATH not set to a built gm_shim.dll',
  );

  test(
    'gm_cancel() gracefully stops a live gdigrab capture before its -t deadline',
    () async {
      final engine = GmShimRecorderEngine(dllPath!);
      final outPath = p.join(Directory.systemTemp.path, 'gm_recorder_cancel_test.mkv');
      addTearDown(() {
        final f = File(outPath);
        if (f.existsSync()) f.deleteSync();
      });

      final args = FfmpegCommand.screenCapture(
        outputPath: outPath,
        offsetX: 0,
        offsetY: 0,
        width: 320,
        height: 240,
        durationSeconds: 30, // long -t; cancel() should stop it well before this
      );

      final sw = Stopwatch()..start();
      final future = engine.execute(90002, ['ffmpeg', ...args]);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      engine.cancel(90002);
      final result = await future.timeout(const Duration(seconds: 10));
      sw.stop();

      // fftools' own cancelRequested() path exits with 255 (see
      // fftools_ffmpeg.c's exit_program((received_nb_signals ||
      // cancelRequested(...)) ? 255 : ...)) -- a deliberate sentinel for
      // "stopped by cancel", distinct from a clean success (0), a crash
      // (gmCrashExitCode), or a real ffmpeg error.
      expect(result.rc, equals(255), reason: result.logs);
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)),
          reason: 'cancel() should stop capture well before the 30s -t deadline');
      expect(File(outPath).existsSync(), isTrue);
    },
    skip: shouldRun ? false : 'GM_SHIM_DLL_PATH not set to a built gm_shim.dll',
  );
}
