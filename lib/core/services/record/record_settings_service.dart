import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three configurable global hotkeys. Defaults avoid `Ctrl+Shift+*`
/// combos that browsers/IDEs rely on, since a system-scoped hotkey steals
/// the combo everywhere while registered.
class RecordHotkeys {
  const RecordHotkeys({
    required this.start,
    required this.pauseResume,
    required this.stop,
  });

  final HotKey start;
  final HotKey pauseResume;
  final HotKey stop;

  static HotKey _default(PhysicalKeyboardKey key) => HotKey(
        key: key,
        modifiers: const [HotKeyModifier.alt, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );

  static RecordHotkeys defaults() => RecordHotkeys(
        start: _default(PhysicalKeyboardKey.keyR),
        pauseResume: _default(PhysicalKeyboardKey.keyP),
        stop: _default(PhysicalKeyboardKey.keyS),
      );

  RecordHotkeys copyWith({HotKey? start, HotKey? pauseResume, HotKey? stop}) =>
      RecordHotkeys(
        start: start ?? this.start,
        pauseResume: pauseResume ?? this.pauseResume,
        stop: stop ?? this.stop,
      );

  /// True if any pair of the three shares the same key + modifier set.
  bool get hasConflict =>
      _sameCombo(start, pauseResume) ||
      _sameCombo(start, stop) ||
      _sameCombo(pauseResume, stop);

  static bool _sameCombo(HotKey a, HotKey b) {
    if (a.logicalKey.keyId != b.logicalKey.keyId) return false;
    final am = (a.modifiers ?? const []).toSet();
    final bm = (b.modifiers ?? const []).toSet();
    return am.length == bm.length && am.containsAll(bm);
  }
}

/// Output video size. [targetHeight] is `null` for [original] (no `-vf
/// scale`, whatever the monitor natively is); otherwise it's the height fed
/// to `screenCapture`'s `-vf scale=-2:targetHeight` (width auto, even).
enum RecordOutputResolution {
  original(null, 'Original'),
  hd1080(1080, '1080p'),
  hd720(720, '720p'),
  sd480(480, '480p');

  const RecordOutputResolution(this.targetHeight, this.label);
  final int? targetHeight;
  final String label;

  static RecordOutputResolution fromPrefValue(String? value) =>
      RecordOutputResolution.values.firstWhere(
        (r) => r.name == value,
        orElse: () => RecordOutputResolution.original,
      );
}

class RecordSettings {
  const RecordSettings({
    this.captureSystemAudio = false,
    this.captureMic = false,
    required this.hotkeys,
    this.lastDisplayName,
    this.outputResolution = RecordOutputResolution.original,
  });

  final bool captureSystemAudio;
  final bool captureMic;
  final RecordHotkeys hotkeys;

  /// [RecordTarget.name] of the last-used monitor — used by the home-screen
  /// start hotkey to pick a monitor without opening the record screen first.
  final String? lastDisplayName;

  final RecordOutputResolution outputResolution;

  RecordSettings copyWith({
    bool? captureSystemAudio,
    bool? captureMic,
    RecordHotkeys? hotkeys,
    String? lastDisplayName,
    RecordOutputResolution? outputResolution,
  }) =>
      RecordSettings(
        captureSystemAudio: captureSystemAudio ?? this.captureSystemAudio,
        captureMic: captureMic ?? this.captureMic,
        hotkeys: hotkeys ?? this.hotkeys,
        lastDisplayName: lastDisplayName ?? this.lastDisplayName,
        outputResolution: outputResolution ?? this.outputResolution,
      );
}

/// `shared_preferences`-backed persistence for Screen Record's audio toggles,
/// hotkeys, and last-used monitor. Mirrors [RecentsService]'s
/// self-persistence pattern (load once, save per-field on change).
class RecordSettingsService {
  static const _kSystemAudio = 'record_capture_system_audio';
  static const _kMic = 'record_capture_mic';
  static const _kHotkeyStart = 'record_hotkey_start';
  static const _kHotkeyPause = 'record_hotkey_pause_resume';
  static const _kHotkeyStop = 'record_hotkey_stop';
  static const _kLastDisplay = 'record_last_display_name';
  static const _kOutputResolution = 'record_output_resolution';

  Future<RecordSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final defaults = RecordHotkeys.defaults();
    return RecordSettings(
      captureSystemAudio: p.getBool(_kSystemAudio) ?? false,
      captureMic: p.getBool(_kMic) ?? false,
      hotkeys: RecordHotkeys(
        start: _readHotkey(p, _kHotkeyStart) ?? defaults.start,
        pauseResume: _readHotkey(p, _kHotkeyPause) ?? defaults.pauseResume,
        stop: _readHotkey(p, _kHotkeyStop) ?? defaults.stop,
      ),
      lastDisplayName: p.getString(_kLastDisplay),
      outputResolution:
          RecordOutputResolution.fromPrefValue(p.getString(_kOutputResolution)),
    );
  }

  Future<void> setCaptureSystemAudio(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSystemAudio, value);
  }

  Future<void> setCaptureMic(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMic, value);
  }

  Future<void> setHotkeyStart(HotKey key) => _writeHotkey(_kHotkeyStart, key);
  Future<void> setHotkeyPauseResume(HotKey key) =>
      _writeHotkey(_kHotkeyPause, key);
  Future<void> setHotkeyStop(HotKey key) => _writeHotkey(_kHotkeyStop, key);

  Future<void> setLastDisplayName(String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLastDisplay, name);
  }

  Future<void> setOutputResolution(RecordOutputResolution value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOutputResolution, value.name);
  }

  Future<void> _writeHotkey(String prefKey, HotKey key) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(prefKey, jsonEncode(key.toJson()));
  }

  HotKey? _readHotkey(SharedPreferences p, String prefKey) {
    final raw = p.getString(prefKey);
    if (raw == null) return null;
    try {
      return HotKey.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
