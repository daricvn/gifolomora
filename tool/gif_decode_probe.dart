// Probe what package:image's decodeGif hands us per frame.
// Usage: dart run tool/gif_decode_probe.dart <in.gif> [maxFrames]
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  final decoded = img.decodeGif(File(args[0]).readAsBytesSync())!;
  final maxFrames = args.length > 1 ? int.parse(args[1]) : 4;
  print('canvas ${decoded.width}x${decoded.height} '
      'frames=${decoded.frames.length}');
  for (var f = 0; f < decoded.frames.length && f < maxFrames; f++) {
    final fr = decoded.frames[f];
    final colors = <int, int>{};
    var alpha0 = 0;
    for (final px in fr) {
      if (px.a.toInt() == 0) alpha0++;
      final c = (px.r.toInt() << 16) | (px.g.toInt() << 8) | px.b.toInt();
      colors[c] = (colors[c] ?? 0) + 1;
    }
    final top = colors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final t = top.first;
    print('f$f: ${fr.width}x${fr.height} dur=${fr.frameDuration}ms '
        'alpha0=$alpha0 unique=${colors.length} '
        'top=#${t.key.toRadixString(16).padLeft(6, '0')} x${t.value}');
  }
}
