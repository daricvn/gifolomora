import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/common/section_header.dart';
import '../data/tool_catalog.dart';
import '../widgets/home_hero.dart';
import '../widgets/featured_tool_card.dart';
import '../widgets/tool_card.dart';
import '../widgets/recents_strip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 700;
    final topPad = MediaQuery.of(context).padding.top + 64 + 12;

    final maxContentWidth = isWide ? 880.0 : double.infinity;
    final featuredCols = isWide ? 2 : 1;
    final refineCols = isWide ? 4 : 2;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: 'Gifolomora',
        leading: const _BrandLockup(),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune_rounded,
                color: AppColors.textLo, size: 22),
            tooltip: 'Settings',
          ),
          IconButton(
            onPressed: () => context.push('/about'),
            icon: const Icon(Icons.info_outline_rounded,
                color: AppColors.textLo, size: 22),
            tooltip: 'About',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, topPad, 16, 0),
                sliver: SliverToBoxAdapter(child: HomeHero(isWide: isWide)),
              ),

              // ── Recents ─────────────────────────────────────────────────
              const SliverToBoxAdapter(child: RecentsStrip()),

              // ── Create ──────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
                sliver: const SliverToBoxAdapter(
                  child: SectionHeader(
                    overline: 'Start here',
                    title: 'Create a GIF',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: featuredCols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 118,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final entry = createTools[i];
                      return FeaturedToolCard(
                        entry: entry,
                        onTap: () => context.push(entry.route),
                      );
                    },
                    childCount: createTools.length,
                  ),
                ),
              ),

              // ── Refine ──────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
                sliver: const SliverToBoxAdapter(
                  child: SectionHeader(
                    overline: 'Toolkit',
                    title: 'Edit & optimize',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: refineCols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: isWide ? 1.05 : 0.92,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final entry = refineTools[i];
                      return ToolCard(
                        entry: entry,
                        onTap: () => context.push(entry.route),
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
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accentA, AppColors.accentB],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentA.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.gif_box_rounded,
                color: Colors.white, size: 19),
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
