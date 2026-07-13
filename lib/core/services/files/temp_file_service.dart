import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/logger.dart';

class TempFileService {
  static const _tag = 'TempFileService';
  static const _dirName = 'gifolomora_jobs';

  String? _base;

  /// Job dirs created outside the shared base (a `baseDirOverride` — Screen
  /// Record's custom save folder). [wipeAll] deletes only the base dir, so
  /// these must be tracked and deleted individually or they survive app
  /// exit. Static because the exit path constructs its own fresh
  /// [TempFileService] instance (see `app.dart`'s `onWindowClose`).
  static final Set<String> _overrideJobDirs = {};

  /// Monotonic suffix so two same-microsecond [createJobDir] calls still get
  /// distinct dirs. Static: uniqueness must hold across service instances.
  static int _seq = 0;

  Future<String> get _baseDir async {
    if (_base != null) return _base!;
    final tmp = await getTemporaryDirectory();
    _base = p.join(tmp.path, _dirName);
    await Directory(_base!).create(recursive: true);
    return _base!;
  }

  /// Creates a unique job directory. Returns its path. [baseDirOverride]
  /// swaps the system-temp base for a user-chosen folder (Screen Record's
  /// "save to" setting) — every other caller keeps the default.
  Future<String> createJobDir({String? baseDirOverride}) async {
    final base = baseDirOverride ?? await _baseDir;
    final micros = DateTime.now().microsecondsSinceEpoch;
    final id = '${micros}_${_seq++}';
    final dir = Directory(p.join(base, id));
    await dir.create(recursive: true);
    if (baseDirOverride != null) _overrideJobDirs.add(dir.path);
    return dir.path;
  }

  /// Returns a unique output path under a job dir.
  Future<String> tempOutputPath(String jobDir, String ext) async {
    return p.join(jobDir, 'output.$ext');
  }

  /// Decodes [frames] and re-writes them as BMP into [jobDir] (sequential
  /// names); returns new paths. BMP, not a straight copy: frames can arrive
  /// in mixed input formats (png/jpg/webp/...) and the concat demuxer needs
  /// a uniform codec across all listed files. BMP needs no external decoder
  /// lib and is always present, regardless of which input codecs the shim
  /// build has compiled in.
  Future<List<String>> copyFrames(List<File> frames, String jobDir) async {
    final result = <String>[];
    for (int i = 0; i < frames.length; i++) {
      final bytes = await frames[i].readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw FormatException('Unrecognized image format: ${frames[i].path}');
      }
      final dest = p.join(jobDir, 'frame_${i.toString().padLeft(4, '0')}.bmp');
      await File(dest).writeAsBytes(img.encodeBmp(decoded));
      result.add(dest);
    }
    return result;
  }

  /// Deletes [jobDir] silently.
  Future<void> cleanJob(String jobDir) async {
    try {
      final dir = Directory(jobDir);
      if (await dir.exists()) await dir.delete(recursive: true);
      _overrideJobDirs.remove(jobDir);
    } catch (e) {
      Log.e(_tag, 'cleanJob failed for $jobDir', e);
    }
  }

  /// Deletes the whole job base dir (every job, regardless of age/owner)
  /// plus every tracked override job dir — a custom-save-folder recording
  /// lives outside the base, so deleting the base alone leaves it behind.
  /// Call on app exit — per-job cleanup only ever frees the caller's own
  /// dir, leaving sibling dirs (other controllers' history/working dirs)
  /// orphaned on disk.
  Future<void> wipeAll() async {
    for (final jobDir in _overrideJobDirs.toList()) {
      try {
        final dir = Directory(jobDir);
        if (await dir.exists()) await dir.delete(recursive: true);
        _overrideJobDirs.remove(jobDir);
      } catch (e) {
        Log.e(_tag, 'wipeAll failed for override dir $jobDir', e);
      }
    }
    try {
      final base = await _baseDir;
      final dir = Directory(base);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      Log.e(_tag, 'wipeAll failed', e);
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
