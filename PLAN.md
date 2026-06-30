# PLAN — Video Studio "Cut" tool

Add a **Cut** tool to Video Studio (video stage only). Trim defines the kept
window `[trimStartMs, effectiveTrimEndMs]`. Cut removes one or more **segments**
inside that window. Non-destructive until Apply/Export, same as every other
studio tool.

Scope: **video stage only** (Cut depends on the Trim window; GIF stage has no
Trim). Do not add Cut to the GIF tool selector.

---

## 1. Data model

`lib/features/video_studio/controller/video_studio_controller.dart`

Add a record typedef (value equality + sorting free — no boilerplate class):

```dart
/// A span (absolute source ms) marked for removal. start < end.
typedef CutSegment = ({int startMs, int endMs});
```

`VideoStudioState`:
- New field `final List<CutSegment> cutSegments` (default `const []`), wired into
  the constructor and `copyWith` (plain `List?` param, `?? this.cutSegments`).
- Getters:
  - `bool get hasCut => cutSegments.isNotEmpty;`
  - `int get cutDurationMs` = sum of `(s.endMs - s.startMs)`, but only the part
    overlapping the trim window (clamp each to `[trimStartMs, effectiveTrimEndMs]`).
  - `int get cutOutputMs => (trimDurationMs - cutDurationMs).clamp(0, trimDurationMs);`
  - `List<CutSegment> get keepRanges` — the trim window minus all cut segments,
    sorted, used by the ffmpeg layer. (Complement of `cutSegments` within
    `[trimStartMs, effectiveTrimEndMs]`.)
- Fold Cut into the "needs encode" gate: the real `applyVideoEdits` guard is
  `if (!s.hasEdits && !s.hasTrim && !s.hasText && !s.hasVolumeChange)` (4 terms,
  not 2) — add `&& !s.hasCut`. Same treatment for any `exportVideo` no-op path.

---

## 2. Controller methods

Mirror the Trim methods’ style (read `state.valueOrNull`, write `AsyncData`).

- `bool addCutSegment(int startMs, int endMs)`:
  1. Clamp `[startMs,endMs]` to `[trimStartMs, effectiveTrimEndMs]`. If `end-start <= 0` → return false.
  2. Reject overlap: false if any existing seg has `startMs < e.endMs && endMs > e.startMs`.
  3. Reject if it would leave < 1s kept: `trimDurationMs - cutDurationMs - (end-start) < 1000` → false.
  4. Insert, then sort list by `startMs`. Set state. Return true.
- `void removeCutSegment(CutSegment seg)` — remove matching, keep sorted.
- `void resetCut()` — `cutSegments: const []`.
- **Trim reconciliation:** in `setTrimStart` / `setTrimEnd` / `resetTrim`, **clip**
  each segment to the new `[trimStartMs, effectiveTrimEndMs]`:
  `start = max(start, trimStart)`, `end = min(end, trimEnd)`. Drop a segment only
  if clipping empties it (`end - start <= 0`, fully outside the new window).
  Clipping preserves the still-valid part of a partially-overlapping segment.
  Extract `List<CutSegment> _clipSegments(List<CutSegment>, int lo, int hi)`,
  call from all three setters. Result stays sorted (clipping preserves order).

Return `bool` from `addCutSegment` so the UI can toast the rejection reason
(overlap / too short). Caller maps false → generic "Can't add that segment".

---

## 3. FFmpeg layer

Thread **`keepRanges`** (absolute ms, the trim-window complement of the cuts) to
both video bakes — one name end to end, no `cutSegments` param in the ffmpeg
layer (controller already has the `keepRanges` getter). Empty/single-range ⇒
existing behavior unchanged (no regressions).

`ffmpeg_service.dart`: add `List<CutSegment>? keepRanges` param to `editVideo`
and `bakeVideoToGif`; forward to the command builders. Controller passes
`s.hasCut ? s.keepRanges : null` at **all three** call sites: `applyVideoEdits`,
`exportVideo`, **and `makeGif`** (video→gif bake — easy to miss, cut is dropped
if skipped).

**Cuts own the window — suppress `-ss`/`-t`.** `keepRanges` already encodes the
trim window (complement computed within `[trimStartMs, effectiveTrimEndMs]`), so
when `hasCut` the controller/service must pass `startMs: null, durationMs: null`.
Passing both → double-trim. Only the keepRanges path carries the window in that
case.

**`editVideo` no-op guard (service):** the existing `isNoOp` check
([ffmpeg_service.dart](lib/core/services/ffmpeg/ffmpeg_service.dart) ~L336) does
NOT include cuts. A cut-only edit would hit `videoStreamCopy` and silently drop
the cut. Extend `isNoOp` with `&& (keepRanges == null || keepRanges.length < 2)`.

**Progress duration:** with cuts the output length is `cutOutputMs`, not
`durationMs`. Service passes `cutOutputMs` as `effectiveTotalMs` when `hasCut`
(else the progress bar overshoots). Controller hands `cutOutputMs` to the
service alongside `keepRanges`.

`ffmpeg_command.dart` — `videoEdit` and `videoEditToGif`:
- Add `List<CutSegment>? keepRanges` param.
- **When `keepRanges` has ≥2 ranges (i.e. cuts exist):** do NOT emit
  `-ss`/`-t` (filtergraph owns the window). Prepend to the video filter chain:
  ```
  select='between(t,a1,b1)+between(t,a2,b2)+...',setpts=N/FRAME_RATE/TB
  ```
  (seconds, 3-dp). Audio (`videoEdit`, when `hasAudio`): prepend
  `aselect='between(t,...)+...',asetpts=N/SR/TB` **first** in the audio chain,
  before any `atempo`/`volume`. For `videoEditToGif`, put `select=...,setpts=...`
  first in `pre` (before `crop`/`fps`).
- When `keepRanges` null/empty/single-range → unchanged (`-ss`/`-t` path stays).
  Single range = a cut touching a trim edge → expressible as a plain trim.
- Helper: `static String _selectKeepExpr(List<CutSegment> ranges)` building the
  `between(t,...)` sum; reuse for select + aselect.

> Rationale: multi-segment removal can't be expressed by `-ss`/`-t`; `select`
> keeps the complement of the cuts and `setpts=N/FRAME_RATE/TB` restitches the
> kept frames into a continuous timeline.
>
> **VFR caveat:** plain `videoEdit` (mp4) has no `fps` filter, so `FRAME_RATE`
> resolves to the input rate. Constant-frame-rate sources restitch cleanly; a
> variable-frame-rate source may glitch at cut seams. Acceptable for v1.

---

## 4. UI — tool + panel

`video_studio_screen.dart`:

- `StudioTool` enum (in controller): add `cut`.
- `_ToolSelector.tools`: add `if (!isGif) (StudioTool.cut, Icons.cut_rounded, 'Cut', false, null)`.
  **Fix the width divisor**: replace hardcoded `/ 7` with `/ tools.length`
  (selector now has a variable count per stage: video+cut = 7, gif = 6). Note
  it's inside a `Wrap`, so the divisor sets item width only, not column count.
- `_ToolPanel` switch: `case StudioTool.cut: return _CutPanel(...)`.

`_CutPanel` (new, in this file, modeled on `_TrimPanel`):
- A **pending range** held in local state (`_CutPanel` becomes Stateful):
  `pendingStartMs`, `pendingEndMs`, seeded to a ~1s span at `positionMs` clamped
  into the trim window.
- A `CutSegmentSlider` (new widget, §5) to pick the pending range + seek.
- "Mark for removal" button → `ctrl.addCutSegment(pendingStart, pendingEnd)`;
  toast on false.
- Segment list (sorted): one row per `CutSegment` showing `start–end` via `_fmtMs`,
  with a delete (×) button → `ctrl.removeCutSegment(seg)`. Reuse `_TrimChip`
  styling / glass row look. Empty state: hint text "Mark a span to remove it".
- Footer line: "Output ≈ {_fmtMs(state.cutOutputMs)}".

---

## 5. Cut slider widget

`lib/features/video_studio/widgets/cut_segment_slider.dart` — adapt
`_TrimPainter`/`VideoTrimSlider`:
- Track spans full `totalMs`; the **trim window** `[trimStartMs, trimEndMs]` drawn
  as the active region (outside dimmed, non-interactive).
- Existing `cutSegments` painted as **red filled blocks**.
- Pending range = two brackets, draggable, **clamped to the trim window**; plus
  the seek thumb (drives preview, same as trim slider).
- Callbacks: `onPendingChanged(start,end)`, `onSeek(ms)`.

---

## 6. Preview red overlay

`video_studio_screen.dart`, inside the preview `Stack` (after `VideoPreview`,
before the controls overlay), video stage only:

```dart
if (!state.isGif &&
    state.cutSegments.any((s) => _positionMs >= s.startMs && _positionMs < s.endMs))
  const Positioned.fill(
    child: IgnorePointer(
      child: ColoredBox(color: Color(0x80FF0000)), // red @ 50%
    ),
  ),
```

`_positionMs` already updates via `onPositionChanged`. Overlay is a **hint only** —
preview does not skip the cut span (real skip happens at Apply/Export). No new
state needed.

---

## 7. Edge rules (enforce in controller, assert in tests)

- Cut range must lie within `[trimStartMs, effectiveTrimEndMs]` (clamped).
- No two segments overlap (touching at a boundary, `end==start`, is allowed).
- Kept output must stay ≥ 1000 ms after every add.
- List always sorted by `startMs`.
- Shrinking Trim clips overlapping segments to the new window; drops only those
  fully outside.
- Empty `cutSegments` ⇒ ffmpeg args identical to today (no select filter).

---

## 8. Tests

Add to `test/features/video_studio/` (fakes capture ffmpeg args via
`FakeFfmpegBackend`; `editVideo`/`bakeVideoToGif` hit real super → backend).

`video_studio_cut_test.dart` (controller/state):
1. add segment within window → `cutSegments.length==1`, sorted.
2. add overlapping segment → returns false, list unchanged.
3. boundary-touching segments (e.g. 1000–2000 then 2000–3000) → both accepted.
4. add segment leaving < 1s kept → false.
5. segments out of order added → list sorted by `startMs`.
6. `removeCutSegment` removes the right one.
7. `cutOutputMs == trimDurationMs - sum(cuts)`.
8. shrink Trim window:
   - segment fully outside new window → dropped.
   - segment straddling the new `trimStart` (or `trimEnd`) → clipped to the
     window edge, kept (assert new `start`/`end`).
   - segment fully inside → untouched.
9. `keepRanges` = correct complement (e.g. window 0–10000, cut 3000–5000 →
   `[(0,3000),(5000,10000)]`).

`ffmpeg_command_test.dart` (extend existing):
10. `videoEdit` with keepRanges → `-vf` contains `select='between(t,...)...'` +
    `setpts=N/FRAME_RATE/TB`, and **no** `-ss`/`-t`.
11. with `hasAudio` → `-af` contains `aselect`/`asetpts`.
12. `videoEditToGif` with keepRanges → `select` is first in the filtergraph,
    before `fps`.
13. empty/null keepRanges → args byte-identical to current (regression guard).

`video_studio_apply_video_test.dart` (extend):
14. apply with a cut present → not a no-op (encode runs), `editsApplied` set.

Optional widget test (`video_studio_cut_widget_test.dart`): pump screen with a
cut segment, drive `_positionMs` into it, assert the red `ColoredBox(0x80FF0000)`
is present; outside the span it's absent.

---

## Out of scope (v1)
- Cut on GIF stage.
- Skipping cut spans during live preview playback (overlay hint only).
