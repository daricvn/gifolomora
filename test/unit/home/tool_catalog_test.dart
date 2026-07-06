import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/features/home/data/tool_catalog.dart';

void main() {
  group('toolCatalog', () {
    test('total of 8 tools', () {
      expect(toolCatalog.length, equals(8));
    });

    test('all tool routes are unique', () {
      final routes = toolCatalog.map((t) => t.route).toSet();
      expect(routes.length, equals(toolCatalog.length));
    });

    test('all tools have non-empty id, label, and description', () {
      for (final tool in toolCatalog) {
        expect(tool.id, isNotEmpty);
        expect(tool.label, isNotEmpty);
        expect(tool.description, isNotEmpty);
      }
    });

    test('createTools returns only ToolCategory.create entries', () {
      expect(createTools.every((t) => t.category == ToolCategory.create), isTrue);
    });

    test('refineTools returns only ToolCategory.refine entries', () {
      expect(refineTools.every((t) => t.category == ToolCategory.refine), isTrue);
    });

    test('createTools + refineTools = full catalog', () {
      expect(createTools.length + refineTools.length, equals(toolCatalog.length));
    });

    test('video-to-gif and images-to-gif are create tools', () {
      final routes = createTools.map((t) => t.route).toSet();
      expect(routes, containsAll(['/video-studio', '/images-to-gif']));
    });

    test('refine tools include resize, crop, text-overlay, optimize, effects', () {
      final routes = refineTools.map((t) => t.route).toSet();
      expect(routes,
          containsAll(['/resize', '/crop', '/text-overlay', '/optimize', '/effects']));
    });

    test('screen_record is windowsOnly and hidden off-Windows', () {
      final entry = toolCatalog.firstWhere((t) => t.id == 'screen_record');
      expect(entry.windowsOnly, isTrue);
      expect(entry.category, ToolCategory.create);
      final inCreate = createTools.any((t) => t.id == 'screen_record');
      expect(inCreate, Platform.isWindows);
    });
  });
}
