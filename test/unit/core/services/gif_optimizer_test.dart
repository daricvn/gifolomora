import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:gifolomora/core/services/gif/gif_lzw.dart';
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

/// Hand-assembles a sticker-class GIF: transparent background, a 2×2 opaque
/// red dot that MOVES between frames, disposal=2. package:image's GifEncoder
/// can't write transparency, so the file is built byte-by-byte (frame data via
/// GifLzw, which is round-trip tested separately).
Uint8List _buildStickerGif() {
  const size = 8;
  const transparent = 3;
  final out = BytesBuilder();
  void u16(int v) => out
    ..addByte(v & 0xff)
    ..addByte((v >> 8) & 0xff);

  out.add('GIF89a'.codeUnits);
  u16(size);
  u16(size);
  out.addByte(0x80 | 0x01); // GCT present, 4 entries
  out.addByte(0);
  out.addByte(0);
  // GCT: red, green, white, black (index 3 = transparent).
  out.add(const [220, 40, 40, 40, 200, 40, 255, 255, 255, 0, 0, 0]);
  // NETSCAPE2.0 loop forever.
  out
    ..addByte(0x21)
    ..addByte(0xFF)
    ..addByte(11)
    ..add('NETSCAPE2.0'.codeUnits)
    ..addByte(0x03)
    ..addByte(0x01);
  u16(0);
  out.addByte(0);

  for (final dotAt in [1, 5]) {
    final indices = Uint8List(size * size)
      ..fillRange(0, size * size, transparent);
    for (var y = dotAt; y < dotAt + 2; y++) {
      for (var x = dotAt; x < dotAt + 2; x++) {
        indices[y * size + x] = 0; // red
      }
    }
    out
      ..addByte(0x21)
      ..addByte(0xF9)
      ..addByte(4)
      ..addByte((2 << 2) | 0x01); // disposal=2, transparency on
    u16(10); // 10cs
    out
      ..addByte(transparent)
      ..addByte(0)
      ..addByte(0x2C);
    u16(0);
    u16(0);
    u16(size);
    u16(size);
    out.addByte(0); // no local color table
    out.add(GifLzw.encode(indices, 2));
  }
  out.addByte(0x3B);
  return out.toBytes();
}

/// GIF whose frame 1 is a 1×1 sub-rect duplicate-frame placeholder (disposal=1,
/// no local color table) — the shape pre-optimized GIFs (gifsicle/ffmpeg) use
/// for "nothing changed". package:image's decode() mis-composites this into a
/// solid index-0 flood; the optimizer must composite raw frames itself.
Uint8List _buildSubRectDupGif() {
  const size = 16;
  final out = BytesBuilder();
  void u16(int v) => out
    ..addByte(v & 0xff)
    ..addByte((v >> 8) & 0xff);

  out.add('GIF89a'.codeUnits);
  u16(size);
  u16(size);
  out.addByte(0x80 | 0x01); // GCT present, 4 entries
  out.addByte(0);
  out.addByte(0);
  // GCT: teal (index 0 — the mis-composite flood color), red, white, black.
  out.add(const [66, 137, 160, 220, 40, 40, 255, 255, 255, 0, 0, 0]);

  // Frame 0: full-canvas red/white checker.
  final full = Uint8List(size * size);
  for (var p = 0; p < full.length; p++) {
    full[p] = ((p ~/ size) + p) % 2 == 0 ? 1 : 2;
  }
  out
    ..addByte(0x21)
    ..addByte(0xF9)
    ..addByte(4)
    ..addByte(1 << 2); // disposal=1, no transparency
  u16(10);
  out
    ..addByte(0)
    ..addByte(0)
    ..addByte(0x2C);
  u16(0);
  u16(0);
  u16(size);
  u16(size);
  out.addByte(0);
  out.add(GifLzw.encode(full, 2));

  // Frame 1: 1×1 rect at the bottom-right corner repeating that pixel.
  out
    ..addByte(0x21)
    ..addByte(0xF9)
    ..addByte(4)
    ..addByte(1 << 2);
  u16(10);
  out
    ..addByte(0)
    ..addByte(0)
    ..addByte(0x2C);
  u16(size - 1);
  u16(size - 1);
  u16(1);
  u16(1);
  out.addByte(0);
  out.add(GifLzw.encode(Uint8List.fromList([full[size * size - 1]]), 2));

  out.addByte(0x3B);
  return out.toBytes();
}

/// Source designed so per-frame local color tables win: a many-color
/// background (drives the GLOBAL palette to ~8-bit codes) that is IDENTICAL
/// across frames, while the animation is a red square moving inside a flat
/// dark-blue strip — so each diffed frame region uses only red + blue
/// (+ transparent) and qualifies for a tiny local table with a small minimum
/// code size. Hand-assembled with one shared GCT: GifEncoder quantizes each
/// frame independently, which makes "identical" background pixels drift
/// between frames and would inflate the diff regions.
Uint8List _buildGradientStripGif() {
  const size = 128;
  final out = BytesBuilder();
  void u16(int v) => out
    ..addByte(v & 0xff)
    ..addByte((v >> 8) & 0xff);

  out.add('GIF89a'.codeUnits);
  u16(size);
  u16(size);
  out.addByte(0x80 | 0x06); // GCT present, 128 entries
  out.addByte(0);
  out.addByte(0);
  // 120 spread-out "gradient" colors, then blue (120), red (121), padding.
  for (var i = 0; i < 120; i++) {
    out
      ..addByte((i * 2) & 0xff)
      ..addByte(255 - i * 2)
      ..addByte((i * 37) % 256);
  }
  out.add(const [10, 10, 80]); // 120 = strip blue
  out.add(const [220, 30, 30]); // 121 = checker red
  for (var i = 122; i < 128; i++) {
    out.add(const [0, 0, 0]);
  }

  // A 32×24 red/blue checkerboard moving inside the blue strip. The checker
  // makes the diffed region code-dense, so the small-min-code-size advantage
  // clearly exceeds the local table's byte cost.
  for (var f = 0; f < 3; f++) {
    final idx = Uint8List(size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        idx[y * size + x] = (y >= 88 && y < 120) ? 120 : (x + y * 7) % 120;
      }
    }
    for (var y = 92; y < 116; y++) {
      for (var x = f * 32; x < f * 32 + 32; x++) {
        idx[y * size + x] = (x + y) % 2 == 0 ? 121 : 120;
      }
    }
    out
      ..addByte(0x21)
      ..addByte(0xF9)
      ..addByte(4)
      ..addByte(1 << 2); // disposal=1, no transparency
    u16(10);
    out
      ..addByte(0)
      ..addByte(0)
      ..addByte(0x2C);
    u16(0);
    u16(0);
    u16(size);
    u16(size);
    out.addByte(0); // no local color table
    out.add(GifLzw.encode(idx, 7));
  }
  out.addByte(0x3B);
  return out.toBytes();
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

    test('transparent-background GIF with moving dot leaves no ghost trail',
        () async {
      // Disposal=1 can never erase a drawn pixel, so the diff pipeline would
      // leave the dot's old position opaque forever (ghost trail, growing
      // every frame and across loops). The optimizer must detect the erasure
      // requirement and fall back to disposal=2 standalone frames.
      final src = _buildStickerGif();
      for (final lossy in [0, 40]) {
        final decoded = await optimizeAndDecode(src, lossy: lossy);
        expect(decoded!.numFrames, 2);
        for (var f = 0; f < 2; f++) {
          var opaque = 0;
          for (final px in decoded.frames[f]) {
            if (px.a.toInt() != 0) opaque++;
          }
          expect(opaque, 4,
              reason: 'frame $f (lossy=$lossy) must show exactly the 2×2 dot — '
                  'more means the previous dot position was never erased');
        }
      }
    });

    test('1×1 sub-rect duplicate frame merges instead of flashing', () async {
      // Regression: package:image's decode() floods such frames with index 0
      // (bright teal here), which the optimizer then faithfully encoded — a
      // full-canvas wrong-color flash frame. With correct raw-frame
      // compositing frame 1 displays identically to frame 0 and must merge
      // into a single 20cs frame.
      final src = _buildSubRectDupGif();
      final input = File('${tmp.path}/dup_in.gif')..writeAsBytesSync(src);
      final output = File('${tmp.path}/dup_out.gif');
      await GifOptimizer.optimize(input, output, colors: 64, lossy: 40);
      final outBytes = output.readAsBytesSync();
      final decoded = img.decodeGif(outBytes);
      expect(decoded!.numFrames, 1,
          reason: 'duplicate placeholder frame must fold into frame 0');
      // package:image does not set frameDuration on single-frame decodes, so
      // read the GCE delay (byte 4/5 after the 21 F9 04 header) directly.
      var delayCs = -1;
      for (var i = 0; i + 5 < outBytes.length; i++) {
        if (outBytes[i] == 0x21 && outBytes[i + 1] == 0xF9) {
          delayCs = outBytes[i + 4] | (outBytes[i + 5] << 8);
          break;
        }
      }
      expect(delayCs, 20, reason: 'folded duration must be preserved (cs)');
      // Content must be the checker, not a teal flood.
      final px = decoded.frames[0].getPixel(0, 0);
      expect(px.r, greaterThan(150), reason: 'checker red/white, not teal');
    });

    test('localPalettes shrinks output when frame regions use few colors',
        () async {
      final src = _buildGradientStripGif();
      final input = File('${tmp.path}/lct_in.gif')..writeAsBytesSync(src);
      final global = File('${tmp.path}/lct_off.gif');
      final local = File('${tmp.path}/lct_on.gif');
      await GifOptimizer.optimize(input, global, colors: 128, lossy: 0);
      await GifOptimizer.optimize(input, local,
          colors: 128, lossy: 0, localPalettes: true);
      // The diffed regions (red square over a flat blue strip) use ~3 palette
      // entries against a ~128-color global table — the LCT pass must win.
      expect(local.lengthSync(), lessThan(global.lengthSync()));
      // At least one frame must actually carry a local color table.
      final bytes = local.readAsBytesSync();
      var hasLct = false;
      for (var i = 0; i + 9 < bytes.length; i++) {
        // Image Descriptor: 2C, 8 bytes geometry, then the packed flags byte.
        if (bytes[i] == 0x2C && (bytes[i + 9] & 0x80) != 0) {
          hasLct = true;
          break;
        }
      }
      expect(hasLct, isTrue, reason: 'no frame used a local color table');
    });

    test('localPalettes output keeps frame content correct', () async {
      // Note: the comparison target is the source semantics, not the
      // global-table output — package:image's decode() mis-composites
      // sub-rect disposal=1 frames that LACK a local color table (see the
      // optimizer's decode notes), so the two outputs can't be diffed
      // pixel-for-pixel through it. Frames that carry an LCT decode fine.
      final src = _buildGradientStripGif();
      final input = File('${tmp.path}/lct2_in.gif')..writeAsBytesSync(src);
      final local = File('${tmp.path}/lct2_on.gif');
      await GifOptimizer.optimize(input, local,
          colors: 128, lossy: 0, localPalettes: true);
      final decoded = img.decodeGif(local.readAsBytesSync())!;
      expect(decoded.numFrames, 3);
      expect(decoded.width, 128);
      expect(decoded.height, 128);
      for (var f = 1; f < 3; f++) {
        final frame = decoded.frames[f];
        // A red checker cell at the checker's position for this frame…
        // (x=f*32, y=92 → (x+y) even → red.)
        final sq = frame.getPixel(f * 32 + (f * 32 + 92) % 2, 92);
        expect(sq.r, greaterThan(sq.g), reason: 'frame $f checker not red');
        expect(sq.r, greaterThan(sq.b), reason: 'frame $f checker not red');
        // …and the strip is blue where the previous checker was erased.
        final strip = frame.getPixel((f - 1) * 32 + 16, 100);
        expect(strip.b, greaterThan(strip.r),
            reason: 'frame $f old checker position not restored to blue');
      }
    });

    test('localPalettes with lossy stays within size of lossy alone', () async {
      final src = _buildGradientStripGif();
      final input = File('${tmp.path}/lct3_in.gif')..writeAsBytesSync(src);
      final off = File('${tmp.path}/lct3_off.gif');
      final on = File('${tmp.path}/lct3_on.gif');
      await GifOptimizer.optimize(input, off, colors: 128, lossy: 40);
      await GifOptimizer.optimize(input, on,
          colors: 128, lossy: 40, localPalettes: true);
      // LCT is only kept per frame when it beats the global encoding, so the
      // flag can never make the file bigger.
      expect(on.lengthSync(), lessThanOrEqualTo(off.lengthSync()));
      expect(img.decodeGif(on.readAsBytesSync()), isNotNull);
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

    test('onProgress reports non-decreasing fractions up to completion',
        () async {
      final src = _buildSourceGif(24);
      final input = File('${tmp.path}/progress_in.gif')
        ..writeAsBytesSync(src);
      final output = File('${tmp.path}/progress_out.gif');
      final seen = <double>[];
      await GifOptimizer.optimize(input, output,
          colors: 32, onProgress: seen.add);
      expect(seen, isNotEmpty);
      expect(seen.first, 0.0);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
      expect(seen.last, lessThan(1.0),
          reason: 'sent before each frame — last index never reaches 1.0');
    });

    test(
        'onProgress works even when the callback closes over an unsendable object',
        () async {
      // Regression: Isolate.run captures its whole enclosing lexical Context,
      // not just the variables its own body names. A sibling closure over an
      // unsendable object (here, a Future — real callers close over a
      // Riverpod controller/Future chain) used to get dragged along and blow
      // up with "object is unsendable" even though this closure never
      // crosses the isolate boundary itself.
      final src = _buildSourceGif(24);
      final input = File('${tmp.path}/progress2_in.gif')
        ..writeAsBytesSync(src);
      final output = File('${tmp.path}/progress2_out.gif');
      final guard = Completer<void>(); // unsendable
      var calls = 0;
      await GifOptimizer.optimize(input, output, colors: 32,
          onProgress: (f) {
        calls++;
        guard.future.ignore();
      });
      expect(calls, greaterThan(0));
    });
  });
}
