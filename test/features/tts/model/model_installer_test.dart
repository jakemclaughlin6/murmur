import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/model/model_installer.dart';
import 'package:murmur/features/tts/model/paths.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List buildTarBz2(List<({String name, Uint8List data})> entries) {
    final archive = Archive();
    for (final e in entries) {
      archive.addFile(ArchiveFile(e.name, e.data.length, e.data));
    }
    final tar = TarEncoder().encode(archive);
    return Uint8List.fromList(BZip2Encoder().encode(tar));
  }

  ({File archive, Directory support}) stageArchive(Uint8List archiveBytes) {
    final root = Directory.systemTemp.createTempSync('murmur_install_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final archive = File(p.join(root.path, 'kokoro.tar.bz2'))
      ..writeAsBytesSync(archiveBytes);
    final support = Directory(p.join(root.path, 'support'))..createSync();
    return (archive: archive, support: support);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('happy path: model.int8.onnx extracted, flag set, staging cleaned',
      () async {
    final model = Uint8List.fromList(List.generate(1024, (i) => i % 251));
    final bytes = buildTarBz2([
      (name: 'kokoro-en-v0_19/model.int8.onnx', data: model),
      (name: 'kokoro-en-v0_19/voices.bin', data: Uint8List(4)),
    ]);
    final st = stageArchive(bytes);
    final finalDir = Directory(KokoroPaths.forSupportDir(st.support.path).rootDir)
      ..createSync(recursive: true);
    final stagingDir = Directory('${finalDir.path}.installing');
    final prefs = await SharedPreferences.getInstance();

    await ModelInstaller().installFromArchive(
      archive: st.archive,
      finalDir: finalDir,
      stagingDir: stagingDir,
      prefs: prefs,
    );

    final outFile = File(p.join(finalDir.path, 'model.int8.onnx'));
    expect(outFile.existsSync(), isTrue);
    expect(outFile.lengthSync(), model.length);
    expect(stagingDir.existsSync(), isFalse);
    expect(prefs.getBool(ModelInstaller.installedFlagKey), isTrue);
  });

  test('path-traversal entry -> pathTraversal + flag unset', () async {
    final bytes = buildTarBz2([
      (name: '../evil.txt', data: Uint8List.fromList([1, 2, 3])),
    ]);
    final st = stageArchive(bytes);
    final finalDir = Directory(KokoroPaths.forSupportDir(st.support.path).rootDir)
      ..createSync(recursive: true);
    final prefs = await SharedPreferences.getInstance();

    expect(
      () => ModelInstaller().installFromArchive(
        archive: st.archive,
        finalDir: finalDir,
        stagingDir: Directory('${finalDir.path}.installing'),
        prefs: prefs,
      ),
      throwsA(isA<ModelInstallException>().having(
          (e) => e.reason, 'reason', ModelInstallReason.pathTraversal)),
    );
    expect(prefs.getBool(ModelInstaller.installedFlagKey), isNull);
  });

  test('absolute-path entry -> pathTraversal', () async {
    final bytes = buildTarBz2([
      (name: '/etc/passwd', data: Uint8List.fromList([0])),
    ]);
    final st = stageArchive(bytes);
    final finalDir = Directory(KokoroPaths.forSupportDir(st.support.path).rootDir)
      ..createSync(recursive: true);
    final prefs = await SharedPreferences.getInstance();

    expect(
      () => ModelInstaller().installFromArchive(
        archive: st.archive,
        finalDir: finalDir,
        stagingDir: Directory('${finalDir.path}.installing'),
        prefs: prefs,
      ),
      throwsA(isA<ModelInstallException>().having(
          (e) => e.reason, 'reason', ModelInstallReason.pathTraversal)),
    );
  });

  test('corrupt archive -> archiveCorrupt', () async {
    final root = Directory.systemTemp.createTempSync('murmur_install_bad_');
    addTearDown(() => root.deleteSync(recursive: true));
    final archive = File(p.join(root.path, 'kokoro.tar.bz2'))
      ..writeAsBytesSync(List.filled(64, 0));
    final finalDir = Directory(p.join(root.path, 'final'))..createSync();
    final prefs = await SharedPreferences.getInstance();

    expect(
      () => ModelInstaller().installFromArchive(
        archive: archive,
        finalDir: finalDir,
        stagingDir: Directory('${finalDir.path}.installing'),
        prefs: prefs,
      ),
      throwsA(isA<ModelInstallException>().having(
          (e) => e.reason, 'reason', ModelInstallReason.archiveCorrupt)),
    );
  });
}
