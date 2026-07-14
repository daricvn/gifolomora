import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/glass_container.dart';
import '../../../l10n/app_localizations.dart';

/// Where the temp job dir goes ([saveDirectory], `null` = system temp) and
/// whether it's deleted on app exit. Persisted via the controller immediately
/// on change, same pattern as [AudioOptionsCard]/[OutputResolutionCard].
class StorageOptionsCard extends StatelessWidget {
  const StorageOptionsCard({
    super.key,
    required this.saveDirectory,
    required this.deleteTempOnExit,
    required this.onSaveDirectoryChanged,
    required this.onDeleteTempOnExitChanged,
  });

  final String? saveDirectory;
  final bool deleteTempOnExit;
  final ValueChanged<String?> onSaveDirectoryChanged;
  final ValueChanged<bool> onDeleteTempOnExitChanged;

  Future<void> _pickFolder(BuildContext context) async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context)!.recordChooseFolderDialogTitle,
    );
    if (dirPath != null) onSaveDirectoryChanged(dirPath);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.recordStorage,
              style: const TextStyle(
                  color: AppColors.textHi,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.folder_rounded,
                  color: AppColors.accentB, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.recordSaveLocation,
                        style: const TextStyle(
                            color: AppColors.textHi,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Text(saveDirectory ?? l10n.recordDefaultTempFolder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textLo, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _pickFolder(context),
                child: Text(l10n.recordChoose),
              ),
              if (saveDirectory != null)
                IconButton(
                  tooltip: l10n.recordResetToDefault,
                  icon: const Icon(Icons.restart_alt_rounded,
                      color: AppColors.textLo, size: 20),
                  onPressed: () => onSaveDirectoryChanged(null),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: AppColors.glassStroke.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.delete_outline_rounded,
                  color: AppColors.accentB, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.recordDeleteTempOnExit,
                    style: const TextStyle(
                        color: AppColors.textHi,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              Switch(
                value: deleteTempOnExit,
                onChanged: onDeleteTempOnExitChanged,
                activeThumbColor: AppColors.accentB,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
