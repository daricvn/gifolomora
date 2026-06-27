// Android/iOS backend using ffmpeg_kit_flutter_new.
// VERIFY: check pub.dev for current package name, version, and API before enabling Android builds.
// If package is unavailable, swap this file for your preferred ffmpeg_kit fork.
import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';

import '../../utils/logger.dart';
import '../../utils/result.dart';
import 'ffmpeg_backend.dart';
import 'ffmpeg_progress.dart';

class FfmpegKitBackend implements FfmpegBackend {
  static const _tag = 'FfmpegKitBackend';

  bool _cancelled = false;

  @override
  Future<Result<File, FfmpegError>> run(
    List<String> args,
    String outputPath, {
    void Function(FfmpegProgress)? onProgress,
    int? totalFrames,
    int? totalMs,
  }) async {
    _cancelled = false;
    // Strip -progress pipe:1 — the kit drives progress via statisticsCallback.
    final filteredArgs = _stripProgressFlag(args);
    final command = filteredArgs.map(_quoteArg).join(' ');
    final completer = Completer<int?>();
    final stderr = StringBuffer();

    await FFmpegKit.executeAsync(
      command,
      (session) async {
        final rc = await session.getReturnCode();
        if (!completer.isCompleted) completer.complete(rc?.getValue());
      },
      (log) {
        stderr.writeln(log.getMessage());
      },
      (stats) {
        if (_cancelled) return;
        final timeMs = stats.getTime();
        final frames = stats.getVideoFrameNumber();
        double fraction = 0;
        if (totalMs != null && totalMs > 0) {
          fraction = (timeMs / totalMs).clamp(0.0, 1.0);
        } else if (totalFrames != null && totalFrames > 0) {
          fraction = (frames / totalFrames).clamp(0.0, 1.0);
        }
        onProgress?.call(
          FfmpegProgress(fraction: fraction, framesDone: frames, timeMs: timeMs),
        );
      },
    );

    final exitCode = await completer.future;
    if (exitCode == 0) {
      return Ok(File(outputPath));
    }
    Log.e(_tag, 'FFmpeg failed (exit=$exitCode)', stderr.toString());
    return Err(FfmpegError(
      message: 'FFmpeg exited with code $exitCode',
      exitCode: exitCode,
      stderr: stderr.toString(),
    ));
  }

  @override
  Future<MediaInfo?> probe(String inputPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(inputPath);
      final info = session.getMediaInformation();
      if (info == null) return null;

      final streams = info.getStreams();
      final video = streams.firstWhereOrNull((s) => s.getType() == 'video');
      if (video == null) return null;

      final hasAudio = streams.any((s) => s.getType() == 'audio');
      final durationSec = double.tryParse(info.getDuration() ?? '') ?? 0;
      return MediaInfo(
        durationMs: (durationSec * 1000).round(),
        width: int.tryParse(video.getWidth()?.toString() ?? '') ?? 0,
        height: int.tryParse(video.getHeight()?.toString() ?? '') ?? 0,
        fps: _parseFps(video.getRealFrameRate()),
        hasAudio: hasAudio,
      );
    } catch (e, st) {
      Log.e(_tag, 'probe failed for $inputPath', e, st);
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await FFmpegKit.cancel();
  }

  @override
  void dispose() {}

  static List<String> _stripProgressFlag(List<String> args) {
    final result = <String>[];
    for (int i = 0; i < args.length; i++) {
      if (args[i] == '-progress') {
        i++; // skip 'pipe:1'
        continue;
      }
      result.add(args[i]);
    }
    return result;
  }

  double? _parseFps(String? fr) {
    if (fr == null) return null;
    final parts = fr.split('/');
    if (parts.length == 2) {
      final n = double.tryParse(parts[0]);
      final d = double.tryParse(parts[1]);
      if (n != null && d != null && d != 0) return n / d;
    }
    return double.tryParse(fr);
  }

  String _quoteArg(String arg) =>
      arg.contains(' ') ? '"$arg"' : arg;
}

extension _IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
