import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:murmur/features/tts/spike/copy_assets.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('copyKokoroAssetsToSupportDir', () {
    testWidgets('copies bundled Kokoro assets idempotently', (tester) async {
      final supportDir = await getApplicationSupportDirectory();
      final target = Directory(p.join(supportDir.path, 'kokoro-en-v0_19'));
      if (await target.exists()) {
        await target.delete(recursive: true);
      }

      final resolved = await copyKokoroAssetsToSupportDir();
      expect(resolved, equals(target.path));
      expect(File(p.join(target.path, 'voices.bin')).existsSync(), isTrue);
      expect(File(p.join(target.path, 'tokens.txt')).existsSync(), isTrue);
      expect(
        Directory(p.join(target.path, 'espeak-ng-data')).existsSync(),
        isTrue,
      );
      final voicesBytes = await File(p.join(target.path, 'voices.bin')).length();
      expect(voicesBytes, greaterThan(5 * 1024 * 1024));

      // Second call must be idempotent — no throw, same path, same size.
      final resolved2 = await copyKokoroAssetsToSupportDir();
      expect(resolved2, equals(resolved));
      final voicesBytes2 = await File(p.join(target.path, 'voices.bin')).length();
      expect(voicesBytes2, equals(voicesBytes));
    });
  });
}
