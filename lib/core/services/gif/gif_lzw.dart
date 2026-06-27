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
}
