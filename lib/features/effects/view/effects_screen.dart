import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../_shared/widgets/export_bottom_sheet.dart';
import '../../_shared/widgets/file_drop_zone.dart';
import '../../_shared/widgets/media_preview.dart';
import '../../_shared/widgets/option_slider.dart';
import '../controller/effects_controller.dart';

class EffectsScreen extends ConsumerWidget {
  const EffectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(effectsControllerProvider).valueOrNull ?? const EffectsState();
    final ctrl = ref.read(effectsControllerProvider.notifier);

    Future<void> doExport() async {
      await ExportBottomSheet.show(
        context,
        onExport: () async {
          final ok = await ctrl.exportGif();
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export cancelled')),
            );
          }
        },
      );
    }

    return GradientScaffold(
      appBar: GlassAppBar(
        title: 'Effects',
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textHi, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          state.outputGif != null ? _ExportBar(onExport: doExport) : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16 + MediaQuery.of(context).padding.top + 64,
          16,
          100,
        ),
        children: [
          // ── Step 1: Pick GIF ───────────────────────────────────────────
          const _SectionHeader(number: 1, title: 'Select GIF'),
          const SizedBox(height: 12),
          if (state.isProbing)
            GlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: const Column(children: [
                CircularProgressIndicator(color: AppColors.accentB),
                SizedBox(height: 12),
                Text('Reading file…',
                    style: TextStyle(color: AppColors.textLo, fontSize: 13)),
              ]),
            )
          else if (!state.hasInput)
            FileDropZone(
              hint: 'Tap to select GIF',
              icon: Icons.auto_awesome_rounded,
              allowedExtensions: const ['gif'],
              onFilesSelected: (files) {
                if (files.isNotEmpty) ctrl.setInput(files.first);
              },
            )
          else
            _FileInfoCard(
              name: state.inputFile!.path.split(Platform.pathSeparator).last,
              width: state.originalWidth,
              height: state.originalHeight,
              onClear: ctrl.clear,
            ),

          // ── Step 2: Effect Options ─────────────────────────────────────
          if (state.hasInput && !state.isProbing) ...[
            const SizedBox(height: 24),
            const _SectionHeader(number: 2, title: 'Effect'),
            const SizedBox(height: 12),
            GlassContainer(
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mode',
                      style: TextStyle(color: AppColors.textLo, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ModeCard(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Reverse',
                          subtitle: 'Play backwards',
                          selected: state.mode == EffectMode.reverse,
                          onTap: () => ctrl.setMode(EffectMode.reverse),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModeCard(
                          icon: Icons.speed_rounded,
                          label: 'Speed',
                          subtitle: 'Change tempo',
                          selected: state.mode == EffectMode.speed,
                          onTap: () => ctrl.setMode(EffectMode.speed),
                        ),
                      ),
                    ],
                  ),
                  if (state.mode == EffectMode.speed) ...[
                    const Divider(color: AppColors.glassStroke, height: 24),
                    OptionSlider(
                      label: 'Speed',
                      value: state.speedFactor,
                      min: 0.25,
                      max: 4.0,
                      divisions: 75,
                      displayValue: _speedLabel(state.speedFactor),
                      onChanged: (v) => ctrl.setSpeedFactor(
                        _snapSpeed(v),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('0.25×  slower',
                            style: TextStyle(
                                color: AppColors.textLo, fontSize: 11)),
                        const Text('4×  faster',
                            style: TextStyle(
                                color: AppColors.textLo, fontSize: 11)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Step 3: Preview / Generate ─────────────────────────────
            const SizedBox(height: 24),
            const _SectionHeader(number: 3, title: 'Preview'),
            const SizedBox(height: 12),
            if (state.isProcessing)
              _ProgressCard(
                  progress: state.progress?.fraction, onCancel: ctrl.cancel)
            else if (state.outputGif != null)
              Column(
                children: [
                  MediaPreview(file: state.outputGif!),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: ctrl.generate,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Regenerate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textLo,
                      side: const BorderSide(color: AppColors.glassStroke),
                    ),
                  ),
                ],
              )
            else
              _GenerateButton(onTap: ctrl.generate),

            if (state.error != null) ...[
              const SizedBox(height: 12),
              _ErrorCard(message: state.error!),
            ],
          ],
        ],
      ),
    );
  }

  String _speedLabel(double v) {
    if ((v - 1.0).abs() < 0.01) return '1× (original)';
    if (v < 1.0) return '${v.toStringAsFixed(2)}× (slower)';
    return '${v.toStringAsFixed(2)}× (faster)';
  }

  double _snapSpeed(double v) {
    const snaps = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0];
    for (final s in snaps) {
      if ((v - s).abs() < 0.12) return s;
    }
    return double.parse(v.toStringAsFixed(2));
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.number, required this.title});
  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: AppGradients.primaryButton,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$number',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: AppColors.textHi,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentA.withValues(alpha: 0.2)
              : AppColors.glassTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accentA : AppColors.glassStroke,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppColors.accentB : AppColors.textLo,
                size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? AppColors.accentB : AppColors.textHi,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textLo, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _FileInfoCard extends StatelessWidget {
  const _FileInfoCard({
    required this.name,
    required this.width,
    required this.height,
    required this.onClear,
  });
  final String name;
  final int width;
  final int height;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      child: Row(
        children: [
          const Icon(Icons.gif_box_rounded, color: AppColors.accentB, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.textHi,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (width > 0)
                  Text('$width×$height px',
                      style: const TextStyle(
                          color: AppColors.textLo, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textLo, size: 20),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({this.progress, required this.onCancel});
  final double? progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.glassStroke,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentB),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progress != null
                    ? '${(progress! * 100).round()}%  processing…'
                    : 'Processing…',
                style: const TextStyle(color: AppColors.textLo, fontSize: 13),
              ),
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.accentC)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onTap != null ? AppGradients.primaryButton : null,
          color: onTap == null ? AppColors.glassTint : null,
          borderRadius: BorderRadius.circular(16),
          border: onTap == null
              ? Border.all(color: AppColors.glassStroke)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: onTap != null ? Colors.white : AppColors.textLo,
                  size: 20),
              const SizedBox(width: 8),
              Text(
                'Generate Preview',
                style: TextStyle(
                  color: onTap != null ? Colors.white : AppColors.textLo,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 16,
      tint: Colors.red,
      opacity: 0.08,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({required this.onExport});
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        border:
            Border(top: BorderSide(color: AppColors.glassStroke, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.primaryButton,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ElevatedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.save_alt_rounded,
                size: 18, color: Colors.white),
            label: const Text('Export GIF',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}
