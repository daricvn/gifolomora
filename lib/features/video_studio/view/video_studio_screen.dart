import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/font_registry.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../_shared/widgets/file_drop_zone.dart';
import '../../_shared/widgets/option_slider.dart';
import '../../_shared/widgets/text_overlay_controls.dart';
import '../../_shared/widgets/video_preview.dart';
import '../../text_overlay/model/text_item.dart';
import '../widgets/cut_segment_slider.dart';
import '../widgets/video_trim_slider.dart';
import '../controller/video_studio_controller.dart';

// ffmpeg drawtext anchors the glyph top at y; Flutter's line box keeps ~0.1em
// of ascent above caps. Lift the preview text so the on-screen top matches the
// rendered output. (calibration knob — mirrors the Text Overlay screen)
const double _kTextTopBias = 0.10;

String _fmtMs(int ms) {
  if (ms <= 0) return '0:00';
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

const _kVideoExtensions = ['mp4', 'mov', 'mkv', 'avi', 'webm'];
const _kAllExtensions = [..._kVideoExtensions, 'gif'];

class VideoStudioScreen extends ConsumerStatefulWidget {
  const VideoStudioScreen({super.key, this.initialFile});

  final File? initialFile;

  @override
  ConsumerState<VideoStudioScreen> createState() => _VideoStudioScreenState();
}

class _VideoStudioScreenState extends ConsumerState<VideoStudioScreen> {
  int _positionMs = 0;
  bool _picking = false;
  // Preview zoom: null = Fit to window; otherwise a video-px scale.
  double? _zoom = 1.0;
  late final VideoPreviewController _previewCtrl;
  // Pan offset for the preview when zoomed past the pane. Owned so it can be
  // reset to identity when the frame shrinks back to fit (else stale pan keeps
  // the preview pushed off-screen and truncated).
  final TransformationController _transform = TransformationController();

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(videoStudioControllerProvider.notifier)
              .setInput(widget.initialFile!);
        }
      });
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    _previewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoStudioControllerProvider).valueOrNull ??
        const VideoStudioState();
    final ctrl = ref.read(videoStudioControllerProvider.notifier);
    final topInset = MediaQuery.of(context).padding.top;

    void toast(String msg) {
      if (!context.mounted) return;
      _StudioToast.show(context, msg);
    }

    return GradientScaffold(
      appBar: GlassAppBar(
        title: 'Video Studio',
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              iconSize: 20,
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textHi),
            onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        actions: [
          if (state.hasInput && !state.isProcessing)
            IconButton(
              tooltip: 'Start over',
              icon: const Icon(Icons.restart_alt_rounded,
                  color: AppColors.textLo, size: 22),
              onPressed: ctrl.clear,
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
    if (state.isProbing) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.accentB),
          SizedBox(height: 12),
          Text('Reading file…',
              style: TextStyle(color: AppColors.textLo, fontSize: 13)),
        ]),
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
          onChangeVideo: state.isProcessing || _picking ? null : () => _pickFile(ctrl),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: LayoutBuilder(
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
                double fitScale = 1.0;
                if (baseW > 0 && baseH > 0) {
                  fitScale = math.min(
                    constraints.maxWidth / baseW,
                    constraints.maxHeight / baseH,
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
                              key: ValueKey(state.sourceFile!.path),
                              file: state.sourceFile!,
                              videoWidth: srcW,
                              videoHeight: srcH,
                              speedRate: state.speedFactor,
                              volume: state.volume,
                              cropRect: (cropActive || !state.isCropFull)
                                  ? state.cropNormalized
                                  : null,
                              interactive: cropActive,
                              onCropChanged: ctrl.setCrop,
                              controller: _previewCtrl,
                              onPositionChanged: (ms) =>
                                  setState(() => _positionMs = ms),
                              trimStartMs: state.trimStartMs,
                              trimEndMs: state.sourceDurationMs > 0
                                  ? state.effectiveTrimEndMs
                                  : 0,
                            ),
                          ),
                          if (state.textItems.isNotEmpty)
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
                          // Red tint when playhead is inside a cut segment (hint only).
                          if (!state.isGif &&
                              state.cutSegments.any((s) =>
                                  _positionMs >= s.startMs &&
                                  _positionMs < s.endMs))
                            const Positioned.fill(
                              child: IgnorePointer(
                                child: ColoredBox(color: Color(0x80FF0000)),
                              ),
                            ),
                          // YouTube-style controls — videos only, and only when
                          // no canvas tool (crop/text) owns the preview gestures.
                          if (!state.isGif && !cropActive && !textActive)
                            Positioned.fill(
                              child: _VideoControlsOverlay(
                                controller: _previewCtrl,
                                positionMs: _positionMs,
                                durationMs: state.sourceDurationMs,
                                onSeek: (ms) {
                                  _previewCtrl.seekTo(ms);
                                  setState(() => _positionMs = ms);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );

                final overflowX = renderW > constraints.maxWidth + 0.5;
                final overflowY = renderH > constraints.maxHeight + 0.5;
                // Crop's drag gesture owns the whole frame, so pan stays off
                // during crop to avoid fighting the handles.
                final canPan = !fitMode &&
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
                      height: math.max(renderH, constraints.maxHeight),
                      child: Center(child: preview),
                    ),
                  ),
                );

                return Stack(
                  children: [
                    Positioned.fill(child: pane),
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
        _ControlDock(
          state: state,
          ctrl: ctrl,
          toast: toast,
          positionMs: _positionMs,
          onSeekPreview: (ms) {
            _previewCtrl.seekTo(ms);
            setState(() => _positionMs = ms);
          },
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
              color: state.isGif ? AppColors.accentC.withValues(alpha: 0.25) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
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
                    fontWeight: FontWeight.w700),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                if (dims.isNotEmpty) dims,
                if (!state.isGif)
                  state.hasAudio ? 'audio' : 'no audio',
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
              icon: const Icon(Icons.video_library_rounded,
                  size: 15, color: AppColors.accentB),
              label: const Text('Change',
                  style: TextStyle(color: AppColors.accentB, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// ── Zoom control (preview magnifier) ─────────────────────────────────────────

// label, video-px scale. null scale = Fit to window.
const _kZoomPresets = <(String, double?)>[
  ('50%', 0.5),
  ('75%', 0.75),
  ('100%', 1.0),
  ('125%', 1.25),
  ('150%', 1.5),
  ('200%', 2.0),
  ('Fit', null),
];

class _ZoomControl extends StatelessWidget {
  const _ZoomControl({required this.zoom, required this.onChanged});
  final double? zoom;
  final void Function(double?) onChanged;

  String get _label {
    for (final p in _kZoomPresets) {
      if (p.$2 == zoom) return p.$1;
    }
    return 'Fit';
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
            const Icon(Icons.zoom_in_rounded,
                size: 15, color: AppColors.accentB),
            const SizedBox(width: 5),
            Text(
              _label,
              style: const TextStyle(
                  color: AppColors.textHi,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: AppColors.textLo),
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
  });
  final VideoPreviewController controller;
  final int positionMs;
  final int durationMs;
  final void Function(int ms) onSeek;

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

  void _show() {
    _hideTimer?.cancel();
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      // Stay visible while paused or scrubbing.
      if (!mounted || _dragging || !widget.controller.playing.value) return;
      setState(() => _visible = false);
    });
  }

  void _toggleVisible() {
    if (_visible) {
      _hideTimer?.cancel();
      setState(() => _visible = false);
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
          setState(() => _visible = false);
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
              Text(_fmtMs(pos.round()),
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: Colors.red,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                    thumbColor: Colors.red,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
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
              Text(_fmtMs(dur),
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
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
  final int positionMs;
  final void Function(int ms) onSeekPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        border:
            Border(top: BorderSide(color: AppColors.glassStroke, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolSelector(
            active: state.activeTool,
            onSelect: ctrl.setActiveTool,
            isGif: state.isGif,
          ),
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
    );
  }
}

class _ToolSelector extends StatelessWidget {
  const _ToolSelector({
    required this.active,
    required this.onSelect,
    required this.isGif,
  });
  final StudioTool? active;
  final void Function(StudioTool?) onSelect;
  final bool isGif;

  @override
  Widget build(BuildContext context) {
    // (tool, icon, label, disabled, tag)
    final tools = [
      (StudioTool.crop, Icons.crop_rounded, 'Crop', false, null),
      (StudioTool.resize, Icons.photo_size_select_large_rounded, 'Resize', false, null),
      (StudioTool.speed, Icons.speed_rounded, 'Speed', false, null),
      if (!isGif) (StudioTool.trim, Icons.straighten_rounded, 'Trim', false, null),
      if (!isGif) (StudioTool.cut, Icons.cut_rounded, 'Cut', false, null),
      (StudioTool.text, Icons.title_rounded, 'Text', false, null),
      if (isGif) (StudioTool.optimize, Icons.tune_rounded, 'Optimise', false, null),
      (StudioTool.properties, Icons.settings_suggest_rounded, 'Props', false, null),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in tools)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 44) / (tools.length + 1),
            child: _ToolButton(
              icon: t.$2,
              label: t.$3,
              selected: active == t.$1,
              disabled: t.$4,
              tag: t.$5,
              onTap: t.$4 ? null : () => onSelect(active == t.$1 ? null : t.$1),
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
    this.disabled = false,
    this.tag,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool disabled;
  final String? tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled
        ? AppColors.textLo.withValues(alpha: 0.35)
        : selected
            ? Colors.white
            : AppColors.textHi;
    final btn = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: selected && !disabled ? AppGradients.primaryButton : null,
        color: selected && !disabled ? null : AppColors.glassTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected && !disabled
              ? Colors.transparent
              : AppColors.glassStroke,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: effectiveColor),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: effectiveColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: tag == null
          ? btn
          : Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                btn,
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accentC.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          height: 1.2),
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
  final int positionMs;
  final void Function(int ms) onSeekPreview;
  final void Function(String) toast;

  @override
  Widget build(BuildContext context) {
    switch (state.activeTool) {
      case StudioTool.crop:
        return Row(
          key: const ValueKey('crop'),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text('Drag the handles on the preview to crop',
                  style: TextStyle(color: AppColors.textLo, fontSize: 12)),
            ),
            if (!state.isCropFull)
              TextButton.icon(
                onPressed: ctrl.resetCrop,
                icon: const Icon(Icons.crop_free_rounded,
                    size: 14, color: AppColors.accentB),
                label: const Text('Reset',
                    style: TextStyle(color: AppColors.accentB, fontSize: 12)),
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
                Text('0.25× slower',
                    style:
                        TextStyle(color: AppColors.textLo, fontSize: 11)),
                Text('4× faster',
                    style:
                        TextStyle(color: AppColors.textLo, fontSize: 11)),
              ],
            ),
          ],
        );
      case StudioTool.trim:
        return _TrimPanel(
          key: const ValueKey('trim'),
          state: state,
          ctrl: ctrl,
          positionMs: positionMs,
          onSeekPreview: onSeekPreview,
        );
      case StudioTool.cut:
        return _CutPanel(
          key: const ValueKey('cut'),
          state: state,
          ctrl: ctrl,
          positionMs: positionMs,
          onSeekPreview: onSeekPreview,
          toast: toast,
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
    super.key,
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
    final clipMs = (endMs - state.trimStartMs).clamp(0, totalMs > 0 ? totalMs : 1);

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
            _TrimChip(
              icon: Icons.logout_rounded,
              label: 'Out',
              ms: endMs,
            ),
            if (state.hasTrim)
              TextButton.icon(
                onPressed: ctrl.resetTrim,
                icon: const Icon(Icons.restore_rounded,
                    size: 13, color: AppColors.accentB),
                label: const Text('Reset',
                    style: TextStyle(color: AppColors.accentB, fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
    super.key,
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
    if (_pendingStartMs < lo) _pendingStartMs = lo;
    if (_pendingEndMs > hi) _pendingEndMs = hi;
    if (_pendingEndMs - _pendingStartMs <= 0) {
      _pendingEndMs = (_pendingStartMs + 1000).clamp(lo, hi);
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
            onPendingChanged: (start, end) =>
                setState(() {
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
            GestureDetector(
              onTap: () {
                final ok = widget.ctrl.addCutSegment(_pendingStartMs, _pendingEndMs);
                if (!ok) widget.toast("Can't add that segment");
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cut_rounded, color: Colors.redAccent, size: 14),
                  SizedBox(width: 6),
                  Text('Mark for removal',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
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
          ...s.cutSegments.map((seg) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.30)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.cut_rounded,
                            color: Colors.redAccent, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${_fmtMs(seg.startMs)} – ${_fmtMs(seg.endMs)}',
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => widget.ctrl.removeCutSegment(seg),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: AppColors.textLo),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          Text(
            'Output ≈ ${_fmtMs(s.cutOutputMs)}',
            style: const TextStyle(color: AppColors.textLo, fontSize: 12),
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
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No system font found. Text may fail to render.',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ]),
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
            selected: item.id == state.selectedTextId,
            scale: scale,
            renderW: renderW,
            renderH: renderH,
            fontFamily: FontRegistry.familyFor(item.font, item.style) ??
                state.fontFamilies[item.style],
            ctrl: ctrl,
          ),
      ],
    );
    return interactive ? layer : IgnorePointer(child: layer);
  }
}

class _StudioDraggableText extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = item.fontSize * scale;
    // When the real font file is loaded its weight/style are baked in — don't
    // also synthesize bold/italic or it doubles up.
    final hasFam = fontFamily != null;
    final fw = !hasFam &&
            (item.style == TextStyleKind.bold ||
                item.style == TextStyleKind.boldItalic)
        ? FontWeight.w700
        : FontWeight.w400;
    final fst = !hasFam &&
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
      left: item.nx * renderW,
      top: item.ny * renderH - fs * _kTextTopBias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ctrl.selectText(item.id),
        onPanDown: (_) => ctrl.selectText(item.id),
        onPanUpdate: (d) {
          final cur =
              ref.read(videoStudioControllerProvider).valueOrNull?.selectedText;
          if (cur == null) return;
          ctrl.moveSelectedText(
            cur.nx + d.delta.dx / renderW,
            cur.ny + d.delta.dy / renderH,
          );
        },
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
          Text(label,
              style: const TextStyle(color: AppColors.textLo, fontSize: 10)),
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
  const _SmallChip(
      {required this.label, required this.selected, required this.onTap});
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
                  borderRadius: BorderRadius.circular(10)),
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
              Text('10% smaller',
                  style: TextStyle(color: AppColors.textLo, fontSize: 11)),
              Text('200% larger',
                  style: TextStyle(color: AppColors.textLo, fontSize: 11)),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Optimize panel ────────────────────────────────────────────────────────────

class _OptimizePanel extends StatelessWidget {
  const _OptimizePanel({
    super.key,
    required this.state,
    required this.ctrl,
  });
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
            const Text('Optimise output GIF',
                style: TextStyle(color: AppColors.textHi, fontSize: 14)),
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
            displayValue:
                state.optimizeLossy == 0 ? 'Off' : '${state.optimizeLossy}',
            onChanged: (v) => ctrl.setOptimizeLossy(v.round()),
          ),
          const SizedBox(height: 14),
          const Text('Remove frames',
              style: TextStyle(
                  color: AppColors.textHi,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
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
                  color: selected ? AppColors.accentA : AppColors.glassStroke,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Properties panel (video: volume · gif: fps · loop count · boomerang) ──────

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({
    super.key,
    required this.state,
    required this.ctrl,
  });
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

  @override
  Widget build(BuildContext context) {
    // Video: audio volume only (no fps/loop/reverse — those are GIF concepts).
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
            onChanged: state.hasAudio
                ? (v) => ctrl.setVolume(v / 100)
                : (_) {},
          ),
          const SizedBox(height: 4),
          Text(
            state.hasAudio
                ? '100% = original · 0% mutes · up to 200% louder.'
                : 'This video has no audio track.',
            style: const TextStyle(color: AppColors.textLo, fontSize: 11),
          ),
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
        const Text('Loops',
            style: TextStyle(
                color: AppColors.textHi,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
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
              onChanged: ctrl.setBoomerang,
              activeThumbColor: AppColors.accentB,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Boomerang — reverse for a seamless loop',
                  style: TextStyle(color: AppColors.textHi, fontSize: 14)),
            ),
          ],
        ),
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
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Discard GIF edits?'),
                    content: const Text(
                        'Going back will discard all changes made to the GIF.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Discard',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
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
              onTap: () async {
                final ok = await ctrl.applyEdits();
                toast(ok ? 'Applied to preview' : 'Nothing to apply');
              },
            ),
          ),
          const SizedBox(width: 10),
          _PrimaryButton(
            icon: Icons.save_alt_rounded,
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
        _SecondaryButton(
          icon: Icons.gif_box_rounded,
          label: 'Make GIF',
          onTap: () async {
            if (state.effectiveOutputMs > 60000) {
              final proceed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Video too long'),
                  content: const Text(
                      'GIF is limited to 60 seconds. Trim the video first for best results, or only the first 60 seconds will be used.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Use first 60s'),
                    ),
                  ],
                ),
              );
              if (proceed != true) return;
            }
            final ok = await ctrl.makeGif();
            if (!ok) toast('Could not create GIF');
          },
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SecondaryButton(
            icon: Icons.auto_fix_high_rounded,
            label: 'Apply',
            onTap: () async {
              final ok = await ctrl.applyVideoEdits();
              toast(ok ? 'Applied to preview' : 'Nothing to apply');
            },
          ),
        ),
        const SizedBox(width: 10),
        _PrimaryButton(
          icon: Icons.save_alt_rounded,
          tooltip: 'Export Video',
          onTap: () async {
            final ok = await ctrl.exportVideo();
            toast(ok ? 'Video saved' : 'Export cancelled');
          },
        ),
      ],
    );
  }
}

// Icon-only primary action (gradient fill). Pass [tooltip] to name the action.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.icon, this.tooltip, required this.onTap});
  final IconData icon;
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
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
    if (tooltip != null) btn = Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            Text(label,
                style: const TextStyle(
                    color: AppColors.textHi,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
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
    final color =
        enabled ? AppColors.textHi : AppColors.textLo.withValues(alpha: 0.35);
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
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 12)),
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
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.accentB, size: 18),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(widget.message,
                          style: const TextStyle(
                              color: AppColors.textHi,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
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
                        color: AppColors.textHi, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.accentC)),
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
