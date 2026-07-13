import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../ffmpeg/ffmpeg_command.dart';
import '../ffmpeg/ffmpeg_dll_backend.dart';
import '../ffmpeg/gm_shim_ffi.dart';
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

/// Narrow interface the recorder talks to for running ffmpeg -- gm_execute/
/// gm_cancel stand in for the old Process.start/stdin "q" pair. Fakeable in
/// tests; the real implementation is [GmShimRecorderEngine].
abstract interface class RecorderEngine {
  Future<GmExecResult> execute(int sessionId, List<String> argv);
  void cancel(int sessionId);
}

class GmShimRecorderEngine implements RecorderEngine {
  GmShimRecorderEngine(String dllPath) : _shim = GmShim(dllPath);
  final GmShim _shim;

  @override
  Future<GmExecResult> execute(int sessionId, List<String> argv) =>
      _shim.execute(sessionId, argv);

  @override
  void cancel(int sessionId) => _shim.cancel(sessionId);

  /// Null if gm_shim.dll isn't present/loadable -- there is no exe fallback
  /// for the recorder (all-in on the DLL backend, PLAN.md §9 decision #2).
  static RecorderEngine? tryCreate() {
    final path = FfmpegDllBackend.tryResolvePath();
    return path == null ? null : GmShimRecorderEngine(path);
  }
}

const int kMaxRecordSeconds = 600;

/// Seconds left before the 10-minute cap, given [finishedElapsed] already
/// banked from prior segments. Belt-and-braces alongside the controller's
/// 500ms tick — even a hung Dart timer can't push a single segment's `-t`
/// past the remaining budget.
int remainingCaptureSeconds(Duration finishedElapsed) =>
    kMaxRecordSeconds - finishedElapsed.inSeconds;

/// Parses `ffmpeg -list_devices true -f dshow -i dummy` log text for the
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

/// Owns ffmpeg sessions directly via [RecorderEngine] (not
/// `FfmpegBackend.run()` — that API is job-shaped; recording is open-ended
/// and cancel-controlled). Segment-per-resume: ffmpeg has no pause, so
/// pause/resume stops one segment and starts the next; stop() concatenates
/// all segments (+ muxes system audio) into one output file.
class ScreenRecorderService {
  // `loopback` is the public param name; `this._loopback` would leak the
  // private field name into the constructor's named-arg API.
  ScreenRecorderService({
    LoopbackController? loopback,
    TempFileService? temp,
    RecorderEngine? engine,
  })  : _loopback = loopback, // ignore: prefer_initializing_formals
        _temp = temp ?? TempFileService(),
        _engine = engine ?? GmShimRecorderEngine.tryCreate();

  static const _tag = 'ScreenRecorderService';

  final LoopbackController? _loopback;
  final TempFileService _temp;
  final RecorderEngine? _engine;

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
  int? _currentSessionId;
  Future<GmExecResult>? _segmentFuture;
  bool _expectingExit = false;
  final _videoSegments = <String>[];
  final _wavSegments = <String>[];

  Duration _finishedElapsed = Duration.zero;
  final _segmentStopwatch = Stopwatch();

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

  /// Parses `ffmpeg -list_devices true -f dshow -i dummy` log output for the
  /// first listed DirectShow audio device name. Cached per session.
  Future<String?> discoverDefaultMicDeviceName() async {
    if (_cachedMicDeviceName != null) return _cachedMicDeviceName;
    final engine = _engine;
    if (engine == null) return null;
    try {
      final result = await engine.execute(
        GmSessionIds.allocate(),
        ['ffmpeg', ...FfmpegCommand.listDshowDevicesArgs()],
      );
      _cachedMicDeviceName = parseDshowDefaultMicName(result.logs);
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
    if (_engine == null) {
      _errorController.add('FFmpeg engine unavailable (gm_shim.dll not found)');
      return;
    }
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
    final sessionId = GmSessionIds.allocate();
    _currentSessionId = sessionId;
    _expectingExit = false;
    final future = _engine!.execute(sessionId, ['ffmpeg', ...args]);
    _segmentFuture = future;
    future.then(
      (result) => _onSegmentExit(sessionId, result, videoPath),
      onError: (Object e, StackTrace st) =>
          _onSegmentError(sessionId, videoPath, e, st),
    );

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
  }

  void _onSegmentExit(int sessionId, GmExecResult result, String videoPath) {
    if (_expectingExit) return; // pause()/stop() already handled bookkeeping
    if (_currentSessionId != sessionId) return; // a stale future, already superseded
    Log.e(_tag,
        'ffmpeg segment exited unexpectedly (rc=${result.rc})\n${result.logs}');
    _handleSegmentDeath(
        videoPath, 'Recording stopped unexpectedly (ffmpeg exit ${result.rc})');
  }

  /// Same bookkeeping as [_onSegmentExit] for a segment future that *throws*
  /// — without this, a throw leaves status stuck at `recording` plus an
  /// unhandled async exception.
  void _onSegmentError(
      int sessionId, String videoPath, Object e, StackTrace st) {
    if (_expectingExit) return;
    if (_currentSessionId != sessionId) return;
    Log.e(_tag, 'ffmpeg segment future threw', e, st);
    _handleSegmentDeath(videoPath, 'Recording stopped unexpectedly ($e)');
  }

  void _handleSegmentDeath(String videoPath, String message) {
    // MKV has no moov atom to lose — a killed/crashed segment is still
    // playable, so keep it for partial-recording recovery.
    _videoSegments.add(videoPath);
    _finishedElapsed += _segmentStopwatch.elapsed;
    _segmentStopwatch.stop();
    _currentSessionId = null;
    _segmentFuture = null;
    _setStatus(RecordStatus.idle);
    _errorController.add(message);
  }

  /// Gracefully stops the live segment (gm_cancel, 5s timeout) and stops
  /// loopback capture for it, if any. Unlike the old Process.kill()
  /// fallback, a session that doesn't honor cancel within the timeout can't
  /// be force-killed in-process (PLAN.md §3) — it's leaked; the segment file
  /// recorded up to the cancel point is still kept for playback/recovery.
  Future<void> _stopCurrentSegment(String videoPath) async {
    _expectingExit = true;
    final sessionId = _currentSessionId;
    final future = _segmentFuture;
    if (sessionId != null && future != null) {
      _engine!.cancel(sessionId);
      try {
        await future.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        Log.e(_tag, 'segment $sessionId did not stop within 5s of cancel(); leaking it');
      }
    }
    _currentSessionId = null;
    _segmentFuture = null;
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

  Future<File>? _stopFuture;

  /// Single-flight: a second stop() while one is already stopping/finalizing
  /// (hotkey mash, cap-tick + click race) awaits the first call's future
  /// instead of running _finalize() twice concurrently.
  Future<File> stop() =>
      _stopFuture ??= _stop().whenComplete(() => _stopFuture = null);

  Future<File> _stop() async {
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
    final engine = _engine;
    if (engine == null) {
      throw StateError('FFmpeg engine unavailable (gm_shim.dll not found)');
    }
    final result = await engine.execute(GmSessionIds.allocate(), ['ffmpeg', ...args]);
    if (result.rc != 0) {
      Log.e(_tag, 'ffmpeg finalize step failed (rc=${result.rc}): ${result.logs}');
      throw Exception('FFmpeg exited with code ${result.rc}: ${result.logs}');
    }
  }

  Future<void> discard() async {
    _expectingExit = true;
    final sessionId = _currentSessionId;
    if (sessionId != null) _engine?.cancel(sessionId);
    _currentSessionId = null;
    _segmentFuture = null;
    _segmentStopwatch.stop();
    if (_audio.captureSystemAudio && _loopback != null) {
      await _loopback.stop();
    }
    if (_jobDir != null) await _temp.cleanJob(_jobDir!);
    _jobDir = null;
    _videoSegments.clear();
    _wavSegments.clear();
    _finishedElapsed = Duration.zero;
    _setStatus(RecordStatus.idle);
  }

  /// Stops a live segment (if any) on app shutdown. Dir cleanup is handled
  /// by `TempFileService.wipeAll()` right after this call (see `app.dart`'s
  /// `onWindowClose`), which deletes the whole job base dir — no need to
  /// clean `_jobDir` individually here too. Bounded wait, same leak-not-kill
  /// tradeoff as `_stopCurrentSegment`.
  Future<void> cleanupOnShutdown() async {
    _expectingExit = true;
    final sessionId = _currentSessionId;
    final future = _segmentFuture;
    if (sessionId != null && future != null) {
      _engine?.cancel(sessionId);
      try {
        await future.timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    _currentSessionId = null;
    _segmentFuture = null;
    if (_audio.captureSystemAudio && _loopback != null) {
      await _loopback.stop();
    }
    _jobDir = null;
  }

  void dispose() {
    _statusController.close();
    _errorController.close();
  }
}
