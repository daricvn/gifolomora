import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/record/record_target.dart';
import 'package:screen_retriever/screen_retriever.dart';

Display _display({
  required Size size,
  Offset visiblePosition = Offset.zero,
  num scaleFactor = 1,
  String? name,
}) =>
    Display(
      id: 0,
      name: name,
      size: size,
      visiblePosition: visiblePosition,
      scaleFactor: scaleFactor,
    );

void main() {
  test('1x scale: physical == logical', () {
    final t = RecordTarget.fromDisplay(
      _display(size: const Size(1920, 1080), name: r'\\.\DISPLAY1'),
      index: 0,
      isPrimary: true,
    );
    expect(t.physicalX, 0);
    expect(t.physicalY, 0);
    expect(t.physicalW, 1920);
    expect(t.physicalH, 1080);
    expect(t.label, 'Display 1 (Primary)');
    expect(t.name, r'\\.\DISPLAY1');
  });

  test('1.5x scale: multiplies logical px, clamps odd dims to even', () {
    final t = RecordTarget.fromDisplay(
      _display(
        size: const Size(1281, 721), // 1281*1.5=1921.5 -> 1922 -> even 1922
        visiblePosition: const Offset(1920, 0),
        scaleFactor: 1.5,
      ),
      index: 1,
      isPrimary: false,
    );
    expect(t.physicalX, 2880); // 1920 * 1.5
    expect(t.physicalY, 0);
    expect(t.physicalW, 1922); // round(1921.5)=1922, already even
    expect(t.physicalH, 1082); // round(1081.5)=1082 (721*1.5=1081.5)
    expect(t.label, 'Display 2');
  });

  test('2x scale on a monitor left of primary (negative logical offset)', () {
    final t = RecordTarget.fromDisplay(
      _display(
        size: const Size(1920, 1080),
        visiblePosition: const Offset(-1920, 0),
        scaleFactor: 2,
      ),
      index: 0,
      isPrimary: false,
    );
    expect(t.physicalX, -3840);
    expect(t.physicalY, 0);
    expect(t.physicalW, 3840);
    expect(t.physicalH, 2160);
  });

  test('missing name falls back to a stable synthetic id', () {
    final t = RecordTarget.fromDisplay(
      _display(size: const Size(800, 600)),
      index: 2,
      isPrimary: false,
    );
    expect(t.name, 'display-2');
  });

  test('odd physical width from rounding is clamped down to even', () {
    final t = RecordTarget.fromDisplay(
      _display(size: const Size(641, 481), scaleFactor: 1),
      index: 0,
      isPrimary: false,
    );
    expect(t.physicalW, 640);
    expect(t.physicalH, 480);
  });
}
