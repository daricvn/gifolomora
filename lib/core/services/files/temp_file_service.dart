import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/logger.dart';

class TempFileService {
  static const _tag = 'TempFileService';
  static const _dirName = 'gifolomora_jobs';

  String? _base;

  Future<String> get _baseDir async {
    if (_base != null) return _base!;
    final tmp = await getTemporaryDirectory();
    _base = p.join(tmp.path, _dirName);
    await Directory(_base!).create(recursive: true);
    return _base!;
  }

  /// Creates a unique job directory. Returns its path.
  Future<String> createJobDir() async {
    final base = await _baseDir;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dir = Directory(p.join(base, id));
    await dir.create(recursive: true);
    return dir.path;
  }

  /// Returns a unique output path under a job dir.
  Future<String> tempOutputPath(String jobDir, String ext) async {
    return p.join(jobDir, 'output.$ext');
  }

  /// Copies [frames] into [jobDir] with sequential names; returns new paths.
  Future<List<String>> copyFrames(List<File> frames, String jobDir) async {
    final result = <String>[];
    for (int i = 0; i < frames.length; i++) {
      final ext = p.extension(frames[i].path).toLowerCase();
      final dest = p.join(jobDir, 'frame_${i.toString().padLeft(4, '0')}$ext');
      await frames[i].copy(dest);
      result.add(dest);
    }
    return result;
  }

  /// Deletes [jobDir] silently.
  Future<void> cleanJob(String jobDir) async {
    try {
      final dir = Directory(jobDir);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      Log.e(_tag, 'cleanJob failed for $jobDir', e);
    }
  }

  /// Sweeps stale job dirs older than [maxAge]. Call on app start.
  Future<void> sweepStale({Duration maxAge = const Duration(hours: 1)}) async {
    try {
      final base = await _baseDir;
      final dir = Directory(base);
      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete(recursive: true).catchError((_) => entity);
          }
        }
      }
    } catch (e) {
      Log.e(_tag, 'sweepStale failed', e);
    }
  }
}
