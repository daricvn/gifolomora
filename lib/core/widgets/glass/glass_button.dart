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
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;
  final double? width;

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
      return SizedBox(
        width: width,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppGradients.primaryButton,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentA.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        borderRadius: 12,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: content,
          ),
        ),
      ),
    );
  }
}
