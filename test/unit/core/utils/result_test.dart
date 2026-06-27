import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/utils/result.dart';

void main() {
  group('Ok', () {
    test('isOk → true', () {
      expect(const Ok<int, String>(42).isOk, isTrue);
    });

    test('isErr → false', () {
      expect(const Ok<int, String>(42).isErr, isFalse);
    });

    test('value returns wrapped value', () {
      expect(const Ok<int, String>(42).value, equals(42));
    });

    test('error throws StateError', () {
      expect(() => const Ok<int, String>(42).error, throwsStateError);
    });

    test('fold calls ok branch', () {
      final result = const Ok<int, String>(7).fold(
        ok: (v) => 'ok:$v',
        err: (e) => 'err:$e',
      );
      expect(result, equals('ok:7'));
    });
  });

  group('Err', () {
    test('isOk → false', () {
      expect(const Err<int, String>('oops').isOk, isFalse);
    });

    test('isErr → true', () {
      expect(const Err<int, String>('oops').isErr, isTrue);
    });

    test('error returns wrapped error', () {
      expect(const Err<int, String>('oops').error, equals('oops'));
    });

    test('value throws StateError', () {
      expect(() => const Err<int, String>('oops').value, throwsStateError);
    });

    test('fold calls err branch', () {
      final result = const Err<int, String>('oops').fold(
        ok: (v) => 'ok:$v',
        err: (e) => 'err:$e',
      );
      expect(result, equals('err:oops'));
    });
  });
}
