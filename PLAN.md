# Performance Tackle Plan

> Scope: performance scan of Gifolomora, navigated via `ARCHITECTURE.md`.
> Status of evidence: all findings are from **reading source** (file:line cited).
> Runtime impact is **inferred**, not yet profiled on a device. Confirm each with
> a Flutter DevTools timeline / `--profile` run before and after the fix.

---

## Findings (ranked by impact)

### P1 — Too many `BackdropFilter` blur surfaces, some inside scrolling lists
**Confirmed.** `ARCHITECTURE.md:186-189` sets the rules: cap ~3–6 blur surfaces
per screen, and **never** put `BackdropFilter` inside a scrolling list.

Both are violated:
- `GlassContainer` is the sole `BackdropFilter` primitive
  ([glass_container.dart:41](lib/core/widgets/glass/glass_container.dart#L41)),
  and `GlassCard` wraps it ([glass_card.dart:25](lib/core/widgets/glass/glass_card.dart#L25)).
- Home screen stacks well past the cap: `GlassAppBar` + up to 10 recents cards +
  2 featured cards + 5 tool cards.
- **Scrolling-list violation:** `RecentsStrip` builds a `GlassContainer` per card
  inside a horizontal `ListView.builder`
  ([recents_strip.dart:39-46](lib/features/home/widgets/recents_strip.dart#L39-L46),
  [recents_strip.dart:75](lib/features/home/widgets/recents_strip.dart#L75)).
  The two home `SliverGrid`s of `GlassCard`s scroll too
  ([home_screen.dart:111-161](lib/features/home/view/home_screen.dart#L111-L161)).
- 62 `GlassContainer`/`GlassCard`/`BackdropFilter` references across 21 files;
  several tool screens use 5–6 each (crop / text_overlay = 6).
- Compounder: the animated blob background (P4) keeps the backdrop layer dirty,
  so every blur **re-runs the gaussian every frame**, not just on scroll.
  Desktop sigma is 18 ([glass_container.dart:30](lib/core/widgets/glass/glass_container.dart#L30)).

**Fix:**
1. Add a no-blur mode to the glass primitive — a flat fill that keeps the same
   tint + border + sheen + shadow but drops `BackdropFilter` (e.g.
   `GlassContainer(blur: 0)` → plain `DecoratedBox`, or a `GlassCard.flat`).
2. Use the flat variant for every surface inside a scroll view: recents cards,
   featured grid, refine grid. Reserve true blur for the app bar + at most one
   or two non-scrolling hero surfaces per screen.
3. Audit each tool screen against the 3–6 cap; convert overflow to flat.

**Verify:** DevTools raster-thread timeline on Home — scroll + idle. Expect the
per-frame `BackdropFilter` raster cost to drop sharply.

---

### P2 — `GifOptimizer` exhaustive nearest-color search dominates CPU
**Confirmed (CPU hot path).**
[gif_optimizer.dart:114-143](lib/core/services/gif_optimizer.dart#L114-L143).
Per pixel, on a cache miss, it linearly scans all palette colors
(`O(pixels × realColors)`, up to ~254). The RGB memo cache
([gif_optimizer.dart:113](lib/core/services/gif_optimizer.dart#L113)) keys on the
**exact** 24-bit color, so it only helps flat-color GIFs. A video-sourced or
photographic GIF has near-unique colors per pixel → cache rarely hits → cost
approaches `pixels × 254`. For 480×270×60 frames ≈ 7.8M px × 254 ≈ 2e9 ops.

**Fix (pick one, lowest risk first):**
1. **Quantize the cache key** — mask low bits per channel (e.g. `>>3`, 5-bit →
   32768 buckets). Near-guaranteed cache hits, turns per-pixel cost ~constant.
   Tiny quality cost (sub-perceptual at 5-bit). Smallest diff.
2. Build a fixed 3D RGB→index LUT (e.g. 32³) once after palette training; pixel
   lookup becomes a single array index. More memory (~32KB), zero per-pixel scan.
3. Spatial structure (k-d tree) over the palette — more code, only worth it if
   1/2 prove insufficient.

Runs in an isolate already ([gif_optimizer.dart:42](lib/core/services/gif_optimizer.dart#L42)),
so this is wall-clock latency of the optimize step, not UI jank — but it's the
single biggest CPU cost in the app.

**Verify:** time `optimize()` on a real photographic GIF before/after; assert
output bytes within a small tolerance (quality regression guard).

---

### P3 — `GifOptimizer` palette training: full stacked image + full-pixel walk
**Confirmed (memory + CPU).**
[gif_optimizer.dart:205-226](lib/core/services/gif_optimizer.dart#L205-L226).
`_buildGlobalPalette` allocates one `img.Image` of `W × (H×N)` then
`toUint8List()` copies it again, and `OctreeQuantizer` walks every pixel of every
frame. For 480×270×60 that's ~23MB stacked + a 23MB copy, on top of `framesRgb`
(23MB), `framesIndex` (7.8MB), `framesTransparent` (7.8MB), and the decoder's
RGBA frames (~31MB) — peak ~100MB+ in the isolate.

**Fix:** train the quantizer on a **subsample** — every Nth pixel (stride) and/or
every Nth frame. A global palette is statistically stable under subsampling; this
cuts training memory and time several-fold. Avoid materializing the stacked
image; feed strided samples directly.

**Verify:** compare palette + output size on a few GIFs; expect ~equal size,
lower peak RSS, faster training.

---

### P4 — `GradientScaffold` blobs repaint full-screen every frame, forever
**Confirmed.** [gradient_scaffold.dart:34-37](lib/core/widgets/common/gradient_scaffold.dart#L34-L37)
runs an 8s `AnimationController.repeat(reverse: true)` that never stops; the
`AnimatedBuilder` rebuilds `_Blobs` (three large `RadialGradient` circles) every
tick ([gradient_scaffold.dart:65-74](lib/core/widgets/common/gradient_scaffold.dart#L65-L74)).
This runs on **every screen, while idle**, and is what keeps every `BackdropFilter`
above it dirty (see P1) — constant GPU + battery drain even when nothing moves.

**Fix:**
1. Biggest win is P1: once scrolling surfaces stop blurring, the blob repaint no
   longer forces N gaussian recomputes.
2. Wrap the blob layer in its own `RepaintBoundary` so it doesn't dirty siblings.
3. Consider pausing/slowing the controller when the route is not visible, or
   lowering the effective tick rate; the motion is subtle enough that ~30fps or a
   paused-when-occluded state is unnoticeable.

**Verify:** GPU/raster timeline at idle on Home before/after.

---

## Non-issues checked (ruled out)
- Tool controllers (`images_to_gif`, etc.) keep heavy work off the main thread —
  all encode/optimize goes through `FfmpegService` / the optimizer isolate
  ([images_to_gif_controller.dart:202-260](lib/features/images_to_gif/controller/images_to_gif_controller.dart#L202-L260)). OK.
- `GifLzw.encode` is a single linear pass with a dict map — fine
  ([gif_lzw.dart](lib/core/services/gif/gif_lzw.dart)).
- `VideoPreview` crop painter repaints only on crop/size change
  ([video_preview.dart:380-381](lib/features/_shared/widgets/video_preview.dart#L380-L381)). OK.
- `MediaPreview` uses `Image.file` with `gaplessPlayback` — fine.

---

## Suggested order
1. **P1** — highest runtime win, contained change (one primitive + swap call sites).
2. **P4** — small, compounds with P1.
3. **P2** — biggest CPU win for the optimize feature, isolated to one function.
4. **P3** — memory + latency polish on the same file.

## Caveat (most-likely-wrong claim)
Runtime magnitudes are **inferred from code shape, not profiled.** The P1 ordering
assumes blur-over-animated-backdrop is the dominant cost; confirm with a DevTools
raster timeline before committing to the refactor scope.
