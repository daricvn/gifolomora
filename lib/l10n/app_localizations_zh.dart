// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Gifolomora';

  @override
  String get settingsTooltip => '设置';

  @override
  String get aboutTooltip => '关于';

  @override
  String get exitDialogTitle => '退出 Gifolomora？';

  @override
  String get exitDialogMessage => '您有未保存的工作。确定要退出吗？';

  @override
  String get exitConfirmLabel => '退出';

  @override
  String get commonCancel => '取消';

  @override
  String get commonClear => '清除';

  @override
  String get commonClearAll => '全部清除';

  @override
  String get commonDone => '完成';

  @override
  String get commonReadingFile => '正在读取文件…';

  @override
  String get commonProcessing => '正在处理…';

  @override
  String commonProcessingPercent(int percent) {
    return '$percent% 正在处理…';
  }

  @override
  String get commonRegenerate => '重新生成';

  @override
  String get commonGeneratePreview => '生成预览';

  @override
  String get commonExportGif => '导出 GIF';

  @override
  String get commonExportCancelled => '已取消导出';

  @override
  String get commonSelectGif => '选择 GIF';

  @override
  String get commonTapToSelectGif => '点击选择 GIF';

  @override
  String get commonPreview => '预览';

  @override
  String get commonReset => '重置';

  @override
  String get commonOriginal => '原始';

  @override
  String get commonOff => '关闭';

  @override
  String get commonOptions => '选项';

  @override
  String get commonSpeed => '速度';

  @override
  String get commonFontSizeLabel => '字体大小';

  @override
  String commonFileDimensions(int width, int height) {
    return '$width×$height px';
  }

  @override
  String get commonSaveLocationHint => '系统将要求您选择保存位置。';

  @override
  String get homeSectionCreateOverline => '从这里开始';

  @override
  String get homeSectionCreateTitle => '创建 GIF';

  @override
  String get homeSectionRefineOverline => '工具箱';

  @override
  String get homeSectionRefineTitle => '编辑与优化';

  @override
  String homeDropUnsupported(String ext) {
    return '.$ext 不受支持。请拖放视频或 GIF。';
  }

  @override
  String get homeDropVideoOrGif => '拖放视频或 GIF';

  @override
  String homeVersionBadge(String version) {
    return 'v$version';
  }

  @override
  String get homeDragDropHint => '拖放任意文件以开始';

  @override
  String get homeRecentsOverline => '历史';

  @override
  String get homeRecentsTitle => '最近导出';

  @override
  String get homeTimeJustNow => '刚刚';

  @override
  String homeTimeMinutesAgo(int minutes) {
    return '$minutes 分钟前';
  }

  @override
  String homeTimeHoursAgo(int hours) {
    return '$hours 小时前';
  }

  @override
  String homeTimeDaysAgo(int days) {
    return '$days 天前';
  }

  @override
  String get toolVideoStudioLabel => '视频工作室';

  @override
  String get toolVideoStudioDesc => '裁剪、调整大小和速度 — 导出为视频或 GIF';

  @override
  String get toolImagesToGifLabel => '图片 → GIF';

  @override
  String get toolImagesToGifDesc => '将帧序列拼接成流畅循环';

  @override
  String get toolScreenRecordLabel => '屏幕录制';

  @override
  String get toolScreenRecordDesc => '捕获屏幕，然后在视频工作室中编辑';

  @override
  String get toolResizeLabel => '调整大小';

  @override
  String get toolResizeDesc => '缩放到任意分辨率或预设';

  @override
  String get toolCropLabel => '裁剪';

  @override
  String get toolCropDesc => '使用可拖动矩形修剪帧';

  @override
  String get toolTextOverlayLabel => '文字叠加';

  @override
  String get toolTextOverlayDesc => '为任意 GIF 添加样式化字幕';

  @override
  String get toolOptimizeLabel => '优化';

  @override
  String get toolOptimizeDesc => '压缩以获得最小文件大小';

  @override
  String get toolEffectsLabel => '效果';

  @override
  String get toolEffectsDesc => '反向播放或更改播放速度';

  @override
  String get toolToWebmLabel => '转为 WebM';

  @override
  String get toolToWebmDesc => '将视频或 GIF 转换为 WebM';

  @override
  String get settingsScreenTitle => '设置';

  @override
  String get settingsSoftwarePreviewTitle => '软件预览渲染';

  @override
  String get settingsSoftwarePreviewDesc =>
      '修复某些 GPU 上视频工作室预览中罕见的黑色闪烁问题。会使用更多 CPU 并将预览限制在 1080p。导出不受影响。下次打开编辑器时生效。';

  @override
  String get settingsLanguageTitle => '语言';

  @override
  String get settingsLanguageDesc => '选择应用显示语言。';

  @override
  String get settingsLanguageSystemDefault => '跟随系统';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsAboutDesc => '版本、鸣谢与许可证';

  @override
  String get cropAppBarTitle => '裁剪 GIF';

  @override
  String get cropStepCropArea => '裁剪区域';

  @override
  String get cropStepCropAreaSubtitle => '拖动角点调整 · 拖动内部移动';

  @override
  String cropSizeLabel(int width, int height) {
    return '$width×${height}px';
  }

  @override
  String get cropCouldNotReadDims => '无法读取 GIF 尺寸 — 裁剪不可用';

  @override
  String get resizeAppBarTitle => '调整 GIF 大小';

  @override
  String get resizeStepOutputSize => '输出尺寸';

  @override
  String get resizePresetsLabel => '预设';

  @override
  String get resizeCustomWidth => '自定义宽度';

  @override
  String resizeOutputLabel(int width, int height) {
    return '输出: $width×${height}px';
  }

  @override
  String get effectsAppBarTitle => '效果';

  @override
  String get effectsStepEffect => '效果';

  @override
  String get effectsModeLabel => '模式';

  @override
  String get effectsReverseLabel => '反向';

  @override
  String get effectsReverseSubtitle => '向后播放';

  @override
  String get effectsSpeedSubtitle => '改变节奏';

  @override
  String get effectsSpeedSlower => '0.25× 更慢';

  @override
  String get effectsSpeedFaster => '4× 更快';

  @override
  String get effectsSpeedLabelOriginal => '1× (原始)';

  @override
  String effectsSpeedLabelSlower(String speed) {
    return '$speed× (更慢)';
  }

  @override
  String effectsSpeedLabelFaster(String speed) {
    return '$speed× (更快)';
  }

  @override
  String get optimizeAppBarTitle => '优化 GIF';

  @override
  String get optimizeStepCompression => '压缩';

  @override
  String get optimizeColorsLabel => '颜色';

  @override
  String get optimizeLossyLabel => '有损';

  @override
  String get optimizeRemoveFrames => '移除帧';

  @override
  String get optimizeKeepAll => '保留全部';

  @override
  String get optimizeFrameDropQuarter => '1 / 4';

  @override
  String get optimizeFrameDropThird => '1 / 3';

  @override
  String get optimizeFrameDropHalf => '1 / 2';

  @override
  String get imagesToGifAppBarTitle => '图片 → GIF';

  @override
  String get imagesStepSelectFrames => '选择帧';

  @override
  String get imagesStepSelectFramesSubtitle => '按您希望的播放顺序选择图片';

  @override
  String get imagesTapToSelectImages => '点击选择图片';

  @override
  String imagesFrameCountOne(int count) {
    return '$count 帧';
  }

  @override
  String imagesFrameCountOther(int count) {
    return '$count 帧';
  }

  @override
  String get imagesAddMore => '添加更多';

  @override
  String get imagesFrameRateLabel => '帧率';

  @override
  String get imagesWidthLabel => '宽度';

  @override
  String get imagesStepCaption => '字幕';

  @override
  String get imagesStepCaptionSubtitle => '可选文字，将绘制在每一帧上';

  @override
  String get imagesStepOptimizeGif => '优化 GIF';

  @override
  String get imagesStepOptimizeGifSubtitle => '减少颜色和文件大小';

  @override
  String get imagesNoFontWarning => '未找到系统字体。文字叠加可能会失败。';

  @override
  String get imagesCaptionHint => '留空以跳过…';

  @override
  String get imagesPositionLabel => '位置';

  @override
  String get imagesPositionTop => '顶部';

  @override
  String get imagesPositionCenter => '居中';

  @override
  String get imagesPositionBottom => '底部';

  @override
  String get imagesColorLabel => '颜色';

  @override
  String get imagesColorWhite => '白色';

  @override
  String get imagesColorYellow => '黄色';

  @override
  String get imagesColorBlack => '黑色';

  @override
  String get imagesColorRed => '红色';

  @override
  String get imagesOptimizeToggleLabel => '优化输出 GIF';

  @override
  String get textOverlayAppBarTitle => '文字叠加';

  @override
  String get textOverlayStepEditText => '编辑文字';

  @override
  String get textOverlayStepEditTextSubtitle => '拖动以定位 · 点击以选择';

  @override
  String get textOverlayCannotReadDims => '无法读取尺寸';

  @override
  String get textOverlayFontWarning => '未找到系统字体。生成时文字渲染可能会失败。';

  @override
  String get textOverlayTextFieldHint => '文字…';

  @override
  String get textOverlayStyleLabel => '样式';

  @override
  String get textOverlayFontLabel => '字体';

  @override
  String get textOverlayFillLabel => '填充';

  @override
  String get textOverlayStrokeLabel => '描边';

  @override
  String get textOverlayStrokeWidthLabel => '描边宽度';

  @override
  String get textOverlayLayersTitle => '文字图层';

  @override
  String get textOverlayNoTextYet => '还没有文字。点击“添加”创建一个。';

  @override
  String get textOverlayAdd => '添加';

  @override
  String get textOverlayEmptyPlaceholder => '(空)';

  @override
  String get webmAppBarTitle => '转为 WebM';

  @override
  String webmRejectedToastOne(int count) {
    return '已跳过 $count 个文件 — 每批最多 20 个';
  }

  @override
  String webmRejectedToastOther(int count) {
    return '已跳过 $count 个文件 — 每批最多 20 个';
  }

  @override
  String get webmSavedToast => '已保存';

  @override
  String webmExportedToastOne(int count) {
    return '已导出 $count 个文件';
  }

  @override
  String webmExportedToastOther(int count) {
    return '已导出 $count 个文件';
  }

  @override
  String get webmStepSelectFiles => '选择文件';

  @override
  String get webmDropHint => '拖放或点击选择视频/GIF（最多 20 个）';

  @override
  String get webmStepConvert => '转换';

  @override
  String get webmCodecLabel => '编解码器';

  @override
  String get webmVp9 => 'VP9';

  @override
  String get webmVp9Sub => '推荐';

  @override
  String get webmAv1 => 'AV1';

  @override
  String get webmAv1Sub => '最小 · 更慢';

  @override
  String get webmQualityLabel => '质量 (CRF)';

  @override
  String get webmSharperBigger => '18 更锐利、更大';

  @override
  String get webmSmallerSofter => '45 更小、更柔和';

  @override
  String get webmFast => '快速';

  @override
  String get webmBalanced => '平衡';

  @override
  String get webmBest => '最佳';

  @override
  String get webmMaxWidth => '最大宽度';

  @override
  String get webmKeepTransparency => '保留透明度';

  @override
  String get webmProbing => '探测中…';

  @override
  String get webmConversionFailed => '转换失败';

  @override
  String get webmQueued => '已排队';

  @override
  String get webmConverting => '转换中';

  @override
  String get webmDone => '完成';

  @override
  String get webmError => '错误';

  @override
  String webmConvertingProgress(int done, int total, int percent) {
    return '正在转换 $done / $total · $percent%';
  }

  @override
  String get webmConvertButton => '转换';

  @override
  String webmExportAll(int count) {
    return '导出全部 ($count)';
  }

  @override
  String get webmExportSingle => '导出 WebM';

  @override
  String get recordAppBarTitle => '屏幕录制';

  @override
  String recordFailedToLoad(String error) {
    return '加载屏幕录制失败: $error';
  }

  @override
  String get recordStepSelectMonitor => '选择显示器';

  @override
  String get recordStepRecord => '录制';

  @override
  String get recordButtonLabel => '录制';

  @override
  String get recordMaxDuration => '最长 10:00';

  @override
  String get recordPaused => '已暂停';

  @override
  String get recordRecording => '录制中';

  @override
  String recordElapsedOfMax(String elapsed) {
    return '$elapsed / 10:00';
  }

  @override
  String get recordResume => '继续';

  @override
  String get recordPause => '暂停';

  @override
  String get recordStop => '停止';

  @override
  String get recordHotkeyStart => '开始';

  @override
  String get recordHotkeyPauseResume => '暂停 / 继续';

  @override
  String get recordAudio => '音频';

  @override
  String get recordSystemAudio => '系统音频';

  @override
  String get recordDefaultOutputDevice => '默认输出设备';

  @override
  String get recordMicrophone => '麦克风';

  @override
  String get recordNoMicFound => '未找到麦克风';

  @override
  String get recordDefaultInputDevice => '默认输入设备';

  @override
  String get recordEditHotkeyTooltip => '编辑快捷键';

  @override
  String recordPressKeysFor(String label) {
    return '按下按键以设置 \"$label\"';
  }

  @override
  String get recordSave => '保存';

  @override
  String get recordHotkeyConflict => '该按键组合与另一个屏幕录制快捷键冲突，或已被其他应用占用。';

  @override
  String get recordNoDisplays => '未检测到显示器';

  @override
  String get recordDisplay => '显示器';

  @override
  String get recordSelectDisplay => '选择显示器';

  @override
  String get recordOutputSize => '输出尺寸';

  @override
  String get recordStorage => '存储';

  @override
  String get recordSaveLocation => '保存位置';

  @override
  String get recordDefaultTempFolder => '默认（临时文件夹）';

  @override
  String get recordChoose => '选择';

  @override
  String get recordResetToDefault => '重置为默认';

  @override
  String get recordDeleteTempOnExit => '退出时删除临时视频';

  @override
  String get recordChooseFolderDialogTitle => '选择录制视频的保存文件夹';

  @override
  String get sharedFileDropDefaultHint => '点击选择文件';

  @override
  String get sharedFileDropAnyFile => '任意文件';

  @override
  String get sharedExportAndSave => '导出并保存';

  @override
  String get sharedPreviewUnavailable => '预览不可用';

  @override
  String get sharedPerFramePalettes => '每帧调色板';

  @override
  String get sharedPerFramePalettesDesc => '无损额外压缩，更慢';

  @override
  String get studioStartOverLabel => '重新开始';

  @override
  String get studioStartOverDialogTitle => '重新开始？';

  @override
  String get studioStartOverDialogMessage => '这将丢弃已加载的文件和所有编辑。';

  @override
  String get studioRenderingGif => '正在渲染 GIF…';

  @override
  String get studioEncoding => '正在编码…';

  @override
  String get studioTapToSelectVideoOrGif => '点击选择视频或 GIF';

  @override
  String get studioEditingGif => '正在编辑 GIF';

  @override
  String get studioEditingVideo => '正在编辑视频';

  @override
  String get studioAudioLabel => '音频';

  @override
  String get studioNoAudioLabel => '无音频';

  @override
  String get studioChangeButton => '更改';

  @override
  String get studioZoomFit => '适应';

  @override
  String get studioZoomFitToWindow => '适应窗口';

  @override
  String get studioZoomTooltip => '缩放';

  @override
  String get studioCompareLabel => '比较';

  @override
  String get studioOriginalBadge => '原始';

  @override
  String get studioCutBadge => '剪切';

  @override
  String studioPositionOfDuration(String position, String duration) {
    return '$position / $duration';
  }

  @override
  String get studioToolTrim => '修剪';

  @override
  String get studioToolCut => '剪切';

  @override
  String get studioToolText => '文字';

  @override
  String get studioToolOptimize => '优化';

  @override
  String get studioToolProps => '属性';

  @override
  String get studioCropDragHint => '在预览上拖动手柄进行裁剪';

  @override
  String get studioPlaybackSpeedLabel => '播放速度';

  @override
  String get studioTrimInLabel => '入点';

  @override
  String get studioTrimClipLabel => '片段';

  @override
  String get studioTrimOutLabel => '出点';

  @override
  String studioGifCappedFpsHint(int maxFps) {
    return 'GIF 将在此长度下限制为 $maxFps fps。';
  }

  @override
  String get studioCutFromLabel => '从';

  @override
  String get studioCutToLabel => '到';

  @override
  String get studioCantAddSegment => '无法添加该片段';

  @override
  String get studioMarkForRemoval => '标记为移除';

  @override
  String get studioMarkSpanHint => '标记要移除的范围';

  @override
  String studioCutOutputLabel(String duration) {
    return '输出 ≈ $duration';
  }

  @override
  String get studioNoFontWarning => '未找到系统字体。文字可能无法渲染。';

  @override
  String get studioScaleLabel => '缩放';

  @override
  String get studioScaleSmaller => '缩小 10%';

  @override
  String get studioScaleLarger => '放大 200%';

  @override
  String get studioFrameRateLabel => '帧率';

  @override
  String studioCappedFpsHint(int maxFps) {
    return '在此长度下限制为 $maxFps fps。';
  }

  @override
  String studioGifCappedWidthHint(int width) {
    return 'GIF 限制为 ${width}px 宽';
  }

  @override
  String get studioIgnoreGifSizeLimit => '忽略 GIF 大小限制';

  @override
  String get studioFullSizeSlowWarning => '完整尺寸可能会运行缓慢';

  @override
  String get studioMakeGifButton => '制作 GIF';

  @override
  String get studioVideoTooLongTitle => '视频过长';

  @override
  String get studioGifLimitMessage => 'GIF 限制为 40 秒。请先修剪视频以获得最佳效果，否则仅使用前 40 秒。';

  @override
  String get studioUseFirst40s => '使用前 40 秒';

  @override
  String get studioCouldNotCreateGif => '无法创建 GIF';

  @override
  String get studioWebmConvertHint =>
      '将此 GIF 转换为 WebM 视频，然后切换到视频编辑。单向操作 — 无法返回 GIF。';

  @override
  String get studioConvertToWebmButton => '转换为 WebM';

  @override
  String get studioCouldNotConvertWebm => '无法转换为 WebM';

  @override
  String studioSmoothLoopLabel(int ms) {
    return '平滑循环 — 将最后 ${ms}ms 淡入到前 ${ms}ms';
  }

  @override
  String get studioNounClips => '片段';

  @override
  String get studioNounGifs => 'GIF';

  @override
  String studioLoopMinLengthHint(String noun) {
    return '仅限 $noun 长于 3 秒。';
  }

  @override
  String get studioCrossfadeTooShort => '速度/修剪后剩余长度不足以淡入淡出 — 请关闭平滑循环。';

  @override
  String get studioLoopsSeamlessly => '通过将尾部淡入到头部来实现无缝循环。';

  @override
  String get studioCrossfadeDurationLabel => '淡入淡出时长';

  @override
  String get studioVolumeLabel => '音量';

  @override
  String get studioNoAudioCaption => '无音频';

  @override
  String get studioVolumeHint => '100% = 原始 · 0% = 静音 · 最高可达 200% 更大声。';

  @override
  String get studioNoAudioTrackHint => '此视频没有音频轨道。';

  @override
  String get studioFpsLowerHint => '降低帧率会重新计时 GIF；您无法添加回帧。';

  @override
  String get studioFpsHigherHint => '更高 = 更流畅但文件更大。';

  @override
  String get studioLoopsLabel => '循环';

  @override
  String get studioPlaysForever => '永远播放';

  @override
  String studioPlaysThenRepeats(int count) {
    return '播放后重复 $count 次';
  }

  @override
  String get studioBoomerangLabel => '回环 — 反向播放以实现无缝循环';

  @override
  String get studioBackToVideoButton => '返回视频';

  @override
  String get studioDiscardGifTitle => '丢弃 GIF 编辑？';

  @override
  String get studioDiscardGifMessage => '返回将丢弃对 GIF 所做的所有更改。';

  @override
  String get studioDiscardButton => '丢弃';

  @override
  String get studioUndoTooltip => '撤销';

  @override
  String get studioNothingToUndo => '没有可撤销的内容';

  @override
  String get studioRedoTooltip => '重做';

  @override
  String get studioNothingToRedo => '没有可重做的内容';

  @override
  String get studioApplyButton => '应用';

  @override
  String get studioAppliedToPreview => '已应用到预览';

  @override
  String get studioExportButton => '导出';

  @override
  String get studioGifSaved => 'GIF 已保存';

  @override
  String get studioExportVideoTooltip => '导出视频';

  @override
  String get studioWebmSaved => 'WebM 已保存';

  @override
  String get studioVideoSaved => '视频已保存';

  @override
  String get studioCutUnavailable => '时长未知 — 剪切不可用';

  @override
  String get studioTrimUnavailable => '时长未知 — 修剪不可用';

  @override
  String get studioExportFormatTitle => '导出格式';

  @override
  String studioFormatOriginalTitle(String ext) {
    return '原始 ($ext)';
  }

  @override
  String get studioFormatOriginalSubtitle => '原样保存 · 不重新编码 · 最快';

  @override
  String get studioFormatMp4Subtitle => 'H.264 · 最佳兼容性 · 硬件加速';

  @override
  String get studioFormatWebmSubtitle => 'VP9 · 文件更小 · 适合网页';
}
