import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'model_manifest.dart';

enum ModelInstallReason {
  pathTraversal,
  sizeOverflow,
  archiveCorrupt,
  ioError,
}

class ModelInstallException implements Exception {
  final ModelInstallReason reason;
  final Object? underlying;
  ModelInstallException(this.reason, [this.underlying]);
  @override
  String toString() =>
      'ModelInstallException(reason=$reason, underlying=$underlying)';
}

/// Extracts the Kokoro tar.bz2 archive into [stagingDir], validates each
/// entry against path traversal and size overflow, then atomic-renames
/// `model.int8.onnx` into [finalDir]. Sets the installed flag AFTER the
/// rename succeeds — never before.
class ModelInstaller {
  static const String installedFlagKey = 'tts.model_installed';
  static const String installedSha256Key = 'tts.model_sha256';

  Future<void> installFromArchive({
    required File archive,
    required Directory finalDir,
    required Directory stagingDir,
    required SharedPreferences prefs,
  }) async {
    if (stagingDir.existsSync()) stagingDir.deleteSync(recursive: true);
    stagingDir.createSync(recursive: true);
    final stagingCanonical = p.canonicalize(stagingDir.path);

    Archive decoded;
    try {
      final bz2 = BZip2Decoder().decodeBytes(await archive.readAsBytes());
      decoded = TarDecoder().decodeBytes(bz2);
    } catch (e) {
      _cleanup(stagingDir);
      throw ModelInstallException(ModelInstallReason.archiveCorrupt, e);
    }

    try {
      for (final entry in decoded.files) {
        if (!entry.isFile) continue;
        final name = entry.name;
        if (name.contains('..') ||
            name.startsWith('/') ||
            name.startsWith(r'\')) {
          throw ModelInstallException(ModelInstallReason.pathTraversal);
        }
        if (entry.size > ModelManifest.downloadMaxBytes) {
          throw ModelInstallException(ModelInstallReason.sizeOverflow);
        }
        final outPath = p.canonicalize(p.join(stagingDir.path, name));
        if (!p.isWithin(stagingCanonical, outPath)) {
          throw ModelInstallException(ModelInstallReason.pathTraversal);
        }
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>, flush: true);
      }

      final stagedModel =
          File(p.join(stagingDir.path, 'kokoro-en-v0_19', 'model.int8.onnx'));
      if (!stagedModel.existsSync()) {
        throw ModelInstallException(ModelInstallReason.archiveCorrupt,
            'model.int8.onnx not found inside archive');
      }

      await finalDir.create(recursive: true);
      final finalModel = File(p.join(finalDir.path, 'model.int8.onnx'));
      await stagedModel.rename(finalModel.path);

      await prefs.setBool(installedFlagKey, true);
      await prefs.setString(installedSha256Key, ModelManifest.archiveSha256);
    } on ModelInstallException {
      _cleanup(stagingDir);
      rethrow;
    } catch (e) {
      _cleanup(stagingDir);
      throw ModelInstallException(ModelInstallReason.ioError, e);
    }

    _cleanup(stagingDir);
  }

  static void _cleanup(Directory d) {
    try {
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {
      // best effort
    }
  }
}
