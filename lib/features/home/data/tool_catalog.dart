import 'package:flutter/material.dart';

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
    required this.label,
    required this.description,
    required this.icon,
    required this.route,
    required this.accentColor,
    required this.category,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final String route;
  final Color accentColor;
  final ToolCategory category;
}

const List<ToolEntry> toolCatalog = [
  // ── Create ──────────────────────────────────────────────────────────────
  ToolEntry(
    id: 'video_studio',
    label: 'Video Studio',
    description: 'Crop, resize & speed — export as video or GIF',
    icon: Icons.movie_creation_rounded,
    route: '/video-studio',
    accentColor: Color(0xFFFF8C00),
    category: ToolCategory.create,
  ),
  ToolEntry(
    id: 'images_to_gif',
    label: 'Images → GIF',
    description: 'Stitch a sequence of frames into a smooth loop',
    icon: Icons.photo_library_rounded,
    route: '/images-to-gif',
    accentColor: Color(0xFF00C2FF),
    category: ToolCategory.create,
  ),

  // ── Refine ──────────────────────────────────────────────────────────────
  ToolEntry(
    id: 'resize',
    label: 'Resize',
    description: 'Scale to any resolution or preset',
    icon: Icons.photo_size_select_large_rounded,
    route: '/resize',
    accentColor: Color(0xFF00E5CC),
    category: ToolCategory.refine,
  ),
  ToolEntry(
    id: 'crop',
    label: 'Crop',
    description: 'Trim the frame with a draggable rect',
    icon: Icons.crop_rounded,
    route: '/crop',
    accentColor: Color(0xFFFF5CAA),
    category: ToolCategory.refine,
  ),
  ToolEntry(
    id: 'text_overlay',
    label: 'Text Overlay',
    description: 'Add styled captions to any GIF',
    icon: Icons.text_fields_rounded,
    route: '/text-overlay',
    accentColor: Color(0xFF4CAF50),
    category: ToolCategory.refine,
  ),
  ToolEntry(
    id: 'optimize',
    label: 'Optimize',
    description: 'Compress for the smallest file size',
    icon: Icons.compress_rounded,
    route: '/optimize',
    accentColor: Color(0xFFFFB800),
    category: ToolCategory.refine,
  ),
  ToolEntry(
    id: 'effects',
    label: 'Effects',
    description: 'Reverse or change playback speed',
    icon: Icons.auto_awesome_rounded,
    route: '/effects',
    accentColor: Color(0xFF9C27B0),
    category: ToolCategory.refine,
  ),
];

/// Tools shown as large featured cards.
List<ToolEntry> get createTools =>
    toolCatalog.where((t) => t.category == ToolCategory.create).toList();

/// Tools shown in the compact refine grid.
List<ToolEntry> get refineTools =>
    toolCatalog.where((t) => t.category == ToolCategory.refine).toList();
