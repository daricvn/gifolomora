import 'dart:io';
import '../../features/text_overlay/model/text_item.dart';

abstract final class FontResolver {
  static const _windowsCandidates = [
    r'C:\Windows\Fonts\arial.ttf',
    r'C:\Windows\Fonts\calibri.ttf',
    r'C:\Windows\Fonts\tahoma.ttf',
    r'C:\Windows\Fonts\segoeui.ttf',
  ];

  static const _windowsBoldCandidates = [
    r'C:\Windows\Fonts\arialbd.ttf',
    r'C:\Windows\Fonts\calibrib.ttf',
    r'C:\Windows\Fonts\tahomabd.ttf',
  ];

  static const _windowsItalicCandidates = [
    r'C:\Windows\Fonts\ariali.ttf',
    r'C:\Windows\Fonts\calibrii.ttf',
  ];

  static const _windowsBoldItalicCandidates = [
    r'C:\Windows\Fonts\arialbi.ttf',
    r'C:\Windows\Fonts\calibriz.ttf',
  ];

  static const _androidCandidates = [
    '/system/fonts/Roboto-Regular.ttf',
    '/system/fonts/NotoSans-Regular.ttf',
    '/system/fonts/DroidSans.ttf',
  ];

  static const _androidBoldCandidates = [
    '/system/fonts/Roboto-Bold.ttf',
    '/system/fonts/NotoSans-Bold.ttf',
  ];

  static const _androidItalicCandidates = [
    '/system/fonts/Roboto-Italic.ttf',
    '/system/fonts/NotoSans-Italic.ttf',
  ];

  static const _androidBoldItalicCandidates = [
    '/system/fonts/Roboto-BoldItalic.ttf',
  ];

  static const _linuxCandidates = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/freefont/FreeSans.ttf',
    '/usr/share/fonts/TTF/DejaVuSans.ttf',
  ];

  static const _linuxBoldCandidates = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf',
  ];

  static const _linuxItalicCandidates = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf',
    '/usr/share/fonts/TTF/DejaVuSans-Oblique.ttf',
  ];

  static const _linuxBoldItalicCandidates = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-BoldOblique.ttf',
    '/usr/share/fonts/TTF/DejaVuSans-BoldOblique.ttf',
  ];

  static String? resolve() => _findFirst(
        Platform.isWindows
            ? _windowsCandidates
            : Platform.isAndroid
                ? _androidCandidates
                : _linuxCandidates,
      );

  // ponytail: uses system fonts; swap to rootBundle copy when assets/fonts/ is populated
  static String? fileForStyle(TextStyleKind style) {
    if (style == TextStyleKind.regular) return resolve();
    final List<String> styleCandidates;
    if (Platform.isWindows) {
      styleCandidates = switch (style) {
        TextStyleKind.bold       => _windowsBoldCandidates,
        TextStyleKind.italic     => _windowsItalicCandidates,
        TextStyleKind.boldItalic => _windowsBoldItalicCandidates,
        TextStyleKind.regular    => _windowsCandidates,
      };
    } else if (Platform.isAndroid) {
      styleCandidates = switch (style) {
        TextStyleKind.bold       => _androidBoldCandidates,
        TextStyleKind.italic     => _androidItalicCandidates,
        TextStyleKind.boldItalic => _androidBoldItalicCandidates,
        TextStyleKind.regular    => _androidCandidates,
      };
    } else {
      styleCandidates = switch (style) {
        TextStyleKind.bold       => _linuxBoldCandidates,
        TextStyleKind.italic     => _linuxItalicCandidates,
        TextStyleKind.boldItalic => _linuxBoldItalicCandidates,
        TextStyleKind.regular    => _linuxCandidates,
      };
    }
    return _findFirst(styleCandidates) ?? resolve();
  }

  static String? _findFirst(List<String> paths) {
    for (final path in paths) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }
}
