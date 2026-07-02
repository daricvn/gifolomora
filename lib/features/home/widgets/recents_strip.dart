import 'dart:io';
import 'dart:ui' as ui;
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

class _RecentCard extends StatefulWidget {
  const _RecentCard({required this.item});
  final RecentExport item;

  @override
  State<_RecentCard> createState() => _RecentCardState();
}

class _RecentCardState extends State<_RecentCard> {
  bool _hovered = false;

  String get _fileName => widget.item.path.split(Platform.pathSeparator).last;

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
      width: 210,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => context.push(widget.item.toolRoute),
          child: GlassContainer(
            blur: 0.0,
            borderRadius: 12,
            borderColor: _hovered
                ? AppColors.accentB.withValues(alpha: 0.5)
                : null,
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumb(path: widget.item.path, animate: _hovered),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.toolName,
                        style: const TextStyle(
                          color: AppColors.accentB,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
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
                        _timeAgo(widget.item.timestamp),
                        style: const TextStyle(
                          color: AppColors.textLo,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// GIF thumbnail: static first frame normally, live animation on hover.
/// Non-GIF or unreadable files fall back to an icon tile.
class _Thumb extends StatefulWidget {
  const _Thumb({required this.path, required this.animate});
  final String path;
  final bool animate;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  ui.Image? _firstFrame;
  bool _failed = false;

  bool get _isGif => widget.path.toLowerCase().endsWith('.gif');

  @override
  void initState() {
    super.initState();
    _decodeFirstFrame();
  }

  Future<void> _decodeFirstFrame() async {
    if (!_isGif) return;
    try {
      final bytes = await File(widget.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 140);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (mounted) {
        setState(() => _firstFrame = frame.image);
      } else {
        frame.image.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _firstFrame?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (!_isGif || _failed || _firstFrame == null) {
      child = const Icon(
        Icons.gif_box_rounded,
        color: AppColors.accentB,
        size: 26,
      );
    } else if (widget.animate) {
      child = Image.file(
        File(widget.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(
          Icons.gif_box_rounded,
          color: AppColors.accentB,
          size: 26,
        ),
      );
    } else {
      child = RawImage(image: _firstFrame, fit: BoxFit.cover);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 66,
        height: 66,
        color: Colors.white.withValues(alpha: 0.05),
        child: child,
      ),
    );
  }
}
