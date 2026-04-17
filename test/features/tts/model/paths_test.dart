import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/model/paths.dart';
import 'package:path/path.dart' as p;

void main() {
  group('KokoroPaths', () {
    const support = '/tmp/app_support';
    final paths = KokoroPaths.forSupportDir(support);

    test('rootDir lives under the support dir', () {
      expect(paths.rootDir, p.join(support, 'kokoro-en-v0_19'));
    });

    test('modelFile, voicesFile, tokensFile, espeakDir are under rootDir', () {
      expect(p.isWithin(paths.rootDir, paths.modelFile), isTrue);
      expect(p.isWithin(paths.rootDir, paths.voicesFile), isTrue);
      expect(p.isWithin(paths.rootDir, paths.tokensFile), isTrue);
      expect(p.isWithin(paths.rootDir, paths.espeakDir), isTrue);
      expect(p.basename(paths.modelFile), 'model.int8.onnx');
      expect(p.basename(paths.voicesFile), 'voices.bin');
      expect(p.basename(paths.tokensFile), 'tokens.txt');
      expect(p.basename(paths.espeakDir), 'espeak-ng-data');
    });
  });
}
