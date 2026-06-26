import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
import '../controller/images_to_gif_controller.dart';
import '../widgets/frame_strip.dart';

class ImagesToGifScreen extends ConsumerStatefulWidget {
  const ImagesToGifScreen({super.key});

  @override
  ConsumerState<ImagesToGifScreen> createState() => _ImagesToGifScreenState();
}

class _ImagesToGifScreenState extends ConsumerState<ImagesToGifScreen> {
  Future<void> _addMore() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    if (result == null || !mounted) return;
    final files = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();
    if (files.isNotEmpty) {
      ref.read(imagesToGifControllerProvider.notifier).addFrames(files);
    }
  }

  Future<void> _export() async {
    if (!mounted) return;
    await ExportBottomSheet.show(
      context,
      onExport: () async {
        final ok = await ref
            .read(imagesToGifControllerProvider.notifier)
            .exportGif();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export cancelled')),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imagesToGifControllerProvider).valueOrNull ??
        const ImagesToGifState();
    final ctrl = ref.read(imagesToGifControllerProvider.notifier);

    return GradientScaffold(
      appBar: GlassAppBar(
        title: 'Images → GIF',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textHi, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      bottomNavigationBar: state.outputGif != null
          ? _ExportBar(onExport: _export)
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16 + MediaQuery.of(context).padding.top + 64,
          16,
          100,
        ),
        children: [
          // ── Step 1: Pick frames ────────────────────────────────────────
          _SectionHeader(
            number: 1,
            title: 'Select Frames',
            subtitle: 'Pick images in the order you want them to play',
          ),
          const SizedBox(height: 12),
          if (!state.hasFrames)
            FileDropZone(
              allowMultiple: true,
              hint: 'Tap to select images',
              icon: Icons.photo_library_rounded,
              allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
              onFilesSelected: ctrl.addFrames,
            )
          else
            FrameStrip(
              frames: state.frames,
              onRemove: ctrl.removeFrame,
              onReorder: ctrl.reorderFrames,
              onAddMore: _addMore,
            ),

          // ── Step 2: Options ────────────────────────────────────────────
          if (state.hasFrames) ...[
            const SizedBox(height: 24),
            const _SectionHeader(number: 2, title: 'Options'),
            const SizedBox(height: 12),
            GlassContainer(
              borderRadius: 20,
              child: Column(
                children: [
                  OptionSlider(
                    label: 'Frame rate',
                    value: state.fps.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 25,
                    unit: ' fps',
                    onChanged: (v) => ctrl.setFps(v.round()),
                  ),
                  const SizedBox(height: 8),
                  OptionSlider(
                    label: 'Width',
                    value: (state.width ?? 0).toDouble(),
                    min: 0,
                    max: 1280,
                    divisions: 64,
                    displayValue: state.width == null || state.width == 0
                        ? 'Original'
                        : '${state.width}px',
                    onChanged: (v) =>
                        ctrl.setWidth(v.round() == 0 ? null : v.round()),
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
                progress: state.progress?.fraction,
                onCancel: ctrl.cancel,
              )
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.number, required this.title, this.subtitle});
  final int number;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: AppGradients.primaryButton,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textHi,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(color: AppColors.textLo, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
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
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.accentC),
                ),
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
              Icon(
                Icons.auto_awesome_rounded,
                color: onTap != null ? Colors.white : AppColors.textLo,
                size: 20,
              ),
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
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
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
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
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
            label: const Text(
              'Export GIF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
