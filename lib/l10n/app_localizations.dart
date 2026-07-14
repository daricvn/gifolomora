import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('ja'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Gifolomora'**
  String get appTitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @aboutTooltip.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTooltip;

  /// No description provided for @exitDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Gifolomora?'**
  String get exitDialogTitle;

  /// No description provided for @exitDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved work in progress. Are you sure you want to exit?'**
  String get exitDialogMessage;

  /// No description provided for @exitConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitConfirmLabel;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get commonClearAll;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonReadingFile.
  ///
  /// In en, this message translates to:
  /// **'Reading file…'**
  String get commonReadingFile;

  /// No description provided for @commonProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get commonProcessing;

  /// No description provided for @commonProcessingPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%  processing…'**
  String commonProcessingPercent(int percent);

  /// No description provided for @commonRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get commonRegenerate;

  /// No description provided for @commonGeneratePreview.
  ///
  /// In en, this message translates to:
  /// **'Generate Preview'**
  String get commonGeneratePreview;

  /// No description provided for @commonExportGif.
  ///
  /// In en, this message translates to:
  /// **'Export GIF'**
  String get commonExportGif;

  /// No description provided for @commonExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled'**
  String get commonExportCancelled;

  /// No description provided for @commonSelectGif.
  ///
  /// In en, this message translates to:
  /// **'Select GIF'**
  String get commonSelectGif;

  /// No description provided for @commonTapToSelectGif.
  ///
  /// In en, this message translates to:
  /// **'Tap to select GIF'**
  String get commonTapToSelectGif;

  /// No description provided for @commonPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get commonPreview;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get commonOriginal;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @commonOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get commonOptions;

  /// No description provided for @commonSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get commonSpeed;

  /// No description provided for @commonFontSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get commonFontSizeLabel;

  /// No description provided for @commonFileDimensions.
  ///
  /// In en, this message translates to:
  /// **'{width}×{height} px'**
  String commonFileDimensions(int width, int height);

  /// No description provided for @commonSaveLocationHint.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be asked to choose where to save the file.'**
  String get commonSaveLocationHint;

  /// No description provided for @homeSectionCreateOverline.
  ///
  /// In en, this message translates to:
  /// **'Start here'**
  String get homeSectionCreateOverline;

  /// No description provided for @homeSectionCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a GIF'**
  String get homeSectionCreateTitle;

  /// No description provided for @homeSectionRefineOverline.
  ///
  /// In en, this message translates to:
  /// **'Toolkit'**
  String get homeSectionRefineOverline;

  /// No description provided for @homeSectionRefineTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit & optimize'**
  String get homeSectionRefineTitle;

  /// No description provided for @homeDropUnsupported.
  ///
  /// In en, this message translates to:
  /// **'.{ext} is not supported. Drop a video or GIF.'**
  String homeDropUnsupported(String ext);

  /// No description provided for @homeDropVideoOrGif.
  ///
  /// In en, this message translates to:
  /// **'Drop video or GIF'**
  String get homeDropVideoOrGif;

  /// No description provided for @homeVersionBadge.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String homeVersionBadge(String version);

  /// No description provided for @homeDragDropHint.
  ///
  /// In en, this message translates to:
  /// **'Drag & drop a file anywhere to begin'**
  String get homeDragDropHint;

  /// No description provided for @homeRecentsOverline.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get homeRecentsOverline;

  /// No description provided for @homeRecentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent exports'**
  String get homeRecentsTitle;

  /// No description provided for @homeTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get homeTimeJustNow;

  /// No description provided for @homeTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String homeTimeMinutesAgo(int minutes);

  /// No description provided for @homeTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String homeTimeHoursAgo(int hours);

  /// No description provided for @homeTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String homeTimeDaysAgo(int days);

  /// No description provided for @toolVideoStudioLabel.
  ///
  /// In en, this message translates to:
  /// **'Video Studio'**
  String get toolVideoStudioLabel;

  /// No description provided for @toolVideoStudioDesc.
  ///
  /// In en, this message translates to:
  /// **'Crop, resize & speed — export as video or GIF'**
  String get toolVideoStudioDesc;

  /// No description provided for @toolImagesToGifLabel.
  ///
  /// In en, this message translates to:
  /// **'Images → GIF'**
  String get toolImagesToGifLabel;

  /// No description provided for @toolImagesToGifDesc.
  ///
  /// In en, this message translates to:
  /// **'Stitch a sequence of frames into a smooth loop'**
  String get toolImagesToGifDesc;

  /// No description provided for @toolScreenRecordLabel.
  ///
  /// In en, this message translates to:
  /// **'Screen Record'**
  String get toolScreenRecordLabel;

  /// No description provided for @toolScreenRecordDesc.
  ///
  /// In en, this message translates to:
  /// **'Capture your screen, then edit in Video Studio'**
  String get toolScreenRecordDesc;

  /// No description provided for @toolResizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get toolResizeLabel;

  /// No description provided for @toolResizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Scale to any resolution or preset'**
  String get toolResizeDesc;

  /// No description provided for @toolCropLabel.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get toolCropLabel;

  /// No description provided for @toolCropDesc.
  ///
  /// In en, this message translates to:
  /// **'Trim the frame with a draggable rect'**
  String get toolCropDesc;

  /// No description provided for @toolTextOverlayLabel.
  ///
  /// In en, this message translates to:
  /// **'Text Overlay'**
  String get toolTextOverlayLabel;

  /// No description provided for @toolTextOverlayDesc.
  ///
  /// In en, this message translates to:
  /// **'Add styled captions to any GIF'**
  String get toolTextOverlayDesc;

  /// No description provided for @toolOptimizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Optimize'**
  String get toolOptimizeLabel;

  /// No description provided for @toolOptimizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Compress for the smallest file size'**
  String get toolOptimizeDesc;

  /// No description provided for @toolEffectsLabel.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get toolEffectsLabel;

  /// No description provided for @toolEffectsDesc.
  ///
  /// In en, this message translates to:
  /// **'Reverse or change playback speed'**
  String get toolEffectsDesc;

  /// No description provided for @toolToWebmLabel.
  ///
  /// In en, this message translates to:
  /// **'To WebM'**
  String get toolToWebmLabel;

  /// No description provided for @toolToWebmDesc.
  ///
  /// In en, this message translates to:
  /// **'Convert video or GIF to WebM'**
  String get toolToWebmDesc;

  /// No description provided for @settingsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsScreenTitle;

  /// No description provided for @settingsSoftwarePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Software preview rendering'**
  String get settingsSoftwarePreviewTitle;

  /// No description provided for @settingsSoftwarePreviewDesc.
  ///
  /// In en, this message translates to:
  /// **'Fixes rare black flickering in the Video Studio preview on some GPUs. Uses more CPU and caps the preview at 1080p. Exports are never affected. Takes effect the next time you open the editor.'**
  String get settingsSoftwarePreviewDesc;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose the app display language.'**
  String get settingsLanguageDesc;

  /// No description provided for @settingsLanguageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystemDefault;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsAboutDesc.
  ///
  /// In en, this message translates to:
  /// **'Version, credits, and licenses'**
  String get settingsAboutDesc;

  /// No description provided for @cropAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop GIF'**
  String get cropAppBarTitle;

  /// No description provided for @cropStepCropArea.
  ///
  /// In en, this message translates to:
  /// **'Crop Area'**
  String get cropStepCropArea;

  /// No description provided for @cropStepCropAreaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drag corners to adjust · Drag inside to move'**
  String get cropStepCropAreaSubtitle;

  /// No description provided for @cropSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'{width}×{height}px'**
  String cropSizeLabel(int width, int height);

  /// No description provided for @cropCouldNotReadDims.
  ///
  /// In en, this message translates to:
  /// **'Could not read GIF dimensions — crop unavailable'**
  String get cropCouldNotReadDims;

  /// No description provided for @resizeAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Resize GIF'**
  String get resizeAppBarTitle;

  /// No description provided for @resizeStepOutputSize.
  ///
  /// In en, this message translates to:
  /// **'Output Size'**
  String get resizeStepOutputSize;

  /// No description provided for @resizePresetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get resizePresetsLabel;

  /// No description provided for @resizeCustomWidth.
  ///
  /// In en, this message translates to:
  /// **'Custom width'**
  String get resizeCustomWidth;

  /// No description provided for @resizeOutputLabel.
  ///
  /// In en, this message translates to:
  /// **'Output: {width}×{height}px'**
  String resizeOutputLabel(int width, int height);

  /// No description provided for @effectsAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get effectsAppBarTitle;

  /// No description provided for @effectsStepEffect.
  ///
  /// In en, this message translates to:
  /// **'Effect'**
  String get effectsStepEffect;

  /// No description provided for @effectsModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get effectsModeLabel;

  /// No description provided for @effectsReverseLabel.
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get effectsReverseLabel;

  /// No description provided for @effectsReverseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play backwards'**
  String get effectsReverseSubtitle;

  /// No description provided for @effectsSpeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change tempo'**
  String get effectsSpeedSubtitle;

  /// No description provided for @effectsSpeedSlower.
  ///
  /// In en, this message translates to:
  /// **'0.25×  slower'**
  String get effectsSpeedSlower;

  /// No description provided for @effectsSpeedFaster.
  ///
  /// In en, this message translates to:
  /// **'4×  faster'**
  String get effectsSpeedFaster;

  /// No description provided for @effectsSpeedLabelOriginal.
  ///
  /// In en, this message translates to:
  /// **'1× (original)'**
  String get effectsSpeedLabelOriginal;

  /// No description provided for @effectsSpeedLabelSlower.
  ///
  /// In en, this message translates to:
  /// **'{speed}× (slower)'**
  String effectsSpeedLabelSlower(String speed);

  /// No description provided for @effectsSpeedLabelFaster.
  ///
  /// In en, this message translates to:
  /// **'{speed}× (faster)'**
  String effectsSpeedLabelFaster(String speed);

  /// No description provided for @optimizeAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Optimize GIF'**
  String get optimizeAppBarTitle;

  /// No description provided for @optimizeStepCompression.
  ///
  /// In en, this message translates to:
  /// **'Compression'**
  String get optimizeStepCompression;

  /// No description provided for @optimizeColorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get optimizeColorsLabel;

  /// No description provided for @optimizeLossyLabel.
  ///
  /// In en, this message translates to:
  /// **'Lossy'**
  String get optimizeLossyLabel;

  /// No description provided for @optimizeRemoveFrames.
  ///
  /// In en, this message translates to:
  /// **'Remove frames'**
  String get optimizeRemoveFrames;

  /// No description provided for @optimizeKeepAll.
  ///
  /// In en, this message translates to:
  /// **'Keep all'**
  String get optimizeKeepAll;

  /// No description provided for @optimizeFrameDropQuarter.
  ///
  /// In en, this message translates to:
  /// **'1 / 4'**
  String get optimizeFrameDropQuarter;

  /// No description provided for @optimizeFrameDropThird.
  ///
  /// In en, this message translates to:
  /// **'1 / 3'**
  String get optimizeFrameDropThird;

  /// No description provided for @optimizeFrameDropHalf.
  ///
  /// In en, this message translates to:
  /// **'1 / 2'**
  String get optimizeFrameDropHalf;

  /// No description provided for @imagesToGifAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Images → GIF'**
  String get imagesToGifAppBarTitle;

  /// No description provided for @imagesStepSelectFrames.
  ///
  /// In en, this message translates to:
  /// **'Select Frames'**
  String get imagesStepSelectFrames;

  /// No description provided for @imagesStepSelectFramesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick images in the order you want them to play'**
  String get imagesStepSelectFramesSubtitle;

  /// No description provided for @imagesTapToSelectImages.
  ///
  /// In en, this message translates to:
  /// **'Tap to select images'**
  String get imagesTapToSelectImages;

  /// No description provided for @imagesFrameCountOne.
  ///
  /// In en, this message translates to:
  /// **'{count} frame'**
  String imagesFrameCountOne(int count);

  /// No description provided for @imagesFrameCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} frames'**
  String imagesFrameCountOther(int count);

  /// No description provided for @imagesAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add more'**
  String get imagesAddMore;

  /// No description provided for @imagesFrameRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Frame rate'**
  String get imagesFrameRateLabel;

  /// No description provided for @imagesWidthLabel.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get imagesWidthLabel;

  /// No description provided for @imagesStepCaption.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get imagesStepCaption;

  /// No description provided for @imagesStepCaptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional text drawn on every frame'**
  String get imagesStepCaptionSubtitle;

  /// No description provided for @imagesStepOptimizeGif.
  ///
  /// In en, this message translates to:
  /// **'Optimise GIF'**
  String get imagesStepOptimizeGif;

  /// No description provided for @imagesStepOptimizeGifSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce colors and file size'**
  String get imagesStepOptimizeGifSubtitle;

  /// No description provided for @imagesNoFontWarning.
  ///
  /// In en, this message translates to:
  /// **'No system font found. Text overlay may fail.'**
  String get imagesNoFontWarning;

  /// No description provided for @imagesCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to skip…'**
  String get imagesCaptionHint;

  /// No description provided for @imagesPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get imagesPositionLabel;

  /// No description provided for @imagesPositionTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get imagesPositionTop;

  /// No description provided for @imagesPositionCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get imagesPositionCenter;

  /// No description provided for @imagesPositionBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get imagesPositionBottom;

  /// No description provided for @imagesColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get imagesColorLabel;

  /// No description provided for @imagesColorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get imagesColorWhite;

  /// No description provided for @imagesColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get imagesColorYellow;

  /// No description provided for @imagesColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get imagesColorBlack;

  /// No description provided for @imagesColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get imagesColorRed;

  /// No description provided for @imagesOptimizeToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Optimise output GIF'**
  String get imagesOptimizeToggleLabel;

  /// No description provided for @textOverlayAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Text Overlay'**
  String get textOverlayAppBarTitle;

  /// No description provided for @textOverlayStepEditText.
  ///
  /// In en, this message translates to:
  /// **'Edit Text'**
  String get textOverlayStepEditText;

  /// No description provided for @textOverlayStepEditTextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drag to position · tap to select'**
  String get textOverlayStepEditTextSubtitle;

  /// No description provided for @textOverlayCannotReadDims.
  ///
  /// In en, this message translates to:
  /// **'Cannot read dimensions'**
  String get textOverlayCannotReadDims;

  /// No description provided for @textOverlayFontWarning.
  ///
  /// In en, this message translates to:
  /// **'No system font found. Text rendering may fail on Generate.'**
  String get textOverlayFontWarning;

  /// No description provided for @textOverlayTextFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Text…'**
  String get textOverlayTextFieldHint;

  /// No description provided for @textOverlayStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get textOverlayStyleLabel;

  /// No description provided for @textOverlayFontLabel.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get textOverlayFontLabel;

  /// No description provided for @textOverlayFillLabel.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get textOverlayFillLabel;

  /// No description provided for @textOverlayStrokeLabel.
  ///
  /// In en, this message translates to:
  /// **'Stroke'**
  String get textOverlayStrokeLabel;

  /// No description provided for @textOverlayStrokeWidthLabel.
  ///
  /// In en, this message translates to:
  /// **'Stroke Width'**
  String get textOverlayStrokeWidthLabel;

  /// No description provided for @textOverlayLayersTitle.
  ///
  /// In en, this message translates to:
  /// **'Text Layers'**
  String get textOverlayLayersTitle;

  /// No description provided for @textOverlayNoTextYet.
  ///
  /// In en, this message translates to:
  /// **'No text yet. Tap “Add” to create one.'**
  String get textOverlayNoTextYet;

  /// No description provided for @textOverlayAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get textOverlayAdd;

  /// No description provided for @textOverlayEmptyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get textOverlayEmptyPlaceholder;

  /// No description provided for @webmAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'To WebM'**
  String get webmAppBarTitle;

  /// No description provided for @webmRejectedToastOne.
  ///
  /// In en, this message translates to:
  /// **'{count} file skipped — 20 max per batch'**
  String webmRejectedToastOne(int count);

  /// No description provided for @webmRejectedToastOther.
  ///
  /// In en, this message translates to:
  /// **'{count} files skipped — 20 max per batch'**
  String webmRejectedToastOther(int count);

  /// No description provided for @webmSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get webmSavedToast;

  /// No description provided for @webmExportedToastOne.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} file'**
  String webmExportedToastOne(int count);

  /// No description provided for @webmExportedToastOther.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} files'**
  String webmExportedToastOther(int count);

  /// No description provided for @webmStepSelectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select files'**
  String get webmStepSelectFiles;

  /// No description provided for @webmDropHint.
  ///
  /// In en, this message translates to:
  /// **'Drop or tap to select videos/GIFs (max 20)'**
  String get webmDropHint;

  /// No description provided for @webmStepConvert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get webmStepConvert;

  /// No description provided for @webmCodecLabel.
  ///
  /// In en, this message translates to:
  /// **'Codec'**
  String get webmCodecLabel;

  /// No description provided for @webmVp9.
  ///
  /// In en, this message translates to:
  /// **'VP9'**
  String get webmVp9;

  /// No description provided for @webmVp9Sub.
  ///
  /// In en, this message translates to:
  /// **'recommended'**
  String get webmVp9Sub;

  /// No description provided for @webmAv1.
  ///
  /// In en, this message translates to:
  /// **'AV1'**
  String get webmAv1;

  /// No description provided for @webmAv1Sub.
  ///
  /// In en, this message translates to:
  /// **'smallest · slower'**
  String get webmAv1Sub;

  /// No description provided for @webmQualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quality (CRF)'**
  String get webmQualityLabel;

  /// No description provided for @webmSharperBigger.
  ///
  /// In en, this message translates to:
  /// **'18  sharper, bigger'**
  String get webmSharperBigger;

  /// No description provided for @webmSmallerSofter.
  ///
  /// In en, this message translates to:
  /// **'45  smaller, softer'**
  String get webmSmallerSofter;

  /// No description provided for @webmFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get webmFast;

  /// No description provided for @webmBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get webmBalanced;

  /// No description provided for @webmBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get webmBest;

  /// No description provided for @webmMaxWidth.
  ///
  /// In en, this message translates to:
  /// **'Max width'**
  String get webmMaxWidth;

  /// No description provided for @webmKeepTransparency.
  ///
  /// In en, this message translates to:
  /// **'Keep transparency'**
  String get webmKeepTransparency;

  /// No description provided for @webmProbing.
  ///
  /// In en, this message translates to:
  /// **'probing…'**
  String get webmProbing;

  /// No description provided for @webmConversionFailed.
  ///
  /// In en, this message translates to:
  /// **'Conversion failed'**
  String get webmConversionFailed;

  /// No description provided for @webmQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get webmQueued;

  /// No description provided for @webmConverting.
  ///
  /// In en, this message translates to:
  /// **'Converting'**
  String get webmConverting;

  /// No description provided for @webmDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get webmDone;

  /// No description provided for @webmError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get webmError;

  /// No description provided for @webmConvertingProgress.
  ///
  /// In en, this message translates to:
  /// **'Converting {done} of {total} · {percent}%'**
  String webmConvertingProgress(int done, int total, int percent);

  /// No description provided for @webmConvertButton.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get webmConvertButton;

  /// No description provided for @webmExportAll.
  ///
  /// In en, this message translates to:
  /// **'Export all ({count})'**
  String webmExportAll(int count);

  /// No description provided for @webmExportSingle.
  ///
  /// In en, this message translates to:
  /// **'Export WebM'**
  String get webmExportSingle;

  /// No description provided for @recordAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen Record'**
  String get recordAppBarTitle;

  /// No description provided for @recordFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load Screen Record: {error}'**
  String recordFailedToLoad(String error);

  /// No description provided for @recordStepSelectMonitor.
  ///
  /// In en, this message translates to:
  /// **'Select a monitor'**
  String get recordStepSelectMonitor;

  /// No description provided for @recordStepRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get recordStepRecord;

  /// No description provided for @recordButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get recordButtonLabel;

  /// No description provided for @recordMaxDuration.
  ///
  /// In en, this message translates to:
  /// **'Max 10:00'**
  String get recordMaxDuration;

  /// No description provided for @recordPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get recordPaused;

  /// No description provided for @recordRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordRecording;

  /// No description provided for @recordElapsedOfMax.
  ///
  /// In en, this message translates to:
  /// **'{elapsed} / 10:00'**
  String recordElapsedOfMax(String elapsed);

  /// No description provided for @recordResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get recordResume;

  /// No description provided for @recordPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get recordPause;

  /// No description provided for @recordStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get recordStop;

  /// No description provided for @recordHotkeyStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get recordHotkeyStart;

  /// No description provided for @recordHotkeyPauseResume.
  ///
  /// In en, this message translates to:
  /// **'Pause / Resume'**
  String get recordHotkeyPauseResume;

  /// No description provided for @recordAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get recordAudio;

  /// No description provided for @recordSystemAudio.
  ///
  /// In en, this message translates to:
  /// **'System audio'**
  String get recordSystemAudio;

  /// No description provided for @recordDefaultOutputDevice.
  ///
  /// In en, this message translates to:
  /// **'Default output device'**
  String get recordDefaultOutputDevice;

  /// No description provided for @recordMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get recordMicrophone;

  /// No description provided for @recordNoMicFound.
  ///
  /// In en, this message translates to:
  /// **'No microphone found'**
  String get recordNoMicFound;

  /// No description provided for @recordDefaultInputDevice.
  ///
  /// In en, this message translates to:
  /// **'Default input device'**
  String get recordDefaultInputDevice;

  /// No description provided for @recordEditHotkeyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit hotkey'**
  String get recordEditHotkeyTooltip;

  /// No description provided for @recordPressKeysFor.
  ///
  /// In en, this message translates to:
  /// **'Press keys for \"{label}\"'**
  String recordPressKeysFor(String label);

  /// No description provided for @recordSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get recordSave;

  /// No description provided for @recordHotkeyConflict.
  ///
  /// In en, this message translates to:
  /// **'That combo conflicts with another Screen Record hotkey, or is already taken by another app.'**
  String get recordHotkeyConflict;

  /// No description provided for @recordNoDisplays.
  ///
  /// In en, this message translates to:
  /// **'No displays detected'**
  String get recordNoDisplays;

  /// No description provided for @recordDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get recordDisplay;

  /// No description provided for @recordSelectDisplay.
  ///
  /// In en, this message translates to:
  /// **'Select a display'**
  String get recordSelectDisplay;

  /// No description provided for @recordOutputSize.
  ///
  /// In en, this message translates to:
  /// **'Output size'**
  String get recordOutputSize;

  /// No description provided for @recordStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get recordStorage;

  /// No description provided for @recordSaveLocation.
  ///
  /// In en, this message translates to:
  /// **'Save location'**
  String get recordSaveLocation;

  /// No description provided for @recordDefaultTempFolder.
  ///
  /// In en, this message translates to:
  /// **'Default (temp folder)'**
  String get recordDefaultTempFolder;

  /// No description provided for @recordChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get recordChoose;

  /// No description provided for @recordResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get recordResetToDefault;

  /// No description provided for @recordDeleteTempOnExit.
  ///
  /// In en, this message translates to:
  /// **'Delete temporary video on exit'**
  String get recordDeleteTempOnExit;

  /// No description provided for @recordChooseFolderDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose folder for recorded video'**
  String get recordChooseFolderDialogTitle;

  /// No description provided for @sharedFileDropDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to select files'**
  String get sharedFileDropDefaultHint;

  /// No description provided for @sharedFileDropAnyFile.
  ///
  /// In en, this message translates to:
  /// **'Any file'**
  String get sharedFileDropAnyFile;

  /// No description provided for @sharedExportAndSave.
  ///
  /// In en, this message translates to:
  /// **'Export & Save'**
  String get sharedExportAndSave;

  /// No description provided for @sharedPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get sharedPreviewUnavailable;

  /// No description provided for @sharedPerFramePalettes.
  ///
  /// In en, this message translates to:
  /// **'Per-frame palettes'**
  String get sharedPerFramePalettes;

  /// No description provided for @sharedPerFramePalettesDesc.
  ///
  /// In en, this message translates to:
  /// **'Lossless extra compression, slower'**
  String get sharedPerFramePalettesDesc;

  /// No description provided for @studioStartOverLabel.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get studioStartOverLabel;

  /// No description provided for @studioStartOverDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Start over?'**
  String get studioStartOverDialogTitle;

  /// No description provided for @studioStartOverDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'This discards the loaded file and all edits.'**
  String get studioStartOverDialogMessage;

  /// No description provided for @studioRenderingGif.
  ///
  /// In en, this message translates to:
  /// **'Rendering GIF…'**
  String get studioRenderingGif;

  /// No description provided for @studioEncoding.
  ///
  /// In en, this message translates to:
  /// **'Encoding…'**
  String get studioEncoding;

  /// No description provided for @studioTapToSelectVideoOrGif.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a video or GIF'**
  String get studioTapToSelectVideoOrGif;

  /// No description provided for @studioEditingGif.
  ///
  /// In en, this message translates to:
  /// **'Editing GIF'**
  String get studioEditingGif;

  /// No description provided for @studioEditingVideo.
  ///
  /// In en, this message translates to:
  /// **'Editing video'**
  String get studioEditingVideo;

  /// No description provided for @studioAudioLabel.
  ///
  /// In en, this message translates to:
  /// **'audio'**
  String get studioAudioLabel;

  /// No description provided for @studioNoAudioLabel.
  ///
  /// In en, this message translates to:
  /// **'no audio'**
  String get studioNoAudioLabel;

  /// No description provided for @studioChangeButton.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get studioChangeButton;

  /// No description provided for @studioZoomFit.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get studioZoomFit;

  /// No description provided for @studioZoomFitToWindow.
  ///
  /// In en, this message translates to:
  /// **'Fit to window'**
  String get studioZoomFitToWindow;

  /// No description provided for @studioZoomTooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get studioZoomTooltip;

  /// No description provided for @studioCompareLabel.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get studioCompareLabel;

  /// No description provided for @studioOriginalBadge.
  ///
  /// In en, this message translates to:
  /// **'ORIGINAL'**
  String get studioOriginalBadge;

  /// No description provided for @studioCutBadge.
  ///
  /// In en, this message translates to:
  /// **'CUT'**
  String get studioCutBadge;

  /// No description provided for @studioPositionOfDuration.
  ///
  /// In en, this message translates to:
  /// **'{position} / {duration}'**
  String studioPositionOfDuration(String position, String duration);

  /// No description provided for @studioToolTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get studioToolTrim;

  /// No description provided for @studioToolCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get studioToolCut;

  /// No description provided for @studioToolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get studioToolText;

  /// No description provided for @studioToolOptimize.
  ///
  /// In en, this message translates to:
  /// **'Optimise'**
  String get studioToolOptimize;

  /// No description provided for @studioToolProps.
  ///
  /// In en, this message translates to:
  /// **'Props'**
  String get studioToolProps;

  /// No description provided for @studioCropDragHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the handles on the preview to crop'**
  String get studioCropDragHint;

  /// No description provided for @studioPlaybackSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get studioPlaybackSpeedLabel;

  /// No description provided for @studioTrimInLabel.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get studioTrimInLabel;

  /// No description provided for @studioTrimClipLabel.
  ///
  /// In en, this message translates to:
  /// **'Clip'**
  String get studioTrimClipLabel;

  /// No description provided for @studioTrimOutLabel.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get studioTrimOutLabel;

  /// No description provided for @studioGifCappedFpsHint.
  ///
  /// In en, this message translates to:
  /// **'GIF will be capped at {maxFps} fps for this length.'**
  String studioGifCappedFpsHint(int maxFps);

  /// No description provided for @studioCutFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get studioCutFromLabel;

  /// No description provided for @studioCutToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get studioCutToLabel;

  /// No description provided for @studioCantAddSegment.
  ///
  /// In en, this message translates to:
  /// **'Can\'t add that segment'**
  String get studioCantAddSegment;

  /// No description provided for @studioMarkForRemoval.
  ///
  /// In en, this message translates to:
  /// **'Mark for removal'**
  String get studioMarkForRemoval;

  /// No description provided for @studioMarkSpanHint.
  ///
  /// In en, this message translates to:
  /// **'Mark a span to remove it'**
  String get studioMarkSpanHint;

  /// No description provided for @studioCutOutputLabel.
  ///
  /// In en, this message translates to:
  /// **'Output ≈ {duration}'**
  String studioCutOutputLabel(String duration);

  /// No description provided for @studioNoFontWarning.
  ///
  /// In en, this message translates to:
  /// **'No system font found. Text may fail to render.'**
  String get studioNoFontWarning;

  /// No description provided for @studioScaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get studioScaleLabel;

  /// No description provided for @studioScaleSmaller.
  ///
  /// In en, this message translates to:
  /// **'10% smaller'**
  String get studioScaleSmaller;

  /// No description provided for @studioScaleLarger.
  ///
  /// In en, this message translates to:
  /// **'200% larger'**
  String get studioScaleLarger;

  /// No description provided for @studioFrameRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Frame rate'**
  String get studioFrameRateLabel;

  /// No description provided for @studioCappedFpsHint.
  ///
  /// In en, this message translates to:
  /// **'Capped at {maxFps} fps for this length.'**
  String studioCappedFpsHint(int maxFps);

  /// No description provided for @studioGifCappedWidthHint.
  ///
  /// In en, this message translates to:
  /// **'GIF capped at {width}px wide'**
  String studioGifCappedWidthHint(int width);

  /// No description provided for @studioIgnoreGifSizeLimit.
  ///
  /// In en, this message translates to:
  /// **'Ignore GIF size limit'**
  String get studioIgnoreGifSizeLimit;

  /// No description provided for @studioFullSizeSlowWarning.
  ///
  /// In en, this message translates to:
  /// **'Full size may run slow'**
  String get studioFullSizeSlowWarning;

  /// No description provided for @studioMakeGifButton.
  ///
  /// In en, this message translates to:
  /// **'Make GIF'**
  String get studioMakeGifButton;

  /// No description provided for @studioVideoTooLongTitle.
  ///
  /// In en, this message translates to:
  /// **'Video too long'**
  String get studioVideoTooLongTitle;

  /// No description provided for @studioGifLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'GIF is limited to 40 seconds. Trim the video first for best results, or only the first 40 seconds will be used.'**
  String get studioGifLimitMessage;

  /// No description provided for @studioUseFirst40s.
  ///
  /// In en, this message translates to:
  /// **'Use first 40s'**
  String get studioUseFirst40s;

  /// No description provided for @studioCouldNotCreateGif.
  ///
  /// In en, this message translates to:
  /// **'Could not create GIF'**
  String get studioCouldNotCreateGif;

  /// No description provided for @studioWebmConvertHint.
  ///
  /// In en, this message translates to:
  /// **'Converts this GIF to a WebM video, then switches to video editing. One-way — there is no going back to the GIF.'**
  String get studioWebmConvertHint;

  /// No description provided for @studioConvertToWebmButton.
  ///
  /// In en, this message translates to:
  /// **'Convert to WebM'**
  String get studioConvertToWebmButton;

  /// No description provided for @studioCouldNotConvertWebm.
  ///
  /// In en, this message translates to:
  /// **'Could not convert to WebM'**
  String get studioCouldNotConvertWebm;

  /// No description provided for @studioSmoothLoopLabel.
  ///
  /// In en, this message translates to:
  /// **'Smooth Loop — crossfade last {ms}ms into first {ms}ms'**
  String studioSmoothLoopLabel(int ms);

  /// No description provided for @studioNounClips.
  ///
  /// In en, this message translates to:
  /// **'Clips'**
  String get studioNounClips;

  /// No description provided for @studioNounGifs.
  ///
  /// In en, this message translates to:
  /// **'GIFs'**
  String get studioNounGifs;

  /// No description provided for @studioLoopMinLengthHint.
  ///
  /// In en, this message translates to:
  /// **'{noun} longer than 3s only.'**
  String studioLoopMinLengthHint(String noun);

  /// No description provided for @studioCrossfadeTooShort.
  ///
  /// In en, this message translates to:
  /// **'Speed/trim leave too little to crossfade — turn Smooth Loop off.'**
  String get studioCrossfadeTooShort;

  /// No description provided for @studioLoopsSeamlessly.
  ///
  /// In en, this message translates to:
  /// **'Loops seamlessly by dissolving the tail into the head.'**
  String get studioLoopsSeamlessly;

  /// No description provided for @studioCrossfadeDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Crossfade duration'**
  String get studioCrossfadeDurationLabel;

  /// No description provided for @studioVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get studioVolumeLabel;

  /// No description provided for @studioNoAudioCaption.
  ///
  /// In en, this message translates to:
  /// **'No audio'**
  String get studioNoAudioCaption;

  /// No description provided for @studioVolumeHint.
  ///
  /// In en, this message translates to:
  /// **'100% = original · 0% mutes · up to 200% louder.'**
  String get studioVolumeHint;

  /// No description provided for @studioNoAudioTrackHint.
  ///
  /// In en, this message translates to:
  /// **'This video has no audio track.'**
  String get studioNoAudioTrackHint;

  /// No description provided for @studioFpsLowerHint.
  ///
  /// In en, this message translates to:
  /// **'Lowering re-times the GIF; you can\'t add frames back.'**
  String get studioFpsLowerHint;

  /// No description provided for @studioFpsHigherHint.
  ///
  /// In en, this message translates to:
  /// **'Higher = smoother but larger.'**
  String get studioFpsHigherHint;

  /// No description provided for @studioLoopsLabel.
  ///
  /// In en, this message translates to:
  /// **'Loops'**
  String get studioLoopsLabel;

  /// No description provided for @studioPlaysForever.
  ///
  /// In en, this message translates to:
  /// **'Plays forever'**
  String get studioPlaysForever;

  /// No description provided for @studioPlaysThenRepeats.
  ///
  /// In en, this message translates to:
  /// **'Plays then repeats {count}×'**
  String studioPlaysThenRepeats(int count);

  /// No description provided for @studioBoomerangLabel.
  ///
  /// In en, this message translates to:
  /// **'Boomerang — reverse for a seamless loop'**
  String get studioBoomerangLabel;

  /// No description provided for @studioBackToVideoButton.
  ///
  /// In en, this message translates to:
  /// **'Back to video'**
  String get studioBackToVideoButton;

  /// No description provided for @studioDiscardGifTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard GIF edits?'**
  String get studioDiscardGifTitle;

  /// No description provided for @studioDiscardGifMessage.
  ///
  /// In en, this message translates to:
  /// **'Going back will discard all changes made to the GIF.'**
  String get studioDiscardGifMessage;

  /// No description provided for @studioDiscardButton.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get studioDiscardButton;

  /// No description provided for @studioUndoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get studioUndoTooltip;

  /// No description provided for @studioNothingToUndo.
  ///
  /// In en, this message translates to:
  /// **'Nothing to undo'**
  String get studioNothingToUndo;

  /// No description provided for @studioRedoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get studioRedoTooltip;

  /// No description provided for @studioNothingToRedo.
  ///
  /// In en, this message translates to:
  /// **'Nothing to redo'**
  String get studioNothingToRedo;

  /// No description provided for @studioApplyButton.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get studioApplyButton;

  /// No description provided for @studioAppliedToPreview.
  ///
  /// In en, this message translates to:
  /// **'Applied to preview'**
  String get studioAppliedToPreview;

  /// No description provided for @studioExportButton.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get studioExportButton;

  /// No description provided for @studioGifSaved.
  ///
  /// In en, this message translates to:
  /// **'GIF saved'**
  String get studioGifSaved;

  /// No description provided for @studioExportVideoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export Video'**
  String get studioExportVideoTooltip;

  /// No description provided for @studioWebmSaved.
  ///
  /// In en, this message translates to:
  /// **'WebM saved'**
  String get studioWebmSaved;

  /// No description provided for @studioVideoSaved.
  ///
  /// In en, this message translates to:
  /// **'Video saved'**
  String get studioVideoSaved;

  /// No description provided for @studioCutUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Duration unknown — cut unavailable'**
  String get studioCutUnavailable;

  /// No description provided for @studioTrimUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Duration unknown — trim unavailable'**
  String get studioTrimUnavailable;

  /// No description provided for @studioExportFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Format'**
  String get studioExportFormatTitle;

  /// No description provided for @studioFormatOriginalTitle.
  ///
  /// In en, this message translates to:
  /// **'Original ({ext})'**
  String studioFormatOriginalTitle(String ext);

  /// No description provided for @studioFormatOriginalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save as-is · no re-encode · fastest'**
  String get studioFormatOriginalSubtitle;

  /// No description provided for @studioFormatMp4Subtitle.
  ///
  /// In en, this message translates to:
  /// **'H.264 · best compatibility · hardware-accelerated'**
  String get studioFormatMp4Subtitle;

  /// No description provided for @studioFormatWebmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'VP9 · smaller files · web-friendly'**
  String get studioFormatWebmSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'fr',
    'ja',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
