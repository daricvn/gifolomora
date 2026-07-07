import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/ffmpeg/ffmpeg_job_pool.dart';

void main() {
  group('FfmpegJobPool', () {
    test('runs a single job and returns its result', () async {
      final pool = FfmpegJobPool(maxConcurrent: 2);
      final result = await pool.run(() async => 42);
      expect(result, equals(42));
    });

    test('caps concurrency at maxConcurrent', () async {
      final pool = FfmpegJobPool(maxConcurrent: 2);
      var running = 0;
      var maxSeen = 0;
      final completers = List.generate(5, (_) => Completer<void>());

      final futures = List.generate(5, (i) {
        return pool.run(() async {
          running++;
          maxSeen = running > maxSeen ? running : maxSeen;
          await completers[i].future;
          running--;
        });
      });

      // Let the pool admit as many as it will.
      await Future<void>.delayed(Duration.zero);
      expect(running, equals(2));

      // Release one, a third should be admitted.
      completers[0].complete();
      await Future<void>.delayed(Duration.zero);
      expect(running, equals(2));

      completers[1].complete();
      completers[2].complete();
      completers[3].complete();
      completers[4].complete();
      await Future.wait(futures);

      expect(maxSeen, equals(2));
    });

    test('a job throwing does not wedge the pool for the next job', () async {
      final pool = FfmpegJobPool(maxConcurrent: 1);
      await expectLater(
        pool.run(() async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );
      final result = await pool.run(() async => 'ok');
      expect(result, equals('ok'));
    });
  });
}
