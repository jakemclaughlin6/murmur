import 'dart:io';

import 'package:flutter/services.dart'
    show AssetBundle, AssetManifest, rootBundle;
import 'package:path/path.dart' as p;

import 'paths.dart';

class KokoroAssetCopyException implements Exception {
  final String path;
  final Object underlying;
  KokoroAssetCopyException(this.path, this.underlying);

  @override
  String toString() =>
      'KokoroAssetCopyException(path=$path, underlying=$underlying)';
}

/// Copies every `assets/kokoro/**` asset from [bundle] (defaults to
/// [rootBundle]) into the [KokoroPaths] root directory under [supportDir],
/// preserving layout.
///
/// Idempotent: files whose byte length already matches are skipped.
///
/// Throws [StateError] if the manifest contains `assets/kokoro/model.int8.onnx`
/// (guards against an accidental commit blowing past the 150 MB AAB limit).
/// Throws [KokoroAssetCopyException] for any filesystem error during copy.
Future<KokoroPaths> copyBundledKokoroAssets(
  Directory supportDir, {
  AssetBundle? bundle,
}) async {
  final b = bundle ?? rootBundle;
  final paths = KokoroPaths.forSupportDir(supportDir.path);

  final manifest = await AssetManifest.loadFromAssetBundle(b);
  final assets = manifest
      .listAssets()
      .where((k) => k.startsWith('assets/kokoro/') && !k.endsWith('/'))
      .toList();

  if (assets.contains('assets/kokoro/model.int8.onnx')) {
    throw StateError(
      'assets/kokoro/model.int8.onnx must NOT be bundled — it is downloaded '
      'at runtime (see ModelDownloader). Remove it from pubspec.yaml assets.',
    );
  }

  try {
    await Directory(paths.rootDir).create(recursive: true);
    for (final assetPath in assets) {
      final relative = assetPath.substring('assets/kokoro/'.length);
      final dest = File(p.join(paths.rootDir, relative));
      final data = await b.load(assetPath);
      final expectedLen = data.lengthInBytes;
      if (dest.existsSync() && dest.lengthSync() == expectedLen) {
        continue;
      }
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
  } catch (e) {
    if (e is StateError) rethrow;
    throw KokoroAssetCopyException(paths.rootDir, e);
  }

  return paths;
}
