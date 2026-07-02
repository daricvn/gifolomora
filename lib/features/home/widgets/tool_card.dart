import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/glass_card.dart';
import '../data/tool_catalog.dart';

/// Compact card for the "refine" grid. Lighter weight than [FeaturedToolCard]:
/// a soft accent-tinted icon chip keeps these secondary to the hero row.
class ToolCard extends StatelessWidget {
  const ToolCard({super.key, required this.entry, required this.onTap});

  final ToolEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      flat: true,
      hoverAccent: entry.accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconChip(icon: entry.icon, color: entry.accentColor),
          const SizedBox(height: 14),
          Text(
            entry.label,
            style: const TextStyle(
              color: AppColors.textHi,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            entry.description,
            style: const TextStyle(
              color: AppColors.textLo,
              fontSize: 11.5,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}
