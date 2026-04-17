import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/model/model_assets.dart';
import 'package:path/path.dart' as p;

/// Minimal in-memory AssetBundle that serves `AssetManifest.bin` encoded with
/// [StandardMessageCodec], as Flutter 3.41's `AssetManifest.loadFromAssetBundle`
/// requires on non-web platforms.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._assets);
  final Map<String, Uint8List> _assets;

  // Build a StandardMessageCodec-encoded binary manifest from the asset keys.
  // The manifest is a Map<String, List<Map<String, dynamic>>> where each asset
  // maps to a list of variant objects with an 'asset' key.
  ByteData _buildBinaryManifest() {
    final manifestMap = <String, List<Map<String, dynamic>>>{
      for (final k in _assets.keys)
        k: [
          {'asset': k},
        ],
    };
    const codec = StandardMessageCodec();
    return codec.encodeMessage(manifestMap)!;
  }

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return _buildBinaryManifest();
    }
    final v = _assets[key];
    if (v == null) throw FlutterError('asset not found: $key');
    return ByteData.sublistView(v);
  }
}

Uint8List _filled(int n, int v) => Uint8List(n)..fillRange(0, n, v);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Directory tmp() {
    final d = Directory.systemTemp.createTempSync('murmur_assets_');
    addTearDown(() {
      if (d.existsSync()) d.deleteSync(recursive: true);
    });
    return d;
  }

  test('copies every assets/kokoro/** entry to supportDir/kokoro-en-v0_19/',
      () async {
    final bundle = _FakeBundle({
      'assets/kokoro/voices.bin': _filled(1024, 1),
      'assets/kokoro/tokens.txt': _filled(8, 2),
      'assets/kokoro/espeak-ng-data/lang/ine/en': _filled(16, 3),
      'assets/kokoro/LICENSE': _filled(4, 4),
    });
    final dir = tmp();

    final paths = await copyBundledKokoroAssets(dir, bundle: bundle);

    expect(paths.rootDir, p.join(dir.path, 'kokoro-en-v0_19'));
    expect(File(paths.voicesFile).lengthSync(), 1024);
    expect(File(paths.tokensFile).lengthSync(), 8);
    expect(
        File(p.join(paths.espeakDir, 'lang', 'ine', 'en')).existsSync(), isTrue);
    expect(File(p.join(paths.rootDir, 'LICENSE')).lengthSync(), 4);
  });

  test('is idempotent when target file byte length already matches', () async {
    final bundle = _FakeBundle({
      'assets/kokoro/voices.bin': _filled(1024, 1),
      'assets/kokoro/tokens.txt': _filled(8, 2),
    });
    final dir = tmp();

    await copyBundledKokoroAssets(dir, bundle: bundle);
    final modelFile =
        File(p.join(dir.path, 'kokoro-en-v0_19', 'voices.bin'));
    final stat1 = modelFile.statSync();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await copyBundledKokoroAssets(dir, bundle: bundle);
    final stat2 = modelFile.statSync();
    expect(stat2.modified, stat1.modified,
        reason: 'idempotent skip did not re-write file');
  });

  test('throws StateError if manifest contains model.int8.onnx (guard)',
      () async {
    final bundle = _FakeBundle({
      'assets/kokoro/voices.bin': _filled(1, 1),
      'assets/kokoro/model.int8.onnx': _filled(1, 0xff),
    });
    final dir = tmp();
    expect(
      () => copyBundledKokoroAssets(dir, bundle: bundle),
      throwsA(isA<StateError>()),
    );
  });

  test('wraps I/O errors in KokoroAssetCopyException', () async {
    final bundle = _FakeBundle({'assets/kokoro/voices.bin': _filled(1, 1)});
    // Point supportDir at a path whose parent is a file → mkdir must fail.
    final blockerRoot =
        Directory.systemTemp.createTempSync('murmur_blocker_');
    addTearDown(() => blockerRoot.deleteSync(recursive: true));
    final blocker = File(p.join(blockerRoot.path, 'notadir'))
      ..writeAsBytesSync(<int>[0]);
    final bogusSupport = Directory(p.join(blocker.path, 'nested'));
    expect(
      () => copyBundledKokoroAssets(bogusSupport, bundle: bundle),
      throwsA(isA<KokoroAssetCopyException>()),
    );
  });
}
