import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ffmpeg/ffmpeg_backend.dart';
import 'ffmpeg/ffmpeg_factory.dart';
import 'ffmpeg/ffmpeg_service.dart';
import 'files/export_service.dart';
import 'files/temp_file_service.dart';
import 'permissions/permission_service.dart';
import 'recents/recents_service.dart';

// ── FFmpeg ─────────────────────────────────────────────────────────────────────

final ffmpegBackendProvider = Provider<FfmpegBackend>(
  (ref) {
    final backend = FfmpegFactory.create();
    ref.onDispose(backend.dispose);
    return backend;
  },
  name: 'ffmpegBackendProvider',
);

final tempFileServiceProvider = Provider<TempFileService>(
  (_) => TempFileService(),
  name: 'tempFileServiceProvider',
);

final ffmpegServiceProvider = Provider<FfmpegService>(
  (ref) => FfmpegService(
    ref.watch(ffmpegBackendProvider),
    ref.watch(tempFileServiceProvider),
  ),
  name: 'ffmpegServiceProvider',
);

final exportServiceProvider = Provider<ExportService>(
  (_) => ExportService(),
  name: 'exportServiceProvider',
);

final permissionServiceProvider = Provider<PermissionService>(
  (_) => PermissionService(),
  name: 'permissionServiceProvider',
);

// ── Recents ────────────────────────────────────────────────────────────────────

final recentsServiceProvider = Provider<RecentsService>(
  (_) => RecentsService(),
  name: 'recentsServiceProvider',
);

final recentsProvider =
    AsyncNotifierProvider<RecentsNotifier, List<RecentExport>>(
  RecentsNotifier.new,
  name: 'recentsProvider',
);

class RecentsNotifier extends AsyncNotifier<List<RecentExport>> {
  @override
  Future<List<RecentExport>> build() =>
      ref.read(recentsServiceProvider).load();

  Future<void> add(RecentExport item) async {
    await ref.read(recentsServiceProvider).add(item);
    state = AsyncData(
        [item, ...state.valueOrNull ?? <RecentExport>[]].take(10).toList());
  }

  Future<void> clear() async {
    await ref.read(recentsServiceProvider).clear();
    state = const AsyncData([]);
  }
}
