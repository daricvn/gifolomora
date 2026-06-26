import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../router/app_router.dart';

class GifolomoraApp extends ConsumerWidget {
  const GifolomoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Gifolomora',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
