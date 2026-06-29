# PLAN — Text Overlay (full rewrite)

Standalone tool at `/text-overlay`. Multi-text, list-driven, free drag positioning, per-text format panel. Model + render layer built host-agnostic so they later drop into Video Studio / Images→GIF unchanged.

Current impl = single-text, 3 position presets, preset colors. **Replace entirely.**

**Two tracks, decoupled:** Backend (model + ffmpeg + controller + fonts) and UI (screen + widgets). The **Contract** section below is the only thing they share — UI talks to the controller provider + state shape and never touches ffmpeg. Tracks can be implemented by different models in parallel; build Backend first only because UI needs the contract to compile.

---

## Decisions (locked)

1. Bundle fonts in `assets/fonts/` (Roboto regular/bold/italic) for deterministic cross-platform styling.
2. Preview is **approximate** (Flutter Text). Real output via Generate.
3. Color = **full color-wheel picker** (HSV). Store hex `RRGGBB`.
4. No resize handles — font-size slider covers sizing.
5. Up to **20** text items.

---

## Scope

- Input: GIF (same pick flow). Source GIF = preview background.
- Add / remove / select / edit text items.
- List panel: every item; tap → select + edit.
- Selected item on preview: draggable, bounding box, format toolbar floats above box.
- Per-item format: font style, font size, font color, stroke color, stroke width.
- Output: bake all drawtext → GIF (palettegen/paletteuse) → export (existing flow).

---

# CONTRACT (shared — both tracks depend on this)

Implemented by Backend, consumed by UI. UI imports only `model/text_item.dart` + `controller/text_overlay_controller.dart`.

### Model — `lib/features/text_overlay/model/text_item.dart`

```dart
enum TextStyleKind { regular, bold, italic, boldItalic }

class TextItem {            // immutable + copyWith
  final String id;         // unique
  final String text;
  final double nx, ny;     // normalized TOP-LEFT of box, 0..1 of media W/H
  final int    fontSize;   // media px
  final String fontColor;  // hex 'RRGGBB'
  final String strokeColor;// hex 'RRGGBB'
  final int    strokeWidth;// 0..12 px (0 = none)
  final TextStyleKind style;
}
```

Coord helpers (pure, static — single source of truth, used by UI for drag + by Backend for ffmpeg):
- `nxFromLocal(localX, scale, mw) => (localX/scale)/mw`  (same for y)
- `leftFromNx(nx, mw, scale) => nx*mw*scale`             (same for top)
- `previewFontSize(fontSize, scale) => fontSize*scale`
- `pxX(nx, mw) => (nx*mw).round()`                       (same for y)
- clamp nx,ny to [0,1) on write.

`scale = displayW / mediaW` (uniform letterbox fit).

### State — `TextOverlayState`

```
File? inputFile; MediaInfo? mediaInfo; bool isProbing;
List<TextItem> items; String? selectedId;
File? outputGif; FfmpegProgress? progress;
bool isProcessing; String? error;
```
Getters: `hasInput`, `selected` (TextItem?), `canAdd` (items.length<20), `fontReady` (bool), `canGenerate` (hasInput && items.isNotEmpty && every item.text.trim non-empty && fontReady).

### Controller API — `textOverlayControllerProvider` (`AsyncNotifierProvider<TextOverlayController, TextOverlayState>`)

```
Future<void> setInput(File)
void addText()                 // guard canAdd; default item centered (nx,ny=.4), text 'Text', selects it; invalidate outputGif
void removeText(String id)     // clears selection if removed
void select(String? id)
void updateSelected({ String? text, TextStyleKind? style, int? fontSize,
                      String? fontColor, String? strokeColor, int? strokeWidth })
void moveSelected(double nx, double ny)   // clamps
Future<void> generate()        // builds output gif
Future<bool> exportGif()
Future<void> cancel()
void clear()
```
Any item mutation invalidates `outputGif` + clears `error`.

UI needs **nothing else** from backend. Everything below CONTRACT is Backend-internal.

---

# BACKEND TRACK

### B1 — Model
`text_item.dart`: TextItem, TextStyleKind, copyWith, coord helpers (above). **Unit test**: mapping round-trip (local→nx→px), clamp bounds.

### B2 — Fonts
- Add `assets/fonts/Roboto-Regular.ttf`, `-Bold.ttf`, `-Italic.ttf`, `-BoldItalic.ttf`; register in `pubspec.yaml` assets.
- `FontResolver`: add `fileForStyle(TextStyleKind) -> String` resolving bundled asset path on disk. Bundled assets need a real filesystem path for ffmpeg `fontfile` — copy from rootBundle to a temp/app-support dir once, cache path (assets aren't direct FS paths on Android). Fallback to existing system-font `resolve()` if copy fails.
- `fontReady` in state = at least regular resolvable.

### B3 — FFmpeg
`FfmpegCommand` — replace `textOverlay`/`_textPosition` with:
```
textOverlayMulti({ inputPath, outputPath, List<DrawTextSpec> specs })
DrawTextSpec { text, fontFile, x, y, fontSize, fontColorHex, strokeColorHex, strokeWidth }  // x,y abs px
```
Filter graph: one `drawtext` per spec, chained, then split→palettegen→paletteuse:
```
drawtext=fontfile='F':text='T':x=X:y=Y:fontsize=S:fontcolor=0xRRGGBB:borderw=W:bordercolor=0xRRGGBB, ... ,
split[a][b];[a]palettegen[p];[b][p]paletteuse
```
- strokeWidth 0 → emit `borderw=0` (omit bordercolor).
- Reuse `_escapeText`, `_escapeFontPath`. Hex → `0x` prefix.
- Empty specs → guard.

`FfmpegService`: rewrite `textOverlay` → `textOverlayMulti({ input, List<TextItem> items, MediaInfo mediaInfo, onProgress, totalMs })`; maps items→specs (`pxX/pxY` + `fileForStyle`). Keep job-dir / Result / progress pattern.

### B4 — Controller
Rewrite `TextOverlayController` + `TextOverlayState` per CONTRACT. **Unit test**: add caps at 20, removeText clears selection, updateSelected patches correct item + invalidates outputGif, canGenerate logic.

### B5 — verify
`flutter analyze` 0, `flutter test`. Update `ARCHITECTURE.md` GIF-source command list (`textOverlay`→`textOverlayMulti`).

---

# UI TRACK

Depends only on CONTRACT. Rewrite `text_overlay_screen.dart`. Keep step skeleton; Preview becomes interactive editor. Reuse glass widgets, `GradientScaffold`, `GlassAppBar`, `ExportBottomSheet`, `FileDropZone`, `MediaPreview`, and existing sub-widgets (`_SectionHeader`, `_FileInfoCard`, `_ProgressCard`, `_GenerateButton`, `_ErrorCard`, `_ExportBar`).

### U1 — Step 1 Pick
Unchanged: `FileDropZone` / `_FileInfoCard`; if `!state.fontReady` show font warning card.

### U2 — Editor (after input)
- `_PreviewEditor`: `LayoutBuilder` → displayW; derive displayH + `scale` from `mediaInfo` aspect (letterbox). `Stack`:
  - bg `Image.file(inputFile)` sized display W×H (Flutter renders animated GIF).
  - per item `Positioned(left/top from leftFromNx/topFromNy)` → `GestureDetector(onTap: select, onPanUpdate → moveSelected(nxFromLocal,...))` rendering Flutter `Text`:
    - fontSize = `previewFontSize`, fontWeight/fontStyle from `style`, color = fontColor.
    - stroke: layered `Text` w/ `foreground = Paint()..style=stroke..strokeWidth..color=strokeColor` under fill Text.
  - selected item: bounding box `Border` + `_FormatToolbar` positioned above box (flip below if near top edge).
  - hit-test: last item in list = topmost wins; list panel = reliable select.
- `_FormatToolbar` (glass, compact, floats above selected box):
  - text field bound to `selected.text` → `updateSelected(text:)`.
  - style toggle Aa / **B** / *I* → `updateSelected(style:)`.
  - font-size mini-slider/stepper (12–96) → `updateSelected(fontSize:)`.
  - font color button → opens color-wheel sheet → `updateSelected(fontColor:)`.
  - stroke color button → wheel sheet → `updateSelected(strokeColor:)`.
  - stroke width slider 0–12 → `updateSelected(strokeWidth:)`.
- `_TextListPanel` (glass): header "+ Add" (disabled when !canAdd) + `n/20`; `ListView` rows = text preview + selected highlight + delete icon. Tap row → `select(id)`.

### U3 — Color-wheel picker
Add dep `flutter_colorpicker` (HSV/wheel). Wrap in a glass bottom sheet; return hex `RRGGBB`. (ponytail: building an HSV wheel by hand is non-trivial; use the package. If dep undesired, swap to a swatch grid — but decision #3 = wheel.)

### U4 — Step 3 Generate/Preview
`_GenerateButton` (enabled = `canGenerate`) → `generate()`. On `outputGif` show `MediaPreview(outputGif)` + Regenerate. `_ProgressCard` while processing, `_ErrorCard` on error. Export bar unchanged.

### U5 — verify
`flutter analyze` 0; manual: add/select/drag/style/color/stroke/delete, generate, export.

---

## Build order
Backend B1→B5 first (unblocks compile + contract), then UI U1→U5. Can hand UI to a separate model once CONTRACT types/provider exist (stub controller methods compile-ready early if parallelizing).

## Notes
- Reusability: model + coord helpers + `textOverlayMulti` are screen-independent. Video Studio embed later = feed its `mediaInfo` + reuse `_PreviewEditor` over its preview; no backend change.
- WYSIWYG drift accepted (decision #2): Flutter Text ≠ exact drawtext metrics; Generate shows truth.
