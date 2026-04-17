import 'package:path/path.dart' as p;

/// Canonical layout of Kokoro model + bundled assets on disk.
///
/// Single source of truth: every other caller that needs a path MUST go
/// through here. Grep for 'kokoro-en-v0_19' should return only this file.
class KokoroPaths {
  final String rootDir;
  const KokoroPaths._(this.rootDir);

  factory KokoroPaths.forSupportDir(String appSupport) =>
      KokoroPaths._(p.join(appSupport, 'kokoro-en-v0_19'));

  String get modelFile => p.join(rootDir, 'model.int8.onnx');
  String get voicesFile => p.join(rootDir, 'voices.bin');
  String get tokensFile => p.join(rootDir, 'tokens.txt');
  String get espeakDir => p.join(rootDir, 'espeak-ng-data');
}
