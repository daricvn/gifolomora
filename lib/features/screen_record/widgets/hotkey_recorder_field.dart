import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common/app_toast.dart';
import '../../../core/widgets/glass/glass_container.dart';

/// One row of the hotkey strip: a read-only chip (via the package's
/// [HotKeyVirtualView]) plus an edit affordance that opens a small recorder
/// dialog ("press keys to assign"). [onSave] returns false on conflict with
/// one of the other two hotkeys or OS registration failure (combo already
/// taken by another app) — surfaced as an [AppToast].
class HotkeyRecorderField extends StatelessWidget {
  const HotkeyRecorderField({
    super.key,
    required this.label,
    required this.hotkey,
    required this.onSave,
  });

  final String label;
  final HotKey hotkey;
  final Future<bool> Function(HotKey) onSave;

  Future<void> _openRecorder(BuildContext context) async {
    HotKey? recorded;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassStroke),
        ),
        title: Text('Press keys for "$label"',
            style: const TextStyle(color: AppColors.textHi, fontSize: 15)),
        content: SizedBox(
          width: 220,
          child: HotKeyRecorder(
            initalHotKey: hotkey,
            onHotKeyRecorded: (k) => recorded = k,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textLo)),
          ),
          TextButton(
            onPressed: () async {
              final k = recorded;
              Navigator.of(dialogContext).pop();
              if (k == null) return;
              final ok = await onSave(k);
              if (!ok && context.mounted) {
                AppToast.error(context,
                    'That combo conflicts with another Screen Record hotkey, or is already taken by another app.');
              }
            },
            child: const Text('Save',
                style: TextStyle(color: AppColors.accentB)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textHi,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          HotKeyVirtualView(hotKey: hotkey),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_rounded,
                size: 16, color: AppColors.textLo),
            onPressed: () => _openRecorder(context),
            tooltip: 'Edit hotkey',
          ),
        ],
      ),
    );
  }
}
