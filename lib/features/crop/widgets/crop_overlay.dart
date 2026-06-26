import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

const _kHandleRadius = 12.0;
const _kMinFraction = 0.08;

enum _Handle { topLeft, topRight, bottomLeft, bottomRight, body, none }

class CropOverlay extends StatefulWidget {
  const CropOverlay({
    super.key,
    required this.file,
    required this.imageWidth,
    required this.imageHeight,
    required this.onCropChanged,
    this.initialCrop = const Rect.fromLTWH(0, 0, 1, 1),
  });

  final File file;
  final int imageWidth;
  final int imageHeight;
  final Rect initialCrop; // normalized 0..1
  final void Function(Rect) onCropChanged;

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  late Rect _crop;
  _Handle _active = _Handle.none;
  Offset? _lastPos;

  @override
  void initState() {
    super.initState();
    _crop = widget.initialCrop;
  }

  Rect _imageRect(Size container) {
    if (widget.imageWidth <= 0 || widget.imageHeight <= 0) {
      return Rect.fromLTWH(0, 0, container.width, container.height);
    }
    final scale = math.min(
      container.width / widget.imageWidth,
      container.height / widget.imageHeight,
    );
    final w = widget.imageWidth * scale;
    final h = widget.imageHeight * scale;
    return Rect.fromLTWH(
      (container.width - w) / 2,
      (container.height - h) / 2,
      w,
      h,
    );
  }

  Rect _toPixels(Rect imgRect) => Rect.fromLTRB(
        imgRect.left + _crop.left * imgRect.width,
        imgRect.top + _crop.top * imgRect.height,
        imgRect.left + _crop.right * imgRect.width,
        imgRect.top + _crop.bottom * imgRect.height,
      );

  _Handle _hitTest(Offset pos, Rect cropPx) {
    final corners = {
      _Handle.topLeft: cropPx.topLeft,
      _Handle.topRight: cropPx.topRight,
      _Handle.bottomLeft: cropPx.bottomLeft,
      _Handle.bottomRight: cropPx.bottomRight,
    };
    for (final e in corners.entries) {
      if ((pos - e.value).distance < _kHandleRadius * 2.5) return e.key;
    }
    if (cropPx.contains(pos)) return _Handle.body;
    return _Handle.none;
  }

  void _panStart(DragStartDetails d, Size sz) {
    final imgRect = _imageRect(sz);
    final cropPx = _toPixels(imgRect);
    _active = _hitTest(d.localPosition, cropPx);
    _lastPos = d.localPosition;
  }

  void _panUpdate(DragUpdateDetails d, Size sz) {
    if (_active == _Handle.none || _lastPos == null) return;
    final imgRect = _imageRect(sz);
    final delta = d.localPosition - _lastPos!;
    _lastPos = d.localPosition;
    final dx = delta.dx / imgRect.width;
    final dy = delta.dy / imgRect.height;

    setState(() {
      double l = _crop.left, t = _crop.top, r = _crop.right, b = _crop.bottom;
      switch (_active) {
        case _Handle.topLeft:
          l = (l + dx).clamp(0.0, r - _kMinFraction);
          t = (t + dy).clamp(0.0, b - _kMinFraction);
        case _Handle.topRight:
          r = (r + dx).clamp(l + _kMinFraction, 1.0);
          t = (t + dy).clamp(0.0, b - _kMinFraction);
        case _Handle.bottomLeft:
          l = (l + dx).clamp(0.0, r - _kMinFraction);
          b = (b + dy).clamp(t + _kMinFraction, 1.0);
        case _Handle.bottomRight:
          r = (r + dx).clamp(l + _kMinFraction, 1.0);
          b = (b + dy).clamp(t + _kMinFraction, 1.0);
        case _Handle.body:
          final w = r - l, h = b - t;
          l = (l + dx).clamp(0.0, 1.0 - w);
          t = (t + dy).clamp(0.0, 1.0 - h);
          r = l + w;
          b = t + h;
        case _Handle.none:
          break;
      }
      _crop = Rect.fromLTRB(l, t, r, b);
    });
    widget.onCropChanged(_crop);
  }

  void _panEnd(DragEndDetails _) {
    _active = _Handle.none;
    _lastPos = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final sz = Size(constraints.maxWidth, constraints.maxHeight);
      final imgRect = _imageRect(sz);
      final cropPx = _toPixels(imgRect);

      return GestureDetector(
        onPanStart: (d) => _panStart(d, sz),
        onPanUpdate: (d) => _panUpdate(d, sz),
        onPanEnd: _panEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(widget.file, fit: BoxFit.contain, gaplessPlayback: true),
            CustomPaint(
              painter: _CropPainter(cropPx: cropPx, containerSize: sz),
            ),
          ],
        ),
      );
    });
  }
}

class _CropPainter extends CustomPainter {
  const _CropPainter({required this.cropPx, required this.containerSize});
  final Rect cropPx;
  final Size containerSize;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, cropPx.top), overlay);
    canvas.drawRect(Rect.fromLTRB(0, cropPx.top, cropPx.left, cropPx.bottom), overlay);
    canvas.drawRect(Rect.fromLTRB(cropPx.right, cropPx.top, size.width, cropPx.bottom), overlay);
    canvas.drawRect(Rect.fromLTRB(0, cropPx.bottom, size.width, size.height), overlay);

    // rule-of-thirds grid
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    final tw = cropPx.width / 3;
    final th = cropPx.height / 3;
    canvas.drawLine(Offset(cropPx.left + tw, cropPx.top), Offset(cropPx.left + tw, cropPx.bottom), grid);
    canvas.drawLine(Offset(cropPx.left + tw * 2, cropPx.top), Offset(cropPx.left + tw * 2, cropPx.bottom), grid);
    canvas.drawLine(Offset(cropPx.left, cropPx.top + th), Offset(cropPx.right, cropPx.top + th), grid);
    canvas.drawLine(Offset(cropPx.left, cropPx.top + th * 2), Offset(cropPx.right, cropPx.top + th * 2), grid);

    // border
    canvas.drawRect(
      cropPx,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // corner handles
    final handle = Paint()..color = AppColors.accentB;
    for (final corner in [
      cropPx.topLeft, cropPx.topRight, cropPx.bottomLeft, cropPx.bottomRight,
    ]) {
      canvas.drawCircle(corner, _kHandleRadius, Paint()..color = Colors.black.withValues(alpha: 0.4));
      canvas.drawCircle(corner, _kHandleRadius - 2, handle);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.cropPx != cropPx || old.containerSize != containerSize;
}
