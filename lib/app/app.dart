import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import '../core/services/files/temp_file_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/glass/glass_confirm_dialog.dart';
import '../features/screen_record/controller/record_controller.dart';
import '../router/app_router.dart';

class GifolomoraApp extends ConsumerStatefulWidget {
  const GifolomoraApp({super.key});

  @override
  ConsumerState<GifolomoraApp> createState() => _GifolomoraAppState();
}

class _GifolomoraAppState extends ConsumerState<GifolomoraApp>
    with WindowListener {
  // Set the instant onWindowClose starts — guards against a second
  // WM_CLOSE (e.g. X mashed again) re-entering mid-dialog/mid-cleanup and
  // stacking a second confirm dialog or a second destroy() call.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  static const _noConfirmExitRoutes = {'/', '/about', '/screen-record'};

  // Users have hit an intermittent "app freezes for a while before exiting"
  // bug that doesn't reproduce on demand. This appends a timestamped line
  // per exit stage to %TEMP%\gifolomora_exit.log — whichever stage is last
  // on disk after a hang names where it stuck. Uses Directory.systemTemp
  // (not TempFileService's base dir) because wipeAll() below deletes that
  // whole directory, which would erase the log before it could be read.
  static File get _exitLogFile =>
      File(p.join(Directory.systemTemp.path, 'gifolomora_exit.log'));

  Future<void> _logExitStep(String step) async {
    try {
      await _exitLogFile.writeAsString(
        '${DateTime.now().toIso8601String()} $step\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  void _logExitStepSync(String step) {
    try {
      _exitLogFile.writeAsStringSync(
        '${DateTime.now().toIso8601String()} $step\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  // Intercepted via setPreventClose — a bare windowManager.close() would tear
  // the window (and process) down before Flutter/Riverpod dispose lifecycle
  // runs, orphaning a live ffmpeg segment and its temp job dir on disk.
  @override
  void onWindowClose() async {
    if (_closing) return;
    _closing = true;

    // .uri.path is stale for pushed routes (go_router only updates it on
    // go()/replace(), not push()) — matches.last.matchedLocation reflects
    // the actual top route regardless of how it was navigated to.
    final location = appRouter.routerDelegate.currentConfiguration.matches.last
        .matchedLocation;
    await _logExitStep('onWindowClose start, route=$location');

    if (!_noConfirmExitRoutes.contains(location)) {
      final confirmed = await GlassConfirmDialog.show(
        rootNavigatorKey.currentContext!,
        title: 'Exit Gifolomora?',
        message:
            'You have unsaved work in progress. Are you sure you want to exit?',
        confirmLabel: 'Exit',
      );
      if (confirmed != true) {
        _closing = false;
        await _logExitStep('exit cancelled by user');
        return;
      }
    }

    // Hide the window before cleanup/teardown so any hang in the steps below
    // (native cleanup, temp wipe, engine shutdown) is invisible to the user
    // instead of reading as a frozen "Not Responding" window.
    await windowManager.hide();
    await _logExitStep('window hidden, starting cleanup');

    final s = ref.read(recordControllerProvider).valueOrNull;
    await ref.read(recordControllerProvider.notifier).cleanupForAppExit();
    await _logExitStep('recorder cleanup done');
    if (s?.settings.deleteTempOnExit ?? true) {
      await TempFileService().wipeAll();
    }
    await _logExitStep('wipeAll done, destroying window');

    // Watchdog: if windowManager.destroy() (native engine/window teardown)
    // hangs, force the process down rather than leave it stuck forever.
    // Cleanup already ran above, so this is safe even mid-teardown.
    final watchdog = Timer(const Duration(seconds: 4), () {
      _logExitStepSync('watchdog fired, forcing exit');
      exit(0);
    });
    await windowManager.destroy();
    watchdog.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Gifolomora',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
