// Shared dart:ffi bindings for gm_shim.dll (windows/ffmpeg_shim/), used by
// both FfmpegDllBackend (job-shaped FfmpegBackend implementation) and
// ScreenRecorderService (open-ended, cancel-controlled recording sessions --
// same shape as the old Process-based recorder, gm_execute/gm_cancel standing
// in for Process.start/stdin "q").
import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'ffmpeg_progress.dart' show MediaInfo;

final class GmMediaInfoStruct extends Struct {
  @Int64()
  external int durationMs;
  @Int32()
  external int width;
  @Int32()
  external int height;
  @Double()
  external double fps;
  @Int32()
  external int hasAudio;
}

typedef GmExecuteNative = Int32 Function(Int64, Int32, Pointer<Pointer<Utf8>>);
typedef GmExecuteDart = int Function(int, int, Pointer<Pointer<Utf8>>);

typedef GmCancelNative = Void Function(Int64);
typedef GmCancelDart = void Function(int);

typedef GmProbeNative = Int32 Function(Pointer<Utf8>, Pointer<GmMediaInfoStruct>);
typedef GmProbeDart = int Function(Pointer<Utf8>, Pointer<GmMediaInfoStruct>);

typedef GmSupportsEncoderNative = Int32 Function(Pointer<Utf8>);
typedef GmSupportsEncoderDart = int Function(Pointer<Utf8>);

typedef GmGetLogsNative = Int32 Function(Int64, Pointer<Utf8>, Int32);
typedef GmGetLogsDart = int Function(int, Pointer<Utf8>, int);

const int kGmLogBufSize = 65536;

/// Matches gm_shim.h's GM_ERR_CRASH -- returned when the VEH/SEH guard caught
/// a native crash inside gm_execute.
const int gmCrashExitCode = -1000;

/// fftools' own cancellation sentinel: `exit_program((received_nb_signals ||
/// cancelRequested(...)) ? 255 : main_ffmpeg_return_code)` in
/// fftools_ffmpeg.c. Distinguishes "stopped by gm_cancel()" from a real
/// ffmpeg error, confirmed via a real gdigrab capture + cancel() (Phase 3
/// recorder port) -- not from reading the source alone.
const int gmCancelledExitCode = 255;

/// Single counter shared by every gm_shim.dll consumer in the app
/// (FfmpegDllBackend jobs and ScreenRecorderService segments alike) --
/// session ids are a lookup key into gm_shim's fixed-size session table, so
/// two independent counters could hand out the same id to two genuinely
/// concurrent sessions (e.g. exporting a GIF while recording) and cross-wire
/// gm_cancel()/cancelRequested() between them.
class GmSessionIds {
  GmSessionIds._();
  static int _next = 1;
  static int allocate() => _next++;
}

class GmExecResult {
  const GmExecResult(this.rc, this.logs);
  final int rc;
  final String logs;
}

/// Args passed across the Isolate.run boundary. Plain data only (String,
/// int, list of String) -- no Pointer crosses the boundary, every native
/// allocation is made and freed inside the spawned isolate.
class GmExecRequest {
  const GmExecRequest(this.dllPath, this.sessionId, this.argv);
  final String dllPath;
  final int sessionId;
  final List<String> argv;
}

Future<GmExecResult> gmExecuteInIsolate(GmExecRequest req) async {
  final lib = DynamicLibrary.open(req.dllPath);
  final gmExecute = lib.lookupFunction<GmExecuteNative, GmExecuteDart>('gm_execute');
  final gmGetLogs = lib.lookupFunction<GmGetLogsNative, GmGetLogsDart>('gm_get_logs');

  final argvPtrs = calloc<Pointer<Utf8>>(req.argv.length);
  for (var i = 0; i < req.argv.length; i++) {
    argvPtrs[i] = req.argv[i].toNativeUtf8();
  }

  int rc;
  try {
    rc = gmExecute(req.sessionId, req.argv.length, argvPtrs);
  } finally {
    for (var i = 0; i < req.argv.length; i++) {
      calloc.free(argvPtrs[i]);
    }
    calloc.free(argvPtrs);
  }

  final logBuf = calloc<Uint8>(kGmLogBufSize);
  String logs = '';
  try {
    final n = gmGetLogs(req.sessionId, logBuf.cast<Utf8>(), kGmLogBufSize);
    logs = logBuf.cast<Utf8>().toDartString(length: n);
  } finally {
    calloc.free(logBuf);
  }

  return GmExecResult(rc, logs);
}

MediaInfo? gmProbeInIsolate(String dllPath, String inputPath) {
  final lib = DynamicLibrary.open(dllPath);
  final gmProbe = lib.lookupFunction<GmProbeNative, GmProbeDart>('gm_probe');

  final pathPtr = inputPath.toNativeUtf8();
  final infoPtr = calloc<GmMediaInfoStruct>();
  try {
    final rc = gmProbe(pathPtr, infoPtr);
    if (rc != 0) return null;
    final info = infoPtr.ref;
    return MediaInfo(
      durationMs: info.durationMs,
      width: info.width,
      height: info.height,
      fps: info.fps > 0 ? info.fps : null,
      hasAudio: info.hasAudio != 0,
    );
  } finally {
    calloc.free(pathPtr);
    calloc.free(infoPtr);
  }
}

bool gmSupportsEncoderInIsolate(String dllPath, String encoderName) {
  final lib = DynamicLibrary.open(dllPath);
  final gmSupports =
      lib.lookupFunction<GmSupportsEncoderNative, GmSupportsEncoderDart>('gm_supports_encoder');
  final namePtr = encoderName.toNativeUtf8();
  try {
    return gmSupports(namePtr) != 0;
  } finally {
    calloc.free(namePtr);
  }
}

/// Thin, synchronous wrapper for the one call site (cancel) that doesn't
/// need Isolate.run -- gm_cancel() just flips an atomic flag, it's not a
/// blocking native call.
class GmShim {
  GmShim(this.dllPath);
  final String dllPath;

  void cancel(int sessionId) {
    final lib = DynamicLibrary.open(dllPath);
    final gmCancel = lib.lookupFunction<GmCancelNative, GmCancelDart>('gm_cancel');
    gmCancel(sessionId);
  }

  Future<GmExecResult> execute(int sessionId, List<String> argv) {
    return Isolate.run(() => gmExecuteInIsolate(GmExecRequest(dllPath, sessionId, argv)));
  }

  Future<MediaInfo?> probe(String inputPath) {
    return Isolate.run(() => gmProbeInIsolate(dllPath, inputPath));
  }

  Future<bool> supportsEncoder(String encoderName) {
    return Isolate.run(() => gmSupportsEncoderInIsolate(dllPath, encoderName));
  }
}
