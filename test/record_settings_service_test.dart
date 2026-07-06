import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/record/record_settings_service.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// HotKey.toJson() includes an auto-generated uuid identifier that differs
// per instance even for an equivalent combo — compare everything else.
Map<String, dynamic> _combo(HotKey k) =>
    Map<String, dynamic>.from(k.toJson())..remove('identifier');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load() with nothing persisted returns defaults', () async {
    final settings = await RecordSettingsService().load();
    expect(settings.captureSystemAudio, false);
    expect(settings.captureMic, false);
    expect(settings.lastDisplayName, isNull);
    final defaults = RecordHotkeys.defaults();
    expect(_combo(settings.hotkeys.start), _combo(defaults.start));
    expect(_combo(settings.hotkeys.pauseResume), _combo(defaults.pauseResume));
    expect(_combo(settings.hotkeys.stop), _combo(defaults.stop));
  });

  test('audio toggles + last display round-trip', () async {
    final service = RecordSettingsService();
    await service.setCaptureSystemAudio(true);
    await service.setCaptureMic(true);
    await service.setLastDisplayName(r'\\.\DISPLAY2');

    final reloaded = await service.load();
    expect(reloaded.captureSystemAudio, true);
    expect(reloaded.captureMic, true);
    expect(reloaded.lastDisplayName, r'\\.\DISPLAY2');
  });

  test('hotkeys round-trip through jsonEncode/HotKey.fromJson', () async {
    final service = RecordSettingsService();
    final custom = HotKey(
      key: PhysicalKeyboardKey.keyG,
      modifiers: const [HotKeyModifier.control, HotKeyModifier.alt],
      scope: HotKeyScope.system,
    );
    await service.setHotkeyStart(custom);

    final reloaded = await service.load();
    expect(reloaded.hotkeys.start.physicalKey, PhysicalKeyboardKey.keyG);
    expect(reloaded.hotkeys.start.modifiers, contains(HotKeyModifier.control));
    expect(reloaded.hotkeys.start.modifiers, contains(HotKeyModifier.alt));
    // Untouched hotkeys still fall back to defaults.
    final defaults = RecordHotkeys.defaults();
    expect(_combo(reloaded.hotkeys.stop), _combo(defaults.stop));
  });

  test('outputResolution defaults to Original and round-trips', () async {
    final service = RecordSettingsService();
    final defaults = await service.load();
    expect(defaults.outputResolution, RecordOutputResolution.original);

    await service.setOutputResolution(RecordOutputResolution.hd720);
    final reloaded = await service.load();
    expect(reloaded.outputResolution, RecordOutputResolution.hd720);
  });

  test('RecordHotkeys.hasConflict detects a shared key+modifier combo', () {
    final a = HotKey(
      key: PhysicalKeyboardKey.keyR,
      modifiers: const [HotKeyModifier.alt, HotKeyModifier.shift],
    );
    final b = HotKey(
      key: PhysicalKeyboardKey.keyR,
      modifiers: const [HotKeyModifier.shift, HotKeyModifier.alt],
    );
    final c = HotKey(
      key: PhysicalKeyboardKey.keyS,
      modifiers: const [HotKeyModifier.alt, HotKeyModifier.shift],
    );
    expect(RecordHotkeys(start: a, pauseResume: b, stop: c).hasConflict, true);
    expect(RecordHotkeys(start: a, pauseResume: c, stop: c).hasConflict, true);
    expect(
      RecordHotkeys.defaults().hasConflict,
      false,
    );
  });
}
