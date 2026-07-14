import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/services/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common/gradient_scaffold.dart';
import '../../../core/widgets/glass/glass_app_bar.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../../l10n/app_localizations.dart';

/// Autonym (each language's name in itself — conventionally shown as-is,
/// never translated through the active locale) plus flag, per locale code.
const _kLanguages = {
  'en': ('English', '🇬🇧'),
  'vi': ('Tiếng Việt', '🇻🇳'),
  'de': ('Deutsch', '🇩🇪'),
  'fr': ('Français', '🇫🇷'),
  'ja': ('日本語', '🇯🇵'),
  'zh': ('中文', '🇨🇳'),
};

/// App-wide preferences, grouped into labelled sections of icon-led rows.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top + 64 + 24;
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final l10n = AppLocalizations.of(context)!;
    final ctrl = ref.read(appSettingsProvider.notifier);

    return GradientScaffold(
      appBar: GlassAppBar(
        title: l10n.settingsScreenTitle,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              iconSize: 20,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textHi,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(l10n.settingsSectionGeneral),
                  GlassContainer(
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.translate_rounded,
                          iconColor: AppColors.accentB,
                          title: l10n.settingsLanguageTitle,
                          subtitle: l10n.settingsLanguageDesc,
                          trailing: _LanguageDropdown(
                            value: settings?.localeCode,
                            systemDefaultLabel:
                                l10n.settingsLanguageSystemDefault,
                            onChanged:
                                settings == null ? null : ctrl.setLocale,
                          ),
                        ),
                        if (Platform.isWindows) ...[
                          const Divider(
                              color: AppColors.glassStroke, height: 1),
                          _SettingsTile(
                            icon: Icons.videocam_rounded,
                            iconColor: AppColors.accentA,
                            title: l10n.settingsSoftwarePreviewTitle,
                            subtitle: l10n.settingsSoftwarePreviewDesc,
                            trailing: Switch(
                              value: settings?.softwareVideoPreview ?? false,
                              activeThumbColor: AppColors.accentB,
                              // Disabled (null) until prefs load so a tap
                              // can't race the initial value.
                              onChanged: settings == null
                                  ? null
                                  : (v) => ctrl.setSoftwareVideoPreview(v),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(l10n.aboutTooltip),
                  GlassContainer(
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.accentC,
                      title: 'Gifolomora',
                      subtitle: l10n.settingsAboutDesc,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _VersionBadge(),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textLo,
                            size: 22,
                          ),
                        ],
                      ),
                      onTap: () => context.push('/about'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small uppercase-style label above each settings card.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textLo,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// One settings row: tinted icon chip, title + description, trailing control.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textHi,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textLo,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: row,
    );
  }
}

/// Current app version, e.g. "v1.0.2". Empty until package info resolves.
class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final version = snap.data?.version;
        if (version == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.glassTint,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.glassStroke),
          ),
          child: Text(
            l10n.homeVersionBadge(version),
            style: const TextStyle(
              color: AppColors.textLo,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown(
      {required this.value,
      required this.systemDefaultLabel,
      required this.onChanged});

  /// Null = system default.
  final String? value;
  final String systemDefaultLabel;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.glassTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          isDense: true,
          padding: const EdgeInsets.symmetric(vertical: 10),
          dropdownColor: AppColors.bg1,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(Icons.expand_more_rounded,
              color: AppColors.textLo, size: 20),
          style: const TextStyle(
            color: AppColors.textHi,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: _LanguageRow(flag: '🌐', label: systemDefaultLabel),
            ),
            for (final locale in AppLocalizations.supportedLocales)
              DropdownMenuItem<String?>(
                value: locale.languageCode,
                child: _LanguageRow(
                  flag: _kLanguages[locale.languageCode]?.$2 ?? '🏳️',
                  label:
                      _kLanguages[locale.languageCode]?.$1 ?? locale.languageCode,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.flag, required this.label});
  final String flag;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(flag, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
