// Generates assets/noise.png — a 128x128 tileable grain texture overlaid on
// the background gradient to hide banding. Alpha is baked in (~3% average)
// so the widget tree needs no Opacity wrapper.
//
// Run: dart run tool/gen_noise.dart
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart';

void main() {
  const size = 128;
  final rng = Random(42);
  final img = Image(width: size, height: size, numChannels: 4);

  for (final p in img) {
    // Half the pixels lighten, half darken, both at very low alpha.
    final lighten = rng.nextBool();
    final v = lighten ? 255 : 0;
    p.setRgba(v, v, v, rng.nextInt(15));
  }

  File('assets/noise.png').writeAsBytesSync(encodePng(img));
  stdout.writeln('Wrote assets/noise.png (${size}x$size)');
}
