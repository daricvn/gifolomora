import 'dart:io';
import 'package:file_picker/file_picker.dart';

class ExportService {
  /// Prompts the user to pick a save location, then copies [tempFile] there.
  /// Returns the saved [File] or null if cancelled.
  Future<File?> saveGif(File tempFile, {String defaultName = 'animated.gif'}) async {
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
  }
}
