# Smooth-Loop GIF Feature — Plan

## Ask
Video Studio, GIF stage, properties dock. New toggle: "Smooth Loop". Crossfade last 1s
into first 1s, then trim first 1s → seamless loop point. Gate: only offered when GIF
> 5s.

## Where it lives (confirmed from code)

- Dock tool = `StudioTool.properties`. Panel = `_PropertiesPanel` in
  [video_studio_screen.dart:2099](lib/features/video_studio/view/video_studio_screen.dart#L2099),
  right next to existing "Boomerang" switch
  ([video_studio_screen.dart:2192-2205](lib/features/video_studio/view/video_studio_screen.dart#L2192-L2205)).
- State field pattern to mirror: `boomerang` — threaded through
  `VideoStudioState` ([video_studio_controller.dart:65-119](lib/features/video_studio/controller/video_studio_controller.dart#L65-L119)),
  `copyWith`, `needsGifEdit`, `isToolEdited`, `setBoomerang()`.
- FFmpeg build: `FfmpegCommand.gifEdit()` ([ffmpeg_command.dart:411-472](lib/core/services/ffmpeg/ffmpeg_command.dart#L411-L472))
  — single filter_complex, palette pass shares frames via `split`. Boomerang already
  branches the graph here (`split→reverse→concat`) — smooth-loop follows same shape.
- Service: `FfmpegService.editGif()` ([ffmpeg_service.dart:473-530](lib/core/services/ffmpeg/ffmpeg_service.dart#L473-L530))
  passes params through, estimates `effectiveTotalMs` for progress.

## Effect, precisely

Crossfade(tail 1s, head 1s) → replaces the tail, then drop original head 1s.
Net: output = `[1s, D)` with its own last 1s overwritten by the dissolve. Output
duration = `D - 1s`. Last frame of output ≈ head's continuation point → wraps into
frame 0 of next loop with no jump cut. Standard "xfade seamless loop" recipe, not
novel — just picking crossfade duration = 1s.

## Filter graph (drop-in replacement for `gifEdit`'s linear `pre`→`split[a][b]` step)

```
[0:v]<pre-chain: crop,fps,scale,setpts-speed,drawtext>,split=3[p0][p1][p2];
[p0]trim=0:1,setpts=PTS-STARTPTS[head];
[p1]trim=<D-1>:<D>,setpts=PTS-STARTPTS[tail];
[p2]trim=1:<D>,setpts=PTS-STARTPTS[mid];
[tail][head]xfade=transition=fade:duration=1:offset=0[blend];
[mid][blend]concat=n=2:v=1[a0];
[a0]split[a][b];
[a]palettegen=stats_mode=diff[p];
[b][p]paletteuse=dither=bayer:bayer_scale=5
```

`D` = post-speed, post-trim duration in seconds — the duration the pre-chain actually
emits. Boomerang's branch and this branch are mutually exclusive (can't both replace
the tail of the graph) → **UI + service must forbid combining smoothLoop + boomerang**.

**CFR requirement (validated concern):** `xfade` requires constant-frame-rate input;
GIFs are VFR (per-frame delays). Today the pre-chain only gets `fps=` when the user
changed fps (`fps: fpsChanged ? s.fps : null` at the call site). With VFR input the
`trim=` boundaries and `xfade` offset drift. **Rule: when `smoothLoop` is true, `fps`
must always be present in the pre-chain.** Controller passes
`fpsChanged ? s.fps : (srcFps?.round() ?? s.fps)`; `gifEdit` asserts `fps != null`
when `smoothLoop`.

**Number formatting:** emit `D`, `D-1` via `toStringAsFixed(3)` (same precision as
existing `-ss`/`-t` emission). Guard in `gifEdit`: require `D > 2 * _crossfadeSec + 0.1`
(mid ≥ 100ms) — throw `ArgumentError` otherwise; mirrors the state-level
`smoothLoopValid` floor so a bad graph can never be emitted even if UI gating slips.

## The one hard part: computing `D` correctly

`gifEdit()` receives `startMs`/`durationMs` as the **trim window on the source**
(applied as `-ss`/`-t` input options, before decode) and `speedFactor` (applied inside
the pre-chain via `setpts`). So:

```
D = (durationMs ?? <caller must supply full source duration>) / 1000 / speedFactor
```

Problem: when the user hasn't trimmed, `durationMs` is today left `null` (ffmpeg just
reads to EOF) — `gifEdit` has no idea how long the source actually is. **Fix:** when
`smoothLoop` is true, the controller must always pass an explicit `durationMs` (default
to `sourceDurationMs` when no trim is set), so `gifEdit` can compute `D` from a value
it already receives — no new parameter needed.

Validated: `_trimParams` (video_studio_controller.dart:793-799) already returns non-null
`durationMs` whenever `hasTrim` (even start-only trims, since `trimDurationMs` derives
from `effectiveTrimEndMs`). So the *only* gap is the no-trim case → at the `editGif`
call, replace `durationMs: t.durationMs` with
`durationMs: s.smoothLoop ? (t.durationMs ?? s.sourceDurationMs) : t.durationMs`.
At GIF stage `sourceDurationMs` **is** the baked GIF's own duration (`sourceInfo` is
re-probed from the baked file at stage switch) — exactly the input `gifEdit` reads.

Second-order risk: speed changes shrink `D` *after* the >5s gate is checked. A 5.5s
GIF at 2× speed → 2.75s post-speed duration, leaving <2s for `mid` after removing 2×1s
— cramped or invalid (`tailStart <= headEnd`). **Gate must be re-evaluated live** against
the *post-speed, post-trim* effective duration (`state.effectiveOutputMs / speedFactor`
equivalent), not just the raw source length, and the switch should disable/turn off
if the user later drags speed/trim into the unsafe zone.

Minimum safe margin: require post-speed duration > `2 × crossfadeSec + 100ms` (i.e.
>2.1s) so `mid` always has ≥100ms of frames — exact `>2s` leaves mid ~0 frames and
`concat` fails on an empty stream. Hard validation floor = 2100ms; `>5s` on raw
source stays the softer "don't even offer it for short clips" UX gate.

## Plan of changes (no code written yet)

1. **`FfmpegCommand.gifEdit()`** — add `bool smoothLoop = false`. When true, replace
   the current `final chain = ...; final body = boomerang ? ... : '$chain,split[a][b]'`
   branch with the trim/xfade/concat graph above, using `durationMs` (required
   non-null/>0 in this mode — throw/assert otherwise, caller's job to guarantee it)
   and `speedFactor` to derive `D = durationMs / 1000 / speedFactor`. Add a top-level
   `const _crossfadeSec = 1.0`. Emit all graph timestamps via `toStringAsFixed(3)`.
   Guards (all `ArgumentError`, enforced at lowest layer per "fix at the shared
   function" convention, even though UI prevents each):
   - `smoothLoop && boomerang` → throw (mutually exclusive graph tails).
   - `smoothLoop && (durationMs == null || durationMs <= 0)` → throw.
   - `smoothLoop && fps == null` → throw (CFR requirement, see above).
   - `smoothLoop && D <= 2 * _crossfadeSec + 0.1` → throw (mid would be empty).

2. **`FfmpegService.editGif()`** — add `bool smoothLoop = false` passthrough
   (ffmpeg_service.dart:473-530). Adjust `effectiveTotalMs` calc: today
   `baseMs = durationMs ?? totalMs`, divided by `speedFactor` only when speed ≠ 1.
   When `smoothLoop`, subtract `1000` from the post-speed value in **both** branches
   (speed changed or not) and clamp ≥ 1: output duration is `D - 1s`, otherwise the
   progress bar overshoots by ~1s of estimated frames. `durationMs` is guaranteed
   non-null here in smoothLoop mode (caller contract from step 4), so `baseMs` never
   falls back to `totalMs` in this mode.

3. **`VideoStudioState`** (video_studio_controller.dart) — add `final bool smoothLoop`
   field (default `false`), thread through `copyWith`. Add:
   - `bool get canSmoothLoop => sourceDurationMs > 5000` (UX gate; at GIF stage
     `sourceDurationMs` is the baked GIF's duration — matches the "GIF > 5s" ask).
   - `bool get smoothLoopValid => effectiveOutputMs / speedFactor > 2100` (hard
     safety floor at the actual post-speed/post-trim duration; `effectiveOutputMs`
     is pre-speed — verified video_studio_controller.dart:185-189 — so divide here).
   - `needsGifEdit` (line 249) → OR in `smoothLoop`.
   - `isToolEdited(StudioTool.properties)` (line 286, GIF branch) → OR in `smoothLoop`.
   - `setSmoothLoop(bool v)`: mirror `setBoomerang` (lines 768-770) exactly — plain
     state set, `error: null`, no history push. If `v`, also set `boomerang: false`
     (mutual excl.). `copyWith` auto-clears `editsApplied` (defaults `false` unless
     explicitly passed, line 318-321) — nothing extra needed.
   - `setBoomerang(bool v)`: if `v`, also set `smoothLoop: false`.

4. **Call + state-carry sites** (verified — earlier line list was wrong; most hits
   are state copies, not calls):
   - **The one real `editGif` call at GIF stage**: `_runGifPipeline`,
     video_studio_controller.dart:969-984 (serves apply, export, and preview-bake —
     all route through it). Add `smoothLoop: s.smoothLoop`; change
     `durationMs: t.durationMs` →
     `s.smoothLoop ? (t.durationMs ?? s.sourceDurationMs) : t.durationMs`; change
     `fps: fpsChanged ? s.fps : null` →
     `fps: fpsChanged ? s.fps : (s.smoothLoop ? (srcFps?.round() ?? s.fps) : null)`
     (CFR requirement).
   - **State-carry sites** — add `smoothLoop:` next to every existing `boomerang:`:
     - line ~884 (video→GIF bake, fresh `VideoStudioState`): carry `s.smoothLoop`? No —
       smoothLoop is a GIF-stage-only toggle set *after* the GIF exists; start `false`.
       (Boomerang is carried because it's settable pre-bake; smoothLoop switch only
       renders in the GIF branch of `_PropertiesPanel`, so there is nothing to carry.)
     - line ~920 (`discardGif`, back to video stage): omit / `false` — same reason.
     - line ~1237 (post-preview-bake state reset, `boomerang: false`): add
       `smoothLoop: false` — **required**, effect is now baked into the frames;
       leaving it `true` re-applies the crossfade-and-trim on the next bake and eats
       another second off the GIF each time.
   - Sanity: grep `boomerang` across `lib/` after wiring to catch any site missed here.

5. **UI** — `_PropertiesPanel`, GIF branch, next to the Boomerang `Switch`:
   ```
   Switch(value: state.smoothLoop, onChanged: state.canSmoothLoop ? ctrl.setSmoothLoop : null)
   'Smooth Loop — crossfade last 1s into first 1s'
   ```
   - Hide or disable (grayed, with helper text "GIFs longer than 5s only") when
     `!state.canSmoothLoop`.
   - If `state.smoothLoop && !state.smoothLoopValid` (user cranked speed after
     enabling) → show inline warning + auto-disable rather than silently emitting
     a broken filter graph.
   - Boomerang switch: disable while `state.smoothLoop` is on (or auto-uncheck via
     the controller's mutual-exclusion setter from point 3).

6. **Tests** (`test/unit/core/services/ffmpeg/ffmpeg_command_test.dart` — exists,
   confirmed) — new cases, mirroring existing boomerang assertions for shape:
   - `smoothLoop: true` (with valid `durationMs`, `fps`) → args contain `trim=`,
     `xfade=transition=fade:duration=1`, `concat=n=2:v=1`, `split=3`.
   - default → none of the above present.
   - trim boundary math: `durationMs: 8000, speedFactor: 2.0` → D=4.0 → expect
     `trim=3.000:4.000` (tail) and `trim=1.000:4.000` (mid).
   - guard throws: `smoothLoop+boomerang`; `smoothLoop` with null/0 `durationMs`;
     null `fps`; `durationMs`/`speedFactor` yielding D ≤ 2.1.
   (state/controller tests — find the existing video_studio test file via glob, don't
   assume the name) — cover `canSmoothLoop`/`smoothLoopValid` gating, mutual-exclusion
   setters both directions, and `needsGifEdit` picking up `smoothLoop`.

## Open risk to verify before implementing (not blocking the plan, but flag)

- Confirm bundled Windows `ffmpeg.exe` (assets/bin/windows/, git-ignored) actually
  has `xfade` compiled in (ffmpeg ≥ 4.3, all standard builds since 2020 include it —
  Android side is `ffmpeg-kit-full-gpl` per
  [ffmpeg_kit_flutter_new pubspec/build.gradle](packages/ffmpeg_kit_flutter_new/android/build.gradle#L54),
  which does). One quick check: `ffmpeg -filters | findstr xfade` against the
  Windows binary in `scripts/setup_windows_dev.ps1`'s target dir.

## Explicitly not doing

- No user-adjustable crossfade duration — spec says fixed 1s, keep it a constant.
- No support combining with `cutSegments`/multi-segment cut (GIF-stage `gifEdit` has
  no cut-segment param today; smooth-loop only interacts with existing trim/speed).
- Not touching `EffectMode` (`reverse`/`speed`) in the separate standalone **Effects**
  tool — that screen is unrelated to Video Studio's GIF stage and out of scope here.
