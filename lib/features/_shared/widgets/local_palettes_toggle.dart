import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class LocalPalettesToggle extends StatelessWidget {
  const LocalPalettesToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Per-frame palettes',
                  style: TextStyle(
                      color: AppColors.textHi,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 2),
              Text('Lossless extra compression, slower',
                  style: TextStyle(color: AppColors.textLo, fontSize: 12)),
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
