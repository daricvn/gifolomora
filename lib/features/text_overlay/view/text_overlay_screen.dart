import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/font_registry.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../_shared/widgets/export_bottom_sheet.dart';
import '../../_shared/widgets/file_drop_zone.dart';
import '../../_shared/widgets/media_preview.dart';
import '../../_shared/widgets/text_overlay_controls.dart';
import '../../../l10n/app_localizations.dart';
import '../controller/text_overlay_controller.dart';
import '../model/text_item.dart';

// ffmpeg drawtext anchors the glyph top at y; Flutter's line box keeps ~0.1em of
// ascent space above caps. Lift the preview text by this fraction of fontSize so
// the on-screen top matches the rendered output. (calibration knob)
const double _kTextTopBias = 0.10;

class TextOverlayScreen extends ConsumerWidget {
  const TextOverlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(textOverlayControllerProvider).valueOrNull ??
        const TextOverlayState();
    final ctrl = ref.read(textOverlayControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    Future<void> doExport() async {
      await ExportBottomSheet.show(
        context,
        onExport: () async {
          final ok = await ctrl.exportGif();
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.commonExportCancelled)),
            );
          }
        },
      );
    }

    return GradientScaffold(
      appBar: GlassAppBar(
        title: l10n.textOverlayAppBarTitle,
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
          _SectionHeader(number: 1, title: l10n.commonSelectGif),
          const SizedBox(height: 12),
          if (!state.fontReady) ...[
            const _FontWarningCard(),
            const SizedBox(height: 12),
          ],
          if (state.isProbing)
            GlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                const CircularProgressIndicator(color: AppColors.accentB),
                const SizedBox(height: 12),
                Text(l10n.commonReadingFile,
                    style: const TextStyle(color: AppColors.textLo, fontSize: 13)),
              ]),
            )
          else if (!state.hasInput)
            FileDropZone(
              hint: l10n.commonTapToSelectGif,
              icon: Icons.gif_box_rounded,
              allowedExtensions: const ['gif'],
              onFilesSelected: (files) {
                if (files.isNotEmpty) ctrl.setInput(files.first);
              },
            )
          else
            _FileInfoCard(
              name: state.inputFile!.path.split(Platform.pathSeparator).last,
              width: state.mediaInfo?.width ?? 0,
              height: state.mediaInfo?.height ?? 0,
              onClear: ctrl.clear,
            ),

          // ── Step 2: Editor ─────────────────────────────────────────────
          if (state.hasInput && !state.isProbing && state.mediaInfo != null) ...[
            const SizedBox(height: 24),
            _SectionHeader(
                number: 2,
                title: l10n.textOverlayStepEditText,
                subtitle: l10n.textOverlayStepEditTextSubtitle),
            const SizedBox(height: 12),
            _PreviewEditor(state: state, ctrl: ctrl),
            const SizedBox(height: 12),
            if (state.selected != null)
              TextFormatCard(
                key: ValueKey(state.selectedId),
                item: state.selected!,
                onText: (v) => ctrl.updateSelected(text: v),
                onStyle: (v) => ctrl.updateSelected(style: v),
                onFont: (v) => ctrl.updateSelected(font: v),
                onFontSize: (v) => ctrl.updateSelected(fontSize: v),
                onFontColor: (v) => ctrl.updateSelected(fontColor: v),
                onStrokeColor: (v) => ctrl.updateSelected(strokeColor: v),
                onStrokeWidth: (v) => ctrl.updateSelected(strokeWidth: v),
              ),
            const SizedBox(height: 12),
            TextLayersPanel(
              items: state.items,
              selectedId: state.selectedId,
              canAdd: state.canAdd,
              onAdd: ctrl.addText,
              onSelect: ctrl.select,
              onDelete: ctrl.removeText,
            ),

            // ── Step 3: Generate / Preview ───────────────────────────────
            const SizedBox(height: 24),
            _SectionHeader(number: 3, title: l10n.commonPreview),
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
                    onPressed: state.canGenerate ? ctrl.generate : null,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(l10n.commonRegenerate),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textLo,
                      side: const BorderSide(color: AppColors.glassStroke),
                    ),
                  ),
                ],
              )
            else
              _GenerateButton(onTap: state.canGenerate ? ctrl.generate : null),

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

// ── Preview editor ──────────────────────────────────────────────────────────────

class _PreviewEditor extends ConsumerWidget {
  const _PreviewEditor({required this.state, required this.ctrl});
  final TextOverlayState state;
  final TextOverlayController ctrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mi = state.mediaInfo!;
    final mw = mi.width.toDouble();
    final mh = mi.height.toDouble();

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, c) {
          if (mw <= 0 || mh <= 0) {
            return SizedBox(
              height: 120,
              child: Center(
                child: Text(AppLocalizations.of(context)!.textOverlayCannotReadDims,
                    style: const TextStyle(color: AppColors.textLo, fontSize: 13)),
              ),
            );
          }
          const maxH = 360.0;
          var scale = c.maxWidth / mw;
          if (mh * scale > maxH) scale = maxH / mh;
          final dW = mw * scale;
          final dH = mh * scale;

          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: dW,
                height: dH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.file(
                        state.inputFile!,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                    ),
                    // tap empty → deselect
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => ctrl.select(null),
                      ),
                    ),
                    for (final item in state.items)
                      _DraggableText(
                        item: item,
                        selected: item.id == state.selectedId,
                        scale: scale,
                        mw: mw,
                        mh: mh,
                        ctrl: ctrl,
                        ref: ref,
                        fontFamily: FontRegistry.familyFor(item.font, item.style) ??
                            state.fontFamilies[item.style],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DraggableText extends StatelessWidget {
  const _DraggableText({
    required this.item,
    required this.selected,
    required this.scale,
    required this.mw,
    required this.mh,
    required this.ctrl,
    required this.ref,
    required this.fontFamily,
  });

  final TextItem item;
  final bool selected;
  final double scale;
  final double mw;
  final double mh;
  final TextOverlayController ctrl;
  final WidgetRef ref;
  final String? fontFamily;

  TextItem? get _current =>
      ref.read(textOverlayControllerProvider).valueOrNull?.selected;

  @override
  Widget build(BuildContext context) {
    final left = TextItem.leftFromNx(item.nx, mw, scale);
    final top = TextItem.topFromNy(item.ny, mh, scale);
    final fs = TextItem.previewFontSize(item.fontSize, scale);

    // When the real font file is loaded its weight/style are baked in (same file
    // ffmpeg uses) — don't also synthesize bold/italic or it doubles up.
    final hasFam = fontFamily != null;
    final fw = !hasFam &&
            (item.style == TextStyleKind.bold ||
                item.style == TextStyleKind.boldItalic)
        ? FontWeight.w700
        : FontWeight.w400;
    final fst = !hasFam &&
            (item.style == TextStyleKind.italic ||
                item.style == TextStyleKind.boldItalic)
        ? FontStyle.italic
        : FontStyle.normal;
    final fill = colorFromHex(item.fontColor);
    final strokeC = colorFromHex(item.strokeColor);
    // ffmpeg borderw=N grows the glyph N px each side; Flutter's centered stroke
    // grows W/2 — double it so the preview footprint matches the output.
    final sw = item.strokeWidth * 2 * scale;

    final textStack = Stack(
      children: [
        if (item.strokeWidth > 0)
          Text(
            item.text,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fs,
              fontWeight: fw,
              fontStyle: fst,
              height: 1.0,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = sw
                ..strokeJoin = StrokeJoin.round
                ..color = strokeC,
            ),
          ),
        Text(
          item.text,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: fs,
            fontWeight: fw,
            fontStyle: fst,
            height: 1.0,
            color: fill,
          ),
        ),
      ],
    );

    return Positioned(
      left: left,
      top: top - fs * _kTextTopBias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ctrl.select(item.id),
        onPanDown: (_) => ctrl.select(item.id),
        onPanUpdate: (d) {
          final cur = _current;
          if (cur == null) return;
          ctrl.moveSelected(
            cur.nx + d.delta.dx / scale / mw,
            cur.ny + d.delta.dy / scale / mh,
          );
        },
        // foregroundDecoration paints the selection outline over the text without
        // adding layout padding that would shift it off the true position.
        child: Container(
          foregroundDecoration: selected
              ? BoxDecoration(
                  border: Border.all(color: AppColors.accentB, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: textStack,
        ),
      ),
    );
  }
}

// ── Shared sub-widgets (mirrors resize/images_to_gif) ────────────────────────────

class _FontWarningCard extends StatelessWidget {
  const _FontWarningCard();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 16,
      tint: Colors.orange,
      opacity: 0.08,
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.textOverlayFontWarning,
              style: const TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textHi,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(
                        color: AppColors.textLo, fontSize: 12)),
            ],
          ),
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
          const Icon(Icons.gif_box_rounded,
              color: AppColors.accentB, size: 36),
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
    final l10n = AppLocalizations.of(context)!;
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
                    ? l10n.commonProcessingPercent((progress! * 100).round())
                    : l10n.commonProcessing,
                style: const TextStyle(color: AppColors.textLo, fontSize: 13),
              ),
              TextButton(
                onPressed: onCancel,
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
          border:
              onTap == null ? Border.all(color: AppColors.glassStroke) : null,
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
                AppLocalizations.of(context)!.commonGeneratePreview,
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
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 13)),
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
            label: Text(AppLocalizations.of(context)!.commonExportGif,
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
