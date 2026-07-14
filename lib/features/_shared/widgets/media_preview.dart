import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../../l10n/app_localizations.dart';

/// Displays a GIF or image file using Flutter's native decoder.
class MediaPreview extends StatelessWidget {
  const MediaPreview({
    super.key,
    required this.file,
    this.label,
    this.maxHeight = 300,
  });

  final File file;
  final String? label;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: const TextStyle(
                color: AppColors.textLo,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Image.file(
                file,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_rounded,
                          color: AppColors.textLo, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.sharedPreviewUnavailable,
                        style: const TextStyle(
                            color: AppColors.textLo, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
