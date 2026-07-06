import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart' show HotKey;
// ignore: implementation_imports
import 'package:uni_platform/src/extensions/keyboard_key.dart';

import '../../utils/logger.dart';
import 'native_window_channel.dart';
import 'record_settings_service.dart';

const _tag = 'HotkeyService';
const _kStart = 'start';
const _kPauseResume = 'pauseResume';
const _kStop = 'stop';

/// Registers the three record hotkeys as OS-global combos via the native
/// `WH_KEYBOARD_LL` hook (`windows/runner/global_hotkey_hook.cpp`) — not
/// `hotkey_manager`'s own `RegisterHotKey`-backed registration. Windows UIPI
/// silently drops `RegisterHotKey` delivery whenever the foreground window
/// runs at higher integrity than this process (an elevated Task Manager, an
/// installer, some games), which made the hotkeys go dead the moment the app
/// lost focus to one of those. The low-level hook runs beneath that check,
/// so it fires regardless of which window is focused — only which app
/// screen (home / Screen Record / a live recording) is on, via the caller's
/// scope logic in `RecordController`.
///
/// `RecordController` calls [registerAll]/[unregisterAll] from several
/// places that can fire within the same tick (the status-stream listener,
/// the explicit call after `start()`, and scope exit from a screen dispose
/// during the same navigation) — without serialization, two overlapping
/// unregister-then-register cycles could interleave against the native
/// hook's combo map and corrupt which keys end up actually bound. All calls
/// are queued through [_chain] so only one cycle ever runs at a time.
class HotkeyService {
  HotkeyService(this._channel);

  final NativeWindowChannel _channel;
  final _handlers = <String, VoidCallback>{};
  StreamSubscription<String>? _eventSub;
  Future<void> _chain = Future.value();

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final result = _chain.then((_) => action());
    _chain = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> registerAll(
    RecordHotkeys keys, {
    required VoidCallback onStart,
    required VoidCallback onPauseResume,
    required VoidCallback onStop,
  }) {
    return _synchronized(() async {
      if (!Platform.isWindows) return;
      _eventSub ??= _channel.globalHotkeyEvents.listen((identifier) {
        Log.d(_tag, 'globalHotkeyEvents fired: $identifier'
            ' (handler present: ${_handlers.containsKey(identifier)})');
        _handlers[identifier]?.call();
      });
      await _unregisterAllLocked();
      await _register(_kStart, keys.start, onStart);
      await _register(_kPauseResume, keys.pauseResume, onPauseResume);
      await _register(_kStop, keys.stop, onStop);
    });
  }

  Future<void> _register(
      String identifier, HotKey key, VoidCallback handler) async {
    _handlers[identifier] = handler;
    final keyCode = key.physicalKey.keyCode ?? 0;
    final modifiers = (key.modifiers ?? const []).map((m) => m.name).toList();
    Log.d(_tag, '_register($identifier, keyCode=$keyCode,'
        ' modifiers=$modifiers)');
    await _channel.registerGlobalHotkey(
      identifier: identifier,
      keyCode: keyCode,
      modifiers: modifiers,
    );
  }

  Future<void> unregisterAll() => _synchronized(_unregisterAllLocked);

  Future<void> _unregisterAllLocked() async {
    if (!Platform.isWindows) return;
    _handlers.clear();
    await _channel.unregisterAllGlobalHotkeys();
  }
}
