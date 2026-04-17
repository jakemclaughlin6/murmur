import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/model/model_manifest.dart';

void main() {
  group('ModelManifest', () {
    test('voiceCatalog has exactly 11 entries', () {
      expect(ModelManifest.voiceCatalog.length, 11);
    });

    test('all voiceId strings are unique', () {
      final ids = ModelManifest.voiceCatalog.map((v) => v.voiceId).toSet();
      expect(ids.length, 11);
    });

    test('all sid values are 0..10 contiguous', () {
      final sids = ModelManifest.voiceCatalog.map((v) => v.sid).toList()..sort();
      expect(sids, List.generate(11, (i) => i));
    });

    test('defaultVoiceId is present in the catalog', () {
      expect(ModelManifest.byVoiceId(ModelManifest.defaultVoiceId), isNotNull);
    });

    test('byVoiceId returns null for unknown id', () {
      expect(ModelManifest.byVoiceId('no_such_voice'), isNull);
    });

    test('downloadUrl is HTTPS on github.com', () {
      final uri = Uri.parse(ModelManifest.downloadUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, 'github.com');
    });

    test('archiveSha256 is a placeholder OR 64 lowercase hex chars', () {
      const h = ModelManifest.archiveSha256;
      const isPlaceholder = h == 'PENDING_04_02';
      final isSha = RegExp(r'^[0-9a-f]{64}$').hasMatch(h);
      expect(isPlaceholder || isSha, isTrue);
    });

    test('downloadMaxBytes > archiveBytes', () {
      expect(ModelManifest.downloadMaxBytes, greaterThan(ModelManifest.archiveBytes));
    });

    test('previewSentence is non-empty and reasonably short', () {
      expect(ModelManifest.previewSentence, isNotEmpty);
      expect(ModelManifest.previewSentence.length, lessThan(200));
    });
  });
}
