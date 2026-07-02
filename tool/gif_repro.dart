// One-off repro runner: optimize an arbitrary input GIF at app-default knobs.
// Usage: dart run tool/gif_repro.dart <in.gif> <out.gif> [colors] [lossy] [frameDrop]
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:gifolomora/core/services/gif_optimizer.dart';

Future<void> main(List<String> args) async {
  final input = File(args[0]);
  final output = File(args[1]);
  final colors = args.length > 2 ? int.parse(args[2]) : 128;
  final lossy = args.length > 3 ? int.parse(args[3]) : 40;
  final frameDrop = args.length > 4 ? int.parse(args[4]) : 0;

  // What does package:image hand the optimizer? Transparent pixels leaking
  // out of its compositing become transparent holes in our output.
  final decoded = img.decodeGif(input.readAsBytesSync())!;
  for (var f = 0; f < decoded.frames.length; f++) {
    final frame = decoded.frames[f];
    var alpha0 = 0;
    for (final px in frame) {
      if (px.a.toInt() == 0) alpha0++;
    }
    if (alpha0 > 0 || f == 0) {
      print('in f$f: dur=${frame.frameDuration}ms alpha0=$alpha0/'
          '${frame.width * frame.height}');
    }
  }

  await GifOptimizer.optimize(input, output,
      colors: colors, lossy: lossy, frameDrop: frameDrop);
  print('${input.lengthSync()} -> ${output.lengthSync()} bytes');
}
