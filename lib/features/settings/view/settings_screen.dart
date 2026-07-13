import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';

/// App-wide preferences. Currently Windows-only (the router redirects the
/// route away elsewhere) since its single option targets the desktop
/// video-preview renderer.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top + 64 + 24;
    final settings = ref.watch(appSettingsProvider).valueOrNull;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: 'Settings',
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              iconSize: 20,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textHi,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, 40),
        children: [
          GlassContainer(
            borderRadius: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Software preview rendering',
                        style: TextStyle(
                          color: AppColors.textHi,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Fixes rare black flickering in the Video Studio '
                        'preview on some GPUs. Uses more CPU and caps the '
                        'preview at 1080p. Exports are never affected. '
                        'Takes effect the next time you open the editor.',
                        style: TextStyle(
                          color: AppColors.textLo,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: settings?.softwareVideoPreview ?? false,
                  activeThumbColor: AppColors.accentB,
                  // Disabled (null) until prefs load so a tap can't race the
                  // initial value.
                  onChanged: settings == null
                      ? null
                      : (v) => ref
                          .read(appSettingsProvider.notifier)
                          .setSoftwareVideoPreview(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
