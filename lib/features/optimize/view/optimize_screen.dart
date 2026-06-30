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
import '../controller/optimize_controller.dart';

class OptimizeScreen extends ConsumerWidget {
  const OptimizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(optimizeControllerProvider).valueOrNull ?? const OptimizeState();
    final ctrl = ref.read(optimizeControllerProvider.notifier);

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
        title: 'Optimize GIF',
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
              icon: Icons.compress_rounded,
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

          // ── Step 2: Options ────────────────────────────────────────────
          if (state.hasInput && !state.isProbing) ...[
            const SizedBox(height: 24),
            const _SectionHeader(number: 2, title: 'Compression'),
            const SizedBox(height: 12),
            GlassContainer(
              borderRadius: 20,
              child: Column(
                children: [
                  OptionSlider(
                    label: 'Colors',
                    value: state.colors.toDouble(),
                    min: 16,
                    max: 256,
                    divisions: 30,
                    unit: '',
                    displayValue: '${state.colors}',
                    onChanged: (v) => ctrl.setColors(v.round()),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: AppColors.glassStroke, height: 24),
                  OptionSlider(
                    label: 'Lossy',
                    value: state.lossy.toDouble(),
                    min: 0,
                    max: 80,
                    divisions: 16,
                    unit: '',
                    displayValue: state.lossy == 0 ? 'Off' : '${state.lossy}',
                    onChanged: (v) => ctrl.setLossy(v.round()),
                  ),
                  const Divider(color: AppColors.glassStroke, height: 24),
                  _FrameDropSelector(
                    value: state.frameDrop,
                    onChanged: ctrl.setFrameDrop,
                  ),
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

class _FrameDropSelector extends StatelessWidget {
  const _FrameDropSelector({required this.value, required this.onChanged});
  final int value; // 0 = keep all; 2/3/4 = remove 1 of every N
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    const presets = <(String, int)>[
      ('Keep all', 0),
      ('1 / 4', 4),
      ('1 / 3', 3),
      ('1 / 2', 2),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('Remove frames',
              style: TextStyle(
                  color: AppColors.textHi,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((p) {
            final selected = p.$2 == value;
            return ChoiceChip(
              label: Text(p.$1),
              selected: selected,
              onSelected: (_) => onChanged(p.$2),
              selectedColor: AppColors.accentA.withValues(alpha: 0.3),
              backgroundColor: AppColors.glassTint,
              labelStyle: TextStyle(
                color: selected ? AppColors.accentB : AppColors.textHi,
                fontSize: 13,
              ),
              side: BorderSide(
                color: selected ? AppColors.accentA : AppColors.glassStroke,
              ),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            );
          }).toList(),
        ),
      ],
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
          const Icon(Icons.compress_rounded, color: AppColors.accentB, size: 36),
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
        border: Border(top: BorderSide(color: AppColors.glassStroke, width: 0.5)),
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
            icon: const Icon(Icons.save_alt_rounded, size: 18, color: Colors.white),
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
