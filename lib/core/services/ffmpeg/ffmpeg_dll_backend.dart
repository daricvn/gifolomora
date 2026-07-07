// Windows in-process backend: loads gm_shim.dll (windows/ffmpeg_shim/, built
// by scripts/build_ffmpeg_shim.ps1) via dart:ffi instead of spawning
// ffmpeg.exe. See PLAN.md for the full design; this implements Phase 1
// (backend) behind the same FfmpegBackend interface FfmpegProcessBackend
// implements, so callers need no changes.
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../utils/logger.dart';
import '../../utils/result.dart';
import 'ffmpeg_backend.dart';
import 'ffmpeg_job_pool.dart';
import 'ffmpeg_progress.dart';
import 'gm_shim_ffi.dart';

class FfmpegDllBackend implements FfmpegBackend {
  FfmpegDllBackend({required this.dllPath, FfmpegJobPool? pool})
      : _pool = pool ?? FfmpegJobPool(),
        _shim = GmShim(dllPath);

  final String dllPath;
  final FfmpegJobPool _pool;
  final GmShim _shim;

  static const _tag = 'FfmpegDllBackend';

  /// FallbackFfmpegBackend checks FfmpegError.exitCode against this to
  /// trigger the poison switch (§3).
  static const int crashExitCode = gmCrashExitCode;

  final Set<int> _activeSessions = {};
  // ponytail: gm_cancel() on a session that hasn't reached gm_execute yet
  // (still queued behind FfmpegJobPool's cap) is a no-op on the native side --
  // it registers with cancelled=0 when its turn comes, ignoring the earlier
  // cancel. This set catches that case in Dart instead.
  final Set<int> _cancelledBeforeStart = {};

  /// Resolves gm_shim.dll next to Platform.resolvedExecutable, same
  /// convention as FfmpegProcessBackend.resolveBin. Returns null (caller
  /// falls back to the exe backend) if the DLL or its DynamicLibrary.open
  /// isn't usable -- e.g. missing, or one of the FFmpeg DLLs beside it is
  /// missing.
  static String? tryResolvePath() {
    final dir = File(Platform.resolvedExecutable).parent;
    final path = p.join(dir.path, 'gm_shim.dll');
    if (!File(path).existsSync()) return null;
    try {
      DynamicLibrary.open(path).close();
      return path;
    } catch (e) {
      Log.e(_tag, 'gm_shim.dll present but failed to load', e);
      return null;
    }
  }

  @override
  Future<Result<File, FfmpegError>> run(
    List<String> args,
    String outputPath, {
    void Function(FfmpegProgress)? onProgress,
    int? totalFrames,
    int? totalMs,
  }) async {
    final sessionId = GmSessionIds.allocate();
    _activeSessions.add(sessionId);

    final progressFile = File(p.join(
      Directory.systemTemp.path,
      'gifolomora_progress_$sessionId.txt',
    ));
    final rewrittenArgs = _rewriteProgressArg(args, progressFile.path);
    final argv = ['ffmpeg', ...rewrittenArgs];

    Log.d(_tag, 'run(session=$sessionId): ${rewrittenArgs.join(' ')}');

    Timer? tailTimer;
    var lastOffset = 0;
    var pendingLine = '';
    void tailOnce() {
      if (!progressFile.existsSync()) return;
      final raf = progressFile.openSync();
      try {
        final length = raf.lengthSync();
        if (length <= lastOffset) return;
        raf.setPositionSync(lastOffset);
        final chunk = String.fromCharCodes(raf.readSync(length - lastOffset));
        lastOffset = length;
        pendingLine += chunk;
        final lines = pendingLine.split('\n');
        pendingLine = lines.removeLast(); // may be incomplete
        for (final line in lines) {
          FfmpegProgress.parseProgressLine(line.trim(), totalFrames, totalMs, onProgress);
        }
      } finally {
        raf.closeSync();
      }
    }

    if (onProgress != null) {
      tailTimer = Timer.periodic(const Duration(milliseconds: 150), (_) => tailOnce());
    }

    try {
      final result = await _pool.run(() {
        if (_cancelledBeforeStart.remove(sessionId)) {
          return Future.value(const GmExecResult(gmCancelledExitCode, ''));
        }
        return _shim.execute(sessionId, argv);
      });

      tailTimer?.cancel();
      tailOnce(); // final catch-up pass

      if (result.rc == 0) {
        return Ok(File(outputPath));
      }

      if (result.rc == crashExitCode) {
        Log.e(_tag, 'session $sessionId: native crash caught, engine faulted\n${result.logs}');
        return Err(FfmpegError(
          message: 'FFmpeg engine fault (recovered)',
          exitCode: result.rc,
          stderr: result.logs,
        ));
      }

      if (result.rc == gmCancelledExitCode) {
        return const Err(FfmpegError(message: 'Cancelled'));
      }

      Log.e(_tag, 'session $sessionId failed (rc=${result.rc})\n${result.logs}');
      return Err(FfmpegError(
        message: 'FFmpeg exited with code ${result.rc}',
        exitCode: result.rc,
        stderr: result.logs,
      ));
    } finally {
      tailTimer?.cancel();
      _activeSessions.remove(sessionId);
      if (progressFile.existsSync()) {
        try {
          progressFile.deleteSync();
        } catch (_) {
          // best-effort cleanup
        }
      }
    }
  }

  /// Rewrites the trailing `-progress pipe:1` pair (appended by every
  /// FfmpegCommand builder) to `-progress <path>` -- stdout isn't ours to
  /// pipe through in-process, so we tail a file instead (§4).
  List<String> _rewriteProgressArg(List<String> args, String progressPath) {
    final out = List<String>.of(args);
    for (var i = 0; i < out.length - 1; i++) {
      if (out[i] == '-progress' && out[i + 1] == 'pipe:1') {
        out[i + 1] = progressPath;
      }
    }
    return out;
  }

  @override
  Future<MediaInfo?> probe(String inputPath) async {
    try {
      return await _shim.probe(inputPath);
    } catch (e, st) {
      Log.e(_tag, 'probe failed for $inputPath', e, st);
      return null;
    }
  }

  @override
  Future<bool> supportsEncoder(String encoderName) async {
    try {
      return await _shim.supportsEncoder(encoderName);
    } catch (e) {
      Log.e(_tag, 'supportsEncoder($encoderName) failed', e);
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    for (final id in _activeSessions) {
      _cancelledBeforeStart.add(id);
      _shim.cancel(id);
    }
  }

  @override
  void dispose() {
    unawaited(cancel());
  }
}
