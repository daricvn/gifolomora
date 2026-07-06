import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../ffmpeg/ffmpeg_command.dart';
import '../ffmpeg/ffmpeg_process_backend.dart';
import '../files/temp_file_service.dart';
import '../../utils/logger.dart';
import 'record_settings_service.dart' show RecordOutputResolution;
import 'record_target.dart';

enum RecordStatus { idle, recording, paused, finalizing }

/// Audio capture selection for one recording session.
class RecordAudioOptions {
  const RecordAudioOptions({
    this.captureMic = false,
    this.captureSystemAudio = false,
    this.micDeviceName,
  });

  final bool captureMic;
  final bool captureSystemAudio;

  /// dshow device name (e.g. `Microphone (Realtek(R) Audio)`); required when
  /// [captureMic] is true.
  final String? micDeviceName;
}

/// Narrow interface the recorder talks to for system-audio capture —
/// implemented by [NativeWindowChannel] on Windows; fakeable in tests.
abstract interface class LoopbackController {
  Future<void> start(String wavPath);
  Future<int> stop();
}

const int kMaxRecordSeconds = 600;

/// Seconds left before the 10-minute cap, given [finishedElapsed] already
/// banked from prior segments. Belt-and-braces alongside the service's own
/// 500ms tick — even a hung Dart timer can't push a single segment's `-t`
/// past the remaining budget.
int remainingCaptureSeconds(Duration finishedElapsed) =>
    kMaxRecordSeconds - finishedElapsed.inSeconds;

/// Parses `ffmpeg -list_devices true -f dshow -i dummy` stderr text for the
/// first DirectShow **audio** device name (ffmpeg lists audio after video;
/// the "DirectShow audio devices" header marks the start of the section).
String? parseDshowDefaultMicName(String stderrText) {
  bool inAudioSection = false;
  for (final line in stderrText.split('\n')) {
    if (line.contains('DirectShow audio devices')) {
      inAudioSection = true;
      continue;
    }
    if (line.contains('DirectShow video devices')) {
      inAudioSection = false;
      continue;
    }
    if (!inAudioSection) continue;
    final match = RegExp(r'"([^"]+)"').firstMatch(line);
    if (match != null) return match.group(1);
  }
  return null;
}

/// Owns the ffmpeg `Process` directly (not `FfmpegBackend.run()` — that API
/// is job-shaped; recording is open-ended and stdin-controlled). Segment-per-
/// resume: ffmpeg has no pause, so pause/resume stops one segment and starts
/// the next; stop() concatenates all segments (+ muxes system audio) into
/// one output file.
class ScreenRecorderService {
  // `loopback` is the public param name; `this._loopback` would leak the
  // private field name into the constructor's named-arg API.
  ScreenRecorderService({LoopbackController? loopback, TempFileService? temp})
      : _loopback = loopback, // ignore: prefer_initializing_formals
        _temp = temp ?? TempFileService();

  static const _tag = 'ScreenRecorderService';

  final LoopbackController? _loopback;
  final TempFileService _temp;

  final _statusController = StreamController<RecordStatus>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<RecordStatus> get status$ => _statusController.stream;
  Stream<String> get errors$ => _errorController.stream;

  RecordStatus _status = RecordStatus.idle;
  RecordStatus get status => _status;

  String? _jobDir;
  RecordTarget? _monitor;
  RecordAudioOptions _audio = const RecordAudioOptions();
  RecordOutputResolution _resolution = RecordOutputResolution.original;

  int _segmentIndex = 0;
  Process? _process;
  bool _expectingExit = false;
  final _videoSegments = <String>[];
  final _wavSegments = <String>[];
  final _stderrTail = <String>[]; // last ~20 lines, for crash diagnostics

  Duration _finishedElapsed = Duration.zero;
  final _segmentStopwatch = Stopwatch();
  Timer? _capTimer;

  double? _syncOffsetSeconds;
  String? _cachedMicDeviceName;

  Duration get elapsed =>
      _finishedElapsed +
      (_status == RecordStatus.recording
          ? _segmentStopwatch.elapsed
          : Duration.zero);

  void _setStatus(RecordStatus s) {
    _status = s;
    _statusController.add(s);
  }

  String get _ffmpegPath => FfmpegProcessBackend.resolveBin('ffmpeg');

  /// Parses `ffmpeg -list_devices true -f dshow -i dummy` stderr for the
  /// first listed DirectShow audio device name. Cached per session.
  Future<String?> discoverDefaultMicDeviceName() async {
    if (_cachedMicDeviceName != null) return _cachedMicDeviceName;
    try {
      final result = await Process.run(
          _ffmpegPath, FfmpegCommand.listDshowDevicesArgs());
      _cachedMicDeviceName = parseDshowDefaultMicName(result.stderr as String);
      return _cachedMicDeviceName;
    } catch (e) {
      Log.e(_tag, 'mic device discovery failed', e);
    }
    return null;
  }

  Future<void> start(
    RecordTarget monitor,
    RecordAudioOptions audio, {
    RecordOutputResolution resolution = RecordOutputResolution.original,
    String? saveDirectory,
  }) async {
    if (_status != RecordStatus.idle) return;
    _monitor = monitor;
    _audio = audio;
    _resolution = resolution;
    _jobDir = await _temp.createJobDir(baseDirOverride: saveDirectory);
    _segmentIndex = 0;
    _videoSegments.clear();
    _wavSegments.clear();
    _finishedElapsed = Duration.zero;
    _syncOffsetSeconds = null;
    await _startSegment();
  }

  Future<void> resume() async {
    if (_status != RecordStatus.paused) return;
    await _startSegment();
  }

  Future<void> _startSegment() async {
    final monitor = _monitor!;
    final jobDir = _jobDir!;
    final remaining = remainingCaptureSeconds(_finishedElapsed);
    if (remaining <= 0) {
      await stop();
      return;
    }
    final videoPath =
        p.join(jobDir, 'seg_${_segmentIndex.toString().padLeft(3, '0')}.mkv');
    final args = FfmpegCommand.screenCapture(
      outputPath: videoPath,
      offsetX: monitor.physicalX,
      offsetY: monitor.physicalY,
      width: monitor.physicalW,
      height: monitor.physicalH,
      durationSeconds: remaining,
      micDeviceName: _audio.captureMic ? _audio.micDeviceName : null,
      targetHeight: _resolution.targetHeight,
    );

    final tProcessStart = DateTime.now();
    _process = await Process.start(_ffmpegPath, args);
    _expectingExit = false;
    _stderrTail.clear();
    // ffmpeg writes a constantly-updating stats line to stderr for the
    // entire (open-ended, potentially minutes-long) recording. Nothing else
    // in this class reads stdout/stderr, so left undrained the pipe buffer
    // fills and ffmpeg's own write() blocks — the process goes silently
    // unresponsive (still "alive": exitCode never resolves, status stays
    // recording) while producing no more output. Must drain both for the
    // whole lifetime of the process, not just while polling for exit.
    _process!.stdout.drain<void>();
    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _stderrTail.add(line);
      if (_stderrTail.length > 20) _stderrTail.removeAt(0);
    });
    _process!.exitCode.then((code) => _onSegmentExit(code, videoPath));

    if (_audio.captureSystemAudio && _loopback != null) {
      final wavPath = p.join(
          jobDir, 'seg_${_segmentIndex.toString().padLeft(3, '0')}.wav');
      await _loopback.start(wavPath);
      _wavSegments.add(wavPath);
      _syncOffsetSeconds ??=
          DateTime.now().difference(tProcessStart).inMilliseconds / 1000.0;
    }

    _segmentStopwatch
      ..reset()
      ..start();
    _segmentIndex++;
    _setStatus(RecordStatus.recording);
    _startCapTimer();
  }

  void _startCapTimer() {
    _capTimer?.cancel();
    _capTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (elapsed.inSeconds >= kMaxRecordSeconds) {
        _capTimer?.cancel();
        stop();
      }
    });
  }

  void _onSegmentExit(int code, String videoPath) {
    if (_expectingExit) return; // pause()/stop() already handled bookkeeping
    final tail = _stderrTail.join('\n');
    Log.e(_tag, 'ffmpeg segment exited unexpectedly (code=$code)\n$tail');
    // MKV has no moov atom to lose — a killed/crashed segment is still
    // playable, so keep it for partial-recording recovery.
    _videoSegments.add(videoPath);
    _finishedElapsed += _segmentStopwatch.elapsed;
    _segmentStopwatch.stop();
    _capTimer?.cancel();
    _setStatus(RecordStatus.idle);
    _errorController.add('Recording stopped unexpectedly (ffmpeg exit $code)');
  }

  /// Gracefully stops the live segment (`q` over stdin, 5s timeout, kill
  /// fallback) and stops loopback capture for it, if any.
  Future<void> _stopCurrentSegment(String videoPath) async {
    _expectingExit = true;
    final process = _process;
    if (process != null) {
      try {
        process.stdin.write('q\n');
        await process.stdin.flush();
      } catch (_) {
        // stdin already closed — process is likely exiting on its own.
      }
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        process.kill();
        await process.exitCode;
      }
    }
    _process = null;
    _capTimer?.cancel();
    _segmentStopwatch.stop();
    _finishedElapsed += _segmentStopwatch.elapsed;
    _videoSegments.add(videoPath);
    if (_audio.captureSystemAudio && _loopback != null) {
      await _loopback.stop();
    }
  }

  String get _currentVideoPath => p.join(_jobDir!,
      'seg_${(_segmentIndex - 1).toString().padLeft(3, '0')}.mkv');

  Future<void> pause() async {
    if (_status != RecordStatus.recording) return;
    await _stopCurrentSegment(_currentVideoPath);
    _setStatus(RecordStatus.paused);
  }

  Future<File> stop() async {
    if (_status == RecordStatus.recording) {
      await _stopCurrentSegment(_currentVideoPath);
    }
    _setStatus(RecordStatus.finalizing);
    try {
      final output = await _finalize();
      _setStatus(RecordStatus.idle);
      return output;
    } catch (e) {
      _setStatus(RecordStatus.idle);
      rethrow;
    }
  }

  /// Recovers a playable file from segments finished before an unexpected
  /// crash (see [errors$]). Returns null if nothing finished yet.
  Future<File?> recoverPartial() async {
    if (_videoSegments.isEmpty) return null;
    return _finalize();
  }

  Future<File> _finalize() async {
    final jobDir = _jobDir!;
    final videoOut = p.join(jobDir, 'concat_video.mp4');
    await _concat(_videoSegments, videoOut, jobDir, 'video_list.txt');

    if (_wavSegments.isEmpty) {
      final finalPath = p.join(jobDir, 'output.mp4');
      await File(videoOut).rename(finalPath);
      return File(finalPath);
    }

    final audioOut = p.join(jobDir, 'concat_audio.wav');
    await _concat(_wavSegments, audioOut, jobDir, 'audio_list.txt');

    final finalPath = p.join(jobDir, 'output.mp4');
    final muxArgs = FfmpegCommand.muxAudio(
      videoPath: videoOut,
      audioPath: audioOut,
      outputPath: finalPath,
      videoHasAudio: _audio.captureMic,
      itsOffsetSeconds: _syncOffsetSeconds ?? 0,
    );
    await _runFfmpeg(muxArgs);
    return File(finalPath);
  }

  // Single segment still routes through the concat demuxer (list of one) —
  // same code path as multi-segment, remux is a stream-copy either way.
  Future<void> _concat(List<String> segments, String outputPath,
      String jobDir, String listFileName) async {
    final listPath = await _writeConcatList(segments, jobDir, listFileName);
    final args = FfmpegCommand.concatSegments(
      listFilePath: listPath,
      outputPath: outputPath,
    );
    await _runFfmpeg(args);
  }

  Future<String> _writeConcatList(
      List<String> segments, String jobDir, String fileName) async {
    final listPath = p.join(jobDir, fileName);
    await File(listPath)
        .writeAsString(FfmpegCommand.buildSegmentConcatListContent(segments));
    return listPath;
  }

  Future<void> _runFfmpeg(List<String> args) async {
    final result = await Process.run(_ffmpegPath, args);
    if (result.exitCode != 0) {
      Log.e(_tag, 'ffmpeg finalize step failed: ${result.stderr}');
      throw ProcessException(_ffmpegPath, args, result.stderr.toString(),
          result.exitCode);
    }
  }

  Future<void> discard() async {
    _capTimer?.cancel();
    _expectingExit = true;
    _process?.kill();
    _process = null;
    _segmentStopwatch.stop();
    if (_jobDir != null) await _temp.cleanJob(_jobDir!);
    _jobDir = null;
    _videoSegments.clear();
    _wavSegments.clear();
    _finishedElapsed = Duration.zero;
    _setStatus(RecordStatus.idle);
  }

  /// Kills a live ffmpeg segment and deletes its job dir on app shutdown.
  /// No-op when idle — a finished job's `_jobDir` may still be the source
  /// file Video Studio is editing, so only an in-progress recording's temp
  /// segments are fair game here. [deleteTemp] gates the dir deletion —
  /// the "Delete temporary video on exit" setting.
  Future<void> cleanupOnShutdown({bool deleteTemp = true}) async {
    if (_status == RecordStatus.idle) return;
    _capTimer?.cancel();
    _expectingExit = true;
    _process?.kill();
    _process = null;
    if (deleteTemp && _jobDir != null) await _temp.cleanJob(_jobDir!);
  }

  void dispose() {
    _capTimer?.cancel();
    _statusController.close();
    _errorController.close();
  }
}
