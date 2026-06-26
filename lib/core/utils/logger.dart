import 'package:flutter/foundation.dart';

abstract final class Log {
  static void d(String tag, String msg) {
    if (kDebugMode) debugPrint('[$tag] $msg');
  }

  static void e(String tag, String msg, [Object? error, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[$tag] ERROR: $msg');
      if (error != null) debugPrint('  $error');
      if (stack != null) debugPrint('  $stack');
    }
  }
}
