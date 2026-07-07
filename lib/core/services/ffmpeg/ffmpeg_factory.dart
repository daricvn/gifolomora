import 'dart:io';
import 'ffmpeg_backend.dart';
import 'ffmpeg_dll_backend.dart';
import 'ffmpeg_kit_backend.dart';
import 'ffmpeg_process_backend.dart';

/// Windows: all-in on the DLL backend (PLAN.md §9 decision #2, revisited --
/// no exe anywhere, not even as a mid-session crash fallback). A crashed job
/// is still recovered by gm_shim's VEH guard and returns a clean error; it
/// just doesn't auto-switch to an exe backend afterward, because there is no
/// bundled ffmpeg.exe to switch to. FfmpegProcessBackend / ffmpeg.exe only
/// come into play if gm_shim.dll itself can't be found/loaded at startup --
/// a dev-machine-without-the-DLL-built situation, not a runtime fault.
abstract final class FfmpegFactory {
  static FfmpegBackend create() {
    if (Platform.isAndroid || Platform.isIOS) {
      return FfmpegKitBackend();
    }
    if (Platform.isWindows) {
      final dllPath = FfmpegDllBackend.tryResolvePath();
      if (dllPath != null) {
        return FfmpegDllBackend(dllPath: dllPath);
      }
    }
    return FfmpegProcessBackend(
      ffmpegPath: FfmpegProcessBackend.resolveBin('ffmpeg'),
      ffprobePath: FfmpegProcessBackend.resolveBin('ffprobe'),
    );
  }
}
