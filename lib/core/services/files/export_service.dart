import 'dart:io';
import 'package:file_picker/file_picker.dart';

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
}
