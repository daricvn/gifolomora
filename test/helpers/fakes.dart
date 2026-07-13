import 'dart:io';

import 'package:gifolomora/core/services/ffmpeg/ffmpeg_backend.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_service.dart';
import 'package:gifolomora/core/services/files/export_service.dart';
import 'package:gifolomora/core/services/files/temp_file_service.dart';
import 'package:gifolomora/core/services/recents/recents_service.dart';
import 'package:gifolomora/core/utils/result.dart';
import 'package:gifolomora/features/text_overlay/model/text_item.dart';

class FakeFfmpegBackend implements FfmpegBackend {
  Result<File, FfmpegError> nextResult = Ok(File('/fake/output.gif'));
  MediaInfo? nextProbeResult;
  bool cancelCalled = false;
  int runCount = 0;
  List<String>? lastRunArgs;

  @override
  Future<Result<File, FfmpegError>> run(
    List<String> args,
    String outputPath, {
    void Function(FfmpegProgress)? onProgress,
    int? totalFrames,
    int? totalMs,
  }) async {
    runCount++;
    lastRunArgs = args;
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return nextResult;
  }

  @override
  Future<MediaInfo?> probe(String inputPath) async => nextProbeResult;

  bool nextSupportsEncoder = false;
  int supportsEncoderCallCount = 0;
  String? lastSupportsEncoderArg;

  @override
  Future<bool> supportsEncoder(String encoderName) async {
    supportsEncoderCallCount++;
    lastSupportsEncoderArg = encoderName;
    return nextSupportsEncoder;
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
  }

  @override
  void dispose() {}
}

class _NoOpTempFileService extends TempFileService {
  @override
  Future<String> createJobDir({String? baseDirOverride}) async => '/fake/job';

  @override
  Future<String> tempOutputPath(String jobDir, String ext) async =>
      '$jobDir/output.$ext';

  @override
  Future<List<String>> copyFrames(List<File> frames, String jobDir) async =>
      frames.map((f) => f.path).toList();

  @override
  Future<void> cleanJob(String jobDir) async {}

  @override
  Future<void> sweepStale(
      {Duration maxAge = const Duration(hours: 1)}) async {}
}

/// FfmpegService backed by FakeFfmpegBackend — no real FFmpeg, no file I/O.
class FakeFfmpegService extends FfmpegService {
  FakeFfmpegService(this.fakeBackend)
      : super(fakeBackend, _NoOpTempFileService());

  final FakeFfmpegBackend fakeBackend;

  @override
  Future<Result<File, FfmpegError>> imagesToGif({
    required List<File> frames,
    int fps = 15,
    int? width,
    void Function(FfmpegProgress)? onProgress,
  }) async {
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return fakeBackend.nextResult;
  }

  @override
  Future<Result<File, FfmpegError>> videoToGif({
    required File input,
    Duration? start,
    Duration? duration,
    int fps = 15,
    int? width,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return fakeBackend.nextResult;
  }

  @override
  Future<Result<File, FfmpegError>> resizeGif({
    required File input,
    int? width,
    int? height,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return fakeBackend.nextResult;
  }

  @override
  Future<Result<File, FfmpegError>> cropGif({
    required File input,
    required int x,
    required int y,
    required int cropWidth,
    required int cropHeight,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return fakeBackend.nextResult;
  }

  @override
  Future<Result<File, FfmpegError>> optimizeGif({
    required File input,
    int colors = 128,
    int lossy = 40,
    int? loopCount,
    int frameDrop = 0,
    bool localPalettes = false,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return fakeBackend.nextResult;
  }

  @override
  Future<Result<File, FfmpegError>> textOverlay({
    required File input,
    required String text,
    required String fontFile,
    int fontSize = 36,
    String fontColor = 'white',
    String position = 'center',
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return fakeBackend.nextResult;
  }

  @override
  Future<Result<File, FfmpegError>> textOverlayMulti({
    required File input,
    required List<TextItem> items,
    required MediaInfo mediaInfo,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return fakeBackend.nextResult;
  }

  @override
  Future<Result<File, FfmpegError>> reverseGif({
    required File input,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return fakeBackend.nextResult;
  }

  @override
  Future<Result<File, FfmpegError>> changeSpeed({
    required File input,
    required double factor,
    void Function(FfmpegProgress)? onProgress,
    int? totalMs,
  }) async {
    onProgress?.call(const FfmpegProgress(fraction: 1.0));
    return fakeBackend.nextResult;
  }

  @override
  Future<MediaInfo?> probe(File file) async => fakeBackend.nextProbeResult;

  @override
  Future<void> cleanCurrentJob() async {}

  @override
  Future<void> cancel() => fakeBackend.cancel();
}

/// ExportService that returns a fake File without opening the file picker.
class FakeExportService extends ExportService {
  File? returnFile = File('/fake/export/output.gif');

  @override
  Future<File?> saveGif(File tempFile,
      {String defaultName = 'animated.gif'}) async {
    return returnFile;
  }

  /// Records the temp file handed to the last saveVideo call.
  File? savedVideoSource;

  @override
  Future<File?> saveVideo(File tempFile,
      {String defaultName = 'edited.mp4', String extension = 'mp4'}) async {
    savedVideoSource = tempFile;
    return returnFile;
  }

  /// Records the temp file handed to the last saveWebm call.
  File? savedWebmSource;

  @override
  Future<File?> saveWebm(File tempFile,
      {String defaultName = 'converted.webm'}) async {
    savedWebmSource = tempFile;
    return returnFile;
  }

  Directory? returnDirectory;

  @override
  Future<Directory?> saveWebmBatch(List<MapEntry<File, String>> items) async =>
      returnDirectory;
}

/// RecentsService backed by an in-memory list — no SharedPreferences.
class FakeRecentsService extends RecentsService {
  final items = <RecentExport>[];

  @override
  Future<List<RecentExport>> load() async => List.unmodifiable(items);

  @override
  Future<void> add(RecentExport item) async {
    items.insert(0, item);
    if (items.length > 10) items.removeLast();
  }

  @override
  Future<void> clear() async => items.clear();
}
