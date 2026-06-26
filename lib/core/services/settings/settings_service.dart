import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    this.defaultFps = 15,
    this.defaultWidth = 480,
    this.defaultColors = 128,
    this.defaultLossy = 0,
  });

  final int defaultFps;
  final int defaultWidth;
  final int defaultColors;
  final int defaultLossy;

  AppSettings copyWith({
    int? defaultFps,
    int? defaultWidth,
    int? defaultColors,
    int? defaultLossy,
  }) =>
      AppSettings(
        defaultFps: defaultFps ?? this.defaultFps,
        defaultWidth: defaultWidth ?? this.defaultWidth,
        defaultColors: defaultColors ?? this.defaultColors,
        defaultLossy: defaultLossy ?? this.defaultLossy,
      );
}

class SettingsService {
  static const _kFps = 'cfg_fps';
  static const _kWidth = 'cfg_width';
  static const _kColors = 'cfg_colors';
  static const _kLossy = 'cfg_lossy';

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      defaultFps: p.getInt(_kFps) ?? 15,
      defaultWidth: p.getInt(_kWidth) ?? 480,
      defaultColors: p.getInt(_kColors) ?? 128,
      defaultLossy: p.getInt(_kLossy) ?? 0,
    );
  }

  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kFps, s.defaultFps);
    await p.setInt(_kWidth, s.defaultWidth);
    await p.setInt(_kColors, s.defaultColors);
    await p.setInt(_kLossy, s.defaultLossy);
  }
}
