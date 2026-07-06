import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_progress.dart';
import 'package:gifolomora/core/services/providers.dart';
import 'package:gifolomora/core/utils/result.dart';
import 'package:gifolomora/features/webm_converter/controller/webm_converter_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

/// Blocks `run()` until [resume] is called — lets a test pause convertAll
/// mid-item to exercise cancel() deterministically instead of racing timers.
class _GatedBackend extends FakeFfmpegBackend {
  Completer<void>? _gate;
  void pause() => _gate = Completer<void>();
  void resume() {
    _gate?.complete();
    _gate = null;
  }

  @override
  Future<Result<File, FfmpegError>> run(
    List<String> args,
    String outputPath, {
    void Function(FfmpegProgress)? onProgress,
    int? totalFrames,
    int? totalMs,
  }) async {
    final g = _gate;
    if (g != null) await g.future;
    return super.run(args, outputPath,
        onProgress: onProgress, totalFrames: totalFrames, totalMs: totalMs);
  }
}

/// Returns a different result per call, in order (clamped to the last entry
/// once exhausted) — lets a test simulate "item 2 of 3 fails" batches.
class _SequencedBackend extends FakeFfmpegBackend {
  _SequencedBackend(this.results);
  final List<Result<File, FfmpegError>> results;
  int _i = 0;

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
    final r = results[_i.clamp(0, results.length - 1)];
    _i++;
    return r;
  }
}

ProviderContainer _makeContainer({
  FakeFfmpegBackend? backend,
  FakeExportService? export,
}) {
  final b = backend ??
      (FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240));
  return ProviderContainer(overrides: [
    ffmpegServiceProvider.overrideWithValue(FakeFfmpegService(b)),
    exportServiceProvider.overrideWithValue(export ?? FakeExportService()),
    recentsServiceProvider.overrideWithValue(FakeRecentsService()),
  ]);
}

WebmConverterState _state(ProviderContainer c) =>
    c.read(webmConverterControllerProvider).value!;

Future<WebmConverterController> _build(ProviderContainer c) async {
  await c.read(webmConverterControllerProvider.future);
  return c.read(webmConverterControllerProvider.notifier);
}

/// A real on-disk file so `File.length()` (called by convertAll on success)
/// doesn't throw — FakeFfmpegBackend.run ignores args and always returns
/// whatever File is set as nextResult, so that File must actually exist.
File _realFile(Directory dir, String name, int bytes) {
  final f = File('${dir.path}/$name');
  f.writeAsBytesSync(Uint8List(bytes));
  return f;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('webm_ctrl_test');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('addFiles — 20 item cap', () {
    test('accepts up to 20, rejects the rest, returns reject count', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _build(c);

      final srcs = List.generate(25, (i) => _realFile(tmp, 'in$i.mp4', 10));
      final rejected = await ctrl.addFiles(srcs);

      expect(rejected, equals(5));
      expect(_state(c).items.length, equals(20));
    });

    test('second addFiles call respects remaining room from first', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _build(c);

      await ctrl.addFiles(List.generate(18, (i) => _realFile(tmp, 'a$i.mp4', 10)));
      final rejected =
          await ctrl.addFiles(List.generate(5, (i) => _realFile(tmp, 'b$i.mp4', 10)));

      expect(_state(c).items.length, equals(20));
      expect(rejected, equals(3)); // room was 2, 5 offered → 3 rejected
    });

    test('already-full list rejects every new file', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _build(c);

      await ctrl.addFiles(List.generate(20, (i) => _realFile(tmp, 'a$i.mp4', 10)));
      final rejected = await ctrl.addFiles([_realFile(tmp, 'extra.mp4', 10)]);

      expect(rejected, equals(1));
      expect(_state(c).items.length, equals(20));
    });

    test('each added item gets probed and info populated', () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 3000, width: 100, height: 100);
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await _build(c);

      await ctrl.addFiles([_realFile(tmp, 'in.mp4', 10)]);

      final item = _state(c).items.single;
      expect(item.isProbing, isFalse);
      expect(item.info!.durationMs, equals(3000));
    });
  });

  group('option setters — resetDoneOutputs on change', () {
    Future<WebmConverterController> setupOneDoneItem(ProviderContainer c) async {
      final ctrl = await _build(c);
      await ctrl.addFiles([_realFile(tmp, 'in.mp4', 10)]);
      await ctrl.convertAll();
      expect(_state(c).items.single.status, equals(WebmItemStatus.done));
      return ctrl;
    }

    test('setCrf on a done item resets it to queued and clears output', () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240)
        ..nextResult = Ok(_realFile(tmp, 'out.webm', 500));
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await setupOneDoneItem(c);

      ctrl.setCrf(20);

      final item = _state(c).items.single;
      expect(item.status, equals(WebmItemStatus.queued));
      expect(item.output, isNull);
      expect(_state(c).crf, equals(20));
    });

    test('setCrf clamps to [18, 45]', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _build(c);

      ctrl.setCrf(5);
      expect(_state(c).crf, equals(18));
      ctrl.setCrf(999);
      expect(_state(c).crf, equals(45));
    });

    test('setSpeed resets done outputs', () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240)
        ..nextResult = Ok(_realFile(tmp, 'out.webm', 500));
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await setupOneDoneItem(c);

      ctrl.setSpeed(WebmSpeed.best);

      expect(_state(c).items.single.status, equals(WebmItemStatus.queued));
      expect(_state(c).speed, equals(WebmSpeed.best));
    });

    test('setMaxWidth resets done outputs', () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240)
        ..nextResult = Ok(_realFile(tmp, 'out.webm', 500));
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await setupOneDoneItem(c);

      ctrl.setMaxWidth(720);

      expect(_state(c).items.single.status, equals(WebmItemStatus.queued));
      expect(_state(c).maxWidth, equals(720));
    });
  });

  group('setAv1 — gating', () {
    test('rejected when av1Supported is false (no-op)', () async {
      final backend = FakeFfmpegBackend()..nextSupportsEncoder = false;
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      expect(_state(c).av1Supported, isFalse);

      ctrl.setAv1(true);

      expect(_state(c).av1, isFalse);
    });

    test('rejected when alpha already on, even if av1Supported', () async {
      final backend = FakeFfmpegBackend()..nextSupportsEncoder = true;
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      ctrl.setAlpha(true);

      ctrl.setAv1(true);

      expect(_state(c).av1, isFalse);
    });

    test('accepted when supported and alpha off', () async {
      final backend = FakeFfmpegBackend()..nextSupportsEncoder = true;
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await _build(c);

      ctrl.setAv1(true);

      expect(_state(c).av1, isTrue);
    });
  });

  group('setAlpha — forces vp9', () {
    test('turning alpha on while av1 is on forces av1 back off', () async {
      final backend = FakeFfmpegBackend()..nextSupportsEncoder = true;
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      ctrl.setAv1(true);
      expect(_state(c).av1, isTrue);

      ctrl.setAlpha(true);

      expect(_state(c).alpha, isTrue);
      expect(_state(c).av1, isFalse);
    });
  });

  group('convertAll — sequential batch processing', () {
    test('processes queued items in order, marks done, tracks currentIndex progress',
        () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240)
        ..nextResult = Ok(_realFile(tmp, 'out.webm', 500));
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([
        _realFile(tmp, 'a.mp4', 10),
        _realFile(tmp, 'b.mp4', 10),
        _realFile(tmp, 'c.mp4', 10),
      ]);

      await ctrl.convertAll();

      final s = _state(c);
      expect(s.isProcessing, isFalse);
      expect(s.currentIndex, equals(-1));
      expect(s.doneCount, equals(3));
      expect(s.allDone, isTrue);
    });

    test('per-item ffmpeg error marks that item error, others still process',
        () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240)
        ..nextResult = const Err(FfmpegError(message: 'boom'));
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([
        _realFile(tmp, 'a.mp4', 10),
        _realFile(tmp, 'b.mp4', 10),
      ]);

      await ctrl.convertAll();

      final s = _state(c);
      expect(s.errorCount, equals(2));
      expect(s.items.every((i) => i.status == WebmItemStatus.error), isTrue);
      expect(s.items.every((i) => i.error == 'boom'), isTrue);
      expect(s.allDone, isTrue); // error counts toward allDone too
    });

    test('no queued items → no-op, isProcessing stays false', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _build(c);

      await ctrl.convertAll();

      expect(_state(c).isProcessing, isFalse);
    });

    test('re-entrant convertAll call while already processing is ignored', () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240)
        ..nextResult = Ok(_realFile(tmp, 'out.webm', 500));
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([_realFile(tmp, 'a.mp4', 10)]);

      // isProcessing flips true synchronously (before any await) inside the
      // first call, so the second call's guard sees it deterministically —
      // no timer/microtask race.
      final first = ctrl.convertAll();
      final second = ctrl.convertAll();
      await Future.wait([first, second]);

      expect(_state(c).doneCount, equals(1));
    });
  });

  group('cancel', () {
    test('mid-flight cancel resets the in-flight item to queued and stops the batch before the next item starts',
        () async {
      final backend = _GatedBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240);
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([
        _realFile(tmp, 'a.mp4', 10),
        _realFile(tmp, 'b.mp4', 10),
      ]);

      backend.pause();
      final future = ctrl.convertAll();
      // convertAll runs synchronously up to its first await (inside
      // convertToWebm), so item 0 is already marked converting here.
      expect(_state(c).items[0].status, equals(WebmItemStatus.converting));

      await ctrl.cancel();

      expect(backend.cancelCalled, isTrue);
      expect(_state(c).items[0].status, equals(WebmItemStatus.queued));
      expect(_state(c).items[1].status, equals(WebmItemStatus.queued));
      expect(_state(c).isProcessing, isFalse);
      expect(_state(c).currentIndex, equals(-1));

      // Let the gated in-flight call resolve and the loop unwind — item 1
      // must never have started (loop breaks before it), regardless of how
      // item 0's already-cancelled result eventually lands.
      backend.nextResult = Ok(_realFile(tmp, 'out.webm', 500));
      backend.resume();
      await future;

      expect(_state(c).items[1].status, equals(WebmItemStatus.queued));
    });

    test('cancel with nothing in flight is a safe no-op', () async {
      final backend = FakeFfmpegBackend();
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      await _build(c);

      await c.read(webmConverterControllerProvider.notifier).cancel();

      expect(backend.cancelCalled, isTrue);
      expect(_state(c).isProcessing, isFalse);
    });
  });

  group('exportSingle', () {
    test('single done item: saves, cleans job dir, adds to recents, removes item',
        () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240)
        ..nextResult = Ok(_realFile(tmp, 'out.webm', 500));
      final export = FakeExportService()
        ..returnFile = _realFile(tmp, 'saved.webm', 500);
      final c = _makeContainer(backend: backend, export: export);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([_realFile(tmp, 'a.mp4', 10)]);
      await ctrl.convertAll();

      final ok = await ctrl.exportSingle();

      expect(ok, isTrue);
      expect(_state(c).items, isEmpty);
      expect(export.savedWebmSource, isNotNull);
    });

    test('returns false when more than one item present', () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240)
        ..nextResult = Ok(_realFile(tmp, 'out.webm', 500));
      final c = _makeContainer(backend: backend);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([
        _realFile(tmp, 'a.mp4', 10),
        _realFile(tmp, 'b.mp4', 10),
      ]);
      await ctrl.convertAll();

      final ok = await ctrl.exportSingle();

      expect(ok, isFalse);
      expect(_state(c).items.length, equals(2)); // untouched
    });

    test('returns false when the single item has no output yet (not converted)',
        () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([_realFile(tmp, 'a.mp4', 10)]);

      final ok = await ctrl.exportSingle();

      expect(ok, isFalse);
    });

    test('user cancels save dialog (export returns null) → item stays', () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240)
        ..nextResult = Ok(_realFile(tmp, 'out.webm', 500));
      final export = FakeExportService()..returnFile = null;
      final c = _makeContainer(backend: backend, export: export);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([_realFile(tmp, 'a.mp4', 10)]);
      await ctrl.convertAll();

      final ok = await ctrl.exportSingle();

      expect(ok, isFalse);
      expect(_state(c).items, hasLength(1));
    });
  });

  group('exportBatch', () {
    test('saves only done items, leaves errored items in the list', () async {
      final backend = _SequencedBackend([
        Ok(_realFile(tmp, 'out0.webm', 500)),
        const Err(FfmpegError(message: 'boom')),
        Ok(_realFile(tmp, 'out2.webm', 500)),
      ])..nextProbeResult =
          const MediaInfo(durationMs: 5000, width: 320, height: 240);
      final export = FakeExportService()..returnDirectory = tmp;
      final c = _makeContainer(backend: backend, export: export);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([
        _realFile(tmp, 'a.mp4', 10),
        _realFile(tmp, 'b.mp4', 10),
        _realFile(tmp, 'c.mp4', 10),
      ]);
      await ctrl.convertAll();
      expect(_state(c).doneCount, equals(2));
      expect(_state(c).errorCount, equals(1));

      final saved = await ctrl.exportBatch();

      expect(saved, equals(2));
      expect(_state(c).items.length, equals(1));
      expect(_state(c).items.single.status, equals(WebmItemStatus.error));
    });

    test('returns null when nothing is done yet', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([_realFile(tmp, 'a.mp4', 10)]);

      final saved = await ctrl.exportBatch();

      expect(saved, isNull);
    });

    test('user cancels directory picker (returns null) → items remain', () async {
      final backend = FakeFfmpegBackend()
        ..nextProbeResult =
            const MediaInfo(durationMs: 5000, width: 320, height: 240)
        ..nextResult = Ok(_realFile(tmp, 'out.webm', 500));
      final export = FakeExportService()..returnDirectory = null;
      final c = _makeContainer(backend: backend, export: export);
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([_realFile(tmp, 'a.mp4', 10)]);
      await ctrl.convertAll();

      final saved = await ctrl.exportBatch();

      expect(saved, isNull);
      expect(_state(c).items, hasLength(1));
    });
  });

  group('clear / removeItem', () {
    test('clear empties items and resets processing state', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([_realFile(tmp, 'a.mp4', 10)]);

      ctrl.clear();

      expect(_state(c).items, isEmpty);
      expect(_state(c).isProcessing, isFalse);
      expect(_state(c).currentIndex, equals(-1));
    });

    test('removeItem removes only the matching id', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      final ctrl = await _build(c);
      await ctrl.addFiles([
        _realFile(tmp, 'a.mp4', 10),
        _realFile(tmp, 'b.mp4', 10),
      ]);
      final firstId = _state(c).items.first.id;

      ctrl.removeItem(firstId);

      expect(_state(c).items.length, equals(1));
      expect(_state(c).items.any((i) => i.id == firstId), isFalse);
    });
  });

  group('option persistence', () {
    test('setCrf/setSpeed/setMaxWidth/setAlpha persist across rebuild', () async {
      final backend = FakeFfmpegBackend()..nextSupportsEncoder = true;
      final c1 = _makeContainer(backend: backend);
      final ctrl1 = await _build(c1);
      ctrl1.setCrf(25);
      ctrl1.setSpeed(WebmSpeed.fast);
      ctrl1.setMaxWidth(480);
      ctrl1.setAlpha(true);
      // Let the fire-and-forget _persist() calls (SharedPreferences writes)
      // settle before tearing this container down.
      await Future.delayed(Duration.zero);
      c1.dispose();

      final c2 = _makeContainer(backend: backend);
      addTearDown(c2.dispose);
      await _build(c2);

      final s = _state(c2);
      expect(s.crf, equals(25));
      expect(s.speed, equals(WebmSpeed.fast));
      expect(s.maxWidth, equals(480));
      expect(s.alpha, isTrue);
    });
  });
}
