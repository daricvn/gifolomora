// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Gifolomora';

  @override
  String get settingsTooltip => '設定';

  @override
  String get aboutTooltip => 'このアプリについて';

  @override
  String get exitDialogTitle => 'Gifolomora を終了しますか？';

  @override
  String get exitDialogMessage => '保存されていない作業内容があります。本当に終了しますか？';

  @override
  String get exitConfirmLabel => '終了';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonClear => 'クリア';

  @override
  String get commonClearAll => 'すべてクリア';

  @override
  String get commonDone => '完了';

  @override
  String get commonReadingFile => 'ファイルを読み込み中…';

  @override
  String get commonProcessing => '処理中…';

  @override
  String commonProcessingPercent(int percent) {
    return '$percent% 処理中…';
  }

  @override
  String get commonRegenerate => '再生成';

  @override
  String get commonGeneratePreview => 'プレビューを生成';

  @override
  String get commonExportGif => 'GIFを書き出す';

  @override
  String get commonExportCancelled => '書き出しがキャンセルされました';

  @override
  String get commonSelectGif => 'GIFを選択';

  @override
  String get commonTapToSelectGif => 'タップしてGIFを選択';

  @override
  String get commonPreview => 'プレビュー';

  @override
  String get commonReset => 'リセット';

  @override
  String get commonOriginal => 'オリジナル';

  @override
  String get commonOff => 'オフ';

  @override
  String get commonOptions => 'オプション';

  @override
  String get commonSpeed => '速度';

  @override
  String get commonFontSizeLabel => 'フォントサイズ';

  @override
  String commonFileDimensions(int width, int height) {
    return '$width×$height px';
  }

  @override
  String get commonSaveLocationHint => 'ファイルの保存先を選択するよう求められます。';

  @override
  String get homeSectionCreateOverline => 'ここから開始';

  @override
  String get homeSectionCreateTitle => 'GIFを作成';

  @override
  String get homeSectionRefineOverline => 'ツールキット';

  @override
  String get homeSectionRefineTitle => '編集と最適化';

  @override
  String homeDropUnsupported(String ext) {
    return '.$ext はサポートされていません。ビデオまたはGIFをドロップしてください。';
  }

  @override
  String get homeDropVideoOrGif => 'ビデオまたはGIFをドロップ';

  @override
  String homeVersionBadge(String version) {
    return 'v$version';
  }

  @override
  String get homeDragDropHint => 'ファイルをどこかにドラッグ＆ドロップして開始';

  @override
  String get homeRecentsOverline => '履歴';

  @override
  String get homeRecentsTitle => '最近の書き出し';

  @override
  String get homeTimeJustNow => 'たった今';

  @override
  String homeTimeMinutesAgo(int minutes) {
    return '$minutes分前';
  }

  @override
  String homeTimeHoursAgo(int hours) {
    return '$hours時間前';
  }

  @override
  String homeTimeDaysAgo(int days) {
    return '$days日前';
  }

  @override
  String get toolVideoStudioLabel => 'ビデオスタジオ';

  @override
  String get toolVideoStudioDesc => '切り抜き、リサイズ、速度変更 — ビデオまたはGIFとして書き出し';

  @override
  String get toolImagesToGifLabel => '画像 → GIF';

  @override
  String get toolImagesToGifDesc => '一連のフレームを滑らかなループにつなぎ合わせる';

  @override
  String get toolScreenRecordLabel => '画面録画';

  @override
  String get toolScreenRecordDesc => '画面をキャプチャしてビデオスタジオで編集';

  @override
  String get toolResizeLabel => 'リサイズ';

  @override
  String get toolResizeDesc => '任意の解像度やプリセットにスケール';

  @override
  String get toolCropLabel => '切り抜き';

  @override
  String get toolCropDesc => 'ドラッグ可能な枠でフレームをトリミング';

  @override
  String get toolTextOverlayLabel => 'テキストオーバーレイ';

  @override
  String get toolTextOverlayDesc => 'GIFにスタイル付きのキャプションを追加';

  @override
  String get toolOptimizeLabel => '最適化';

  @override
  String get toolOptimizeDesc => 'ファイルサイズを最小限に圧縮';

  @override
  String get toolEffectsLabel => 'エフェクト';

  @override
  String get toolEffectsDesc => '逆再生や再生速度の変更';

  @override
  String get toolToWebmLabel => 'WebMへ変換';

  @override
  String get toolToWebmDesc => 'ビデオまたはGIFをWebMに変換';

  @override
  String get settingsScreenTitle => '設定';

  @override
  String get settingsSoftwarePreviewTitle => 'ソフトウェアプレビューレンダリング';

  @override
  String get settingsSoftwarePreviewDesc =>
      '一部のGPUでビデオスタジオのプレビュー時に発生する、稀な黒いちらつきを修正します。CPU使用率が増加し、プレビューは最大1080pに制限されます。書き出しには影響しません。次回エディタを開いた時に適用されます。';

  @override
  String get settingsLanguageTitle => '言語';

  @override
  String get settingsLanguageDesc => 'アプリの表示言語を選択してください。';

  @override
  String get settingsLanguageSystemDefault => 'システムのデフォルト';

  @override
  String get settingsSectionGeneral => '一般';

  @override
  String get settingsAboutDesc => 'バージョン、クレジット、ライセンス';

  @override
  String get cropAppBarTitle => 'GIFを切り抜き';

  @override
  String get cropStepCropArea => '切り抜きエリア';

  @override
  String get cropStepCropAreaSubtitle => '角をドラッグして調整 ・ 中をドラッグして移動';

  @override
  String cropSizeLabel(int width, int height) {
    return '$width×${height}px';
  }

  @override
  String get cropCouldNotReadDims => 'GIFの寸法を読み取れませんでした — 切り抜きは利用できません';

  @override
  String get resizeAppBarTitle => 'GIFをリサイズ';

  @override
  String get resizeStepOutputSize => '出力サイズ';

  @override
  String get resizePresetsLabel => 'プリセット';

  @override
  String get resizeCustomWidth => 'カスタム幅';

  @override
  String resizeOutputLabel(int width, int height) {
    return '出力: $width×${height}px';
  }

  @override
  String get effectsAppBarTitle => 'エフェクト';

  @override
  String get effectsStepEffect => 'エフェクト';

  @override
  String get effectsModeLabel => 'モード';

  @override
  String get effectsReverseLabel => '逆再生';

  @override
  String get effectsReverseSubtitle => '後ろ向きに再生';

  @override
  String get effectsSpeedSubtitle => 'テンポを変更';

  @override
  String get effectsSpeedSlower => '0.25倍 遅い';

  @override
  String get effectsSpeedFaster => '4倍 速い';

  @override
  String get effectsSpeedLabelOriginal => '1倍 (オリジナル)';

  @override
  String effectsSpeedLabelSlower(String speed) {
    return '$speed倍 (遅い)';
  }

  @override
  String effectsSpeedLabelFaster(String speed) {
    return '$speed倍 (速い)';
  }

  @override
  String get optimizeAppBarTitle => 'GIFを最適化';

  @override
  String get optimizeStepCompression => '圧縮';

  @override
  String get optimizeColorsLabel => 'カラー';

  @override
  String get optimizeLossyLabel => '損失あり (Lossy)';

  @override
  String get optimizeRemoveFrames => 'フレームを削除';

  @override
  String get optimizeKeepAll => 'すべて保持';

  @override
  String get optimizeFrameDropQuarter => '1 / 4';

  @override
  String get optimizeFrameDropThird => '1 / 3';

  @override
  String get optimizeFrameDropHalf => '1 / 2';

  @override
  String get imagesToGifAppBarTitle => '画像 → GIF';

  @override
  String get imagesStepSelectFrames => 'フレームを選択';

  @override
  String get imagesStepSelectFramesSubtitle => '再生したい順序で画像を選択';

  @override
  String get imagesTapToSelectImages => 'タップして画像を選択';

  @override
  String imagesFrameCountOne(int count) {
    return '$count フレーム';
  }

  @override
  String imagesFrameCountOther(int count) {
    return '$count フレーム';
  }

  @override
  String get imagesAddMore => 'さらに追加';

  @override
  String get imagesFrameRateLabel => 'フレームレート';

  @override
  String get imagesWidthLabel => '幅';

  @override
  String get imagesStepCaption => 'キャプション';

  @override
  String get imagesStepCaptionSubtitle => 'すべてのフレームに描画されるオプションのテキスト';

  @override
  String get imagesStepOptimizeGif => 'GIFを最適化';

  @override
  String get imagesStepOptimizeGifSubtitle => '色数とファイルサイズを削減';

  @override
  String get imagesNoFontWarning => 'システムフォントが見つかりません。テキストオーバーレイが失敗する可能性があります。';

  @override
  String get imagesCaptionHint => 'スキップする場合は空のままにしてください…';

  @override
  String get imagesPositionLabel => '位置';

  @override
  String get imagesPositionTop => '上';

  @override
  String get imagesPositionCenter => '中央';

  @override
  String get imagesPositionBottom => '下';

  @override
  String get imagesColorLabel => '色';

  @override
  String get imagesColorWhite => '白';

  @override
  String get imagesColorYellow => '黄';

  @override
  String get imagesColorBlack => '黒';

  @override
  String get imagesColorRed => '赤';

  @override
  String get imagesOptimizeToggleLabel => '出力GIFを最適化';

  @override
  String get textOverlayAppBarTitle => 'テキストオーバーレイ';

  @override
  String get textOverlayStepEditText => 'テキストを編集';

  @override
  String get textOverlayStepEditTextSubtitle => 'ドラッグで配置 ・ タップで選択';

  @override
  String get textOverlayCannotReadDims => '寸法を読み取れません';

  @override
  String get textOverlayFontWarning =>
      'システムフォントが見つかりません。生成時にテキストレンダリングが失敗する可能性があります。';

  @override
  String get textOverlayTextFieldHint => 'テキスト…';

  @override
  String get textOverlayStyleLabel => 'スタイル';

  @override
  String get textOverlayFontLabel => 'フォント';

  @override
  String get textOverlayFillLabel => '塗りつぶし';

  @override
  String get textOverlayStrokeLabel => '縁取り';

  @override
  String get textOverlayStrokeWidthLabel => '縁取りの幅';

  @override
  String get textOverlayLayersTitle => 'テキストレイヤー';

  @override
  String get textOverlayNoTextYet => 'まだテキストがありません。「追加」をタップして作成してください。';

  @override
  String get textOverlayAdd => '追加';

  @override
  String get textOverlayEmptyPlaceholder => '(空)';

  @override
  String get webmAppBarTitle => 'WebMへ変換';

  @override
  String webmRejectedToastOne(int count) {
    return '$count 個のファイルをスキップしました — 1バッチにつき最大20個までです';
  }

  @override
  String webmRejectedToastOther(int count) {
    return '$count 個のファイルをスキップしました — 1バッチにつき最大20個までです';
  }

  @override
  String get webmSavedToast => '保存しました';

  @override
  String webmExportedToastOne(int count) {
    return '$count 個のファイルを書き出しました';
  }

  @override
  String webmExportedToastOther(int count) {
    return '$count 個のファイルを書き出しました';
  }

  @override
  String get webmStepSelectFiles => 'ファイルを選択';

  @override
  String get webmDropHint => 'ビデオまたはGIFをドロップまたはタップして選択 (最大20個)';

  @override
  String get webmStepConvert => '変換';

  @override
  String get webmCodecLabel => 'コーデック';

  @override
  String get webmVp9 => 'VP9';

  @override
  String get webmVp9Sub => '推奨';

  @override
  String get webmAv1 => 'AV1';

  @override
  String get webmAv1Sub => '最小サイズ ・ 低速';

  @override
  String get webmQualityLabel => '品質 (CRF)';

  @override
  String get webmSharperBigger => '18 鮮明・大';

  @override
  String get webmSmallerSofter => '45 小・ソフト';

  @override
  String get webmFast => '高速';

  @override
  String get webmBalanced => 'バランス';

  @override
  String get webmBest => '最高';

  @override
  String get webmMaxWidth => '最大幅';

  @override
  String get webmKeepTransparency => '透過を保持';

  @override
  String get webmProbing => '調査中…';

  @override
  String get webmConversionFailed => '変換に失敗しました';

  @override
  String get webmQueued => '待機中';

  @override
  String get webmConverting => '変換中';

  @override
  String get webmDone => '完了';

  @override
  String get webmError => 'エラー';

  @override
  String webmConvertingProgress(int done, int total, int percent) {
    return '$total 中 $done を変換中 ・ $percent%';
  }

  @override
  String get webmConvertButton => '変換';

  @override
  String webmExportAll(int count) {
    return 'すべて書き出す ($count)';
  }

  @override
  String get webmExportSingle => 'WebMを書き出す';

  @override
  String get recordAppBarTitle => '画面録画';

  @override
  String recordFailedToLoad(String error) {
    return '画面録画の読み込みに失敗しました: $error';
  }

  @override
  String get recordStepSelectMonitor => 'モニターを選択';

  @override
  String get recordStepRecord => '録画';

  @override
  String get recordButtonLabel => '録画';

  @override
  String get recordMaxDuration => '最大 10:00';

  @override
  String get recordPaused => '一時停止中';

  @override
  String get recordRecording => '録画中';

  @override
  String recordElapsedOfMax(String elapsed) {
    return '$elapsed / 10:00';
  }

  @override
  String get recordResume => '再開';

  @override
  String get recordPause => '一時停止';

  @override
  String get recordStop => '停止';

  @override
  String get recordHotkeyStart => '開始';

  @override
  String get recordHotkeyPauseResume => '一時停止 / 再開';

  @override
  String get recordAudio => 'オーディオ';

  @override
  String get recordSystemAudio => 'システムオーディオ';

  @override
  String get recordDefaultOutputDevice => 'デフォルトの出力デバイス';

  @override
  String get recordMicrophone => 'マイク';

  @override
  String get recordNoMicFound => 'マイクが見つかりません';

  @override
  String get recordDefaultInputDevice => 'デフォルトの入力デバイス';

  @override
  String get recordEditHotkeyTooltip => 'ホットキーを編集';

  @override
  String recordPressKeysFor(String label) {
    return '\"$label\" のキーを押してください';
  }

  @override
  String get recordSave => '保存';

  @override
  String get recordHotkeyConflict =>
      'その組み合わせは、他の画面録画ホットキーと競合しているか、既に他のアプリで使用されています。';

  @override
  String get recordNoDisplays => 'ディスプレイが検出されませんでした';

  @override
  String get recordDisplay => 'ディスプレイ';

  @override
  String get recordSelectDisplay => 'ディスプレイを選択';

  @override
  String get recordOutputSize => '出力サイズ';

  @override
  String get recordStorage => 'ストレージ';

  @override
  String get recordSaveLocation => '保存先';

  @override
  String get recordDefaultTempFolder => 'デフォルト (一時フォルダ)';

  @override
  String get recordChoose => '選択';

  @override
  String get recordResetToDefault => 'デフォルトにリセット';

  @override
  String get recordDeleteTempOnExit => '終了時に一時的なビデオを削除';

  @override
  String get recordChooseFolderDialogTitle => '録画したビデオの保存先フォルダを選択';

  @override
  String get sharedFileDropDefaultHint => 'タップしてファイルを選択';

  @override
  String get sharedFileDropAnyFile => 'すべてのファイル';

  @override
  String get sharedExportAndSave => '書き出し & 保存';

  @override
  String get sharedPreviewUnavailable => 'プレビューを利用できません';

  @override
  String get sharedPerFramePalettes => 'フレームごとのパレット';

  @override
  String get sharedPerFramePalettesDesc => 'ロスレスの追加圧縮、低速';

  @override
  String get studioStartOverLabel => '最初からやり直す';

  @override
  String get studioStartOverDialogTitle => '最初からやり直しますか？';

  @override
  String get studioStartOverDialogMessage => '読み込まれたファイルとすべての編集内容が破棄されます。';

  @override
  String get studioRenderingGif => 'GIFをレンダリング中…';

  @override
  String get studioEncoding => 'エンコード中…';

  @override
  String get studioTapToSelectVideoOrGif => 'タップしてビデオまたはGIFを選択';

  @override
  String get studioEditingGif => 'GIFを編集';

  @override
  String get studioEditingVideo => 'ビデオを編集';

  @override
  String get studioAudioLabel => 'オーディオ';

  @override
  String get studioNoAudioLabel => 'オーディオなし';

  @override
  String get studioChangeButton => '変更';

  @override
  String get studioZoomFit => 'フィット';

  @override
  String get studioZoomFitToWindow => 'ウィンドウに合わせる';

  @override
  String get studioZoomTooltip => 'ズーム';

  @override
  String get studioCompareLabel => '比較';

  @override
  String get studioOriginalBadge => 'オリジナル';

  @override
  String get studioCutBadge => 'カット';

  @override
  String studioPositionOfDuration(String position, String duration) {
    return '$position / $duration';
  }

  @override
  String get studioToolTrim => 'トリミング';

  @override
  String get studioToolCut => 'カット';

  @override
  String get studioToolText => 'テキスト';

  @override
  String get studioToolOptimize => '最適化';

  @override
  String get studioToolProps => 'プロパティ';

  @override
  String get studioCropDragHint => 'プレビュー上のハンドルをドラッグして切り抜きます';

  @override
  String get studioPlaybackSpeedLabel => '再生速度';

  @override
  String get studioTrimInLabel => '開始位置';

  @override
  String get studioTrimClipLabel => 'クリップ';

  @override
  String get studioTrimOutLabel => '終了位置';

  @override
  String studioGifCappedFpsHint(int maxFps) {
    return 'この長さの場合、GIFは最大 $maxFps fpsに制限されます。';
  }

  @override
  String get studioCutFromLabel => '開始';

  @override
  String get studioCutToLabel => '終了';

  @override
  String get studioCantAddSegment => 'そのセグメントは追加できません';

  @override
  String get studioMarkForRemoval => '削除対象としてマーク';

  @override
  String get studioMarkSpanHint => '削除する範囲をマークしてください';

  @override
  String studioCutOutputLabel(String duration) {
    return '出力 ≈ $duration';
  }

  @override
  String get studioNoFontWarning =>
      'システムフォントが見つかりません。テキストのレンダリングに失敗する可能性があります。';

  @override
  String get studioScaleLabel => 'スケール';

  @override
  String get studioScaleSmaller => '10% 小さく';

  @override
  String get studioScaleLarger => '200% 大きく';

  @override
  String get studioFrameRateLabel => 'フレームレート';

  @override
  String studioCappedFpsHint(int maxFps) {
    return 'この長さの場合、$maxFps fpsに制限されます。';
  }

  @override
  String studioGifCappedWidthHint(int width) {
    return 'GIFは幅 ${width}px に制限されます';
  }

  @override
  String get studioIgnoreGifSizeLimit => 'GIFサイズ制限を無視';

  @override
  String get studioFullSizeSlowWarning => 'フルサイズは動作が遅くなる可能性があります';

  @override
  String get studioMakeGifButton => 'GIFを作成';

  @override
  String get studioVideoTooLongTitle => 'ビデオが長すぎます';

  @override
  String get studioGifLimitMessage =>
      'GIFは40秒に制限されています。最良の結果を得るには、まずビデオをトリミングしてください。そうしない場合、最初の40秒間のみが使用されます。';

  @override
  String get studioUseFirst40s => '最初の40秒を使用';

  @override
  String get studioCouldNotCreateGif => 'GIFを作成できませんでした';

  @override
  String get studioWebmConvertHint =>
      'このGIFをWebMビデオに変換し、ビデオ編集に切り替えます。この操作は一方通行で、GIFに戻ることはできません。';

  @override
  String get studioConvertToWebmButton => 'WebMへ変換';

  @override
  String get studioCouldNotConvertWebm => 'WebMへ変換できませんでした';

  @override
  String studioSmoothLoopLabel(int ms) {
    return '滑らかなループ — 最後の ${ms}ms を最初の ${ms}ms にクロスフェード';
  }

  @override
  String get studioNounClips => 'クリップ';

  @override
  String get studioNounGifs => 'GIF';

  @override
  String studioLoopMinLengthHint(String noun) {
    return '3秒より長い $noun のみ。';
  }

  @override
  String get studioCrossfadeTooShort =>
      '速度またはトリミングによりクロスフェードするための余白が不足しています — 滑らかなループをオフにしてください。';

  @override
  String get studioLoopsSeamlessly => '末尾を先頭にディゾルブさせることで、シームレスにループします。';

  @override
  String get studioCrossfadeDurationLabel => 'クロスフェードの長さ';

  @override
  String get studioVolumeLabel => '音量';

  @override
  String get studioNoAudioCaption => 'オーディオなし';

  @override
  String get studioVolumeHint => '100% = オリジナル ・ 0% ミュート ・ 最大200%まで。';

  @override
  String get studioNoAudioTrackHint => 'このビデオにはオーディオトラックがありません。';

  @override
  String get studioFpsLowerHint =>
      '下げるとGIFのタイミングが再調整されます。削除したフレームを元に戻すことはできません。';

  @override
  String get studioFpsHigherHint => '高い = 滑らかですが、サイズが大きくなります。';

  @override
  String get studioLoopsLabel => 'ループ';

  @override
  String get studioPlaysForever => '無限再生';

  @override
  String studioPlaysThenRepeats(int count) {
    return '再生後 $count 回繰り返す';
  }

  @override
  String get studioBoomerangLabel => 'ブーメラン — シームレスなループのために逆再生';

  @override
  String get studioBackToVideoButton => 'ビデオに戻る';

  @override
  String get studioDiscardGifTitle => 'GIFの編集内容を破棄しますか？';

  @override
  String get studioDiscardGifMessage => '戻ると、GIFに対して行われたすべての変更が破棄されます。';

  @override
  String get studioDiscardButton => '破棄';

  @override
  String get studioUndoTooltip => '元に戻す';

  @override
  String get studioNothingToUndo => '元に戻す操作はありません';

  @override
  String get studioRedoTooltip => 'やり直し';

  @override
  String get studioNothingToRedo => 'やり直し操作はありません';

  @override
  String get studioApplyButton => '適用';

  @override
  String get studioAppliedToPreview => 'プレビューに適用されました';

  @override
  String get studioExportButton => '書き出し';

  @override
  String get studioGifSaved => 'GIFを保存しました';

  @override
  String get studioExportVideoTooltip => 'ビデオを書き出す';

  @override
  String get studioWebmSaved => 'WebMを保存しました';

  @override
  String get studioVideoSaved => 'ビデオを保存しました';

  @override
  String get studioCutUnavailable => '長さが不明です — カットは利用できません';

  @override
  String get studioTrimUnavailable => '長さが不明です — トリミングは利用できません';

  @override
  String get studioExportFormatTitle => '書き出し形式';

  @override
  String studioFormatOriginalTitle(String ext) {
    return 'オリジナル ($ext)';
  }

  @override
  String get studioFormatOriginalSubtitle => 'そのまま保存 ・ 再エンコードなし ・ 最速';

  @override
  String get studioFormatMp4Subtitle => 'H.264 ・ 最高の互換性 ・ ハードウェアアクセラレーション';

  @override
  String get studioFormatWebmSubtitle => 'VP9 ・ 小さなファイルサイズ ・ Webフレンドリー';
}
