import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/recents/recents_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  RecentExport makeExport(String path) => RecentExport(
        path: path,
        toolName: 'Test Tool',
        toolRoute: '/test',
        timestamp: DateTime(2024, 1, 1),
      );

  group('RecentExport', () {
    test('JSON round-trip preserves all fields', () {
      final ts = DateTime(2024, 6, 15, 12, 0, 0);
      final item = RecentExport(
        path: '/output/test.gif',
        toolName: 'Crop GIF',
        toolRoute: '/crop',
        timestamp: ts,
      );
      final restored = RecentExport.fromJson(item.toJson());
      expect(restored.path, equals(item.path));
      expect(restored.toolName, equals(item.toolName));
      expect(restored.toolRoute, equals(item.toolRoute));
      expect(
        restored.timestamp.millisecondsSinceEpoch,
        equals(ts.millisecondsSinceEpoch),
      );
    });
  });

  group('RecentsService', () {
    test('load returns empty list initially', () async {
      final svc = RecentsService();
      expect(await svc.load(), isEmpty);
    });

    test('add prepends item (newest first)', () async {
      final svc = RecentsService();
      await svc.add(makeExport('/a.gif'));
      await svc.add(makeExport('/b.gif'));
      final items = await svc.load();
      expect(items.first.path, equals('/b.gif'));
      expect(items[1].path, equals('/a.gif'));
    });

    test('add caps list at 10 items', () async {
      final svc = RecentsService();
      for (int i = 0; i < 12; i++) {
        await svc.add(makeExport('/file_$i.gif'));
      }
      final items = await svc.load();
      expect(items.length, equals(10));
    });

    test('oldest item dropped when over 10', () async {
      final svc = RecentsService();
      for (int i = 0; i < 11; i++) {
        await svc.add(makeExport('/file_$i.gif'));
      }
      final items = await svc.load();
      expect(items.any((e) => e.path == '/file_0.gif'), isFalse);
    });

    test('clear removes all items', () async {
      final svc = RecentsService();
      await svc.add(makeExport('/x.gif'));
      await svc.clear();
      expect(await svc.load(), isEmpty);
    });
  });
}
