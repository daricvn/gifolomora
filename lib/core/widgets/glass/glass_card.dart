import 'package:flutter/material.dart';
import '../../theme/app_gradients.dart';
import 'glass_container.dart';

class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(16),
    this.blur,
    this.opacity = 0.10,
    this.flat = false,
    this.hoverAccent,
    this.onHoverChanged,
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

  /// Accent used for the hover border + glow. Defaults to white.
  final Color? hoverAccent;

  /// Notifies parents (e.g. to animate their own hover details).
  final ValueChanged<bool>? onHoverChanged;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHoverChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final accent = widget.hoverAccent ?? Colors.white;
    final hovering = interactive && _hovered;

    return MouseRegion(
      onEnter: interactive ? (_) => _setHovered(true) : null,
      onExit: interactive ? (_) => _setHovered(false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, hovering ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: hovering
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: GlassContainer(
          blur: widget.flat ? 0.0 : widget.blur,
          opacity: widget.opacity,
          borderRadius: widget.borderRadius,
          padding: EdgeInsets.zero,
          gradient: AppGradients.cardSheen,
          borderColor: hovering ? accent.withValues(alpha: 0.55) : null,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              splashColor: Colors.white.withValues(alpha: 0.08),
              highlightColor: Colors.white.withValues(alpha: 0.04),
              child: Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
