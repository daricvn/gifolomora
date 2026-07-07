import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';

/// Shows one bundled license/notice text file from assets/licenses/.
/// Pushed directly via Navigator (not a named go_router route) -- it's a
/// simple detail screen, not something that needs to be deep-linkable.
class LicenseViewerScreen extends StatelessWidget {
  const LicenseViewerScreen({super.key, required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 64 + 24;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: title,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              iconSize: 20,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHi),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentA),
            );
          }
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, topPad, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SelectableText(
                  snapshot.data!,
                  style: const TextStyle(
                    color: AppColors.textLo,
                    fontSize: 12.5,
                    height: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
