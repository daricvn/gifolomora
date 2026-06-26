import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Premium section divider: a small uppercase overline above a bold title,
/// optionally with a trailing action. Gives the home screen visual rhythm
/// and clear hierarchy between tool groups.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.overline,
    required this.title,
    this.trailing,
  });

  final String overline;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overline.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textLo,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textHi,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
