import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/glass_card.dart';
import '../data/tool_catalog.dart';

/// Large, horizontal hero card for primary "Create" tools. Carries an accent
/// wash and a leading gradient icon tile so the entry points read as the
/// headline actions, distinct from the compact refine grid.
class FeaturedToolCard extends StatefulWidget {
  const FeaturedToolCard({super.key, required this.entry, required this.onTap});

  final ToolEntry entry;
  final VoidCallback onTap;

  @override
  State<FeaturedToolCard> createState() => _FeaturedToolCardState();
}

class _FeaturedToolCardState extends State<FeaturedToolCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return GlassCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(18),
      flat: true,
      hoverAccent: entry.accentColor,
      onHoverChanged: (h) => setState(() => _hovered = h),
      child: Stack(
        children: [
          // Accent wash bleeding from the leading edge.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    entry.accentColor.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.65],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _IconTile(icon: entry.icon, color: entry.accentColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.label,
                      style: const TextStyle(
                        color: AppColors.textHi,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.description,
                      style: const TextStyle(
                        color: AppColors.textLo,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSlide(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                offset: _hovered ? const Offset(0.2, 0) : Offset.zero,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: _hovered
                      ? entry.accentColor
                      : AppColors.textLo.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
