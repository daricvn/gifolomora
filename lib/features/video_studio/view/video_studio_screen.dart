import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/font_registry.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_confirm_dialog.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../_shared/widgets/file_drop_zone.dart';
import '../../_shared/widgets/local_palettes_toggle.dart';
import '../../_shared/widgets/option_slider.dart';
import '../../_shared/widgets/text_overlay_controls.dart';
import '../../_shared/widgets/video_preview.dart';
import '../../text_overlay/model/text_item.dart';
import '../widgets/cut_segment_slider.dart';
import '../widgets/video_trim_slider.dart';
import '../controller/video_studio_controller.dart';
import 'export_format_screen.dart';

// Matches app_router's fade + 4%-slide transition for non-home routes — this
// page is a Navigator push (a sub-flow of Export, not a top-level GoRoute) so
// it can't reuse that private helper directly.
PageRouteBuilder<T> _formatPageRoute<T>(Widget child) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 240),
  reverseTransitionDuration: const Duration(milliseconds: 200),
  pageBuilder: (context, animation, secondaryAnimation) => child,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final fade = CurveTween(curve: Curves.easeOut).animate(animation);
    final slide = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurveTween(curve: Curves.easeOut).animate(animation));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  },
);

// ffmpeg drawtext anchors the glyph top at y; Flutter's line box keeps ~0.1em
// of ascent above caps. Lift the preview text so the on-screen top matches the
// rendered output. (calibration knob — mirrors the Text Overlay screen)
const double _kTextTopBias = 0.10;

String _fmtMs(int ms) {
  if (ms <= 0) return '0:00';
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

// Small black rounded label used for preview overlay chips (ORIGINAL badge,
// position readout).
Widget _chip(
  String text, {
  double alpha = 0.7,
  FontWeight weight = FontWeight.w700,
}) {
  return IgnorePointer(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: weight),
      ),
    ),
  );
}

// Visibility rule for the "keep original size" checkbox: under 25s it tracks
// whether the cap would kick in; at/after 25s it only stays visible (and
// disabled) if the user had already checked it.
bool _showForceOriginalWidth(VideoStudioState s) =>
    s.effectiveOutputMs < 25000 ? s.gifWidthCapped : s.forceOriginalGifWidth;

const _kVideoExtensions = ['mp4', 'mov', 'mkv', 'avi', 'webm'];
const _kAllExtensions = [..._kVideoExtensions, 'gif'];

class VideoStudioScreen extends ConsumerStatefulWidget {
  const VideoStudioScreen({super.key, this.initialFile});

  final File? initialFile;

  @override
  ConsumerState<VideoStudioScreen> createState() => _VideoStudioScreenState();
}

class _VideoStudioScreenState extends ConsumerState<VideoStudioScreen> {
  // ValueNotifier (not setState) so a playback tick repaints only the
  // small widgets below that read it, not the whole screen tree.
  final ValueNotifier<int> _positionMs = ValueNotifier(0);
  // Set by _VideoControlsOverlay so the persistent bottom-left duration chip
  // can hide while the hover chrome (which has its own time readout) is up.
  final ValueNotifier<bool> _controlsVisible = ValueNotifier(false);
  bool _picking = false;
  // Preview zoom: null = Fit to window; otherwise a video-px scale. Defaults
  // to 100% (not Fit) so the initial preview shows true pixel size.
  double? _zoom = 1.0;
  // Hold-to-peek: true while the compare button is pressed.
  bool _comparing = false;
  late final VideoPreviewController _previewCtrl;
  // True from mount until setInput(initialFile) resolves. The provider is
  // keep-alive, so without this gate the first frame mounts the preview on
  // the PREVIOUS session's file — its Player.open(play:true) then races the
  // dispose triggered by setInput's probing state, leaving an orphaned
  // native player playing audio in the background.
  bool _awaitingInitialFile = false;
  // Pan offset for the preview when zoomed past the pane. Owned so it can be
  // reset to identity when the frame shrinks back to fit (else stale pan keeps
  // the preview pushed off-screen and truncated).
  final TransformationController _transform = TransformationController();
  bool _isDragHovering = false;
  // Ctrl+scroll (desktop) / pinch (touch) zoom over the preview. Pointer
  // tracking is raw (Listener), not a GestureDetector, so it never enters the
  // gesture arena and can't steal the drag from InteractiveViewer's own pan
  // recognizer — single-finger moves fall straight through untouched.
  final Map<int, Offset> _zoomPointers = {};
  double? _pinchStartDistance;
  double? _pinchStartZoom;

  // Snaps to 5% steps (0.05) so scroll/pinch zoom lands on round percentages,
  // same granularity as the preset dropdown values.
  double _snapZoom(double value) =>
      (value.clamp(0.25, 3.0) * 20).round() / 20;
  // Measured height of the glass control dock. The preview pane extends under
  // the dock (bottom edge shows through the blur), so Fit mode subtracts this
  // to keep the whole frame visible above it.
  final ValueNotifier<double> _dockHeight = ValueNotifier(0);

  Future<void> _handleDrop(
    DropDoneDetails details,
    VideoStudioController ctrl,
    void Function(String) toast,
  ) async {
    if (details.files.isEmpty) return;
    final file = details.files.first;
    final ext = file.path.split('.').last.toLowerCase();
    if (!_kAllExtensions.contains(ext)) {
      toast('.$ext is not supported. Drop a video or GIF.');
      return;
    }
    await ctrl.setInput(File(file.path));
  }

  Future<void> _pickFile(VideoStudioController ctrl) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _kAllExtensions,
      );
      final path = result?.files.single.path;
      if (path != null && mounted) await ctrl.setInput(File(path));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _previewCtrl = VideoPreviewController();
    if (widget.initialFile != null) {
      _awaitingInitialFile = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // Awaited fully (not fire-and-forget): setInput's first step now
        // awaits the controller's own initial build (see setInput's doc) so
        // its probing state no longer lands synchronously. Clearing the gate
        // any earlier would show whatever stale state the keep-alive
        // provider already held for one frame.
        await ref
            .read(videoStudioControllerProvider.notifier)
            .setInput(widget.initialFile!);
        if (mounted) setState(() => _awaitingInitialFile = false);
      });
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    _previewCtrl.dispose();
    _positionMs.dispose();
    _controlsVisible.dispose();
    _dockHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(videoStudioControllerProvider).valueOrNull ??
        const VideoStudioState();
    final ctrl = ref.read(videoStudioControllerProvider.notifier);
    final topInset = MediaQuery.of(context).padding.top;

    void toast(String msg) {
      if (!context.mounted) return;
      _StudioToast.show(context, msg);
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragHovering = true),
      onDragExited: (_) => setState(() => _isDragHovering = false),
      onDragDone: (details) {
        setState(() => _isDragHovering = false);
        if (!state.isProcessing) _handleDrop(details, ctrl, toast);
      },
      child: _buildScaffold(context, state, ctrl, toast, topInset),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    VideoStudioState state,
    VideoStudioController ctrl,
    void Function(String) toast,
    double topInset,
  ) {
    return GradientScaffold(
      appBar: GlassAppBar(
        title: 'Video Studio',
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              iconSize: 20,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textHi,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        actions: [
          if (state.hasInput && !state.isProcessing)
            IconButton(
              tooltip: 'Start over',
              icon: const Icon(
                Icons.restart_alt_rounded,
                color: AppColors.textLo,
                size: 22,
              ),
              onPressed: () async {
                final ok = await GlassConfirmDialog.show(
                  context,
                  title: 'Start over?',
                  message: 'This discards the loaded file and all edits.',
                  confirmLabel: 'Start over',
                  isDestructive: true,
                );
                if (ok == true) ctrl.clear();
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: topInset + 64),
            child: _buildBody(context, state, ctrl, toast),
          ),
          if (state.isProcessing)
            _ProcessingOverlay(
              label: state.isGif ? 'Rendering GIF…' : 'Encoding…',
              progress: state.progress?.fraction,
              onCancel: ctrl.cancel,
            ),
          if (_isDragHovering && !state.isProcessing)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: AppColors.bg0.withValues(alpha: 0.6),
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.accentB.withValues(alpha: 0.08),
                        border: Border.all(
                          color: AppColors.accentB.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.file_download_rounded,
                              color: AppColors.accentB,
                              size: 64,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Drop video or GIF',
                              style: TextStyle(
                                color: AppColors.textHi,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    VideoStudioState state,
    VideoStudioController ctrl,
    void Function(String) toast,
  ) {
    if (state.isProbing || _awaitingInitialFile) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accentB),
            SizedBox(height: 12),
            Text(
              'Reading file…',
              style: TextStyle(color: AppColors.textLo, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (!state.hasInput) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: FileDropZone(
            hint: 'Tap to select a video or GIF',
            icon: Icons.perm_media_rounded,
            allowedExtensions: _kAllExtensions,
            onFilesSelected: (files) {
              if (files.isNotEmpty) ctrl.setInput(files.first);
            },
          ),
        ),
      );
    }

    return Column(
      children: [
        _StageBanner(
          state: state,
          onChangeVideo: state.isProcessing || _picking
              ? null
              : () => _pickFile(ctrl),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: ValueListenableBuilder<double>(
                    valueListenable: _dockHeight,
                    builder: (context, dockH, _) => LayoutBuilder(
                      builder: (context, constraints) {
                        final cropActive = state.activeTool == StudioTool.crop;
                        final srcW = state.sourceWidth;
                        final srcH = state.sourceHeight;

                        // Output dimensions after Resize (aspect preserved — the tool
                        // only scales width). Zoom presets are relative to these, so
                        // 100% renders at the resized pixel size the Resize tool
                        // reports (e.g. 800px wide -> 800 logical px at 100%, 400 at
                        // 50%). Fit ignores this and fills the pane.
                        double baseW = srcW.toDouble();
                        double baseH = srcH.toDouble();
                        final tw = state.targetWidth;
                        if (tw != null && srcW > 0) {
                          baseW = tw.toDouble();
                          baseH = srcH * tw / srcW;
                        }

                        // Scale that fits the output frame inside the preview pane.
                        // The pane extends under the glass dock, so Fit targets the
                        // area above it — zoomed frames may slide beneath the blur.
                        final visibleH = math.max(
                          1.0,
                          constraints.maxHeight - dockH,
                        );
                        double fitScale = 1.0;
                        if (baseW > 0 && baseH > 0) {
                          fitScale = math.min(
                            constraints.maxWidth / baseW,
                            visibleH / baseH,
                          );
                        }

                        // output-px -> logical-px scale for the rendered preview.
                        final bool fitMode = _zoom == null;
                        final double renderScale = fitMode ? fitScale : _zoom!;

                        double renderW = constraints.maxWidth;
                        double renderH = constraints.maxHeight;
                        if (baseW > 0 && baseH > 0) {
                          renderW = baseW * renderScale;
                          renderH = baseH * renderScale;
                        }

                        // Compare button unmounts when there's nothing left to
                        // compare (e.g. edits cleared mid-hold) — drop the
                        // stuck hold-to-peek flag so preview doesn't stay
                        // pinned to the original with no control left to undo it.
                        if (_comparing &&
                            !(state.inputFile != null &&
                                state.hasComparableEdit)) {
                          _comparing = false;
                        }

                        final textActive = state.activeTool == StudioTool.text;

                        final preview = SizedBox(
                          width: renderW,
                          height: renderH,
                          child: GlassContainer(
                            borderRadius: 20,
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: VideoPreview(
                                      // No key: didUpdateWidget already swaps `file`
                                      // (see video_preview.dart) without tearing down
                                      // the player. A path-based key here forced a full
                                      // dispose/recreate of the native player on every
                                      // compare-button press.
                                      file: _comparing
                                          ? (state.inputFile ??
                                                state.sourceFile!)
                                          : state.sourceFile!,
                                      videoWidth: srcW,
                                      videoHeight: srcH,
                                      speedRate: _comparing
                                          ? 1.0
                                          : state.speedFactor,
                                      volume: _comparing ? 1.0 : state.volume,
                                      cropRect: _comparing
                                          ? null
                                          : (cropActive || !state.isCropFull)
                                          ? state.cropNormalized
                                          : null,
                                      interactive: !_comparing && cropActive,
                                      onCropChanged: ctrl.setCrop,
                                      controller: _previewCtrl,
                                      onPositionChanged: (ms) =>
                                          _positionMs.value = ms,
                                      trimStartMs: _comparing
                                          ? 0
                                          : state.trimStartMs,
                                      trimEndMs: _comparing
                                          ? 0
                                          : state.sourceDurationMs > 0
                                          ? state.effectiveTrimEndMs
                                          : 0,
                                    ),
                                  ),
                                  if (_comparing)
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: _chip('ORIGINAL'),
                                    ),
                                  if (state.textItems.isNotEmpty && !_comparing)
                                    Positioned.fill(
                                      child: _StudioTextLayer(
                                        state: state,
                                        ctrl: ctrl,
                                        renderW: renderW,
                                        renderH: renderH,
                                        srcW: srcW,
                                        interactive: textActive,
                                      ),
                                    ),
                                  // Red tint + corner chip when playhead is inside a
                                  // cut segment (hint only — marked for removal, not
                                  // an error state). Only this leaf repaints per tick.
                                  ValueListenableBuilder<int>(
                                    valueListenable: _positionMs,
                                    builder: (_, pos, _) {
                                      final inCut =
                                          !_comparing &&
                                          !state.isGif &&
                                          state.cutSegments.any(
                                            (s) =>
                                                pos >= s.startMs &&
                                                pos < s.endMs,
                                          );
                                      if (!inCut) {
                                        return const SizedBox.shrink();
                                      }
                                      return Positioned.fill(
                                        child: IgnorePointer(
                                          child: Stack(
                                            children: [
                                              const Positioned.fill(
                                                child: ColoredBox(
                                                  color: Color(0x40FF0000),
                                                ),
                                              ),
                                              Positioned(
                                                top: 10,
                                                left: 10,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withValues(
                                                          alpha: 0.85,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.cut_rounded,
                                                        color: Colors.white,
                                                        size: 11,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'CUT',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  // Persistent position chip — hidden while the
                                  // hover-chrome (which has its own time row) is up,
                                  // so the two don't visually overlap; on GIF stage
                                  // (no hover chrome) it's the only indicator.
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _controlsVisible,
                                    builder: (_, controlsVisible, _) {
                                      if (controlsVisible) {
                                        return const SizedBox.shrink();
                                      }
                                      return ValueListenableBuilder<int>(
                                        valueListenable: _positionMs,
                                        builder: (_, pos, _) => Positioned(
                                          left: 10,
                                          bottom: 8,
                                          child: _chip(
                                            '${_fmtMs(pos)} / ${_fmtMs(state.sourceDurationMs)}',
                                            alpha: 0.55,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  // YouTube-style controls — videos only, and only when
                                  // no canvas tool (crop/text) owns the preview gestures.
                                  if (!state.isGif &&
                                      !cropActive &&
                                      !textActive)
                                    Positioned.fill(
                                      child: ValueListenableBuilder<int>(
                                        valueListenable: _positionMs,
                                        builder: (_, pos, _) =>
                                            _VideoControlsOverlay(
                                              controller: _previewCtrl,
                                              positionMs: pos,
                                              durationMs:
                                                  state.sourceDurationMs,
                                              onSeek: (ms) {
                                                _previewCtrl.seekTo(ms);
                                                _positionMs.value = ms;
                                              },
                                              onVisibleChanged: (v) =>
                                                  _controlsVisible.value = v,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );

                        final overflowX = renderW > constraints.maxWidth + 0.5;
                        // Against the area above the dock — anything hidden
                        // under the glass must be pannable back into view.
                        final overflowY = renderH > visibleH + 0.5;
                        // Crop's drag gesture owns the whole frame, so pan stays off
                        // during crop to avoid fighting the handles.
                        final canPan =
                            !fitMode &&
                            !cropActive &&
                            !textActive &&
                            (overflowX || overflowY);

                        // Frame now fits the pane but a prior pan left a stale
                        // translation — recenter so it isn't truncated to one edge.
                        if (!canPan && !_transform.value.isIdentity()) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _transform.value = Matrix4.identity();
                          });
                        }

                        final pane = ClipRect(
                          child: InteractiveViewer(
                            transformationController: _transform,
                            constrained: false,
                            scaleEnabled: false,
                            panEnabled: canPan,
                            child: SizedBox(
                              width: math.max(renderW, constraints.maxWidth),
                              // Constant dock-height tail below the frame:
                              // small frames center above the dock; oversized
                              // ones start under the glass but pan up until
                              // the bottom edge clears it.
                              height: math.max(
                                  renderH + dockH, constraints.maxHeight),
                              child: Padding(
                                padding: EdgeInsets.only(bottom: dockH),
                                child: Center(child: preview),
                              ),
                            ),
                          ),
                        );

                        final zoomablePane = Listener(
                          onPointerSignal: (event) {
                            if (event is! PointerScrollEvent) return;
                            if (!HardwareKeyboard.instance.isControlPressed) {
                              return;
                            }
                            final current = _zoom ?? fitScale;
                            final next = _snapZoom(
                              current - event.scrollDelta.dy * 0.0015,
                            );
                            setState(() => _zoom = next);
                          },
                          onPointerDown: (event) {
                            _zoomPointers[event.pointer] = event.position;
                            if (_zoomPointers.length == 2) {
                              final pts = _zoomPointers.values.toList();
                              _pinchStartDistance = (pts[0] - pts[1]).distance;
                              _pinchStartZoom = _zoom ?? fitScale;
                            }
                          },
                          onPointerMove: (event) {
                            if (!_zoomPointers.containsKey(event.pointer)) {
                              return;
                            }
                            _zoomPointers[event.pointer] = event.position;
                            final startDist = _pinchStartDistance;
                            final startZoom = _pinchStartZoom;
                            if (_zoomPointers.length == 2 &&
                                startDist != null &&
                                startDist > 0 &&
                                startZoom != null) {
                              final pts = _zoomPointers.values.toList();
                              final dist = (pts[0] - pts[1]).distance;
                              final next = _snapZoom(
                                startZoom * dist / startDist,
                              );
                              setState(() => _zoom = next);
                            }
                          },
                          onPointerUp: (event) {
                            _zoomPointers.remove(event.pointer);
                            if (_zoomPointers.length < 2) {
                              _pinchStartDistance = null;
                              _pinchStartZoom = null;
                            }
                          },
                          onPointerCancel: (event) {
                            _zoomPointers.remove(event.pointer);
                            _pinchStartDistance = null;
                            _pinchStartZoom = null;
                          },
                          child: pane,
                        );

                        return Stack(
                          children: [
                            Positioned.fill(child: zoomablePane),
                            if (state.inputFile != null &&
                                state.hasComparableEdit)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: _CompareButton(
                                  active: _comparing,
                                  onHoldChanged: (v) =>
                                      setState(() => _comparing = v),
                                ),
                              ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: _ZoomControl(
                                zoom: _zoom,
                                onChanged: (v) => setState(() => _zoom = v),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _SizeReporter(
                  onSize: (s) {
                    if (mounted) _dockHeight.value = s.height;
                  },
                  child: _ControlDock(
                    state: state,
                    ctrl: ctrl,
                    toast: toast,
                    positionMs: _positionMs,
                    onSeekPreview: (ms) {
                      _previewCtrl.seekTo(ms);
                      _positionMs.value = ms;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stage banner ────────────────────────────────────────────────────────────

class _StageBanner extends StatelessWidget {
  const _StageBanner({required this.state, this.onChangeVideo});
  final VideoStudioState state;
  final VoidCallback? onChangeVideo;

  @override
  Widget build(BuildContext context) {
    final dims = state.sourceWidth > 0
        ? '${state.sourceWidth}×${state.sourceHeight}'
        : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: state.isGif ? null : AppGradients.primaryButton,
              color: state.isGif
                  ? AppColors.accentC.withValues(alpha: 0.25)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.isGif ? Icons.gif_box_rounded : Icons.movie_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  state.isGif ? 'Editing GIF' : 'Editing video',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                if (dims.isNotEmpty) dims,
                if (!state.isGif) state.hasAudio ? 'audio' : 'no audio',
              ].join(' · '),
              style: const TextStyle(color: AppColors.textLo, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onChangeVideo != null)
            TextButton.icon(
              onPressed: onChangeVideo,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(
                Icons.video_library_rounded,
                size: 15,
                color: AppColors.accentB,
              ),
              label: const Text(
                'Change',
                style: TextStyle(color: AppColors.accentB, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Zoom control (preview magnifier) ─────────────────────────────────────────

// label, video-px scale. null scale = Fit to window.
const _kZoomPresets = <(String, double?)>[
  ('25%', 0.25),
  ('50%', 0.5),
  ('75%', 0.75),
  ('100%', 1.0),
  ('125%', 1.25),
  ('150%', 1.5),
  ('200%', 2.0),
  ('250%', 2.5),
  ('300%', 3.0),
  ('Fit', null),
];

class _ZoomControl extends StatelessWidget {
  const _ZoomControl({required this.zoom, required this.onChanged});
  final double? zoom;
  final void Function(double?) onChanged;

  String get _label {
    if (zoom == null) return 'Fit';
    for (final p in _kZoomPresets) {
      if (p.$2 == zoom) return p.$1;
    }
    return '${(zoom! * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Zoom',
      position: PopupMenuPosition.under,
      color: AppColors.bg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.glassStroke),
      ),
      onSelected: (i) => onChanged(_kZoomPresets[i].$2),
      itemBuilder: (context) => [
        for (var i = 0; i < _kZoomPresets.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: _kZoomPresets[i].$2 == zoom
                      ? AppColors.accentB
                      : Colors.transparent,
                ),
                const SizedBox(width: 8),
                Text(
                  _kZoomPresets[i].$1 == 'Fit'
                      ? 'Fit to window'
                      : _kZoomPresets[i].$1,
                  style: TextStyle(
                    color: _kZoomPresets[i].$2 == zoom
                        ? AppColors.accentB
                        : AppColors.textHi,
                    fontSize: 13,
                    fontWeight: _kZoomPresets[i].$2 == zoom
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: GlassContainer(
        borderRadius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.zoom_in_rounded,
              size: 15,
              color: AppColors.accentB,
            ),
            const SizedBox(width: 5),
            Text(
              _label,
              style: const TextStyle(
                color: AppColors.textHi,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: AppColors.textLo,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compare (before/after) button ────────────────────────────────────────────
// Hold to peek the original input file; release to return to the live edit.

class _CompareButton extends StatelessWidget {
  const _CompareButton({required this.active, required this.onHoldChanged});
  final bool active;
  final ValueChanged<bool> onHoldChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onHoldChanged(true),
      onTapUp: (_) => onHoldChanged(false),
      onTapCancel: () => onHoldChanged(false),
      child: GlassContainer(
        borderRadius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_rounded,
              size: 15,
              color: active ? AppColors.accentB : AppColors.textHi,
            ),
            const SizedBox(width: 5),
            Text(
              active ? 'Original' : 'Compare',
              style: TextStyle(
                color: active ? AppColors.accentB : AppColors.textHi,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Video controls overlay (YouTube-style play/pause + scrubber) ─────────────
//
// Shows on hover (desktop) or tap (touch); auto-hides ~3s after playback
// resumes, stays up while paused or scrubbing. Drives the shared
// VideoPreviewController for play/pause + seek.
class _VideoControlsOverlay extends StatefulWidget {
  const _VideoControlsOverlay({
    required this.controller,
    required this.positionMs,
    required this.durationMs,
    required this.onSeek,
    required this.onVisibleChanged,
  });
  final VideoPreviewController controller;
  final int positionMs;
  final int durationMs;
  final void Function(int ms) onSeek;
  final void Function(bool visible) onVisibleChanged;

  @override
  State<_VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<_VideoControlsOverlay> {
  bool _visible = false;
  bool _dragging = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.playing.addListener(_onPlayingChanged);
  }

  @override
  void dispose() {
    widget.controller.playing.removeListener(_onPlayingChanged);
    _hideTimer?.cancel();
    if (_visible) widget.onVisibleChanged(false);
    super.dispose();
  }

  void _onPlayingChanged() {
    // Only manages timer — never reveals. Loop emits false→true; revealing here
    // causes unwanted flash. Show only from user gestures (_show).
    if (widget.controller.playing.value) {
      if (_visible) _scheduleHide();
    } else {
      _hideTimer?.cancel();
      // keep visible if already visible; don't force-show
    }
  }

  void _setVisible(bool v) {
    setState(() => _visible = v);
    widget.onVisibleChanged(v);
  }

  void _show() {
    _hideTimer?.cancel();
    if (!_visible) _setVisible(true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      // Stay visible while paused or scrubbing.
      if (!mounted || _dragging || !widget.controller.playing.value) return;
      _setVisible(false);
    });
  }

  void _toggleVisible() {
    if (_visible) {
      _hideTimer?.cancel();
      _setVisible(false);
    } else {
      _show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dur = widget.durationMs;
    final maxMs = (dur > 0 ? dur : 1).toDouble();
    final pos = widget.positionMs.toDouble().clamp(0.0, maxMs);
    return MouseRegion(
      onEnter: (_) => _show(),
      onHover: (_) => _show(),
      onExit: (_) {
        if (widget.controller.playing.value && mounted) {
          _hideTimer?.cancel();
          _setVisible(false);
        }
      },
      child: Stack(
        children: [
          // Tap empty area to toggle the chrome (touch). Always present so a
          // tap re-shows controls after they auto-hide.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleVisible,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_visible,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: _chrome(pos, maxMs, dur),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chrome(double pos, double maxMs, int dur) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),
        Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.controller.playing,
            builder: (_, playing, _) => _CenterPlayButton(
              playing: playing,
              onTap: () {
                widget.controller.togglePlay();
                _show();
              },
            ),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 4,
          child: Row(
            children: [
              Text(
                _fmtMs(pos.round()),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: Colors.red,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                    thumbColor: Colors.red,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    overlayColor: Colors.red.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: pos,
                    max: maxMs,
                    onChangeStart: (_) {
                      _dragging = true;
                      _hideTimer?.cancel();
                    },
                    onChanged: dur > 0 ? (v) => widget.onSeek(v.round()) : null,
                    onChangeEnd: (_) {
                      _dragging = false;
                      _scheduleHide();
                    },
                  ),
                ),
              ),
              Text(
                _fmtMs(dur),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CenterPlayButton extends StatelessWidget {
  const _CenterPlayButton({required this.playing, required this.onTap});
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }
}

// ── Control dock: tool selector + active panel + actions ─────────────────────

class _ControlDock extends StatelessWidget {
  const _ControlDock({
    required this.state,
    required this.ctrl,
    required this.toast,
    required this.positionMs,
    required this.onSeekPreview,
  });
  final VideoStudioState state;
  final VideoStudioController ctrl;
  final void Function(String) toast;
  final ValueListenable<int> positionMs;
  final void Function(int ms) onSeekPreview;

  @override
  Widget build(BuildContext context) {
    // Glassy overlay (GlassAppBar-style blur): the dock floats over the
    // preview pane, so an oversized video's bottom edge stays visible,
    // blurred, behind it.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg1.withValues(alpha: 0.55),
            border: const Border(
              top: BorderSide(color: AppColors.glassStroke, width: 0.5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToolSelector(state: state, onSelect: ctrl.setActiveTool),
                const SizedBox(height: 12),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _ToolPanel(
                    state: state,
                    ctrl: ctrl,
                    positionMs: positionMs,
                    onSeekPreview: onSeekPreview,
                    toast: toast,
                  ),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 10),
                  _ErrorCard(message: state.error!),
                ],
                const SizedBox(height: 12),
                _ActionBar(state: state, ctrl: ctrl, toast: toast),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Reports the child's laid-out size (post-frame) so the preview pane can
// subtract the dock height when computing Fit.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required Widget child})
    : super(child: child);
  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);
  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (_last != size) {
      _last = size;
      final s = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onSize(s));
    }
  }
}

class _ToolSelector extends StatelessWidget {
  const _ToolSelector({required this.state, required this.onSelect});
  final VideoStudioState state;
  final void Function(StudioTool?) onSelect;

  @override
  Widget build(BuildContext context) {
    final active = state.activeTool;
    final isGif = state.isGif;
    // (tool, icon, label)
    final tools = [
      (StudioTool.crop, Icons.crop_rounded, 'Crop'),
      (StudioTool.resize, Icons.photo_size_select_large_rounded, 'Resize'),
      (StudioTool.speed, Icons.speed_rounded, 'Speed'),
      (StudioTool.trim, Icons.straighten_rounded, 'Trim'),
      if (!isGif) (StudioTool.cut, Icons.cut_rounded, 'Cut'),
      (StudioTool.text, Icons.title_rounded, 'Text'),
      if (isGif) (StudioTool.optimize, Icons.tune_rounded, 'Optimise'),
      (StudioTool.properties, Icons.settings_suggest_rounded, 'Props'),
      if (!isGif) (StudioTool.gif, Icons.gif_box_rounded, 'GIF'),
      if (isGif) (StudioTool.webm, Icons.movie_creation_rounded, 'WebM'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in tools)
          SizedBox(
            width:
                (MediaQuery.of(context).size.width - 44) / (tools.length + 1),
            child: (t.$1 == StudioTool.gif || t.$1 == StudioTool.webm)
                ? _AccentToolButton(
                    icon: t.$2,
                    label: t.$3,
                    selected: active == t.$1,
                    edited: state.isToolEdited(t.$1),
                    onTap: () => onSelect(active == t.$1 ? null : t.$1),
                  )
                : _ToolButton(
                    icon: t.$2,
                    label: t.$3,
                    selected: active == t.$1,
                    edited: state.isToolEdited(t.$1),
                    onTap: () => onSelect(active == t.$1 ? null : t.$1),
                  ),
          ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    this.edited = false,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool edited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = selected ? Colors.white : AppColors.textHi;
    final btn = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: selected ? AppGradients.primaryButton : null,
        color: selected ? null : AppColors.glassTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? Colors.transparent : AppColors.glassStroke,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: effectiveColor),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: !edited
          ? btn
          : Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                btn,
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : AppColors.accentC,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg1, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Animated accent gradient (GIF tool highlight) ────────────────────────────

// Samples the accent wheel (violet → cyan → magenta → violet) at phase
// [t] ∈ [0,1), wrapping, so two samples a fixed phase apart give a gradient
// that drifts through the palette without ever jumping.
Color _accentCycle(double t) {
  const wheel = [AppColors.accentA, AppColors.accentB, AppColors.accentC];
  final x = (t % 1.0) * wheel.length;
  final i = x.floor();
  return Color.lerp(
    wheel[i % wheel.length],
    wheel[(i + 1) % wheel.length],
    x - i,
  )!;
}

/// Rebuilds [builder] every frame with a slowly drifting two-stop accent
/// gradient. One looping controller per instance; keep instances few (the GIF
/// tool button and the Make GIF button).
class _GradientCycle extends StatefulWidget {
  const _GradientCycle({required this.builder});
  final Widget Function(BuildContext context, LinearGradient gradient) builder;

  @override
  State<_GradientCycle> createState() => _GradientCycleState();
}

class _GradientCycleState extends State<_GradientCycle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => widget.builder(
        context,
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accentCycle(_c.value), _accentCycle(_c.value + 1 / 3)],
        ),
      ),
    );
  }
}

// Standout variant of [_ToolButton] for the GIF tool: animated gradient
// border (unselected) or fill (selected) plus a soft glow, so the export
// entry point reads as the destination of the video stage.
// Accent tool button (GIF, WebM): animated gradient border/icon shared by
// both stage-switching tools so they read as one visual family.
class _AccentToolButton extends StatelessWidget {
  const _AccentToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.edited,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool edited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final btn = _GradientCycle(
      builder: (context, gradient) => Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(
                alpha: selected ? 0.55 : 0.35,
              ),
              blurRadius: selected ? 14 : 10,
            ),
          ],
        ),
        // Gradient border: outer gradient box, inset dark inner box. A plain
        // Border.all can't take a gradient.
        padding: const EdgeInsets.all(1.4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.6),
          decoration: BoxDecoration(
            color: selected ? Colors.transparent : AppColors.bg1,
            borderRadius: BorderRadius.circular(10.6),
          ),
          child: Column(
            children: [
              selected
                  ? Icon(icon, size: 18, color: Colors.white)
                  : ShaderMask(
                      shaderCallback: (r) => gradient.createShader(r),
                      child: Icon(icon, size: 18, color: Colors.white),
                    ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textHi,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: !edited
          ? btn
          : Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                btn,
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : AppColors.accentC,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg1, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ToolPanel extends StatelessWidget {
  const _ToolPanel({
    required this.state,
    required this.ctrl,
    required this.positionMs,
    required this.onSeekPreview,
    required this.toast,
  });
  final VideoStudioState state;
  final VideoStudioController ctrl;
  final ValueListenable<int> positionMs;
  final void Function(int ms) onSeekPreview;
  final void Function(String) toast;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: _panel(),
    );
  }

  Widget _panel() {
    switch (state.activeTool) {
      case StudioTool.crop:
        return Row(
          key: const ValueKey('crop'),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Drag the handles on the preview to crop',
                style: TextStyle(color: AppColors.textLo, fontSize: 12),
              ),
            ),
            if (!state.isCropFull)
              TextButton.icon(
                onPressed: ctrl.resetCrop,
                icon: const Icon(
                  Icons.crop_free_rounded,
                  size: 14,
                  color: AppColors.accentB,
                ),
                label: const Text(
                  'Reset',
                  style: TextStyle(color: AppColors.accentB, fontSize: 12),
                ),
              ),
          ],
        );
      case StudioTool.resize:
        return _ResizeChips(
          key: const ValueKey('resize'),
          sourceWidth: state.sourceWidth,
          targetWidth: state.targetWidth,
          onChanged: ctrl.setResize,
        );
      case StudioTool.speed:
        return Column(
          key: const ValueKey('speed'),
          children: [
            OptionSlider(
              label: 'Playback speed',
              value: state.speedFactor,
              min: 0.25,
              max: 4.0,
              divisions: 75,
              displayValue: _speedLabel(state.speedFactor),
              onChanged: (v) => ctrl.setSpeed(_snapSpeed(v)),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0.25× slower',
                  style: TextStyle(color: AppColors.textLo, fontSize: 11),
                ),
                Text(
                  '4× faster',
                  style: TextStyle(color: AppColors.textLo, fontSize: 11),
                ),
              ],
            ),
          ],
        );
      case StudioTool.trim:
        return ValueListenableBuilder<int>(
          key: const ValueKey('trim'),
          valueListenable: positionMs,
          builder: (_, pos, _) => _TrimPanel(
            state: state,
            ctrl: ctrl,
            positionMs: pos,
            onSeekPreview: onSeekPreview,
          ),
        );
      case StudioTool.cut:
        return ValueListenableBuilder<int>(
          key: const ValueKey('cut'),
          valueListenable: positionMs,
          builder: (_, pos, _) => _CutPanel(
            state: state,
            ctrl: ctrl,
            positionMs: pos,
            onSeekPreview: onSeekPreview,
            toast: toast,
          ),
        );
      case StudioTool.text:
        return _StudioTextPanel(
          key: const ValueKey('text'),
          state: state,
          ctrl: ctrl,
        );
      case StudioTool.optimize:
        return _OptimizePanel(
          key: const ValueKey('optimize'),
          state: state,
          ctrl: ctrl,
        );
      case StudioTool.properties:
        return _PropertiesPanel(
          key: const ValueKey('properties'),
          state: state,
          ctrl: ctrl,
        );
      case StudioTool.gif:
        return _GifPanel(
          key: const ValueKey('gif'),
          state: state,
          ctrl: ctrl,
          toast: toast,
        );
      case StudioTool.webm:
        return _WebmPanel(
          key: const ValueKey('webm'),
          state: state,
          ctrl: ctrl,
          toast: toast,
        );
      case null:
        return const SizedBox(width: double.infinity, key: ValueKey('none'));
    }
  }

  String _speedLabel(double v) {
    if ((v - 1.0).abs() < 0.01) return '1× (original)';
    if (v < 1.0) return '${v.toStringAsFixed(2)}× (slower)';
    return '${v.toStringAsFixed(2)}× (faster)';
  }

  double _snapSpeed(double v) {
    const snaps = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0];
    for (final s in snaps) {
      if ((v - s).abs() < 0.04) return s;
    }
    return double.parse(v.toStringAsFixed(2));
  }
}

// ── Trim panel ────────────────────────────────────────────────────────────────

class _TrimPanel extends StatelessWidget {
  const _TrimPanel({
    required this.state,
    required this.ctrl,
    required this.positionMs,
    required this.onSeekPreview,
  });
  final VideoStudioState state;
  final VideoStudioController ctrl;
  final int positionMs;
  final void Function(int ms) onSeekPreview;

  @override
  Widget build(BuildContext context) {
    final totalMs = state.sourceDurationMs;
    final endMs = state.effectiveTrimEndMs;
    final clipMs = (endMs - state.trimStartMs).clamp(
      0,
      totalMs > 0 ? totalMs : 1,
    );

    return Column(
      children: [
        if (totalMs > 0) ...[
          VideoTrimSlider(
            totalMs: totalMs,
            startMs: state.trimStartMs,
            endMs: endMs,
            positionMs: positionMs.clamp(0, totalMs),
            onStartChanged: ctrl.setTrimStart,
            onEndChanged: ctrl.setTrimEnd,
            onSeek: onSeekPreview,
          ),
          const SizedBox(height: 6),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TrimChip(
              icon: Icons.login_rounded,
              label: 'In',
              ms: state.trimStartMs,
            ),
            _TrimChip(
              icon: Icons.straighten_rounded,
              label: 'Clip',
              ms: clipMs,
              highlight: true,
            ),
            _TrimChip(icon: Icons.logout_rounded, label: 'Out', ms: endMs),
            if (state.hasTrim)
              TextButton.icon(
                onPressed: ctrl.resetTrim,
                icon: const Icon(
                  Icons.restore_rounded,
                  size: 13,
                  color: AppColors.accentB,
                ),
                label: const Text(
                  'Reset',
                  style: TextStyle(color: AppColors.accentB, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.speed_rounded, size: 13, color: AppColors.textLo),
            const SizedBox(width: 4),
            Text(
              'GIF will be capped at ${state.maxGifFps} fps for this length.',
              style: const TextStyle(color: AppColors.textLo, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Cut panel ──────────────────────────────────────────────────────────────────

class _CutPanel extends StatefulWidget {
  const _CutPanel({
    required this.state,
    required this.ctrl,
    required this.positionMs,
    required this.onSeekPreview,
    required this.toast,
  });
  final VideoStudioState state;
  final VideoStudioController ctrl;
  final int positionMs;
  final void Function(int ms) onSeekPreview;
  final void Function(String) toast;

  @override
  State<_CutPanel> createState() => _CutPanelState();
}

class _CutPanelState extends State<_CutPanel> {
  late int _pendingStartMs;
  late int _pendingEndMs;

  @override
  void initState() {
    super.initState();
    _initPending();
  }

  void _initPending() {
    final s = widget.state;
    final lo = s.trimStartMs;
    final hi = s.effectiveTrimEndMs;
    if (hi - lo <= 1000) {
      _pendingStartMs = lo;
      _pendingEndMs = hi;
      return;
    }
    const span = 1000;
    final start = widget.positionMs.clamp(lo, hi - span);
    _pendingStartMs = start;
    _pendingEndMs = start + span;
  }

  @override
  void didUpdateWidget(_CutPanel old) {
    super.didUpdateWidget(old);
    final lo = widget.state.trimStartMs;
    final hi = widget.state.effectiveTrimEndMs;
    // Clamp both ends into the (possibly shrunk) trim window before fixing
    // order — clamping only the edge that moved (old code) could leave
    // start > end when the window shrank past the *other* edge, drawing an
    // inverted range.
    _pendingStartMs = _pendingStartMs.clamp(lo, hi);
    _pendingEndMs = _pendingEndMs.clamp(lo, hi);
    if (_pendingEndMs <= _pendingStartMs) {
      _pendingEndMs = (_pendingStartMs + 1000).clamp(lo, hi);
      if (_pendingEndMs <= _pendingStartMs) _pendingStartMs = _pendingEndMs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final totalMs = s.sourceDurationMs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (totalMs > 0) ...[
          CutSegmentSlider(
            totalMs: totalMs,
            trimStartMs: s.trimStartMs,
            trimEndMs: s.effectiveTrimEndMs,
            cutSegments: s.cutSegments,
            pendingStartMs: _pendingStartMs,
            pendingEndMs: _pendingEndMs,
            positionMs: widget.positionMs.clamp(0, totalMs),
            onPendingChanged: (start, end) => setState(() {
              _pendingStartMs = start;
              _pendingEndMs = end;
            }),
            onSeek: widget.onSeekPreview,
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            _TrimChip(
              icon: Icons.login_rounded,
              label: 'From',
              ms: _pendingStartMs,
            ),
            const SizedBox(width: 8),
            _TrimChip(
              icon: Icons.logout_rounded,
              label: 'To',
              ms: _pendingEndMs,
            ),
            const Spacer(),
            Builder(
              builder: (_) {
                final zeroLen = _pendingEndMs - _pendingStartMs < 20;
                final covered =
                    zeroLen || s.isFullyCovered(_pendingStartMs, _pendingEndMs);
                final color = covered ? AppColors.textLo : Colors.redAccent;
                return GestureDetector(
                  onTap: covered
                      ? null
                      : () {
                          final ok = widget.ctrl.addCutSegment(
                            _pendingStartMs,
                            _pendingEndMs,
                          );
                          if (!ok) widget.toast("Can't add that segment");
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cut_rounded, color: color, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Mark for removal',
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (s.cutSegments.isEmpty)
          const Text(
            'Mark a span to remove it',
            style: TextStyle(color: AppColors.textLo, fontSize: 12),
          )
        else ...[
          ...s.cutSegments.map(
            (seg) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cut_rounded,
                          color: Colors.redAccent,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_fmtMs(seg.startMs)} – ${_fmtMs(seg.endMs)}',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => widget.ctrl.removeCutSegment(seg),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textLo,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Output ≈ ${_fmtMs(s.cutOutputMs)}',
                style: const TextStyle(color: AppColors.textLo, fontSize: 12),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.ctrl.resetCut,
                icon: const Icon(
                  Icons.restore_rounded,
                  size: 13,
                  color: AppColors.accentB,
                ),
                label: const Text(
                  'Clear all',
                  style: TextStyle(color: AppColors.accentB, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Text overlay (multi-item, shared model with the Text Overlay tool) ───────
//
// Drag to position on the main preview canvas; edit the selected layer here.
// GIF stage bakes layers via textOverlayMulti (Apply / Export GIF); video
// stage bakes them into the encode via editVideo (Export Video).

class _StudioTextPanel extends StatelessWidget {
  const _StudioTextPanel({super.key, required this.state, required this.ctrl});
  final VideoStudioState state;
  final VideoStudioController ctrl;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 340),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!state.fontReady) ...[
              GlassContainer(
                borderRadius: 16,
                tint: Colors.orange,
                opacity: 0.08,
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No system font found. Text may fail to render.',
                        style: TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (state.selectedText != null) ...[
              TextFormatCard(
                key: ValueKey(state.selectedTextId),
                item: state.selectedText!,
                onText: (v) => ctrl.updateSelectedText(text: v),
                onStyle: (v) => ctrl.updateSelectedText(style: v),
                onFont: (v) => ctrl.updateSelectedText(font: v),
                onFontSize: (v) => ctrl.updateSelectedText(fontSize: v),
                onFontColor: (v) => ctrl.updateSelectedText(fontColor: v),
                onStrokeColor: (v) => ctrl.updateSelectedText(strokeColor: v),
                onStrokeWidth: (v) => ctrl.updateSelectedText(strokeWidth: v),
              ),
              const SizedBox(height: 12),
            ],
            TextLayersPanel(
              items: state.textItems,
              selectedId: state.selectedTextId,
              canAdd: state.canAddText,
              onAdd: ctrl.addText,
              onSelect: ctrl.selectText,
              onDelete: ctrl.removeText,
            ),
          ],
        ),
      ),
    );
  }
}

// Draggable text overlay rendered on the main preview canvas. Positions are
// normalized to the source-gif dims and laid out against the rendered frame
// (renderW × renderH), so they line up with the textOverlayMulti bake.
class _StudioTextLayer extends StatelessWidget {
  const _StudioTextLayer({
    required this.state,
    required this.ctrl,
    required this.renderW,
    required this.renderH,
    required this.srcW,
    this.interactive = true,
  });
  final VideoStudioState state;
  final VideoStudioController ctrl;
  final double renderW;
  final double renderH;
  final int srcW;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final scale = srcW > 0 ? renderW / srcW : 1.0;
    final layer = Stack(
      clipBehavior: Clip.none,
      children: [
        if (interactive)
          // tap empty → deselect
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => ctrl.selectText(null),
            ),
          ),
        for (final item in state.textItems)
          _StudioDraggableText(
            item: item,
            selected: interactive && item.id == state.selectedTextId,
            scale: scale,
            renderW: renderW,
            renderH: renderH,
            fontFamily:
                FontRegistry.familyFor(item.font, item.style) ??
                state.fontFamilies[item.style],
            ctrl: ctrl,
          ),
      ],
    );
    return interactive ? layer : IgnorePointer(child: layer);
  }
}

class _StudioDraggableText extends StatefulWidget {
  const _StudioDraggableText({
    required this.item,
    required this.selected,
    required this.scale,
    required this.renderW,
    required this.renderH,
    required this.fontFamily,
    required this.ctrl,
  });
  final TextItem item;
  final bool selected;
  final double scale;
  final double renderW;
  final double renderH;
  final String? fontFamily;
  final VideoStudioController ctrl;

  @override
  State<_StudioDraggableText> createState() => _StudioDraggableTextState();
}

class _StudioDraggableTextState extends State<_StudioDraggableText> {
  // Live position while dragging, committed to the controller once on
  // release — writing to Riverpod state on every pointer-move (as this used
  // to via ctrl.moveSelectedText) rebuilds the whole studio screen per frame.
  double? _dragNx;
  double? _dragNy;

  @override
  void didUpdateWidget(_StudioDraggableText old) {
    super.didUpdateWidget(old);
    // A committed drag (or an external move e.g. undo) landed — drop the
    // local override so the widget tracks the real item again.
    if (old.item.nx != widget.item.nx || old.item.ny != widget.item.ny) {
      _dragNx = null;
      _dragNy = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final fontFamily = widget.fontFamily;
    final scale = widget.scale;
    final renderW = widget.renderW;
    final renderH = widget.renderH;
    final selected = widget.selected;
    final ctrl = widget.ctrl;
    final nx = _dragNx ?? item.nx;
    final ny = _dragNy ?? item.ny;
    final fs = item.fontSize * scale;
    // When the real font file is loaded its weight/style are baked in — don't
    // also synthesize bold/italic or it doubles up.
    final hasFam = fontFamily != null;
    final fw =
        !hasFam &&
            (item.style == TextStyleKind.bold ||
                item.style == TextStyleKind.boldItalic)
        ? FontWeight.w700
        : FontWeight.w400;
    final fst =
        !hasFam &&
            (item.style == TextStyleKind.italic ||
                item.style == TextStyleKind.boldItalic)
        ? FontStyle.italic
        : FontStyle.normal;
    final fill = colorFromHex(item.fontColor);
    final strokeC = colorFromHex(item.strokeColor);
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
      left: nx * renderW,
      top: ny * renderH - fs * _kTextTopBias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ctrl.selectText(item.id),
        onPanDown: (_) => ctrl.selectText(item.id),
        // Reads _dragNx/_dragNy fresh (not the build-time nx/ny above) —
        // pointer-move can fire faster than rebuilds, and basing the delta on
        // a stale build snapshot drops in-between movement, lagging the drag.
        onPanUpdate: (d) => setState(() {
          _dragNx = (_dragNx ?? item.nx) + d.delta.dx / renderW;
          _dragNy = (_dragNy ?? item.ny) + d.delta.dy / renderH;
        }),
        onPanEnd: (_) {
          if (_dragNx != null) ctrl.moveSelectedText(_dragNx!, _dragNy!);
        },
        onPanCancel: () => setState(() {
          _dragNx = null;
          _dragNy = null;
        }),
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

class _TrimChip extends StatelessWidget {
  const _TrimChip({
    required this.icon,
    required this.label,
    required this.ms,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final int ms;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? AppColors.accentA : AppColors.accentB;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: highlight ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textLo, fontSize: 10),
          ),
          const SizedBox(width: 4),
          Text(
            _fmtMs(ms),
            style: TextStyle(
              color: highlight ? AppColors.textHi : AppColors.accentB,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentA.withValues(alpha: 0.25)
              : AppColors.glassTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accentA : AppColors.glassStroke,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accentB : AppColors.textLo,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ResizeChips extends StatelessWidget {
  const _ResizeChips({
    super.key,
    required this.sourceWidth,
    required this.targetWidth,
    required this.onChanged,
  });
  final int sourceWidth;
  final int? targetWidth;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) {
    final presets = <(String, int?)>[
      ('Original', null),
      ('1080p', 1920),
      ('720p', 1280),
      ('480p', 854),
      ('320p', 480),
    ];
    final pct = (targetWidth != null && sourceWidth > 0)
        ? (targetWidth! / sourceWidth * 100).round()
        : 100;
    final sliderPct = pct.clamp(10, 200).toDouble();
    final resultW = targetWidth ?? (sourceWidth > 0 ? sourceWidth : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((p) {
            final selected = p.$2 == targetWidth;
            final disabled =
                p.$2 != null && sourceWidth > 0 && p.$2! >= sourceWidth;
            return ChoiceChip(
              label: Text(p.$1),
              selected: selected,
              onSelected: disabled ? null : (_) => onChanged(p.$2),
              selectedColor: AppColors.accentA.withValues(alpha: 0.3),
              backgroundColor: AppColors.glassTint,
              labelStyle: TextStyle(
                color: disabled
                    ? AppColors.textLo.withValues(alpha: 0.4)
                    : selected
                    ? AppColors.accentB
                    : AppColors.textHi,
                fontSize: 13,
              ),
              side: BorderSide(
                color: selected ? AppColors.accentA : AppColors.glassStroke,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }).toList(),
        ),
        if (sourceWidth > 0) ...[
          const SizedBox(height: 16),
          OptionSlider(
            label: 'Scale',
            value: sliderPct,
            min: 10,
            max: 200,
            divisions: 38,
            displayValue: resultW != null ? '$pct% · ${resultW}px' : '$pct%',
            onChanged: (v) {
              final p = v.round();
              if (p == 100) {
                onChanged(null);
              } else {
                onChanged((sourceWidth * p / 100).round());
              }
            },
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '10% smaller',
                style: TextStyle(color: AppColors.textLo, fontSize: 11),
              ),
              Text(
                '200% larger',
                style: TextStyle(color: AppColors.textLo, fontSize: 11),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Optimize panel ────────────────────────────────────────────────────────────

// ── GIF panel (video stage only): fps + size-cap warning + Make GIF action ──

class _GifPanel extends StatelessWidget {
  const _GifPanel({
    super.key,
    required this.state,
    required this.ctrl,
    required this.toast,
  });
  final VideoStudioState state;
  final VideoStudioController ctrl;
  final void Function(String) toast;

  @override
  Widget build(BuildContext context) {
    final maxFps = state.maxGifFps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OptionSlider(
          label: 'Frame rate',
          value: state.fps.toDouble().clamp(2, maxFps.toDouble()),
          min: 2,
          max: maxFps.toDouble(),
          divisions: maxFps > 2 ? maxFps - 2 : 1,
          displayValue: '${state.fps.clamp(2, maxFps)} fps',
          onChanged: (v) => ctrl.setFps(v.round()),
        ),
        const SizedBox(height: 4),
        Text(
          'Capped at $maxFps fps for this length.',
          style: const TextStyle(color: AppColors.textLo, fontSize: 11),
        ),
        if (state.gifWidthCapped) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'GIF capped at ${state.maxGifWidth}px wide',
                  style: const TextStyle(color: AppColors.textLo, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
        if (_showForceOriginalWidth(state)) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ignore GIF size limit',
                  style: TextStyle(color: AppColors.textHi, fontSize: 14),
                ),
              ),
              Switch(
                value: state.forceOriginalGifWidth,
                onChanged: state.effectiveOutputMs < 25000
                    ? ctrl.setForceOriginalGifWidth
                    : null,
                activeThumbColor: AppColors.accentB,
              ),
            ],
          ),
          if (state.forceOriginalGifWidthActive)
            const Text(
              'Full size may run slow',
              style: TextStyle(color: AppColors.textLo, fontSize: 11),
            ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: _MakeActionButton(
            icon: Icons.auto_awesome_rounded,
            label: 'Make GIF',
            onTap: () async {
              if (state.effectiveOutputMs > 40000) {
                final proceed = await GlassConfirmDialog.show(
                  context,
                  title: 'Video too long',
                  message:
                      'GIF is limited to 40 seconds. Trim the video first for best results, or only the first 40 seconds will be used.',
                  confirmLabel: 'Use first 40s',
                );
                if (proceed != true) return;
              }
              final ok = await ctrl.makeGif();
              if (!ok) toast('Could not create GIF');
            },
          ),
        ),
      ],
    );
  }
}

// The panel's call to action: animated gradient fill + breathing glow so the
// bake step is unmissable once the user opens the GIF/WebM tool.
class _MakeActionButton extends StatelessWidget {
  const _MakeActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _GradientCycle(
      builder: (context, gradient) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.45),
                blurRadius: 18,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: gradient.colors.last.withValues(alpha: 0.30),
                blurRadius: 26,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── WebM panel (GIF stage only): convert to WebM + switch to video editing ──

class _WebmPanel extends StatelessWidget {
  const _WebmPanel({
    super.key,
    required this.state,
    required this.ctrl,
    required this.toast,
  });
  final VideoStudioState state;
  final VideoStudioController ctrl;
  final void Function(String) toast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Converts this GIF to a WebM video, then switches to video editing. '
          'One-way — there is no going back to the GIF.',
          style: TextStyle(color: AppColors.textLo, fontSize: 12),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: _MakeActionButton(
            icon: Icons.movie_creation_rounded,
            label: 'Convert to WebM',
            onTap: () async {
              final ok = await ctrl.makeWebm();
              if (!ok) toast('Could not convert to WebM');
            },
          ),
        ),
      ],
    );
  }
}

class _OptimizePanel extends StatelessWidget {
  const _OptimizePanel({super.key, required this.state, required this.ctrl});
  final VideoStudioState state;
  final VideoStudioController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch(
              value: state.doOptimize,
              onChanged: ctrl.setDoOptimize,
              activeThumbColor: AppColors.accentB,
            ),
            const SizedBox(width: 8),
            const Text(
              'Optimise output GIF',
              style: TextStyle(color: AppColors.textHi, fontSize: 14),
            ),
          ],
        ),
        if (state.doOptimize) ...[
          const SizedBox(height: 10),
          OptionSlider(
            label: 'Colors',
            value: state.optimizeColors.toDouble(),
            min: 16,
            max: 254,
            divisions: 29,
            displayValue: '${state.optimizeColors}',
            onChanged: (v) => ctrl.setOptimizeColors(v.round()),
          ),
          const SizedBox(height: 8),
          OptionSlider(
            label: 'Lossy',
            value: state.optimizeLossy.toDouble(),
            min: 0,
            max: 80,
            divisions: 16,
            displayValue: state.optimizeLossy == 0
                ? 'Off'
                : '${state.optimizeLossy}',
            onChanged: (v) => ctrl.setOptimizeLossy(v.round()),
          ),
          const SizedBox(height: 14),
          const Text(
            'Remove frames',
            style: TextStyle(
              color: AppColors.textHi,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                const [
                  ('Keep all', 0),
                  ('1 / 4', 4),
                  ('1 / 3', 3),
                  ('1 / 2', 2),
                ].map((p) {
                  final selected = p.$2 == state.optimizeFrameDrop;
                  return ChoiceChip(
                    label: Text(p.$1),
                    selected: selected,
                    onSelected: (_) => ctrl.setOptimizeFrameDrop(p.$2),
                    selectedColor: AppColors.accentA.withValues(alpha: 0.3),
                    backgroundColor: AppColors.glassTint,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.accentB : AppColors.textHi,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppColors.accentA
                          : AppColors.glassStroke,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 14),
          LocalPalettesToggle(
            value: state.optimizeLocalPalettes,
            onChanged: ctrl.setOptimizeLocalPalettes,
          ),
        ],
      ],
    );
  }
}

// ── Properties panel (video: volume · smooth loop; gif: fps · loop count · boomerang · smooth loop) ──────

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({super.key, required this.state, required this.ctrl});
  final VideoStudioState state;
  final VideoStudioController ctrl;

  static const _loops = <(String, int)>[
    ('∞', 0),
    ('1', 1),
    ('2', 2),
    ('3', 3),
    ('5', 5),
    ('10', 10),
  ];

  // Shared by both stages: switch + status text + conditional crossfade
  // slider. [noun] fills the "___ longer than 3s only." gate message.
  List<Widget> _smoothLoopControls(String noun) => [
    Row(
      children: [
        Switch(
          value: state.smoothLoop,
          onChanged: state.canSmoothLoop ? ctrl.setSmoothLoop : null,
          activeThumbColor: AppColors.accentB,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Smooth Loop — crossfade last ${state.smoothLoopCrossfadeMs}ms into first ${state.smoothLoopCrossfadeMs}ms',
            style: const TextStyle(color: AppColors.textHi, fontSize: 14),
          ),
        ),
      ],
    ),
    const SizedBox(height: 6),
    Text(
      !state.canSmoothLoop
          ? '$noun longer than 3s only.'
          : (state.smoothLoop && !state.smoothLoopValid
                ? 'Speed/trim leave too little to crossfade — turn Smooth Loop off.'
                : 'Loops seamlessly by dissolving the tail into the head.'),
      style: const TextStyle(color: AppColors.textLo, fontSize: 11),
    ),
    if (state.smoothLoop) ...[
      const SizedBox(height: 8),
      OptionSlider(
        label: 'Crossfade duration',
        value: state.smoothLoopCrossfadeMs.toDouble(),
        min: 500,
        max: 1000,
        divisions: 5,
        displayValue: '${state.smoothLoopCrossfadeMs}ms',
        onChanged: (v) => ctrl.setSmoothLoopCrossfadeMs(v.round()),
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    // Video: volume + smooth loop (no fps/loopCount/boomerang — GIF concepts).
    if (!state.isGif) {
      final pct = (state.volume * 100).round();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OptionSlider(
            label: 'Volume',
            value: (state.volume * 100).clamp(0, 200),
            min: 0,
            max: 200,
            divisions: 40,
            displayValue: state.hasAudio ? '$pct%' : 'No audio',
            onChanged: state.hasAudio ? (v) => ctrl.setVolume(v / 100) : (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            state.hasAudio
                ? '100% = original · 0% mutes · up to 200% louder.'
                : 'This video has no audio track.',
            style: const TextStyle(color: AppColors.textLo, fontSize: 11),
          ),
          const SizedBox(height: 14),
          ..._smoothLoopControls('Clips'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OptionSlider(
          label: 'Frame rate',
          value: state.fps.toDouble().clamp(5, 30),
          min: 5,
          max: 30,
          divisions: 25,
          displayValue: '${state.fps} fps',
          onChanged: (v) => ctrl.setFps(v.round()),
        ),
        const SizedBox(height: 4),
        Text(
          state.isGif
              ? 'Lowering re-times the GIF; you can\'t add frames back.'
              : 'Higher = smoother but larger.',
          style: const TextStyle(color: AppColors.textLo, fontSize: 11),
        ),
        const SizedBox(height: 14),
        const Text(
          'Loops',
          style: TextStyle(
            color: AppColors.textHi,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final opt in _loops)
              _SmallChip(
                label: opt.$1,
                selected: state.loopCount == opt.$2,
                onTap: () => ctrl.setLoopCount(opt.$2),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          state.loopCount == 0
              ? 'Plays forever'
              : 'Plays then repeats ${state.loopCount}×',
          style: const TextStyle(color: AppColors.textLo, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: state.boomerang,
              onChanged: state.smoothLoop ? null : ctrl.setBoomerang,
              activeThumbColor: AppColors.accentB,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Boomerang — reverse for a seamless loop',
                style: TextStyle(color: AppColors.textHi, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._smoothLoopControls('GIFs'),
      ],
    );
  }
}

// ── Action bar ───────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.state,
    required this.ctrl,
    required this.toast,
  });
  final VideoStudioState state;
  final VideoStudioController ctrl;
  final void Function(String) toast;

  @override
  Widget build(BuildContext context) {
    if (state.isGif) {
      final inputIsGif =
          state.inputFile?.path.toLowerCase().endsWith('.gif') == true;
      return Row(
        children: [
          if (!inputIsGif) ...[
            _SecondaryButton(
              icon: Icons.arrow_back_rounded,
              label: 'Back to video',
              onTap: () async {
                final ok = await GlassConfirmDialog.show(
                  context,
                  title: 'Discard GIF edits?',
                  message:
                      'Going back will discard all changes made to the GIF.',
                  confirmLabel: 'Discard',
                  isDestructive: true,
                );
                if (ok == true) ctrl.discardGif();
              },
            ),
            const SizedBox(width: 10),
          ],
          _IconButton(
            icon: Icons.undo_rounded,
            tooltip: 'Undo',
            enabled: ctrl.canUndo,
            onTap: () {
              if (!ctrl.undo()) toast('Nothing to undo');
            },
          ),
          const SizedBox(width: 8),
          _IconButton(
            icon: Icons.redo_rounded,
            tooltip: 'Redo',
            enabled: ctrl.canRedo,
            onTap: () {
              if (!ctrl.redo()) toast('Nothing to redo');
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SecondaryButton(
              icon: Icons.auto_fix_high_rounded,
              label: 'Apply',
              enabled: state.hasPendingApply,
              onTap: () async {
                final ok = await ctrl.applyEdits();
                if (ok) toast('Applied to preview');
              },
            ),
          ),
          const SizedBox(width: 10),
          _PrimaryButton(
            icon: Icons.save_alt_rounded,
            label: 'Export',
            tooltip: 'Export GIF',
            onTap: () async {
              final ok = await ctrl.exportGif();
              toast(ok ? 'GIF saved' : 'Export cancelled');
            },
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _SecondaryButton(
            icon: Icons.auto_fix_high_rounded,
            label: 'Apply',
            enabled: state.hasPendingApply,
            onTap: () async {
              final ok = await ctrl.applyVideoEdits();
              if (ok) toast('Applied to preview');
            },
          ),
        ),
        const SizedBox(width: 10),
        _PrimaryButton(
          icon: Icons.save_alt_rounded,
          label: 'Export',
          tooltip: 'Export Video',
          onTap: () async {
            final format = await Navigator.of(context).push<ExportVideoFormat>(
              _formatPageRoute(
                ExportFormatScreen(initial: ctrl.lastExportFormat),
              ),
            );
            if (format == null) return;
            await ctrl.setLastExportFormat(format);
            final ok = await ctrl.exportVideo(format: format);
            toast(
              ok
                  ? '${format == ExportVideoFormat.webm ? 'WebM' : 'Video'} saved'
                  : 'Export cancelled',
            );
          },
        ),
      ],
    );
  }
}

// Primary action (gradient fill). Pass [label] to show text next to the
// icon; omit for an icon-only button. [tooltip] names the action either way.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    this.label,
    this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget btn = GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.primaryButton,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 15,
            horizontal: label == null ? 18 : 16,
          ),
          child: label == null
              ? Icon(icon, color: Colors.white, size: 22)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
    if (tooltip != null) btn = Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.glassTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassStroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.textHi, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textHi,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.textHi
        : AppColors.textLo.withValues(alpha: 0.35);
    Widget btn = GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.glassTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassStroke),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
    if (tooltip != null) btn = Tooltip(message: tooltip!, child: btn);
    return Opacity(opacity: enabled ? 1 : 0.6, child: btn);
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 12,
      tint: Colors.red,
      opacity: 0.08,
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toast (top-anchored, non-blocking) ───────────────────────────────────────
//
// Replaces the default bottom SnackBar, which floated over the action bar
// (undo / redo / apply / export). This anchors below the app bar instead, so
// the buttons stay tappable while a message is visible.
class _StudioToast {
  _StudioToast._();

  static OverlayEntry? _entry;

  static void show(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry?.remove();
    _entry = null;

    final topInset = MediaQuery.of(context).padding.top;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: topInset + 72,
        left: 16,
        right: 16,
        child: _ToastCard(
          message: message,
          onDismissed: () {
            if (_entry == entry) _entry = null;
            entry.remove();
          },
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({required this.message, required this.onDismissed});
  final String message;
  final VoidCallback onDismissed;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.45),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2200), _dismiss);
  }

  Future<void> _dismiss() async {
    if (_done || !mounted) return;
    _done = true;
    await _c.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: GlassContainer(
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.accentB,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: AppColors.textHi,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay({
    required this.label,
    required this.progress,
    required this.onCancel,
  });
  final String label;
  final double? progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: GlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      value: progress,
                      color: AppColors.accentB,
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    progress != null
                        ? '${(progress! * 100).round()}%  $label'
                        : label,
                    style: const TextStyle(
                      color: AppColors.textHi,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.accentC),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
