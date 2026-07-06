import 'package:screen_retriever/screen_retriever.dart';

/// One capturable monitor, in **physical** pixels (gdigrab's coordinate
/// space) derived from screen_retriever's logical-px [Display].
///
/// DPI trap: screen_retriever reports logical coordinates; gdigrab wants
/// physical pixels. `physical = logical × scaleFactor`, applied per-display
/// since each monitor can have its own scale factor.
///
/// Windows quirk (screen_retriever 0.1.9): every [Display.id] is hardcoded
/// to `0` by the bundled native plugin, so it cannot identify a monitor.
/// [name] (the raw Win32 device string, e.g. `\\.\DISPLAY1`) is the only
/// value the plugin gives that's actually unique per monitor — used here
/// for persistence (`RecordSettings.lastDisplayId`) and primary matching.
class RecordTarget {
  const RecordTarget({
    required this.index,
    required this.name,
    required this.label,
    required this.physicalX,
    required this.physicalY,
    required this.physicalW,
    required this.physicalH,
    required this.isPrimary,
  });

  /// Position in the enumeration list at the time of the call. Not stable
  /// across enumerations (a monitor unplugged/replugged can reorder) —
  /// [name] is the stable identity.
  final int index;

  /// Win32 device name (e.g. `\\.\DISPLAY1`). Stable per physical monitor
  /// across enumerations on the same machine.
  final String name;

  /// User-facing label, e.g. "Display 1 (Primary)".
  final String label;

  final int physicalX;
  final int physicalY;
  final int physicalW;
  final int physicalH;
  final bool isPrimary;

  /// Maps a [Display] (logical px) to physical px. [visiblePosition] is used
  /// as the monitor-position proxy — screen_retriever exposes the work area
  /// position, not the full monitor rect, so a taskbar docked on the top/left
  /// edge of this monitor introduces a small offset error. [size] is the
  /// full monitor size (logical), scaled to physical and clamped to even
  /// (yuv420p requirement).
  factory RecordTarget.fromDisplay(
    Display d, {
    required int index,
    required bool isPrimary,
  }) {
    final scale = (d.scaleFactor ?? 1).toDouble();
    final vx = d.visiblePosition?.dx ?? 0;
    final vy = d.visiblePosition?.dy ?? 0;
    final w = d.size.width;
    final h = d.size.height;
    final physicalW = ((w * scale).round() ~/ 2) * 2;
    final physicalH = ((h * scale).round() ~/ 2) * 2;
    final name = (d.name == null || d.name!.isEmpty)
        ? 'display-$index'
        : d.name!;
    return RecordTarget(
      index: index,
      name: name,
      label: 'Display ${index + 1}${isPrimary ? ' (Primary)' : ''}',
      physicalX: (vx * scale).round(),
      physicalY: (vy * scale).round(),
      physicalW: physicalW,
      physicalH: physicalH,
      isPrimary: isPrimary,
    );
  }
}
