import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/view/home_screen.dart';
import '../features/about/view/about_screen.dart';
import '../features/images_to_gif/view/images_to_gif_screen.dart';
import '../features/video_studio/view/video_studio_screen.dart';
import '../features/resize/view/resize_screen.dart';
import '../features/crop/view/crop_screen.dart';
import '../features/optimize/view/optimize_screen.dart';
import '../features/text_overlay/view/text_overlay_screen.dart';
import '../features/effects/view/effects_screen.dart';
import '../features/screen_record/view/screen_record_screen.dart';
import '../features/webm_converter/view/webm_converter_screen.dart';

Page<void> _slide(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurveTween(curve: Curves.easeOut).animate(animation);
        final slide = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(CurveTween(curve: Curves.easeOut).animate(animation));
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => const HomeScreen(),
    ),
    GoRoute(
      path: '/about',
      pageBuilder: (context, state) => _slide(state, const AboutScreen()),
    ),
    GoRoute(
      path: '/video-studio',
      pageBuilder: (context, state) => _slide(
        state,
        VideoStudioScreen(initialFile: state.extra as File?),
      ),
    ),
    GoRoute(
      path: '/images-to-gif',
      pageBuilder: (context, state) =>
          _slide(state, const ImagesToGifScreen()),
    ),
    GoRoute(
      path: '/resize',
      pageBuilder: (context, state) => _slide(state, const ResizeScreen()),
    ),
    GoRoute(
      path: '/crop',
      pageBuilder: (context, state) => _slide(state, const CropScreen()),
    ),
    GoRoute(
      path: '/optimize',
      pageBuilder: (context, state) =>
          _slide(state, const OptimizeScreen()),
    ),
    GoRoute(
      path: '/text-overlay',
      pageBuilder: (context, state) =>
          _slide(state, const TextOverlayScreen()),
    ),
    GoRoute(
      path: '/effects',
      pageBuilder: (context, state) =>
          _slide(state, const EffectsScreen()),
    ),
    GoRoute(
      path: '/screen-record',
      redirect: (context, state) => Platform.isWindows ? null : '/',
      pageBuilder: (context, state) =>
          _slide(state, const ScreenRecordScreen()),
    ),
    GoRoute(
      path: '/to-webm',
      pageBuilder: (context, state) =>
          _slide(state, const WebmConverterScreen()),
    ),
  ],
);
