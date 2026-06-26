import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/glass_container.dart';

class FileDropZone extends StatefulWidget {
  const FileDropZone({
    super.key,
    required this.onFilesSelected,
    this.allowMultiple = false,
    this.allowedExtensions,
    this.hint = 'Tap to select files',
    this.icon = Icons.upload_file_rounded,
  });

  final void Function(List<File>) onFilesSelected;
  final bool allowMultiple;
  final List<String>? allowedExtensions;
  final String hint;
  final IconData icon;

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  bool _hovering = false;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: widget.allowMultiple,
      type: widget.allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: widget.allowedExtensions,
    );
    if (result == null || !mounted) return;
    final files = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();
    if (files.isNotEmpty) widget.onFilesSelected(files);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: _pick,
        child: AnimatedOpacity(
          opacity: _hovering ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: GlassContainer(
            blur: 12,
            opacity: _hovering ? 0.18 : 0.10,
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 48, color: AppColors.accentB),
                const SizedBox(height: 12),
                Text(
                  widget.hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textLo,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.allowedExtensions != null
                      ? widget.allowedExtensions!.map((e) => '.$e').join(', ')
                      : 'Any file',
                  style: const TextStyle(
                    color: AppColors.textLo,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
