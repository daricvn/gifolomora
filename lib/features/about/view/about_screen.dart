import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 64 + 24;

    return GradientScaffold(
      appBar: GlassAppBar(
        title: 'About',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textHi, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, 40),
        children: [
          _AppHero(),
          const SizedBox(height: 28),
          _CreditsCard(),
          const SizedBox(height: 16),
          _MadeWithCard(),
        ],
      ),
    );
  }
}

class _AppHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: AppGradients.primaryButton,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentA.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.gif_box_rounded, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 16),
        const Text(
          'Gifolomora',
          style: TextStyle(
            color: AppColors.textHi,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your local GIF studio',
          style: TextStyle(
            color: AppColors.textLo,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _CreditsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Credits',
            style: TextStyle(
              color: AppColors.textHi,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          _CreditRow(
            icon: Icons.person_rounded,
            label: 'Developer',
            value: 'Takayoshi Code',
            iconColor: AppColors.accentA,
          ),
          const Divider(color: AppColors.glassStroke, height: 24),
          _CreditRow(
            icon: Icons.auto_awesome_rounded,
            label: 'AI Co-author',
            value: 'Claude · Anthropic',
            iconColor: AppColors.accentB,
          ),
        ],
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textLo, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textHi,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MadeWithCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppGradients.primaryButton.createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: const Icon(Icons.favorite_rounded, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Built with Flutter · crafted with care',
              style: TextStyle(color: AppColors.textLo, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
