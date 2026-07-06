import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gifolomora/core/services/files/temp_file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // TempFileService resolves its base dir via path_provider's
  // getTemporaryDirectory, a real platform channel with no test-harness
  // implementation — point it at a scratch dir under the OS temp folder so
  // the rest of the service (real Directory/File I/O) runs unmocked.
  final testTempDir = Directory.systemTemp.createTempSync('gifolomora_test_');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    channel,
    (call) async =>
        call.method == 'getTemporaryDirectory' ? testTempDir.path : null,
  );

  tearDownAll(() => testTempDir.deleteSync(recursive: true));

  test('wipeAll deletes every job dir under the shared base, not just one', () async {
    final svc = TempFileService();
    final jobA = await svc.createJobDir();
    final jobB = await svc.createJobDir();
    await File('$jobA/output.gif').writeAsBytes([1, 2, 3]);
    await File('$jobB/output.gif').writeAsBytes([4, 5, 6]);

    await svc.wipeAll();

    expect(await Directory(jobA).exists(), isFalse);
    expect(await Directory(jobB).exists(), isFalse);
  });

  test('wipeAll deletes override job dirs living outside the base — even '
      'from a different TempFileService instance', () async {
    // A custom save folder (Screen Record's "save to" setting) puts the job
    // dir outside the shared base; app exit constructs its own fresh
    // TempFileService, so tracking must survive across instances.
    final overrideBase =
        Directory('${testTempDir.path}/custom_save')..createSync();
    final jobDir = await TempFileService()
        .createJobDir(baseDirOverride: overrideBase.path);
    await File('$jobDir/output.mp4').writeAsBytes([1, 2, 3]);

    await TempFileService().wipeAll();

    expect(await Directory(jobDir).exists(), isFalse,
        reason: 'override job dir must be wiped on exit');
    expect(await overrideBase.exists(), isTrue,
        reason: "the user's chosen folder itself must never be deleted");
  });

  test('cleanJob untracks an override dir so wipeAll does not retry it',
      () async {
    final overrideBase =
        Directory('${testTempDir.path}/custom_save2')..createSync();
    final svc = TempFileService();
    final jobDir =
        await svc.createJobDir(baseDirOverride: overrideBase.path);

    await svc.cleanJob(jobDir);
    expect(await Directory(jobDir).exists(), isFalse);

    // Recreate an unrelated dir at the same path — wipeAll must not touch
    // it, since cleanJob already released ownership.
    Directory(jobDir).createSync();
    await TempFileService().wipeAll();
    expect(await Directory(jobDir).exists(), isTrue);
    Directory(jobDir).deleteSync();
  });

  test('wipeAll is a safe no-op when the base dir was never created', () async {
    // Fresh instance whose _baseDir hasn't been resolved via createJobDir —
    // wipeAll must still resolve it and not throw even though there was
    // nothing to sweep away yet.
    final svc = TempFileService();
    await svc.wipeAll();
  });
}
