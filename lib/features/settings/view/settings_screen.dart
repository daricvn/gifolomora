import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/settings/settings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../_shared/widgets/option_slider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSettings = ref.watch(settingsProvider);

    return GradientScaffold(
      appBar: GlassAppBar(
        title: 'Settings',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textHi, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: asyncSettings.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accentB)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.redAccent))),
        data: (settings) => _SettingsBody(settings: settings),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody({required this.settings});
  final AppSettings settings;

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late AppSettings _local;

  @override
  void initState() {
    super.initState();
    _local = widget.settings;
  }

  void _save(AppSettings updated) {
    setState(() => _local = updated);
    ref.read(settingsProvider.notifier).save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 64 + 16;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPad, 16, 40),
      children: [
        // ── GIF Creation ───────────────────────────────────────────────
        const _GroupLabel('GIF Creation'),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 20,
          child: Column(
            children: [
              OptionSlider(
                label: 'Default FPS',
                value: _local.defaultFps.toDouble(),
                min: 5,
                max: 30,
                divisions: 25,
                unit: ' fps',
                displayValue: '${_local.defaultFps}',
                onChanged: (v) =>
                    _save(_local.copyWith(defaultFps: v.round())),
              ),
              const Divider(color: AppColors.glassStroke, height: 20),
              OptionSlider(
                label: 'Default Width',
                value: _local.defaultWidth.toDouble(),
                min: 240,
                max: 1280,
                divisions: 26,
                unit: ' px',
                displayValue: '${_local.defaultWidth}',
                onChanged: (v) =>
                    _save(_local.copyWith(defaultWidth: v.round())),
              ),
            ],
          ),
        ),

        // ── Optimization ───────────────────────────────────────────────
        const SizedBox(height: 24),
        const _GroupLabel('Optimization'),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 20,
          child: Column(
            children: [
              OptionSlider(
                label: 'Default Colors',
                value: _local.defaultColors.toDouble(),
                min: 16,
                max: 256,
                divisions: 30,
                unit: '',
                displayValue: '${_local.defaultColors}',
                onChanged: (v) =>
                    _save(_local.copyWith(defaultColors: v.round())),
              ),
              const Divider(color: AppColors.glassStroke, height: 20),
              OptionSlider(
                label: 'Default Lossy',
                value: _local.defaultLossy.toDouble(),
                min: 0,
                max: 80,
                divisions: 16,
                unit: '',
                displayValue: _local.defaultLossy == 0
                    ? 'Off'
                    : '${_local.defaultLossy}',
                onChanged: (v) =>
                    _save(_local.copyWith(defaultLossy: v.round())),
              ),
            ],
          ),
        ),

        // ── History ────────────────────────────────────────────────────
        const SizedBox(height: 24),
        const _GroupLabel('History'),
        const SizedBox(height: 12),
        GlassContainer(
          borderRadius: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Recent exports',
                      style: TextStyle(
                          color: AppColors.textHi,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('Clear saved export history',
                      style: TextStyle(color: AppColors.textLo, fontSize: 12)),
                ],
              ),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(recentsProvider.notifier).clear();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('History cleared'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentC,
                  side: const BorderSide(color: AppColors.accentC),
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textLo,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
