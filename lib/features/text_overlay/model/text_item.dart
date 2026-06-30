enum TextStyleKind { regular, bold, italic, boldItalic }

// Selectable typeface. `system` = platform default (FontResolver). The rest are
// bundled assets (assets/fonts/) materialized + registered by FontRegistry.
enum TextFont { system, dancingScript, sourceCodePro, lobsterTwo, caveat }

extension TextFontLabel on TextFont {
  String get label => switch (this) {
        TextFont.system => 'Default',
        TextFont.dancingScript => 'Dancing Script',
        TextFont.sourceCodePro => 'Source Code Pro',
        TextFont.lobsterTwo => 'Lobster Two',
        TextFont.caveat => 'Caveat',
      };
}

class TextItem {
  const TextItem({
    required this.id,
    required this.text,
    required this.nx,
    required this.ny,
    this.fontSize = 36,
    this.fontColor = 'FFFFFF',
    this.strokeColor = '000000',
    this.strokeWidth = 0,
    this.style = TextStyleKind.regular,
    this.font = TextFont.system,
  });

  final String id;
  final String text;
  final double nx; // normalized top-left x, [0,1)
  final double ny; // normalized top-left y, [0,1)
  final int fontSize; // media px, 12..96
  final String fontColor; // hex RRGGBB
  final String strokeColor; // hex RRGGBB
  final int strokeWidth; // 0..12 px
  final TextStyleKind style;
  final TextFont font;

  // scale = displayW / mediaW
  static double nxFromLocal(double localX, double scale, double mw) =>
      _clamp(localX / scale / mw);
  static double nyFromLocal(double localY, double scale, double mh) =>
      _clamp(localY / scale / mh);
  static double leftFromNx(double nx, double mw, double scale) =>
      nx * mw * scale;
  static double topFromNy(double ny, double mh, double scale) =>
      ny * mh * scale;
  static double previewFontSize(int fontSize, double scale) => fontSize * scale;
  static int pxX(double nx, double mw) => (nx * mw).round();
  static int pxY(double ny, double mh) => (ny * mh).round();

  static double _clamp(double v) => v.clamp(0.0, 0.9999);

  TextItem copyWith({
    String? text,
    double? nx,
    double? ny,
    int? fontSize,
    String? fontColor,
    String? strokeColor,
    int? strokeWidth,
    TextStyleKind? style,
    TextFont? font,
  }) =>
      TextItem(
        id: id,
        text: text ?? this.text,
        nx: nx != null ? _clamp(nx) : this.nx,
        ny: ny != null ? _clamp(ny) : this.ny,
        fontSize: fontSize ?? this.fontSize,
        fontColor: fontColor ?? this.fontColor,
        strokeColor: strokeColor ?? this.strokeColor,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        style: style ?? this.style,
        font: font ?? this.font,
      );
}
