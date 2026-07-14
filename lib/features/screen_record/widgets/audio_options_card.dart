import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/services/record/native_window_channel.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../../l10n/app_localizations.dart';

/// Two glass switches — System audio / Microphone. Values persist via the
/// controller immediately on toggle; device-name subtitles are fetched once
/// (display-only — the actual dshow capture device is resolved separately at
/// record-start time).
class AudioOptionsCard extends StatefulWidget {
  const AudioOptionsCard({
    super.key,
    required this.systemAudioEnabled,
    required this.micEnabled,
    required this.onSystemAudioChanged,
    required this.onMicChanged,
  });

  final bool systemAudioEnabled;
  final bool micEnabled;
  final ValueChanged<bool> onSystemAudioChanged;
  final ValueChanged<bool> onMicChanged;

  @override
  State<AudioOptionsCard> createState() => _AudioOptionsCardState();
}

class _AudioOptionsCardState extends State<AudioOptionsCard> {
  String? _micName;
  String? _speakerName;
  bool _noMicDevice = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceNames();
  }

  Future<void> _loadDeviceNames() async {
    if (!Platform.isWindows) return;
    final channel = NativeWindowChannel();
    final mic = await channel.getDefaultDeviceName('input');
    final speaker = await channel.getDefaultDeviceName('output');
    if (!mounted) return;
    setState(() {
      _micName = mic.isEmpty ? null : mic;
      _speakerName = speaker.isEmpty ? null : speaker;
      _noMicDevice = mic.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.recordAudio,
              style: const TextStyle(
                  color: AppColors.textHi,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 12),
          _AudioSwitchRow(
            icon: Icons.speaker_rounded,
            title: l10n.recordSystemAudio,
            subtitle: _speakerName ?? l10n.recordDefaultOutputDevice,
            value: widget.systemAudioEnabled,
            onChanged: widget.onSystemAudioChanged,
          ),
          const SizedBox(height: 10),
          Divider(color: AppColors.glassStroke.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 10),
          _AudioSwitchRow(
            icon: Icons.mic_rounded,
            title: l10n.recordMicrophone,
            subtitle: _noMicDevice
                ? l10n.recordNoMicFound
                : (_micName ?? l10n.recordDefaultInputDevice),
            value: widget.micEnabled && !_noMicDevice,
            onChanged: _noMicDevice ? null : widget.onMicChanged,
          ),
        ],
      ),
    );
  }
}

class _AudioSwitchRow extends StatelessWidget {
  const _AudioSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Row(
      children: [
        Icon(icon,
            color: enabled ? AppColors.accentB : AppColors.textLo, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: enabled ? AppColors.textHi : AppColors.textLo,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textLo, fontSize: 11)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.accentB),
      ],
    );
  }
}
