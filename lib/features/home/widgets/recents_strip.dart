import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/recents/recents_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common/section_header.dart';
import '../../../core/widgets/glass/glass_container.dart';

class RecentsStrip extends ConsumerWidget {
  const RecentsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentsProvider).valueOrNull ?? [];
    if (recents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 4, 14),
          child: SectionHeader(
            overline: 'History',
            title: 'Recent exports',
            trailing: TextButton(
              onPressed: () => ref.read(recentsProvider.notifier).clear(),
              child: const Text(
                'Clear',
                style: TextStyle(color: AppColors.textLo, fontSize: 13),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: recents.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _RecentCard(item: recents[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.item});
  final RecentExport item;

  String get _fileName =>
      item.path.split(Platform.pathSeparator).last;

  String _timeAgo(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 162,
      child: GestureDetector(
        onTap: () => context.push(item.toolRoute),
        child: GlassContainer(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gif_box_rounded,
                      color: AppColors.accentB, size: 16),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.toolName,
                      style: const TextStyle(
                        color: AppColors.accentB,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _fileName,
                style: const TextStyle(
                  color: AppColors.textHi,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                _timeAgo(item.timestamp),
                style: const TextStyle(color: AppColors.textLo, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
