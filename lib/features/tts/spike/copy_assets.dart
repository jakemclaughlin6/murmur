// Spike-only: this file is scaffolding for Wave 0 on-device verification and
// will be rewritten in Wave 1.
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copy bundled Kokoro assets from rootBundle to
/// `getApplicationSupportDirectory()/kokoro-en-v0_19/`.
///
/// sherpa_onnx needs real filesystem paths at runtime; it cannot read
/// directly from the Flutter asset bundle. Idempotent: files with
/// matching byte length are skipped. `model.int8.onnx` is NOT copied
/// here — that is downloaded at runtime in a later wave.
///
/// Returns the absolute path to the target directory.
Future<String> copyKokoroAssetsToSupportDir() async {
  final support = await getApplicationSupportDirectory();
  final targetRoot = Directory(p.join(support.path, 'kokoro-en-v0_19'));
  await targetRoot.create(recursive: true);

  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final kokoroPaths = manifest
      .listAssets()
      .where((k) => k.startsWith('assets/kokoro/') && !k.endsWith('/'))
      .toList();

  for (final assetPath in kokoroPaths) {
    final relative = assetPath.substring('assets/kokoro/'.length);
    final dest = File(p.join(targetRoot.path, relative));
    final bytes = await rootBundle.load(assetPath);
    final expectedLen = bytes.lengthInBytes;
    if (dest.existsSync() && dest.lengthSync() == expectedLen) {
      continue;
    }
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    ));
  }

  return targetRoot.path;
}
