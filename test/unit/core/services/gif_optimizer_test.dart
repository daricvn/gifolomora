import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:gifolomora/core/services/gif_optimizer.dart';

/// Builds an animated GIF: 3 frames, [size]×[size], a solid background with a
/// moving square. Returns the encoded bytes.
Uint8List _buildSourceGif(int size) {
  final encoder = img.GifEncoder(repeat: 0);
  for (var f = 0; f < 3; f++) {
    final frame = img.Image(width: size, height: size, numChannels: 3);
    img.fill(frame, color: img.ColorRgb8(200, 30, 30)); // red background
    // A 16×16 colored square that moves each frame.
    final sq = img.ColorRgb8(f == 0 ? 30 : 30, f == 1 ? 200 : 30, f == 2 ? 200 : 30);
    img.fillRect(frame,
        x1: f * 8, y1: f * 8, x2: f * 8 + 15, y2: f * 8 + 15, color: sq);
    encoder.addFrame(frame, duration: 10);
  }
  return encoder.finish()!;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('gifopt_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<img.Image?> optimizeAndDecode(
    Uint8List srcBytes, {
    int colors = 64,
    int lossy = 0,
  }) async {
    final input = File('${tmp.path}/in.gif')..writeAsBytesSync(srcBytes);
    final output = File('${tmp.path}/out.gif');
    await GifOptimizer.optimize(input, output, colors: colors, lossy: lossy);
    expect(output.existsSync(), isTrue, reason: 'output file not written');
    return img.decodeGif(output.readAsBytesSync());
  }

  group('GifOptimizer', () {
    test('produces a valid GIF that re-decodes', () async {
      final src = _buildSourceGif(64);
      final decoded = await optimizeAndDecode(src);
      expect(decoded, isNotNull, reason: 'optimized GIF failed to decode');
    });

    test('preserves dimensions and frame count', () async {
      final src = _buildSourceGif(64);
      final decoded = await optimizeAndDecode(src);
      expect(decoded!.width, 64);
      expect(decoded.height, 64);
      expect(decoded.numFrames, 3);
    });

    test('inter-frame diff keeps colors recognizable (lossless)', () async {
      final src = _buildSourceGif(64);
      final decoded = await optimizeAndDecode(src, colors: 64, lossy: 0);
      // Background pixel (far corner, never covered by a square) stays reddish.
      final f0 = decoded!.frames[0];
      final bg = f0.getPixel(63, 63);
      expect(bg.r, greaterThan(bg.g));
      expect(bg.r, greaterThan(bg.b));
      // Moving square on frame 1 is green-ish at its location.
      final f1 = decoded.frames[1];
      final sq = f1.getPixel(8 + 4, 8 + 4);
      expect(sq.g, greaterThan(sq.r));
    });

    test('lossy compression is not larger than lossless', () async {
      final src = _buildSourceGif(96);
      final input = File('${tmp.path}/in2.gif')..writeAsBytesSync(src);
      final lossless = File('${tmp.path}/lossless.gif');
      final lossy = File('${tmp.path}/lossy.gif');
      await GifOptimizer.optimize(input, lossless, colors: 64, lossy: 0);
      await GifOptimizer.optimize(input, lossy, colors: 64, lossy: 40);
      expect(lossy.lengthSync(), lessThanOrEqualTo(lossless.lengthSync()));
    });

    test('frameDrop removes 1 of every N frames and preserves total time',
        () async {
      // 4 frames @ 10cs each = 40cs total. Drop 1 of every 2 → 2 kept frames,
      // each absorbing a dropped frame's duration → still 40cs total.
      final encoder = img.GifEncoder(repeat: 0);
      for (var f = 0; f < 4; f++) {
        final frame = img.Image(width: 32, height: 32, numChannels: 3);
        img.fill(frame, color: img.ColorRgb8(10 + f * 40, 30, 30));
        encoder.addFrame(frame, duration: 10); // centiseconds
      }
      final src = encoder.finish()!;
      final input = File('${tmp.path}/drop_in.gif')..writeAsBytesSync(src);
      final output = File('${tmp.path}/drop_out.gif');
      await GifOptimizer.optimize(input, output, colors: 64, frameDrop: 2);
      final decoded = img.decodeGif(output.readAsBytesSync());
      expect(decoded!.numFrames, 2, reason: 'should drop frames 1 and 3');
      final totalMs = decoded.frames
          .fold<int>(0, (sum, fr) => sum + fr.frameDuration);
      expect(totalMs, 400, reason: 'total playback time must be preserved (ms)');
    });

    test('rejects invalid GIF data', () async {
      final input = File('${tmp.path}/bad.gif')
        ..writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));
      final output = File('${tmp.path}/bad_out.gif');
      expect(
        () => GifOptimizer.optimize(input, output),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
