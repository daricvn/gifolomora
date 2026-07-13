import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ffmpeg/ffmpeg_backend.dart';
import 'ffmpeg/ffmpeg_factory.dart';
import 'ffmpeg/ffmpeg_service.dart';
import 'files/export_service.dart';
import 'files/temp_file_service.dart';
import 'permissions/permission_service.dart';
import 'recents/recents_service.dart';
import 'record/native_window_channel.dart';
import 'record/record_settings_service.dart';

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

// ── Screen Record ──────────────────────────────────────────────────────────────

final recordSettingsServiceProvider = Provider<RecordSettingsService>(
  (_) => RecordSettingsService(),
  name: 'recordSettingsServiceProvider',
);

final nativeWindowChannelProvider = Provider<NativeWindowChannel>(
  (_) => NativeWindowChannel(),
  name: 'nativeWindowChannelProvider',
);

// ── App settings ───────────────────────────────────────────────────────────────

/// Global user preferences (app-wide, not per-tool options).
class AppSettings {
  const AppSettings({this.softwareVideoPreview = false});

  /// Windows: render the video preview through media_kit's software
  /// (pixel-buffer) path instead of the default D3D11/ANGLE hardware path.
  /// Works around intermittent black flashes from the plugin's unsynchronized
  /// shared-texture pipeline on some GPUs. Costs CPU and caps the preview
  /// texture at 1080p. The player is configured once at preview mount, so a
  /// change applies the next time the editor is opened.
  final bool softwareVideoPreview;
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
  name: 'appSettingsProvider',
);

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  static const _kSoftwareVideoPreview = 'software_video_preview';

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      softwareVideoPreview: prefs.getBool(_kSoftwareVideoPreview) ?? false,
    );
  }

  Future<void> setSoftwareVideoPreview(bool value) async {
    state = AsyncData(AppSettings(softwareVideoPreview: value));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSoftwareVideoPreview, value);
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
