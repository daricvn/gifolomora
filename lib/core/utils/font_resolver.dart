import 'dart:io';

abstract final class FontResolver {
  static const _windowsCandidates = [
    r'C:\Windows\Fonts\arial.ttf',
    r'C:\Windows\Fonts\calibri.ttf',
    r'C:\Windows\Fonts\tahoma.ttf',
    r'C:\Windows\Fonts\segoeui.ttf',
  ];

  static const _androidCandidates = [
    '/system/fonts/Roboto-Regular.ttf',
    '/system/fonts/NotoSans-Regular.ttf',
    '/system/fonts/DroidSans.ttf',
  ];

  static const _linuxCandidates = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/freefont/FreeSans.ttf',
    '/usr/share/fonts/TTF/DejaVuSans.ttf',
  ];

  static String? resolve() {
    final candidates = Platform.isWindows
        ? _windowsCandidates
        : Platform.isAndroid
            ? _androidCandidates
            : _linuxCandidates;
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }
}
