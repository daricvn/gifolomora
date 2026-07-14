// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Gifolomora';

  @override
  String get settingsTooltip => 'Einstellungen';

  @override
  String get aboutTooltip => 'Über';

  @override
  String get exitDialogTitle => 'Gifolomora beenden?';

  @override
  String get exitDialogMessage =>
      'Du hast ungespeicherte Änderungen. Möchtest du wirklich beenden?';

  @override
  String get exitConfirmLabel => 'Beenden';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonClear => 'Löschen';

  @override
  String get commonClearAll => 'Alles löschen';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonReadingFile => 'Datei wird gelesen…';

  @override
  String get commonProcessing => 'Wird verarbeitet…';

  @override
  String commonProcessingPercent(int percent) {
    return '$percent% verarbeitet…';
  }

  @override
  String get commonRegenerate => 'Neu generieren';

  @override
  String get commonGeneratePreview => 'Vorschau generieren';

  @override
  String get commonExportGif => 'GIF exportieren';

  @override
  String get commonExportCancelled => 'Export abgebrochen';

  @override
  String get commonSelectGif => 'GIF auswählen';

  @override
  String get commonTapToSelectGif => 'Tippen, um GIF auszuwählen';

  @override
  String get commonPreview => 'Vorschau';

  @override
  String get commonReset => 'Zurücksetzen';

  @override
  String get commonOriginal => 'Original';

  @override
  String get commonOff => 'Aus';

  @override
  String get commonOptions => 'Optionen';

  @override
  String get commonSpeed => 'Geschwindigkeit';

  @override
  String get commonFontSizeLabel => 'Schriftgröße';

  @override
  String commonFileDimensions(int width, int height) {
    return '$width×$height px';
  }

  @override
  String get commonSaveLocationHint =>
      'Du wirst gefragt, wo die Datei gespeichert werden soll.';

  @override
  String get homeSectionCreateOverline => 'Hier beginnen';

  @override
  String get homeSectionCreateTitle => 'GIF erstellen';

  @override
  String get homeSectionRefineOverline => 'Toolkit';

  @override
  String get homeSectionRefineTitle => 'Bearbeiten & optimieren';

  @override
  String homeDropUnsupported(String ext) {
    return '.$ext wird nicht unterstützt. Ziehe ein Video oder GIF hierher.';
  }

  @override
  String get homeDropVideoOrGif => 'Video oder GIF hierher ziehen';

  @override
  String homeVersionBadge(String version) {
    return 'v$version';
  }

  @override
  String get homeDragDropHint =>
      'Datei an eine beliebige Stelle ziehen, um zu beginnen';

  @override
  String get homeRecentsOverline => 'Verlauf';

  @override
  String get homeRecentsTitle => 'Letzte Exporte';

  @override
  String get homeTimeJustNow => 'gerade eben';

  @override
  String homeTimeMinutesAgo(int minutes) {
    return 'vor $minutes Min.';
  }

  @override
  String homeTimeHoursAgo(int hours) {
    return 'vor $hours Std.';
  }

  @override
  String homeTimeDaysAgo(int days) {
    return 'vor $days Tg.';
  }

  @override
  String get toolVideoStudioLabel => 'Video Studio';

  @override
  String get toolVideoStudioDesc =>
      'Zuschneiden, skalieren & Geschwindigkeit — Export als Video oder GIF';

  @override
  String get toolImagesToGifLabel => 'Bilder → GIF';

  @override
  String get toolImagesToGifDesc =>
      'Eine Sequenz von Bildern zu einer flüssigen Schleife zusammenfügen';

  @override
  String get toolScreenRecordLabel => 'Bildschirmaufnahme';

  @override
  String get toolScreenRecordDesc =>
      'Bildschirm aufnehmen, dann im Video Studio bearbeiten';

  @override
  String get toolResizeLabel => 'Größe ändern';

  @override
  String get toolResizeDesc =>
      'Auf eine beliebige Auflösung oder Voreinstellung skalieren';

  @override
  String get toolCropLabel => 'Zuschneiden';

  @override
  String get toolCropDesc => 'Rahmen mit einem ziehbaren Rechteck zuschneiden';

  @override
  String get toolTextOverlayLabel => 'Textüberlagerung';

  @override
  String get toolTextOverlayDesc =>
      'Stilisierte Untertitel zu jedem GIF hinzufügen';

  @override
  String get toolOptimizeLabel => 'Optimieren';

  @override
  String get toolOptimizeDesc => 'Für die kleinste Dateigröße komprimieren';

  @override
  String get toolEffectsLabel => 'Effekte';

  @override
  String get toolEffectsDesc =>
      'Rückwärts abspielen oder Wiedergabegeschwindigkeit ändern';

  @override
  String get toolToWebmLabel => 'Zu WebM';

  @override
  String get toolToWebmDesc => 'Video oder GIF in WebM umwandeln';

  @override
  String get settingsScreenTitle => 'Einstellungen';

  @override
  String get settingsSoftwarePreviewTitle => 'Software-Vorschau-Rendering';

  @override
  String get settingsSoftwarePreviewDesc =>
      'Behebt seltenes schwarzes Flackern in der Video Studio-Vorschau auf einigen GPUs. Verbraucht mehr CPU und begrenzt die Vorschau auf 1080p. Exporte sind nie betroffen. Wird beim nächsten Öffnen des Editors wirksam.';

  @override
  String get settingsLanguageTitle => 'Sprache';

  @override
  String get settingsLanguageDesc => 'Wähle die Anzeigesprache der App.';

  @override
  String get settingsLanguageSystemDefault => 'Systemstandard';

  @override
  String get settingsSectionGeneral => 'Allgemein';

  @override
  String get settingsAboutDesc => 'Version, Danksagungen und Lizenzen';

  @override
  String get cropAppBarTitle => 'GIF zuschneiden';

  @override
  String get cropStepCropArea => 'Zuschneidebereich';

  @override
  String get cropStepCropAreaSubtitle =>
      'Ecken zum Anpassen ziehen · Innen zum Verschieben ziehen';

  @override
  String cropSizeLabel(int width, int height) {
    return '$width×${height}px';
  }

  @override
  String get cropCouldNotReadDims =>
      'GIF-Abmessungen konnten nicht gelesen werden — Zuschneiden nicht verfügbar';

  @override
  String get resizeAppBarTitle => 'GIF-Größe ändern';

  @override
  String get resizeStepOutputSize => 'Ausgabegröße';

  @override
  String get resizePresetsLabel => 'Voreinstellungen';

  @override
  String get resizeCustomWidth => 'Benutzerdefinierte Breite';

  @override
  String resizeOutputLabel(int width, int height) {
    return 'Ausgabe: $width×${height}px';
  }

  @override
  String get effectsAppBarTitle => 'Effekte';

  @override
  String get effectsStepEffect => 'Effekt';

  @override
  String get effectsModeLabel => 'Modus';

  @override
  String get effectsReverseLabel => 'Rückwärts';

  @override
  String get effectsReverseSubtitle => 'Rückwärts abspielen';

  @override
  String get effectsSpeedSubtitle => 'Tempo ändern';

  @override
  String get effectsSpeedSlower => '0,25× langsamer';

  @override
  String get effectsSpeedFaster => '4× schneller';

  @override
  String get effectsSpeedLabelOriginal => '1× (Original)';

  @override
  String effectsSpeedLabelSlower(String speed) {
    return '$speed× (langsamer)';
  }

  @override
  String effectsSpeedLabelFaster(String speed) {
    return '$speed× (schneller)';
  }

  @override
  String get optimizeAppBarTitle => 'GIF optimieren';

  @override
  String get optimizeStepCompression => 'Komprimierung';

  @override
  String get optimizeColorsLabel => 'Farben';

  @override
  String get optimizeLossyLabel => 'Verlustbehaftet';

  @override
  String get optimizeRemoveFrames => 'Frames entfernen';

  @override
  String get optimizeKeepAll => 'Alle behalten';

  @override
  String get optimizeFrameDropQuarter => '1 / 4';

  @override
  String get optimizeFrameDropThird => '1 / 3';

  @override
  String get optimizeFrameDropHalf => '1 / 2';

  @override
  String get imagesToGifAppBarTitle => 'Bilder → GIF';

  @override
  String get imagesStepSelectFrames => 'Frames auswählen';

  @override
  String get imagesStepSelectFramesSubtitle =>
      'Wähle die Bilder in der Reihenfolge aus, in der sie abgespielt werden sollen';

  @override
  String get imagesTapToSelectImages => 'Tippen, um Bilder auszuwählen';

  @override
  String imagesFrameCountOne(int count) {
    return '$count Frame';
  }

  @override
  String imagesFrameCountOther(int count) {
    return '$count Frames';
  }

  @override
  String get imagesAddMore => 'Mehr hinzufügen';

  @override
  String get imagesFrameRateLabel => 'Bildrate';

  @override
  String get imagesWidthLabel => 'Breite';

  @override
  String get imagesStepCaption => 'Untertitel';

  @override
  String get imagesStepCaptionSubtitle => 'Optionaler Text auf jedem Frame';

  @override
  String get imagesStepOptimizeGif => 'GIF optimieren';

  @override
  String get imagesStepOptimizeGifSubtitle =>
      'Farben und Dateigröße reduzieren';

  @override
  String get imagesNoFontWarning =>
      'Keine Systemschriftart gefunden. Textüberlagerung könnte fehlschlagen.';

  @override
  String get imagesCaptionHint => 'Leer lassen zum Überspringen…';

  @override
  String get imagesPositionLabel => 'Position';

  @override
  String get imagesPositionTop => 'Oben';

  @override
  String get imagesPositionCenter => 'Mitte';

  @override
  String get imagesPositionBottom => 'Unten';

  @override
  String get imagesColorLabel => 'Farbe';

  @override
  String get imagesColorWhite => 'Weiß';

  @override
  String get imagesColorYellow => 'Gelb';

  @override
  String get imagesColorBlack => 'Schwarz';

  @override
  String get imagesColorRed => 'Rot';

  @override
  String get imagesOptimizeToggleLabel => 'Ausgabe-GIF optimieren';

  @override
  String get textOverlayAppBarTitle => 'Textüberlagerung';

  @override
  String get textOverlayStepEditText => 'Text bearbeiten';

  @override
  String get textOverlayStepEditTextSubtitle =>
      'Zum Positionieren ziehen · zum Auswählen tippen';

  @override
  String get textOverlayCannotReadDims =>
      'Abmessungen können nicht gelesen werden';

  @override
  String get textOverlayFontWarning =>
      'Keine Systemschriftart gefunden. Text-Rendering könnte beim Generieren fehlschlagen.';

  @override
  String get textOverlayTextFieldHint => 'Text…';

  @override
  String get textOverlayStyleLabel => 'Stil';

  @override
  String get textOverlayFontLabel => 'Schriftart';

  @override
  String get textOverlayFillLabel => 'Füllung';

  @override
  String get textOverlayStrokeLabel => 'Kontur';

  @override
  String get textOverlayStrokeWidthLabel => 'Konturbreite';

  @override
  String get textOverlayLayersTitle => 'Textebenen';

  @override
  String get textOverlayNoTextYet =>
      'Noch kein Text. Tippe auf „Hinzufügen“, um einen zu erstellen.';

  @override
  String get textOverlayAdd => 'Hinzufügen';

  @override
  String get textOverlayEmptyPlaceholder => '(leer)';

  @override
  String get webmAppBarTitle => 'Zu WebM';

  @override
  String webmRejectedToastOne(int count) {
    return '$count Datei übersprungen — max. 20 pro Batch';
  }

  @override
  String webmRejectedToastOther(int count) {
    return '$count Dateien übersprungen — max. 20 pro Batch';
  }

  @override
  String get webmSavedToast => 'Gespeichert';

  @override
  String webmExportedToastOne(int count) {
    return '$count Datei exportiert';
  }

  @override
  String webmExportedToastOther(int count) {
    return '$count Dateien exportiert';
  }

  @override
  String get webmStepSelectFiles => 'Dateien auswählen';

  @override
  String get webmDropHint => 'Videos/GIFs ziehen oder tippen (max. 20)';

  @override
  String get webmStepConvert => 'Konvertieren';

  @override
  String get webmCodecLabel => 'Codec';

  @override
  String get webmVp9 => 'VP9';

  @override
  String get webmVp9Sub => 'empfohlen';

  @override
  String get webmAv1 => 'AV1';

  @override
  String get webmAv1Sub => 'kleinste · langsamer';

  @override
  String get webmQualityLabel => 'Qualität (CRF)';

  @override
  String get webmSharperBigger => '18 schärfer, größer';

  @override
  String get webmSmallerSofter => '45 kleiner, weicher';

  @override
  String get webmFast => 'Schnell';

  @override
  String get webmBalanced => 'Ausgewogen';

  @override
  String get webmBest => 'Beste';

  @override
  String get webmMaxWidth => 'Max. Breite';

  @override
  String get webmKeepTransparency => 'Transparenz beibehalten';

  @override
  String get webmProbing => 'Prüfung…';

  @override
  String get webmConversionFailed => 'Konvertierung fehlgeschlagen';

  @override
  String get webmQueued => 'Warteschlange';

  @override
  String get webmConverting => 'Wird konvertiert';

  @override
  String get webmDone => 'Fertig';

  @override
  String get webmError => 'Fehler';

  @override
  String webmConvertingProgress(int done, int total, int percent) {
    return 'Konvertiere $done von $total · $percent%';
  }

  @override
  String get webmConvertButton => 'Konvertieren';

  @override
  String webmExportAll(int count) {
    return 'Alle exportieren ($count)';
  }

  @override
  String get webmExportSingle => 'WebM exportieren';

  @override
  String get recordAppBarTitle => 'Bildschirmaufnahme';

  @override
  String recordFailedToLoad(String error) {
    return 'Bildschirmaufnahme konnte nicht geladen werden: $error';
  }

  @override
  String get recordStepSelectMonitor => 'Monitor auswählen';

  @override
  String get recordStepRecord => 'Aufnehmen';

  @override
  String get recordButtonLabel => 'Aufnehmen';

  @override
  String get recordMaxDuration => 'Max. 10:00';

  @override
  String get recordPaused => 'Pausiert';

  @override
  String get recordRecording => 'Aufnahme läuft';

  @override
  String recordElapsedOfMax(String elapsed) {
    return '$elapsed / 10:00';
  }

  @override
  String get recordResume => 'Fortsetzen';

  @override
  String get recordPause => 'Pause';

  @override
  String get recordStop => 'Stopp';

  @override
  String get recordHotkeyStart => 'Start';

  @override
  String get recordHotkeyPauseResume => 'Pause / Fortsetzen';

  @override
  String get recordAudio => 'Audio';

  @override
  String get recordSystemAudio => 'System-Audio';

  @override
  String get recordDefaultOutputDevice => 'Standard-Ausgabegerät';

  @override
  String get recordMicrophone => 'Mikrofon';

  @override
  String get recordNoMicFound => 'Kein Mikrofon gefunden';

  @override
  String get recordDefaultInputDevice => 'Standard-Eingabegerät';

  @override
  String get recordEditHotkeyTooltip => 'Hotkey bearbeiten';

  @override
  String recordPressKeysFor(String label) {
    return 'Tasten drücken für „$label“';
  }

  @override
  String get recordSave => 'Speichern';

  @override
  String get recordHotkeyConflict =>
      'Diese Kombination steht im Konflikt mit einem anderen Aufnahme-Hotkey oder wird bereits von einer anderen App verwendet.';

  @override
  String get recordNoDisplays => 'Keine Displays erkannt';

  @override
  String get recordDisplay => 'Display';

  @override
  String get recordSelectDisplay => 'Display auswählen';

  @override
  String get recordOutputSize => 'Ausgabegröße';

  @override
  String get recordStorage => 'Speicher';

  @override
  String get recordSaveLocation => 'Speicherort';

  @override
  String get recordDefaultTempFolder => 'Standard (Temp-Ordner)';

  @override
  String get recordChoose => 'Wählen';

  @override
  String get recordResetToDefault => 'Auf Standard zurücksetzen';

  @override
  String get recordDeleteTempOnExit => 'Temporäres Video beim Beenden löschen';

  @override
  String get recordChooseFolderDialogTitle =>
      'Ordner für aufgenommenes Video wählen';

  @override
  String get sharedFileDropDefaultHint => 'Tippen, um Dateien auszuwählen';

  @override
  String get sharedFileDropAnyFile => 'Beliebige Datei';

  @override
  String get sharedExportAndSave => 'Exportieren & Speichern';

  @override
  String get sharedPreviewUnavailable => 'Vorschau nicht verfügbar';

  @override
  String get sharedPerFramePalettes => 'Paletten pro Frame';

  @override
  String get sharedPerFramePalettesDesc =>
      'Verlustfreie Zusatzkomprimierung, langsamer';

  @override
  String get studioStartOverLabel => 'Neu beginnen';

  @override
  String get studioStartOverDialogTitle => 'Neu beginnen?';

  @override
  String get studioStartOverDialogMessage =>
      'Dadurch werden die geladene Datei und alle Bearbeitungen verworfen.';

  @override
  String get studioRenderingGif => 'GIF wird gerendert…';

  @override
  String get studioEncoding => 'Codierung läuft…';

  @override
  String get studioTapToSelectVideoOrGif =>
      'Tippen, um Video oder GIF auszuwählen';

  @override
  String get studioEditingGif => 'GIF bearbeiten';

  @override
  String get studioEditingVideo => 'Video bearbeiten';

  @override
  String get studioAudioLabel => 'Audio';

  @override
  String get studioNoAudioLabel => 'kein Audio';

  @override
  String get studioChangeButton => 'Ändern';

  @override
  String get studioZoomFit => 'Anpassen';

  @override
  String get studioZoomFitToWindow => 'An das Fenster anpassen';

  @override
  String get studioZoomTooltip => 'Zoom';

  @override
  String get studioCompareLabel => 'Vergleichen';

  @override
  String get studioOriginalBadge => 'ORIGINAL';

  @override
  String get studioCutBadge => 'SCHNITT';

  @override
  String studioPositionOfDuration(String position, String duration) {
    return '$position / $duration';
  }

  @override
  String get studioToolTrim => 'Zuschneiden';

  @override
  String get studioToolCut => 'Schneiden';

  @override
  String get studioToolText => 'Text';

  @override
  String get studioToolOptimize => 'Optimieren';

  @override
  String get studioToolProps => 'Eigenschaften';

  @override
  String get studioCropDragHint =>
      'Ziehe die Griffe in der Vorschau zum Zuschneiden';

  @override
  String get studioPlaybackSpeedLabel => 'Wiedergabegeschwindigkeit';

  @override
  String get studioTrimInLabel => 'Anfang';

  @override
  String get studioTrimClipLabel => 'Clip';

  @override
  String get studioTrimOutLabel => 'Ende';

  @override
  String studioGifCappedFpsHint(int maxFps) {
    return 'Das GIF wird für diese Länge auf $maxFps fps begrenzt.';
  }

  @override
  String get studioCutFromLabel => 'Von';

  @override
  String get studioCutToLabel => 'Bis';

  @override
  String get studioCantAddSegment =>
      'Dieses Segment kann nicht hinzugefügt werden';

  @override
  String get studioMarkForRemoval => 'Zum Entfernen markieren';

  @override
  String get studioMarkSpanHint => 'Markiere einen Bereich zum Entfernen';

  @override
  String studioCutOutputLabel(String duration) {
    return 'Ausgabe ≈ $duration';
  }

  @override
  String get studioNoFontWarning =>
      'Keine Systemschriftart gefunden. Text-Rendering könnte fehlschlagen.';

  @override
  String get studioScaleLabel => 'Skalierung';

  @override
  String get studioScaleSmaller => '10% kleiner';

  @override
  String get studioScaleLarger => '200% größer';

  @override
  String get studioFrameRateLabel => 'Bildrate';

  @override
  String studioCappedFpsHint(int maxFps) {
    return 'Auf $maxFps fps begrenzt für diese Länge.';
  }

  @override
  String studioGifCappedWidthHint(int width) {
    return 'GIF auf ${width}px Breite begrenzt';
  }

  @override
  String get studioIgnoreGifSizeLimit => 'GIF-Größenbeschränkung ignorieren';

  @override
  String get studioFullSizeSlowWarning =>
      'Volle Größe läuft möglicherweise langsam';

  @override
  String get studioMakeGifButton => 'GIF erstellen';

  @override
  String get studioVideoTooLongTitle => 'Video zu lang';

  @override
  String get studioGifLimitMessage =>
      'GIFs sind auf 40 Sekunden begrenzt. Schneide das Video für beste Ergebnisse zuerst zu, sonst werden nur die ersten 40 Sekunden verwendet.';

  @override
  String get studioUseFirst40s => 'Erste 40 Sek. verwenden';

  @override
  String get studioCouldNotCreateGif => 'GIF konnte nicht erstellt werden';

  @override
  String get studioWebmConvertHint =>
      'Konvertiert dieses GIF in ein WebM-Video und wechselt dann zur Videobearbeitung. Einweg — kein Zurück zum GIF möglich.';

  @override
  String get studioConvertToWebmButton => 'In WebM umwandeln';

  @override
  String get studioCouldNotConvertWebm =>
      'Konnte nicht in WebM umgewandelt werden';

  @override
  String studioSmoothLoopLabel(int ms) {
    return 'Flüssige Schleife — überblende letzte ${ms}ms in erste ${ms}ms';
  }

  @override
  String get studioNounClips => 'Clips';

  @override
  String get studioNounGifs => 'GIFs';

  @override
  String studioLoopMinLengthHint(String noun) {
    return 'Nur $noun länger als 3 Sek.';
  }

  @override
  String get studioCrossfadeTooShort =>
      'Geschwindigkeit/Schnitt lassen zu wenig Platz für die Überblendung — schalte Flüssige Schleife aus.';

  @override
  String get studioLoopsSeamlessly =>
      'Läuft nahtlos in einer Schleife, indem das Ende in den Anfang übergeht.';

  @override
  String get studioCrossfadeDurationLabel => 'Dauer der Überblendung';

  @override
  String get studioVolumeLabel => 'Lautstärke';

  @override
  String get studioNoAudioCaption => 'Kein Audio';

  @override
  String get studioVolumeHint =>
      '100% = Original · 0% stumm · bis zu 200% lauter.';

  @override
  String get studioNoAudioTrackHint => 'Dieses Video hat keine Audiospur.';

  @override
  String get studioFpsLowerHint =>
      'Absenken passt das Timing des GIFs an; Frames können nicht wieder hinzugefügt werden.';

  @override
  String get studioFpsHigherHint => 'Höher = flüssiger, aber größer.';

  @override
  String get studioLoopsLabel => 'Schleifen';

  @override
  String get studioPlaysForever => 'Endlos abspielen';

  @override
  String studioPlaysThenRepeats(int count) {
    return 'Abspielen, dann $count× wiederholen';
  }

  @override
  String get studioBoomerangLabel =>
      'Boomerang — rückwärts für eine nahtlose Schleife';

  @override
  String get studioBackToVideoButton => 'Zurück zum Video';

  @override
  String get studioDiscardGifTitle => 'GIF-Änderungen verwerfen?';

  @override
  String get studioDiscardGifMessage =>
      'Durch Zurückgehen werden alle am GIF vorgenommenen Änderungen verworfen.';

  @override
  String get studioDiscardButton => 'Verwerfen';

  @override
  String get studioUndoTooltip => 'Rückgängig machen';

  @override
  String get studioNothingToUndo => 'Nichts zum Rückgängigmachen';

  @override
  String get studioRedoTooltip => 'Wiederholen';

  @override
  String get studioNothingToRedo => 'Nichts zum Wiederholen';

  @override
  String get studioApplyButton => 'Anwenden';

  @override
  String get studioAppliedToPreview => 'Auf Vorschau angewendet';

  @override
  String get studioExportButton => 'Exportieren';

  @override
  String get studioGifSaved => 'GIF gespeichert';

  @override
  String get studioExportVideoTooltip => 'Video exportieren';

  @override
  String get studioWebmSaved => 'WebM gespeichert';

  @override
  String get studioVideoSaved => 'Video gespeichert';

  @override
  String get studioCutUnavailable =>
      'Dauer unbekannt — Schneiden nicht verfügbar';

  @override
  String get studioTrimUnavailable =>
      'Dauer unbekannt — Zuschneiden nicht verfügbar';

  @override
  String get studioExportFormatTitle => 'Exportformat';

  @override
  String studioFormatOriginalTitle(String ext) {
    return 'Original ($ext)';
  }

  @override
  String get studioFormatOriginalSubtitle =>
      'Unverändert speichern · keine Neucodierung · am schnellsten';

  @override
  String get studioFormatMp4Subtitle =>
      'H.264 · beste Kompatibilität · hardwarebeschleunigt';

  @override
  String get studioFormatWebmSubtitle =>
      'VP9 · kleinere Dateien · webfreundlich';
}
