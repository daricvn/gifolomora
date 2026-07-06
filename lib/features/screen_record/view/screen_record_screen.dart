import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/record/screen_recorder_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../controller/record_controller.dart';
import '../widgets/audio_options_card.dart';
import '../widgets/hotkey_recorder_field.dart';
import '../widgets/monitor_card.dart';
import '../widgets/output_resolution_card.dart';
import '../widgets/storage_options_card.dart';

const _kHotkeyScope = 'record';

class ScreenRecordScreen extends ConsumerStatefulWidget {
  const ScreenRecordScreen({super.key});

  @override
  ConsumerState<ScreenRecordScreen> createState() => _ScreenRecordScreenState();
}

class _ScreenRecordScreenState extends ConsumerState<ScreenRecordScreen> {
  // Cached rather than looked up via `ref` in dispose() — Riverpod asserts
  // `ref` unusable once the element is mid-unmount, so the notifier must be
  // captured while the widget is still alive.
  late final RecordController _recordController =
      ref.read(recordControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Global hotkeys are live while this screen (or the home screen, or a
    // live recording) is on screen — never app-wide from other tools.
    Future.microtask(() => _recordController.enterHotkeyScope(_kHotkeyScope));
  }

  @override
  void dispose() {
    _recordController.exitHotkeyScope(_kHotkeyScope);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(recordControllerProvider);
    final ctrl = ref.read(recordControllerProvider.notifier);

    return GradientScaffold(
      appBar: GlassAppBar(
        title: 'Screen Record',
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textHi, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      body: asyncState.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accentB)),
        error: (e, _) => Center(
          child: Text('Failed to load Screen Record: $e',
              style: const TextStyle(color: AppColors.textLo)),
        ),
        data: (state) => ListView(
          padding: EdgeInsets.fromLTRB(
              16, 16 + MediaQuery.of(context).padding.top + 64, 16, 32),
          children: [
            const _SectionHeader(number: 1, title: 'Select a monitor'),
            const SizedBox(height: 12),
            MonitorCard(
              monitors: state.monitors,
              rawDisplays: state.rawDisplays,
              selected: state.selected,
              onSelect: ctrl.selectMonitor,
            ),
            const SizedBox(height: 24),
            const _SectionHeader(number: 2, title: 'Options'),
            const SizedBox(height: 12),
            AudioOptionsCard(
              systemAudioEnabled: state.settings.captureSystemAudio,
              micEnabled: state.settings.captureMic,
              onSystemAudioChanged: ctrl.setCaptureSystemAudio,
              onMicChanged: ctrl.setCaptureMic,
            ),
            const SizedBox(height: 16),
            OutputResolutionCard(
              value: state.settings.outputResolution,
              onChanged: ctrl.setOutputResolution,
            ),
            const SizedBox(height: 16),
            StorageOptionsCard(
              saveDirectory: state.settings.saveDirectory,
              deleteTempOnExit: state.settings.deleteTempOnExit,
              onSaveDirectoryChanged: ctrl.setSaveDirectory,
              onDeleteTempOnExitChanged: ctrl.setDeleteTempOnExit,
            ),
            const SizedBox(height: 16),
            HotkeyRecorderField(
              label: 'Start',
              hotkey: state.settings.hotkeys.start,
              onSave: (k) => ctrl.setHotkey(HotkeySlot.start, k),
            ),
            const SizedBox(height: 8),
            HotkeyRecorderField(
              label: 'Pause / Resume',
              hotkey: state.settings.hotkeys.pauseResume,
              onSave: (k) => ctrl.setHotkey(HotkeySlot.pauseResume, k),
            ),
            const SizedBox(height: 8),
            HotkeyRecorderField(
              label: 'Stop',
              hotkey: state.settings.hotkeys.stop,
              onSave: (k) => ctrl.setHotkey(HotkeySlot.stop, k),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(number: 3, title: 'Record'),
            const SizedBox(height: 12),
            if (state.status == RecordStatus.idle) ...[
              _RecordButton(
                enabled: state.selected != null,
                onTap: ctrl.startRecording,
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Max 10:00',
                    style: TextStyle(color: AppColors.textLo, fontSize: 12)),
              ),
            ] else
              _RecordingControlsCard(
                paused: state.status == RecordStatus.paused,
                elapsed: state.elapsed,
                onPauseResume: ctrl.togglePauseResume,
                onStop: ctrl.stopRecording,
              ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: state.error!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.number, required this.title});
  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
              gradient: AppGradients.primaryButton, shape: BoxShape.circle),
          child: Center(
            child: Text('$number',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: AppColors.textHi,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? AppGradients.primaryButton : null,
          color: enabled ? null : AppColors.glassTint,
          borderRadius: BorderRadius.circular(16),
          border:
              enabled ? null : Border.all(color: AppColors.glassStroke),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fiber_manual_record_rounded,
                  color: enabled ? Colors.white : AppColors.textLo, size: 20),
              const SizedBox(width: 8),
              Text('Record',
                  style: TextStyle(
                      color: enabled ? Colors.white : AppColors.textLo,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// Mouse-clickable pause/resume + stop — the global hotkeys are the
// hands-off path, not the only path. Without this, a failed/undiscoverable
// hotkey left a recording with no way to stop it from the UI at all.
class _RecordingControlsCard extends StatelessWidget {
  const _RecordingControlsCard({
    required this.paused,
    required this.elapsed,
    required this.onPauseResume,
    required this.onStop,
  });

  final bool paused;
  final Duration elapsed;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 16,
      tint: paused ? Colors.amber : AppColors.accentC,
      opacity: 0.1,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fiber_manual_record_rounded,
                  color: paused ? Colors.amber : Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              Text(paused ? 'Paused' : 'Recording',
                  style: const TextStyle(
                      color: AppColors.textHi,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(width: 10),
              Text('${_fmt(elapsed)} / 10:00',
                  style: const TextStyle(color: AppColors.textLo, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPauseResume,
                  icon: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 18),
                  label: Text(paused ? 'Resume' : 'Pause'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textHi,
                    side: const BorderSide(color: AppColors.glassStroke),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded, size: 18, color: Colors.white),
                  label: const Text('Stop', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
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
