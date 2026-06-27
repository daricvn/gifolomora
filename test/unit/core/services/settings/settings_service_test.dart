import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppSettings', () {
    test('defaults are correct', () {
      const s = AppSettings();
      expect(s.defaultFps, equals(15));
      expect(s.defaultWidth, equals(480));
      expect(s.defaultColors, equals(128));
      expect(s.defaultLossy, equals(0));
    });

    test('copyWith updates only the specified field', () {
      const s = AppSettings();
      final updated = s.copyWith(defaultFps: 30);
      expect(updated.defaultFps, equals(30));
      expect(updated.defaultWidth, equals(480));
      expect(updated.defaultColors, equals(128));
      expect(updated.defaultLossy, equals(0));
    });

    test('copyWith with all fields', () {
      const s = AppSettings();
      final updated =
          s.copyWith(defaultFps: 24, defaultWidth: 360, defaultColors: 64, defaultLossy: 20);
      expect(updated.defaultFps, equals(24));
      expect(updated.defaultWidth, equals(360));
      expect(updated.defaultColors, equals(64));
      expect(updated.defaultLossy, equals(20));
    });
  });

  group('SettingsService', () {
    test('load returns defaults when prefs empty', () async {
      final svc = SettingsService();
      final settings = await svc.load();
      expect(settings.defaultFps, equals(15));
      expect(settings.defaultWidth, equals(480));
      expect(settings.defaultColors, equals(128));
      expect(settings.defaultLossy, equals(0));
    });

    test('save then load round-trips all values', () async {
      final svc = SettingsService();
      const saved = AppSettings(
        defaultFps: 24,
        defaultWidth: 320,
        defaultColors: 64,
        defaultLossy: 20,
      );
      await svc.save(saved);
      final loaded = await svc.load();
      expect(loaded.defaultFps, equals(24));
      expect(loaded.defaultWidth, equals(320));
      expect(loaded.defaultColors, equals(64));
      expect(loaded.defaultLossy, equals(20));
    });

    test('second save overwrites first', () async {
      final svc = SettingsService();
      await svc.save(const AppSettings(defaultFps: 24));
      await svc.save(const AppSettings(defaultFps: 30));
      final loaded = await svc.load();
      expect(loaded.defaultFps, equals(30));
    });
  });
}
