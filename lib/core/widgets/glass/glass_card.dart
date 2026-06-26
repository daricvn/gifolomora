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
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsets padding;
  final double? blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: blur,
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
