import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/font_registry.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../text_overlay/model/text_item.dart';
import 'option_slider.dart';

// Shared text-overlay editing controls. The draggable preview differs per host
// screen (full-page vs Video Studio canvas) and stays local; these layout-
// neutral pieces — format card, style/colour chips, layer list, colour wheel —
// are reused by both Text Overlay and Video Studio.

// ── Hex helpers ──────────────────────────────────────────────────────────────
Color colorFromHex(String hex) =>
    Color(int.parse('FF${hex.padLeft(6, '0')}', radix: 16));
String hexFromColor(Color c) =>
    (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

// ── Format card (edits the selected item via callbacks) ──────────────────────

class TextFormatCard extends StatefulWidget {
  const TextFormatCard({
    super.key,
    required this.item,
    required this.onText,
    required this.onStyle,
    required this.onFont,
    required this.onFontSize,
    required this.onFontColor,
    required this.onStrokeColor,
    required this.onStrokeWidth,
  });

  final TextItem item;
  final ValueChanged<String> onText;
  final ValueChanged<TextStyleKind> onStyle;
  final ValueChanged<TextFont> onFont;
  final ValueChanged<int> onFontSize;
  final ValueChanged<String> onFontColor;
  final ValueChanged<String> onStrokeColor;
  final ValueChanged<int> onStrokeWidth;

  @override
  State<TextFormatCard> createState() => _TextFormatCardState();
}

class _TextFormatCardState extends State<TextFormatCard> {
  late final TextEditingController _textCtrl =
      TextEditingController(text: widget.item.text);

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickColor(bool isFill) async {
    final initial = isFill ? widget.item.fontColor : widget.item.strokeColor;
    final hex = await showTextColorWheel(context, initial);
    if (hex == null) return;
    if (isFill) {
      widget.onFontColor(hex);
    } else {
      widget.onStrokeColor(hex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textCtrl,
            onChanged: widget.onText,
            style: const TextStyle(color: AppColors.textHi, fontSize: 14),
            maxLines: 1,
            decoration: InputDecoration(
              hintText: l10n.textOverlayTextFieldHint,
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
          Text(l10n.textOverlayStyleLabel,
              style: const TextStyle(color: AppColors.textLo, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in TextStyleKind.values)
                _StyleChip(
                  kind: s,
                  selected: item.style == s,
                  onTap: () => widget.onStyle(s),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(l10n.textOverlayFontLabel,
              style: const TextStyle(color: AppColors.textLo, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in TextFont.values)
                _FontChip(
                  font: f,
                  selected: item.font == f,
                  onTap: () => widget.onFont(f),
                ),
            ],
          ),
          const SizedBox(height: 14),
          OptionSlider(
            label: l10n.commonFontSizeLabel,
            value: item.fontSize.toDouble(),
            min: 12,
            max: 160,
            divisions: 92,
            unit: 'px',
            onChanged: (v) => widget.onFontSize(v.round()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ColorButton(
                  label: l10n.textOverlayFillLabel,
                  hex: item.fontColor,
                  onTap: () => _pickColor(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ColorButton(
                  label: l10n.textOverlayStrokeLabel,
                  hex: item.strokeColor,
                  onTap: () => _pickColor(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OptionSlider(
            label: l10n.textOverlayStrokeWidthLabel,
            value: item.strokeWidth.toDouble(),
            min: 0,
            max: 12,
            divisions: 12,
            displayValue:
                item.strokeWidth == 0 ? l10n.commonOff : '${item.strokeWidth}px',
            onChanged: (v) => widget.onStrokeWidth(v.round()),
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

class _FontChip extends StatelessWidget {
  const _FontChip(
      {required this.font, required this.selected, required this.onTap});
  final TextFont font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Render each label in its own typeface (null family = system default) so
    // the picker previews the font itself.
    final family = FontRegistry.familyFor(font, TextStyleKind.regular);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
          font.label,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: family,
            color: selected ? AppColors.accentB : AppColors.textLo,
            fontSize: 15,
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
                color: colorFromHex(hex),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style:
                      const TextStyle(color: AppColors.textHi, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Text('#$hex',
                style: const TextStyle(color: AppColors.textLo, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Text layer list (add / select / delete) ──────────────────────────────────

class TextLayersPanel extends StatelessWidget {
  const TextLayersPanel({
    super.key,
    required this.items,
    required this.selectedId,
    required this.canAdd,
    required this.onAdd,
    required this.onSelect,
    required this.onDelete,
  });
  final List<TextItem> items;
  final String? selectedId;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.textOverlayLayersTitle,
                  style: const TextStyle(
                      color: AppColors.textHi,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('${items.length}/20',
                  style: const TextStyle(color: AppColors.textLo, fontSize: 12)),
              const Spacer(),
              _AddButton(onTap: canAdd ? onAdd : null),
            ],
          ),
          if (items.isEmpty) ...[
            const SizedBox(height: 12),
            Text(l10n.textOverlayNoTextYet,
                style: const TextStyle(color: AppColors.textLo, fontSize: 13)),
          ] else
            for (final item in items) ...[
              const SizedBox(height: 8),
              _TextRow(
                item: item,
                selected: item.id == selectedId,
                onTap: () => onSelect(item.id),
                onDelete: () => onDelete(item.id),
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
          border: enabled ? null : Border.all(color: AppColors.glassStroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded,
                size: 16, color: enabled ? Colors.white : AppColors.textLo),
            const SizedBox(width: 4),
            Text(AppLocalizations.of(context)!.textOverlayAdd,
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
    final label = item.text.trim().isEmpty
        ? AppLocalizations.of(context)!.textOverlayEmptyPlaceholder
        : item.text;
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

// ── Colour wheel sheet ────────────────────────────────────────────────────────

Future<String?> showTextColorWheel(BuildContext context, String initialHex) {
  var picked = colorFromHex(initialHex);
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
              LayoutBuilder(
                builder: (ctx, constraints) {
                  // Package ColorPicker hard-sizes wheel + slider row to
                  // colorPickerWidth (non-flexible). Use the real available
                  // width so it never overflows; fall back to screen width if
                  // the constraint is unbounded; cap at 300 (package default).
                  final avail = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : MediaQuery.of(ctx).size.width - 72;
                  return ColorPicker(
                    pickerColor: picked,
                    onColorChanged: (c) => picked = c,
                    colorPickerWidth: avail.clamp(0.0, 300.0),
                    portraitOnly: true,
                    enableAlpha: false,
                    displayThumbColor: true,
                    paletteType: PaletteType.hueWheel,
                    labelTypes: const [],
                    pickerAreaBorderRadius: BorderRadius.circular(12),
                  );
                },
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
                        Navigator.of(context).pop(hexFromColor(picked)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.commonDone,
                        style: const TextStyle(
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
