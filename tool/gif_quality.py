# Quality validation for GifOptimizer bench output (see tool/gif_bench.dart).
#
# Pillow is giflib-based like browsers/Skia, so unlike package:image's lenient
# decoder it both catches corrupt LZW streams and composites disposal=1
# correctly. Compares each source frame against the optimized frame displayed
# at the same playback time (robust to merged/dropped frames).
#
# Usage: python tool/gif_quality.py <benchDir>
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageSequence


def timeline(path):
    """[(start_ms, end_ms, rgb_array)] of displayed frames."""
    im = Image.open(path)
    frames = []
    t = 0
    for frame in ImageSequence.Iterator(im):
        dur = frame.info.get("duration", 100) or 100
        frames.append((t, t + dur, np.asarray(frame.convert("RGB"), dtype=np.int32)))
        t += dur
    return frames


def displayed_at(frames, ms):
    for start, end, arr in frames:
        if start <= ms < end:
            return arr
    return frames[-1][2]


def compare(src_path, out_path):
    src = timeline(src_path)
    out = timeline(out_path)
    max_sq = 0.0
    sum_sq = 0.0
    n = 0
    for start, end, s in src:
        o = displayed_at(out, (start + end) / 2)
        if o.shape != s.shape:
            return None  # dimension mismatch — report as failure
        d = ((s - o) ** 2).sum(axis=2)  # per-pixel squared RGB distance
        max_sq = max(max_sq, float(d.max()))
        sum_sq += float(d.sum())
        n += d.size
    rmse = (sum_sq / n) ** 0.5
    return max_sq, rmse


def main():
    bench = Path(sys.argv[1] if len(sys.argv) > 1 else "bench_out")
    failures = 0
    for src_path in sorted(bench.glob("*_src.gif")):
        name = src_path.name[: -len("_src.gif")]
        for out_path in sorted(bench.glob(f"{name}_l*.gif")):
            try:
                result = compare(src_path, out_path)
            except Exception as e:  # noqa: BLE001 — decode failure IS the signal
                print(f"{out_path.name}: DECODE FAILED: {e}")
                failures += 1
                continue
            if result is None:
                print(f"{out_path.name}: SIZE MISMATCH")
                failures += 1
                continue
            max_sq, rmse = result
            print(f"{out_path.name}: max_sqdist={max_sq:.0f} rmse={rmse:.2f}")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
