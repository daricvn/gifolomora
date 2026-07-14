import 'package:flutter/material.dart';

import '../../../core/services/ffmpeg/ffmpeg_command.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

enum _CutHandle { pendingStart, pendingEnd, seek }

/// Combined seekbar + cut-range picker.
/// Shows the full video timeline with:
///   - outside-trim region dimmed (non-interactive)
///   - existing cutSegments as red filled blocks
///   - pending range as two orange draggable brackets (clamped to trim window)
///   - seek thumb (white circle)
class CutSegmentSlider extends StatefulWidget {
  const CutSegmentSlider({
    super.key,
    required this.totalMs,
    required this.trimStartMs,
    required this.trimEndMs,
    required this.cutSegments,
    required this.pendingStartMs,
    required this.pendingEndMs,
    required this.positionMs,
    required this.onPendingChanged,
    required this.onSeek,
  });

  final int totalMs;
  final int trimStartMs;
  final int trimEndMs;
  final List<CutSegment> cutSegments;
  final int pendingStartMs;
  final int pendingEndMs;
  final int positionMs;
  final void Function(int start, int end) onPendingChanged;
  final void Function(int ms) onSeek;

  @override
  State<CutSegmentSlider> createState() => _CutSegmentSliderState();
}

class _CutSegmentSliderState extends State<CutSegmentSlider> {
  _CutHandle _active = _CutHandle.seek;
  double _w = 1;

  double _toX(int ms) {
    if (widget.totalMs <= 0) return 0;
    return (ms / widget.totalMs).clamp(0.0, 1.0) * _w;
  }

  int _toMs(double x) {
    if (widget.totalMs <= 0 || _w <= 0) return 0;
    return ((x / _w) * widget.totalMs).round().clamp(0, widget.totalMs);
  }

  _CutHandle _hitTest(Offset pos) {
    const kR = 24.0;
    final sx = _toX(widget.pendingStartMs);
    final ex = _toX(widget.pendingEndMs);
    if ((pos.dx - sx).abs() < kR) return _CutHandle.pendingStart;
    if ((pos.dx - ex).abs() < kR) return _CutHandle.pendingEnd;
    return _CutHandle.seek;
  }

  void _apply(double x) {
    final lo = widget.trimStartMs;
    final hi = widget.trimEndMs;
    final ms = _toMs(x.clamp(0, _w)).clamp(lo, hi);
    switch (_active) {
      case _CutHandle.pendingStart:
        final cap = widget.pendingEndMs > lo + 1 ? widget.pendingEndMs - 1 : lo;
        final newStart = ms.clamp(lo, cap);
        final newEnd = newStart < widget.pendingEndMs ? widget.pendingEndMs : newStart + 1;
        widget.onPendingChanged(newStart, newEnd.clamp(lo, hi));
      case _CutHandle.pendingEnd:
        final floor = widget.pendingStartMs < hi - 1 ? widget.pendingStartMs + 1 : hi;
        final newEnd = ms.clamp(floor, hi);
        final newStart = newEnd > widget.pendingStartMs ? widget.pendingStartMs : newEnd - 1;
        widget.onPendingChanged(newStart.clamp(lo, hi), newEnd);
      case _CutHandle.seek:
        widget.onSeek(ms);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalMs <= 0) {
      return SizedBox(
        height: 72,
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.studioCutUnavailable,
            style: const TextStyle(color: AppColors.textLo, fontSize: 12),
          ),
        ),
      );
    }
    return LayoutBuilder(builder: (_, constraints) {
      _w = constraints.maxWidth;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _active = _hitTest(e.localPosition);
          _apply(e.localPosition.dx);
        },
        onPointerMove: (e) => _apply(e.localPosition.dx),
        onPointerUp: (_) {},
        onPointerCancel: (_) {},
        child: CustomPaint(
          painter: _CutSliderPainter(
            totalMs: widget.totalMs,
            trimStartMs: widget.trimStartMs,
            trimEndMs: widget.trimEndMs,
            cutSegments: widget.cutSegments,
            pendingStartMs: widget.pendingStartMs,
            pendingEndMs: widget.pendingEndMs,
            positionMs: widget.positionMs.clamp(0, widget.totalMs),
          ),
          size: Size(_w, 68),
        ),
      );
    });
  }
}

class _CutSliderPainter extends CustomPainter {
  const _CutSliderPainter({
    required this.totalMs,
    required this.trimStartMs,
    required this.trimEndMs,
    required this.cutSegments,
    required this.pendingStartMs,
    required this.pendingEndMs,
    required this.positionMs,
  });

  final int totalMs;
  final int trimStartMs;
  final int trimEndMs;
  final List<CutSegment> cutSegments;
  final int pendingStartMs;
  final int pendingEndMs;
  final int positionMs;

  double _x(int ms, double w) =>
      totalMs > 0 ? (ms / totalMs).clamp(0.0, 1.0) * w : 0;

  @override
  void paint(Canvas canvas, Size size) {
    const cy = 34.0;
    const trackH = 3.0;
    const rangeH = 5.0;
    const bracketW = 5.0;
    const bracketH = 42.0;
    const seekR = 8.0;

    final w = size.width;
    final tsx = _x(trimStartMs, w);
    final tex = _x(trimEndMs, w);
    final px = _x(positionMs, w);

    // Full track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, cy - trackH / 2, w, cy + trackH / 2),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x22FFFFFF),
    );

    // Outside trim window (dimmed, non-interactive)
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.4);
    if (tsx > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(0, cy - rangeH, tsx, cy + rangeH),
          const Radius.circular(2),
        ),
        dimPaint,
      );
    }
    if (tex < w) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(tex, cy - rangeH, w, cy + rangeH),
          const Radius.circular(2),
        ),
        dimPaint,
      );
    }

    // Trim window background fill (subtle purple)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(tsx, cy - rangeH / 2, tex, cy + rangeH / 2),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF6D5DF6).withValues(alpha: 0.25),
    );

    // Existing cut segments (red blocks)
    final cutPaint = Paint()..color = Colors.red.withValues(alpha: 0.6);
    for (final seg in cutSegments) {
      final sx = _x(seg.startMs, w);
      final ex = _x(seg.endMs, w);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(sx, cy - rangeH, ex, cy + rangeH),
          const Radius.circular(2),
        ),
        cutPaint,
      );
    }

    // Pending range (orange fill)
    final psx = _x(pendingStartMs, w);
    final pex = _x(pendingEndMs, w);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(psx, cy - rangeH / 2 - 1, pex, cy + rangeH / 2 + 1),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.orange.withValues(alpha: 0.45),
    );

    // Pending start bracket
    _drawBracket(canvas, psx, cy, bracketW, bracketH, Colors.orange);
    // Pending end bracket
    _drawBracket(canvas, pex, cy, bracketW, bracketH, Colors.orange);

    // Seek thumb shadow
    canvas.drawCircle(
      Offset(px, cy),
      seekR + 2,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    // Seek thumb body
    canvas.drawCircle(Offset(px, cy), seekR, Paint()..color = Colors.white);
    // Seek thumb accent
    canvas.drawCircle(
      Offset(px, cy),
      3.5,
      Paint()..color = const Color(0xFF6D5DF6),
    );
  }

  void _drawBracket(
    Canvas canvas,
    double x,
    double cy,
    double bw,
    double bh,
    Color color,
  ) {
    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - bw / 2 - 1, cy - bh / 2, x + bw / 2 + 1, cy + bh / 2),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - bw / 2, cy - bh / 2, x + bw / 2, cy + bh / 2),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
    // Horizontal nub at center
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - bw / 2 - 5, cy - 1.5, x + bw / 2 + 5, cy + 1.5),
        const Radius.circular(2),
      ),
      Paint()..color = color.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_CutSliderPainter old) =>
      old.totalMs != totalMs ||
      old.trimStartMs != trimStartMs ||
      old.trimEndMs != trimEndMs ||
      old.cutSegments != cutSegments ||
      old.pendingStartMs != pendingStartMs ||
      old.pendingEndMs != pendingEndMs ||
      old.positionMs != positionMs;
}
