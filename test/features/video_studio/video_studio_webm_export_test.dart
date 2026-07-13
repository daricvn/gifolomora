import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/providers.dart';
import 'package:gifolomora/core/utils/result.dart';
import 'package:gifolomora/features/video_studio/controller/video_studio_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

VideoStudioState _state(ProviderContainer c) =>
    c.read(videoStudioControllerProvider).value!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeFfmpegBackend backend;
  late FakeExportService export;
  late ProviderContainer c;

  Future<VideoStudioController> loadVideo({bool hasAudio = false}) async {
    await c.read(videoStudioControllerProvider.future);
    final ctrl = c.read(videoStudioControllerProvider.notifier);
    await ctrl.setInput(File('/input.mp4'));
    return ctrl;
  }

  setUp(() {
    backend = FakeFfmpegBackend()
      ..nextResult = Ok(File('/fake/output.webm'))
      ..nextProbeResult = const MediaInfo(
          durationMs: 5000, width: 320, height: 240, hasAudio: true);
    export = FakeExportService();
    c = ProviderContainer(overrides: [
      ffmpegServiceProvider.overrideWithValue(FakeFfmpegService(backend)),
      exportServiceProvider.overrideWithValue(export),
      recentsServiceProvider.overrideWithValue(FakeRecentsService()),
    ]);
  });

  tearDown(() => c.dispose());

  group('exportVideo(format: webm) — editsApplied fast path', () {
    test('after Apply, WebM export reuses the baked source via convertToWebm (real encode, not stream-copy)',
        () async {
      final ctrl = await loadVideo();
      ctrl.setResize(160);
      await ctrl.applyVideoEdits();
      expect(_state(c).editsApplied, isTrue);
      final bakedPath = _state(c).sourceFile!.path;

      final ok =
          await ctrl.exportVideo(format: ExportVideoFormat.webm);

      expect(ok, isTrue);
      expect(export.savedWebmSource, isNotNull);
      // convertToWebm always builds a VP9/AV1 arg set — never '-c copy'.
      expect(backend.lastRunArgs, isNot(contains('copy')));
      expect(backend.lastRunArgs, contains('libvpx-vp9'));
      // Sanity: the baked (post-Apply) file is what got fed to the encode,
      // not the original input.
      expect(bakedPath, isNot(equals('/input.mp4')));
    });

    test('adds a recents entry on successful webm save', () async {
      final ctrl = await loadVideo();
      ctrl.setResize(160);
      await ctrl.applyVideoEdits();

      await ctrl.exportVideo(format: ExportVideoFormat.webm);

      final recents = c.read(recentsServiceProvider) as FakeRecentsService;
      expect(recents.items, isNotEmpty);
      expect(recents.items.first.toolName, equals('Video Studio'));
    });

    test('export failure (backend Err) sets error, isProcessing false, no recent added',
        () async {
      final ctrl = await loadVideo();
      ctrl.setResize(160);
      await ctrl.applyVideoEdits();
      backend.nextResult = const Err(FfmpegError(message: 'webm encode failed'));

      final ok = await ctrl.exportVideo(format: ExportVideoFormat.webm);

      expect(ok, isFalse);
      expect(_state(c).isProcessing, isFalse);
      expect(_state(c).error, equals('webm encode failed'));
      final recents = c.read(recentsServiceProvider) as FakeRecentsService;
      expect(recents.items, isEmpty);
    });
  });

  group('exportVideo(format: webm) — pending edits path', () {
    test('with no edits applied yet, WebM export runs editVideo(webm:true), never stream-copy',
        () async {
      final ctrl = await loadVideo();
      // No edits set — an mp4 export in this state would take the isNoOp
      // stream-copy shortcut; webm must not.

      final ok = await ctrl.exportVideo(format: ExportVideoFormat.webm);

      expect(ok, isTrue);
      expect(backend.lastRunArgs, isNot(contains('copy')));
      expect(backend.lastRunArgs, contains('libvpx-vp9'));
      expect(export.savedWebmSource, isNotNull);
    });

    test('with pending (unapplied) crop/resize edits, WebM export bakes them into the encode',
        () async {
      final ctrl = await loadVideo();
      ctrl.setResize(160);
      expect(_state(c).editsApplied, isFalse);

      final ok = await ctrl.exportVideo(format: ExportVideoFormat.webm);

      expect(ok, isTrue);
      expect(backend.lastRunArgs, contains('libvpx-vp9'));
    });
  });

  group('exportVideo(format: mp4) — unaffected regression guard', () {
    test('mp4 export with no edits still takes the stream-copy no-op path', () async {
      backend.nextResult = Ok(File('/fake/output.mp4'));
      final ctrl = await loadVideo();

      final ok = await ctrl.exportVideo(); // defaults to mp4

      expect(ok, isTrue);
      expect(backend.lastRunArgs, contains('copy'));
      expect(backend.lastRunArgs, isNot(contains('libvpx-vp9')));
      expect(export.savedVideoSource, isNotNull);
    });
  });

  group('exportVideo(format: original) — untouched save-as-is', () {
    test('copies the source file directly, no ffmpeg run', () async {
      final ctrl = await loadVideo();

      final ok = await ctrl.exportVideo(format: ExportVideoFormat.original);

      expect(ok, isTrue);
      expect(export.savedVideoSource!.path, equals('/input.mp4'));
      expect(backend.runCount, equals(0));
    });

    test('originalExportExt: basename extension only — a dotted directory or extension-less file yields null',
        () async {
      final ctrl = await loadVideo();
      expect(_state(c).originalExportExt, equals('mp4'));

      // Dotted dir, no file extension: lastIndexOf('.') would have said "0/clip".
      await ctrl.setInput(File('/v2.0/clip'));
      expect(_state(c).originalExportExt, isNull);
    });

    test('gate: hasComparableEdit false when untouched, true once an edit is pending or applied',
        () async {
      final ctrl = await loadVideo();
      expect(_state(c).hasComparableEdit, isFalse);

      ctrl.setResize(160);
      expect(_state(c).hasComparableEdit, isTrue);

      await ctrl.applyVideoEdits();
      // Applied (baked) still counts as modified — card must stay hidden.
      expect(_state(c).hasComparableEdit, isTrue);
    });
  });

  group('lastExportFormat persistence', () {
    test('setLastExportFormat persists across a controller rebuild', () async {
      await loadVideo();
      final ctrl = c.read(videoStudioControllerProvider.notifier);
      expect(ctrl.lastExportFormat, equals(ExportVideoFormat.mp4));

      await ctrl.setLastExportFormat(ExportVideoFormat.webm);
      expect(ctrl.lastExportFormat, equals(ExportVideoFormat.webm));

      final c2 = ProviderContainer(overrides: [
        ffmpegServiceProvider.overrideWithValue(FakeFfmpegService(backend)),
        exportServiceProvider.overrideWithValue(export),
        recentsServiceProvider.overrideWithValue(FakeRecentsService()),
      ]);
      addTearDown(c2.dispose);
      await c2.read(videoStudioControllerProvider.future);
      final ctrl2 = c2.read(videoStudioControllerProvider.notifier);

      expect(ctrl2.lastExportFormat, equals(ExportVideoFormat.webm));
    });
  });
}
