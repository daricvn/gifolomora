import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'glass_button.dart';
import 'glass_container.dart';

/// Shared confirm/cancel prompt shell — same glass look as the app-exit
/// dialog, so every "are you sure?" in the app reads as one system.
class GlassConfirmDialog {
  GlassConfirmDialog._();

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String cancelLabel = 'Cancel',
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: IntrinsicWidth(
            child: GlassContainer(
              borderRadius: 0,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textHi,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(color: AppColors.textLo, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GlassButton(
                        label: cancelLabel,
                        borderRadius: 12,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: 12),
                      GlassButton(
                        label: confirmLabel,
                        isPrimary: true,
                        isDestructive: isDestructive,
                        borderRadius: 12,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
