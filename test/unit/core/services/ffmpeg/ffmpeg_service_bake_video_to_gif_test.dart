// Integration test against a real gm_shim.dll, exercising the actual
// FfmpegService.bakeVideoToGif pipeline (palette pass -> palette.png ->
// render pass) instead of FakeFfmpegBackend. Regression guard for the
// build-config-gaps class of bug (ARCHITECTURE.md's Dual-backend FFmpeg
// section): a missing codec/filter in the FFmpeg build makes gm_execute
// return rc=1 with no exception, which FakeFfmpegBackend-based controller
// tests can never observe since they never call the real DLL.
//
// Not run by default -- point GM_SHIM_DLL_PATH at a built gm_shim.dll (see
// ffmpeg_dll_backend_test.dart) to exercise this locally/CI.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_dll_backend.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_job_pool.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_service.dart';
import 'package:gifolomora/core/services/files/temp_file_service.dart';
import 'package:gifolomora/core/utils/result.dart';
import 'package:path/path.dart' as p;

/// TempFileService backed by Directory.systemTemp instead of path_provider's
/// getTemporaryDirectory() -- that needs a platform channel flutter_test
/// doesn't provide, but real directories/files are still what
/// FfmpegService.bakeVideoToGif needs to actually write palette.png + the
/// rendered GIF to disk.
class _RealTempDirService extends TempFileService {
  final _jobDirs = <String>[];

  @override
  Future<String> createJobDir({String? baseDirOverride}) async {
    final dir = await Directory.systemTemp.createTemp('gifolomora_bake_test_');
    _jobDirs.add(dir.path);
    return dir.path;
  }

  @override
  Future<String> tempOutputPath(String jobDir, String ext) async =>
      p.join(jobDir, 'output.$ext');

  @override
  Future<void> cleanJob(String jobDir) async {
    final dir = Directory(jobDir);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> cleanupAll() async {
    for (final dir in _jobDirs) {
      final d = Directory(dir);
      if (await d.exists()) await d.delete(recursive: true);
    }
  }
}

void main() {
  final dllPath = Platform.environment['GM_SHIM_DLL_PATH'];
  final shouldRun =
      Platform.isWindows && dllPath != null && File(dllPath).existsSync();

  test(
    'bakeVideoToGif() encodes a real source through the palette pipeline',
    () async {
      final backend = FfmpegDllBackend(dllPath: dllPath!, pool: FfmpegJobPool());
      final temp = _RealTempDirService();
      final service = FfmpegService(backend, temp);

      final inputPath = p.join(
        Directory.systemTemp.path,
        'gm_bake_test_input.mp4',
      );
      addTearDown(() async {
        final f = File(inputPath);
        if (f.existsSync()) f.deleteSync();
        await temp.cleanupAll();
      });

      // Real source clip via the same DLL -- not a checked-in fixture, so
      // the test needs nothing beyond gm_shim.dll to run anywhere.
      final source = await backend.run(
        [
          '-y', '-f', 'lavfi', '-i',
          'testsrc=duration=1:size=64x64:rate=10',
          '-c:v', 'libx264', '-pix_fmt', 'yuv420p', inputPath,
        ],
        inputPath,
      );
      expect(source, isA<Ok<File, FfmpegError>>(),
          reason: 'setup: failed to generate real input clip');

      final result = await service.bakeVideoToGif(
        input: File(inputPath),
        scaleW: 32,
        fps: 5,
        durationMs: 500,
      );

      if (result.isErr) {
        fail('bakeVideoToGif failed: ${result.error.message}\n'
            'exitCode=${result.error.exitCode}\n${result.error.stderr}');
      }
      expect(File(result.value.path).existsSync(), isTrue);
      expect(File(result.value.path).lengthSync(), greaterThan(0));
    },
    skip: shouldRun ? false : 'GM_SHIM_DLL_PATH not set to a built gm_shim.dll',
  );
}
