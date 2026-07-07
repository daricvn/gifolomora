// Integration test against a real gm_shim.dll. Not run by default: building
// the shim needs the MSYS2/clang toolchain (scripts/build_ffmpeg_shim.ps1),
// which isn't assumed to be present on every dev machine or in CI yet
// (Phase 3 formalizes that requirement). Point GM_SHIM_DLL_PATH at a built
// gm_shim.dll to exercise this locally; its companion FFmpeg DLLs
// (avcodec-*.dll etc) must be resolvable via the default Windows DLL search
// order -- e.g. by adding their directory to PATH before running the test.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_dll_backend.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_job_pool.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/utils/result.dart';
import 'package:path/path.dart' as p;

void main() {
  final dllPath = Platform.environment['GM_SHIM_DLL_PATH'];
  final shouldRun = Platform.isWindows && dllPath != null && File(dllPath).existsSync();

  group('FfmpegDllBackend (real gm_shim.dll)', () {
    test(
      'run() encodes a lavfi source and reports progress',
      () async {
        final backend = FfmpegDllBackend(dllPath: dllPath!, pool: FfmpegJobPool());
        final outPath = p.join(Directory.systemTemp.path, 'gm_dll_backend_test_out.avi');
        addTearDown(() {
          final f = File(outPath);
          if (f.existsSync()) f.deleteSync();
        });

        final progressCalls = <FfmpegProgress>[];
        final result = await backend.run(
          [
            '-y', '-f', 'lavfi', '-i', 'testsrc=duration=1:size=64x64:rate=10',
            '-c:v', 'mpeg4', '-progress', 'pipe:1', outPath,
          ],
          outPath,
          onProgress: progressCalls.add,
          totalFrames: 10,
        );

        expect(result, isA<Ok<File, FfmpegError>>());
        expect(File(outPath).existsSync(), isTrue);
        expect(progressCalls, isNotEmpty);
      },
      skip: shouldRun ? false : 'GM_SHIM_DLL_PATH not set to a built gm_shim.dll',
    );

    test(
      'run() surfaces a real error without throwing',
      () async {
        final backend = FfmpegDllBackend(dllPath: dllPath!);
        final result = await backend.run(
          ['-y', '-i', 'gm_dll_backend_test_missing_input.mp4', 'out.avi'],
          'out.avi',
        );
        expect(result, isA<Err<File, FfmpegError>>());
      },
      skip: shouldRun ? false : 'GM_SHIM_DLL_PATH not set to a built gm_shim.dll',
    );

    test(
      'probe() reads real media info',
      () async {
        final backend = FfmpegDllBackend(dllPath: dllPath!);
        final outPath = p.join(Directory.systemTemp.path, 'gm_dll_backend_test_probe.avi');
        addTearDown(() {
          final f = File(outPath);
          if (f.existsSync()) f.deleteSync();
        });
        await backend.run(
          ['-y', '-f', 'lavfi', '-i', 'testsrc=duration=2:size=320x240:rate=5', '-c:v', 'mpeg4', outPath],
          outPath,
        );

        final info = await backend.probe(outPath);
        expect(info, isNotNull);
        expect(info!.width, equals(320));
        expect(info.height, equals(240));
        expect(info.durationMs, greaterThan(0));
      },
      skip: shouldRun ? false : 'GM_SHIM_DLL_PATH not set to a built gm_shim.dll',
    );

    test(
      'supportsEncoder() reflects the build',
      () async {
        final backend = FfmpegDllBackend(dllPath: dllPath!);
        expect(await backend.supportsEncoder('mpeg4'), isTrue);
        expect(await backend.supportsEncoder('totally_bogus_codec'), isFalse);
      },
      skip: shouldRun ? false : 'GM_SHIM_DLL_PATH not set to a built gm_shim.dll',
    );

    test(
      'run() supports the drawtext filter '
      '(regression guard -- our FFmpeg build once lacked libfreetype, '
      'failing every text-overlay job with "No such filter: \'drawtext\'")',
      () async {
        final backend = FfmpegDllBackend(dllPath: dllPath!);
        final outPath = p.join(Directory.systemTemp.path, 'gm_dll_backend_test_drawtext.avi');
        addTearDown(() {
          final f = File(outPath);
          if (f.existsSync()) f.deleteSync();
        });

        const fontFile = r'C:/Windows/Fonts/arial.ttf';
        expect(File(fontFile).existsSync(), isTrue,
            reason: 'test relies on the standard Windows Arial font');
        // Colon after the drive letter must be escaped -- it's drawtext's
        // own option separator (same escaping FfmpegCommand._escapeFontPath
        // does for real font paths).
        const escapedFontFile = r'C\:/Windows/Fonts/arial.ttf';

        final result = await backend.run(
          [
            '-y', '-f', 'lavfi', '-i', 'testsrc=duration=1:size=64x64:rate=10',
            '-vf', "drawtext=fontfile='$escapedFontFile':text='Text':x=0:y=0",
            '-c:v', 'mpeg4', outPath,
          ],
          outPath,
        );

        expect(result, isA<Ok<File, FfmpegError>>());
        expect(File(outPath).existsSync(), isTrue);
      },
      skip: shouldRun ? false : 'GM_SHIM_DLL_PATH not set to a built gm_shim.dll',
    );

    test(
      'two concurrent run() calls do not corrupt each other',
      () async {
        final backend = FfmpegDllBackend(dllPath: dllPath!, pool: FfmpegJobPool(maxConcurrent: 2));
        final outA = p.join(Directory.systemTemp.path, 'gm_dll_backend_test_a.avi');
        final outB = p.join(Directory.systemTemp.path, 'gm_dll_backend_test_b.avi');
        addTearDown(() {
          for (final path in [outA, outB]) {
            final f = File(path);
            if (f.existsSync()) f.deleteSync();
          }
        });

        final results = await Future.wait([
          backend.run(
            ['-y', '-f', 'lavfi', '-i', 'testsrc=duration=1:size=64x64:rate=10', '-c:v', 'mpeg4', outA],
            outA,
          ),
          backend.run(
            ['-y', '-f', 'lavfi', '-i', 'testsrc=duration=1:size=64x64:rate=10', '-c:v', 'mpeg4', outB],
            outB,
          ),
        ]);

        expect(results[0], isA<Ok<File, FfmpegError>>());
        expect(results[1], isA<Ok<File, FfmpegError>>());
        expect(File(outA).existsSync(), isTrue);
        expect(File(outB).existsSync(), isTrue);
      },
      skip: shouldRun ? false : 'GM_SHIM_DLL_PATH not set to a built gm_shim.dll',
    );
  });
}
