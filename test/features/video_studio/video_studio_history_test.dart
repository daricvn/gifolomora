import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/providers.dart';
import 'package:gifolomora/core/utils/result.dart';
import 'package:gifolomora/features/video_studio/controller/video_studio_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

/// FakeFfmpegService that records every cleanJobAt() call.
class _TrackingFfmpegService extends FakeFfmpegService {
  _TrackingFfmpegService(super.backend);

  final List<String> cleanedJobDirs = [];

  @override
  Future<void> cleanJobAt(String jobDir) async {
    cleanedJobDirs.add(jobDir);
  }
}

ProviderContainer _makeContainer({
  FakeFfmpegBackend? backend,
  _TrackingFfmpegService? service,
}) {
  final b = backend ?? FakeFfmpegBackend();
  return ProviderContainer(overrides: [
    ffmpegServiceProvider
        .overrideWithValue(service ?? _TrackingFfmpegService(b)),
    exportServiceProvider.overrideWithValue(FakeExportService()),
    recentsServiceProvider.overrideWithValue(FakeRecentsService()),
  ]);
}

/// Gets the controller into GIF stage by loading a .gif file.
Future<VideoStudioController> _loadGif(
  ProviderContainer c, {
  String path = '/input.gif',
}) async {
  await c.read(videoStudioControllerProvider.future);
  final ctrl = c.read(videoStudioControllerProvider.notifier);
  await ctrl.setInput(File(path));
  return ctrl;
}

/// Gets into GIF stage via makeGif (video → bake → gif stage).
Future<VideoStudioController> _makeGifFromVideo(
  ProviderContainer c,
) async {
  await c.read(videoStudioControllerProvider.future);
  final ctrl = c.read(videoStudioControllerProvider.notifier);
  await ctrl.setInput(File('/input.mp4'));
  await ctrl.makeGif();
  return ctrl;
}

VideoStudioState _state(ProviderContainer c) =>
    c.read(videoStudioControllerProvider).value!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('VideoStudio GIF history — canUndo / canRedo', () {
    test('both false on initial state', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(videoStudioControllerProvider.future);
      final ctrl = c.read(videoStudioControllerProvider.notifier);
      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isFalse);
    });

    test('loading a .gif seeds base version — canUndo stays false', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isFalse);
    });

    test('loading a .mp4 does not seed history — canUndo false', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await c.read(videoStudioControllerProvider.future);
      final ctrl = c.read(videoStudioControllerProvider.notifier);
      await ctrl.setInput(File('/input.mp4'));
      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isFalse);
    });

    test('makeGif seeds base version — canUndo false', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _makeGifFromVideo(c);
      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isFalse);
    });

    test('applyEdits pushes version — canUndo true, canRedo false', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      ctrl.setLoopCount(1); // triggers needsEdit (loopCount != 0)
      final ok = await ctrl.applyEdits();

      expect(ok, isTrue);
      expect(ctrl.canUndo, isTrue);
      expect(ctrl.canRedo, isFalse);
    });

    test('applyEdits with nothing to bake returns false, no push', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);
      // Default state: no edits, no optimize, loopCount=0 → nothing to bake.
      final ok = await ctrl.applyEdits();
      expect(ok, isFalse);
      expect(ctrl.canUndo, isFalse);
    });
  });

  group('VideoStudio GIF history — undo / redo', () {
    test('undo() restores the pre-apply settings, not the post-bake reset',
        () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      ctrl.setLoopCount(3);
      await ctrl.applyEdits(); // pushes v1 with loopCount=3

      ctrl.undo();

      // Undo reverses the Apply: it returns to the editing state right before
      // it — the user's pending settings (loopCount=3) over the parent source —
      // so the panels show what was applied and can be tweaked / re-applied.
      expect(_state(c).loopCount, equals(3));
      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isTrue);
    });

    test('redo() after undo restores the applied version', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      ctrl.setLoopCount(5);
      await ctrl.applyEdits(); // v1(loopCount=5)
      ctrl.undo();
      ctrl.redo();

      expect(_state(c).loopCount, equals(5));
      expect(ctrl.canUndo, isTrue);
      expect(ctrl.canRedo, isFalse);
    });

    test('undo() returns false at base, does not change state', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      final result = ctrl.undo();

      expect(result, isFalse);
      expect(ctrl.canUndo, isFalse);
    });

    test('redo() returns false at tip, does not change state', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      final result = ctrl.redo();

      expect(result, isFalse);
      expect(ctrl.canRedo, isFalse);
    });

    test('multi-apply then multi-undo chain', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      // v0: loopCount=0 (base loaded gif)
      ctrl.setLoopCount(1);
      await ctrl.applyEdits(); // v1: loopCount=1

      ctrl.setLoopCount(2);
      await ctrl.applyEdits(); // v2: loopCount=2

      ctrl.setLoopCount(3);
      await ctrl.applyEdits(); // v3: loopCount=3

      expect(_state(c).loopCount, equals(3));

      // Each undo restores the pre-apply settings of the Apply it reverses, so
      // the panel shows the value the user had set for that step.
      ctrl.undo(); // reverses 3rd apply → loop=3 pending over v2 source
      expect(_state(c).loopCount, equals(3));
      expect(ctrl.canUndo, isTrue);
      expect(ctrl.canRedo, isTrue);

      ctrl.undo(); // reverses 2nd apply → loop=2
      expect(_state(c).loopCount, equals(2));

      ctrl.undo(); // reverses 1st apply → loop=1 over base source
      expect(_state(c).loopCount, equals(1));
      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isTrue);
    });

    test('new apply after undo truncates redo tail', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      ctrl.setLoopCount(1);
      await ctrl.applyEdits(); // v1

      ctrl.setLoopCount(2);
      await ctrl.applyEdits(); // v2

      ctrl.undo(); // back to v1
      expect(ctrl.canRedo, isTrue);

      ctrl.setLoopCount(9);
      await ctrl.applyEdits(); // v2_new — truncates old v2

      expect(ctrl.canRedo, isFalse);
      expect(_state(c).loopCount, equals(9));

      ctrl.undo(); // reverses the loop=9 apply → loop=9 pending
      expect(_state(c).loopCount, equals(9));
      ctrl.undo(); // reverses the loop=1 apply → loop=1 over base source
      expect(_state(c).loopCount, equals(1));
    });

    test('undo restores baked text layers to the panel (reported bug)',
        () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      // Add text on the clean base gif, then apply (bakes text into pixels and
      // resets the live text layer to []).
      ctrl.addText();
      ctrl.updateSelectedText(text: 'Hello');
      await ctrl.applyEdits();
      expect(_state(c).textItems, isEmpty); // baked → live layer cleared
      expect(ctrl.canUndo, isTrue);

      // Undo must bring the text back into the panel over the clean base source.
      ctrl.undo();
      expect(_state(c).textItems, hasLength(1));
      expect(_state(c).textItems.single.text, equals('Hello'));
    });

    test('text layer API: add / update / move / remove', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      ctrl.addText();
      final id = _state(c).selectedTextId;
      expect(id, isNotNull);
      expect(_state(c).textItems.length, equals(1));
      expect(_state(c).hasText, isTrue); // default text 'Text'

      ctrl.updateSelectedText(text: 'Hello', fontColor: 'FF0000');
      expect(_state(c).selectedText!.text, equals('Hello'));
      expect(_state(c).selectedText!.fontColor, equals('FF0000'));

      ctrl.moveSelectedText(0.2, 0.3);
      expect(_state(c).selectedText!.nx, closeTo(0.2, 1e-9));
      expect(_state(c).selectedText!.ny, closeTo(0.3, 1e-9));

      ctrl.removeText(id!);
      expect(_state(c).textItems, isEmpty);
      expect(_state(c).selectedTextId, isNull);
      expect(_state(c).hasText, isFalse);
    });
  });

  group('VideoStudio GIF history — cleanup on reset', () {
    test('setInput clears history — canUndo false after new source', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      ctrl.setLoopCount(1);
      await ctrl.applyEdits(); // push v1
      expect(ctrl.canUndo, isTrue);

      await ctrl.setInput(File('/input2.gif'));

      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isFalse);
    });

    test('discardGif clears history', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _makeGifFromVideo(c);

      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      expect(ctrl.canUndo, isTrue);

      await ctrl.discardGif();

      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isFalse);
    });

    test('clear() clears history', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _loadGif(c);

      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      expect(ctrl.canUndo, isTrue);

      ctrl.clear();

      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isFalse);
    });

    test('setInput cleans owned temp dirs from previous session', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      backend.nextProbeResult =
          const MediaInfo(durationMs: 1000, width: 320, height: 240);

      final svc = _TrackingFfmpegService(backend);
      final c = _makeContainer(service: svc);
      addTearDown(c.dispose);

      final ctrl = await _loadGif(c, path: '/input.gif');
      ctrl.setLoopCount(1);
      await ctrl.applyEdits(); // v1 owns '/fake'
      expect(ctrl.canUndo, isTrue);

      // New source: history cleared → cleanJobAt called for owned dirs.
      await ctrl.setInput(File('/another.gif'));

      // '/fake' is the ownedDir for v1; it must have been cleaned.
      expect(svc.cleanedJobDirs, contains('/fake'));
    });

    test('new apply after undo cleans the truncated redo entry', () async {
      final backend = FakeFfmpegBackend();
      backend.nextResult = Ok(File('/fake/output.gif'));
      backend.nextProbeResult =
          const MediaInfo(durationMs: 1000, width: 320, height: 240);

      final svc = _TrackingFfmpegService(backend);
      final c = _makeContainer(service: svc);
      addTearDown(c.dispose);

      final ctrl = await _loadGif(c);
      ctrl.setLoopCount(1);
      await ctrl.applyEdits(); // v1 owns '/fake'

      ctrl.setLoopCount(2);
      await ctrl.applyEdits(); // v2 owns '/fake'

      ctrl.undo(); // cursor at v1; v2 is redo tail

      svc.cleanedJobDirs.clear();

      ctrl.setLoopCount(9);
      await ctrl.applyEdits(); // truncates v2 → cleanJobAt('/fake')

      expect(svc.cleanedJobDirs, contains('/fake'));
    });
  });

  group('VideoStudio GIF history — makeGif integration', () {
    test('makeGif from video seeds fresh history (clears any prior gif history)',
        () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      // Load a GIF and apply an edit.
      final ctrl = await _loadGif(c);
      ctrl.setLoopCount(1);
      await ctrl.applyEdits();
      expect(ctrl.canUndo, isTrue);

      // Now switch source to video → makeGif.
      await ctrl.setInput(File('/video.mp4')); // clears history
      await ctrl.makeGif(); // seeds new base

      expect(ctrl.canUndo, isFalse);
      expect(ctrl.canRedo, isFalse);
    });

    test('apply after makeGif works and is undoable', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _makeGifFromVideo(c);

      ctrl.setLoopCount(2);
      await ctrl.applyEdits();

      expect(ctrl.canUndo, isTrue);
      ctrl.undo();
      expect(ctrl.canUndo, isFalse);
      // Pre-apply settings restored (loop=2 pending over the baked base).
      expect(_state(c).loopCount, equals(2));
    });
  });
}
