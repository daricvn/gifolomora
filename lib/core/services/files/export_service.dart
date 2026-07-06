import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class ExportService {
  bool _saving = false;

  Future<File?> saveGif(File tempFile, {String defaultName = 'animated.gif'}) async {
    if (_saving) return null;
    _saving = true;
    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save GIF',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['gif'],
      );
      if (savePath == null) return null;
      final dest = File(savePath);
      await tempFile.copy(dest.path);
      return dest;
    } finally {
      _saving = false;
    }
  }

  Future<File?> saveVideo(File tempFile, {String defaultName = 'edited.mp4'}) async {
    if (_saving) return null;
    _saving = true;
    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Video',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['mp4'],
      );
      if (savePath == null) return null;
      final dest = File(savePath);
      await tempFile.copy(dest.path);
      return dest;
    } finally {
      _saving = false;
    }
  }

  Future<File?> saveWebm(File tempFile, {String defaultName = 'converted.webm'}) async {
    if (_saving) return null;
    _saving = true;
    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save WebM',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['webm'],
      );
      if (savePath == null) return null;
      final dest = File(savePath);
      await tempFile.copy(dest.path);
      return dest;
    } finally {
      _saving = false;
    }
  }

  /// Batch export: one directory picker, then every entry (temp file → desired
  /// base name, no extension) is copied in as `<name>.webm`, suffixing
  /// ` (1)`, ` (2)`… on collision. Twenty sequential saveFile dialogs is not a
  /// UX. Returns the chosen directory, or null if cancelled/already saving.
  Future<Directory?> saveWebmBatch(
      List<MapEntry<File, String>> items) async {
    if (_saving) return null;
    _saving = true;
    try {
      final dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose export folder',
      );
      if (dirPath == null) return null;
      final used = <String>{};
      for (final entry in items) {
        var name = '${entry.value}.webm';
        var counter = 1;
        while (used.contains(name) || File(p.join(dirPath, name)).existsSync()) {
          name = '${entry.value} ($counter).webm';
          counter++;
        }
        used.add(name);
        await entry.key.copy(p.join(dirPath, name));
      }
      return Directory(dirPath);
    } finally {
      _saving = false;
    }
  }
}
