import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class LocalPalettesToggle extends StatelessWidget {
  const LocalPalettesToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.sharedPerFramePalettes,
                  style: const TextStyle(
                      color: AppColors.textHi,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(l10n.sharedPerFramePalettesDesc,
                  style: const TextStyle(color: AppColors.textLo, fontSize: 12)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.accentB,
          activeTrackColor: AppColors.accentA.withValues(alpha: 0.4),
          inactiveTrackColor: AppColors.glassTint,
        ),
      ],
    );
  }
}
