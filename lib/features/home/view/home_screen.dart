import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/common/entrance.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/common/section_header.dart';
import '../data/tool_catalog.dart';
import '../widgets/home_hero.dart';
import '../widgets/featured_tool_card.dart';
import '../widgets/tool_card.dart';
import '../widgets/recents_strip.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isDragHovering = false;
  String? _version;

  static const _kSupportedExts = ['mp4', 'mov', 'mkv', 'avi', 'webm', 'gif'];

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  void _handleDrop(DropDoneDetails details) {
    if (details.files.isEmpty) return;
    final file = details.files.first;
    final ext = file.path.split('.').last.toLowerCase();
    if (_kSupportedExts.contains(ext)) {
      context.push('/video-studio', extra: File(file.path));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('.$ext is not supported. Drop a video or GIF.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 700;
    final topPad = MediaQuery.of(context).padding.top + 64 + 12;

    final maxContentWidth = isWide ? 880.0 : double.infinity;
    final featuredCols = isWide ? 2 : 1;
    final refineCols = isWide ? 4 : 2;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragHovering = true),
      onDragExited: (_) => setState(() => _isDragHovering = false),
      onDragDone: (details) {
        setState(() => _isDragHovering = false);
        _handleDrop(details);
      },
      child: GradientScaffold(
        appBar: GlassAppBar(
          title: 'Gifolomora',
          leading: const _BrandLockup(),
          actions: [
            IconButton(
              onPressed: () => context.push('/about'),
              icon: const Icon(Icons.info_outline_rounded,
                  color: AppColors.textLo, size: 22),
              tooltip: 'About',
            ),
          ],
        ),
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, topPad, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Entrance(child: HomeHero(isWide: isWide)),
                      ),
                    ),

                    // ── Recents ────────────────────────────────────────────
                    const SliverToBoxAdapter(
                      child: Entrance(
                        delay: Duration(milliseconds: 60),
                        child: RecentsStrip(),
                      ),
                    ),

                    // ── Create ─────────────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
                      sliver: const SliverToBoxAdapter(
                        child: Entrance(
                          delay: Duration(milliseconds: 100),
                          child: SectionHeader(
                            overline: 'Start here',
                            title: 'Create a GIF',
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: featuredCols,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 118,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final entry = createTools[i];
                            return Entrance(
                              delay: Duration(milliseconds: 140 + 50 * i),
                              child: FeaturedToolCard(
                                entry: entry,
                                onTap: () => context.push(entry.route),
                              ),
                            );
                          },
                          childCount: createTools.length,
                        ),
                      ),
                    ),

                    // ── Refine ─────────────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
                      sliver: const SliverToBoxAdapter(
                        child: Entrance(
                          delay: Duration(milliseconds: 200),
                          child: SectionHeader(
                            overline: 'Toolkit',
                            title: 'Edit & optimize',
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: refineCols,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: isWide ? 1.05 : 0.92,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final entry = refineTools[i];
                            return Entrance(
                              delay: Duration(milliseconds: 240 + 40 * i),
                              child: ToolCard(
                                entry: entry,
                                onTap: () => context.push(entry.route),
                              ),
                            );
                          },
                          childCount: refineTools.length,
                        ),
                      ),
                    ),

                    const SliverPadding(padding: EdgeInsets.only(bottom: 28)),
                  ],
                ),
              ),
            ),

            // ── Version badge ───────────────────────────────────────────────
            if (_version != null)
              Positioned(
                left: 16,
                bottom: 12,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.5,
                    child: Text(
                      'v$_version',
                      style: const TextStyle(
                        color: AppColors.textLo,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Drag-hover overlay ──────────────────────────────────────────
            if (_isDragHovering)
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Container(
                        // Dim the page behind the drop panel.
                        color: AppColors.bg0.withValues(alpha: 0.6 * t),
                        padding: const EdgeInsets.all(16),
                        child: Transform.scale(
                          scale: 0.98 + 0.02 * t,
                          child: child,
                        ),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.accentB.withValues(alpha: 0.08),
                        border: Border.all(
                          color: AppColors.accentB.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.file_download_rounded,
                                color: AppColors.accentB, size: 64),
                            SizedBox(height: 12),
                            Text(
                              'Drop video or GIF',
                              style: TextStyle(
                                color: AppColors.textHi,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/app.png',
            width: 30,
            height: 30,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 11),
          const Text(
            'Gifolomora',
            style: TextStyle(
              color: AppColors.textHi,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
