import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../core/theme/app_theme.dart';
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

  // Intercepted via setPreventClose — a bare windowManager.close() would tear
  // the window (and process) down before Flutter/Riverpod dispose lifecycle
  // runs, orphaning a live ffmpeg segment and its temp job dir on disk.
  @override
  void onWindowClose() async {
    await ref.read(recordControllerProvider.notifier).cleanupForAppExit();
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
