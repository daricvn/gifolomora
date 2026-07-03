import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/theme/app_colors.dart';

const _kHandleRadius = 12.0;
const _kMinFraction = 0.08;
// Wall-clock advance per gif playback tick (ms). Not vsync-locked — this
// drives a preview scrubber, not the exported frame timing.
const _kGifTickMs = 33;

/// Margin reserved around the video while cropping so corner handles render
/// fully inside the (clipped) preview and stay grabbable past the video edge.
const _kCropInset = _kHandleRadius + 4;

enum _Handle { topLeft, topRight, bottomLeft, bottomRight, body, none }

/// Allows the parent to seek/play/pause the embedded player from outside.
class VideoPreviewController {
  _VideoPreviewState? _state;

  /// Live play/pause state of the player (true while playing). GIFs report
  /// false since they aren't player-driven.
  final ValueNotifier<bool> playing = ValueNotifier(false);

  void _attach(_VideoPreviewState s) => _state = s;
  void _detach() => _state = null;
  void seekTo(int ms) => _state?._seekTo(ms);
  void togglePlay() => _state?._togglePlay();
  void dispose() => playing.dispose();
}

class VideoPreview extends StatefulWidget {
  const VideoPreview({
    super.key,
    required this.file,
    required this.videoWidth,
    required this.videoHeight,
    this.speedRate = 1.0,
    this.volume = 1.0,
    this.cropRect,
    this.onCropChanged,
    this.interactive = true,
    this.controller,
    this.onPositionChanged,
    this.trimStartMs = 0,
    this.trimEndMs = 0,
  });

  final File file;
  final int videoWidth;
  final int videoHeight;
  final double speedRate;

  /// Audio gain multiplier (1.0 = 100%). Applied live to the preview player.
  final double volume;
  final Rect? cropRect;
  final void Function(Rect)? onCropChanged;

  /// When false the crop overlay is painted but not draggable.
  final bool interactive;

  /// Optional controller to seek the player from outside.
  final VideoPreviewController? controller;

  /// Called on every player position tick (ms).
  final void Function(int ms)? onPositionChanged;

  /// Preview loops within [trimStartMs, trimEndMs]. 0 = no boundary.
  final int trimStartMs;
  final int trimEndMs;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late final Player _player;
  late final VideoController _videoController;

  bool _initialized = false;
  String? _activePath;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<bool>? _playingSub;

  /// Animated GIFs are decoded frame-by-frame below (not handed to libmpv,
  /// which only renders the first frame of a GIF).
  bool get _isAnimatedImage => widget.file.path.toLowerCase().endsWith('.gif');

  // ── Animated-gif playback (frame-array, so seek/trim are real operations
  // instead of riding the image's own free-running loop) ────────────────────
  // ponytail: decodes every frame eagerly — fine for social-sized gifs (the
  // studio caps baked gifs at 60s); bound frame count or window the decode if
  // this ever needs to handle much larger loaded files.
  List<ui.Image> _gifFrames = const [];
  List<int> _gifFrameEndMs = const [];
  int _gifTotalMs = 0;
  int _gifPosMs = 0;
  Timer? _gifTicker;
  int _gifLoadToken = 0;

  Rect _crop = const Rect.fromLTWH(0, 0, 1, 1);
  _Handle _active = _Handle.none;
  Offset? _lastPos;

  @override
  void initState() {
    super.initState();
    _crop = widget.cropRect ?? const Rect.fromLTWH(0, 0, 1, 1);
    _player = Player();
    _videoController = VideoController(_player);
    widget.controller?._attach(this);
    _openFile();
  }

  @override
  void didUpdateWidget(VideoPreview old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._detach();
      widget.controller?._attach(this);
    }
    if (old.file.path != widget.file.path) {
      _openFile();
    }
    if (!_isAnimatedImage && old.speedRate != widget.speedRate) {
      _player.setRate(widget.speedRate);
    }
    if (!_isAnimatedImage && old.volume != widget.volume) {
      _player.setVolume((widget.volume * 100).clamp(0.0, 200.0));
    }
    if (widget.cropRect != null && widget.cropRect != _crop) {
      setState(() => _crop = widget.cropRect!);
    }
    if (!_isAnimatedImage &&
        (old.trimStartMs != widget.trimStartMs ||
            old.trimEndMs != widget.trimEndMs)) {
      final cur = _player.state.position.inMilliseconds;
      final end = widget.trimEndMs;
      if (cur < widget.trimStartMs || (end > 0 && cur >= end)) {
        _seekTo(widget.trimStartMs);
      }
    }
    if (_isAnimatedImage &&
        (old.trimStartMs != widget.trimStartMs ||
            old.trimEndMs != widget.trimEndMs)) {
      final end = widget.trimEndMs > 0 ? widget.trimEndMs : _gifTotalMs;
      if (_gifPosMs < widget.trimStartMs || (end > 0 && _gifPosMs >= end)) {
        // Deferred: _seekTo fires onPositionChanged synchronously, which
        // calls setState on the ancestor (video_studio_screen) — doing that
        // inline here would hit it mid-rebuild (this runs from that same
        // rebuild's didUpdateWidget cascade) and throw "setState() or
        // markNeedsBuild() called during build."
        final target = widget.trimStartMs;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _seekTo(target);
        });
      }
    }
  }

  Future<void> _openFile() async {
    // GIFs are decoded frame-by-frame below; never hand them to libmpv.
    if (_isAnimatedImage) {
      await _openGif();
      return;
    }
    _activePath = widget.file.path;
    _positionSub?.cancel();
    _completedSub?.cancel();
    _playingSub?.cancel();
    if (mounted) setState(() => _initialized = false);
    try {
      // Subscribe before open() — stream.playing is a plain broadcast piped
      // through distinct() with no replay, so the play:true edge fired during
      // open() is lost if we listen after. Missing it leaves the controller's
      // playing flag stuck false (icon never flips, controls never auto-hide).
      _playingSub = _player.stream.playing.listen((p) {
        widget.controller?.playing.value = p;
      });
      await _player.open(Media(widget.file.path), play: true);
      // Manual loop so we can enforce trim boundaries on restart.
      await _player.setPlaylistMode(PlaylistMode.none);
      await _player.setRate(widget.speedRate);
      await _player.setVolume((widget.volume * 100).clamp(0.0, 200.0));
      if (widget.trimStartMs > 0) {
        await _player.seek(Duration(milliseconds: widget.trimStartMs));
      }
      _positionSub = _player.stream.position.listen((pos) {
        final ms = pos.inMilliseconds;
        widget.onPositionChanged?.call(ms);
        final end = widget.trimEndMs;
        if (end > 0 && ms >= end) {
          _player.seek(Duration(milliseconds: widget.trimStartMs));
        }
      });
      // Natural end-of-file: restart from trimStartMs.
      _completedSub = _player.stream.completed.listen((done) {
        if (done) {
          _player
              .seek(Duration(milliseconds: widget.trimStartMs))
              .then((_) => _player.play());
        }
      });
      if (mounted && _activePath == widget.file.path) {
        setState(() => _initialized = true);
      }
    } catch (_) {
      if (mounted) setState(() => _initialized = false);
    }
  }

  Future<void> _openGif() async {
    final token = ++_gifLoadToken;
    _gifTicker?.cancel();
    _disposeGifFrames();
    if (mounted) setState(() => _initialized = false);
    try {
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frames = <ui.Image>[];
      final endMs = <int>[];
      var cum = 0;
      for (var i = 0; i < codec.frameCount; i++) {
        final info = await codec.getNextFrame();
        if (token != _gifLoadToken) {
          info.image.dispose();
          continue;
        }
        frames.add(info.image);
        cum += info.duration.inMilliseconds;
        endMs.add(cum);
      }
      if (token != _gifLoadToken || !mounted) {
        for (final f in frames) {
          f.dispose();
        }
        return;
      }
      _gifFrames = frames;
      _gifFrameEndMs = endMs;
      _gifTotalMs = cum;
      _gifPosMs = widget.trimStartMs.clamp(0, cum);
      setState(() => _initialized = true);
      widget.onPositionChanged?.call(_gifPosMs);
      _gifTicker = Timer.periodic(
          const Duration(milliseconds: _kGifTickMs), (_) => _tickGif());
    } catch (_) {
      if (mounted) setState(() => _initialized = false);
    }
  }

  void _tickGif() {
    if (!mounted || _gifFrames.isEmpty) return;
    final total = _gifTotalMs;
    final end = widget.trimEndMs > 0 ? widget.trimEndMs.clamp(0, total) : total;
    final start = widget.trimStartMs.clamp(0, end);
    var pos = _gifPosMs + _kGifTickMs;
    if (end <= start) {
      pos = start;
    } else if (pos >= end) {
      pos = start + (pos - end) % (end - start);
    }
    setState(() => _gifPosMs = pos);
    widget.onPositionChanged?.call(pos);
  }

  int _gifFrameIndexFor(int posMs) {
    if (_gifFrameEndMs.isEmpty) return 0;
    var lo = 0, hi = _gifFrameEndMs.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_gifFrameEndMs[mid] <= posMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _disposeGifFrames() {
    for (final f in _gifFrames) {
      f.dispose();
    }
    _gifFrames = const [];
    _gifFrameEndMs = const [];
    _gifTotalMs = 0;
  }

  void _seekTo(int ms) {
    if (_isAnimatedImage) {
      if (_gifTotalMs <= 0) return;
      final clamped = ms.clamp(0, _gifTotalMs);
      setState(() => _gifPosMs = clamped);
      widget.onPositionChanged?.call(clamped);
      return;
    }
    _player.seek(Duration(milliseconds: ms));
  }

  void _togglePlay() {
    if (_isAnimatedImage) return;
    _player.playOrPause();
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _positionSub?.cancel();
    _completedSub?.cancel();
    _playingSub?.cancel();
    _gifTicker?.cancel();
    _disposeGifFrames();
    _player.dispose();
    super.dispose();
  }

  // ── Crop overlay geometry (mirrors crop_overlay.dart math) ─────────────

  /// While cropping, the frame is drawn inset so corner handles keep a
  /// grabbable margin on every side, all inside the (opaque) gesture box.
  double get _cropInset => widget.cropRect != null ? _kCropInset : 0.0;

  Rect _imageRect(Size sz) {
    final inset = _cropInset;
    final aw = math.max(1.0, sz.width - inset * 2);
    final ah = math.max(1.0, sz.height - inset * 2);
    if (widget.videoWidth <= 0 || widget.videoHeight <= 0) {
      return Rect.fromLTWH(inset, inset, aw, ah);
    }
    final scale = math.min(aw / widget.videoWidth, ah / widget.videoHeight);
    final w = widget.videoWidth * scale;
    final h = widget.videoHeight * scale;
    return Rect.fromLTWH(
      (sz.width - w) / 2,
      (sz.height - h) / 2,
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
    widget.onCropChanged?.call(_crop);
  }

  void _panEnd(DragEndDetails _) {
    _active = _Handle.none;
    _lastPos = null;
  }

  @override
  Widget build(BuildContext context) {
    final showCrop = widget.cropRect != null;
    final canDrag = widget.interactive && widget.onCropChanged != null;
    final ar = widget.videoWidth > 0 && widget.videoHeight > 0
        ? widget.videoWidth / widget.videoHeight.toDouble()
        : 16 / 9.0;

    return AspectRatio(
      aspectRatio: ar,
      child: LayoutBuilder(builder: (context, constraints) {
        final sz = Size(constraints.maxWidth, constraints.maxHeight);
        final imgRect = _imageRect(sz);
        final cropPx = _toPixels(imgRect);

        final Widget media;
        if (_isAnimatedImage) {
          media = _gifFrames.isEmpty
              ? const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accentB),
                  ),
                )
              : RawImage(
                  image: _gifFrames[_gifFrameIndexFor(_gifPosMs)
                      .clamp(0, _gifFrames.length - 1)],
                  fit: BoxFit.contain,
                );
        } else if (_initialized) {
          media = Video(controller: _videoController, controls: NoVideoControls);
        } else {
          media = const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accentB),
            ),
          );
        }

        return GestureDetector(
          // Opaque so pans land anywhere in the box, incl. the handle margin.
          behavior: HitTestBehavior.opaque,
          onPanStart: showCrop && canDrag ? (d) => _panStart(d, sz) : null,
          onPanUpdate: showCrop && canDrag ? (d) => _panUpdate(d, sz) : null,
          onPanEnd: showCrop && canDrag ? _panEnd : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Frame drawn exactly at imgRect so normalized crop maps 1:1 to
              // real pixels; the inset leaves margin around the handles.
              Positioned.fromRect(rect: imgRect, child: media),
              if (showCrop)
                Positioned.fill(
                  child: CustomPaint(
                    painter:
                        _VideoCropPainter(cropPx: cropPx, containerSize: sz),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _VideoCropPainter extends CustomPainter {
  const _VideoCropPainter({required this.cropPx, required this.containerSize});
  final Rect cropPx;
  final Size containerSize;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, cropPx.top), overlay);
    canvas.drawRect(
        Rect.fromLTRB(0, cropPx.top, cropPx.left, cropPx.bottom), overlay);
    canvas.drawRect(
        Rect.fromLTRB(cropPx.right, cropPx.top, size.width, cropPx.bottom),
        overlay);
    canvas.drawRect(
        Rect.fromLTRB(0, cropPx.bottom, size.width, size.height), overlay);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    final tw = cropPx.width / 3;
    final th = cropPx.height / 3;
    canvas.drawLine(Offset(cropPx.left + tw, cropPx.top),
        Offset(cropPx.left + tw, cropPx.bottom), grid);
    canvas.drawLine(Offset(cropPx.left + tw * 2, cropPx.top),
        Offset(cropPx.left + tw * 2, cropPx.bottom), grid);
    canvas.drawLine(Offset(cropPx.left, cropPx.top + th),
        Offset(cropPx.right, cropPx.top + th), grid);
    canvas.drawLine(Offset(cropPx.left, cropPx.top + th * 2),
        Offset(cropPx.right, cropPx.top + th * 2), grid);

    canvas.drawRect(
      cropPx,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    final handle = Paint()..color = AppColors.accentB;
    for (final corner in [
      cropPx.topLeft,
      cropPx.topRight,
      cropPx.bottomLeft,
      cropPx.bottomRight,
    ]) {
      canvas.drawCircle(corner, _kHandleRadius,
          Paint()..color = Colors.black.withValues(alpha: 0.4));
      canvas.drawCircle(corner, _kHandleRadius - 2, handle);
    }
  }

  @override
  bool shouldRepaint(_VideoCropPainter old) =>
      old.cropPx != cropPx || old.containerSize != containerSize;
}
