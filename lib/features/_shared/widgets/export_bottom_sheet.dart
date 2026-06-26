import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/glass/glass_container.dart';

/// Shows an export bottom sheet and calls [onExport] when user confirms.
/// Shows progress overlay while exporting.
class ExportBottomSheet extends StatefulWidget {
  const ExportBottomSheet({
    super.key,
    required this.onExport,
    this.estimatedFrames,
  });

  final Future<void> Function() onExport;
  final int? estimatedFrames;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function() onExport,
    int? estimatedFrames,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ExportBottomSheet(
        onExport: onExport,
        estimatedFrames: estimatedFrames,
      ),
    );
  }

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  bool _exporting = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      await widget.onExport();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassStroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Export GIF',
                style: TextStyle(
                  color: AppColors.textHi,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You\'ll be asked to choose where to save the file.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLo, fontSize: 14),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              _exporting
                  ? const Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.accentB),
                        SizedBox(height: 12),
                        Text(
                          'Processing…',
                          style: TextStyle(color: AppColors.textLo, fontSize: 13),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppGradients.primaryButton,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton(
                          onPressed: _start,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Export & Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textLo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
