import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/glass/glass_container.dart';

/// Premium masthead: gradient brand wordmark, tagline, and a contextual
/// drag-drop hint on desktop. Anchors the page and sets the tone before the
/// tool sections.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key, required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 10,
      opacity: 0.08,
      padding: EdgeInsets.all(isWide ? 28 : 22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x22FFFFFF), Color(0x05FFFFFF)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassStroke, width: 1),
                  color: Colors.white.withValues(alpha: 0.04),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentB,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'GIF STUDIO',
                      style: TextStyle(
                        color: AppColors.textLo,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isWide ? 18 : 14),
          ShaderMask(
            shaderCallback: (rect) =>
                AppGradients.primaryButton.createShader(rect),
            child: Text(
              'Make a GIF\nthat looks the part.',
              style: TextStyle(
                color: Colors.white,
                fontSize: isWide ? 34 : 26,
                height: 1.12,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A premium GIF studio — convert, edit, and optimize, all powered by FFmpeg.',
            style: TextStyle(
              color: AppColors.textLo,
              fontSize: isWide ? 14 : 13,
              height: 1.4,
            ),
          ),
          if (Platform.isWindows) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: AppColors.glassStroke, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_upload_outlined,
                      size: 16, color: AppColors.textLo),
                  SizedBox(width: 8),
                  Text(
                    'Drag & drop a file anywhere to begin',
                    style: TextStyle(color: AppColors.textLo, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
