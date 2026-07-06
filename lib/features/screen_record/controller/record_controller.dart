import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:screen_retriever/screen_retriever.dart' show Display, screenRetriever;

import '../../../core/services/providers.dart';
import '../../../core/services/record/hotkey_service.dart';
import '../../../core/services/record/native_window_channel.dart';
import '../../../core/services/record/record_settings_service.dart';
import '../../../core/services/record/record_target.dart';
import '../../../core/services/record/screen_recorder_service.dart';
import '../../../core/utils/logger.dart';
import '../../../router/app_router.dart';

const _tag = 'RecordController';

class RecordState {
  const RecordState({
    this.monitors = const [],
    this.rawDisplays = const [],
    this.selected,
    this.status = RecordStatus.idle,
    this.elapsed = Duration.zero,
    required this.settings,
    this.error,
  });

  final List<RecordTarget> monitors;
  final List<Display> rawDisplays;
  final RecordTarget? selected;
  final RecordStatus status;
  final Duration elapsed;
  final RecordSettings settings;
  final String? error;

  bool get isRecording => status != RecordStatus.idle;

  RecordState copyWith({
    Object? monitors = _s,
    Object? rawDisplays = _s,
    Object? selected = _s,
    RecordStatus? status,
    Duration? elapsed,
    RecordSettings? settings,
    Object? error = _s,
  }) =>
      RecordState(
        monitors: identical(monitors, _s)
            ? this.monitors
            : monitors as List<RecordTarget>,
        rawDisplays: identical(rawDisplays, _s)
            ? this.rawDisplays
            : rawDisplays as List<Display>,
        selected:
            identical(selected, _s) ? this.selected : selected as RecordTarget?,
        status: status ?? this.status,
        elapsed: elapsed ?? this.elapsed,
        settings: settings ?? this.settings,
        error: identical(error, _s) ? this.error : error as String?,
      );

  static const _s = Object();
}

/// Orchestrates monitor enumeration, settings load/save, the recorder
/// service, the native click-through recording indicator, and global-hotkey
/// (un)registration. Kept alive for the app's lifetime (plain
/// [AsyncNotifierProvider], like every other controller in this codebase) so
/// a recording survives navigating away from both the home and Screen
/// Record screens.
class RecordController extends AsyncNotifier<RecordState> {
  ScreenRecorderService? _recorderInstance;
  late final HotkeyService _hotkeyService =
      HotkeyService(ref.read(nativeWindowChannelProvider));
  final Set<String> _activeScopes = {};
  StreamSubscription<RecordStatus>? _statusSub;
  StreamSubscription<String>? _errorSub;
  Timer? _elapsedTicker;

  ScreenRecorderService get _recorder => _recorderInstance ??=
      ScreenRecorderService(
          loopback: NativeLoopbackController(ref.read(nativeWindowChannelProvider)));

  @override
  Future<RecordState> build() async {
    final settings = await ref.read(recordSettingsServiceProvider).load();
    final (monitors, displays) = await _enumerateMonitors();
    final selected = _pickInitialMonitor(monitors, settings.lastDisplayName);

    ref.onDispose(() {
      _statusSub?.cancel();
      _errorSub?.cancel();
      _elapsedTicker?.cancel();
      _hotkeyService.unregisterAll();
      _recorderInstance?.dispose();
    });
    _listenToService();

    return RecordState(
      monitors: monitors,
      rawDisplays: displays,
      selected: selected,
      settings: settings,
    );
  }

  RecordTarget? _pickInitialMonitor(
      List<RecordTarget> monitors, String? lastDisplayName) {
    if (monitors.isEmpty) return null;
    for (final m in monitors) {
      if (m.name == lastDisplayName) return m;
    }
    for (final m in monitors) {
      if (m.isPrimary) return m;
    }
    return monitors.first;
  }

  Future<(List<RecordTarget>, List<Display>)> _enumerateMonitors() async {
    if (!Platform.isWindows) return (const <RecordTarget>[], const <Display>[]);
    try {
      final displays = await screenRetriever.getAllDisplays();
      String? primaryName;
      try {
        primaryName = (await screenRetriever.getPrimaryDisplay()).name;
      } catch (_) {
        // getPrimaryDisplay failing still leaves a usable (if primary-less)
        // monitor list — fall through with primaryName null.
      }
      final targets = <RecordTarget>[
        for (var i = 0; i < displays.length; i++)
          RecordTarget.fromDisplay(
            displays[i],
            index: i,
            isPrimary: displays[i].name == primaryName,
          ),
      ];
      return (targets, displays);
    } catch (_) {
      return (const <RecordTarget>[], const <Display>[]);
    }
  }

  void _listenToService() {
    _statusSub = _recorder.status$.listen((status) {
      final s = state.valueOrNull;
      if (s == null) return;
      state = AsyncData(s.copyWith(status: status, elapsed: _recorder.elapsed));
      _syncHotkeyRegistration();
      if (status == RecordStatus.idle) {
        _hideIndicator();
      } else {
        _updateIndicator();
      }
    });
    _errorSub = _recorder.errors$.listen((msg) async {
      final recovered = await _recorder.recoverPartial();
      await _hideIndicator();
      final s = state.valueOrNull;
      if (s != null) {
        state = AsyncData(s.copyWith(error: msg, status: RecordStatus.idle));
      }
      await _syncHotkeyRegistration();
      if (recovered != null) appRouter.push('/video-studio', extra: recovered);
    });
    _elapsedTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final s = state.valueOrNull;
      if (s != null && s.isRecording) {
        state = AsyncData(s.copyWith(elapsed: _recorder.elapsed));
        _updateIndicator();
      }
    });
  }

  // ── Monitor / audio option setters ────────────────────────────────────

  void selectMonitor(RecordTarget target) {
    final s = state.valueOrNull;
    if (s == null) return;
    state = AsyncData(s.copyWith(selected: target));
  }

  Future<void> setCaptureSystemAudio(bool value) async {
    await ref.read(recordSettingsServiceProvider).setCaptureSystemAudio(value);
    final s = state.valueOrNull;
    if (s == null) return;
    state = AsyncData(
        s.copyWith(settings: s.settings.copyWith(captureSystemAudio: value)));
  }

  Future<void> setCaptureMic(bool value) async {
    await ref.read(recordSettingsServiceProvider).setCaptureMic(value);
    final s = state.valueOrNull;
    if (s == null) return;
    state =
        AsyncData(s.copyWith(settings: s.settings.copyWith(captureMic: value)));
  }

  Future<void> setOutputResolution(RecordOutputResolution value) async {
    await ref.read(recordSettingsServiceProvider).setOutputResolution(value);
    final s = state.valueOrNull;
    if (s == null) return;
    state = AsyncData(
        s.copyWith(settings: s.settings.copyWith(outputResolution: value)));
  }

  /// Returns false (and leaves persisted state untouched) on conflict with
  /// one of the other two hotkeys, or if the OS rejects the combo (already
  /// taken by another app) — caller surfaces either as an [AppToast].
  Future<bool> setHotkey(HotkeySlot slot, HotKey key) async {
    final s = state.valueOrNull;
    if (s == null) return false;
    final current = s.settings.hotkeys;
    final candidate = switch (slot) {
      HotkeySlot.start => current.copyWith(start: key),
      HotkeySlot.pauseResume => current.copyWith(pauseResume: key),
      HotkeySlot.stop => current.copyWith(stop: key),
    };
    if (candidate.hasConflict) return false;

    final settingsService = ref.read(recordSettingsServiceProvider);
    switch (slot) {
      case HotkeySlot.start:
        await settingsService.setHotkeyStart(key);
      case HotkeySlot.pauseResume:
        await settingsService.setHotkeyPauseResume(key);
      case HotkeySlot.stop:
        await settingsService.setHotkeyStop(key);
    }
    state = AsyncData(s.copyWith(settings: s.settings.copyWith(hotkeys: candidate)));
    try {
      await _syncHotkeyRegistrationOrThrow();
      return true;
    } catch (e, st) {
      Log.e(_tag, 'setHotkey registration failed', e, st);
      return false;
    }
  }

  // ── Hotkey scope lifecycle (home screen / record screen / live recording) ──

  // `await future` first: `enterHotkeyScope`/`exitHotkeyScope` are called
  // from a screen's `initState` via `Future.microtask`, which can fire
  // before `build()` (settings load + monitor enumeration) has resolved.
  // Without this, `_syncHotkeyRegistrationOrThrow` reads `state.valueOrNull`
  // while it's still null, silently takes the unregister branch, and the
  // hotkeys never actually get registered on a cold launch — no scope
  // change or recording-status event ever re-triggers the sync afterward.
  Future<void> enterHotkeyScope(String scopeId) async {
    _activeScopes.add(scopeId);
    await future;
    await _syncHotkeyRegistration();
  }

  Future<void> exitHotkeyScope(String scopeId) async {
    _activeScopes.remove(scopeId);
    await future;
    await _syncHotkeyRegistration();
  }

  /// Throwing version — [setHotkey] needs the failure to propagate so it can
  /// report a conflict/OS-registration failure back to its caller as `false`.
  Future<void> _syncHotkeyRegistrationOrThrow() async {
    final s = state.valueOrNull;
    if (s == null || (_activeScopes.isEmpty && !s.isRecording)) {
      await _hotkeyService.unregisterAll();
      return;
    }
    await _hotkeyService.registerAll(
      s.settings.hotkeys,
      onStart: () {
        if (state.valueOrNull?.status == RecordStatus.idle) {
          appRouter.push('/screen-record');
          startRecording();
        }
      },
      onPauseResume: togglePauseResume,
      onStop: stopRecording,
    );
  }

  /// Safe (catch + log, never throws) wrapper — used by every fire-and-forget
  /// call site (status-stream listener, scope enter/exit) where an unhandled
  /// throw would silently vanish and leave hotkeys in an indeterminate state.
  Future<void> _syncHotkeyRegistration() async {
    try {
      await _syncHotkeyRegistrationOrThrow();
    } catch (e, st) {
      Log.e(_tag, '_syncHotkeyRegistration failed', e, st);
    }
  }

  // ── Recording lifecycle ────────────────────────────────────────────────

  Future<void> startRecording() async {
    final s = state.valueOrNull;
    Log.d(_tag,
        'startRecording called: s=${s != null}, selected=${s?.selected?.name}, status=${s?.status}');
    if (s == null || s.selected == null || s.status != RecordStatus.idle) {
      Log.d(_tag, 'startRecording: guard returned early, no-op');
      return;
    }
    final monitor = s.selected!;
    try {
      await ref
          .read(recordSettingsServiceProvider)
          .setLastDisplayName(monitor.name);

      String? micName;
      if (s.settings.captureMic) {
        micName = await _recorder.discoverDefaultMicDeviceName();
        if (micName == null) {
          state = AsyncData(s.copyWith(error: 'No microphone device found'));
          return;
        }
      }

      Log.d(_tag, 'calling ScreenRecorderService.start on ${monitor.name}'
          ' (${monitor.physicalX},${monitor.physicalY} ${monitor.physicalW}x${monitor.physicalH})');
      await _recorder.start(
        monitor,
        RecordAudioOptions(
          captureMic: s.settings.captureMic,
          captureSystemAudio: s.settings.captureSystemAudio,
          micDeviceName: micName,
        ),
        resolution: s.settings.outputResolution,
      );
      Log.d(_tag, 'ScreenRecorderService.start returned, status=${_recorder.status}');
      await _showIndicator(monitor);
      await _syncHotkeyRegistration();
    } catch (e, st) {
      // Was previously unhandled here — any throw (ffmpeg spawn failure,
      // hotkey registration conflict, etc.) silently vanished and the
      // Record button appeared to do nothing at all.
      Log.e(_tag, 'startRecording failed', e, st);
      final cur = state.valueOrNull ?? s;
      state = AsyncData(cur.copyWith(error: 'Could not start recording: $e'));
    }
  }

  Future<void> togglePauseResume() async {
    final s = state.valueOrNull;
    if (s == null) return;
    try {
      if (s.status == RecordStatus.recording) {
        await _recorder.pause();
      } else if (s.status == RecordStatus.paused) {
        await _recorder.resume();
      }
    } catch (e, st) {
      Log.e(_tag, 'togglePauseResume failed', e, st);
      final cur = state.valueOrNull ?? s;
      state = AsyncData(cur.copyWith(error: 'Pause/resume failed: $e'));
    }
  }

  /// Called from the window-close handler — kills a live ffmpeg segment and
  /// deletes its temp job dir so nothing orphans on disk. No-op if idle.
  Future<void> cleanupForAppExit() async {
    await _recorderInstance?.cleanupOnShutdown();
  }

  Future<void> stopRecording() async {
    final s = state.valueOrNull;
    if (s == null || s.status == RecordStatus.idle) return;
    File? output;
    try {
      output = await _recorder.stop();
    } catch (e, st) {
      Log.e(_tag, 'stopRecording failed', e, st);
      final cur = state.valueOrNull ?? s;
      state = AsyncData(cur.copyWith(error: 'Could not finalize recording: $e'));
    } finally {
      // Crash-safe: the indicator is always hidden and hotkeys resynced
      // even if finalize (concat/mux) throws.
      await _hideIndicator();
      await _syncHotkeyRegistration();
    }
    if (output != null) appRouter.push('/video-studio', extra: output);
  }

  // ── Recording indicator (native, click-through overlay) ───────────────

  // Native channel calls must never block the recording flow — a stuck
  // platform-thread call (e.g. a native draw call that never reaches
  // result->Success()) previously hung startRecording() forever with no
  // error, since `await` has no built-in ceiling.
  static const _kIndicatorCallTimeout = Duration(seconds: 3);

  Future<void> _showIndicator(RecordTarget monitor) async {
    if (!Platform.isWindows) return;
    // Covers the full recorded area (border traces the monitor's edges,
    // status dot/text sit in its top-left corner) — not just a small pill.
    final x = monitor.physicalX;
    final y = monitor.physicalY;
    final w = monitor.physicalW;
    final h = monitor.physicalH;
    Log.d(_tag, 'showRecordingIndicator($x,$y,$w,$h)');
    try {
      final ok = await ref
          .read(nativeWindowChannelProvider)
          .showRecordingIndicator(x, y, w, h)
          .timeout(_kIndicatorCallTimeout);
      Log.d(_tag, 'showRecordingIndicator returned ok=$ok'
          ' (false = GDI+/window creation failed natively — indicator is not'
          ' actually visible even though the call did not throw)');
    } catch (e, st) {
      // Best-effort — a failed/timed-out indicator still leaves recording
      // running, the user just has no on-screen cue (hotkeys still work).
      Log.e(_tag, 'showRecordingIndicator failed', e, st);
    }
  }

  Future<void> _updateIndicator() async {
    if (!Platform.isWindows) return;
    final s = state.valueOrNull;
    if (s == null) return;
    try {
      await ref
          .read(nativeWindowChannelProvider)
          .updateRecordingIndicator(
            paused: s.status == RecordStatus.paused,
            elapsedMs: s.elapsed.inMilliseconds,
            maxMs: kMaxRecordSeconds * 1000,
            micOn: s.settings.captureMic,
            systemAudioOn: s.settings.captureSystemAudio,
          )
          .timeout(_kIndicatorCallTimeout);
    } catch (e, st) {
      Log.e(_tag, 'updateRecordingIndicator failed', e, st);
    }
  }

  Future<void> _hideIndicator() async {
    if (!Platform.isWindows) return;
    try {
      await ref
          .read(nativeWindowChannelProvider)
          .hideRecordingIndicator()
          .timeout(_kIndicatorCallTimeout);
    } catch (e, st) {
      Log.e(_tag, 'hideRecordingIndicator failed', e, st);
    }
  }
}

enum HotkeySlot { start, pauseResume, stop }

final recordControllerProvider =
    AsyncNotifierProvider<RecordController, RecordState>(RecordController.new);
