import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/gif/gif_lzw.dart';

/// Reference GIF-LZW decoder (standard browser/giflib convention) used to
/// round-trip the encoder under test.
List<int> _decode(Uint8List bytes) {
  final mcs = bytes[0];
  final clear = 1 << mcs;
  final eoi = clear + 1;
  // Reassemble sub-blocks (skip leading mcs byte).
  final data = <int>[];
  var p = 1;
  while (p < bytes.length) {
    final n = bytes[p++];
    if (n == 0) break;
    for (var i = 0; i < n; i++) {
      data.add(bytes[p++]);
    }
  }

  var bitBuf = 0, bitCnt = 0, pos = 0;
  int? read(int size) {
    while (bitCnt < size) {
      if (pos >= data.length) return null;
      bitBuf |= data[pos++] << bitCnt;
      bitCnt += 8;
    }
    final v = bitBuf & ((1 << size) - 1);
    bitBuf >>= size;
    bitCnt -= size;
    return v;
  }

  var codeSize = mcs + 1;
  List<List<int>>? table;
  int? prev;
  final out = <int>[];
  while (true) {
    final code = read(codeSize);
    if (code == null) break;
    if (code == clear) {
      table = [for (var i = 0; i < clear; i++) [i], [], []];
      codeSize = mcs + 1;
      prev = null;
      continue;
    }
    if (code == eoi) break;
    if (table == null) {
      throw StateError('data before clear');
    }
    List<int> entry;
    if (code < table.length && table[code].isNotEmpty || code < clear) {
      entry = table[code];
    } else if (code == table.length) {
      entry = [...table[prev!], table[prev][0]];
    } else {
      throw StateError('bad code $code at ${out.length}');
    }
    out.addAll(entry);
    if (prev != null) {
      table.add([...table[prev], entry[0]]);
      if (table.length == (1 << codeSize) && codeSize < 12) codeSize++;
    }
    prev = code;
  }
  return out;
}

void main() {
  group('GifLzw', () {
    test('emits clear code first', () {
      final b = GifLzw.encode(Uint8List.fromList([0, 0, 0, 0]), 2);
      // ignore: avoid_print
      print('bytes=${b.map((e) => '0x${e.toRadixString(16)}').toList()}');
      expect(b[0], 2, reason: 'min code size byte');
    });

    test('round-trips a simple run', () {
      final input = Uint8List.fromList([0, 0, 0, 1, 1, 2, 3, 3, 3, 3]);
      final encoded = GifLzw.encode(input, 2);
      expect(_decode(encoded), input);
    });

    test('round-trips data that crosses code-size boundaries', () {
      // 600 pseudo-random indices over 16 colors → forces growth past 16,32...
      final input = Uint8List(600);
      var s = 12345;
      for (var i = 0; i < input.length; i++) {
        s = (s * 1103515245 + 12345) & 0x7fffffff;
        input[i] = s % 16;
      }
      final encoded = GifLzw.encode(input, 4);
      expect(_decode(encoded), input);
    });

    test('round-trips a long single-value run (dictionary growth)', () {
      final input = Uint8List(5000); // all zeros
      final encoded = GifLzw.encode(input, 2);
      expect(_decode(encoded), input);
    });

    test('round-trips output spanning many 255-byte sub-blocks', () {
      // High-entropy data over 256 colors: LZW barely compresses, so the
      // encoded stream is far longer than 255 bytes and flushes the reusable
      // block buffer repeatedly. This is the multi-sub-block path that a
      // single-block test cannot exercise.
      final input = Uint8List(20000);
      var s = 987654321;
      for (var i = 0; i < input.length; i++) {
        s = (s * 1103515245 + 12345) & 0x7fffffff;
        input[i] = (s >> 7) & 0xff;
      }
      final encoded = GifLzw.encode(input, 8);
      expect(encoded.length, greaterThan(255 * 3),
          reason: 'must span multiple sub-blocks to be a valid regression test');
      expect(_decode(encoded), input);
    });
  });

  group('GifLzw.encodeLossy', () {
    // 8-entry gray palette (0, 36, ..., 252); index 8 = transparent.
    final pal = Uint8List.fromList([for (var i = 0; i < 8; i++) i * 36]);
    const transparent = 8;

    int nearestGray(int v) {
      var best = 0;
      var bestD = 1 << 30;
      for (var i = 0; i < pal.length; i++) {
        final d = (v - pal[i]) * (v - pal[i]);
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      return best;
    }

    Uint8List candidates(int budget, int r, int g, int b) {
      final ids = <int>[];
      final errs = <int>[];
      for (var i = 0; i < pal.length; i++) {
        final d = (r - pal[i]) * (r - pal[i]) +
            (g - pal[i]) * (g - pal[i]) +
            (b - pal[i]) * (b - pal[i]);
        if (d <= budget) {
          var at = ids.length;
          while (at > 0 && errs[at - 1] > d) {
            at--;
          }
          ids.insert(at, i);
          errs.insert(at, d);
        }
      }
      return ids.isEmpty
          ? Uint8List.fromList([nearestGray(r)])
          : Uint8List.fromList(ids);
    }

    // Pseudo-random gray pixels with a sprinkling of transparent ones.
    final n = 4000;
    final rgb = Uint8List(n * 3);
    final indices = Uint8List(n);
    var s = 24681357;
    for (var i = 0; i < n; i++) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      if (s % 11 == 0) {
        indices[i] = transparent;
      } else {
        final v = (s >> 8) & 0xff;
        rgb[i * 3] = v;
        rgb[i * 3 + 1] = v;
        rgb[i * 3 + 2] = v;
        indices[i] = nearestGray(v);
      }
    }

    test('round-trips to the chosen indices within budget', () {
      const budget = 1600; // lossy 40
      final chosen = Uint8List(n);
      final encoded = GifLzw.encodeLossy(
        indices,
        rgb,
        4,
        transparentIndex: transparent,
        candidatesFor: (r, g, b) => candidates(budget, r, g, b),
        paletteR: pal,
        paletteG: pal,
        paletteB: pal,
        budget: budget,
        chosen: chosen,
      );
      expect(_decode(encoded), chosen,
          reason: 'decoder must reproduce exactly what chosen[] claims');
      for (var i = 0; i < n; i++) {
        if (indices[i] == transparent) {
          expect(chosen[i], transparent,
              reason: 'transparency must never be altered (pixel $i)');
        } else {
          final v = rgb[i * 3];
          final d = 3 * (v - pal[chosen[i]]) * (v - pal[chosen[i]]);
          expect(d, lessThanOrEqualTo(budget),
              reason: 'pixel $i substituted outside the error budget');
        }
      }
    });

    test('zero budget is byte-identical to encode()', () {
      final chosen = Uint8List(n);
      final lossy = GifLzw.encodeLossy(
        indices,
        rgb,
        4,
        transparentIndex: transparent,
        candidatesFor: (r, g, b) => Uint8List.fromList([nearestGray(r)]),
        paletteR: pal,
        paletteG: pal,
        paletteB: pal,
        budget: 0,
        chosen: chosen,
      );
      expect(lossy, GifLzw.encode(indices, 4));
      expect(chosen, indices);
    });
  });
}
