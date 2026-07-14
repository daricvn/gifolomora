import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/common/app_toast.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../_shared/widgets/file_drop_zone.dart';
import '../../_shared/widgets/option_slider.dart';
import '../../../l10n/app_localizations.dart';
import '../controller/webm_converter_controller.dart';

const _videoExtensions = ['mp4', 'mov', 'mkv', 'avi', 'm4v', 'webm'];

class WebmConverterScreen extends ConsumerWidget {
  const WebmConverterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(webmConverterControllerProvider).valueOrNull ??
            const WebmConverterState();
    final ctrl = ref.read(webmConverterControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    Future<void> pick(List<File> files) async {
      final rejected = await ctrl.addFiles(files);
      if (rejected > 0 && context.mounted) {
        AppToast.info(
            context,
            rejected == 1
                ? l10n.webmRejectedToastOne(rejected)
                : l10n.webmRejectedToastOther(rejected));
      }
    }

    Future<void> doExport() async {
      if (state.items.length == 1) {
        final ok = await ctrl.exportSingle();
        if (context.mounted) {
          if (ok) {
            AppToast.success(context, l10n.webmSavedToast);
          } else {
            AppToast.error(context, l10n.commonExportCancelled);
          }
        }
        return;
      }
      final n = await ctrl.exportBatch();
      if (context.mounted) {
        if (n != null) {
          AppToast.success(
              context, n == 1 ? l10n.webmExportedToastOne(n) : l10n.webmExportedToastOther(n));
        } else {
          AppToast.error(context, l10n.commonExportCancelled);
        }
      }
    }

    return GradientScaffold(
      appBar: GlassAppBar(
        title: l10n.webmAppBarTitle,
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
      bottomNavigationBar: state.hasDone
          ? _ExportBar(count: state.doneCount, onExport: doExport)
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16 + MediaQuery.of(context).padding.top + 64,
          16,
          100,
        ),
        children: [
          _SectionHeader(number: 1, title: l10n.webmStepSelectFiles),
          const SizedBox(height: 12),
          FileDropZone(
            hint: l10n.webmDropHint,
            icon: Icons.movie_filter_rounded,
            allowMultiple: true,
            allowedExtensions: const [..._videoExtensions, 'gif'],
            onFilesSelected: pick,
          ),

          if (state.items.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(number: 2, title: l10n.commonOptions),
            const SizedBox(height: 12),
            _OptionsCard(state: state, ctrl: ctrl),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionHeader(number: 3, title: l10n.webmStepConvert),
                TextButton(
                  onPressed: ctrl.clear,
                  child: Text(l10n.commonClearAll,
                      style: const TextStyle(color: AppColors.textLo)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.isProcessing) _OverallProgressCard(state: state, ctrl: ctrl),
            const SizedBox(height: 12),
            ...state.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FileRow(item: item, onRemove: () => ctrl.removeItem(item.id)),
                )),
            const SizedBox(height: 12),
            _ConvertButton(
              enabled: state.canConvert,
              onTap: ctrl.convertAll,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

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
          decoration: const BoxDecoration(
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

class _OptionsCard extends StatelessWidget {
  const _OptionsCard({required this.state, required this.ctrl});
  final WebmConverterState state;
  final WebmConverterController ctrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.webmCodecLabel,
              style: const TextStyle(color: AppColors.textLo, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Chip(
                  label: l10n.webmVp9,
                  subtitle: l10n.webmVp9Sub,
                  selected: !state.av1,
                  onTap: () => ctrl.setAv1(false),
                ),
              ),
              if (state.av1Supported) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _Chip(
                    label: l10n.webmAv1,
                    subtitle: l10n.webmAv1Sub,
                    selected: state.av1,
                    disabled: state.alpha,
                    onTap: () => ctrl.setAv1(true),
                  ),
                ),
              ],
            ],
          ),
          const Divider(color: AppColors.glassStroke, height: 24),
          OptionSlider(
            label: l10n.webmQualityLabel,
            value: state.crf.toDouble(),
            min: 18,
            max: 45,
            divisions: 27,
            displayValue: '${state.crf}',
            onChanged: (v) => ctrl.setCrf(v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.webmSharperBigger,
                  style: const TextStyle(color: AppColors.textLo, fontSize: 11)),
              Text(l10n.webmSmallerSofter,
                  style: const TextStyle(color: AppColors.textLo, fontSize: 11)),
            ],
          ),
          const Divider(color: AppColors.glassStroke, height: 24),
          Text(l10n.commonSpeed,
              style: const TextStyle(color: AppColors.textLo, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Chip(
                  label: l10n.webmFast,
                  selected: state.speed == WebmSpeed.fast,
                  onTap: () => ctrl.setSpeed(WebmSpeed.fast),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Chip(
                  label: l10n.webmBalanced,
                  selected: state.speed == WebmSpeed.balanced,
                  onTap: () => ctrl.setSpeed(WebmSpeed.balanced),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Chip(
                  label: l10n.webmBest,
                  selected: state.speed == WebmSpeed.best,
                  onTap: () => ctrl.setSpeed(WebmSpeed.best),
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.glassStroke, height: 24),
          Text(l10n.webmMaxWidth,
              style: const TextStyle(color: AppColors.textLo, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final w in [null, 1080, 720, 480]) ...[
                if (w != null) const SizedBox(width: 8),
                Expanded(
                  child: _Chip(
                    label: w == null ? l10n.commonOriginal : '$w',
                    selected: state.maxWidth == w,
                    onTap: () => ctrl.setMaxWidth(w),
                  ),
                ),
              ],
            ],
          ),
          if (state.hasAnyGif) ...[
            const Divider(color: AppColors.glassStroke, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(l10n.webmKeepTransparency,
                      style: const TextStyle(color: AppColors.textHi, fontSize: 14)),
                ),
                Switch(
                  value: state.alpha,
                  activeThumbColor: AppColors.accentB,
                  onChanged: ctrl.setAlpha,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.disabled = false,
  });
  final String label;
  final String? subtitle;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentA.withValues(alpha: 0.2)
                : AppColors.glassTint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accentA : AppColors.glassStroke,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: selected ? AppColors.accentB : AppColors.textHi,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textLo, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({required this.state, required this.ctrl});
  final WebmConverterState state;
  final WebmConverterController ctrl;

  @override
  Widget build(BuildContext context) {
    final done = state.doneCount + state.errorCount;
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      borderRadius: 16,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.overallProgress,
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
                l10n.webmConvertingProgress(done + 1, state.items.length,
                    (state.overallProgress * 100).round()),
                style: const TextStyle(color: AppColors.textLo, fontSize: 13),
              ),
              TextButton(
                onPressed: ctrl.cancel,
                child: Text(l10n.commonCancel,
                    style: const TextStyle(color: AppColors.accentC)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.item, required this.onRemove});
  final WebmItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final info = item.info;
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.isGif ? Icons.gif_box_rounded : Icons.movie_rounded,
                  color: AppColors.accentB, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.source.path.split(RegExp(r'[\\/]')).last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textHi,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      item.isProbing
                          ? l10n.webmProbing
                          : info == null
                              ? ''
                              : '${info.width}×${info.height}'
                                  '${info.durationMs > 0 ? ' · ${(info.durationMs / 1000).toStringAsFixed(1)}s' : ''}',
                      style: const TextStyle(
                          color: AppColors.textLo, fontSize: 11),
                    ),
                  ],
                ),
              ),
              _StatusChip(item: item),
              if (item.status != WebmItemStatus.converting)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textLo, size: 18),
                  onPressed: onRemove,
                ),
            ],
          ),
          if (item.status == WebmItemStatus.converting) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: item.progressFraction,
                backgroundColor: AppColors.glassStroke,
                valueColor: const AlwaysStoppedAnimation(AppColors.accentB),
                minHeight: 4,
              ),
            ),
          ],
          if (item.status == WebmItemStatus.done) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _WebmPreviewDialog.show(context, item.output!),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded,
                      color: AppColors.accentB, size: 14),
                  const SizedBox(width: 6),
                  Text(item.sizeDeltaLabel,
                      style: const TextStyle(
                          color: AppColors.accentB,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          if (item.status == WebmItemStatus.error) ...[
            const SizedBox(height: 6),
            Text(item.error ?? l10n.webmConversionFailed,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});
  final WebmItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (item.status) {
      WebmItemStatus.queued => (l10n.webmQueued, AppColors.textLo),
      WebmItemStatus.converting => (l10n.webmConverting, AppColors.accentB),
      WebmItemStatus.done => (l10n.webmDone, AppColors.accentB),
      WebmItemStatus.error => (l10n.webmError, Colors.redAccent),
    };
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _ConvertButton extends StatelessWidget {
  const _ConvertButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? AppGradients.primaryButton : null,
          color: enabled ? null : AppColors.glassTint,
          borderRadius: BorderRadius.circular(16),
          border: enabled ? null : Border.all(color: AppColors.glassStroke),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt_rounded,
                  color: enabled ? Colors.white : AppColors.textLo, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.webmConvertButton,
                style: TextStyle(
                  color: enabled ? Colors.white : AppColors.textLo,
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

class _ExportBar extends StatelessWidget {
  const _ExportBar({required this.count, required this.onExport});
  final int count;
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
            label: Text(
                count > 1
                    ? AppLocalizations.of(context)!.webmExportAll(count)
                    : AppLocalizations.of(context)!.webmExportSingle,
                style: const TextStyle(
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

/// Minimal media_kit playback dialog for a converted WebM — libmpv plays
/// WebM on both platforms, so no special-casing is needed beyond Player+Video.
class _WebmPreviewDialog extends StatefulWidget {
  const _WebmPreviewDialog({required this.file});
  final File file;

  static void show(BuildContext context, File file) {
    showDialog<void>(
      context: context,
      builder: (_) => _WebmPreviewDialog(file: file),
    );
  }

  @override
  State<_WebmPreviewDialog> createState() => _WebmPreviewDialogState();
}

class _WebmPreviewDialogState extends State<_WebmPreviewDialog> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.file.path));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Video(controller: _controller),
        ),
      ),
    );
  }
}
