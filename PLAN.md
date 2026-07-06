# PLAN — Convert to WebM (tool section, single + batch)

New refine tool: pick one or more videos/GIFs (max 20), convert each to WebM, export. Route
`/to-webm`, feature dir `lib/features/webm_converter/`. Plus: Video Studio's Export Video gains
a format choice page (MP4 | WebM) — §8.

---

## 1. Encoder decision (the performance call)

**Chosen: `libvpx-vp9`, single-pass constrained-quality (`-crf N -b:v 0`), with full
multithreading flags. Audio: `libopus`.**

Availability confirmed:
- Windows bundled `assets/bin/windows/ffmpeg.exe` lists `libvpx`, `libvpx-vp9`, `libaom-av1`,
  `vp9_qsv`, `libopus` (checked via `ffmpeg -encoders`).
- Android uses `com.antonkarpenko:ffmpeg-kit-full-gpl:2.1.0`
  (`packages/ffmpeg_kit_flutter_new/android/build.gradle:54`) — full-gpl includes libvpx + libopus.

Rejected alternatives:
| Option | Why not |
|---|---|
| `libaom-av1` as default | 5–20× slower than VP9 at comparable quality; wrong default for a batch tool. Offered as an opt-in codec mode instead (below). |
| `vp9_qsv` | Intel-only, different rate-control knobs, historically flaky quality. Not worth a second code path + fallback loop. |
| NVENC / AMF VP9 | Don't exist — NVIDIA/AMD have no VP9 *encode* hardware. (NVENC AV1 exists but AV1-in-WebM playback support is spottier and the bundled build would still need SW fallback.) |
| VP8 (`libvpx`) | ~2× faster encode but clearly worse size/quality; VP9 with `cpu-used 4–5` closes most of the speed gap. One codec path only. |
| Two-pass VP9 | ~2× wall time for ~10–15% smaller files. Wrong trade for an interactive tool; single-pass CRF. |

Speed flags (this is where VP9 perf actually comes from):
- `-row-mt 1 -tile-columns 2 -threads <Platform.numberOfProcessors>` — without `row-mt`,
  libvpx-vp9 is effectively single-threaded on typical sizes. Threads passed explicitly; don't
  rely on the wrapper default.
- `-deadline good -cpu-used <preset>` — UI "Speed" chips map: Fast = 5, Balanced = 4 (default),
  Best = 2.
- Straight transcode; no filters beyond one `scale` (below).

Filter chain (always present, one `scale` only):
- yuv420p requires even dimensions and GIFs are frequently odd-sized:
  no max-width → `scale=trunc(iw/2)*2:trunc(ih/2)*2`; with max-width →
  `scale='trunc(min(<maxW>,iw)/2)*2':-2` (`-2` keeps height even; the `trunc` guards an odd
  source narrower than the cap — 641 wide under a 1080 cap must still land even; never upscales).
- `-pix_fmt yuv420p` default. GIF input with "keep transparency" ON → `-pix_fmt yuva420p`
  `-auto-alt-ref 0` (VP9 alpha side-band; supported by Chrome/Firefox). Verified on the bundled
  Windows build: encode exits 0 and ffprobe shows `alpha_mode=1`, with or without the flag — the
  flag stays anyway because older libvpx wrappers (Android kit) reject alpha when auto-alt-ref is
  on. Default OFF — opaque is smaller and faster.
- GIF input → `-an`. Video input → `-c:a libopus -b:a 128k` when `MediaInfo.hasAudio`, else
  `-an`. No keep-audio toggle — audio always survives conversion; muting is a Video Studio job
  (volume 0), not a converter knob. (Vorbis rejected — Opus is better at every bitrate and
  present on both backends.)

CRF range: slider 18–45, default 32 (VP9 CRF scale is unlike x264 — 32 is a sane web default).

**AV1 opt-in mode.** Codec chips: **VP9 (recommended)** | **AV1 — smallest file, much slower**.
AV1 stays WebM-contained, swaps only the video encoder block:
`-c:v libaom-av1 -crf <same slider> -b:v 0 -cpu-used {Fast 8 | Balanced 6 | Best 4} -row-mt 1
-tile-columns 2 -threads N`. Audio stays Opus. Constraints:
- **No alpha.** Verified on the bundled build: libaom encode with `yuva420p` input exits 0 but
  silently drops to `yuv420p`, no `alpha_mode` tag. Transparency ON disables the AV1 chip
  (forces VP9).
- **Availability**: Windows bundle confirmed (`-encoders` lists `libaom-av1`). Android
  **unverified and likely absent** — upstream ffmpeg-kit builds have never bundled libaom (dav1d
  is decode-only). Gate the chip behind a one-time `FfmpegService.supportsAv1()` probe: run
  `-hide_banner -encoders` once, grep `libaom-av1`, cache the bool. Chip hidden when false —
  no dead option, no crash on unsupported devices.

Batch concurrency: **sequential, one ffmpeg job at a time.** `row-mt` + tiles already saturate
cores on a single encode; parallel jobs would thrash CPU/RAM and break the existing
one-`_currentJobDir`/one-`cancel()` backend model. This *is* the performant choice, not a
compromise.

GIF looping: gif demuxer `ignore_loop` defaults to true (confirmed via `ffmpeg -h demuxer=gif`
on the bundled build) — decodes one pass, no flag needed; output duration == one loop.

---

## 2. Files

**New**
- `lib/features/webm_converter/controller/webm_converter_controller.dart` — state + queue loop
- `lib/features/webm_converter/view/webm_converter_screen.dart` — screen; batch list rendered
  inline (no separate widgets/ dir — the file rows are ~40 lines of ListView)

**Modified**
- `lib/core/services/ffmpeg/ffmpeg_command.dart` — `static List<String> toWebm({...})`
- `lib/core/services/ffmpeg/ffmpeg_service.dart` — `convertToWebm({...})`
- `lib/core/services/files/export_service.dart` — `saveWebm()` + batch directory export
- `lib/features/home/data/tool_catalog.dart` — refine entry: id `to_webm`, label "To WebM",
  description "Convert video or GIF to WebM", route `/to-webm`, unused accent hue (e.g. `0xFF7C9EFF`)
- `lib/router/app_router.dart` — route with the standard fade+slide transition
- `test/` — arg-builder test for `FfmpegCommand.toWebm` (pure function, no ffmpeg needed)
- §8 (Video Studio format choice) additionally touches:
  `lib/features/video_studio/controller/video_studio_controller.dart` (`exportVideo(format)`),
  `lib/features/video_studio/view/video_studio_screen.dart` (Export → format page),
  `ffmpeg_command.dart` `videoEdit` (webm variant), `ffmpeg_service.dart` `editVideo`

No new packages. No backend interface changes — `FfmpegBackend.run(args, outputPath,
onProgress, totalMs)` already covers this job shape on both platforms (process backend parses
`-progress pipe:1` `out_time_ms`; kit backend uses the statistics callback).

---

## 3. Service layer

```dart
// FfmpegCommand
static List<String> toWebm({
  required String inputPath,
  required String outputPath,
  required int crf,            // 18–45
  required int cpuUsed,        // vp9: 2|4|5 · av1: 4|6|8
  bool av1 = false,            // codec mode: false = libvpx-vp9, true = libaom-av1
  int? maxWidth,               // null = keep size (even-clamped)
  bool keepAudio = false,      // caller passes MediaInfo.hasAudio (no UI toggle)
  bool alpha = false,          // gif transparency → yuva420p (vp9 only; caller forces !av1)
  int threads = 0,             // caller passes Platform.numberOfProcessors
});
```

```dart
// FfmpegService — per-file job dir; does NOT touch _currentJobDir (batch owns
// multiple outputs at once, the single-slot model doesn't fit)
Future<Result<File, FfmpegError>> convertToWebm({
  required File input,
  required int crf,
  required int cpuUsed,
  bool av1 = false,
  int? maxWidth,
  bool keepAudio = false,
  bool alpha = false,
  void Function(FfmpegProgress)? onProgress,
  int? totalMs,                // MediaInfo.durationMs — no speed change, maps 1:1
});
```

Output file lives in its own job dir until export; controller frees each with the existing
`cleanJobAt(file.parent.path)` (`ffmpeg_service.dart`, already used by Video Studio history).

---

## 4. Controller

Follows the `EffectsController` pattern (`AsyncNotifier`, immutable state, `_s` sentinel
`copyWith`) — no shared base class exists, per ARCHITECTURE.md.

```dart
enum WebmItemStatus { queued, converting, done, error }

class WebmItem {          // immutable
  File source; MediaInfo? info; WebmItemStatus status;
  File? output; int? outputBytes;   // + source length → "2.4 MB → 780 KB · −68%" row label
  double progressFraction; String? error;
}

class WebmConverterState {
  List<WebmItem> items;   // ≤ 20, enforced in addFiles() with AppToast on overflow
  int crf; int speedPreset; bool av1; int? maxWidth; bool alpha;
  bool isProcessing; int currentIndex;
  bool get isBatch => items.length > 1;
  double get overallProgress => (doneCount + currentFraction) / items.length;
}
```

No global `error` field — errors are per-item; a service-level failure toasts. No `canceled`
status — cancel puts the in-flight item back to `queued`, so Convert resumes exactly where it
stopped instead of dead-ending the batch.

- `addFiles(List<File>)` — append (drop zone stays visible above the list, so more files can be
  added to an existing batch), cap 20, probe each sequentially (a null `info` renders as
  "probing…"; no per-item probing flag).
- `convertAll()` — for-loop over queued items; per item: mark `converting`, call
  `convertToWebm`, fold into `done` (stat output size) / `error`; check `_cancelRequested`
  between items. An `error` item does not stop the batch — remaining files still convert.
- `cancel()` — set flag + backend `cancel()`; current item → back to `queued`, its job dir
  cleaned; `done` items keep their outputs.
- Changing any option while `done` items exist resets them to `queued` (outputs freed) — the
  options card is live, the button reads "Convert again"; no stale outputs that silently ignore
  the new settings.
- `removeItem(i)` / `clear()` — clean owned job dirs.
- Options (crf/speed/av1/maxWidth/alpha) load from and persist to `shared_preferences` as
  last-used values — a user converting for the same target twice shouldn't re-dial the knobs.
- Export (§5) then `recentsProvider.notifier.add(...)` per saved file (notifier already caps
  at 10).

---

## 5. Export (locked flow preserved)

Everything converts into temp job dirs first; writing to the user's disk is always explicit —
per ARCHITECTURE.md "Export flow (locked decision)".

- **Single file:** `ExportService.saveWebm(tempFile, defaultName: '<basename>.webm')` — same
  shape as the existing `saveVideo()`, extension `webm`.
- **Batch:** one `FilePicker.platform.getDirectoryPath()` dialog, then copy every `done` item
  as `<basename>.webm`, suffixing ` (1)`, ` (2)`… on collision. Twenty sequential `saveFile`
  dialogs is not a UX.
- After each successful copy: `cleanJobAt` that item's dir.

**Android risk (flagged, not solved on paper):** `getDirectoryPath()` may return a SAF tree URI
that plain `File.copy` can't write into. Mitigation order: (1) test on device — many paths
(Downloads, primary storage) work with the `permission_handler` storage grant the app already
holds; (2) if writes fail, fall back to per-file `saveFile` dialogs on Android only (acceptable —
mobile batch sizes are small in practice). Decide from the device test, not speculation.

Disk note: up to 20 converted WebMs sit in temp until export. WebM output is typically smaller
than source; `TempFileService.sweepStale()` already reclaims leftovers on next launch if the
user bails.

---

## 6. Screen

Standard 4-step skeleton:

1. **Pick** — `FileDropZone(allowMultiple: true, allowedExtensions: [mp4, mov, mkv, avi, m4v,
   webm, gif])` — drag-drop already works on Windows via the existing widget.
2. **Options** — glass card: Codec chips (VP9 recommended / AV1 smallest·slower — hidden when
   `supportsAv1()` is false, disabled when transparency ON), Quality `OptionSlider` (CRF 18–45
   shown as value, hint "lower = sharper, bigger"), Speed chips (Fast/Balanced/Best), Max width
   chips (Original/1080/720/480), Keep transparency toggle (shown only when any input is GIF).
   Options are global — apply to every file in the batch — and persist as last-used (§4).
3. **Convert** — file rows: name, resolution/duration from probe, status chip, per-file progress
   bar; `done` rows show the size delta ("2.4 MB → 780 KB · −68%") — the number the user came
   for. Overall `ProgressOverlay` with "Converting 3 of 12 · 41%" + cancel while `isProcessing`.
4. **Export** — single: save dialog; batch: "Export all (N)" → directory picker. Success
   `AppToast` includes total saved ("12 files · 34 MB → 11 MB") + recents.

Preview: tap a `done` row → play via the existing `media_kit` `Video` player (libmpv plays WebM
on both platforms). Skipped: pre-convert quality preview — a converter isn't an editor; the
convert itself is the preview.

---

## 7. Implementation order

1. `FfmpegCommand.toWebm` + arg-builder unit test.
2. `FfmpegService.convertToWebm`.
3. Controller + state.
4. Screen; router + tool catalog entries.
5. `ExportService` additions (single, then batch dir copy).
6. Gate: `flutter analyze` → 0 issues; `flutter test`.
7. Manual verify (Windows dev run): odd-dimension mp4 (e.g. 641×359) → even clamp; audio-less
   video (must emit `-an`, not fail); audio video → Opus track present; GIF with transparency,
   alpha ON vs OFF; batch of 3 mixed video+GIF — size deltas shown per row; cancel mid-batch →
   in-flight item back to queued, Convert resumes, no orphan temp dirs; option change after done
   → items reset to queued; 21-file pick → cap toast; AV1 smoke encode (plays in Chrome, smaller
   than VP9 at same CRF); AV1 chip disables when transparency ON; options + studio format
   restored after app restart. Android device: single convert + batch export directory write
   (the §5 risk) + `supportsAv1()` probe result (expect false — chip hidden).

---

## 8. Video Studio — Export Video format choice (MP4 | WebM)

Today `exportVideo()` (`video_studio_controller.dart:1206`) is a direct button → h264/mp4 via
`editVideo`'s encoder-candidate fallback, hardcoded `studio.mp4`. Change: Export Video opens a
**format page** first, then runs the chosen pipeline.

**UI.** Export button pushes a compact glass page (standard fade+slide route, matching the rest
of the app) with two selectable format cards:
- **MP4** — "H.264 · best compatibility · hardware-accelerated" (default)
- **WebM** — "VP9 · smaller files · web-friendly"
plus the existing "you'll be asked where to save" note and an Export button. The chosen format
persists as last-used (`shared_preferences`) and preselects next time — repeat exporters skip a
tap. No quality knobs here — WebM uses the §1 defaults (CRF 32, cpu-used 4, Opus 128k); a quality
slider can join the page later if asked. GIF-stage export is untouched.

**Pipeline.**
- `FfmpegCommand.videoEdit` gains a format switch: same filter graph (crop · scale · speed ·
  text · cuts · volume), but WebM swaps the encoder block to the §1 VP9 arg set (shared private
  helper with `toWebm` — one place owns the VP9 flags) + `-c:a libopus -b:a 128k`, output
  extension `webm`.
- `FfmpegService.editVideo` gains `format`; for WebM the encoder-candidate loop runs with the
  single candidate `libvpx-vp9` (no hw VP9 encoders exist — §1). H.264 path unchanged.
- **No stream-copy / fast path for WebM.** WebM only admits VP8/VP9/AV1, so an h264 source can
  never be remuxed — every WebM export encodes:
  - `editsApplied` fast path (baked mp4, nothing pending): MP4 → `saveVideo` as-is (unchanged);
    WebM → `convertToWebm(baked)` (§3) then save. One encode, from the already-baked frames.
  - No-edits + WebM likewise routes through `convertToWebm` — it's exactly the converter-tool op.
- Save: WebM uses `ExportService.saveWebm` (§5), default name `studio.webm`; MP4 keeps
  `saveVideo` / `studio.mp4`.

**Order.** Implement after §7 steps 1–2 (reuses `toWebm` args + `convertToWebm`); before or
parallel with the converter screen — no dependency between the two UIs.

**Verify.** MP4 export unchanged (regression check); WebM export with edits pending (single
encode, plays in Chrome); WebM export right after Apply (routes via `convertToWebm`, no
double-encode of pending layers); volume ≠ 1.0 survives into Opus track.

---

## 9. Open questions (defaults chosen, revisit only if wrong)

- CRF default 32 — not wired to `SettingsService` (its fps/width/colors/lossy defaults are
  GIF-shaped). Add a settings slider later only if users ask.
- `webm` accepted as *input* (re-encode to smaller/newer settings) — trivially free since ffmpeg
  demuxes it; drop from the extension list if product-wise confusing.
- Studio format page (§8) stays MP4 | WebM(VP9) — AV1 lives in the converter tool; add a third
  card there only if asked.
