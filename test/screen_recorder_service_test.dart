import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/gm_shim_ffi.dart';
import 'package:gifolomora/core/services/files/temp_file_service.dart';
import 'package:gifolomora/core/services/record/record_target.dart';
import 'package:gifolomora/core/services/record/screen_recorder_service.dart';

/// Avoids TempFileService's real getTemporaryDirectory() call, which needs
/// the path_provider platform channel (unavailable without
/// TestWidgetsFlutterBinding) -- uses Directory.systemTemp directly instead.
class _FakeTempFileService extends TempFileService {
  final _dirs = <String>[];

  @override
  Future<String> createJobDir({String? baseDirOverride}) async {
    final base = baseDirOverride ?? Directory.systemTemp.path;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dir = Directory('$base/gifolomora_test_$id');
    await dir.create(recursive: true);
    _dirs.add(dir.path);
    return dir.path;
  }

  @override
  Future<void> cleanJob(String jobDir) async {
    try {
      final dir = Directory(jobDir);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}

/// Fakes gm_execute/gm_cancel. Segment-capture calls (argv containing
/// `gdigrab`) are held open until the test completes or cancels them --
/// same shape as a real open-ended capture session; everything else
/// (dshow device listing, concat/mux finalize steps) resolves immediately.
/// On a successful completion it writes a dummy file at the command's
/// output path (always the last argv element, per FfmpegCommand's builders)
/// so the recorder's own concat/rename file-I/O has something real to work
/// with.
class FakeRecorderEngine implements RecorderEngine {
  final Map<int, Completer<GmExecResult>> held = {};
  final List<int> cancelledSessions = [];
  final List<List<String>> executedArgv = [];

  @override
  Future<GmExecResult> execute(int sessionId, List<String> argv) {
    executedArgv.add(argv);
    if (argv.any((a) => a.contains('gdigrab'))) {
      final c = Completer<GmExecResult>();
      held[sessionId] = c;
      return c.future.then((result) {
        if (result.rc == 0) _writeDummyOutput(argv);
        return result;
      });
    }
    _writeDummyOutput(argv);
    return Future.value(const GmExecResult(0, ''));
  }

  void _writeDummyOutput(List<String> argv) {
    final path = argv.last;
    if (!(path.endsWith('.mkv') || path.endsWith('.mp4') || path.endsWith('.wav'))) {
      return; // not an output-path command (e.g. dshow device listing)
    }
    try {
      File(path).writeAsStringSync('fake-output');
    } catch (_) {
      // best-effort; not every finalize step's output path is exercised
    }
  }

  @override
  void cancel(int sessionId) {
    cancelledSessions.add(sessionId);
    // Real fftools exits cancelled sessions with 255, not 0 (confirmed
    // against a real gm_shim.dll capture) -- ScreenRecorderService doesn't
    // branch on this rc for its own cancels (the _expectingExit flag short-
    // circuits _onSegmentExit first), so this only matters for fidelity.
    held[sessionId]?.complete(const GmExecResult(gmCancelledExitCode, 'cancelled gracefully'));
  }

  void crashSession(int sessionId, {int rc = gmCrashExitCode}) {
    held[sessionId]?.complete(GmExecResult(rc, 'native crash'));
  }

  int? get lastHeldSessionId => held.keys.isEmpty ? null : held.keys.last;
}

const _testMonitor = RecordTarget(
  index: 0,
  name: 'Test Monitor',
  label: 'Test Monitor',
  physicalX: 0,
  physicalY: 0,
  physicalW: 640,
  physicalH: 480,
  isPrimary: true,
);

void main() {
  group('remainingCaptureSeconds', () {
    test('full budget when nothing recorded yet', () {
      expect(remainingCaptureSeconds(Duration.zero), 600);
    });

    test('decreases by finished elapsed time (pauses excluded upstream)', () {
      expect(remainingCaptureSeconds(const Duration(minutes: 3)), 420);
    });

    test('can go to zero or negative once the cap is reached/exceeded', () {
      expect(remainingCaptureSeconds(const Duration(minutes: 10)), 0);
      expect(remainingCaptureSeconds(const Duration(minutes: 11)), -60);
    });
  });

  group('parseDshowDefaultMicName', () {
    test('picks the first quoted name under the audio devices header', () {
      const stderrText = '''
[dshow @ 000001] DirectShow video devices (some may be both video and audio devices)
[dshow @ 000001]  "Integrated Webcam"
[dshow @ 000001] DirectShow audio devices
[dshow @ 000001]  "Microphone (Realtek(R) Audio)"
[dshow @ 000001]     Alternative name "@device_cm_{33D9A762}\\wave_{A1B2}"
[dshow @ 000001]  "Line In (Realtek(R) Audio)"
''';
      expect(parseDshowDefaultMicName(stderrText),
          'Microphone (Realtek(R) Audio)');
    });

    test('returns null when there is no audio devices section', () {
      const stderrText = '''
[dshow @ 000001] DirectShow video devices
[dshow @ 000001]  "Integrated Webcam"
''';
      expect(parseDshowDefaultMicName(stderrText), isNull);
    });

    test('returns null on empty/garbage input', () {
      expect(parseDshowDefaultMicName(''), isNull);
    });
  });

  test('RecordAudioOptions defaults to everything off', () {
    const options = RecordAudioOptions();
    expect(options.captureMic, false);
    expect(options.captureSystemAudio, false);
    expect(options.micDeviceName, isNull);
  });

  test('ScreenRecorderService starts idle and stays idle until start()', () {
    final service = ScreenRecorderService();
    expect(service.status, RecordStatus.idle);
    expect(service.elapsed, Duration.zero);
    service.dispose();
  });

  test('pause()/resume() are no-ops from the wrong state', () async {
    final service = ScreenRecorderService();
    // Not recording yet — pause() must not throw or change status.
    await service.pause();
    expect(service.status, RecordStatus.idle);
    // Not paused — resume() must not throw or change status.
    await service.resume();
    expect(service.status, RecordStatus.idle);
    service.dispose();
  });

  test('cleanupOnShutdown() is safe to call while idle (app-exit path)',
      () async {
    final service = ScreenRecorderService();
    await service.cleanupOnShutdown();
    expect(service.status, RecordStatus.idle);
    service.dispose();
  });

  group('ScreenRecorderService with no engine (gm_shim.dll unavailable)', () {
    test('start() surfaces an error and stays idle', () async {
      final service = ScreenRecorderService(); // no dll in the test env
      final errors = <String>[];
      service.errors$.listen(errors.add);

      await service.start(_testMonitor, const RecordAudioOptions());

      expect(service.status, RecordStatus.idle);
      expect(errors, hasLength(1));
      expect(errors.single, contains('gm_shim.dll'));
      service.dispose();
    });
  });

  group('ScreenRecorderService with FakeRecorderEngine', () {
    test('start() runs a gdigrab capture session and goes to recording', () async {
      final engine = FakeRecorderEngine();
      final service = ScreenRecorderService(engine: engine, temp: _FakeTempFileService());

      await service.start(_testMonitor, const RecordAudioOptions());

      expect(service.status, RecordStatus.recording);
      expect(engine.executedArgv, hasLength(1));
      expect(engine.executedArgv.single, contains('gdigrab'));
      expect(engine.held, hasLength(1));

      service.dispose();
    });

    test('pause() cancels the live segment and moves to paused', () async {
      final engine = FakeRecorderEngine();
      final service = ScreenRecorderService(engine: engine, temp: _FakeTempFileService());
      await service.start(_testMonitor, const RecordAudioOptions());
      final firstSessionId = engine.lastHeldSessionId;

      await service.pause();

      expect(service.status, RecordStatus.paused);
      expect(engine.cancelledSessions, equals([firstSessionId]));
      service.dispose();
    });

    test('resume() after pause() starts a new held segment', () async {
      final engine = FakeRecorderEngine();
      final service = ScreenRecorderService(engine: engine, temp: _FakeTempFileService());
      await service.start(_testMonitor, const RecordAudioOptions());
      await service.pause();

      await service.resume();

      expect(service.status, RecordStatus.recording);
      expect(engine.executedArgv, hasLength(2));
      service.dispose();
    });

    test('stop() cancels the segment, finalizes, and returns the output file',
        () async {
      final engine = FakeRecorderEngine();
      final service = ScreenRecorderService(engine: engine, temp: _FakeTempFileService());
      await service.start(_testMonitor, const RecordAudioOptions());

      final output = await service.stop();

      expect(service.status, RecordStatus.idle);
      expect(output.path, endsWith('output.mp4'));
      expect(output.existsSync(), isTrue);
      service.dispose();
    });

    test('a segment that reports a crash surfaces via errors\$ and returns to idle',
        () async {
      final engine = FakeRecorderEngine();
      final service = ScreenRecorderService(engine: engine, temp: _FakeTempFileService());
      final errors = <String>[];
      service.errors$.listen(errors.add);

      await service.start(_testMonitor, const RecordAudioOptions());
      final sessionId = engine.lastHeldSessionId!;
      engine.crashSession(sessionId);
      await Future<void>.delayed(Duration.zero); // let the .then() callback run

      expect(service.status, RecordStatus.idle);
      expect(errors, hasLength(1));
      expect(errors.single, contains('ffmpeg exit'));
      service.dispose();
    });

    test('recoverPartial() finalizes segments recorded before a crash', () async {
      final engine = FakeRecorderEngine();
      final service = ScreenRecorderService(engine: engine, temp: _FakeTempFileService());
      await service.start(_testMonitor, const RecordAudioOptions());
      final sessionId = engine.lastHeldSessionId!;
      engine.crashSession(sessionId);
      await Future<void>.delayed(Duration.zero);

      final recovered = await service.recoverPartial();

      expect(recovered, isNotNull);
      expect(recovered!.existsSync(), isTrue);
      service.dispose();
    });

    test('discard() cancels the live segment and returns to idle without finalizing',
        () async {
      final engine = FakeRecorderEngine();
      final service = ScreenRecorderService(engine: engine, temp: _FakeTempFileService());
      await service.start(_testMonitor, const RecordAudioOptions());
      final sessionId = engine.lastHeldSessionId;

      await service.discard();

      expect(service.status, RecordStatus.idle);
      expect(engine.cancelledSessions, equals([sessionId]));
      service.dispose();
    });

    test('cleanupOnShutdown() cancels a live segment with a bounded wait', () async {
      final engine = FakeRecorderEngine();
      final service = ScreenRecorderService(engine: engine, temp: _FakeTempFileService());
      await service.start(_testMonitor, const RecordAudioOptions());
      final sessionId = engine.lastHeldSessionId;

      await service.cleanupOnShutdown();

      expect(engine.cancelledSessions, equals([sessionId]));
      service.dispose();
    });

    test('discoverDefaultMicDeviceName() routes through the engine without throwing',
        () async {
      final engine = FakeRecorderEngine();
      final service = ScreenRecorderService(engine: engine, temp: _FakeTempFileService());

      // dshow listing isn't a "gdigrab" call, so the fake resolves it
      // immediately with empty logs -- parseDshowDefaultMicName('') is null,
      // covered separately above; this test only proves the plumbing calls
      // through to the engine without throwing.
      final name = await service.discoverDefaultMicDeviceName();

      expect(name, isNull);
      expect(engine.executedArgv.single, contains('dshow'));
      service.dispose();
    });
  });
}
