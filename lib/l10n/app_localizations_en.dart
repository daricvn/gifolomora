// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Gifolomora';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get aboutTooltip => 'About';

  @override
  String get exitDialogTitle => 'Exit Gifolomora?';

  @override
  String get exitDialogMessage =>
      'You have unsaved work in progress. Are you sure you want to exit?';

  @override
  String get exitConfirmLabel => 'Exit';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonClearAll => 'Clear all';

  @override
  String get commonDone => 'Done';

  @override
  String get commonReadingFile => 'Reading file…';

  @override
  String get commonProcessing => 'Processing…';

  @override
  String commonProcessingPercent(int percent) {
    return '$percent%  processing…';
  }

  @override
  String get commonRegenerate => 'Regenerate';

  @override
  String get commonGeneratePreview => 'Generate Preview';

  @override
  String get commonExportGif => 'Export GIF';

  @override
  String get commonExportCancelled => 'Export cancelled';

  @override
  String get commonSelectGif => 'Select GIF';

  @override
  String get commonTapToSelectGif => 'Tap to select GIF';

  @override
  String get commonPreview => 'Preview';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonOriginal => 'Original';

  @override
  String get commonOff => 'Off';

  @override
  String get commonOptions => 'Options';

  @override
  String get commonSpeed => 'Speed';

  @override
  String get commonFontSizeLabel => 'Font Size';

  @override
  String commonFileDimensions(int width, int height) {
    return '$width×$height px';
  }

  @override
  String get commonSaveLocationHint =>
      'You\'ll be asked to choose where to save the file.';

  @override
  String get homeSectionCreateOverline => 'Start here';

  @override
  String get homeSectionCreateTitle => 'Create a GIF';

  @override
  String get homeSectionRefineOverline => 'Toolkit';

  @override
  String get homeSectionRefineTitle => 'Edit & optimize';

  @override
  String homeDropUnsupported(String ext) {
    return '.$ext is not supported. Drop a video or GIF.';
  }

  @override
  String get homeDropVideoOrGif => 'Drop video or GIF';

  @override
  String homeVersionBadge(String version) {
    return 'v$version';
  }

  @override
  String get homeDragDropHint => 'Drag & drop a file anywhere to begin';

  @override
  String get homeRecentsOverline => 'History';

  @override
  String get homeRecentsTitle => 'Recent exports';

  @override
  String get homeTimeJustNow => 'just now';

  @override
  String homeTimeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String homeTimeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String homeTimeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get toolVideoStudioLabel => 'Video Studio';

  @override
  String get toolVideoStudioDesc =>
      'Crop, resize & speed — export as video or GIF';

  @override
  String get toolImagesToGifLabel => 'Images → GIF';

  @override
  String get toolImagesToGifDesc =>
      'Stitch a sequence of frames into a smooth loop';

  @override
  String get toolScreenRecordLabel => 'Screen Record';

  @override
  String get toolScreenRecordDesc =>
      'Capture your screen, then edit in Video Studio';

  @override
  String get toolResizeLabel => 'Resize';

  @override
  String get toolResizeDesc => 'Scale to any resolution or preset';

  @override
  String get toolCropLabel => 'Crop';

  @override
  String get toolCropDesc => 'Trim the frame with a draggable rect';

  @override
  String get toolTextOverlayLabel => 'Text Overlay';

  @override
  String get toolTextOverlayDesc => 'Add styled captions to any GIF';

  @override
  String get toolOptimizeLabel => 'Optimize';

  @override
  String get toolOptimizeDesc => 'Compress for the smallest file size';

  @override
  String get toolEffectsLabel => 'Effects';

  @override
  String get toolEffectsDesc => 'Reverse or change playback speed';

  @override
  String get toolToWebmLabel => 'To WebM';

  @override
  String get toolToWebmDesc => 'Convert video or GIF to WebM';

  @override
  String get settingsScreenTitle => 'Settings';

  @override
  String get settingsSoftwarePreviewTitle => 'Software preview rendering';

  @override
  String get settingsSoftwarePreviewDesc =>
      'Fixes rare black flickering in the Video Studio preview on some GPUs. Uses more CPU and caps the preview at 1080p. Exports are never affected. Takes effect the next time you open the editor.';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageDesc => 'Choose the app display language.';

  @override
  String get settingsLanguageSystemDefault => 'System default';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsAboutDesc => 'Version, credits, and licenses';

  @override
  String get cropAppBarTitle => 'Crop GIF';

  @override
  String get cropStepCropArea => 'Crop Area';

  @override
  String get cropStepCropAreaSubtitle =>
      'Drag corners to adjust · Drag inside to move';

  @override
  String cropSizeLabel(int width, int height) {
    return '$width×${height}px';
  }

  @override
  String get cropCouldNotReadDims =>
      'Could not read GIF dimensions — crop unavailable';

  @override
  String get resizeAppBarTitle => 'Resize GIF';

  @override
  String get resizeStepOutputSize => 'Output Size';

  @override
  String get resizePresetsLabel => 'Presets';

  @override
  String get resizeCustomWidth => 'Custom width';

  @override
  String resizeOutputLabel(int width, int height) {
    return 'Output: $width×${height}px';
  }

  @override
  String get effectsAppBarTitle => 'Effects';

  @override
  String get effectsStepEffect => 'Effect';

  @override
  String get effectsModeLabel => 'Mode';

  @override
  String get effectsReverseLabel => 'Reverse';

  @override
  String get effectsReverseSubtitle => 'Play backwards';

  @override
  String get effectsSpeedSubtitle => 'Change tempo';

  @override
  String get effectsSpeedSlower => '0.25×  slower';

  @override
  String get effectsSpeedFaster => '4×  faster';

  @override
  String get effectsSpeedLabelOriginal => '1× (original)';

  @override
  String effectsSpeedLabelSlower(String speed) {
    return '$speed× (slower)';
  }

  @override
  String effectsSpeedLabelFaster(String speed) {
    return '$speed× (faster)';
  }

  @override
  String get optimizeAppBarTitle => 'Optimize GIF';

  @override
  String get optimizeStepCompression => 'Compression';

  @override
  String get optimizeColorsLabel => 'Colors';

  @override
  String get optimizeLossyLabel => 'Lossy';

  @override
  String get optimizeRemoveFrames => 'Remove frames';

  @override
  String get optimizeKeepAll => 'Keep all';

  @override
  String get optimizeFrameDropQuarter => '1 / 4';

  @override
  String get optimizeFrameDropThird => '1 / 3';

  @override
  String get optimizeFrameDropHalf => '1 / 2';

  @override
  String get imagesToGifAppBarTitle => 'Images → GIF';

  @override
  String get imagesStepSelectFrames => 'Select Frames';

  @override
  String get imagesStepSelectFramesSubtitle =>
      'Pick images in the order you want them to play';

  @override
  String get imagesTapToSelectImages => 'Tap to select images';

  @override
  String imagesFrameCountOne(int count) {
    return '$count frame';
  }

  @override
  String imagesFrameCountOther(int count) {
    return '$count frames';
  }

  @override
  String get imagesAddMore => 'Add more';

  @override
  String get imagesFrameRateLabel => 'Frame rate';

  @override
  String get imagesWidthLabel => 'Width';

  @override
  String get imagesStepCaption => 'Caption';

  @override
  String get imagesStepCaptionSubtitle => 'Optional text drawn on every frame';

  @override
  String get imagesStepOptimizeGif => 'Optimise GIF';

  @override
  String get imagesStepOptimizeGifSubtitle => 'Reduce colors and file size';

  @override
  String get imagesNoFontWarning =>
      'No system font found. Text overlay may fail.';

  @override
  String get imagesCaptionHint => 'Leave empty to skip…';

  @override
  String get imagesPositionLabel => 'Position';

  @override
  String get imagesPositionTop => 'Top';

  @override
  String get imagesPositionCenter => 'Center';

  @override
  String get imagesPositionBottom => 'Bottom';

  @override
  String get imagesColorLabel => 'Color';

  @override
  String get imagesColorWhite => 'White';

  @override
  String get imagesColorYellow => 'Yellow';

  @override
  String get imagesColorBlack => 'Black';

  @override
  String get imagesColorRed => 'Red';

  @override
  String get imagesOptimizeToggleLabel => 'Optimise output GIF';

  @override
  String get textOverlayAppBarTitle => 'Text Overlay';

  @override
  String get textOverlayStepEditText => 'Edit Text';

  @override
  String get textOverlayStepEditTextSubtitle =>
      'Drag to position · tap to select';

  @override
  String get textOverlayCannotReadDims => 'Cannot read dimensions';

  @override
  String get textOverlayFontWarning =>
      'No system font found. Text rendering may fail on Generate.';

  @override
  String get textOverlayTextFieldHint => 'Text…';

  @override
  String get textOverlayStyleLabel => 'Style';

  @override
  String get textOverlayFontLabel => 'Font';

  @override
  String get textOverlayFillLabel => 'Fill';

  @override
  String get textOverlayStrokeLabel => 'Stroke';

  @override
  String get textOverlayStrokeWidthLabel => 'Stroke Width';

  @override
  String get textOverlayLayersTitle => 'Text Layers';

  @override
  String get textOverlayNoTextYet => 'No text yet. Tap “Add” to create one.';

  @override
  String get textOverlayAdd => 'Add';

  @override
  String get textOverlayEmptyPlaceholder => '(empty)';

  @override
  String get webmAppBarTitle => 'To WebM';

  @override
  String webmRejectedToastOne(int count) {
    return '$count file skipped — 20 max per batch';
  }

  @override
  String webmRejectedToastOther(int count) {
    return '$count files skipped — 20 max per batch';
  }

  @override
  String get webmSavedToast => 'Saved';

  @override
  String webmExportedToastOne(int count) {
    return 'Exported $count file';
  }

  @override
  String webmExportedToastOther(int count) {
    return 'Exported $count files';
  }

  @override
  String get webmStepSelectFiles => 'Select files';

  @override
  String get webmDropHint => 'Drop or tap to select videos/GIFs (max 20)';

  @override
  String get webmStepConvert => 'Convert';

  @override
  String get webmCodecLabel => 'Codec';

  @override
  String get webmVp9 => 'VP9';

  @override
  String get webmVp9Sub => 'recommended';

  @override
  String get webmAv1 => 'AV1';

  @override
  String get webmAv1Sub => 'smallest · slower';

  @override
  String get webmQualityLabel => 'Quality (CRF)';

  @override
  String get webmSharperBigger => '18  sharper, bigger';

  @override
  String get webmSmallerSofter => '45  smaller, softer';

  @override
  String get webmFast => 'Fast';

  @override
  String get webmBalanced => 'Balanced';

  @override
  String get webmBest => 'Best';

  @override
  String get webmMaxWidth => 'Max width';

  @override
  String get webmKeepTransparency => 'Keep transparency';

  @override
  String get webmProbing => 'probing…';

  @override
  String get webmConversionFailed => 'Conversion failed';

  @override
  String get webmQueued => 'Queued';

  @override
  String get webmConverting => 'Converting';

  @override
  String get webmDone => 'Done';

  @override
  String get webmError => 'Error';

  @override
  String webmConvertingProgress(int done, int total, int percent) {
    return 'Converting $done of $total · $percent%';
  }

  @override
  String get webmConvertButton => 'Convert';

  @override
  String webmExportAll(int count) {
    return 'Export all ($count)';
  }

  @override
  String get webmExportSingle => 'Export WebM';

  @override
  String get recordAppBarTitle => 'Screen Record';

  @override
  String recordFailedToLoad(String error) {
    return 'Failed to load Screen Record: $error';
  }

  @override
  String get recordStepSelectMonitor => 'Select a monitor';

  @override
  String get recordStepRecord => 'Record';

  @override
  String get recordButtonLabel => 'Record';

  @override
  String get recordMaxDuration => 'Max 10:00';

  @override
  String get recordPaused => 'Paused';

  @override
  String get recordRecording => 'Recording';

  @override
  String recordElapsedOfMax(String elapsed) {
    return '$elapsed / 10:00';
  }

  @override
  String get recordResume => 'Resume';

  @override
  String get recordPause => 'Pause';

  @override
  String get recordStop => 'Stop';

  @override
  String get recordHotkeyStart => 'Start';

  @override
  String get recordHotkeyPauseResume => 'Pause / Resume';

  @override
  String get recordAudio => 'Audio';

  @override
  String get recordSystemAudio => 'System audio';

  @override
  String get recordDefaultOutputDevice => 'Default output device';

  @override
  String get recordMicrophone => 'Microphone';

  @override
  String get recordNoMicFound => 'No microphone found';

  @override
  String get recordDefaultInputDevice => 'Default input device';

  @override
  String get recordEditHotkeyTooltip => 'Edit hotkey';

  @override
  String recordPressKeysFor(String label) {
    return 'Press keys for \"$label\"';
  }

  @override
  String get recordSave => 'Save';

  @override
  String get recordHotkeyConflict =>
      'That combo conflicts with another Screen Record hotkey, or is already taken by another app.';

  @override
  String get recordNoDisplays => 'No displays detected';

  @override
  String get recordDisplay => 'Display';

  @override
  String get recordSelectDisplay => 'Select a display';

  @override
  String get recordOutputSize => 'Output size';

  @override
  String get recordStorage => 'Storage';

  @override
  String get recordSaveLocation => 'Save location';

  @override
  String get recordDefaultTempFolder => 'Default (temp folder)';

  @override
  String get recordChoose => 'Choose';

  @override
  String get recordResetToDefault => 'Reset to default';

  @override
  String get recordDeleteTempOnExit => 'Delete temporary video on exit';

  @override
  String get recordChooseFolderDialogTitle =>
      'Choose folder for recorded video';

  @override
  String get sharedFileDropDefaultHint => 'Tap to select files';

  @override
  String get sharedFileDropAnyFile => 'Any file';

  @override
  String get sharedExportAndSave => 'Export & Save';

  @override
  String get sharedPreviewUnavailable => 'Preview unavailable';

  @override
  String get sharedPerFramePalettes => 'Per-frame palettes';

  @override
  String get sharedPerFramePalettesDesc => 'Lossless extra compression, slower';

  @override
  String get studioStartOverLabel => 'Start over';

  @override
  String get studioStartOverDialogTitle => 'Start over?';

  @override
  String get studioStartOverDialogMessage =>
      'This discards the loaded file and all edits.';

  @override
  String get studioRenderingGif => 'Rendering GIF…';

  @override
  String get studioEncoding => 'Encoding…';

  @override
  String get studioTapToSelectVideoOrGif => 'Tap to select a video or GIF';

  @override
  String get studioEditingGif => 'Editing GIF';

  @override
  String get studioEditingVideo => 'Editing video';

  @override
  String get studioAudioLabel => 'audio';

  @override
  String get studioNoAudioLabel => 'no audio';

  @override
  String get studioChangeButton => 'Change';

  @override
  String get studioZoomFit => 'Fit';

  @override
  String get studioZoomFitToWindow => 'Fit to window';

  @override
  String get studioZoomTooltip => 'Zoom';

  @override
  String get studioCompareLabel => 'Compare';

  @override
  String get studioOriginalBadge => 'ORIGINAL';

  @override
  String get studioCutBadge => 'CUT';

  @override
  String studioPositionOfDuration(String position, String duration) {
    return '$position / $duration';
  }

  @override
  String get studioToolTrim => 'Trim';

  @override
  String get studioToolCut => 'Cut';

  @override
  String get studioToolText => 'Text';

  @override
  String get studioToolOptimize => 'Optimise';

  @override
  String get studioToolProps => 'Props';

  @override
  String get studioCropDragHint => 'Drag the handles on the preview to crop';

  @override
  String get studioPlaybackSpeedLabel => 'Playback speed';

  @override
  String get studioTrimInLabel => 'In';

  @override
  String get studioTrimClipLabel => 'Clip';

  @override
  String get studioTrimOutLabel => 'Out';

  @override
  String studioGifCappedFpsHint(int maxFps) {
    return 'GIF will be capped at $maxFps fps for this length.';
  }

  @override
  String get studioCutFromLabel => 'From';

  @override
  String get studioCutToLabel => 'To';

  @override
  String get studioCantAddSegment => 'Can\'t add that segment';

  @override
  String get studioMarkForRemoval => 'Mark for removal';

  @override
  String get studioMarkSpanHint => 'Mark a span to remove it';

  @override
  String studioCutOutputLabel(String duration) {
    return 'Output ≈ $duration';
  }

  @override
  String get studioNoFontWarning =>
      'No system font found. Text may fail to render.';

  @override
  String get studioScaleLabel => 'Scale';

  @override
  String get studioScaleSmaller => '10% smaller';

  @override
  String get studioScaleLarger => '200% larger';

  @override
  String get studioFrameRateLabel => 'Frame rate';

  @override
  String studioCappedFpsHint(int maxFps) {
    return 'Capped at $maxFps fps for this length.';
  }

  @override
  String studioGifCappedWidthHint(int width) {
    return 'GIF capped at ${width}px wide';
  }

  @override
  String get studioIgnoreGifSizeLimit => 'Ignore GIF size limit';

  @override
  String get studioFullSizeSlowWarning => 'Full size may run slow';

  @override
  String get studioMakeGifButton => 'Make GIF';

  @override
  String get studioVideoTooLongTitle => 'Video too long';

  @override
  String get studioGifLimitMessage =>
      'GIF is limited to 40 seconds. Trim the video first for best results, or only the first 40 seconds will be used.';

  @override
  String get studioUseFirst40s => 'Use first 40s';

  @override
  String get studioCouldNotCreateGif => 'Could not create GIF';

  @override
  String get studioWebmConvertHint =>
      'Converts this GIF to a WebM video, then switches to video editing. One-way — there is no going back to the GIF.';

  @override
  String get studioConvertToWebmButton => 'Convert to WebM';

  @override
  String get studioCouldNotConvertWebm => 'Could not convert to WebM';

  @override
  String studioSmoothLoopLabel(int ms) {
    return 'Smooth Loop — crossfade last ${ms}ms into first ${ms}ms';
  }

  @override
  String get studioNounClips => 'Clips';

  @override
  String get studioNounGifs => 'GIFs';

  @override
  String studioLoopMinLengthHint(String noun) {
    return '$noun longer than 3s only.';
  }

  @override
  String get studioCrossfadeTooShort =>
      'Speed/trim leave too little to crossfade — turn Smooth Loop off.';

  @override
  String get studioLoopsSeamlessly =>
      'Loops seamlessly by dissolving the tail into the head.';

  @override
  String get studioCrossfadeDurationLabel => 'Crossfade duration';

  @override
  String get studioVolumeLabel => 'Volume';

  @override
  String get studioNoAudioCaption => 'No audio';

  @override
  String get studioVolumeHint =>
      '100% = original · 0% mutes · up to 200% louder.';

  @override
  String get studioNoAudioTrackHint => 'This video has no audio track.';

  @override
  String get studioFpsLowerHint =>
      'Lowering re-times the GIF; you can\'t add frames back.';

  @override
  String get studioFpsHigherHint => 'Higher = smoother but larger.';

  @override
  String get studioLoopsLabel => 'Loops';

  @override
  String get studioPlaysForever => 'Plays forever';

  @override
  String studioPlaysThenRepeats(int count) {
    return 'Plays then repeats $count×';
  }

  @override
  String get studioBoomerangLabel => 'Boomerang — reverse for a seamless loop';

  @override
  String get studioBackToVideoButton => 'Back to video';

  @override
  String get studioDiscardGifTitle => 'Discard GIF edits?';

  @override
  String get studioDiscardGifMessage =>
      'Going back will discard all changes made to the GIF.';

  @override
  String get studioDiscardButton => 'Discard';

  @override
  String get studioUndoTooltip => 'Undo';

  @override
  String get studioNothingToUndo => 'Nothing to undo';

  @override
  String get studioRedoTooltip => 'Redo';

  @override
  String get studioNothingToRedo => 'Nothing to redo';

  @override
  String get studioApplyButton => 'Apply';

  @override
  String get studioAppliedToPreview => 'Applied to preview';

  @override
  String get studioExportButton => 'Export';

  @override
  String get studioGifSaved => 'GIF saved';

  @override
  String get studioExportVideoTooltip => 'Export Video';

  @override
  String get studioWebmSaved => 'WebM saved';

  @override
  String get studioVideoSaved => 'Video saved';

  @override
  String get studioCutUnavailable => 'Duration unknown — cut unavailable';

  @override
  String get studioTrimUnavailable => 'Duration unknown — trim unavailable';

  @override
  String get studioExportFormatTitle => 'Export Format';

  @override
  String studioFormatOriginalTitle(String ext) {
    return 'Original ($ext)';
  }

  @override
  String get studioFormatOriginalSubtitle =>
      'Save as-is · no re-encode · fastest';

  @override
  String get studioFormatMp4Subtitle =>
      'H.264 · best compatibility · hardware-accelerated';

  @override
  String get studioFormatWebmSubtitle => 'VP9 · smaller files · web-friendly';
}
