import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Groups tools by intent so the home screen can give each group a tailored
/// layout (featured hero row vs. compact grid) instead of one flat grid.
enum ToolCategory {
  /// Source/creation entry points — given featured, large-card treatment.
  create,

  /// Edit & optimize an existing GIF — compact grid treatment.
  refine,
}

class ToolEntry {
  const ToolEntry({
    required this.id,
    required this.icon,
    required this.route,
    required this.accentColor,
    required this.category,
    this.windowsOnly = false,
  });

  final String id;
  final IconData icon;
  final String route;
  final Color accentColor;
  final ToolCategory category;

  /// Hidden from the home grid (and its route guarded) off-Windows —
  /// Screen Record depends on gdigrab + WASAPI loopback + global hotkeys,
  /// all Windows-only.
  final bool windowsOnly;
}

/// Label/description are localized, so they resolve per-[BuildContext]
/// instead of living as static [ToolEntry] fields.
extension ToolEntryL10n on ToolEntry {
  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (id) {
      'video_studio' => l10n.toolVideoStudioLabel,
      'images_to_gif' => l10n.toolImagesToGifLabel,
      'screen_record' => l10n.toolScreenRecordLabel,
      'resize' => l10n.toolResizeLabel,
      'crop' => l10n.toolCropLabel,
      'text_overlay' => l10n.toolTextOverlayLabel,
      'optimize' => l10n.toolOptimizeLabel,
      'effects' => l10n.toolEffectsLabel,
      'to_webm' => l10n.toolToWebmLabel,
      _ => id,
    };
  }

  String description(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (id) {
      'video_studio' => l10n.toolVideoStudioDesc,
      'images_to_gif' => l10n.toolImagesToGifDesc,
      'screen_record' => l10n.toolScreenRecordDesc,
      'resize' => l10n.toolResizeDesc,
      'crop' => l10n.toolCropDesc,
      'text_overlay' => l10n.toolTextOverlayDesc,
      'optimize' => l10n.toolOptimizeDesc,
      'effects' => l10n.toolEffectsDesc,
      'to_webm' => l10n.toolToWebmDesc,
      _ => '',
    };
  }
}

const List<ToolEntry> toolCatalog = [
  // ── Create ──────────────────────────────────────────────────────────────
  ToolEntry(
    id: 'video_studio',
    icon: Icons.movie_creation_rounded,
    route: '/video-studio',
    accentColor: Color(0xFFFF8C00),
    category: ToolCategory.create,
  ),
  ToolEntry(
    id: 'images_to_gif',
    icon: Icons.photo_library_rounded,
    route: '/images-to-gif',
    accentColor: Color(0xFF00C2FF),
    category: ToolCategory.create,
  ),
  ToolEntry(
    id: 'screen_record',
    icon: Icons.fiber_manual_record_rounded,
    route: '/screen-record',
    accentColor: Color(0xFFFF3B5C),
    category: ToolCategory.create,
    windowsOnly: true,
  ),

  // ── Refine ──────────────────────────────────────────────────────────────
  ToolEntry(
    id: 'resize',
    icon: Icons.photo_size_select_large_rounded,
    route: '/resize',
    accentColor: Color(0xFF00E5CC),
    category: ToolCategory.refine,
  ),
  ToolEntry(
    id: 'crop',
    icon: Icons.crop_rounded,
    route: '/crop',
    accentColor: Color(0xFFFF5CAA),
    category: ToolCategory.refine,
  ),
  ToolEntry(
    id: 'text_overlay',
    icon: Icons.text_fields_rounded,
    route: '/text-overlay',
    accentColor: Color(0xFF4CAF50),
    category: ToolCategory.refine,
  ),
  ToolEntry(
    id: 'optimize',
    icon: Icons.compress_rounded,
    route: '/optimize',
    accentColor: Color(0xFFFFB800),
    category: ToolCategory.refine,
  ),
  ToolEntry(
    id: 'effects',
    icon: Icons.auto_awesome_rounded,
    route: '/effects',
    accentColor: Color(0xFF9C27B0),
    category: ToolCategory.refine,
  ),
  ToolEntry(
    id: 'to_webm',
    icon: Icons.video_settings_rounded,
    route: '/to-webm',
    accentColor: Color(0xFF7C9EFF),
    category: ToolCategory.refine,
  ),
];

bool _platformAllows(ToolEntry t) => !t.windowsOnly || Platform.isWindows;

/// Tools shown as large featured cards.
List<ToolEntry> get createTools => toolCatalog
    .where((t) => t.category == ToolCategory.create && _platformAllows(t))
    .toList();

/// Tools shown in the compact refine grid.
List<ToolEntry> get refineTools => toolCatalog
    .where((t) => t.category == ToolCategory.refine && _platformAllows(t))
    .toList();
