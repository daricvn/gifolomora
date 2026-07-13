import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/theme/app_colors.dart';

const _kHandleRadius = 12.0;
const _kMinFraction = 0.08;
// Wall-clock advance per gif playback tick (ms). Not vsync-locked — this
// drives a preview scrubber, not the exported frame timing.
const _kGifTickMs = 33;
// Decoded preview RAM is frames × canvas W×H × 4 bytes — ui.Codec composites
// every frame to the full logical screen, so file size is no proxy (a 30MB
// 1280×720 21fps bake decodes to >1GB). Under the budget: decode every frame
// upfront (fast path). Over it: bounded trailing window instead of holding
// every decoded frame in memory at once.
const _kGifEagerMaxDecodedBytes = 256 * 1024 * 1024;
const _kGifLazyWindow = 30; // frames resident at once in lazy mode

/// Margin reserved around the video while cropping so corner handles render
/// fully inside the (clipped) preview and stay grabbable past the video edge.
const _kCropInset = _kHandleRadius + 4;

enum _Handle { topLeft, topRight, bottomLeft, bottomRight, body, none }

/// Header-only GIF scan (frame delays in ms + canvas size), no pixel decode:
/// `GifDecoder.startDecode` walks block headers and skips LZW data via each
/// block's own length-prefix same as a hand-rolled scanner would, so it lets
/// lazy-mode preview know the full timeline instantly instead of paying for a
/// full ui.Codec decode pass just to read frame timing.
({List<int> delaysMs, int width, int height})? _scanGifHeader(
    Uint8List bytes) {
  final info = img.GifDecoder().startDecode(bytes);
  if (info == null || info.frames.isEmpty) return null;
  return (
    delaysMs: [
      // Field is centiseconds; 0 is "as fast as possible" in the spec, which
      // every renderer treats as its own default frame delay instead.
      for (final f in info.frames) f.duration > 0 ? f.duration * 10 : 100,
    ],
    width: info.width,
    height: info.height,
  );
}

/// Disposing a ui.Image the instant it's replaced can race the rasterizer,
/// which may still be compositing the picture from the frame that just
/// painted it ("Bad state: Cannot clone a disposed image"). One frame's
/// grace is the standard safe-disposal pattern for manually-managed
/// ui.Image lifecycles.
void _disposeGifImage(ui.Image image) {
  WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
}

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
    this.softwareRender = false,
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

  /// Render video through media_kit's software (pixel-buffer) path instead of
  /// the D3D11/ANGLE hardware path — works around intermittent black flashes
  /// from the plugin's unsynchronized shared-texture pipeline on some GPUs.
  /// Read once at mount (the native player is configured in initState); a
  /// changed value takes effect the next time this widget is created.
  final bool softwareRender;

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

  /// The last _openFile call, so dispose() can be ordered after it. Disposing
  /// while open(play:true) is still in flight orphans the native player —
  /// mpv finishes the open and keeps playing audio with no Dart handle left
  /// to stop it.
  Future<void>? _openInFlight;

  /// True while the user has explicitly paused. The preview's auto-loop
  /// (trim-end snap-back, EOF restart+play) must not override it — a seek to
  /// the end fires `completed`, whose unconditional play() used to revive
  /// audio on a paused player.
  bool _pausedByUser = false;

  /// Animated GIFs are decoded frame-by-frame below (not handed to libmpv,
  /// which only renders the first frame of a GIF).
  bool get _isAnimatedImage => widget.file.path.toLowerCase().endsWith('.gif');

  // ── Animated-gif playback (frame-array, so seek/trim are real operations
  // instead of riding the image's own free-running loop) ────────────────────
  // Small/short gifs decode fully upfront into _gifFrames for instant random
  // access. Bigger+longer ones (per the header-only delay scan, no pixel
  // decode) go lazy: only a bounded trailing window (_gifLazyCache) is ever
  // resident, decoded on demand. ponytail: lazy backward-seeks restart the
  // codec from frame 0 (dart:ui can't seek), so scrubbing far back on a big
  // lazy gif re-decodes through it — acceptable for a preview, revisit if it
  // stalls.
  List<ui.Image> _gifFrames = const [];
  List<int> _gifFrameEndMs = const [];
  int _gifTotalMs = 0;
  int _gifPosMs = 0;
  Timer? _gifTicker;
  int _gifLoadToken = 0;

  bool _gifLazy = false;
  Uint8List? _gifLazyBytes;
  ui.Codec? _gifLazyCodec;
  int _gifLazyCursor = 0; // next frame index the live codec will decode
  final Map<int, ui.Image> _gifLazyCache = {};
  ui.Image? _gifLazyShown;
  bool _gifLazyFetching = false;
  int? _gifLazyPendingIdx; // latest requested frame while a fetch is in flight
  bool _gifLazyBusy = false; // debounced — only true once a fetch runs >150ms
  Timer? _gifLazyBusyDelay;

  Rect _crop = const Rect.fromLTWH(0, 0, 1, 1);
  _Handle _active = _Handle.none;
  Offset? _lastPos;

  @override
  void initState() {
    super.initState();
    _crop = widget.cropRect ?? const Rect.fromLTWH(0, 0, 1, 1);
    _player = Player();
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: !widget.softwareRender,
      ),
    );
    widget.controller?._attach(this);
    _openInFlight = _openFile();
  }

  @override
  void didUpdateWidget(VideoPreview old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._detach();
      widget.controller?._attach(this);
    }
    if (old.file.path != widget.file.path) {
      _openInFlight = _openFile();
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
      // State reused across a video->gif file swap (didUpdateWidget, same
      // State) — _player may still be open/playing the old video otherwise.
      _positionSub?.cancel();
      _completedSub?.cancel();
      _playingSub?.cancel();
      await _player.stop();
      await _openGif();
      return;
    }
    _activePath = widget.file.path;
    _positionSub?.cancel();
    _completedSub?.cancel();
    _playingSub?.cancel();
    // gif -> video swap reuses this State: kill the gif ticker (it would keep
    // firing onPositionChanged against the player's own stream) and free the
    // decoded frames.
    _gifTicker?.cancel();
    _gifLoadToken++;
    _disposeGifFrames();
    _pausedByUser = false; // new file autoplays — stale pause intent is gone
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
      // Unmounted while open() was in flight — dispose() is already waiting
      // on this future to tear the player down; don't rebuild state on top.
      if (!mounted) {
        _playingSub?.cancel();
        return;
      }
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
        if (end > 0 && ms >= end && !_pausedByUser) {
          _player.seek(Duration(milliseconds: widget.trimStartMs));
        }
      });
      // Natural end-of-file: restart from trimStartMs — but never against an
      // explicit pause (seeking to the end fires completed too).
      _completedSub = _player.stream.completed.listen((done) {
        if (done && !_pausedByUser) {
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
      // Header-only scan (no pixel decode) tells us the frame count and
      // timeline for free, so the eager/lazy split can be decided before
      // touching ui.Codec at all — a real decode pass was the actual
      // open-time stall.
      final scan = _scanGifHeader(bytes);
      final useLazy = scan != null &&
          scan.delaysMs.length * scan.width * scan.height * 4 >
              _kGifEagerMaxDecodedBytes;

      if (!useLazy) {
        // Fits the decoded-RAM budget, or the scan failed: decode every
        // frame upfront (existing fast path, also the safe fallback).
        final codec = await ui.instantiateImageCodec(bytes);
        final frames = <ui.Image>[];
        final endMs = <int>[];
        var cum = 0;
        for (var i = 0; i < codec.frameCount; i++) {
          final info = await codec.getNextFrame();
          if (token != _gifLoadToken) {
            info.image.dispose();
            for (final f in frames) {
              _disposeGifImage(f);
            }
            return;
          }
          frames.add(info.image);
          cum += info.duration.inMilliseconds;
          endMs.add(cum);
        }
        if (token != _gifLoadToken || !mounted) {
          for (final f in frames) {
            _disposeGifImage(f);
          }
          return;
        }
        _gifFrames = frames;
        _gifFrameEndMs = endMs;
        _gifTotalMs = cum;
        _gifPosMs = widget.trimStartMs.clamp(0, cum);
      } else {
        // Lazy: timeline already known from the scan — decode just the
        // frames near the start now, the rest on demand as playback needs.
        var cum = 0;
        final endMs = <int>[];
        for (final d in scan.delaysMs) {
          cum += d;
          endMs.add(cum);
        }
        _gifFrameEndMs = endMs;
        _gifTotalMs = cum;
        _gifPosMs = widget.trimStartMs.clamp(0, cum);
        _gifLazy = true;
        _gifLazyBytes = bytes;
        final lazyCodec = await ui.instantiateImageCodec(bytes);
        _gifLazyCodec = lazyCodec;
        _gifLazyCursor = 0;
        // Guard against the header scan's frame count disagreeing with
        // ui.Codec's real one (unusual/malformed gif) — without this, a
        // seek could ask the decode loop below to chase an index the
        // codec can never actually reach.
        if (lazyCodec.frameCount < endMs.length) {
          _gifFrameEndMs = endMs.sublist(0, lazyCodec.frameCount);
          _gifTotalMs = _gifFrameEndMs.isEmpty ? 0 : _gifFrameEndMs.last;
          _gifPosMs = _gifPosMs.clamp(0, _gifTotalMs);
        }
        await _seekLazyFrame(token, _gifFrameIndexFor(_gifPosMs));
      }
      if (token != _gifLoadToken || !mounted) return;
      setState(() => _initialized = true);
      widget.onPositionChanged?.call(_gifPosMs);
      _gifTicker = Timer.periodic(
          const Duration(milliseconds: _kGifTickMs), (_) => _tickGif());
    } catch (_) {
      if (mounted) setState(() => _initialized = false);
    }
  }

  /// Ensures frame [idx] is decoded and cached, restarting the codec from 0
  /// if it's behind the live trailing window (dart:ui codecs can't seek
  /// backward). Sets [_gifLazyShown] on success.
  Future<void> _seekLazyFrame(int token, int idx) async {
    if (_gifLazyCache.containsKey(idx)) {
      _gifLazyShown = _gifLazyCache[idx];
      return;
    }
    if (idx < 0) return;
    // Ticks/rebuilds keep firing on the *current* _gifLazyShown for the
    // whole span of this async decode (could be many frames, e.g. a big
    // backward jump) — it must stay alive and undisposed until it's
    // actually replaced below, not just given one frame's grace.
    final previousShown = _gifLazyShown;
    if (idx < _gifLazyCursor - _kGifLazyWindow) {
      _gifLazyCodec = await ui.instantiateImageCodec(_gifLazyBytes!);
      _gifLazyCursor = 0;
      for (final f in _gifLazyCache.values) {
        if (!identical(f, previousShown)) _disposeGifImage(f);
      }
      _gifLazyCache.clear();
    }
    final codec = _gifLazyCodec!;
    while (_gifLazyCursor <= idx) {
      final ui.FrameInfo info;
      try {
        info = await codec.getNextFrame();
      } catch (_) {
        return; // codec was swapped/disposed by a newer load
      }
      if (token != _gifLoadToken) {
        info.image.dispose();
        return;
      }
      _gifLazyCache[_gifLazyCursor++] = info.image;
      final evictBefore = _gifLazyCursor - _kGifLazyWindow;
      _gifLazyCache.removeWhere((i, image) {
        if (i >= evictBefore || identical(image, previousShown)) return false;
        _disposeGifImage(image);
        return true;
      });
    }
    _gifLazyShown = _gifLazyCache[idx];
    // Only now — after the swap above — is it safe to let the old frame go.
    // If previousShown is still a cache entry (normal sequential playback),
    // it must NOT be disposed here: the cache still holds it, and eviction
    // below (or _disposeGifFrames) disposes cache entries — disposing both
    // places double-disposed the same ui.Image ~one window later
    // ("Failed assertion ... Image.dispose"). Cache owns cached frames;
    // this path only owns previousShown once the codec restart above has
    // orphaned it from the cache.
    if (previousShown != null &&
        !identical(previousShown, _gifLazyShown) &&
        !_gifLazyCache.containsValue(previousShown)) {
      _disposeGifImage(previousShown);
    }
    final keep = idx - _kGifLazyWindow + 1;
    _gifLazyCache.removeWhere((i, image) {
      if (i >= keep) return false;
      _disposeGifImage(image);
      return true;
    });
  }

  /// Shows frame [idx] immediately if cached; otherwise kicks off an async
  /// fetch (previous frame stays on screen until it resolves). If a fetch is
  /// already in flight (e.g. scrubber being dragged faster than decode
  /// keeps up), remembers [idx] as the latest target instead of dropping it,
  /// so the drag's final position always lands once the current fetch clears.
  void _gifEnsureFrame(int idx) {
    if (!_gifLazy) return;
    if (_gifLazyCache.containsKey(idx)) {
      _gifLazyShown = _gifLazyCache[idx];
      _gifLazyPendingIdx = null;
      return;
    }
    if (_gifLazyFetching) {
      _gifLazyPendingIdx = idx;
      return;
    }
    _gifLazyFetching = true;
    final token = _gifLoadToken;
    // Debounced — a routine one-frame catch-up resolves before this fires,
    // so the badge only appears for the slow case (backward-seek restart).
    _gifLazyBusyDelay = Timer(const Duration(milliseconds: 150), () {
      if (mounted && _gifLazyFetching) setState(() => _gifLazyBusy = true);
    });
    unawaited(_runLazyFetch(token, idx));
  }

  /// try/finally guarantees _gifLazyFetching always clears — anything
  /// thrown inside _seekLazyFrame that isn't the one guarded getNextFrame()
  /// call (e.g. a restart's instantiateImageCodec) would otherwise leave
  /// the flag stuck true forever, silently dropping every future seek/tick
  /// into _gifLazyPendingIdx with no fetch ever running again.
  Future<void> _runLazyFetch(int token, int idx) async {
    try {
      await _seekLazyFrame(token, idx);
    } catch (_) {
      // Swallowed — a stuck fetch flag is worse than one skipped frame.
    } finally {
      _gifLazyFetching = false;
      _gifLazyBusyDelay?.cancel();
      _gifLazyBusyDelay = null;
    }
    if (!mounted || token != _gifLoadToken) return;
    setState(() => _gifLazyBusy = false);
    final pending = _gifLazyPendingIdx;
    _gifLazyPendingIdx = null;
    if (pending != null && pending != idx) _gifEnsureFrame(pending);
  }

  void _tickGif() {
    if (!mounted) return;
    if (_gifLazy ? _gifLazyShown == null : _gifFrames.isEmpty) return;
    // Frame still loading — hold position so seek bar doesn't lie about
    // playback while the shown frame is stuck stale.
    if (_gifLazy && _gifLazyFetching) return;
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
    _gifEnsureFrame(_gifFrameIndexFor(pos));
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
      _disposeGifImage(f);
    }
    _gifFrames = const [];
    _gifFrameEndMs = const [];
    _gifTotalMs = 0;
    final shown = _gifLazyShown;
    if (shown != null && !_gifLazyCache.containsValue(shown)) {
      _disposeGifImage(shown);
    }
    for (final f in _gifLazyCache.values) {
      _disposeGifImage(f);
    }
    _gifLazyCache.clear();
    _gifLazyCodec?.dispose();
    _gifLazyCodec = null;
    _gifLazyBytes = null;
    _gifLazyShown = null;
    _gifLazyFetching = false;
    _gifLazyPendingIdx = null;
    _gifLazyBusyDelay?.cancel();
    _gifLazyBusyDelay = null;
    _gifLazyBusy = false;
    _gifLazy = false;
    _gifLazyCursor = 0;
  }

  void _seekTo(int ms) {
    if (_isAnimatedImage) {
      if (_gifTotalMs <= 0) return;
      final clamped = ms.clamp(0, _gifTotalMs);
      setState(() => _gifPosMs = clamped);
      widget.onPositionChanged?.call(clamped);
      _gifEnsureFrame(_gifFrameIndexFor(clamped));
      return;
    }
    _player.seek(Duration(milliseconds: ms));
  }

  void _togglePlay() {
    if (_isAnimatedImage) return;
    // About to toggle: playing → this is an explicit pause.
    _pausedByUser = _player.state.playing;
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
    final pending = _openInFlight;
    if (pending == null) {
      _player.dispose();
    } else {
      // open(play:true) may still be in flight; a dispose that races it
      // orphans the native player mid-command (audio keeps playing with no
      // handle to stop it). Silence it now — pause is queued after the open
      // on the player's own command lock — then dispose once open settles.
      _player.pause();
      pending.whenComplete(_player.dispose);
    }
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
  }

  // Committed once on release, not per pointer-move — the local setState
  // above already redraws the crop box live; pushing every frame up to the
  // controller would rebuild the whole studio screen ~60x/sec during a drag.
  // Skipped when no handle was actually hit, so a stray tap in the crop box
  // doesn't force a rebuild.
  void _panEnd(DragEndDetails _) {
    final dragged = _active != _Handle.none;
    _active = _Handle.none;
    _lastPos = null;
    if (dragged) widget.onCropChanged?.call(_crop);
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
          final gifImage = _gifLazy
              ? _gifLazyShown
              : (_gifFrames.isEmpty
                  ? null
                  : _gifFrames[_gifFrameIndexFor(_gifPosMs)
                      .clamp(0, _gifFrames.length - 1)]);
          media = gifImage == null
              ? const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accentB),
                  ),
                )
              : RawImage(image: gifImage, fit: BoxFit.contain);
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
              // Lazy-gif fetch running past the debounce window (slow
              // backward-seek restart) — last frame stays visible underneath.
              if (_gifLazy && _gifLazyBusy)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 20,
                    height: 20,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentB,
                    ),
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
