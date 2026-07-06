import 'package:flutter/material.dart';

import '../../../core/services/record/record_settings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/glass_container.dart';

/// Output video size chips — Original / 1080p / 720p / 480p. Persisted via
/// the controller immediately on selection, same pattern as the audio
/// toggles. Downscaling is applied at capture time (`-vf scale`), so a
/// smaller pick also means less encode work, not more.
class OutputResolutionCard extends StatelessWidget {
  const OutputResolutionCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RecordOutputResolution value;
  final ValueChanged<RecordOutputResolution> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Output size',
              style: TextStyle(
                  color: AppColors.textHi,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RecordOutputResolution.values.map((r) {
              final selected = r == value;
              return ChoiceChip(
                label: Text(r.label),
                selected: selected,
                onSelected: (_) => onChanged(r),
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
      ),
    );
  }
}
