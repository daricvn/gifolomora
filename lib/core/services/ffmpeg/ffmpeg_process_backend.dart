// Windows / Linux backend: wraps bundled ffmpeg binary via dart:io Process.
// Place ffmpeg[.exe] and ffprobe[.exe] next to the app executable.
// During dev: build\windows\x64\runner\Debug\ (or Release\).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../utils/logger.dart';
import '../../utils/result.dart';
import 'ffmpeg_backend.dart';
import 'ffmpeg_progress.dart';

class FfmpegProcessBackend implements FfmpegBackend {
  FfmpegProcessBackend({required this.ffmpegPath, required this.ffprobePath});

  final String ffmpegPath;
  final String ffprobePath;

  static const _tag = 'FfmpegProcessBackend';

  Process? _current;
  bool _cancelled = false;

  /// Resolves [name] binary next to Platform.resolvedExecutable.
  static String resolveBin(String name) {
    final ext = Platform.isWindows ? '.exe' : '';
    final dir = File(Platform.resolvedExecutable).parent;
    return p.join(dir.path, '$name$ext');
  }

  @override
  Future<Result<File, FfmpegError>> run(
    List<String> args,
    String outputPath, {
    void Function(FfmpegProgress)? onProgress,
    int? totalFrames,
    int? totalMs,
  }) async {
    _cancelled = false;

    Log.d(_tag, 'run: $ffmpegPath ${args.join(' ')}');

    final process = await Process.start(
      ffmpegPath,
      args,
      runInShell: false,
    );
    _current = process;

    final stderr = StringBuffer();

    // stderr from ffmpeg (log output)
    process.stderr
        .transform(utf8.decoder)
        .listen((chunk) => stderr.write(chunk));

    // stdout carries -progress pipe:1 key=value pairs
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (_cancelled) return;
      FfmpegProgress.parseProgressLine(line, totalFrames, totalMs, onProgress);
    });

    final exitCode = await process.exitCode;
    _current = null;

    if (_cancelled) {
      return Err(const FfmpegError(message: 'Cancelled'));
    }

    if (exitCode == 0) {
      return Ok(File(outputPath));
    }

    Log.e(_tag, 'FFmpeg failed (exit=$exitCode)\n${stderr.toString()}');
    return Err(FfmpegError(
      message: 'FFmpeg exited with code $exitCode',
      exitCode: exitCode,
      stderr: stderr.toString(),
    ));
  }

  @override
  Future<MediaInfo?> probe(String inputPath) async {
    try {
      final result = await Process.run(
        ffprobePath,
        [
          '-v', 'quiet',
          '-print_format', 'json',
          '-show_streams',
          '-show_format',
          inputPath,
        ],
      );
      if (result.exitCode != 0) return null;
      return _parseProbeJson(result.stdout as String);
    } catch (e, st) {
      Log.e(_tag, 'probe failed for $inputPath', e, st);
      return null;
    }
  }

  MediaInfo? _parseProbeJson(String json) {
    // Minimal manual JSON parse to avoid adding a json_serializable dep.
    try {
      final decoded = _jsonDecode(json);
      final streams = (decoded['streams'] as List?)?.cast<Map>() ?? [];
      final video = streams.firstWhereOrNull(
        (s) => s['codec_type'] == 'video',
      );
      if (video == null) return null;

      final hasAudio = streams.any((s) => s['codec_type'] == 'audio');
      final format = decoded['format'] as Map? ?? {};
      final durationSec = double.tryParse(format['duration']?.toString() ?? '') ?? 0;
      final fps = _parseFps(video['r_frame_rate']?.toString());

      return MediaInfo(
        durationMs: (durationSec * 1000).round(),
        width: (video['width'] as num?)?.toInt() ?? 0,
        height: (video['height'] as num?)?.toInt() ?? 0,
        fps: fps,
        hasAudio: hasAudio,
      );
    } catch (_) {
      return null;
    }
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

  // Minimal JSON decode using dart:convert
  dynamic _jsonDecode(String s) => jsonDecode(s);

  @override
  Future<bool> supportsEncoder(String encoderName) async {
    try {
      final result =
          await Process.run(ffmpegPath, ['-hide_banner', '-encoders']);
      return (result.stdout as String).contains(encoderName);
    } catch (e) {
      Log.e(_tag, 'supportsEncoder($encoderName) failed', e);
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    _current?.kill();
  }

  @override
  void dispose() {
    _current?.kill();
    _current = null;
  }
}

extension _IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
