import 'dart:io';

import 'package:flutter/services.dart' show rootBundle, FontLoader;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/text_overlay/model/text_item.dart';

/// Bundled custom typefaces. Resolves each `(font, style)` to both a Flutter
/// font-family (for the WYSIWYG preview) and an on-disk file path (for ffmpeg
/// `drawtext fontfile=`). Assets must be copied to a real FS path because
/// ffmpeg can't read from rootBundle. System font stays with [FontResolver];
/// this registry only owns the bundled fonts.
///
/// Only Regular + Bold are shipped per font: these display/script fonts have no
/// italic, so italic styles fall back to upright (boldItalic→bold). (ponytail:
/// add italic asset entries here if a future font ships one.)
abstract final class FontRegistry {
  static const Map<TextFont, Map<TextStyleKind, String>> _assets = {
    TextFont.dancingScript: {
      TextStyleKind.regular: 'assets/fonts/DancingScript-Regular.ttf',
      TextStyleKind.bold: 'assets/fonts/DancingScript-Bold.ttf',
    },
    TextFont.sourceCodePro: {
      TextStyleKind.regular: 'assets/fonts/SourceCodePro-Regular.ttf',
      TextStyleKind.bold: 'assets/fonts/SourceCodePro-Bold.ttf',
    },
    TextFont.lobsterTwo: {
      TextStyleKind.regular: 'assets/fonts/LobsterTwo-Regular.ttf',
      TextStyleKind.bold: 'assets/fonts/LobsterTwo-Bold.ttf',
    },
    TextFont.caveat: {
      TextStyleKind.regular: 'assets/fonts/Caveat-Regular.ttf',
      TextStyleKind.bold: 'assets/fonts/Caveat-Bold.ttf',
    },
  };

  static bool _loaded = false;
  static final Map<TextFont, Map<TextStyleKind, String>> _files = {};
  static final Map<TextFont, Map<TextStyleKind, String>> _families = {};

  /// Idempotent. Materializes each bundled font to the app support dir (for
  /// ffmpeg) and registers it with Flutter (for the preview). Per-asset
  /// try/catch so a missing asset or a headless test (no rootBundle / no
  /// support dir) degrades to the system font instead of failing build.
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    Directory? dir;
    try {
      dir = await getApplicationSupportDirectory();
    } catch (_) {
      dir = null;
    }
    for (final fontEntry in _assets.entries) {
      final font = fontEntry.key;
      for (final styleEntry in fontEntry.value.entries) {
        final style = styleEntry.key;
        final asset = styleEntry.value;
        try {
          final data = await rootBundle.load(asset);
          final family = 'overlay_${font.name}_${style.name}';
          final loader = FontLoader(family)..addFont(Future.value(data));
          await loader.load();
          (_families[font] ??= {})[style] = family;
          if (dir != null) {
            final file = File(p.join(dir.path, 'fonts', p.basename(asset)));
            await file.parent.create(recursive: true);
            await file.writeAsBytes(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            );
            (_files[font] ??= {})[style] = file.path;
          }
        } catch (_) {
          // preview/export falls back to the system font for this slot
        }
      }
    }
  }

  // italic→regular, boldItalic→bold (no italic faces bundled).
  static TextStyleKind _base(TextStyleKind style) => switch (style) {
        TextStyleKind.italic => TextStyleKind.regular,
        TextStyleKind.boldItalic => TextStyleKind.bold,
        _ => style,
      };

  /// ffmpeg fontfile path, or null for the system font / unloaded registry.
  static String? pathFor(TextFont font, TextStyleKind style) =>
      _files[font]?[_base(style)] ?? _files[font]?[TextStyleKind.regular];

  /// Flutter font-family for the preview, or null for the system font.
  static String? familyFor(TextFont font, TextStyleKind style) =>
      _families[font]?[_base(style)] ?? _families[font]?[TextStyleKind.regular];
}
