import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../../l10n/app_localizations.dart';

class FrameStrip extends StatelessWidget {
  const FrameStrip({
    super.key,
    required this.frames,
    required this.onRemove,
    required this.onReorder,
    required this.onAddMore,
  });

  final List<File> frames;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAddMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                frames.length == 1
                    ? l10n.imagesFrameCountOne(frames.length)
                    : l10n.imagesFrameCountOther(frames.length),
                style: const TextStyle(
                  color: AppColors.textHi,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: onAddMore,
                icon: const Icon(Icons.add, size: 16, color: AppColors.accentB),
                label: Text(
                  l10n.imagesAddMore,
                  style: const TextStyle(color: AppColors.accentB, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: frames.length,
              onReorderItem: onReorder,
              proxyDecorator: (child, index, animation) => child,
              itemBuilder: (context, index) {
                return _FrameTile(
                  key: ValueKey(frames[index].path),
                  file: frames[index],
                  index: index,
                  onRemove: () => onRemove(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameTile extends StatelessWidget {
  const _FrameTile({
    super.key,
    required this.file,
    required this.index,
    required this.onRemove,
  });

  final File file;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              file,
              width: 72,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 72,
                height: 90,
                color: AppColors.bg1,
                child: const Icon(
                  Icons.broken_image_rounded,
                  color: AppColors.textLo,
                  size: 24,
                ),
              ),
            ),
          ),
          Positioned(
            top: 3,
            left: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
