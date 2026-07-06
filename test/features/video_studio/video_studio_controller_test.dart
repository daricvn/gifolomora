import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/providers.dart';
import 'package:gifolomora/core/utils/result.dart';
import 'package:gifolomora/features/text_overlay/model/text_item.dart';
import 'package:gifolomora/features/video_studio/controller/video_studio_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

// ── shared helpers ─────────────────────────────────────────────────────────

ProviderContainer _makeContainer(FakeFfmpegBackend backend,
    {FakeExportService? exportSvc}) {
  return ProviderContainer(overrides: [
    ffmpegServiceProvider.overrideWithValue(FakeFfmpegService(backend)),
    exportServiceProvider.overrideWithValue(exportSvc ?? FakeExportService()),
    recentsServiceProvider.overrideWithValue(FakeRecentsService()),
  ]);
}

Future<VideoStudioController> _buildCtrl(ProviderContainer c) async {
  await c.read(videoStudioControllerProvider.future);
  return c.read(videoStudioControllerProvider.notifier);
}

Future<VideoStudioController> _loadGif(ProviderContainer c,
    {String path = '/input.gif'}) async {
  final ctrl = await _buildCtrl(c);
  await ctrl.setInput(File(path));
  return ctrl;
}

Future<VideoStudioController> _loadVideo(ProviderContainer c) async {
  final ctrl = await _buildCtrl(c);
  await ctrl.setInput(File('/input.mp4'));
  return ctrl;
}

VideoStudioState _state(ProviderContainer c) =>
    c.read(videoStudioControllerProvider).value!;

// ── tests ──────────────────────────────────────────────────────────────────

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── setCrop / resetCrop ────────────────────────────────────────────────────
  group('VideoStudio — setCrop / resetCrop', () {
    late FakeFfmpegBackend backend;
    late ProviderContainer c;

    setUp(() {
      backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.mp4'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      c = _makeContainer(backend);
    });
    tearDown(() => c.dispose());

    test('setCrop updates cropNormalized', () async {
      final ctrl = await _loadVideo(c);
      const rect = Rect.fromLTRB(0.1, 0.2, 0.9, 0.8);
      ctrl.setCrop(rect);
      expect(_state(c).cropNormalized, equals(rect));
    });

    test('resetCrop restores to full (0,0,1,1)', () async {
      final ctrl = await _loadVideo(c);
      ctrl.setCrop(const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9));
      ctrl.resetCrop();
      expect(_state(c).isCropFull, isTrue);
    });

    test('setCrop clears editsApplied', () async {
      final ctrl = await _loadVideo(c);
      ctrl.setResize(160);
      await ctrl.applyVideoEdits();
      expect(_state(c).editsApplied, isTrue);

      ctrl.setCrop(const Rect.fromLTRB(0, 0, 0.8, 0.8));
      expect(_state(c).editsApplied, isFalse);
    });
  });

  // ── setResize ─────────────────────────────────────────────────────────────
  group('VideoStudio — setResize', () {
    late FakeFfmpegBackend backend;
    late ProviderContainer c;

    setUp(() {
      backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.mp4'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      c = _makeContainer(backend);
    });
    tearDown(() => c.dispose());

    test('setResize sets targetWidth', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setResize(480);
      expect(_state(c).targetWidth, equals(480));
    });

    test('setResize null clears targetWidth', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setResize(480);
      ctrl.setResize(null);
      expect(_state(c).targetWidth, isNull);
    });

    test('setResize clears editsApplied', () async {
      final ctrl = await _loadVideo(c);
      ctrl.setResize(160);
      await ctrl.applyVideoEdits();
      expect(_state(c).editsApplied, isTrue);

      ctrl.setResize(320);
      expect(_state(c).editsApplied, isFalse);
    });
  });

  // ── setSpeed ──────────────────────────────────────────────────────────────
  group('VideoStudio — setSpeed', () {
    late FakeFfmpegBackend backend;
    late ProviderContainer c;

    setUp(() {
      backend = FakeFfmpegBackend();
      c = _makeContainer(backend);
    });
    tearDown(() => c.dispose());

    test('setSpeed sets speedFactor', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setSpeed(2.5);
      expect(_state(c).speedFactor, closeTo(2.5, 1e-9));
    });

    test('setSpeed 1.0 sets speedFactor exactly', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setSpeed(0.5);
      ctrl.setSpeed(1.0);
      expect(_state(c).speedFactor, closeTo(1.0, 1e-9));
    });
  });

  // ── setFps ────────────────────────────────────────────────────────────────
  group('VideoStudio — setFps', () {
    late FakeFfmpegBackend backend;
    late ProviderContainer c;

    setUp(() {
      backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      c = _makeContainer(backend);
    });
    tearDown(() => c.dispose());

    test('setFps valid value preserved', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setFps(24);
      expect(_state(c).fps, equals(24));
    });

    test('setFps clamps below 1 to 1', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setFps(0);
      expect(_state(c).fps, equals(1));
    });

    test('setFps clamps negative to 1', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setFps(-10);
      expect(_state(c).fps, equals(1));
    });

    test('setFps clamps above 60 to 60', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setFps(120);
      expect(_state(c).fps, equals(60));
    });

    test('setFps clears editsApplied', () async {
      final ctrl = await _loadGif(c);
      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      expect(_state(c).editsApplied, isTrue);

      ctrl.setFps(12);
      expect(_state(c).editsApplied, isFalse);
    });
  });

  // ── setLoopCount ──────────────────────────────────────────────────────────
  group('VideoStudio — setLoopCount', () {
    late ProviderContainer c;

    setUp(() {
      c = _makeContainer(FakeFfmpegBackend());
    });
    tearDown(() => c.dispose());

    test('setLoopCount negative → 0', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setLoopCount(-5);
      expect(_state(c).loopCount, equals(0));
    });

    test('setLoopCount 0 preserved', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setLoopCount(3);
      ctrl.setLoopCount(0);
      expect(_state(c).loopCount, equals(0));
    });

    test('setLoopCount positive value preserved', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setLoopCount(5);
      expect(_state(c).loopCount, equals(5));
    });
  });

  // ── setBoomerang ──────────────────────────────────────────────────────────
  group('VideoStudio — setBoomerang', () {
    late FakeFfmpegBackend backend;
    late ProviderContainer c;

    setUp(() {
      backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      c = _makeContainer(backend);
    });
    tearDown(() => c.dispose());

    test('setBoomerang true sets boomerang', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setBoomerang(true);
      expect(_state(c).boomerang, isTrue);
    });

    test('setBoomerang false clears boomerang', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setBoomerang(true);
      ctrl.setBoomerang(false);
      expect(_state(c).boomerang, isFalse);
    });

    test('setBoomerang clears editsApplied', () async {
      final ctrl = await _loadGif(c);
      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      expect(_state(c).editsApplied, isTrue);

      ctrl.setBoomerang(true);
      expect(_state(c).editsApplied, isFalse);
    });

    test('setBoomerang true clears smoothLoop (mutual exclusion)', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setSmoothLoop(true);
      ctrl.setBoomerang(true);
      expect(_state(c).boomerang, isTrue);
      expect(_state(c).smoothLoop, isFalse);
    });
  });

  // ── setSmoothLoop ─────────────────────────────────────────────────────────
  group('VideoStudio — setSmoothLoop', () {
    late FakeFfmpegBackend backend;
    late ProviderContainer c;

    setUp(() {
      backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      c = _makeContainer(backend);
    });
    tearDown(() => c.dispose());

    test('setSmoothLoop true sets smoothLoop', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setSmoothLoop(true);
      expect(_state(c).smoothLoop, isTrue);
    });

    test('setSmoothLoop true clears boomerang (mutual exclusion)', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setBoomerang(true);
      ctrl.setSmoothLoop(true);
      expect(_state(c).smoothLoop, isTrue);
      expect(_state(c).boomerang, isFalse);
    });

    test('setSmoothLoopCrossfadeMs sets value', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setSmoothLoopCrossfadeMs(700);
      expect(_state(c).smoothLoopCrossfadeMs, equals(700));
    });

    test('setSmoothLoopCrossfadeMs clamps below 500 to 500', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setSmoothLoopCrossfadeMs(100);
      expect(_state(c).smoothLoopCrossfadeMs, equals(500));
    });

    test('setSmoothLoopCrossfadeMs clamps above 1000 to 1000', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setSmoothLoopCrossfadeMs(5000);
      expect(_state(c).smoothLoopCrossfadeMs, equals(1000));
    });

    test('setSmoothLoopCrossfadeMs rounds down to nearest 100ms step',
        () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setSmoothLoopCrossfadeMs(750);
      expect(_state(c).smoothLoopCrossfadeMs, equals(700));
    });

    test('setSmoothLoopCrossfadeMs clears editsApplied', () async {
      final ctrl = await _loadGif(c);
      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      expect(_state(c).editsApplied, isTrue);

      ctrl.setSmoothLoopCrossfadeMs(600);
      expect(_state(c).editsApplied, isFalse);
    });

    test('setSpeed auto-disables smoothLoop once duration falls under floor',
        () async {
      final ctrl = await _loadVideo(c); // sourceInfo durationMs = 5000
      ctrl.setSmoothLoop(true);
      expect(_state(c).smoothLoop, isTrue);
      ctrl.setSpeed(4.0); // 5000ms/4 = 1250ms < 2100ms floor
      expect(_state(c).smoothLoop, isFalse);
    });

    test('setTrimEnd auto-disables smoothLoop once trimmed target falls '
        'under the 3s gate', () async {
      final backend2 = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 20000, width: 320, height: 240);
      final c2 = _makeContainer(backend2);
      addTearDown(c2.dispose);
      final ctrl = await _loadVideo(c2);
      ctrl.setSmoothLoop(true);
      expect(_state(c2).smoothLoop, isTrue);
      ctrl.setTrimEnd(2000); // trimmed target 2s < 3s gate
      expect(_state(c2).smoothLoop, isFalse);
    });
  });

  // ── setVolume ─────────────────────────────────────────────────────────────
  group('VideoStudio — setVolume', () {
    late FakeFfmpegBackend backend;
    late ProviderContainer c;

    setUp(() {
      backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.mp4'))
        ..nextProbeResult = const MediaInfo(
            durationMs: 5000, width: 320, height: 240, hasAudio: true);
      c = _makeContainer(backend);
    });
    tearDown(() => c.dispose());

    test('setVolume clamps below 0 to 0.0', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setVolume(-0.5);
      expect(_state(c).volume, closeTo(0.0, 1e-9));
    });

    test('setVolume clamps above 2.0 to 2.0', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setVolume(3.0);
      expect(_state(c).volume, closeTo(2.0, 1e-9));
    });

    test('setVolume valid value preserved', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setVolume(1.5);
      expect(_state(c).volume, closeTo(1.5, 1e-9));
    });

    test('setVolume clears editsApplied', () async {
      final ctrl = await _loadVideo(c);
      ctrl.setResize(160);
      await ctrl.applyVideoEdits();
      expect(_state(c).editsApplied, isTrue);

      ctrl.setVolume(0.5);
      expect(_state(c).editsApplied, isFalse);
    });
  });

  // ── setDoOptimize / setOptimize* ──────────────────────────────────────────
  group('VideoStudio — optimize setters', () {
    late ProviderContainer c;

    setUp(() {
      c = _makeContainer(FakeFfmpegBackend());
    });
    tearDown(() => c.dispose());

    test('setDoOptimize true sets doOptimize', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setDoOptimize(true);
      expect(_state(c).doOptimize, isTrue);
    });

    test('setDoOptimize false clears doOptimize', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setDoOptimize(true);
      ctrl.setDoOptimize(false);
      expect(_state(c).doOptimize, isFalse);
    });

    test('setOptimizeColors sets value', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setOptimizeColors(64);
      expect(_state(c).optimizeColors, equals(64));
    });

    test('setOptimizeLossy sets value', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setOptimizeLossy(50);
      expect(_state(c).optimizeLossy, equals(50));
    });

    test('setOptimizeFrameDrop sets value', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setOptimizeFrameDrop(2);
      expect(_state(c).optimizeFrameDrop, equals(2));
    });
  });

  // ── trim setters ──────────────────────────────────────────────────────────
  group('VideoStudio — trim setters', () {
    late FakeFfmpegBackend backend;
    late ProviderContainer c;

    setUp(() {
      backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      c = _makeContainer(backend);
    });
    tearDown(() => c.dispose());

    test('setTrimStart accepts 0', () async {
      final ctrl = await _loadVideo(c);
      ctrl.setTrimStart(0);
      expect(_state(c).trimStartMs, equals(0));
    });

    test('setTrimStart clamps negative to 0', () async {
      final ctrl = await _loadVideo(c);
      ctrl.setTrimStart(-500);
      expect(_state(c).trimStartMs, equals(0));
    });

    test('setTrimStart clamps so gap to trimEnd is at least 1000ms', () async {
      final ctrl = await _loadVideo(c);
      // effectiveTrimEnd=5000 → max=4000. 4500 clamps to 4000.
      ctrl.setTrimStart(4500);
      expect(_state(c).trimStartMs, equals(4000));
    });

    test('setTrimEnd clamps to trimStart + 1000 (minimum gap)', () async {
      final ctrl = await _loadVideo(c);
      ctrl.setTrimStart(2000);
      // min = 2000 + 1000 = 3000. 2500 clamps to 3000.
      ctrl.setTrimEnd(2500);
      expect(_state(c).trimEndMs, equals(3000));
    });

    test('setTrimEnd clamps to sourceDurationMs (maximum)', () async {
      final ctrl = await _loadVideo(c);
      ctrl.setTrimEnd(9999);
      expect(_state(c).trimEndMs, equals(5000));
    });

    test('resetTrim sets both trimStartMs and trimEndMs to 0', () async {
      final ctrl = await _loadVideo(c);
      ctrl.setTrimStart(1000);
      ctrl.setTrimEnd(3000);
      ctrl.resetTrim();
      expect(_state(c).trimStartMs, equals(0));
      expect(_state(c).trimEndMs, equals(0));
    });
  });

  // ── setActiveTool ─────────────────────────────────────────────────────────
  group('VideoStudio — setActiveTool', () {
    late FakeFfmpegBackend backend;
    late ProviderContainer c;

    setUp(() {
      backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      c = _makeContainer(backend);
    });
    tearDown(() => c.dispose());

    test('setActiveTool changes activeTool', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.setActiveTool(StudioTool.speed);
      expect(_state(c).activeTool, equals(StudioTool.speed));
    });

    test('setActiveTool preserves editsApplied flag', () async {
      final ctrl = await _loadGif(c);
      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      expect(_state(c).editsApplied, isTrue);

      ctrl.setActiveTool(StudioTool.trim);
      expect(_state(c).editsApplied, isTrue);
    });

    test('setActiveTool clears error', () async {
      final ctrl = await _buildCtrl(c);
      // Inject an error by using a failing backend
      backend.nextResult = Err(const FfmpegError(message: 'fail'));
      await ctrl.setInput(File('/input.gif'));
      ctrl.setLoopCount(1);
      await ctrl.applyEdits(); // sets error
      expect(_state(c).error, equals('fail'));

      ctrl.setActiveTool(StudioTool.crop);
      expect(_state(c).error, isNull);
    });
  });

  // ── addText ────────────────────────────────────────────────────────────────
  group('VideoStudio — addText', () {
    late ProviderContainer c;

    setUp(() {
      c = _makeContainer(FakeFfmpegBackend());
    });
    tearDown(() => c.dispose());

    test('addText creates item with default text "Text"', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      expect(_state(c).textItems.length, equals(1));
      expect(_state(c).textItems.first.text, equals('Text'));
    });

    test('addText auto-selects the new item', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      final id = _state(c).textItems.first.id;
      expect(_state(c).selectedTextId, equals(id));
    });

    test('addText consecutive items have different ids', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      final id1 = _state(c).textItems.first.id;
      ctrl.addText();
      final id2 = _state(c).textItems.last.id;
      expect(id1, isNot(equals(id2)));
    });

    test('addText accumulates items', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.addText();
      ctrl.addText();
      expect(_state(c).textItems.length, equals(3));
    });

    test('addText is no-op at 20 items', () async {
      final ctrl = await _buildCtrl(c);
      for (var i = 0; i < 20; i++) {
        ctrl.addText();
      }
      expect(_state(c).textItems.length, equals(20));
      ctrl.addText(); // 21st call
      expect(_state(c).textItems.length, equals(20));
    });
  });

  // ── removeText / selectText ────────────────────────────────────────────────
  group('VideoStudio — removeText / selectText', () {
    late ProviderContainer c;

    setUp(() {
      c = _makeContainer(FakeFfmpegBackend());
    });
    tearDown(() => c.dispose());

    test('removeText removes correct item by id', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.addText();
      final id = _state(c).textItems.first.id;
      ctrl.removeText(id);
      expect(_state(c).textItems.length, equals(1));
      expect(_state(c).textItems.any((i) => i.id == id), isFalse);
    });

    test('removeText clears selectedTextId when selected item removed', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      final id = _state(c).selectedTextId!;
      ctrl.removeText(id);
      expect(_state(c).selectedTextId, isNull);
    });

    test('removeText preserves selectedTextId when different item removed',
        () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      final id1 = _state(c).textItems.first.id;
      ctrl.addText();
      final id2 = _state(c).textItems.last.id;
      ctrl.selectText(id1);
      ctrl.removeText(id2); // remove the non-selected one
      expect(_state(c).selectedTextId, equals(id1));
    });

    test('selectText sets selectedTextId', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.addText();
      final id = _state(c).textItems.first.id;
      ctrl.selectText(id);
      expect(_state(c).selectedTextId, equals(id));
    });

    test('selectText null deselects', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      final id = _state(c).selectedTextId!;
      expect(id, isNotNull);
      ctrl.selectText(null);
      expect(_state(c).selectedTextId, isNull);
    });
  });

  // ── updateSelectedText ─────────────────────────────────────────────────────
  group('VideoStudio — updateSelectedText', () {
    late ProviderContainer c;

    setUp(() {
      c = _makeContainer(FakeFfmpegBackend());
    });
    tearDown(() => c.dispose());

    test('no-op when no item selected', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.selectText(null);
      ctrl.updateSelectedText(text: 'Changed');
      // No selection → state unchanged
      expect(_state(c).textItems.first.text, equals('Text'));
    });

    test('updates text field', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.updateSelectedText(text: 'Hello World');
      expect(_state(c).selectedText!.text, equals('Hello World'));
    });

    test('updates fontSize', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.updateSelectedText(fontSize: 48);
      expect(_state(c).selectedText!.fontSize, equals(48));
    });

    test('updates fontColor', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.updateSelectedText(fontColor: 'FF0000');
      expect(_state(c).selectedText!.fontColor, equals('FF0000'));
    });

    test('updates strokeColor', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.updateSelectedText(strokeColor: '0000FF');
      expect(_state(c).selectedText!.strokeColor, equals('0000FF'));
    });

    test('updates strokeWidth', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.updateSelectedText(strokeWidth: 4);
      expect(_state(c).selectedText!.strokeWidth, equals(4));
    });

    test('updates style and font simultaneously', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.updateSelectedText(
        style: TextStyleKind.bold,
        font: TextFont.dancingScript,
      );
      expect(_state(c).selectedText!.style, equals(TextStyleKind.bold));
      expect(_state(c).selectedText!.font, equals(TextFont.dancingScript));
    });

    test('only updates the selected item, not others', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      final id1 = _state(c).textItems.first.id;
      ctrl.addText();
      // id2 is now selected
      ctrl.updateSelectedText(text: 'Only This');
      // id1 should still have default text
      final item1 = _state(c).textItems.firstWhere((i) => i.id == id1);
      expect(item1.text, equals('Text'));
    });
  });

  // ── moveSelectedText ───────────────────────────────────────────────────────
  group('VideoStudio — moveSelectedText', () {
    late ProviderContainer c;

    setUp(() {
      c = _makeContainer(FakeFfmpegBackend());
    });
    tearDown(() => c.dispose());

    test('updates nx and ny on selected item', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.moveSelectedText(0.3, 0.7);
      expect(_state(c).selectedText!.nx, closeTo(0.3, 1e-9));
      expect(_state(c).selectedText!.ny, closeTo(0.7, 1e-9));
    });

    test('clamps negative nx to 0.0', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.moveSelectedText(-0.5, 0.5);
      expect(_state(c).selectedText!.nx, closeTo(0.0, 1e-9));
    });

    test('clamps nx above limit to 0.9999', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.moveSelectedText(1.5, 0.5);
      expect(_state(c).selectedText!.nx, closeTo(0.9999, 1e-9));
    });

    test('clamps negative ny to 0.0', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      ctrl.moveSelectedText(0.5, -1.0);
      expect(_state(c).selectedText!.ny, closeTo(0.0, 1e-9));
    });

    test('no-op when no item selected', () async {
      final ctrl = await _buildCtrl(c);
      ctrl.addText();
      final origNx = _state(c).textItems.first.nx;
      ctrl.selectText(null);
      ctrl.moveSelectedText(0.9, 0.9);
      expect(_state(c).textItems.first.nx, closeTo(origNx, 1e-9));
    });
  });

  // ── setInput ──────────────────────────────────────────────────────────────
  group('VideoStudio — setInput', () {
    tearDown(() {}); // individual tests manage their containers

    test('mp4 input → video stage', () async {
      final c = _makeContainer(FakeFfmpegBackend());
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      expect(_state(c).stage, equals(EditStage.video));
      expect(ctrl, isNotNull);
    });

    test('mp4 input → activeTool set to crop', () async {
      final c = _makeContainer(FakeFfmpegBackend());
      addTearDown(c.dispose);
      await _loadVideo(c);
      expect(_state(c).activeTool, equals(StudioTool.crop));
    });

    test('gif input → gif stage', () async {
      final c = _makeContainer(FakeFfmpegBackend());
      addTearDown(c.dispose);
      await _loadGif(c);
      expect(_state(c).stage, equals(EditStage.gif));
    });

    test('gif input seeds fps from probe result', () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240, fps: 24);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      await _loadGif(c);
      expect(_state(c).fps, equals(24));
    });

    test('gif fps clamped to 5 when probe returns fps below minimum', () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 1000, width: 320, height: 240, fps: 3);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      await _loadGif(c);
      expect(_state(c).fps, equals(5));
    });

    test('gif fps clamped to 30 when probe returns fps above maximum', () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult = const MediaInfo(
            durationMs: 1000, width: 320, height: 240, fps: 60.0);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      await _loadGif(c);
      expect(_state(c).fps, equals(30));
    });

    test('setInput clears history so canUndo is false', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      ctrl.setLoopCount(1);
      await ctrl.applyEdits(); // push to history
      expect(ctrl.canUndo, isTrue);

      await ctrl.setInput(File('/other.gif'));
      expect(ctrl.canUndo, isFalse);
    });
  });

  // ── makeGif ───────────────────────────────────────────────────────────────
  group('VideoStudio — makeGif', () {
    test('returns false when already on gif stage', () async {
      final c = _makeContainer(FakeFfmpegBackend());
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      expect(_state(c).isGif, isTrue);
      final ok = await ctrl.makeGif();
      expect(ok, isFalse);
    });

    test('returns false when isProcessing', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'));
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);

      final future = ctrl.makeGif(); // starts, sets isProcessing=true
      final ok = await ctrl.makeGif(); // sees isProcessing=true
      await future;
      expect(ok, isFalse);
    });

    test('returns false without sourceFile', () async {
      final c = _makeContainer(FakeFfmpegBackend());
      addTearDown(c.dispose);
      final ctrl = await _buildCtrl(c); // no setInput
      final ok = await ctrl.makeGif();
      expect(ok, isFalse);
    });

    test('success transitions to gif stage', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      await ctrl.makeGif();
      expect(_state(c).stage, equals(EditStage.gif));
    });

    test('success seeds fresh history (canUndo false)', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      await ctrl.makeGif();
      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isFalse);
    });

    test('carries textItems to baked state', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      ctrl.addText();
      ctrl.updateSelectedText(text: 'Banner');
      await ctrl.makeGif();
      expect(_state(c).textItems.length, equals(1));
      expect(_state(c).textItems.first.text, equals('Banner'));
    });

    test('carries fps, loopCount, boomerang, doOptimize to baked state',
        () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      ctrl.setFps(20);
      ctrl.setLoopCount(3);
      ctrl.setBoomerang(true);
      ctrl.setDoOptimize(true);
      await ctrl.makeGif();
      expect(_state(c).fps, equals(20));
      expect(_state(c).loopCount, equals(3));
      expect(_state(c).boomerang, isTrue);
      expect(_state(c).doOptimize, isTrue);
    });

    test('error → sets error message and returns false', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Err(const FfmpegError(message: 'encode failed'));
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      final ok = await ctrl.makeGif();
      expect(ok, isFalse);
      expect(_state(c).error, equals('encode failed'));
      expect(_state(c).isProcessing, isFalse);
    });
  });

  // ── discardGif ────────────────────────────────────────────────────────────
  group('VideoStudio — discardGif', () {
    test('without inputFile does nothing significant', () async {
      final c = _makeContainer(FakeFfmpegBackend());
      addTearDown(c.dispose);
      final ctrl = await _buildCtrl(c); // no setInput
      await ctrl.discardGif(); // should be a no-op
      // State should remain empty / unchanged
      expect(_state(c).inputFile, isNull);
    });

    test('transitions from gif stage back to video stage', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      await ctrl.makeGif();
      expect(_state(c).stage, equals(EditStage.gif));
      await ctrl.discardGif();
      expect(_state(c).stage, equals(EditStage.video));
    });

    test('preserves fps, loopCount, boomerang settings', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      ctrl.setFps(20);
      ctrl.setLoopCount(2);
      ctrl.setBoomerang(true);
      await ctrl.makeGif();
      await ctrl.discardGif();
      expect(_state(c).fps, equals(20));
      expect(_state(c).loopCount, equals(2));
      expect(_state(c).boomerang, isTrue);
    });

    test('clears history so canUndo is false', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      await ctrl.makeGif();
      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      expect(ctrl.canUndo, isTrue);
      await ctrl.discardGif();
      expect(ctrl.canUndo, isFalse);
    });
  });

  // ── applyEdits (GIF stage) ────────────────────────────────────────────────
  group('VideoStudio — applyEdits', () {
    test('returns false when on video stage', () async {
      final c = _makeContainer(FakeFfmpegBackend());
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      final ok = await ctrl.applyEdits();
      expect(ok, isFalse);
    });

    test('returns false when nothing to bake', () async {
      final c = _makeContainer(FakeFfmpegBackend());
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      // Default: no edits, no optimize, loopCount=0, no text
      final ok = await ctrl.applyEdits();
      expect(ok, isFalse);
    });

    test('crop change triggers encode and returns true', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      ctrl.setCrop(const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9));
      final ok = await ctrl.applyEdits();
      expect(ok, isTrue);
    });

    test('boomerang=true triggers encode and returns true', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      ctrl.setBoomerang(true);
      final ok = await ctrl.applyEdits();
      expect(ok, isTrue);
    });

    test('doOptimize=true triggers encode and returns true', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      ctrl.setDoOptimize(true);
      final ok = await ctrl.applyEdits();
      expect(ok, isTrue);
    });

    test('text item with non-blank text triggers encode', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      ctrl.addText();
      ctrl.updateSelectedText(text: 'Overlay');
      final ok = await ctrl.applyEdits();
      expect(ok, isTrue);
    });

    test('error → returns false and sets error message', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Err(const FfmpegError(message: 'gif error'));
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      ctrl.setBoomerang(true);
      final ok = await ctrl.applyEdits();
      expect(ok, isFalse);
      expect(_state(c).error, equals('gif error'));
      expect(_state(c).isProcessing, isFalse);
    });

    test('success resets boomerang to false in applied state', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      ctrl.setBoomerang(true);
      await ctrl.applyEdits();
      // Boomerang baked into frames → reset to false
      expect(_state(c).boomerang, isFalse);
    });

    test('success sets editsApplied to true', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      expect(_state(c).editsApplied, isTrue);
    });
  });

  // ── applyVideoEdits additional cases ──────────────────────────────────────
  group('VideoStudio — applyVideoEdits (additional)', () {
    test('with only trim change runs encode', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.mp4'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      ctrl.setTrimStart(1000); // hasTrim = true (trimStartMs > 0)
      final ok = await ctrl.applyVideoEdits();
      expect(ok, isTrue);
    });

    test('with only volume change runs encode', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.mp4'))
        ..nextProbeResult = const MediaInfo(
            durationMs: 5000, width: 320, height: 240, hasAudio: true);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      ctrl.setVolume(1.5); // hasVolumeChange = true (audio present)
      final ok = await ctrl.applyVideoEdits();
      expect(ok, isTrue);
    });

    test('returns false when on gif stage', () async {
      final c = _makeContainer(FakeFfmpegBackend());
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      final ok = await ctrl.applyVideoEdits();
      expect(ok, isFalse);
    });

    test('error → returns false and sets error message', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Err(const FfmpegError(message: 'video error'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      ctrl.setResize(160);
      final ok = await ctrl.applyVideoEdits();
      expect(ok, isFalse);
      expect(_state(c).error, equals('video error'));
      expect(_state(c).isProcessing, isFalse);
    });
  });

  // ── exportVideo ───────────────────────────────────────────────────────────
  group('VideoStudio — exportVideo', () {
    test('returns false when on gif stage', () async {
      final c = _makeContainer(FakeFfmpegBackend());
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      final ok = await ctrl.exportVideo();
      expect(ok, isFalse);
    });

    test('returns false when isProcessing', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.mp4'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      ctrl.setResize(160);

      final future = ctrl.exportVideo(); // starts, sets isProcessing=true
      final ok = await ctrl.exportVideo(); // should see isProcessing=true
      await future;
      expect(ok, isFalse);
    });

    test('editsApplied=true saves baked file without re-encoding', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.mp4'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      final exportSvc = FakeExportService();
      final c = _makeContainer(backend, exportSvc: exportSvc);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      ctrl.setResize(160);
      await ctrl.applyVideoEdits();
      final runsBefore = backend.runCount;

      await ctrl.exportVideo();

      expect(backend.runCount, equals(runsBefore)); // no new encode
      expect(exportSvc.savedVideoSource!.path, equals('/fake/output.mp4'));
    });

    test('error → returns false', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Err(const FfmpegError(message: 'export error'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      ctrl.setResize(160);
      final ok = await ctrl.exportVideo();
      expect(ok, isFalse);
      expect(_state(c).error, equals('export error'));
    });
  });

  // ── exportGif ─────────────────────────────────────────────────────────────
  group('VideoStudio — exportGif', () {
    test('returns false when on video stage', () async {
      final c = _makeContainer(FakeFfmpegBackend());
      addTearDown(c.dispose);
      final ctrl = await _loadVideo(c);
      final ok = await ctrl.exportGif();
      expect(ok, isFalse);
    });

    test('returns false when isProcessing', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      ctrl.setBoomerang(true);

      final future = ctrl.exportGif();
      final ok = await ctrl.exportGif();
      await future;
      expect(ok, isFalse);
    });

    test('fast path: editsApplied=true saves source without re-encoding',
        () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      expect(_state(c).editsApplied, isTrue);

      final runsBefore = backend.runCount;
      await ctrl.exportGif();
      expect(backend.runCount, equals(runsBefore)); // no new encode
    });

    test('fast path: no pending edits saves source directly', () async {
      // No edits, no optimize, no text, loopCount=0 → fast path
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      final runsBefore = backend.runCount;
      final ok = await ctrl.exportGif();
      expect(ok, isTrue);
      expect(backend.runCount, equals(runsBefore)); // no encode
    });

    test('with pending edits runs gif pipeline', () async {
      final backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      final c = _makeContainer(backend);
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      ctrl.setBoomerang(true);

      final runsBefore = backend.runCount;
      final ok = await ctrl.exportGif();
      expect(ok, isTrue);
      expect(backend.runCount, greaterThan(runsBefore)); // encode ran
    });
  });

  // ── cancel / clear ────────────────────────────────────────────────────────
  group('VideoStudio — cancel / clear', () {
    late FakeFfmpegBackend backend;
    late ProviderContainer c;

    setUp(() {
      backend = FakeFfmpegBackend()
        ..nextResult = Ok(File('/fake/output.gif'))
        ..nextProbeResult =
            const MediaInfo(durationMs: 2000, width: 320, height: 240);
      c = _makeContainer(backend);
    });
    tearDown(() => c.dispose());

    test('cancel sets isProcessing to false', () async {
      final ctrl = await _loadGif(c);
      ctrl.setBoomerang(true);
      final future = ctrl.applyEdits(); // sets isProcessing=true
      await ctrl.cancel();
      await future;
      expect(_state(c).isProcessing, isFalse);
    });

    test('cancel clears progress', () async {
      final ctrl = await _loadGif(c);
      ctrl.setBoomerang(true);
      final future = ctrl.applyEdits();
      await ctrl.cancel();
      await future;
      expect(_state(c).progress, isNull);
    });

    test('clear resets sourceFile to null', () async {
      final ctrl = await _loadGif(c);
      expect(_state(c).sourceFile, isNotNull);
      ctrl.clear();
      expect(_state(c).sourceFile, isNull);
    });

    test('clear resets inputFile to null', () async {
      final ctrl = await _loadGif(c);
      expect(_state(c).inputFile, isNotNull);
      ctrl.clear();
      expect(_state(c).inputFile, isNull);
    });

    test('clear resets history so canUndo is false', () async {
      final ctrl = await _loadGif(c);
      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      expect(ctrl.canUndo, isTrue);

      ctrl.clear();
      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isFalse);
    });
  });
}
