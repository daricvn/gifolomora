import 'package:flutter/material.dart';
import '../../theme/app_gradients.dart';
import 'glass_container.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(16),
    this.blur,
    this.opacity = 0.10,
    this.flat = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsets padding;
  final double? blur;
  final double opacity;
  /// When true, skips BackdropFilter. Use inside scroll views to avoid
  /// re-running the gaussian blur on every frame.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: flat ? 0.0 : blur,
      opacity: opacity,
      borderRadius: borderRadius,
      padding: EdgeInsets.zero,
      gradient: AppGradients.cardSheen,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
