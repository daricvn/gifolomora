import 'dart:async';

import 'package:flutter/services.dart';

import 'screen_recorder_service.dart' show LoopbackController;

/// Wraps the native `gifolomora/native_window` MethodChannel (Windows
/// `windows/runner/flutter_window.cpp`): the recording indicator overlay
/// (native GDI+ drawing, not Flutter — see `recording_indicator.cpp`),
/// WASAPI loopback capture, and the global-hotkey `WH_KEYBOARD_LL` hook (see
/// `global_hotkey_hook.cpp`).
class NativeWindowChannel {
  NativeWindowChannel() {
    // The method channel is a single static object shared by every
    // `NativeWindowChannel()` instance (there are several call sites) — the
    // handler is installed once, gated by the flag, so a later instance
    // never clobbers it and silently orphans the hotkey event stream.
    if (!_handlerInstalled) {
      _handlerInstalled = true;
      _channel.setMethodCallHandler(_handleNativeCall);
    }
  }

  static const _channel = MethodChannel('gifolomora/native_window');
  static bool _handlerInstalled = false;
  static final _hotkeyEvents = StreamController<String>.broadcast();

  static Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onGlobalHotkey') {
      final identifier = (call.arguments as Map)['identifier'] as String;
      _hotkeyEvents.add(identifier);
    }
  }

  /// Fires with the identifier passed to [registerGlobalHotkey] whenever the
  /// native hook matches that combo on a keydown.
  Stream<String> get globalHotkeyEvents => _hotkeyEvents.stream;

  /// Registers a global hotkey via the native `WH_KEYBOARD_LL` hook —
  /// deliberately not `hotkey_manager`'s `RegisterHotKey`, which Windows UIPI
  /// silently blocks whenever the foreground window runs at higher integrity
  /// (an elevated Task Manager, an installer, some games).
  Future<void> registerGlobalHotkey({
    required String identifier,
    required int keyCode,
    required List<String> modifiers,
  }) =>
      _channel.invokeMethod('registerGlobalHotkey', {
        'identifier': identifier,
        'keyCode': keyCode,
        'modifiers': modifiers,
      });

  Future<void> unregisterAllGlobalHotkeys() =>
      _channel.invokeMethod('unregisterAllGlobalHotkeys');

  /// Shows (creating on first call) the click-through recording indicator —
  /// a borderless, per-pixel-alpha, `WS_EX_TRANSPARENT` overlay window drawn
  /// entirely in native GDI+ (pulsing dot + status text, no background fill,
  /// no Flutter content). Every mouse event passes through it; the app is
  /// controlled by global hotkeys only while it's up, never by clicking it.
  /// [x]/[y]/[width]/[height] are **physical** px (same space as
  /// `RecordTarget` / gdigrab) — the caller positions it top-right of the
  /// recorded monitor.
  /// Returns false when the call succeeded but the indicator isn't actually
  /// visible (GDI+ failed to start, or the window couldn't be created) —
  /// distinguishes that from a real success, since both otherwise look
  /// identical to the caller (no exception either way).
  Future<bool> showRecordingIndicator(int x, int y, int width, int height) async {
    final ok = await _channel.invokeMethod<bool>('showRecordingIndicator',
        {'x': x, 'y': y, 'width': width, 'height': height});
    return ok ?? false;
  }

  /// Redraws the indicator with the current status/elapsed/audio-toggle
  /// state. Called on each ~500ms tick plus on pause/resume transitions.
  Future<void> updateRecordingIndicator({
    required bool paused,
    required int elapsedMs,
    required int maxMs,
    required bool micOn,
    required bool systemAudioOn,
  }) =>
      _channel.invokeMethod('updateRecordingIndicator', {
        'paused': paused,
        'elapsedMs': elapsedMs,
        'maxMs': maxMs,
        'micOn': micOn,
        'systemAudioOn': systemAudioOn,
      });

  /// Hides and destroys the indicator window.
  Future<void> hideRecordingIndicator() =>
      _channel.invokeMethod('hideRecordingIndicator');

  /// Starts WASAPI loopback capture of the default render device, writing
  /// 48kHz float WAV to [path].
  Future<void> startLoopback(String path) =>
      _channel.invokeMethod('startLoopback', {'path': path});

  /// Stops loopback capture; returns the actual captured duration in ms.
  Future<int> stopLoopback() async {
    final ms = await _channel.invokeMethod<int>('stopLoopback');
    return ms ?? 0;
  }

  /// Friendly name of the default input ("input") or output ("output") audio
  /// device, for the audio toggles' subtitle rows. Empty string on failure.
  Future<String> getDefaultDeviceName(String flow) async {
    final name =
        await _channel.invokeMethod<String>('getDefaultDeviceName', {'flow': flow});
    return name ?? '';
  }
}

/// Adapts [NativeWindowChannel]'s loopback methods to [LoopbackController]
/// (named `startLoopback`/`stopLoopback` on the channel since it also hosts
/// unrelated methods; `start`/`stop` on the interface `ScreenRecorderService`
/// depends on).
class NativeLoopbackController implements LoopbackController {
  NativeLoopbackController(this._channel);
  final NativeWindowChannel _channel;

  @override
  Future<void> start(String wavPath) => _channel.startLoopback(wavPath);

  @override
  Future<int> stop() => _channel.stopLoopback();
}
