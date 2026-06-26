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
import '../controller/text_overlay_controller.dart';

const _kPositions = [
  ('Top', 'top'),
  ('Center', 'center'),
  ('Bottom', 'bottom'),
];

const _kColors = [
  ('White', 'white', Color(0xFFF2F4FF)),
  ('Yellow', 'yellow', Color(0xFFFFE066)),
  ('Black', 'black', Color(0xFF22242E)),
  ('Red', 'red', Color(0xFFFF5CAA)),
];

class TextOverlayScreen extends ConsumerWidget {
  const TextOverlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(textOverlayControllerProvider).valueOrNull ??
        const TextOverlayState();
    final ctrl = ref.read(textOverlayControllerProvider.notifier);

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
        title: 'Text Overlay',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textHi, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
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
              icon: Icons.text_fields_rounded,
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

          // ── Font warning if not found ──────────────────────────────────
          if (state.fontFile == null) ...[
            const SizedBox(height: 12),
            GlassContainer(
              borderRadius: 16,
              tint: Colors.orange,
              opacity: 0.08,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No system font found. Text overlay may fail. '
                      'Install Arial/Roboto or bundle a .ttf in assets/fonts/.',
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Step 2: Options ────────────────────────────────────────────
          if (state.hasInput && !state.isProbing) ...[
            const SizedBox(height: 24),
            const _SectionHeader(number: 2, title: 'Caption'),
            const SizedBox(height: 12),
            GlassContainer(
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text input
                  TextField(
                    onChanged: ctrl.setText,
                    style: const TextStyle(
                        color: AppColors.textHi, fontSize: 15),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter caption text…',
                      hintStyle: const TextStyle(
                          color: AppColors.textLo, fontSize: 15),
                      filled: true,
                      fillColor: AppColors.glassTint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.glassStroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.glassStroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.accentA),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Position
                  const Text('Position',
                      style: TextStyle(
                          color: AppColors.textLo, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _kPositions.map((pos) {
                      final (label, value) = pos;
                      final selected = value == state.position;
                      return _Chip(
                        label: label,
                        selected: selected,
                        onTap: () => ctrl.setPosition(value),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Font size
                  OptionSlider(
                    label: 'Font Size',
                    value: state.fontSize.toDouble(),
                    min: 12,
                    max: 96,
                    divisions: 28,
                    unit: 'px',
                    onChanged: (v) => ctrl.setFontSize(v.round()),
                  ),
                  const SizedBox(height: 8),

                  // Color
                  const Text('Color',
                      style: TextStyle(
                          color: AppColors.textLo, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _kColors.map((entry) {
                      final (label, value, swatch) = entry;
                      final selected = value == state.fontColor;
                      return _ColorChip(
                        label: label,
                        color: swatch,
                        selected: selected,
                        onTap: () => ctrl.setFontColor(value),
                      );
                    }).toList(),
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
              _GenerateButton(
                onTap: state.canGenerate ? ctrl.generate : null,
                hint: !state.canGenerate && state.text.isEmpty
                    ? 'Enter text above'
                    : null,
              ),

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
                      style:
                          const TextStyle(color: AppColors.textLo, fontSize: 12)),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentA.withValues(alpha: 0.25)
              : AppColors.glassTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accentA : AppColors.glassStroke,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accentB : AppColors.textLo,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentA.withValues(alpha: 0.2)
              : AppColors.glassTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accentA : AppColors.glassStroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.accentB : AppColors.textLo,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
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
  const _GenerateButton({required this.onTap, this.hint});
  final VoidCallback? onTap;
  final String? hint;

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
          child: Column(
            children: [
              Row(
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
              if (hint != null) ...[
                const SizedBox(height: 4),
                Text(hint!,
                    style: const TextStyle(
                        color: AppColors.textLo, fontSize: 12)),
              ],
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
