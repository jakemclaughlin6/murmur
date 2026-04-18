// test/features/tts/providers/tts_worker_provider_test.dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_cache_provider.dart';
import 'package:murmur/features/tts/isolate/tts_client.dart';
import 'package:murmur/features/tts/providers/tts_worker_provider.dart';

import '../../../helpers/fake_tts_engine.dart';

void main() {
  test('ttsWorker(bookId) honors override → in-process client', () async {
    final tmp = Directory.systemTemp.createTempSync('worker_test');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final cache = TtsCache(cacheRoot: tmp);

    final container = ProviderContainer(overrides: [
      ttsCacheProvider.overrideWithValue(cache),
      ttsWorkerProvider('b1').overrideWith(
        (ref) async => TtsClient.spawn(
          cache: cache,
          initialVoiceSid: 1,
          engineFactory: () => FakeTtsEngine(),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final client = await container.read(ttsWorkerProvider('b1').future);
    await client.events.whereType<ModelLoaded>().first;
    expect(client, isA<TtsClient>());
  });
}
