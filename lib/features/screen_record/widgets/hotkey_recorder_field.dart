import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common/app_toast.dart';
import '../../../core/widgets/glass/glass_container.dart';

/// `HotKeyVirtualView` from `hotkey_manager` hardcodes macOS glyphs
/// (⌃ ⇧ ⌥ ⊞) for modifier keys on every platform. This feature is
/// Windows-only, so render the labels Windows users actually expect.
const Map<HotKeyModifier, String> _windowsModifierLabels = {
  HotKeyModifier.control: 'Ctrl',
  HotKeyModifier.shift: 'Shift',
  HotKeyModifier.alt: 'Alt',
  HotKeyModifier.meta: 'Win',
  HotKeyModifier.capsLock: 'Caps',
  HotKeyModifier.fn: 'Fn',
};

class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        border: Border.all(color: AppColors.glassStroke),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(color: AppColors.textHi, fontSize: 12)),
    );
  }
}

class _WindowsHotKeyView extends StatelessWidget {
  const _WindowsHotKeyView({required this.hotKey});

  final HotKey hotKey;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (final modifier in hotKey.modifiers ?? <HotKeyModifier>[])
          _KeyChip(label: _windowsModifierLabels[modifier] ?? modifier.name),
        _KeyChip(label: hotKey.physicalKey.debugName ?? 'Unknown'),
      ],
    );
  }
}

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
    required this.onEditStart,
    required this.onEditEnd,
  });

  final String label;
  final HotKey hotkey;
  final Future<bool> Function(HotKey) onSave;

  /// Suspend/resume the OS-global hotkeys around the dialog below — the
  /// low-level keyboard hook fires regardless of focus, so leaving the
  /// current combo live while the user presses it to reassign would both
  /// trigger its action (e.g. start a recording) and get captured as the new
  /// binding at the same time.
  final Future<void> Function() onEditStart;
  final Future<void> Function() onEditEnd;

  Future<void> _openRecorder(BuildContext context) async {
    await onEditStart();
    // Widget unmounted while hotkeys were suspending (e.g. dialog host
    // popped) — still resume hotkeys, just skip opening a dialog with a
    // dead context.
    if (!context.mounted) {
      await onEditEnd();
      return;
    }
    HotKey? recorded;
    try {
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
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                width: 220,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WindowsHotKeyView(hotKey: recorded ?? hotkey),
                    const SizedBox(height: 12),
                    // `HotKeyRecorder`'s own visual (via `HotKeyVirtualView`)
                    // renders raw OS key labels, not our Windows-style
                    // Ctrl/Alt/Shift labels — mismatched vs the row above and
                    // the list. Keep it offstage purely for keyboard capture;
                    // show our own consistent labels instead.
                    Offstage(
                      child: HotKeyRecorder(
                        initalHotKey: hotkey,
                        onHotKeyRecorded: (k) {
                          recorded = k;
                          setDialogState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
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
    } finally {
      await onEditEnd();
    }
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
          _WindowsHotKeyView(hotKey: hotkey),
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
