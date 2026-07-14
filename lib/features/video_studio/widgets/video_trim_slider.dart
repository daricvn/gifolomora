import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

enum _TrimHandle { start, end, seek }

/// Combined seekbar + range-trim slider.
/// Drag the left/right brackets to set in/out points.
/// Drag the white circle to seek. Tap anywhere to seek.
class VideoTrimSlider extends StatefulWidget {
  const VideoTrimSlider({
    super.key,
    required this.totalMs,
    required this.startMs,
    required this.endMs,
    required this.positionMs,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onSeek,
  });

  final int totalMs;
  final int startMs;
  final int endMs;
  final int positionMs;
  final void Function(int ms) onStartChanged;
  final void Function(int ms) onEndChanged;
  final void Function(int ms) onSeek;

  @override
  State<VideoTrimSlider> createState() => _VideoTrimSliderState();
}

class _VideoTrimSliderState extends State<VideoTrimSlider> {
  _TrimHandle _active = _TrimHandle.seek;
  double _w = 1;

  double _toX(int ms) {
    if (widget.totalMs <= 0) return 0;
    return (ms / widget.totalMs).clamp(0.0, 1.0) * _w;
  }

  int _toMs(double x) {
    if (widget.totalMs <= 0 || _w <= 0) return 0;
    return ((x / _w) * widget.totalMs).round().clamp(0, widget.totalMs);
  }

  _TrimHandle _hitTest(Offset pos) {
    const kR = 24.0;
    final sx = _toX(widget.startMs);
    final ex = _toX(widget.endMs);
    if ((pos.dx - sx).abs() < kR) return _TrimHandle.start;
    if ((pos.dx - ex).abs() < kR) return _TrimHandle.end;
    return _TrimHandle.seek;
  }

  void _apply(double x) {
    final ms = _toMs(x.clamp(0, _w));
    switch (_active) {
      case _TrimHandle.start:
        widget.onStartChanged(ms.clamp(0, math.max(0, widget.endMs - 1000)));
      case _TrimHandle.end:
        widget.onEndChanged(ms.clamp(widget.startMs + 1000, widget.totalMs));
      case _TrimHandle.seek:
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
            AppLocalizations.of(context)!.studioTrimUnavailable,
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
          painter: _TrimPainter(
            totalMs: widget.totalMs,
            startMs: widget.startMs,
            endMs: widget.endMs,
            positionMs: widget.positionMs.clamp(0, widget.totalMs),
          ),
          size: Size(_w, 68),
        ),
      );
    });
  }
}

class _TrimPainter extends CustomPainter {
  const _TrimPainter({
    required this.totalMs,
    required this.startMs,
    required this.endMs,
    required this.positionMs,
  });

  final int totalMs;
  final int startMs;
  final int endMs;
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
    final sx = _x(startMs, w);
    final ex = _x(endMs, w);
    final px = _x(positionMs, w);

    // Full track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, cy - trackH / 2, w, cy + trackH / 2),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x22FFFFFF),
    );

    // Outside-range dim overlay (tighter bars left/right of brackets)
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.4);
    if (sx > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(0, cy - rangeH, sx, cy + rangeH),
          const Radius.circular(2),
        ),
        dimPaint,
      );
    }
    if (ex < w) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(ex, cy - rangeH, w, cy + rangeH),
          const Radius.circular(2),
        ),
        dimPaint,
      );
    }

    // Range fill
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(sx, cy - rangeH / 2, ex, cy + rangeH / 2),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF6D5DF6).withValues(alpha: 0.7),
    );

    // Left bracket
    _drawBracket(canvas, sx, cy, bracketW, bracketH, const Color(0xFF00C2FF));

    // Right bracket
    _drawBracket(canvas, ex, cy, bracketW, bracketH, const Color(0xFF00C2FF));

    // Seek thumb shadow
    canvas.drawCircle(
      Offset(px, cy),
      seekR + 2,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Seek thumb body
    canvas.drawCircle(Offset(px, cy), seekR, Paint()..color = Colors.white);

    // Seek thumb center accent
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
  bool shouldRepaint(_TrimPainter old) =>
      old.totalMs != totalMs ||
      old.startMs != startMs ||
      old.endMs != endMs ||
      old.positionMs != positionMs;
}
