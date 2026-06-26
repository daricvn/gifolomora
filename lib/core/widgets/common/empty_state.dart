import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../glass/glass_container.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.action,
    this.actionLabel,
  });

  final IconData icon;
  final String message;
  final String? subtitle;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textLo, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textHi,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textLo, fontSize: 13),
            ),
          ],
          if (action != null && actionLabel != null) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: action,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentB,
                side: const BorderSide(color: AppColors.accentB),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
