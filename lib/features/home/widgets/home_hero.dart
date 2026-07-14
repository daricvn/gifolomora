import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Premium masthead built around the brand banner. The banner artwork already
/// carries the wordmark + tagline, so instead of a glass card we let it sit
/// full-bleed and dissolve its edges into the animated background — the
/// rectangular boundary disappears so it reads as part of the page, not a
/// pasted-on image.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key, required this.isWide});
  final bool isWide;

  // Native banner aspect ratio (1023 x 415).
  static const double _bannerAspect = 1023 / 415;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: _bannerAspect,
          child: _DissolvedBanner(),
        ),
        if (Platform.isWindows) ...[
          SizedBox(height: isWide ? 8 : 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: AppColors.glassStroke, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.file_upload_outlined,
                    size: 16, color: AppColors.textLo),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.homeDragDropHint,
                  style: const TextStyle(color: AppColors.textLo, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Banner image with all four edges faded to transparent so it melts into the
/// dark gradient + blobs behind it. Two stacked [ShaderMask]s (vertical then
/// horizontal, both [BlendMode.dstIn]) multiply their alpha, giving a soft
/// vignette that also softens the corners.
class _DissolvedBanner extends StatelessWidget {
  const _DissolvedBanner();

  @override
  Widget build(BuildContext context) {
    // Horizontal fade: gentle, so the left-aligned wordmark isn't clipped.
    const horizontal = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [0.0, 0.05, 0.95, 1.0],
    );
    // Vertical fade: stronger at the bottom so the banner bleeds into the
    // content that follows.
    const vertical = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [0.0, 0.08, 0.80, 1.0],
    );

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: vertical.createShader,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: horizontal.createShader,
        child: Image.asset(
          'assets/banner.gif',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
