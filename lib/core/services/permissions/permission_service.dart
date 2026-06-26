import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Requests storage/photo permissions needed to read user media.
  /// Returns true if granted (or not required on this platform/API level).
  Future<bool> requestMediaRead() async {
    if (!Platform.isAndroid) return true;

    // API 33+: READ_MEDIA_IMAGES
    // API 26–32: READ_EXTERNAL_STORAGE (scoped)
    // API <26: READ_EXTERNAL_STORAGE
    final status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return true;

    // Fall back to storage permission for older API levels
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;

    final result = await [Permission.photos, Permission.storage].request();
    return result[Permission.photos]?.isGranted == true ||
        result[Permission.storage]?.isGranted == true;
  }

  Future<bool> openSettings() => openAppSettings();
}
