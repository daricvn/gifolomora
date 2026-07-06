import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../core/services/files/temp_file_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/glass/glass_button.dart';
import '../core/widgets/glass/glass_container.dart';
import '../features/screen_record/controller/record_controller.dart';
import '../router/app_router.dart';

class GifolomoraApp extends ConsumerStatefulWidget {
  const GifolomoraApp({super.key});

  @override
  ConsumerState<GifolomoraApp> createState() => _GifolomoraAppState();
}

class _GifolomoraAppState extends ConsumerState<GifolomoraApp>
    with WindowListener {
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

  // Intercepted via setPreventClose — a bare windowManager.close() would tear
  // the window (and process) down before Flutter/Riverpod dispose lifecycle
  // runs, orphaning a live ffmpeg segment and its temp job dir on disk.
  @override
  void onWindowClose() async {
    // .uri.path is stale for pushed routes (go_router only updates it on
    // go()/replace(), not push()) — matches.last.matchedLocation reflects
    // the actual top route regardless of how it was navigated to.
    final location = appRouter.routerDelegate.currentConfiguration.matches.last
        .matchedLocation;

    if (!_noConfirmExitRoutes.contains(location)) {
      final confirmed = await showDialog<bool>(
        context: rootNavigatorKey.currentContext!,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          child: GlassContainer(
            borderRadius: 0,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exit Gifolomora?',
                  style: TextStyle(
                    color: AppColors.textHi,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You have unsaved work in progress. Are you sure you want to exit?',
                  style: TextStyle(color: AppColors.textLo, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GlassButton(
                      label: 'Cancel',
                      borderRadius: 12,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 12),
                    GlassButton(
                      label: 'Exit',
                      isPrimary: true,
                      borderRadius: 12,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true) return;
    }

    final s = ref.read(recordControllerProvider).valueOrNull;
    await ref.read(recordControllerProvider.notifier).cleanupForAppExit();
    if (s?.settings.deleteTempOnExit ?? true) {
      await TempFileService().wipeAll();
    }
    await windowManager.destroy();
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
