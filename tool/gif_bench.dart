// Benchmark harness for GifOptimizer tuning. Generates a synthetic corpus
// covering the content classes that stress a GIF optimizer differently
// (smooth gradients, flat cartoon, static noise, single frame, duplicate
// frames), runs the optimizer at several lossy levels, and prints sizes.
//
// Usage: dart run tool/gif_bench.dart [outDir]
// Quality validation lives in tool/gif_quality.py (Pillow-based — the image
// package's own decoder is too lenient to trust; see gif_optimizer.dart).
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:gifolomora/core/services/gif_optimizer.dart';

Future<void> main(List<String> args) async {
  final outDir = Directory(args.isNotEmpty ? args[0] : 'bench_out')
    ..createSync(recursive: true);

  final sources = <String, Uint8List>{
    'plasma': _plasma(),
    'cartoon': _cartoon(),
    'noisy': _noisy(),
    'static': _static(),
    'dupframes': _dupFrames(),
  };

  for (final e in sources.entries) {
    final src = File('${outDir.path}/${e.key}_src.gif')
      ..writeAsBytesSync(e.value);
    for (final lossy in [0, 40, 80]) {
      for (final lct in [false, true]) {
        final suffix = lct ? '_lct' : '';
        final out = File('${outDir.path}/${e.key}_l$lossy$suffix.gif');
        final sw = Stopwatch()..start();
        await GifOptimizer.optimize(src, out,
            colors: 128, lossy: lossy, localPalettes: lct);
        sw.stop();
        final srcLen = e.value.length;
        final outLen = out.lengthSync();
        final pct = (100 * (srcLen - outLen) / srcLen).toStringAsFixed(1);
        print('${e.key.padRight(10)} lossy=${lossy.toString().padLeft(3)}'
            '${lct ? ' +lct' : '     '}: '
            '$srcLen -> $outLen bytes (-$pct%)  ${sw.elapsedMilliseconds}ms');
      }
    }
  }
}

/// Smooth animated sinusoid gradients — photographic-ish, many colors.
Uint8List _plasma() {
  final enc = img.GifEncoder(repeat: 0);
  for (var t = 0; t < 12; t++) {
    final f = img.Image(width: 200, height: 200, numChannels: 3);
    for (var y = 0; y < 200; y++) {
      for (var x = 0; x < 200; x++) {
        final r = 127 + 127 * sin(x / 17 + t * 0.5);
        final g = 127 + 127 * sin(y / 13 + t * 0.65);
        final b = 127 + 127 * sin((x + y) / 23 + t * 0.35);
        f.setPixelRgb(x, y, r.round(), g.round(), b.round());
      }
    }
    enc.addFrame(f, duration: 8);
  }
  return enc.finish()!;
}

/// Flat colors, moving shapes, static border — classic sticker/cartoon GIF.
Uint8List _cartoon() {
  final enc = img.GifEncoder(repeat: 0);
  for (var t = 0; t < 16; t++) {
    final f = img.Image(width: 240, height: 240, numChannels: 3);
    img.fill(f, color: img.ColorRgb8(245, 240, 230));
    img.drawRect(f,
        x1: 4, y1: 4, x2: 235, y2: 235, color: img.ColorRgb8(40, 40, 60), thickness: 4);
    img.fillCircle(f,
        x: 40 + t * 10, y: 60, radius: 22, color: img.ColorRgb8(220, 60, 50));
    img.fillCircle(f,
        x: 200 - t * 9, y: 140, radius: 16, color: img.ColorRgb8(60, 160, 220));
    img.fillRect(f,
        x1: 30 + t * 6, y1: 190, x2: 60 + t * 6, y2: 214,
        color: img.ColorRgb8(90, 190, 90));
    enc.addFrame(f, duration: 6);
  }
  return enc.finish()!;
}

/// Static per-pixel noise background + moving sprite — worst case for LZW,
/// best case for inter-frame diffing.
Uint8List _noisy() {
  final rnd = Random(42);
  final w = 160, h = 160;
  final bg = Uint8List(w * h * 3);
  for (var i = 0; i < bg.length; i++) {
    bg[i] = 100 + rnd.nextInt(80);
  }
  final enc = img.GifEncoder(repeat: 0);
  for (var t = 0; t < 10; t++) {
    final f = img.Image(width: w, height: h, numChannels: 3);
    final px = f.toUint8List()..setAll(0, bg);
    // ignore: unused_local_variable
    final _ = px;
    img.fillCircle(f,
        x: 30 + t * 11, y: 80, radius: 14, color: img.ColorRgb8(255, 220, 40));
    enc.addFrame(f, duration: 8);
  }
  return enc.finish()!;
}

/// Single-frame gradient — exercises the static path (no diffing possible).
Uint8List _static() {
  final f = img.Image(width: 256, height: 256, numChannels: 3);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      f.setPixelRgb(x, y, x, y, (x + y) ~/ 2);
    }
  }
  final enc = img.GifEncoder()..addFrame(f, duration: 10);
  return enc.finish()!;
}

/// Only every 3rd frame changes — exercises no-change frame handling.
Uint8List _dupFrames() {
  final enc = img.GifEncoder(repeat: 0);
  for (var t = 0; t < 9; t++) {
    final f = img.Image(width: 120, height: 120, numChannels: 3);
    img.fill(f, color: img.ColorRgb8(30, 120, 180));
    final step = t ~/ 3; // frame content only changes every 3rd frame
    img.fillRect(f,
        x1: 20 + step * 25, y1: 40, x2: 50 + step * 25, y2: 80,
        color: img.ColorRgb8(250, 200, 40));
    enc.addFrame(f, duration: 5);
  }
  return enc.finish()!;
}
