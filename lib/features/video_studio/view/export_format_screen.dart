import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../controller/video_studio_controller.dart';

/// Compact page pushed before Export Video runs (PLAN.md §8): pick MP4 or
/// WebM, then the caller runs the chosen pipeline. Pops with the chosen
/// [ExportVideoFormat], or null if the user backs out.
class ExportFormatScreen extends StatefulWidget {
  const ExportFormatScreen({super.key, required this.initial, this.originalExt});

  final ExportVideoFormat initial;

  /// Source file extension when the video is untouched — shows the
  /// "Original" save-as-is card, pre-selected. Null = video was modified
  /// (or effects pending), card hidden.
  final String? originalExt;

  @override
  State<ExportFormatScreen> createState() => _ExportFormatScreenState();
}

class _ExportFormatScreenState extends State<ExportFormatScreen> {
  // Untouched video defaults to the as-is save; a persisted `original` pick
  // falls back to mp4 when the card is hidden this time.
  late ExportVideoFormat _selected = widget.originalExt != null
      ? ExportVideoFormat.original
      : (widget.initial == ExportVideoFormat.original
          ? ExportVideoFormat.mp4
          : widget.initial);

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: GlassAppBar(
        title: 'Export Format',
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textHi, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16 + MediaQuery.of(context).padding.top + 64,
          16,
          32,
        ),
        children: [
          if (widget.originalExt != null) ...[
            _FormatCard(
              title: 'Original (${widget.originalExt!.toUpperCase()})',
              subtitle: 'Save as-is · no re-encode · fastest',
              icon: Icons.file_copy_rounded,
              selected: _selected == ExportVideoFormat.original,
              onTap: () =>
                  setState(() => _selected = ExportVideoFormat.original),
            ),
            const SizedBox(height: 12),
          ],
          _FormatCard(
            title: 'MP4',
            subtitle: 'H.264 · best compatibility · hardware-accelerated',
            icon: Icons.videocam_rounded,
            selected: _selected == ExportVideoFormat.mp4,
            onTap: () => setState(() => _selected = ExportVideoFormat.mp4),
          ),
          const SizedBox(height: 12),
          _FormatCard(
            title: 'WebM',
            subtitle: 'VP9 · smaller files · web-friendly',
            icon: Icons.public_rounded,
            selected: _selected == ExportVideoFormat.webm,
            onTap: () => setState(() => _selected = ExportVideoFormat.webm),
          ),
          const SizedBox(height: 20),
          const Text(
            'You\'ll be asked to choose where to save the file.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLo, fontSize: 13),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(_selected),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.primaryButton,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Export',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
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

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 18,
        borderColor: selected ? AppColors.accentA : null,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accentA.withValues(alpha: 0.2)
                    : AppColors.glassTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: selected ? AppColors.accentB : AppColors.textLo,
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: selected
                              ? AppColors.accentB
                              : AppColors.textHi,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textLo, fontSize: 12)),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.accentB : AppColors.textLo,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
