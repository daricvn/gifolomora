import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentExport {
  const RecentExport({
    required this.path,
    required this.toolName,
    required this.toolRoute,
    required this.timestamp,
  });

  final String path;
  final String toolName;
  final String toolRoute;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'path': path,
        'toolName': toolName,
        'toolRoute': toolRoute,
        'ts': timestamp.millisecondsSinceEpoch,
      };

  factory RecentExport.fromJson(Map<String, dynamic> j) => RecentExport(
        path: j['path'] as String,
        toolName: j['toolName'] as String,
        toolRoute: j['toolRoute'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
      );
}

class RecentsService {
  static const _key = 'recent_exports';
  static const _max = 10;

  Future<List<RecentExport>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    return raw
        .map((s) =>
            RecentExport.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(RecentExport item) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    final updated =
        [jsonEncode(item.toJson()), ...raw].take(_max).toList();
    await p.setStringList(_key, updated);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
