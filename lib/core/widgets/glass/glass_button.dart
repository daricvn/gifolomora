import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_gradients.dart';
import 'glass_container.dart';

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = false,
    this.isDestructive = false,
    this.width,
    this.borderRadius = 12,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool isDestructive;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.textHi),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textHi,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );

    if (isPrimary) {
      final glowColor =
          isDestructive ? Colors.redAccent : AppColors.accentA;
      return SizedBox(
        width: width,
        child: Container(
          decoration: BoxDecoration(
            gradient: isDestructive
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.redAccent, Color(0xFFB71C1C)],
                  )
                : AppGradients.primaryButton,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(borderRadius),
              splashColor: Colors.white.withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: content,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
