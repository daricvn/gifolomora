import 'dart:typed_data';

/// Variable-width GIF LZW encoder (spec-compliant, LSB-first bit packing).
///
/// Produces the image data block exactly as a GIF requires: a leading
/// minimum-code-size byte, then the LZW code stream chunked into sub-blocks
/// (each ≤ 255 bytes, length-prefixed), terminated by a zero-length block.
///
/// This is what the `image` package's encoder does NOT give us — it hardcodes
/// an 8-bit code size. A correct variable-width size (derived from the real
/// palette) is part of how gifsicle keeps output small.
class GifLzw {
  const GifLzw._();

  static const int _maxBits = 12;
  static const int _maxCode = 1 << _maxBits; // 4096

  /// Encode [indices] (one palette index per pixel, row-major).
  ///
  /// [minCodeSize] is the GIF minimum code size (2..8), derived from the
  /// palette size by the caller.
  static Uint8List encode(Uint8List indices, int minCodeSize) {
    final mcs = minCodeSize < 2 ? 2 : minCodeSize;
    final clearCode = 1 << mcs;
    final eoiCode = clearCode + 1;

    // NOTE: copy:true is required. Sub-blocks are flushed from the reusable
    // [block] buffer below; with copy:false the builder would retain a view
    // into [block] and later sub-blocks would overwrite earlier ones.
    final out = BytesBuilder();
    out.addByte(mcs);

    // Sub-block accumulator + LSB-first bit accumulator.
    final block = Uint8List(255);
    var blockLen = 0;
    var bitBuffer = 0;
    var bitCount = 0;

    void flushBlock() {
      if (blockLen > 0) {
        out.addByte(blockLen);
        out.add(Uint8List.sublistView(block, 0, blockLen));
        blockLen = 0;
      }
    }

    void writeCode(int code, int codeSize) {
      bitBuffer |= code << bitCount;
      bitCount += codeSize;
      while (bitCount >= 8) {
        block[blockLen++] = bitBuffer & 0xff;
        bitBuffer >>= 8;
        bitCount -= 8;
        if (blockLen == 255) flushBlock();
      }
    }

    // Dictionary keyed by (prefix << 8 | nextIndex); indices are ≤ 255.
    final dict = <int, int>{};
    var codeSize = mcs + 1;
    var nextCode = eoiCode + 1;

    void resetDict() {
      dict.clear();
      codeSize = mcs + 1;
      nextCode = eoiCode + 1;
    }

    writeCode(clearCode, codeSize);

    if (indices.isEmpty) {
      writeCode(eoiCode, codeSize);
    } else {
      var prefix = indices[0];
      for (var i = 1; i < indices.length; i++) {
        final k = indices[i];
        final key = (prefix << 8) | k;
        final existing = dict[key];
        if (existing != null) {
          prefix = existing;
        } else {
          writeCode(prefix, codeSize);
          if (nextCode < _maxCode) {
            dict[key] = nextCode++;
            // Grow code width when the next free code no longer fits. nextCode
            // is post-increment, so `>` here matches giflib's pre-increment
            // `>=` growth timing (decoders use `++code > maxcode`).
            if (nextCode > (1 << codeSize) && codeSize < _maxBits) {
              codeSize++;
            }
          } else {
            // Dictionary full: emit clear and start over.
            writeCode(clearCode, codeSize);
            resetDict();
          }
          prefix = k;
        }
      }
      writeCode(prefix, codeSize);
      writeCode(eoiCode, codeSize);
    }

    // Flush remaining bits.
    if (bitCount > 0) {
      block[blockLen++] = bitBuffer & 0xff;
      if (blockLen == 255) flushBlock();
    }
    flushBlock();

    out.addByte(0); // block terminator
    return out.toBytes();
  }

  /// Lossy variant of [encode], gifsicle `--lossy` style: an opaque pixel may
  /// encode as any palette index within the caller's error budget of its true
  /// color when that keeps the current dictionary match alive — the budget is
  /// spent only where it actually lengthens LZW phrases. Pixels whose desired
  /// index is [transparentIndex] are never altered (transparency carries
  /// inter-frame state and may not be invented or dropped here).
  ///
  /// [indices]       desired (nearest) palette index per pixel.
  /// [rgb]           true colors, 3 bytes per pixel, aligned with [indices].
  /// [candidatesFor] palette indices near (r,g,b) sorted by ascending error;
  ///                 never empty. May be cached on a quantized key, so it is
  ///                 only a pre-filter — every candidate is re-verified here
  ///                 against the exact pixel color and [budget].
  /// [paletteR/G/B]  palette channel values, indexed by palette index.
  /// [budget]        max squared RGB distance a substituted index may have
  ///                 from the pixel's true color.
  /// [chosen]        out-buffer (same length as [indices]) receiving the index
  ///                 each pixel actually encoded as — the caller must use it
  ///                 to keep its displayed-canvas state truthful, otherwise
  ///                 lossy drift/ghosting returns.
  static Uint8List encodeLossy(
    Uint8List indices,
    Uint8List rgb,
    int minCodeSize, {
    required int transparentIndex,
    required Uint8List Function(int r, int g, int b) candidatesFor,
    required Uint8List paletteR,
    required Uint8List paletteG,
    required Uint8List paletteB,
    required int budget,
    required Uint8List chosen,
  }) {
    final mcs = minCodeSize < 2 ? 2 : minCodeSize;
    final clearCode = 1 << mcs;
    final eoiCode = clearCode + 1;

    final out = BytesBuilder(); // copy:true required — see NOTE in encode().
    out.addByte(mcs);

    final block = Uint8List(255);
    var blockLen = 0;
    var bitBuffer = 0;
    var bitCount = 0;

    void flushBlock() {
      if (blockLen > 0) {
        out.addByte(blockLen);
        out.add(Uint8List.sublistView(block, 0, blockLen));
        blockLen = 0;
      }
    }

    void writeCode(int code, int codeSize) {
      bitBuffer |= code << bitCount;
      bitCount += codeSize;
      while (bitCount >= 8) {
        block[blockLen++] = bitBuffer & 0xff;
        bitBuffer >>= 8;
        bitCount -= 8;
        if (blockLen == 255) flushBlock();
      }
    }

    final dict = <int, int>{};
    var codeSize = mcs + 1;
    var nextCode = eoiCode + 1;

    void resetDict() {
      dict.clear();
      codeSize = mcs + 1;
      nextCode = eoiCode + 1;
    }

    var prefixCode = 0;

    // Emit the current prefix and register the phrase under [key] — identical
    // bookkeeping to encode(); see the comments there.
    void emitAndAdd(int key) {
      writeCode(prefixCode, codeSize);
      if (nextCode < _maxCode) {
        dict[key] = nextCode++;
        if (nextCode > (1 << codeSize) && codeSize < _maxBits) {
          codeSize++;
        }
      } else {
        writeCode(clearCode, codeSize);
        resetDict();
      }
    }

    writeCode(clearCode, codeSize);

    if (indices.isEmpty) {
      writeCode(eoiCode, codeSize);
    } else {
      chosen[0] = indices[0];
      prefixCode = indices[0];
      for (var i = 1; i < indices.length; i++) {
        final desired = indices[i];
        if (desired == transparentIndex) {
          chosen[i] = transparentIndex;
          final key = (prefixCode << 8) | transparentIndex;
          final existing = dict[key];
          if (existing != null) {
            prefixCode = existing;
          } else {
            emitAndAdd(key);
            prefixCode = transparentIndex;
          }
          continue;
        }
        final j = i * 3;
        final r = rgb[j];
        final g = rgb[j + 1];
        final b = rgb[j + 2];
        final cands = candidatesFor(r, g, b);
        var continued = false;
        for (var c = 0; c < cands.length; c++) {
          final k = cands[c];
          final existing = dict[(prefixCode << 8) | k];
          if (existing != null) {
            if (k != desired) {
              // Exact budget check — the candidate list may be keyed on a
              // quantized color, which would otherwise let error exceed the
              // budget for pixels near a quantization-cell edge.
              final dr = r - paletteR[k];
              final dg = g - paletteG[k];
              final db = b - paletteB[k];
              if (dr * dr + dg * dg + db * db > budget) continue;
            }
            // First hit wins: cands is sorted by error, so this is the
            // lowest-error index that extends the current phrase.
            prefixCode = existing;
            chosen[i] = k;
            continued = true;
            break;
          }
        }
        if (continued) continue;
        chosen[i] = desired; // no continuation — start the next phrase clean
        emitAndAdd((prefixCode << 8) | desired);
        prefixCode = desired;
      }
      writeCode(prefixCode, codeSize);
      writeCode(eoiCode, codeSize);
    }

    if (bitCount > 0) {
      block[blockLen++] = bitBuffer & 0xff;
      if (blockLen == 255) flushBlock();
    }
    flushBlock();

    out.addByte(0); // block terminator
    return out.toBytes();
  }
}
