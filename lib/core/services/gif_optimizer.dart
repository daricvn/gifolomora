import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'gif/gif_lzw.dart';

/// Pure-Dart GIF optimizer. No external binary required — works on all
/// platforms (Android, Windows, Linux).
///
/// Reimplements the core size wins of gifsicle (`optimize.c`) on top of a
/// custom GIF writer:
///   * one shared global color table (NeuralQuantizer) → [colors] colors;
///   * inter-frame transparency diffing — pixels unchanged from the previous
///     displayed frame are written as a transparent index, so the LZW stream
///     collapses long transparent runs (disposal = "leave in place");
///   * per-frame bounding-box cropping of the changed region;
///   * spec-correct variable-width LZW with a minimum code size derived from
///     the real palette.
///
/// [colors]  2–256  global palette size after quantization.
/// [lossy]   0–200  0 = lossless inter-frame diff (only pixels that map to the
///                  exact same palette index become transparent). Higher values
///                  also drop pixels whose previously-displayed color is within
///                  a perceptual distance — like gifsicle's `--lossy`, this
///                  enlarges transparent regions and shrinks the file at the
///                  cost of accuracy.
class GifOptimizer {
  const GifOptimizer._();

  static Future<void> optimize(
    File input,
    File output, {
    int colors = 128,
    int lossy = 0,
  }) async {
    final bytes = await input.readAsBytes();
    final result = await Isolate.run(
      () => _process(bytes, colors.clamp(2, 256), lossy.clamp(0, 200)),
    );
    await output.writeAsBytes(result);
  }

  // ---- pipeline ------------------------------------------------------------

  static Uint8List _process(Uint8List bytes, int colors, int lossy) {
    final decoded = img.decodeGif(bytes);
    if (decoded == null) throw const FormatException('Invalid GIF');

    final width = decoded.width;
    final height = decoded.height;
    final pixels = width * height;
    final srcFrames =
        decoded.frames.isEmpty ? <img.Image>[decoded] : decoded.frames.toList();
    final frameCount = srcFrames.length;

    // Reserve one palette slot for transparency used by inter-frame diffing.
    // The octree quantizer can return up to numberOfColors+1 entries, so cap
    // the request at 254 → at most 255 real colors + 1 transparent ≤ 256.
    final paletteColors = colors > 254 ? 254 : colors;

    // 1. Resolve every frame to full-canvas RGBA + remember which pixels were
    //    originally transparent. Frames from decodeGif are already composited.
    final framesRgb = List<Uint8List>.filled(frameCount, Uint8List(0));
    final framesTransparent = List<Uint8List>.filled(frameCount, Uint8List(0));
    final durations = List<int>.filled(frameCount, 10);
    for (var f = 0; f < frameCount; f++) {
      final frame = srcFrames[f];
      final rgb = Uint8List(pixels * 3);
      final trans = Uint8List(pixels);
      var i = 0;
      var p = 0;
      for (final px in frame) {
        rgb[i] = px.r.toInt();
        rgb[i + 1] = px.g.toInt();
        rgb[i + 2] = px.b.toInt();
        if (px.a.toInt() == 0) trans[p] = 1;
        i += 3;
        p++;
      }
      framesRgb[f] = rgb;
      framesTransparent[f] = trans;
      final d = frame.frameDuration; // ms
      durations[f] = d > 0 ? (d ~/ 10) : 10; // → centiseconds, min 1cs default
    }

    // 2. Train one global palette across all frames.
    final quantizer = _buildGlobalPalette(framesRgb, width, height, paletteColors);
    final palette = quantizer.palette;
    final realColors = palette.numColors;
    final transparentIndex = realColors; // appended slot
    final totalColors = realColors + 1;

    // 3. Map each frame's pixels to palette indices via TRUE nearest-color
    //    search. The octree builds a good palette but its own getColorIndexRgb
    //    is a tree-walk that dead-ends to index 0 for colors whose path was
    //    folded away (e.g. white → near-black) — that produced dark "holes".
    //    Source GIFs have a bounded set of unique colors, so a memo cache makes
    //    the exhaustive search cheap.
    final pr = Uint8List(realColors);
    final pg = Uint8List(realColors);
    final pb = Uint8List(realColors);
    for (var i = 0; i < realColors; i++) {
      pr[i] = palette.getRed(i).toInt();
      pg[i] = palette.getGreen(i).toInt();
      pb[i] = palette.getBlue(i).toInt();
    }
    final cache = <int, int>{};
    int nearest(int r, int g, int b) {
      final key = (r << 16) | (g << 8) | b;
      final cached = cache[key];
      if (cached != null) return cached;
      var best = 0;
      var bestD = 1 << 30;
      for (var i = 0; i < realColors; i++) {
        final dr = r - pr[i];
        final dg = g - pg[i];
        final db = b - pb[i];
        final d = dr * dr + dg * dg + db * db;
        if (d < bestD) {
          bestD = d;
          best = i;
          if (d == 0) break;
        }
      }
      cache[key] = best;
      return best;
    }

    final framesIndex = List<Uint8List>.filled(frameCount, Uint8List(0));
    for (var f = 0; f < frameCount; f++) {
      final rgb = framesRgb[f];
      final idx = Uint8List(pixels);
      for (var p = 0, j = 0; p < pixels; p++, j += 3) {
        idx[p] = nearest(rgb[j], rgb[j + 1], rgb[j + 2]);
      }
      framesIndex[f] = idx;
    }

    // 4. Inter-frame transparency diff against the running DISPLAYED canvas.
    //    With disposal=1 a transparent pixel shows whatever was last *drawn* at
    //    that location — the composite of all prior frames, not the full
    //    previous frame. Diffing against the full previous frame lets lossy
    //    error accumulate: each per-frame change can stay under budget while the
    //    displayed pixel, frozen at an early frame, drifts arbitrarily far from
    //    the true color → heavy ghosting / stale traces. Instead track the
    //    actual displayed index per pixel and only leave a pixel transparent
    //    when the canvas already shows the right color (lossless) or a color
    //    within the lossy budget of the true color; otherwise redraw and update
    //    the canvas. This bounds the displayed error to the budget every frame.
    final lossyBudget = lossy * lossy;
    final canvas = Uint8List(pixels)..fillRange(0, pixels, transparentIndex);
    for (var f = 0; f < frameCount; f++) {
      final cur = framesIndex[f];
      final curRgb = framesRgb[f];
      final curTrans = framesTransparent[f];
      final out = Uint8List(pixels);
      for (var p = 0, j = 0; p < pixels; p++, j += 3) {
        if (curTrans[p] == 1) {
          out[p] = transparentIndex; // originally transparent → reveal previous
          continue;
        }
        final desired = cur[p];
        final shown = canvas[p];
        var transparent = false;
        if (shown == desired) {
          transparent = true; // canvas already correct
        } else if (lossyBudget > 0 && shown != transparentIndex) {
          // Distance of the true current color to what the canvas displays now.
          final dr = curRgb[j] - pr[shown];
          final dg = curRgb[j + 1] - pg[shown];
          final db = curRgb[j + 2] - pb[shown];
          if (dr * dr + dg * dg + db * db <= lossyBudget) transparent = true;
        }
        if (transparent) {
          out[p] = transparentIndex;
        } else {
          out[p] = desired; // redraw — canvas was wrong / too far
          canvas[p] = desired;
        }
      }
      framesIndex[f] = out;
    }

    // 5. Assemble GIF bytes.
    final minCodeSize = _minCodeSize(totalColors);
    final loopCount = decoded.loopCount;
    return _writeGif(
      width: width,
      height: height,
      palette: palette,
      transparentIndex: transparentIndex,
      minCodeSize: minCodeSize,
      framesIndex: framesIndex,
      durations: durations,
      loopCount: loopCount,
    );
  }

  static img.Quantizer _buildGlobalPalette(
    List<Uint8List> framesRgb,
    int width,
    int height,
    int colors,
  ) {
    final n = framesRgb.length;
    // Stack all frames vertically into one RGB image to train the quantizer on
    // the whole animation's color distribution.
    final stacked = img.Image(width: width, height: height * n, numChannels: 3);
    final dst = stacked.toUint8List(); // RGB bytes, row-major
    var o = 0;
    for (var f = 0; f < n; f++) {
      final rgb = framesRgb[f];
      dst.setRange(o, o + rgb.length, rgb);
      o += rgb.length;
    }
    // Octree preserves distinct colors (it counts real colors and folds the
    // least-frequent), which keeps accent colors on flat backgrounds — closer
    // to gifsicle than a neural net that under-trains rare colors.
    return img.OctreeQuantizer(stacked, numberOfColors: colors);
  }

  // ---- GIF byte assembly ---------------------------------------------------

  static Uint8List _writeGif({
    required int width,
    required int height,
    required img.Palette palette,
    required int transparentIndex,
    required int minCodeSize,
    required List<Uint8List> framesIndex,
    required List<int> durations,
    required int loopCount,
  }) {
    final out = BytesBuilder(copy: false);

    void u16(int v) => out
      ..addByte(v & 0xff)
      ..addByte((v >> 8) & 0xff);

    // Header.
    out.add(const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]); // "GIF89a"

    // Global color table sized to next power of two ≥ transparentIndex+1.
    final gctSizeField = _gctSizeField(transparentIndex + 1);
    final gctColors = 1 << (gctSizeField + 1);

    // Logical Screen Descriptor.
    u16(width);
    u16(height);
    out.addByte(0xF0 | gctSizeField); // GCT present, 8-bit color resolution.
    out.addByte(0); // background color index
    out.addByte(0); // pixel aspect ratio

    // Global Color Table.
    final realColors = palette.numColors;
    for (var i = 0; i < gctColors; i++) {
      if (i < realColors) {
        out
          ..addByte(palette.getRed(i).toInt())
          ..addByte(palette.getGreen(i).toInt())
          ..addByte(palette.getBlue(i).toInt());
      } else {
        out
          ..addByte(0)
          ..addByte(0)
          ..addByte(0);
      }
    }

    final animated = framesIndex.length > 1;
    if (animated) {
      // NETSCAPE2.0 looping extension.
      out
        ..addByte(0x21)
        ..addByte(0xFF)
        ..addByte(11)
        ..add('NETSCAPE2.0'.codeUnits)
        ..addByte(0x03)
        ..addByte(0x01);
      u16(loopCount); // 0 = loop forever
      out.addByte(0);
    }

    for (var f = 0; f < framesIndex.length; f++) {
      final idx = framesIndex[f];

      // Crop to bounding box of non-transparent pixels.
      final box = _boundingBox(idx, width, height, transparentIndex);

      // Graphic Control Extension. Disposal = 1 (leave in place) so transparent
      // pixels reveal the previous frame.
      out
        ..addByte(0x21)
        ..addByte(0xF9)
        ..addByte(4)
        ..addByte((1 << 2) | 0x01); // disposal=1, transparency flag on
      u16(durations[f]);
      out
        ..addByte(transparentIndex & 0xff)
        ..addByte(0);

      // Image Descriptor.
      out.addByte(0x2C);
      u16(box.left);
      u16(box.top);
      u16(box.width);
      u16(box.height);
      out.addByte(0); // no local color table, no interlace

      // Cropped index data.
      final region = _crop(idx, width, box);
      out.add(GifLzw.encode(region, minCodeSize));
    }

    out.addByte(0x3B); // trailer
    return out.toBytes();
  }

  static _Box _boundingBox(
      Uint8List idx, int width, int height, int transparentIndex) {
    var minX = width, minY = height, maxX = -1, maxY = -1;
    for (var y = 0, p = 0; y < height; y++) {
      for (var x = 0; x < width; x++, p++) {
        if (idx[p] != transparentIndex) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) {
      // Fully transparent frame — emit a minimal 1×1 region.
      return const _Box(0, 0, 1, 1);
    }
    return _Box(minX, minY, maxX - minX + 1, maxY - minY + 1);
  }

  static Uint8List _crop(Uint8List idx, int srcWidth, _Box box) {
    final region = Uint8List(box.width * box.height);
    var o = 0;
    for (var y = 0; y < box.height; y++) {
      final rowStart = (box.top + y) * srcWidth + box.left;
      region.setRange(o, o + box.width,
          Uint8List.sublistView(idx, rowStart, rowStart + box.width));
      o += box.width;
    }
    return region;
  }

  // ---- helpers -------------------------------------------------------------

  static int _minCodeSize(int totalColors) {
    var bits = 1;
    while ((1 << bits) < totalColors) {
      bits++;
    }
    return bits < 2 ? 2 : bits;
  }

  /// GCT size field: the GIF stores `n` where the table holds 2^(n+1) colors.
  static int _gctSizeField(int neededColors) {
    var n = 0;
    while ((1 << (n + 1)) < neededColors) {
      n++;
    }
    return n > 7 ? 7 : n;
  }
}

class _Box {
  final int left;
  final int top;
  final int width;
  final int height;
  const _Box(this.left, this.top, this.width, this.height);
}
