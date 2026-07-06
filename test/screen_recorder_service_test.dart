import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/record/screen_recorder_service.dart';

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
}
