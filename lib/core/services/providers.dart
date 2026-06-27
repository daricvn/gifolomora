import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ffmpeg/ffmpeg_backend.dart';
import 'ffmpeg/ffmpeg_factory.dart';
import 'ffmpeg/ffmpeg_service.dart';
import 'files/export_service.dart';
import 'files/temp_file_service.dart';
import 'permissions/permission_service.dart';
import 'recents/recents_service.dart';
import 'settings/settings_service.dart';

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
    gifsicleePath: FfmpegFactory.resolveGifsicle(),
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

// ── Settings ───────────────────────────────────────────────────────────────────

final settingsServiceProvider = Provider<SettingsService>(
  (_) => SettingsService(),
  name: 'settingsServiceProvider',
);

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
  name: 'settingsProvider',
);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() =>
      ref.read(settingsServiceProvider).load();

  Future<void> save(AppSettings s) async {
    await ref.read(settingsServiceProvider).save(s);
    state = AsyncData(s);
  }
}

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
