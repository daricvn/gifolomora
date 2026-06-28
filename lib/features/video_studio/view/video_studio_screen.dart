import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../_shared/widgets/file_drop_zone.dart';
import '../../_shared/widgets/option_slider.dart';
import '../../_shared/widgets/video_preview.dart';
import '../widgets/video_trim_slider.dart';
import '../controller/video_studio_controller.dart';

const _kPositions = [
  ('Top', 'top'),
  ('Center', 'center'),
  ('Bottom', 'bottom'),
];

const _kTextColors = [
  ('White', 'white', Color(0xFFF2F4FF)),
  ('Yellow', 'yellow', Color(0xFFFFE066)),
  ('Black', 'black', Color(0xFF22242E)),
  ('Red', 'red', Color(0xFFFF5CAA)),
];

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
  late final VideoPreviewController _previewCtrl;

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
                double displayScale = 1.0;
                if (state.sourceWidth > 0 && state.sourceHeight > 0) {
                  final ar = state.sourceWidth / state.sourceHeight;
                  final cAR = constraints.maxWidth / constraints.maxHeight;
                  // Width the video naturally occupies in the preview container
                  final naturalW = cAR <= ar
                      ? constraints.maxWidth
                      : constraints.maxHeight * ar;
                  final effectiveW =
                      (state.targetWidth ?? state.sourceWidth).toDouble();
                  displayScale = (effectiveW / naturalW).clamp(0.1, 1.0);
                }
                return Center(
                  child: AnimatedScale(
                    scale: displayScale,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: GlassContainer(
                      borderRadius: 20,
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: VideoPreview(
                          key: ValueKey(state.sourceFile!.path),
                          file: state.sourceFile!,
                          videoWidth: state.sourceWidth,
                          videoHeight: state.sourceHeight,
                          speedRate: state.speedFactor,
                          cropRect: (state.activeTool == StudioTool.crop ||
                                  !state.isCropFull)
                              ? state.cropNormalized
                              : null,
                          interactive: state.activeTool == StudioTool.crop,
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
                    ),
                  ),
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
    final tools = [
      (StudioTool.crop, Icons.crop_rounded, 'Crop', false),
      (StudioTool.resize, Icons.photo_size_select_large_rounded, 'Resize', false),
      (StudioTool.speed, Icons.speed_rounded, 'Speed', false),
      if (isGif)
        (StudioTool.optimize, Icons.tune_rounded, 'Optimise', false)
      else
        (StudioTool.trim, Icons.content_cut_rounded, 'Trim', false),
      (StudioTool.text, Icons.text_fields_rounded, 'Text', false),
      (StudioTool.properties, Icons.settings_suggest_rounded, 'Props', false),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in tools)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 44) / 7,
            child: _ToolButton(
              icon: t.$2,
              label: t.$3,
              selected: active == t.$1,
              disabled: t.$4,
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
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled
        ? AppColors.textLo.withValues(alpha: 0.35)
        : selected
            ? Colors.white
            : AppColors.textHi;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
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
  });
  final VideoStudioState state;
  final VideoStudioController ctrl;
  final int positionMs;
  final void Function(int ms) onSeekPreview;

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
      case StudioTool.text:
        return _TextPanel(key: const ValueKey('text'), state: state, ctrl: ctrl);
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

// ── Text overlay panel ────────────────────────────────────────────────────────

class _TextPanel extends StatefulWidget {
  const _TextPanel({super.key, required this.state, required this.ctrl});
  final VideoStudioState state;
  final VideoStudioController ctrl;

  @override
  State<_TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends State<_TextPanel> {
  late final TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.state.overlayText);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final ctrl = widget.ctrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.overlayFontFile == null) ...[
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No system font found. Text may fail.',
                  style: TextStyle(
                      color: Colors.orange.withValues(alpha: 0.9),
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _textCtrl,
          onChanged: ctrl.setOverlayText,
          style: const TextStyle(color: AppColors.textHi, fontSize: 14),
          maxLines: 1,
          decoration: InputDecoration(
            hintText: 'Enter overlay text…',
            hintStyle:
                const TextStyle(color: AppColors.textLo, fontSize: 14),
            filled: true,
            fillColor: AppColors.glassTint,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.glassStroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.glassStroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accentA),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                children: _kPositions.map((pos) {
                  final selected = pos.$2 == state.overlayPosition;
                  return _SmallChip(
                    label: pos.$1,
                    selected: selected,
                    onTap: () => ctrl.setOverlayPosition(pos.$2),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                children: _kTextColors.map((entry) {
                  final selected = entry.$2 == state.overlayFontColor;
                  return _ColorDot(
                    color: entry.$3,
                    selected: selected,
                    onTap: () => ctrl.setOverlayFontColor(entry.$2),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OptionSlider(
          label: 'Size',
          value: state.overlayFontSize.toDouble(),
          min: 12,
          max: 96,
          divisions: 28,
          unit: 'px',
          onChanged: (v) => ctrl.setOverlayFontSize(v.round()),
        ),
      ],
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

class _ColorDot extends StatelessWidget {
  const _ColorDot(
      {required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.accentA : Colors.white.withValues(alpha: 0.25),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accentA.withValues(alpha: 0.4),
                    blurRadius: 6,
                  )
                ]
              : null,
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
            max: 256,
            divisions: 30,
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
        ],
      ],
    );
  }
}

// ── Properties panel (fps · loop count · boomerang) ───────────────────────────

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
              onTap: ctrl.discardGif,
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
          _SecondaryButton(
            icon: Icons.auto_fix_high_rounded,
            label: 'Apply',
            onTap: () async {
              final ok = await ctrl.applyEdits();
              toast(ok ? 'Applied to preview' : 'Nothing to apply');
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PrimaryButton(
              icon: Icons.save_alt_rounded,
              label: 'Export GIF',
              onTap: () async {
                final ok = await ctrl.exportGif();
                toast(ok ? 'GIF saved' : 'Export cancelled');
              },
            ),
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
            final ok = await ctrl.makeGif();
            if (!ok) toast('Could not create GIF');
          },
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PrimaryButton(
            icon: Icons.save_alt_rounded,
            label: 'Export Video',
            onTap: () async {
              final ok = await ctrl.exportVideo();
              toast(ok ? 'Video saved' : 'Export cancelled');
            },
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.primaryButton,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
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
