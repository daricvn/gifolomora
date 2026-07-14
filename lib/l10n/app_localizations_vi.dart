// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Gifolomora';

  @override
  String get settingsTooltip => 'Cài đặt';

  @override
  String get aboutTooltip => 'Giới thiệu';

  @override
  String get exitDialogTitle => 'Thoát Gifolomora?';

  @override
  String get exitDialogMessage =>
      'Bạn có công việc chưa lưu. Bạn có chắc chắn muốn thoát không?';

  @override
  String get exitConfirmLabel => 'Thoát';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonClear => 'Xóa';

  @override
  String get commonClearAll => 'Xóa tất cả';

  @override
  String get commonDone => 'Xong';

  @override
  String get commonReadingFile => 'Đang đọc tệp…';

  @override
  String get commonProcessing => 'Đang xử lý…';

  @override
  String commonProcessingPercent(int percent) {
    return '$percent% đang xử lý…';
  }

  @override
  String get commonRegenerate => 'Tạo lại';

  @override
  String get commonGeneratePreview => 'Tạo xem trước';

  @override
  String get commonExportGif => 'Xuất GIF';

  @override
  String get commonExportCancelled => 'Đã hủy xuất';

  @override
  String get commonSelectGif => 'Chọn GIF';

  @override
  String get commonTapToSelectGif => 'Nhấn để chọn GIF';

  @override
  String get commonPreview => 'Xem trước';

  @override
  String get commonReset => 'Đặt lại';

  @override
  String get commonOriginal => 'Gốc';

  @override
  String get commonOff => 'Tắt';

  @override
  String get commonOptions => 'Tùy chọn';

  @override
  String get commonSpeed => 'Tốc độ';

  @override
  String get commonFontSizeLabel => 'Kích thước chữ';

  @override
  String commonFileDimensions(int width, int height) {
    return '$width×$height px';
  }

  @override
  String get commonSaveLocationHint => 'Bạn sẽ được yêu cầu chọn nơi lưu tệp.';

  @override
  String get homeSectionCreateOverline => 'Bắt đầu tại đây';

  @override
  String get homeSectionCreateTitle => 'Tạo GIF';

  @override
  String get homeSectionRefineOverline => 'Bộ công cụ';

  @override
  String get homeSectionRefineTitle => 'Chỉnh sửa & tối ưu hóa';

  @override
  String homeDropUnsupported(String ext) {
    return '.$ext không được hỗ trợ. Thả video hoặc GIF vào.';
  }

  @override
  String get homeDropVideoOrGif => 'Thả video hoặc GIF';

  @override
  String homeVersionBadge(String version) {
    return 'v$version';
  }

  @override
  String get homeDragDropHint => 'Kéo và thả tệp bất kỳ để bắt đầu';

  @override
  String get homeRecentsOverline => 'Lịch sử';

  @override
  String get homeRecentsTitle => 'Xuất gần đây';

  @override
  String get homeTimeJustNow => 'vừa xong';

  @override
  String homeTimeMinutesAgo(int minutes) {
    return '$minutes phút trước';
  }

  @override
  String homeTimeHoursAgo(int hours) {
    return '$hours giờ trước';
  }

  @override
  String homeTimeDaysAgo(int days) {
    return '$days ngày trước';
  }

  @override
  String get toolVideoStudioLabel => 'Studio Video';

  @override
  String get toolVideoStudioDesc =>
      'Cắt, thay đổi kích thước & tốc độ — xuất dưới dạng video hoặc GIF';

  @override
  String get toolImagesToGifLabel => 'Ảnh → GIF';

  @override
  String get toolImagesToGifDesc =>
      'Ghép nối chuỗi khung hình thành vòng lặp mượt mà';

  @override
  String get toolScreenRecordLabel => 'Ghi màn hình';

  @override
  String get toolScreenRecordDesc =>
      'Quay màn hình của bạn, sau đó chỉnh sửa trong Studio Video';

  @override
  String get toolResizeLabel => 'Thay đổi kích thước';

  @override
  String get toolResizeDesc =>
      'Co giãn đến độ phân giải bất kỳ hoặc mẫu có sẵn';

  @override
  String get toolCropLabel => 'Cắt xén';

  @override
  String get toolCropDesc => 'Cắt khung hình bằng hình chữ nhật có thể kéo';

  @override
  String get toolTextOverlayLabel => 'Chồng chữ';

  @override
  String get toolTextOverlayDesc =>
      'Thêm chú thích được tạo kiểu vào bất kỳ GIF nào';

  @override
  String get toolOptimizeLabel => 'Tối ưu hóa';

  @override
  String get toolOptimizeDesc => 'Nén để có kích thước tệp nhỏ nhất';

  @override
  String get toolEffectsLabel => 'Hiệu ứng';

  @override
  String get toolEffectsDesc => 'Đảo ngược hoặc thay đổi tốc độ phát lại';

  @override
  String get toolToWebmLabel => 'Sang WebM';

  @override
  String get toolToWebmDesc => 'Chuyển đổi video hoặc GIF sang WebM';

  @override
  String get settingsScreenTitle => 'Cài đặt';

  @override
  String get settingsSoftwarePreviewTitle => 'Kết xuất xem trước phần mềm';

  @override
  String get settingsSoftwarePreviewDesc =>
      'Sửa lỗi nhấp nháy đen hiếm gặp trong xem trước Studio Video trên một số GPU. Sử dụng nhiều CPU hơn và giới hạn xem trước ở 1080p. Các bản xuất không bị ảnh hưởng. Có hiệu lực vào lần tiếp theo bạn mở trình chỉnh sửa.';

  @override
  String get settingsLanguageTitle => 'Ngôn ngữ';

  @override
  String get settingsLanguageDesc => 'Chọn ngôn ngữ hiển thị của ứng dụng.';

  @override
  String get settingsLanguageSystemDefault => 'Theo hệ thống';

  @override
  String get settingsSectionGeneral => 'Chung';

  @override
  String get settingsAboutDesc => 'Phiên bản, ghi công và giấy phép';

  @override
  String get cropAppBarTitle => 'Cắt GIF';

  @override
  String get cropStepCropArea => 'Vùng cắt';

  @override
  String get cropStepCropAreaSubtitle =>
      'Kéo các góc để điều chỉnh · Kéo bên trong để di chuyển';

  @override
  String cropSizeLabel(int width, int height) {
    return '$width×${height}px';
  }

  @override
  String get cropCouldNotReadDims =>
      'Không thể đọc kích thước GIF — không thể cắt';

  @override
  String get resizeAppBarTitle => 'Thay đổi kích thước GIF';

  @override
  String get resizeStepOutputSize => 'Kích thước đầu ra';

  @override
  String get resizePresetsLabel => 'Mẫu có sẵn';

  @override
  String get resizeCustomWidth => 'Chiều rộng tùy chỉnh';

  @override
  String resizeOutputLabel(int width, int height) {
    return 'Đầu ra: $width×${height}px';
  }

  @override
  String get effectsAppBarTitle => 'Hiệu ứng';

  @override
  String get effectsStepEffect => 'Hiệu ứng';

  @override
  String get effectsModeLabel => 'Chế độ';

  @override
  String get effectsReverseLabel => 'Đảo ngược';

  @override
  String get effectsReverseSubtitle => 'Phát ngược lại';

  @override
  String get effectsSpeedSubtitle => 'Thay đổi nhịp độ';

  @override
  String get effectsSpeedSlower => '0.25× chậm hơn';

  @override
  String get effectsSpeedFaster => '4× nhanh hơn';

  @override
  String get effectsSpeedLabelOriginal => '1× (gốc)';

  @override
  String effectsSpeedLabelSlower(String speed) {
    return '$speed× (chậm hơn)';
  }

  @override
  String effectsSpeedLabelFaster(String speed) {
    return '$speed× (nhanh hơn)';
  }

  @override
  String get optimizeAppBarTitle => 'Tối ưu hóa GIF';

  @override
  String get optimizeStepCompression => 'Nén';

  @override
  String get optimizeColorsLabel => 'Màu sắc';

  @override
  String get optimizeLossyLabel => 'Mất dữ liệu';

  @override
  String get optimizeRemoveFrames => 'Xóa khung hình';

  @override
  String get optimizeKeepAll => 'Giữ tất cả';

  @override
  String get optimizeFrameDropQuarter => '1 / 4';

  @override
  String get optimizeFrameDropThird => '1 / 3';

  @override
  String get optimizeFrameDropHalf => '1 / 2';

  @override
  String get imagesToGifAppBarTitle => 'Ảnh → GIF';

  @override
  String get imagesStepSelectFrames => 'Chọn khung hình';

  @override
  String get imagesStepSelectFramesSubtitle =>
      'Chọn ảnh theo thứ tự bạn muốn chúng phát';

  @override
  String get imagesTapToSelectImages => 'Nhấn để chọn ảnh';

  @override
  String imagesFrameCountOne(int count) {
    return '$count khung hình';
  }

  @override
  String imagesFrameCountOther(int count) {
    return '$count khung hình';
  }

  @override
  String get imagesAddMore => 'Thêm nữa';

  @override
  String get imagesFrameRateLabel => 'Tốc độ khung hình';

  @override
  String get imagesWidthLabel => 'Chiều rộng';

  @override
  String get imagesStepCaption => 'Chú thích';

  @override
  String get imagesStepCaptionSubtitle =>
      'Văn bản tùy chọn được vẽ trên mỗi khung hình';

  @override
  String get imagesStepOptimizeGif => 'Tối ưu hóa GIF';

  @override
  String get imagesStepOptimizeGifSubtitle => 'Giảm màu sắc và kích thước tệp';

  @override
  String get imagesNoFontWarning =>
      'Không tìm thấy phông chữ hệ thống. Chồng chữ có thể thất bại.';

  @override
  String get imagesCaptionHint => 'Để trống để bỏ qua…';

  @override
  String get imagesPositionLabel => 'Vị trí';

  @override
  String get imagesPositionTop => 'Trên cùng';

  @override
  String get imagesPositionCenter => 'Giữa';

  @override
  String get imagesPositionBottom => 'Dưới cùng';

  @override
  String get imagesColorLabel => 'Màu';

  @override
  String get imagesColorWhite => 'Trắng';

  @override
  String get imagesColorYellow => 'Vàng';

  @override
  String get imagesColorBlack => 'Đen';

  @override
  String get imagesColorRed => 'Đỏ';

  @override
  String get imagesOptimizeToggleLabel => 'Tối ưu hóa GIF đầu ra';

  @override
  String get textOverlayAppBarTitle => 'Chồng chữ';

  @override
  String get textOverlayStepEditText => 'Chỉnh sửa văn bản';

  @override
  String get textOverlayStepEditTextSubtitle => 'Kéo để định vị · nhấn để chọn';

  @override
  String get textOverlayCannotReadDims => 'Không thể đọc kích thước';

  @override
  String get textOverlayFontWarning =>
      'Không tìm thấy phông chữ hệ thống. Kết xuất văn bản có thể thất bại khi Tạo.';

  @override
  String get textOverlayTextFieldHint => 'Văn bản…';

  @override
  String get textOverlayStyleLabel => 'Kiểu cách';

  @override
  String get textOverlayFontLabel => 'Phông chữ';

  @override
  String get textOverlayFillLabel => 'Tô';

  @override
  String get textOverlayStrokeLabel => 'Nét viền';

  @override
  String get textOverlayStrokeWidthLabel => 'Độ rộng nét viền';

  @override
  String get textOverlayLayersTitle => 'Lớp văn bản';

  @override
  String get textOverlayNoTextYet =>
      'Chưa có văn bản. Nhấn “Thêm” để tạo một cái.';

  @override
  String get textOverlayAdd => 'Thêm';

  @override
  String get textOverlayEmptyPlaceholder => '(trống)';

  @override
  String get webmAppBarTitle => 'Sang WebM';

  @override
  String webmRejectedToastOne(int count) {
    return 'Đã bỏ qua $count tệp — tối đa 20 mỗi đợt';
  }

  @override
  String webmRejectedToastOther(int count) {
    return 'Đã bỏ qua $count tệp — tối đa 20 mỗi đợt';
  }

  @override
  String get webmSavedToast => 'Đã lưu';

  @override
  String webmExportedToastOne(int count) {
    return 'Đã xuất $count tệp';
  }

  @override
  String webmExportedToastOther(int count) {
    return 'Đã xuất $count tệp';
  }

  @override
  String get webmStepSelectFiles => 'Chọn tệp';

  @override
  String get webmDropHint => 'Thả hoặc nhấn để chọn video/GIF (tối đa 20)';

  @override
  String get webmStepConvert => 'Chuyển đổi';

  @override
  String get webmCodecLabel => 'Bộ giải mã';

  @override
  String get webmVp9 => 'VP9';

  @override
  String get webmVp9Sub => 'khuyến nghị';

  @override
  String get webmAv1 => 'AV1';

  @override
  String get webmAv1Sub => 'nhỏ nhất · chậm hơn';

  @override
  String get webmQualityLabel => 'Chất lượng (CRF)';

  @override
  String get webmSharperBigger => '18 sắc nét hơn, lớn hơn';

  @override
  String get webmSmallerSofter => '45 nhỏ hơn, mềm hơn';

  @override
  String get webmFast => 'Nhanh';

  @override
  String get webmBalanced => 'Cân bằng';

  @override
  String get webmBest => 'Tốt nhất';

  @override
  String get webmMaxWidth => 'Chiều rộng tối đa';

  @override
  String get webmKeepTransparency => 'Giữ độ trong suốt';

  @override
  String get webmProbing => 'đang thăm dò…';

  @override
  String get webmConversionFailed => 'Chuyển đổi thất bại';

  @override
  String get webmQueued => 'Đã xếp hàng';

  @override
  String get webmConverting => 'Đang chuyển đổi';

  @override
  String get webmDone => 'Xong';

  @override
  String get webmError => 'Lỗi';

  @override
  String webmConvertingProgress(int done, int total, int percent) {
    return 'Đang chuyển đổi $done trên $total · $percent%';
  }

  @override
  String get webmConvertButton => 'Chuyển đổi';

  @override
  String webmExportAll(int count) {
    return 'Xuất tất cả ($count)';
  }

  @override
  String get webmExportSingle => 'Xuất WebM';

  @override
  String get recordAppBarTitle => 'Ghi màn hình';

  @override
  String recordFailedToLoad(String error) {
    return 'Không thể tải Ghi màn hình: $error';
  }

  @override
  String get recordStepSelectMonitor => 'Chọn màn hình';

  @override
  String get recordStepRecord => 'Ghi';

  @override
  String get recordButtonLabel => 'Ghi';

  @override
  String get recordMaxDuration => 'Tối đa 10:00';

  @override
  String get recordPaused => 'Đã tạm dừng';

  @override
  String get recordRecording => 'Đang ghi';

  @override
  String recordElapsedOfMax(String elapsed) {
    return '$elapsed / 10:00';
  }

  @override
  String get recordResume => 'Tiếp tục';

  @override
  String get recordPause => 'Tạm dừng';

  @override
  String get recordStop => 'Dừng';

  @override
  String get recordHotkeyStart => 'Bắt đầu';

  @override
  String get recordHotkeyPauseResume => 'Tạm dừng / Tiếp tục';

  @override
  String get recordAudio => 'Âm thanh';

  @override
  String get recordSystemAudio => 'Âm thanh hệ thống';

  @override
  String get recordDefaultOutputDevice => 'Thiết bị đầu ra mặc định';

  @override
  String get recordMicrophone => 'Micrô';

  @override
  String get recordNoMicFound => 'Không tìm thấy micrô';

  @override
  String get recordDefaultInputDevice => 'Thiết bị đầu vào mặc định';

  @override
  String get recordEditHotkeyTooltip => 'Chỉnh sửa phím tắt';

  @override
  String recordPressKeysFor(String label) {
    return 'Nhấn phím cho \"$label\"';
  }

  @override
  String get recordSave => 'Lưu';

  @override
  String get recordHotkeyConflict =>
      'Tổ hợp phím đó xung đột với phím tắt Ghi màn hình khác, hoặc đã được ứng dụng khác sử dụng.';

  @override
  String get recordNoDisplays => 'Không phát hiện màn hình nào';

  @override
  String get recordDisplay => 'Màn hình';

  @override
  String get recordSelectDisplay => 'Chọn màn hình';

  @override
  String get recordOutputSize => 'Kích thước đầu ra';

  @override
  String get recordStorage => 'Bộ nhớ';

  @override
  String get recordSaveLocation => 'Vị trí lưu';

  @override
  String get recordDefaultTempFolder => 'Mặc định (thư mục tạm)';

  @override
  String get recordChoose => 'Chọn';

  @override
  String get recordResetToDefault => 'Đặt lại về mặc định';

  @override
  String get recordDeleteTempOnExit => 'Xóa video tạm khi thoát';

  @override
  String get recordChooseFolderDialogTitle => 'Chọn thư mục cho video đã ghi';

  @override
  String get sharedFileDropDefaultHint => 'Nhấn để chọn tệp';

  @override
  String get sharedFileDropAnyFile => 'Bất kỳ tệp nào';

  @override
  String get sharedExportAndSave => 'Xuất & Lưu';

  @override
  String get sharedPreviewUnavailable => 'Xem trước không khả dụng';

  @override
  String get sharedPerFramePalettes => 'Bảng màu mỗi khung hình';

  @override
  String get sharedPerFramePalettesDesc =>
      'Nén thêm không mất dữ liệu, chậm hơn';

  @override
  String get studioStartOverLabel => 'Bắt đầu lại';

  @override
  String get studioStartOverDialogTitle => 'Bắt đầu lại?';

  @override
  String get studioStartOverDialogMessage =>
      'Thao tác này sẽ hủy tệp đã tải và tất cả chỉnh sửa.';

  @override
  String get studioRenderingGif => 'Đang kết xuất GIF…';

  @override
  String get studioEncoding => 'Đang mã hóa…';

  @override
  String get studioTapToSelectVideoOrGif => 'Nhấn để chọn video hoặc GIF';

  @override
  String get studioEditingGif => 'Đang chỉnh sửa GIF';

  @override
  String get studioEditingVideo => 'Đang chỉnh sửa video';

  @override
  String get studioAudioLabel => 'âm thanh';

  @override
  String get studioNoAudioLabel => 'không âm thanh';

  @override
  String get studioChangeButton => 'Thay đổi';

  @override
  String get studioZoomFit => 'Vừa';

  @override
  String get studioZoomFitToWindow => 'Vừa cửa sổ';

  @override
  String get studioZoomTooltip => 'Thu phóng';

  @override
  String get studioCompareLabel => 'So sánh';

  @override
  String get studioOriginalBadge => 'GỐC';

  @override
  String get studioCutBadge => 'CẮT';

  @override
  String studioPositionOfDuration(String position, String duration) {
    return '$position / $duration';
  }

  @override
  String get studioToolTrim => 'Cắt bớt';

  @override
  String get studioToolCut => 'Cắt';

  @override
  String get studioToolText => 'Chữ';

  @override
  String get studioToolOptimize => 'Tối ưu';

  @override
  String get studioToolProps => 'Thuộc tính';

  @override
  String get studioCropDragHint => 'Kéo các tay cầm trên xem trước để cắt';

  @override
  String get studioPlaybackSpeedLabel => 'Tốc độ phát lại';

  @override
  String get studioTrimInLabel => 'Vào';

  @override
  String get studioTrimClipLabel => 'Đoạn';

  @override
  String get studioTrimOutLabel => 'Ra';

  @override
  String studioGifCappedFpsHint(int maxFps) {
    return 'GIF sẽ bị giới hạn ở $maxFps fps cho độ dài này.';
  }

  @override
  String get studioCutFromLabel => 'Từ';

  @override
  String get studioCutToLabel => 'Đến';

  @override
  String get studioCantAddSegment => 'Không thể thêm đoạn đó';

  @override
  String get studioMarkForRemoval => 'Đánh dấu để xóa';

  @override
  String get studioMarkSpanHint => 'Đánh dấu một khoảng để xóa nó';

  @override
  String studioCutOutputLabel(String duration) {
    return 'Đầu ra ≈ $duration';
  }

  @override
  String get studioNoFontWarning =>
      'Không tìm thấy phông chữ hệ thống. Văn bản có thể không kết xuất được.';

  @override
  String get studioScaleLabel => 'Tỷ lệ';

  @override
  String get studioScaleSmaller => 'Nhỏ hơn 10%';

  @override
  String get studioScaleLarger => 'Lớn hơn 200%';

  @override
  String get studioFrameRateLabel => 'Tốc độ khung hình';

  @override
  String studioCappedFpsHint(int maxFps) {
    return 'Giới hạn ở $maxFps fps cho độ dài này.';
  }

  @override
  String studioGifCappedWidthHint(int width) {
    return 'GIF bị giới hạn ở ${width}px chiều rộng';
  }

  @override
  String get studioIgnoreGifSizeLimit => 'Bỏ qua giới hạn kích thước GIF';

  @override
  String get studioFullSizeSlowWarning => 'Kích thước đầy đủ có thể chạy chậm';

  @override
  String get studioMakeGifButton => 'Tạo GIF';

  @override
  String get studioVideoTooLongTitle => 'Video quá dài';

  @override
  String get studioGifLimitMessage =>
      'GIF được giới hạn ở 40 giây. Cắt video trước để có kết quả tốt nhất, hoặc chỉ 40 giây đầu tiên sẽ được sử dụng.';

  @override
  String get studioUseFirst40s => 'Sử dụng 40 giây đầu';

  @override
  String get studioCouldNotCreateGif => 'Không thể tạo GIF';

  @override
  String get studioWebmConvertHint =>
      'Chuyển đổi GIF này sang video WebM, sau đó chuyển sang chỉnh sửa video. Một chiều — không thể quay lại GIF.';

  @override
  String get studioConvertToWebmButton => 'Chuyển sang WebM';

  @override
  String get studioCouldNotConvertWebm => 'Không thể chuyển sang WebM';

  @override
  String studioSmoothLoopLabel(int ms) {
    return 'Vòng lặp mượt — hòa tan ${ms}ms cuối vào ${ms}ms đầu';
  }

  @override
  String get studioNounClips => 'Đoạn';

  @override
  String get studioNounGifs => 'GIF';

  @override
  String studioLoopMinLengthHint(String noun) {
    return '$noun dài hơn 3 giây thôi.';
  }

  @override
  String get studioCrossfadeTooShort =>
      'Tốc độ/cắt để lại quá ít để hòa tan — tắt Vòng lặp mượt.';

  @override
  String get studioLoopsSeamlessly =>
      'Lặp lại liền mạch bằng cách hòa tan đuôi vào đầu.';

  @override
  String get studioCrossfadeDurationLabel => 'Thời lượng hòa tan';

  @override
  String get studioVolumeLabel => 'Âm lượng';

  @override
  String get studioNoAudioCaption => 'Không âm thanh';

  @override
  String get studioVolumeHint =>
      '100% = gốc · 0% tắt tiếng · lên đến 200% to hơn.';

  @override
  String get studioNoAudioTrackHint => 'Video này không có track âm thanh.';

  @override
  String get studioFpsLowerHint =>
      'Giảm tốc độ khung hình sẽ thay đổi thời gian GIF; bạn không thể thêm khung hình trở lại.';

  @override
  String get studioFpsHigherHint => 'Cao hơn = mượt hơn nhưng lớn hơn.';

  @override
  String get studioLoopsLabel => 'Vòng lặp';

  @override
  String get studioPlaysForever => 'Phát mãi mãi';

  @override
  String studioPlaysThenRepeats(int count) {
    return 'Phát sau đó lặp lại $count×';
  }

  @override
  String get studioBoomerangLabel =>
      'Boomerang — đảo ngược để tạo vòng lặp liền mạch';

  @override
  String get studioBackToVideoButton => 'Quay lại video';

  @override
  String get studioDiscardGifTitle => 'Hủy chỉnh sửa GIF?';

  @override
  String get studioDiscardGifMessage =>
      'Quay lại sẽ hủy tất cả thay đổi đã thực hiện trên GIF.';

  @override
  String get studioDiscardButton => 'Hủy';

  @override
  String get studioUndoTooltip => 'Hoàn tác';

  @override
  String get studioNothingToUndo => 'Không có gì để hoàn tác';

  @override
  String get studioRedoTooltip => 'Làm lại';

  @override
  String get studioNothingToRedo => 'Không có gì để làm lại';

  @override
  String get studioApplyButton => 'Áp dụng';

  @override
  String get studioAppliedToPreview => 'Đã áp dụng cho xem trước';

  @override
  String get studioExportButton => 'Xuất';

  @override
  String get studioGifSaved => 'GIF đã lưu';

  @override
  String get studioExportVideoTooltip => 'Xuất Video';

  @override
  String get studioWebmSaved => 'WebM đã lưu';

  @override
  String get studioVideoSaved => 'Video đã lưu';

  @override
  String get studioCutUnavailable => 'Không biết thời lượng — không thể cắt';

  @override
  String get studioTrimUnavailable =>
      'Không biết thời lượng — không thể cắt bớt';

  @override
  String get studioExportFormatTitle => 'Định dạng xuất';

  @override
  String studioFormatOriginalTitle(String ext) {
    return 'Gốc ($ext)';
  }

  @override
  String get studioFormatOriginalSubtitle =>
      'Lưu như hiện tại · không mã hóa lại · nhanh nhất';

  @override
  String get studioFormatMp4Subtitle =>
      'H.264 · tương thích tốt nhất · tăng tốc phần cứng';

  @override
  String get studioFormatWebmSubtitle => 'VP9 · tệp nhỏ hơn · thân thiện web';
}
