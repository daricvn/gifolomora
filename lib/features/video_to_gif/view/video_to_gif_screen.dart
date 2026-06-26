import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../_shared/widgets/export_bottom_sheet.dart';
import '../../_shared/widgets/file_drop_zone.dart';
import '../../_shared/widgets/media_preview.dart';
import '../../_shared/widgets/option_slider.dart';
import '../controller/video_to_gif_controller.dart';
import '../widgets/video_trim_slider.dart';

String _fmt(int ms) {
  if (ms <= 0) return '0:00';
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String _fmtBytes(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Output resolution label for the current width override.
String _outputResolution(VideoToGifState s) {
  final sw = s.mediaInfo?.width ?? 0;
  final sh = s.mediaInfo?.height ?? 0;
  if (s.width == null || s.width == 0) {
    return (sw > 0 && sh > 0) ? '$sw × $sh' : 'Original';
  }
  final ow = s.width!;
  final oh = (sw > 0 && sh > 0) ? (ow * sh / sw).round() : 0;
  return oh > 0 ? '$ow × $oh' : '${ow}px';
}

int _estimatedFrames(VideoToGifState s) {
  final durMs = s.trimDurationMs > 0 ? s.trimDurationMs : s.totalMs;
  return (durMs / 1000 * s.fps).round();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class VideoToGifScreen extends ConsumerStatefulWidget {
  const VideoToGifScreen({super.key});

  @override
  ConsumerState<VideoToGifScreen> createState() => _VideoToGifScreenState();
}

class _VideoToGifScreenState extends ConsumerState<VideoToGifScreen> {
  Future<void> _export() async {
    if (!mounted) return;
    await ExportBottomSheet.show(
      context,
      onExport: () async {
        final ok =
            await ref.read(videoToGifControllerProvider.notifier).exportGif();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export cancelled')),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoToGifControllerProvider).valueOrNull ??
        const VideoToGifState();
    final ctrl = ref.read(videoToGifControllerProvider.notifier);

    return GradientScaffold(
      appBar: GlassAppBar(
        title: 'Video → GIF',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textHi, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      bottomNavigationBar:
          state.outputGif != null ? _ExportBar(onExport: _export) : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16 + MediaQuery.of(context).padding.top + 64,
          16,
          110,
        ),
        children: [
          // ── Step 1: Pick + preview + trim ─────────────────────────────
          const _SectionHeader(
            number: 1,
            title: 'Select Video',
            subtitle: 'MP4, MOV, AVI, MKV, WebM',
          ),
          const SizedBox(height: 14),
          if (state.isProbing)
            const _LoadingCard(text: 'Reading video…')
          else if (!state.hasInput)
            FileDropZone(
              hint: 'Tap to select a video',
              icon: Icons.video_file_rounded,
              allowedExtensions: const [
                'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v',
              ],
              onFilesSelected: (files) {
                if (files.isNotEmpty) ctrl.setInput(files.first);
              },
            )
          else ...[
            _FileInfoCard(
              file: state.inputFile!,
              durationMs: state.totalMs,
              width: state.mediaInfo?.width,
              height: state.mediaInfo?.height,
              onClear: ctrl.clear,
            ),
            const SizedBox(height: 12),
            _VideoSection(
              file: state.inputFile!,
              totalMs: state.totalMs,
              startMs: state.startMs,
              endMs: state.effectiveEndMs,
              videoWidth: state.mediaInfo?.width ?? 0,
              videoHeight: state.mediaInfo?.height ?? 0,
              onStartChanged: ctrl.setStart,
              onEndChanged: ctrl.setEnd,
            ),
          ],

          // ── Step 2: Options ────────────────────────────────────────────
          if (state.hasInput && !state.isProbing) ...[
            const SizedBox(height: 28),
            const _SectionHeader(
              number: 2,
              title: 'Output Settings',
              subtitle: 'Frame rate & dimensions',
            ),
            const SizedBox(height: 14),
            GlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                children: [
                  OptionSlider(
                    label: 'Frame rate',
                    value: state.fps.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 25,
                    unit: ' fps',
                    onChanged: (v) => ctrl.setFps(v.round()),
                  ),
                  const SizedBox(height: 10),
                  OptionSlider(
                    label: 'Width',
                    value: (state.width ?? 0).toDouble(),
                    min: 0,
                    max: 1280,
                    divisions: 64,
                    displayValue: state.width == null || state.width == 0
                        ? 'Original'
                        : '${state.width}px',
                    onChanged: (v) =>
                        ctrl.setWidth(v.round() == 0 ? null : v.round()),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.glassStroke, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _EstimateStat(
                        icon: Icons.aspect_ratio_rounded,
                        label: 'Resolution',
                        value: _outputResolution(state),
                      ),
                      const _EstimateDivider(),
                      _EstimateStat(
                        icon: Icons.burst_mode_rounded,
                        label: 'Frames',
                        value: '~${_estimatedFrames(state)}',
                      ),
                      const _EstimateDivider(),
                      _EstimateStat(
                        icon: Icons.timer_outlined,
                        label: 'Length',
                        value: _fmt(state.trimDurationMs),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Step 3: Preview / Generate ─────────────────────────────
            const SizedBox(height: 28),
            const _SectionHeader(
              number: 3,
              title: 'Preview & Generate',
              subtitle: 'Render a preview before exporting',
            ),
            const SizedBox(height: 14),
            if (state.isProcessing)
              _ProgressCard(
                  progress: state.progress?.fraction, onCancel: ctrl.cancel)
            else if (state.outputGif != null)
              _OutputSection(
                file: state.outputGif!,
                onRegenerate: ctrl.generate,
              )
            else
              _GenerateButton(onTap: ctrl.generate),

            if (state.error != null) ...[
              const SizedBox(height: 12),
              _ErrorCard(message: state.error!),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Video Section (player + trim slider) ─────────────────────────────────────

class _VideoSection extends StatefulWidget {
  const _VideoSection({
    required this.file,
    required this.totalMs,
    required this.startMs,
    required this.endMs,
    required this.videoWidth,
    required this.videoHeight,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final File file;
  final int totalMs;
  final int startMs;
  final int endMs;
  final int videoWidth;
  final int videoHeight;
  final void Function(int ms) onStartChanged;
  final void Function(int ms) onEndChanged;

  @override
  State<_VideoSection> createState() => _VideoSectionState();
}

class _VideoSectionState extends State<_VideoSection> {
  late final Player _player;
  late final VideoController _videoController;

  bool _loading = true;
  bool _initialized = false;
  int _positionMs = 0;
  bool _isPlaying = false;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  String? _activePath;

  @override
  void initState() {
    super.initState();
    _positionMs = widget.startMs;
    _player = Player();
    _videoController = VideoController(_player);
    _openFile(widget.file);
  }

  @override
  void didUpdateWidget(_VideoSection old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) {
      _positionMs = widget.startMs;
      _openFile(widget.file);
    }
  }

  Future<void> _openFile(File file) async {
    _activePath = file.path;
    _positionSub?.cancel();
    _playingSub?.cancel();
    if (mounted) {
      setState(() {
        _loading = true;
        _initialized = false;
        _isPlaying = false;
      });
    }

    try {
      await _player.open(Media(file.path), play: false);
      if (!mounted || _activePath != file.path) return;

      _positionSub = _player.stream.position.listen((pos) {
        if (!mounted) return;
        final ms = pos.inMilliseconds;
        if (widget.endMs > 0 && ms >= widget.endMs) {
          _player.pause();
          _player.seek(Duration(milliseconds: widget.endMs));
          if (mounted) {
            setState(() {
              _positionMs = widget.endMs;
              _isPlaying = false;
            });
          }
          return;
        }
        if (mounted) setState(() => _positionMs = ms);
      });

      _playingSub = _player.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });

      if (mounted) {
        setState(() {
          _loading = false;
          _initialized = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _initialized = false;
        });
      }
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _player.pause();
    } else {
      if (widget.endMs > 0 &&
          (_positionMs >= widget.endMs || _positionMs < widget.startMs)) {
        _player.seek(Duration(milliseconds: widget.startMs));
      }
      _player.play();
    }
  }

  void _seek(int ms) {
    _player.seek(Duration(milliseconds: ms));
    if (mounted) setState(() => _positionMs = ms);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Widget _buildTrimControls(int effectiveTotalMs) {
    final trimMs = (widget.endMs - widget.startMs).clamp(0, effectiveTotalMs);
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          VideoTrimSlider(
            totalMs: effectiveTotalMs,
            startMs: widget.startMs,
            endMs: widget.endMs,
            positionMs: _positionMs.clamp(0, effectiveTotalMs),
            onStartChanged: (ms) {
              widget.onStartChanged(ms);
              if (_positionMs < ms) _seek(ms);
            },
            onEndChanged: (ms) {
              widget.onEndChanged(ms);
              if (_positionMs > ms) _seek(ms);
            },
            onSeek: _seek,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TrimChip(
                icon: Icons.login_rounded,
                label: 'In',
                ms: widget.startMs,
              ),
              _TrimChip(
                icon: Icons.straighten_rounded,
                label: 'Clip',
                ms: trimMs,
                highlight: true,
              ),
              _TrimChip(
                icon: Icons.logout_rounded,
                label: 'Out',
                ms: widget.endMs,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _LoadingCard(text: 'Loading video…');

    final totalMs = widget.totalMs > 0
        ? widget.totalMs
        : _player.state.duration.inMilliseconds;
    final ar = widget.videoWidth > 0 && widget.videoHeight > 0
        ? widget.videoWidth / widget.videoHeight.toDouble()
        : 16 / 9.0;

    if (!_initialized) {
      return _buildTrimControls(totalMs > 0 ? totalMs : widget.totalMs);
    }

    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.70,
          ),
          child: GlassContainer(
            borderRadius: 22,
            padding: const EdgeInsets.all(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: AspectRatio(
                aspectRatio: ar,
                child: GestureDetector(
                  onTap: _togglePlay,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Video(
                        controller: _videoController,
                        controls: NoVideoControls,
                      ),
                      // Center play / pause control
                      Center(
                        child: AnimatedScale(
                          scale: _isPlaying ? 0.7 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: AnimatedOpacity(
                            opacity: _isPlaying ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: IgnorePointer(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.42),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Bottom scrim + time readout
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            padding:
                                const EdgeInsets.fromLTRB(12, 24, 12, 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _fmt(_positionMs.clamp(0, totalMs)),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _fmt(totalMs),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
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
        const SizedBox(height: 12),
        _buildTrimControls(totalMs),
      ],
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: highlight ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: AppColors.textLo, fontSize: 11),
          ),
          const SizedBox(width: 6),
          Text(
            _fmt(ms),
            style: TextStyle(
              color: highlight ? AppColors.textHi : AppColors.accentB,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimateStat extends StatelessWidget {
  const _EstimateStat({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.accentB, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textHi,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textLo, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _EstimateDivider extends StatelessWidget {
  const _EstimateDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: AppColors.glassStroke,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
              color: AppColors.accentB, strokeWidth: 3),
        ),
        const SizedBox(height: 14),
        Text(text,
            style: const TextStyle(color: AppColors.textLo, fontSize: 13)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.number,
    required this.title,
    this.subtitle,
  });
  final int number;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: AppGradients.primaryButton,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentA.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textHi,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                        color: AppColors.textLo, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FileInfoCard extends StatefulWidget {
  const _FileInfoCard({
    required this.file,
    required this.durationMs,
    this.width,
    this.height,
    required this.onClear,
  });
  final File file;
  final int durationMs;
  final int? width;
  final int? height;
  final VoidCallback onClear;

  @override
  State<_FileInfoCard> createState() => _FileInfoCardState();
}

class _FileInfoCardState extends State<_FileInfoCard> {
  int _sizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _statSize();
  }

  @override
  void didUpdateWidget(_FileInfoCard old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) _statSize();
  }

  void _statSize() {
    try {
      _sizeBytes = widget.file.statSync().size;
    } catch (_) {
      _sizeBytes = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.file.path.split(Platform.pathSeparator).last;
    final dims = (widget.width != null && widget.height != null)
        ? '${widget.width}×${widget.height}'
        : null;
    final meta = [
      if (widget.durationMs > 0) _fmt(widget.durationMs),
      ?dims,
      if (_sizeBytes > 0) _fmtBytes(_sizeBytes),
    ].join('  ·  ');

    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accentB.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentB.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: const Icon(Icons.movie_rounded,
                color: AppColors.accentB, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textHi,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  style:
                      const TextStyle(color: AppColors.textLo, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textLo, size: 20),
            tooltip: 'Remove',
            onPressed: widget.onClear,
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({this.progress, required this.onCancel});
  final double? progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: AppColors.accentB, strokeWidth: 2.5),
              ),
              const SizedBox(width: 12),
              Text(
                progress != null
                    ? 'Rendering preview… ${(progress! * 100).round()}%'
                    : 'Rendering preview…',
                style: const TextStyle(
                  color: AppColors.textHi,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.accentC)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.glassStroke,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentB),
              minHeight: 7,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputSection extends StatelessWidget {
  const _OutputSection({required this.file, required this.onRegenerate});
  final File file;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    int sizeBytes = 0;
    try {
      sizeBytes = file.statSync().size;
    } catch (_) {}

    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.accentB, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Preview ready',
              style: TextStyle(
                color: AppColors.textHi,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (sizeBytes > 0)
              Text(
                _fmtBytes(sizeBytes),
                style:
                    const TextStyle(color: AppColors.textLo, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 10),
        MediaPreview(file: file),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onRegenerate,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Regenerate Preview'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textHi,
              side: const BorderSide(color: AppColors.glassStroke),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? AppGradients.primaryButton : null,
          color: enabled ? null : AppColors.glassTint,
          borderRadius: BorderRadius.circular(16),
          border:
              enabled ? null : Border.all(color: AppColors.glassStroke),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.accentA.withValues(alpha: 0.40),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: enabled ? Colors.white : AppColors.textLo, size: 20),
              const SizedBox(width: 10),
              Text(
                'Generate Preview',
                style: TextStyle(
                  color: enabled ? Colors.white : AppColors.textLo,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 16,
      tint: Colors.red,
      opacity: 0.08,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({required this.onExport});
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        border:
            Border(top: BorderSide(color: AppColors.glassStroke, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.primaryButton,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentA.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.save_alt_rounded,
                size: 18, color: Colors.white),
            label: const Text('Export GIF',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}
