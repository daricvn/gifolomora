import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart' show Display;

import '../../../core/services/record/record_target.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/glass_container.dart';

/// One glass card per display; a proportional mini-sketch of the virtual
/// desktop layout when there's more than one, or a plain read-only card for
/// a single monitor (selection disabled — there's nothing to choose).
class MonitorCard extends StatelessWidget {
  const MonitorCard({
    super.key,
    required this.monitors,
    required this.rawDisplays,
    required this.selected,
    required this.onSelect,
  });

  final List<RecordTarget> monitors;
  final List<Display> rawDisplays;
  final RecordTarget? selected;
  final ValueChanged<RecordTarget> onSelect;

  @override
  Widget build(BuildContext context) {
    if (monitors.isEmpty) {
      return GlassContainer(
        borderRadius: 20,
        child: Row(
          children: [
            const Icon(Icons.desktop_access_disabled_rounded,
                color: AppColors.textLo, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No displays detected',
                style: const TextStyle(color: AppColors.textLo, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final single = monitors.length == 1;

    return GlassContainer(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_rounded,
                  color: AppColors.accentB, size: 20),
              const SizedBox(width: 10),
              Text(
                single ? 'Display' : 'Select a display',
                style: const TextStyle(
                    color: AppColors.textHi,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (!single) ...[
            const SizedBox(height: 14),
            _LayoutSketch(
              monitors: monitors,
              rawDisplays: rawDisplays,
              selected: selected,
              onSelect: onSelect,
            ),
          ],
          const SizedBox(height: 14),
          for (final m in monitors)
            _MonitorRow(
              target: m,
              selected: single || m.name == selected?.name,
              selectable: !single,
              onTap: () => onSelect(m),
            ),
        ],
      ),
    );
  }
}

class _LayoutSketch extends StatelessWidget {
  const _LayoutSketch({
    required this.monitors,
    required this.rawDisplays,
    required this.selected,
    required this.onSelect,
  });

  final List<RecordTarget> monitors;
  final List<Display> rawDisplays;
  final RecordTarget? selected;
  final ValueChanged<RecordTarget> onSelect;

  @override
  Widget build(BuildContext context) {
    if (rawDisplays.length != monitors.length) return const SizedBox.shrink();

    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final d in rawDisplays) {
      final pos = d.visiblePosition ?? Offset.zero;
      final size = d.visibleSize ?? const Size(1920, 1080);
      minX = math.min(minX, pos.dx);
      minY = math.min(minY, pos.dy);
      maxX = math.max(maxX, pos.dx + size.width);
      maxY = math.max(maxY, pos.dy + size.height);
    }
    final totalW = maxX - minX;
    final totalH = maxY - minY;
    if (totalW <= 0 || totalH <= 0) return const SizedBox.shrink();

    const sketchHeight = 84.0;
    return LayoutBuilder(builder: (context, constraints) {
      final scale =
          math.min(constraints.maxWidth / totalW, sketchHeight / totalH);
      return Center(
        child: SizedBox(
          width: totalW * scale,
          height: totalH * scale,
          child: Stack(
            children: [
              for (var i = 0; i < monitors.length; i++)
                Builder(builder: (context) {
                  final pos = rawDisplays[i].visiblePosition ?? Offset.zero;
                  final size =
                      rawDisplays[i].visibleSize ?? const Size(1920, 1080);
                  final isSelected = monitors[i].name == selected?.name;
                  return Positioned(
                    left: (pos.dx - minX) * scale,
                    top: (pos.dy - minY) * scale,
                    width: size.width * scale,
                    height: size.height * scale,
                    child: GestureDetector(
                      onTap: () => onSelect(monitors[i]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentA.withValues(alpha: 0.35)
                              : AppColors.glassTint,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accentA
                                : AppColors.glassStroke,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                                color: AppColors.textHi,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    });
  }
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({
    required this.target,
    required this.selected,
    required this.selectable,
    required this.onTap,
  });

  final RecordTarget target;
  final bool selected;
  final bool selectable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.accentA.withValues(alpha: 0.15) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? AppColors.accentA.withValues(alpha: 0.5)
              : AppColors.glassStroke,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? AppColors.accentB : AppColors.textLo,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(target.label,
                    style: const TextStyle(
                        color: AppColors.textHi,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text('${target.physicalW}×${target.physicalH}px',
                    style: const TextStyle(
                        color: AppColors.textLo, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
    if (!selectable) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}
