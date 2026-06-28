import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blur,
    this.opacity = 0.10,
    this.borderRadius = 24,
    this.border = true,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.tint = Colors.white,
  });

  final Widget child;
  final double? blur;
  final double opacity;
  final double borderRadius;
  final bool border;
  final EdgeInsets padding;
  final Gradient? gradient;
  final Color tint;

  double get _effectiveBlur {
    if (blur != null) return blur!;
    // Lower sigma on Android to reduce jank
    return (Platform.isAndroid || Platform.isIOS) ? 12 : 18;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final sigma = _effectiveBlur;

    final decoration = BoxDecoration(
      color: tint.withValues(alpha: opacity),
      borderRadius: radius,
      gradient: gradient,
      border: border
          ? Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ],
    );

    // sigma == 0 → flat mode: skip BackdropFilter entirely.
    // A BackdropFilter with sigma=0 still forces a save layer on every frame.
    if (sigma <= 0) {
      return RepaintBoundary(
        child: ClipRRect(
          borderRadius: radius,
          child: Container(padding: padding, decoration: decoration, child: child),
        ),
      );
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Container(padding: padding, decoration: decoration, child: child),
        ),
      ),
    );
  }
}
