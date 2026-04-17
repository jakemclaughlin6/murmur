import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:murmur/features/tts/model/model_assets.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('copyBundledKokoroAssets', () {
    testWidgets('copies bundled Kokoro assets idempotently', (tester) async {
      final supportDir = await getApplicationSupportDirectory();
      final paths = await copyBundledKokoroAssets(supportDir);
      final target = Directory(paths.rootDir);

      addTearDown(() async {
        if (await target.exists()) {
          await target.delete(recursive: true);
        }
      });

      expect(File(paths.voicesFile).existsSync(), isTrue);
      expect(File(paths.tokensFile).existsSync(), isTrue);
      expect(Directory(paths.espeakDir).existsSync(), isTrue);
      final voicesBytes = await File(paths.voicesFile).length();
      expect(voicesBytes, greaterThan(5 * 1024 * 1024));

      // Second call must be idempotent — no throw, same size.
      final paths2 = await copyBundledKokoroAssets(supportDir);
      expect(paths2.rootDir, equals(paths.rootDir));
      final voicesBytes2 = await File(paths2.voicesFile).length();
      expect(voicesBytes2, equals(voicesBytes));
    });
  });
}
