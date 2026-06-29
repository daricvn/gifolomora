import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/features/text_overlay/model/text_item.dart';

void main() {
  group('TextItem coord helpers', () {
    test('round-trip: local → nx → px', () {
      const mw = 320.0;
      const mh = 240.0;
      const scale = 2.0;
      const localX = 100.0;
      const localY = 80.0;

      final nx = TextItem.nxFromLocal(localX, scale, mw);
      final ny = TextItem.nyFromLocal(localY, scale, mh);
      expect(TextItem.pxX(nx, mw), equals((localX / scale).round()));
      expect(TextItem.pxY(ny, mh), equals((localY / scale).round()));
    });

    test('leftFromNx / topFromNy invert nxFromLocal / nyFromLocal', () {
      const mw = 400.0;
      const mh = 300.0;
      const scale = 1.5;
      final nx = TextItem.nxFromLocal(60.0, scale, mw);
      final ny = TextItem.nyFromLocal(45.0, scale, mh);
      expect(TextItem.leftFromNx(nx, mw, scale), closeTo(60.0, 0.001));
      expect(TextItem.topFromNy(ny, mh, scale), closeTo(45.0, 0.001));
    });

    test('previewFontSize scales by factor', () {
      expect(TextItem.previewFontSize(36, 1.5), closeTo(54.0, 0.001));
    });

    test('nxFromLocal clamps negative to 0', () {
      final nx = TextItem.nxFromLocal(-100, 1.0, 320.0);
      expect(nx, equals(0.0));
    });

    test('nxFromLocal clamps overflow to <1', () {
      final nx = TextItem.nxFromLocal(1000, 1.0, 320.0);
      expect(nx, lessThan(1.0));
    });
  });

  group('TextItem copyWith', () {
    test('clamps nx/ny on copyWith', () {
      const item = TextItem(id: 'x', text: 'hi', nx: 0.5, ny: 0.5);
      final moved = item.copyWith(nx: 1.5, ny: -0.1);
      expect(moved.nx, lessThan(1.0));
      expect(moved.ny, equals(0.0));
    });

    test('preserves unchanged fields', () {
      const item = TextItem(
        id: 'x',
        text: 'hello',
        nx: 0.3,
        ny: 0.3,
        fontSize: 48,
        fontColor: 'FF0000',
        strokeColor: '000000',
        strokeWidth: 3,
        style: TextStyleKind.bold,
      );
      final copy = item.copyWith(text: 'world');
      expect(copy.id, equals('x'));
      expect(copy.text, equals('world'));
      expect(copy.fontSize, equals(48));
      expect(copy.fontColor, equals('FF0000'));
      expect(copy.strokeWidth, equals(3));
      expect(copy.style, equals(TextStyleKind.bold));
    });
  });
}
