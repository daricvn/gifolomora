// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Gifolomora';

  @override
  String get settingsTooltip => 'Paramètres';

  @override
  String get aboutTooltip => 'À propos';

  @override
  String get exitDialogTitle => 'Quitter Gifolomora ?';

  @override
  String get exitDialogMessage =>
      'Vous avez un travail non sauvegardé en cours. Êtes-vous sûr de vouloir quitter ?';

  @override
  String get exitConfirmLabel => 'Quitter';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonClearAll => 'Tout effacer';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonReadingFile => 'Lecture du fichier…';

  @override
  String get commonProcessing => 'Traitement…';

  @override
  String commonProcessingPercent(int percent) {
    return '$percent% en cours…';
  }

  @override
  String get commonRegenerate => 'Régénérer';

  @override
  String get commonGeneratePreview => 'Générer l\'aperçu';

  @override
  String get commonExportGif => 'Exporter le GIF';

  @override
  String get commonExportCancelled => 'Exportation annulée';

  @override
  String get commonSelectGif => 'Sélectionner un GIF';

  @override
  String get commonTapToSelectGif => 'Appuyez pour sélectionner un GIF';

  @override
  String get commonPreview => 'Aperçu';

  @override
  String get commonReset => 'Réinitialiser';

  @override
  String get commonOriginal => 'Original';

  @override
  String get commonOff => 'Désactivé';

  @override
  String get commonOptions => 'Options';

  @override
  String get commonSpeed => 'Vitesse';

  @override
  String get commonFontSizeLabel => 'Taille de police';

  @override
  String commonFileDimensions(int width, int height) {
    return '$width×$height px';
  }

  @override
  String get commonSaveLocationHint =>
      'Il vous sera demandé de choisir l\'emplacement de sauvegarde.';

  @override
  String get homeSectionCreateOverline => 'Commencer ici';

  @override
  String get homeSectionCreateTitle => 'Créer un GIF';

  @override
  String get homeSectionRefineOverline => 'Boîte à outils';

  @override
  String get homeSectionRefineTitle => 'Éditer & optimiser';

  @override
  String homeDropUnsupported(String ext) {
    return '.$ext n\'est pas pris en charge. Déposez une vidéo ou un GIF.';
  }

  @override
  String get homeDropVideoOrGif => 'Déposez une vidéo ou un GIF';

  @override
  String homeVersionBadge(String version) {
    return 'v$version';
  }

  @override
  String get homeDragDropHint =>
      'Glissez-déposez un fichier n\'importe où pour commencer';

  @override
  String get homeRecentsOverline => 'Historique';

  @override
  String get homeRecentsTitle => 'Exportations récentes';

  @override
  String get homeTimeJustNow => 'à l\'instant';

  @override
  String homeTimeMinutesAgo(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String homeTimeHoursAgo(int hours) {
    return 'il y a $hours h';
  }

  @override
  String homeTimeDaysAgo(int days) {
    return 'il y a $days j';
  }

  @override
  String get toolVideoStudioLabel => 'Studio Vidéo';

  @override
  String get toolVideoStudioDesc =>
      'Recadrage, redimensionnement & vitesse — exportez en vidéo ou GIF';

  @override
  String get toolImagesToGifLabel => 'Images → GIF';

  @override
  String get toolImagesToGifDesc =>
      'Assemblez une séquence d\'images en une boucle fluide';

  @override
  String get toolScreenRecordLabel => 'Enregistrement d\'écran';

  @override
  String get toolScreenRecordDesc =>
      'Capturez votre écran, puis éditez dans le Studio Vidéo';

  @override
  String get toolResizeLabel => 'Redimensionner';

  @override
  String get toolResizeDesc =>
      'Mettez à l\'échelle vers n\'importe quelle résolution ou préréglage';

  @override
  String get toolCropLabel => 'Recadrer';

  @override
  String get toolCropDesc => 'Taillez l\'image avec un rectangle déplaçable';

  @override
  String get toolTextOverlayLabel => 'Superposition de texte';

  @override
  String get toolTextOverlayDesc =>
      'Ajoutez des légendes stylisées à n\'importe quel GIF';

  @override
  String get toolOptimizeLabel => 'Optimiser';

  @override
  String get toolOptimizeDesc =>
      'Compressez pour obtenir la plus petite taille de fichier';

  @override
  String get toolEffectsLabel => 'Effets';

  @override
  String get toolEffectsDesc => 'Inverser ou changer la vitesse de lecture';

  @override
  String get toolToWebmLabel => 'Vers WebM';

  @override
  String get toolToWebmDesc => 'Convertissez une vidéo ou un GIF en WebM';

  @override
  String get settingsScreenTitle => 'Paramètres';

  @override
  String get settingsSoftwarePreviewTitle => 'Rendu de l\'aperçu logiciel';

  @override
  String get settingsSoftwarePreviewDesc =>
      'Corrige les rares scintillements noirs dans l\'aperçu du Studio Vidéo sur certains GPU. Utilise plus de CPU et limite l\'aperçu à 1080p. Les exportations ne sont jamais affectées. Prend effet à la prochaine ouverture de l\'éditeur.';

  @override
  String get settingsLanguageTitle => 'Langue';

  @override
  String get settingsLanguageDesc =>
      'Choisissez la langue d\'affichage de l\'application.';

  @override
  String get settingsLanguageSystemDefault => 'Par défaut du système';

  @override
  String get settingsSectionGeneral => 'Général';

  @override
  String get settingsAboutDesc => 'Version, crédits et licences';

  @override
  String get cropAppBarTitle => 'Recadrer le GIF';

  @override
  String get cropStepCropArea => 'Zone de recadrage';

  @override
  String get cropStepCropAreaSubtitle =>
      'Faites glisser les coins pour ajuster · Faites glisser l\'intérieur pour déplacer';

  @override
  String cropSizeLabel(int width, int height) {
    return '$width×${height}px';
  }

  @override
  String get cropCouldNotReadDims =>
      'Impossible de lire les dimensions du GIF — recadrage indisponible';

  @override
  String get resizeAppBarTitle => 'Redimensionner le GIF';

  @override
  String get resizeStepOutputSize => 'Taille de sortie';

  @override
  String get resizePresetsLabel => 'Préréglages';

  @override
  String get resizeCustomWidth => 'Largeur personnalisée';

  @override
  String resizeOutputLabel(int width, int height) {
    return 'Sortie : $width×${height}px';
  }

  @override
  String get effectsAppBarTitle => 'Effets';

  @override
  String get effectsStepEffect => 'Effet';

  @override
  String get effectsModeLabel => 'Mode';

  @override
  String get effectsReverseLabel => 'Inverser';

  @override
  String get effectsReverseSubtitle => 'Lire à l\'envers';

  @override
  String get effectsSpeedSubtitle => 'Changer le tempo';

  @override
  String get effectsSpeedSlower => '0,25× plus lent';

  @override
  String get effectsSpeedFaster => '4× plus rapide';

  @override
  String get effectsSpeedLabelOriginal => '1× (original)';

  @override
  String effectsSpeedLabelSlower(String speed) {
    return '$speed× (plus lent)';
  }

  @override
  String effectsSpeedLabelFaster(String speed) {
    return '$speed× (plus rapide)';
  }

  @override
  String get optimizeAppBarTitle => 'Optimiser le GIF';

  @override
  String get optimizeStepCompression => 'Compression';

  @override
  String get optimizeColorsLabel => 'Couleurs';

  @override
  String get optimizeLossyLabel => 'Avec perte (Lossy)';

  @override
  String get optimizeRemoveFrames => 'Supprimer des images';

  @override
  String get optimizeKeepAll => 'Tout garder';

  @override
  String get optimizeFrameDropQuarter => '1 / 4';

  @override
  String get optimizeFrameDropThird => '1 / 3';

  @override
  String get optimizeFrameDropHalf => '1 / 2';

  @override
  String get imagesToGifAppBarTitle => 'Images → GIF';

  @override
  String get imagesStepSelectFrames => 'Sélectionner les images';

  @override
  String get imagesStepSelectFramesSubtitle =>
      'Choisissez les images dans l\'ordre où vous voulez qu\'elles soient lues';

  @override
  String get imagesTapToSelectImages => 'Appuyez pour sélectionner des images';

  @override
  String imagesFrameCountOne(int count) {
    return '$count image';
  }

  @override
  String imagesFrameCountOther(int count) {
    return '$count images';
  }

  @override
  String get imagesAddMore => 'Ajouter plus';

  @override
  String get imagesFrameRateLabel => 'Fréquence d\'images';

  @override
  String get imagesWidthLabel => 'Largeur';

  @override
  String get imagesStepCaption => 'Légende';

  @override
  String get imagesStepCaptionSubtitle =>
      'Texte optionnel dessiné sur chaque image';

  @override
  String get imagesStepOptimizeGif => 'Optimiser le GIF';

  @override
  String get imagesStepOptimizeGifSubtitle =>
      'Réduire les couleurs et la taille du fichier';

  @override
  String get imagesNoFontWarning =>
      'Aucune police système trouvée. La superposition de texte peut échouer.';

  @override
  String get imagesCaptionHint => 'Laisser vide pour ignorer…';

  @override
  String get imagesPositionLabel => 'Position';

  @override
  String get imagesPositionTop => 'Haut';

  @override
  String get imagesPositionCenter => 'Centre';

  @override
  String get imagesPositionBottom => 'Bas';

  @override
  String get imagesColorLabel => 'Couleur';

  @override
  String get imagesColorWhite => 'Blanc';

  @override
  String get imagesColorYellow => 'Jaune';

  @override
  String get imagesColorBlack => 'Noir';

  @override
  String get imagesColorRed => 'Rouge';

  @override
  String get imagesOptimizeToggleLabel => 'Optimiser le GIF de sortie';

  @override
  String get textOverlayAppBarTitle => 'Superposition de texte';

  @override
  String get textOverlayStepEditText => 'Modifier le texte';

  @override
  String get textOverlayStepEditTextSubtitle =>
      'Faites glisser pour positionner · appuyez pour sélectionner';

  @override
  String get textOverlayCannotReadDims => 'Impossible de lire les dimensions';

  @override
  String get textOverlayFontWarning =>
      'Aucune police système trouvée. Le rendu du texte peut échouer à la génération.';

  @override
  String get textOverlayTextFieldHint => 'Texte…';

  @override
  String get textOverlayStyleLabel => 'Style';

  @override
  String get textOverlayFontLabel => 'Police';

  @override
  String get textOverlayFillLabel => 'Remplissage';

  @override
  String get textOverlayStrokeLabel => 'Contour';

  @override
  String get textOverlayStrokeWidthLabel => 'Épaisseur du contour';

  @override
  String get textOverlayLayersTitle => 'Couches de texte';

  @override
  String get textOverlayNoTextYet =>
      'Pas encore de texte. Appuyez sur « Ajouter » pour en créer un.';

  @override
  String get textOverlayAdd => 'Ajouter';

  @override
  String get textOverlayEmptyPlaceholder => '(vide)';

  @override
  String get webmAppBarTitle => 'Vers WebM';

  @override
  String webmRejectedToastOne(int count) {
    return '$count fichier ignoré — 20 max par lot';
  }

  @override
  String webmRejectedToastOther(int count) {
    return '$count fichiers ignorés — 20 max par lot';
  }

  @override
  String get webmSavedToast => 'Enregistré';

  @override
  String webmExportedToastOne(int count) {
    return '$count fichier exporté';
  }

  @override
  String webmExportedToastOther(int count) {
    return '$count fichiers exportés';
  }

  @override
  String get webmStepSelectFiles => 'Sélectionner des fichiers';

  @override
  String get webmDropHint =>
      'Déposez ou appuyez pour sélectionner des vidéos/GIFs (max 20)';

  @override
  String get webmStepConvert => 'Convertir';

  @override
  String get webmCodecLabel => 'Codec';

  @override
  String get webmVp9 => 'VP9';

  @override
  String get webmVp9Sub => 'recommandé';

  @override
  String get webmAv1 => 'AV1';

  @override
  String get webmAv1Sub => 'plus petit · plus lent';

  @override
  String get webmQualityLabel => 'Qualité (CRF)';

  @override
  String get webmSharperBigger => '18 plus net, plus gros';

  @override
  String get webmSmallerSofter => '45 plus petit, plus doux';

  @override
  String get webmFast => 'Rapide';

  @override
  String get webmBalanced => 'Équilibré';

  @override
  String get webmBest => 'Meilleur';

  @override
  String get webmMaxWidth => 'Largeur max';

  @override
  String get webmKeepTransparency => 'Garder la transparence';

  @override
  String get webmProbing => 'analyse…';

  @override
  String get webmConversionFailed => 'La conversion a échoué';

  @override
  String get webmQueued => 'En attente';

  @override
  String get webmConverting => 'Conversion…';

  @override
  String get webmDone => 'Terminé';

  @override
  String get webmError => 'Erreur';

  @override
  String webmConvertingProgress(int done, int total, int percent) {
    return 'Conversion de $done sur $total · $percent%';
  }

  @override
  String get webmConvertButton => 'Convertir';

  @override
  String webmExportAll(int count) {
    return 'Tout exporter ($count)';
  }

  @override
  String get webmExportSingle => 'Exporter en WebM';

  @override
  String get recordAppBarTitle => 'Enregistrement d\'écran';

  @override
  String recordFailedToLoad(String error) {
    return 'Impossible de charger l\'enregistrement d\'écran : $error';
  }

  @override
  String get recordStepSelectMonitor => 'Sélectionner un moniteur';

  @override
  String get recordStepRecord => 'Enregistrer';

  @override
  String get recordButtonLabel => 'Enregistrer';

  @override
  String get recordMaxDuration => 'Max 10:00';

  @override
  String get recordPaused => 'En pause';

  @override
  String get recordRecording => 'Enregistrement en cours';

  @override
  String recordElapsedOfMax(String elapsed) {
    return '$elapsed / 10:00';
  }

  @override
  String get recordResume => 'Reprendre';

  @override
  String get recordPause => 'Pause';

  @override
  String get recordStop => 'Arrêter';

  @override
  String get recordHotkeyStart => 'Démarrer';

  @override
  String get recordHotkeyPauseResume => 'Pause / Reprendre';

  @override
  String get recordAudio => 'Audio';

  @override
  String get recordSystemAudio => 'Audio du système';

  @override
  String get recordDefaultOutputDevice => 'Périphérique de sortie par défaut';

  @override
  String get recordMicrophone => 'Microphone';

  @override
  String get recordNoMicFound => 'Aucun microphone trouvé';

  @override
  String get recordDefaultInputDevice => 'Périphérique d\'entrée par défaut';

  @override
  String get recordEditHotkeyTooltip => 'Modifier le raccourci';

  @override
  String recordPressKeysFor(String label) {
    return 'Appuyez sur les touches pour « $label »';
  }

  @override
  String get recordSave => 'Enregistrer';

  @override
  String get recordHotkeyConflict =>
      'Ce raccourci entre en conflit avec un autre raccourci d\'enregistrement, ou est déjà utilisé par une autre application.';

  @override
  String get recordNoDisplays => 'Aucun écran détecté';

  @override
  String get recordDisplay => 'Écran';

  @override
  String get recordSelectDisplay => 'Sélectionner un écran';

  @override
  String get recordOutputSize => 'Taille de sortie';

  @override
  String get recordStorage => 'Stockage';

  @override
  String get recordSaveLocation => 'Emplacement de sauvegarde';

  @override
  String get recordDefaultTempFolder => 'Défaut (dossier temp)';

  @override
  String get recordChoose => 'Choisir';

  @override
  String get recordResetToDefault => 'Réinitialiser par défaut';

  @override
  String get recordDeleteTempOnExit =>
      'Supprimer la vidéo temporaire à la sortie';

  @override
  String get recordChooseFolderDialogTitle =>
      'Choisir un dossier pour la vidéo enregistrée';

  @override
  String get sharedFileDropDefaultHint =>
      'Appuyez pour sélectionner des fichiers';

  @override
  String get sharedFileDropAnyFile => 'Tous les fichiers';

  @override
  String get sharedExportAndSave => 'Exporter & Enregistrer';

  @override
  String get sharedPreviewUnavailable => 'Aperçu indisponible';

  @override
  String get sharedPerFramePalettes => 'Palettes par image';

  @override
  String get sharedPerFramePalettesDesc =>
      'Compression supplémentaire sans perte, plus lent';

  @override
  String get studioStartOverLabel => 'Recommencer';

  @override
  String get studioStartOverDialogTitle => 'Recommencer ?';

  @override
  String get studioStartOverDialogMessage =>
      'Cela effacera le fichier chargé et toutes les modifications.';

  @override
  String get studioRenderingGif => 'Rendu du GIF…';

  @override
  String get studioEncoding => 'Encodage…';

  @override
  String get studioTapToSelectVideoOrGif =>
      'Appuyez pour sélectionner une vidéo ou un GIF';

  @override
  String get studioEditingGif => 'Édition du GIF';

  @override
  String get studioEditingVideo => 'Édition de la vidéo';

  @override
  String get studioAudioLabel => 'audio';

  @override
  String get studioNoAudioLabel => 'pas d\'audio';

  @override
  String get studioChangeButton => 'Modifier';

  @override
  String get studioZoomFit => 'Ajuster';

  @override
  String get studioZoomFitToWindow => 'Ajuster à la fenêtre';

  @override
  String get studioZoomTooltip => 'Zoom';

  @override
  String get studioCompareLabel => 'Comparer';

  @override
  String get studioOriginalBadge => 'ORIGINAL';

  @override
  String get studioCutBadge => 'COUPE';

  @override
  String studioPositionOfDuration(String position, String duration) {
    return '$position / $duration';
  }

  @override
  String get studioToolTrim => 'Découper';

  @override
  String get studioToolCut => 'Couper';

  @override
  String get studioToolText => 'Texte';

  @override
  String get studioToolOptimize => 'Optimiser';

  @override
  String get studioToolProps => 'Propriétés';

  @override
  String get studioCropDragHint =>
      'Faites glisser les poignées sur l\'aperçu pour recadrer';

  @override
  String get studioPlaybackSpeedLabel => 'Vitesse de lecture';

  @override
  String get studioTrimInLabel => 'Début';

  @override
  String get studioTrimClipLabel => 'Clip';

  @override
  String get studioTrimOutLabel => 'Fin';

  @override
  String studioGifCappedFpsHint(int maxFps) {
    return 'Le GIF sera limité à $maxFps fps pour cette durée.';
  }

  @override
  String get studioCutFromLabel => 'De';

  @override
  String get studioCutToLabel => 'À';

  @override
  String get studioCantAddSegment => 'Impossible d\'ajouter ce segment';

  @override
  String get studioMarkForRemoval => 'Marquer pour suppression';

  @override
  String get studioMarkSpanHint => 'Marquez une plage pour la supprimer';

  @override
  String studioCutOutputLabel(String duration) {
    return 'Sortie ≈ $duration';
  }

  @override
  String get studioNoFontWarning =>
      'Aucune police système trouvée. Le rendu du texte peut échouer.';

  @override
  String get studioScaleLabel => 'Échelle';

  @override
  String get studioScaleSmaller => '10% plus petit';

  @override
  String get studioScaleLarger => '200% plus grand';

  @override
  String get studioFrameRateLabel => 'Fréquence d\'images';

  @override
  String studioCappedFpsHint(int maxFps) {
    return 'Limité à $maxFps fps pour cette durée.';
  }

  @override
  String studioGifCappedWidthHint(int width) {
    return 'GIF limité à ${width}px de large';
  }

  @override
  String get studioIgnoreGifSizeLimit => 'Ignorer la limite de taille GIF';

  @override
  String get studioFullSizeSlowWarning => 'La taille réelle peut être lente';

  @override
  String get studioMakeGifButton => 'Créer le GIF';

  @override
  String get studioVideoTooLongTitle => 'Vidéo trop longue';

  @override
  String get studioGifLimitMessage =>
      'Le GIF est limité à 40 secondes. Taillez d\'abord la vidéo pour de meilleurs résultats, sinon seules les 40 premières secondes seront utilisées.';

  @override
  String get studioUseFirst40s => 'Utiliser les 40 premières secondes';

  @override
  String get studioCouldNotCreateGif => 'Impossible de créer le GIF';

  @override
  String get studioWebmConvertHint =>
      'Convertit ce GIF en vidéo WebM, puis passe à l\'édition vidéo. Opération irréversible — impossible de revenir au GIF.';

  @override
  String get studioConvertToWebmButton => 'Convertir en WebM';

  @override
  String get studioCouldNotConvertWebm => 'Impossible de convertir en WebM';

  @override
  String studioSmoothLoopLabel(int ms) {
    return 'Boucle fluide — fondu enchaîné des $ms derniers ms sur les $ms premiers ms';
  }

  @override
  String get studioNounClips => 'Clips';

  @override
  String get studioNounGifs => 'GIFs';

  @override
  String studioLoopMinLengthHint(String noun) {
    return '$noun de plus de 3s uniquement.';
  }

  @override
  String get studioCrossfadeTooShort =>
      'La vitesse ou le découpage laisse trop peu de place pour le fondu — désactivez la boucle fluide.';

  @override
  String get studioLoopsSeamlessly =>
      'Boucle de manière transparente en dissolvant la fin dans le début.';

  @override
  String get studioCrossfadeDurationLabel => 'Durée du fondu';

  @override
  String get studioVolumeLabel => 'Volume';

  @override
  String get studioNoAudioCaption => 'Pas d\'audio';

  @override
  String get studioVolumeHint =>
      '100% = original · 0% muet · jusqu\'à 200% plus fort.';

  @override
  String get studioNoAudioTrackHint => 'Cette vidéo n\'a pas de piste audio.';

  @override
  String get studioFpsLowerHint =>
      'Réduire recalcule le timing du GIF ; vous ne pourrez plus rajouter d\'images.';

  @override
  String get studioFpsHigherHint =>
      'Plus élevé = plus fluide mais plus volumineux.';

  @override
  String get studioLoopsLabel => 'Boucles';

  @override
  String get studioPlaysForever => 'Lecture infinie';

  @override
  String studioPlaysThenRepeats(int count) {
    return 'Lecture puis répète $count×';
  }

  @override
  String get studioBoomerangLabel =>
      'Boomerang — inversion pour une boucle transparente';

  @override
  String get studioBackToVideoButton => 'Retour à la vidéo';

  @override
  String get studioDiscardGifTitle => 'Abandonner les modifications du GIF ?';

  @override
  String get studioDiscardGifMessage =>
      'Revenir en arrière abandonnera tous les changements effectués sur le GIF.';

  @override
  String get studioDiscardButton => 'Abandonner';

  @override
  String get studioUndoTooltip => 'Annuler';

  @override
  String get studioNothingToUndo => 'Rien à annuler';

  @override
  String get studioRedoTooltip => 'Rétablir';

  @override
  String get studioNothingToRedo => 'Rien à rétablir';

  @override
  String get studioApplyButton => 'Appliquer';

  @override
  String get studioAppliedToPreview => 'Appliqué à l\'aperçu';

  @override
  String get studioExportButton => 'Exporter';

  @override
  String get studioGifSaved => 'GIF enregistré';

  @override
  String get studioExportVideoTooltip => 'Exporter la vidéo';

  @override
  String get studioWebmSaved => 'WebM enregistré';

  @override
  String get studioVideoSaved => 'Vidéo enregistrée';

  @override
  String get studioCutUnavailable => 'Durée inconnue — coupe indisponible';

  @override
  String get studioTrimUnavailable => 'Durée inconnue — découpage indisponible';

  @override
  String get studioExportFormatTitle => 'Format d\'exportation';

  @override
  String studioFormatOriginalTitle(String ext) {
    return 'Original ($ext)';
  }

  @override
  String get studioFormatOriginalSubtitle =>
      'Enregistrer tel quel · pas de ré-encodage · le plus rapide';

  @override
  String get studioFormatMp4Subtitle =>
      'H.264 · meilleure compatibilité · accélération matérielle';

  @override
  String get studioFormatWebmSubtitle =>
      'VP9 · fichiers plus petits · adapté au web';
}
