import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
import '../model/text_item.dart';

// ffmpeg drawtext anchors the glyph top at y; Flutter's line box keeps ~0.1em of
// ascent space above caps. Lift the preview text by this fraction of fontSize so
// the on-screen top matches the rendered output. (calibration knob)
const double _kTextTopBias = 0.10;

// ── Hex helpers ────────────────────────────────────────────────────────────────
Color _colorFromHex(String hex) =>
    Color(int.parse('FF${hex.padLeft(6, '0')}', radix: 16));
String _hexFromColor(Color c) =>
    (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

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
          if (!state.fontReady) ...[
            const _FontWarningCard(),
            const SizedBox(height: 12),
          ],
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
            const _SectionHeader(
                number: 2,
                title: 'Edit Text',
                subtitle: 'Drag to position · tap to select'),
            const SizedBox(height: 12),
            _PreviewEditor(state: state, ctrl: ctrl),
            const SizedBox(height: 12),
            if (state.selected != null)
              _FormatCard(
                key: ValueKey(state.selectedId),
                item: state.selected!,
                ctrl: ctrl,
              ),
            const SizedBox(height: 12),
            _TextListPanel(state: state, ctrl: ctrl),

            // ── Step 3: Generate / Preview ───────────────────────────────
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
                    onPressed: state.canGenerate ? ctrl.generate : null,
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
            return const SizedBox(
              height: 120,
              child: Center(
                child: Text('Cannot read dimensions',
                    style: TextStyle(color: AppColors.textLo, fontSize: 13)),
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
                        fontFamily: state.fontFamilies[item.style],
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
    final fill = _colorFromHex(item.fontColor);
    final strokeC = _colorFromHex(item.strokeColor);
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

// ── Format card (selected item) ──────────────────────────────────────────────────

class _FormatCard extends StatefulWidget {
  const _FormatCard({super.key, required this.item, required this.ctrl});
  final TextItem item;
  final TextOverlayController ctrl;

  @override
  State<_FormatCard> createState() => _FormatCardState();
}

class _FormatCardState extends State<_FormatCard> {
  late final TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.item.text);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickColor(bool isFill) async {
    final initial = isFill ? widget.item.fontColor : widget.item.strokeColor;
    final hex = await _showColorWheel(context, initial);
    if (hex == null) return;
    if (isFill) {
      widget.ctrl.updateSelected(fontColor: hex);
    } else {
      widget.ctrl.updateSelected(strokeColor: hex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ctrl = widget.ctrl;
    return GlassContainer(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textCtrl,
            onChanged: (v) => ctrl.updateSelected(text: v),
            style: const TextStyle(color: AppColors.textHi, fontSize: 14),
            maxLines: 1,
            decoration: InputDecoration(
              hintText: 'Text…',
              hintStyle: const TextStyle(color: AppColors.textLo, fontSize: 14),
              filled: true,
              fillColor: AppColors.glassTint,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.glassStroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.glassStroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accentA),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Style',
              style: TextStyle(color: AppColors.textLo, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final s in TextStyleKind.values) ...[
                _StyleChip(
                  kind: s,
                  selected: item.style == s,
                  onTap: () => ctrl.updateSelected(style: s),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          OptionSlider(
            label: 'Font Size',
            value: item.fontSize.toDouble(),
            min: 12,
            max: 96,
            divisions: 84,
            unit: 'px',
            onChanged: (v) => ctrl.updateSelected(fontSize: v.round()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ColorButton(
                  label: 'Fill',
                  hex: item.fontColor,
                  onTap: () => _pickColor(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ColorButton(
                  label: 'Stroke',
                  hex: item.strokeColor,
                  onTap: () => _pickColor(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OptionSlider(
            label: 'Stroke Width',
            value: item.strokeWidth.toDouble(),
            min: 0,
            max: 12,
            divisions: 12,
            displayValue:
                item.strokeWidth == 0 ? 'Off' : '${item.strokeWidth}px',
            onChanged: (v) => ctrl.updateSelected(strokeWidth: v.round()),
          ),
        ],
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip(
      {required this.kind, required this.selected, required this.onTap});
  final TextStyleKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, weight, style) = switch (kind) {
      TextStyleKind.regular => ('Aa', FontWeight.w400, FontStyle.normal),
      TextStyleKind.bold => ('Aa', FontWeight.w800, FontStyle.normal),
      TextStyleKind.italic => ('Aa', FontWeight.w400, FontStyle.italic),
      TextStyleKind.boldItalic => ('Aa', FontWeight.w800, FontStyle.italic),
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentA.withValues(alpha: 0.25)
              : AppColors.glassTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accentA : AppColors.glassStroke,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accentB : AppColors.textLo,
            fontSize: 15,
            fontWeight: weight,
            fontStyle: style,
          ),
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton(
      {required this.label, required this.hex, required this.onTap});
  final String label;
  final String hex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.glassTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.glassStroke),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _colorFromHex(hex),
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
            ),
            const SizedBox(width: 10),
            Text(label,
                style:
                    const TextStyle(color: AppColors.textHi, fontSize: 13)),
            const Spacer(),
            Text('#$hex',
                style:
                    const TextStyle(color: AppColors.textLo, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Text list panel ───────────────────────────────────────────────────────────────

class _TextListPanel extends StatelessWidget {
  const _TextListPanel({required this.state, required this.ctrl});
  final TextOverlayState state;
  final TextOverlayController ctrl;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Text Layers',
                  style: TextStyle(
                      color: AppColors.textHi,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('${state.items.length}/20',
                  style:
                      const TextStyle(color: AppColors.textLo, fontSize: 12)),
              const Spacer(),
              _AddButton(onTap: state.canAdd ? ctrl.addText : null),
            ],
          ),
          if (state.items.isEmpty) ...[
            const SizedBox(height: 12),
            const Text('No text yet. Tap “Add” to create one.',
                style: TextStyle(color: AppColors.textLo, fontSize: 13)),
          ] else
            for (final item in state.items) ...[
              const SizedBox(height: 8),
              _TextRow(
                item: item,
                selected: item.id == state.selectedId,
                onTap: () => ctrl.select(item.id),
                onDelete: () => ctrl.removeText(item.id),
              ),
            ],
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: enabled ? AppGradients.primaryButton : null,
          color: enabled ? null : AppColors.glassTint,
          borderRadius: BorderRadius.circular(20),
          border:
              enabled ? null : Border.all(color: AppColors.glassStroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded,
                size: 16,
                color: enabled ? Colors.white : AppColors.textLo),
            const SizedBox(width: 4),
            Text('Add',
                style: TextStyle(
                  color: enabled ? Colors.white : AppColors.textLo,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });
  final TextItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = item.text.trim().isEmpty ? '(empty)' : item.text;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentA.withValues(alpha: 0.18)
              : AppColors.glassTint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accentA : AppColors.glassStroke,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.text_fields_rounded,
                color: AppColors.textLo, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.textHi : AppColors.textLo,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.delete_outline_rounded,
                    color: AppColors.textLo, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Color wheel sheet ─────────────────────────────────────────────────────────────

Future<String?> _showColorWheel(BuildContext context, String initialHex) {
  var picked = _colorFromHex(initialHex);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ColorPicker(
                pickerColor: picked,
                onColorChanged: (c) => picked = c,
                enableAlpha: false,
                displayThumbColor: true,
                paletteType: PaletteType.hueWheel,
                labelTypes: const [],
                pickerAreaBorderRadius: BorderRadius.circular(12),
              ),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.primaryButton,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_hexFromColor(picked)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No system font found. Text rendering may fail on Generate.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
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
