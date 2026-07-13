import 'dart:async';
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

  /// [loopCount]  null = preserve the input GIF's loop count; otherwise
  ///              override the NETSCAPE2.0 loop count (0 = loop forever).
  /// [frameDrop]  0 = keep all frames; 2/3/4 = remove 1 of every N frames
  ///              (2 → halve, 3 → drop a third, 4 → drop a quarter). The dropped
  ///              frame's duration is folded into the previous kept frame so
  ///              total playback time is unchanged. Frame 0 is always kept.
  /// [localPalettes]  lossless extra pass (gifsicle optimize level 3 style):
  ///              when a frame's diffed region uses few enough palette entries
  ///              that a smaller LZW minimum code size becomes possible, the
  ///              frame is re-encoded against a compact per-frame local color
  ///              table, and kept only if LCT bytes + narrower codes beat the
  ///              global-table encoding. Off by default (costs an extra encode
  ///              per qualifying frame).
  static Future<void> optimize(
    File input,
    File output, {
    int colors = 128,
    int lossy = 0,
    int? loopCount,
    int frameDrop = 0,
    bool localPalettes = false,
    void Function(double fraction)? onProgress,
  }) async {
    final bytes = await input.readAsBytes();
    // ponytail: only the frame encode loop (step 4, the dominant cost)
    // reports progress — decode/palette/color-map stay coarse. Good enough
    // to turn an indeterminate spinner into a moving bar; per-phase weighting
    // only worth it if users complain the bar jumps at the start.
    ReceivePort? progressPort;
    StreamSubscription? progressSub;
    if (onProgress != null) {
      progressPort = ReceivePort();
      progressSub = progressPort.listen((msg) => onProgress(msg as double));
    }
    try {
      final result = await _spawn(bytes, colors.clamp(2, 256),
          lossy.clamp(0, 200), loopCount, frameDrop, localPalettes,
          progressPort?.sendPort);
      await output.writeAsBytes(result);
    } finally {
      await progressSub?.cancel();
      progressPort?.close();
    }
  }

  // Isolate.run captures its whole enclosing Context, not just the variables
  // its closure body names — a sibling closure over `onProgress` (above, in
  // optimize()) shares that Context, so the callback rides along and blows up
  // ("object is unsendable") the moment the caller's onProgress closes over
  // anything unsendable (a Future, a Riverpod ref, ...). A dedicated function
  // whose scope never contains `onProgress` sidesteps it.
  static Future<Uint8List> _spawn(Uint8List bytes, int colors, int lossy,
      int? loopCount, int frameDrop, bool localPalettes, SendPort? progressPort) {
    return Isolate.run(() => _process(
        bytes, colors, lossy, loopCount, frameDrop, localPalettes, progressPort));
  }

  // ---- pipeline ------------------------------------------------------------

  static Uint8List _process(Uint8List bytes, int colors, int lossy,
      int? loopOverride, int frameDrop, bool localPalettes,
      SendPort? progressPort) {
    // 1. Decode raw frames and composite them ourselves. package:image's
    //    decode() mis-composites sub-rect disposal=1 frames that lack a local
    //    color table — it skips the previous-canvas copy, flooding the frame
    //    with index 0 and drawing only the sub-rect. Pre-optimized GIFs carry
    //    1×1 duplicate-frame placeholders and cropped diff frames, which came
    //    out as a solid wrong-color "flash" frame. decodeFrame() returns raw
    //    rect frames (palette alpha 0 = transparent); spec compositing is done
    //    here: draw opaque pixels at the frame offset, snapshot, then apply
    //    disposal (1 keep, 2 clear rect, 3 restore previous).
    //    ponytail: interlaced sub-rect frames still broken upstream
    //    (decodeFrame writes interlaced rows at absolute y into a rect-sized
    //    image) — write our own LZW/block reader if that class ever shows up.
    final decoder = img.GifDecoder();
    final gifInfo = decoder.startDecode(bytes);
    if (gifInfo == null || gifInfo.frames.isEmpty) {
      throw const FormatException('Invalid GIF');
    }
    final width = gifInfo.width;
    final height = gifInfo.height;
    final pixels = width * height;
    final totalFrames = gifInfo.frames.length;

    // Composite every source frame in order (the disposal chain needs all of
    // them), snapshotting the ones that survive [frameDrop] (1 of every N
    // dropped; a dropped frame's duration folds into the previous kept frame
    // so playback time is unchanged; frame 0 is always kept).
    final framesRgb = <Uint8List>[];
    final framesTransparent = <Uint8List>[];
    final durations = <int>[]; // centiseconds
    final canvasRgb = Uint8List(pixels * 3);
    final canvasCovered = Uint8List(pixels); // 0 = never drawn → transparent
    for (var f = 0; f < totalFrames; f++) {
      final desc = gifInfo.frames[f];
      final raw = decoder.decodeFrame(f);
      if (raw == null) throw const FormatException('Invalid GIF');
      Uint8List? savedRgb;
      Uint8List? savedCovered;
      if (desc.disposal == 3) {
        savedRgb = Uint8List.fromList(canvasRgb);
        savedCovered = Uint8List.fromList(canvasCovered);
      }
      for (final px in raw) {
        if (px.a.toInt() == 0) continue; // transparent → keep canvas
        final p = (desc.y + px.y) * width + (desc.x + px.x);
        final o = p * 3;
        canvasRgb[o] = px.r.toInt();
        canvasRgb[o + 1] = px.g.toInt();
        canvasRgb[o + 2] = px.b.toInt();
        canvasCovered[p] = 1;
      }

      final drop = frameDrop >= 2 &&
          durations.isNotEmpty &&
          (f % frameDrop) == frameDrop - 1;
      final durCs = desc.duration > 0 ? desc.duration.clamp(1, 6000) : 10;
      if (drop) {
        durations[durations.length - 1] =
            (durations.last + durCs).clamp(1, 6000);
      } else {
        framesRgb.add(Uint8List.fromList(canvasRgb));
        final trans = Uint8List(pixels);
        for (var p = 0; p < pixels; p++) {
          trans[p] = canvasCovered[p] == 0 ? 1 : 0;
        }
        framesTransparent.add(trans);
        durations.add(durCs);
      }

      // Disposal applies after the frame is displayed.
      if (desc.disposal == 2) {
        final bottom = desc.y + raw.height;
        final right = desc.x + raw.width;
        for (var y = desc.y; y < bottom; y++) {
          final row = y * width;
          for (var x = desc.x; x < right; x++) {
            canvasCovered[row + x] = 0;
          }
        }
      } else if (desc.disposal == 3 && savedRgb != null) {
        canvasRgb.setAll(0, savedRgb);
        canvasCovered.setAll(0, savedCovered!);
      }
    }
    final frameCount = framesRgb.length;

    // Reserve one palette slot for transparency used by inter-frame diffing,
    // and keep real+transparent within the caller's color budget: crossing a
    // power-of-two boundary (e.g. 130 entries for colors=128) doubles the GCT
    // and widens every LZW code by a bit. The octree quantizer can return up
    // to numberOfColors+1 entries, so request two below the budget.
    final paletteColors = (colors - 2).clamp(2, 254);

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
    // Redmean: cheap luma-weighted RGB distance (compuphase.com/cmetric.htm).
    // Plain squared-RGB treats all channels equally, but the eye is far more
    // sensitive to green — weighting by red level approximates perceptual
    // distance without a colorspace conversion.
    int weightedDist(int r1, int g1, int b1, int r2, int g2, int b2) {
      final rmean = (r1 + r2) >> 1;
      final dr = r1 - r2;
      final dg = g1 - g2;
      final db = b1 - b2;
      return (((512 + rmean) * dr * dr) >> 8) +
          4 * dg * dg +
          (((767 - rmean) * db * db) >> 8);
    }

    final cache = <int, int>{};
    int nearest(int r, int g, int b) {
      // 5-bit quantized key → 32768 buckets; near-photographic cache hit rate.
      final key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
      final cached = cache[key];
      if (cached != null) return cached;
      var best = 0;
      var bestD = 1 << 30;
      for (var i = 0; i < realColors; i++) {
        final d = weightedDist(r, g, b, pr[i], pg[i], pb[i]);
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

    // 3a. Intra-frame lossy: horizontal run-extension. Snap each pixel to its
    //     left neighbor's palette index when the true color is within budget →
    //     long flat runs before encoding.
    final lossyBudget = lossy * lossy;
    if (lossy > 0) {
      for (var f = 0; f < frameCount; f++) {
        final idx = framesIndex[f];
        final rgb = framesRgb[f];
        for (var p = 0, j = 0; p < pixels; p++, j += 3) {
          if (p % width == 0) continue; // first pixel of row — no left neighbor
          final prev = idx[p - 1];
          if (prev == idx[p]) continue;
          final dr = rgb[j] - pr[prev];
          final dg = rgb[j + 1] - pg[prev];
          final db = rgb[j + 2] - pb[prev];
          if (dr * dr + dg * dg + db * db <= lossyBudget) {
            idx[p] = prev;
          }
        }
      }
    }

    // 3b. Lossy candidate lists: for a given true color, every palette index
    //     within the budget, sorted by ascending error. The lossy LZW encoder
    //     picks the first candidate that extends its current dictionary match,
    //     so the error budget is spent only where it lengthens phrases
    //     (gifsicle `--lossy` style). Cached on the same 5-bit-quantized key
    //     as [nearest]; the encoder re-verifies each candidate against the
    //     exact pixel color, so the cache is only a pre-filter.
    final candCache = <int, Uint8List>{};
    Uint8List candidatesFor(int r, int g, int b) {
      final key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
      final cached = candCache[key];
      if (cached != null) return cached;
      final ids = <int>[];
      final errs = <int>[];
      for (var i = 0; i < realColors; i++) {
        final dr = r - pr[i];
        final dg = g - pg[i];
        final db = b - pb[i];
        final d = dr * dr + dg * dg + db * db;
        // Gate stays raw squared-RGB — lossyBudget's scale (lossy*lossy) and
        // the exact re-verification in encodeLossy both assume it. Only the
        // ranking of in-budget candidates uses the perceptual metric, so the
        // LZW encoder's first-fit pick is the best-looking one, not just the
        // numerically closest.
        if (d <= lossyBudget) {
          final wd = weightedDist(r, g, b, pr[i], pg[i], pb[i]);
          // Insertion sort by perceptual error — candidate lists are tiny.
          var at = ids.length;
          while (at > 0 && errs[at - 1] > wd) {
            at--;
          }
          ids.insert(at, i);
          errs.insert(at, wd);
        }
      }
      final result = ids.isEmpty
          ? Uint8List.fromList([nearest(r, g, b)])
          : Uint8List.fromList(ids);
      candCache[key] = result;
      return result;
    }

    // 3c. Sticker-class detection. The diff pipeline writes disposal=1, and
    //     with disposal=1 a transparent pixel can only ever REVEAL what was
    //     drawn before — it can never erase it. A GIF with a genuinely
    //     transparent background whose opaque region moves or shrinks needs
    //     erasure, so disposal=1 would leave permanent ghost trails (and they
    //     accumulate across loop iterations). Detect that case up front and
    //     fall back to standalone disposal=2 frames, which restore the frame
    //     rect to background after display — spec-correct erase.
    var needsErase = false;
    final everDrawn = Uint8List(pixels);
    for (var f = 0; f < frameCount && !needsErase; f++) {
      final trans = framesTransparent[f];
      for (var p = 0; p < pixels; p++) {
        if (trans[p] == 1) {
          if (everDrawn[p] == 1) {
            needsErase = true;
            break;
          }
        } else {
          everDrawn[p] = 1;
        }
      }
    }

    // 4. Per-frame transparency + encode.
    //
    //    Normal mode (disposal=1): inter-frame diff against the running
    //    DISPLAYED canvas. A transparent pixel shows whatever was last *drawn*
    //    at that location — the composite of all prior frames, not the full
    //    previous frame. Diffing against the full previous frame lets lossy
    //    error accumulate: each per-frame change can stay under budget while
    //    the displayed pixel, frozen at an early frame, drifts arbitrarily far
    //    from the true color → heavy ghosting. Instead track the actual
    //    displayed index per pixel and only leave a pixel transparent when the
    //    canvas already shows the right color (lossless) or a color within the
    //    lossy budget of the true color. Encoding happens inside this loop
    //    because the lossy LZW path may substitute a different in-budget index
    //    per pixel, and the canvas must track what is actually displayed — not
    //    what we asked for. Frames that draw nothing merge into the previous
    //    frame's duration (same as gifsicle); frame 0 is always kept.
    //
    //    Erase mode (disposal=2): every frame stands alone on a cleared
    //    canvas, transparency is the source's own; only exact-duplicate
    //    consecutive frames merge. No inter-frame diff savings, but correct.
    //    ponytail: whole-GIF fallback; per-frame disposal mixing (gifsicle
    //    optimize level 3) if sticker GIFs ever need diff savings too.
    final minCodeSize = _minCodeSize(totalColors);
    final canvas = Uint8List(pixels)..fillRange(0, pixels, transparentIndex);
    final boxes = <_Box>[];
    final imageData = <Uint8List>[];
    final outDurations = <int>[];
    final localTables = <Uint8List?>[]; // padded RGB bytes, null = use GCT
    final frameTransparents = <int?>[]; // null = no transparency flag
    Uint8List? prevOut; // erase mode: last kept frame, for duplicate folding
    for (var f = 0; f < frameCount; f++) {
      progressPort?.send(f / frameCount);
      final cur = framesIndex[f];
      final curRgb = framesRgb[f];
      final curTrans = framesTransparent[f];
      final out = Uint8List(pixels);
      var keep = true;
      if (needsErase) {
        for (var p = 0; p < pixels; p++) {
          out[p] = curTrans[p] == 1 ? transparentIndex : cur[p];
        }
        keep = prevOut == null || !_listEquals(out, prevOut);
      } else {
        var drewAny = false;
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
            // Distance of the true current color to what the canvas shows now.
            final dr = curRgb[j] - pr[shown];
            final dg = curRgb[j + 1] - pg[shown];
            final db = curRgb[j + 2] - pb[shown];
            if (dr * dr + dg * dg + db * db <= lossyBudget) transparent = true;
          }
          if (transparent) {
            out[p] = transparentIndex;
          } else {
            out[p] = desired; // redraw — canvas was wrong / too far
            drewAny = true;
          }
        }
        keep = drewAny || outDurations.isEmpty;
      }

      if (!keep) {
        // No-change frame: fold its duration into the previous frame.
        outDurations[outDurations.length - 1] =
            (outDurations.last + durations[f]).clamp(1, 6000);
        continue;
      }

      // Erase mode writes full-canvas frames: disposal=2 only clears the
      // frame's own rect, and package:image's decoder (used when an optimized
      // GIF is fed back in) crashes on disposal=2 sub-rect frames. Transparent
      // runs are nearly free in LZW, so the crop buys little there anyway.
      final box = needsErase
          ? _Box(0, 0, width, height)
          : _boundingBox(out, width, height, transparentIndex);
      final regionIdx = needsErase ? out : _crop(out, width, box);
      var encoded = GifLzw.encode(regionIdx, minCodeSize);
      var finalIdx = regionIdx;
      if (lossyBudget > 0) {
        // Two-way pick: also encode with in-budget index substitution that
        // extends LZW matches, and keep whichever frame is smaller. Which one
        // wins depends on content (substitution shrinks noisy regions but can
        // disrupt phrase build-up on smooth gradients), so measure, don't
        // guess. Both stay within the lossy budget of the true colors.
        final regionRgb = _cropRgb(curRgb, width, box);
        final chosen = Uint8List(regionIdx.length);
        final lossyEncoded = GifLzw.encodeLossy(
          regionIdx,
          regionRgb,
          minCodeSize,
          transparentIndex: transparentIndex,
          candidatesFor: candidatesFor,
          paletteR: pr,
          paletteG: pg,
          paletteB: pb,
          budget: lossyBudget,
          chosen: chosen,
        );
        if (lossyEncoded.length < encoded.length) {
          encoded = lossyEncoded;
          finalIdx = chosen;
        }
      }
      if (needsErase) {
        prevOut = out;
      } else {
        // The canvas must reflect what the encoder actually wrote.
        var o = 0;
        for (var y = 0; y < box.height; y++) {
          var p = (box.top + y) * width + box.left;
          for (var x = 0; x < box.width; x++, p++, o++) {
            final v = finalIdx[o];
            if (v != transparentIndex) canvas[p] = v;
          }
        }
      }

      // Optional lossless LCT pass: if the frame's region uses few enough
      // palette entries for a smaller minimum code size, re-encode against a
      // compact local color table. Remapping is a bijection on the used
      // indices, so the LZW phrase structure — and code count — is identical;
      // only the code widths shrink. Keep it only when LCT bytes + narrower
      // codes actually beat the global-table encoding.
      Uint8List? lct;
      int? frameTransparent = transparentIndex;
      if (localPalettes) {
        final used = Uint8List(totalColors);
        for (final v in finalIdx) {
          used[v] = 1;
        }
        var usedCount = 0;
        for (var i = 0; i < totalColors; i++) {
          usedCount += used[i];
        }
        final lctMinCode = _minCodeSize(usedCount);
        if (lctMinCode < minCodeSize) {
          final remap = Uint8List(totalColors);
          var next = 0;
          for (var i = 0; i < totalColors; i++) {
            if (used[i] == 1) remap[i] = next++;
          }
          final remapped = Uint8List(finalIdx.length);
          for (var p = 0; p < finalIdx.length; p++) {
            remapped[p] = remap[finalIdx[p]];
          }
          final lctEncoded = GifLzw.encode(remapped, lctMinCode);
          final lctColors = 1 << (_gctSizeField(usedCount) + 1);
          if (lctEncoded.length + lctColors * 3 < encoded.length) {
            final table = Uint8List(lctColors * 3);
            for (var i = 0; i < realColors; i++) {
              if (used[i] == 0) continue;
              final o = remap[i] * 3;
              table[o] = pr[i];
              table[o + 1] = pg[i];
              table[o + 2] = pb[i];
            }
            encoded = lctEncoded;
            lct = table;
            frameTransparent =
                used[transparentIndex] == 1 ? remap[transparentIndex] : null;
          }
        }
      }
      localTables.add(lct);
      frameTransparents.add(frameTransparent);

      boxes.add(box);
      imageData.add(encoded);
      outDurations.add(durations[f]);
    }

    // 5. Assemble GIF bytes.
    final loopCount = loopOverride ?? _parseLoopCount(bytes);
    return _writeGif(
      width: width,
      height: height,
      palette: palette,
      transparentIndex: transparentIndex,
      disposal: needsErase ? 2 : 1,
      boxes: boxes,
      imageData: imageData,
      durations: outDurations,
      loopCount: loopCount,
      localTables: localTables,
      frameTransparents: frameTransparents,
    );
  }

  static img.Quantizer _buildGlobalPalette(
    List<Uint8List> framesRgb,
    int width,
    int height,
    int colors,
  ) {
    final n = framesRgb.length;
    // Subsample: every 4th frame, every 2nd pixel in both dimensions.
    // Global palettes are statistically stable under subsampling; this cuts
    // training memory/time ~8× with no perceptible quality loss.
    final frameStride = n > 4 ? 4 : 1;
    const pixelStride = 2;
    final sampledW = (width + pixelStride - 1) ~/ pixelStride;
    final sampledH = (height + pixelStride - 1) ~/ pixelStride;
    var sampledFrameCount = 0;
    for (var f = 0; f < n; f += frameStride) {
      sampledFrameCount++;
    }

    final stacked = img.Image(
        width: sampledW, height: sampledH * sampledFrameCount, numChannels: 3);
    final dst = stacked.toUint8List();
    var o = 0;
    for (var f = 0; f < n; f += frameStride) {
      final rgb = framesRgb[f];
      for (var y = 0; y < height; y += pixelStride) {
        for (var x = 0; x < width; x += pixelStride) {
          final p = (y * width + x) * 3;
          dst[o++] = rgb[p];
          dst[o++] = rgb[p + 1];
          dst[o++] = rgb[p + 2];
        }
      }
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
    required int disposal, // 1 = leave in place (diffed), 2 = restore to bg
    required List<_Box> boxes,
    required List<Uint8List> imageData,
    required List<int> durations,
    required int loopCount,
    required List<Uint8List?> localTables,
    required List<int?> frameTransparents,
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

    final animated = imageData.length > 1;
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

    for (var f = 0; f < imageData.length; f++) {
      final box = boxes[f];
      final lct = localTables[f];
      final ti = frameTransparents[f]; // null = frame has no transparent pixel

      // Graphic Control Extension. Disposal 1 (leave in place: transparent
      // pixels reveal the previous frame) or 2 (restore to background:
      // standalone frames that can erase).
      out
        ..addByte(0x21)
        ..addByte(0xF9)
        ..addByte(4)
        ..addByte((disposal << 2) | (ti != null ? 0x01 : 0x00));
      u16(durations[f]);
      out
        ..addByte((ti ?? 0) & 0xff)
        ..addByte(0);

      // Image Descriptor.
      out.addByte(0x2C);
      u16(box.left);
      u16(box.top);
      u16(box.width);
      u16(box.height);
      if (lct == null) {
        out.addByte(0); // no local color table, no interlace
      } else {
        // LCT present; its length is 3·2^(field+1) bytes by construction.
        final field = (lct.length ~/ 3).bitLength - 2;
        out.addByte(0x80 | field);
        out.add(lct);
      }

      // Pre-encoded LZW image data (cropped to the bounding box).
      out.add(imageData[f]);
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

  /// [_crop] for the 3-bytes-per-pixel RGB plane.
  static Uint8List _cropRgb(Uint8List rgb, int srcWidth, _Box box) {
    final rowBytes = box.width * 3;
    final region = Uint8List(rowBytes * box.height);
    var o = 0;
    for (var y = 0; y < box.height; y++) {
      final rowStart = ((box.top + y) * srcWidth + box.left) * 3;
      region.setRange(o, o + rowBytes,
          Uint8List.sublistView(rgb, rowStart, rowStart + rowBytes));
      o += rowBytes;
    }
    return region;
  }

  // ---- helpers -------------------------------------------------------------

  /// Reads the NETSCAPE2.0 loop count (0 = forever). GifInfo does not expose
  /// it, so scan for the extension: 21 FF 0B "NETSCAPE2.0" 03 01 lo hi.
  static int _parseLoopCount(Uint8List bytes) {
    const tag = 'NETSCAPE2.0';
    outer:
    for (var i = 0; i + 17 < bytes.length; i++) {
      if (bytes[i] != 0x21 || bytes[i + 1] != 0xFF || bytes[i + 2] != 0x0B) {
        continue;
      }
      for (var j = 0; j < tag.length; j++) {
        if (bytes[i + 3 + j] != tag.codeUnitAt(j)) continue outer;
      }
      if (bytes[i + 14] == 0x03 && bytes[i + 15] == 0x01) {
        return bytes[i + 16] | (bytes[i + 17] << 8);
      }
    }
    return 0;
  }

  static bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

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
