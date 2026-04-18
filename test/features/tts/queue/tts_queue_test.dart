import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/text/sentence.dart';
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_client.dart';
import 'package:murmur/features/tts/queue/tts_queue.dart';

import '../../../helpers/fake_audio_player.dart';
import '../../../helpers/fake_tts_engine.dart';

class _Harness {
  _Harness(this.client, this.cache, this.engine, this.tmp);
  final TtsClient client;
  final TtsCache cache;
  final FakeTtsEngine engine;
  final Directory tmp;
}

Future<_Harness> _mkClient({Duration synthDelay = Duration.zero}) async {
  final tmp = Directory.systemTemp.createTempSync('tts_queue_test');
  final cache = TtsCache(cacheRoot: tmp);
  late FakeTtsEngine engine;
  final client = await TtsClient.spawn(
    cache: cache,
    initialVoiceSid: 1,
    engineFactory: () => engine = FakeTtsEngine(synthDelay: synthDelay),
  );
  await client.events.whereType<ModelLoaded>().first;
  return _Harness(client, cache, engine, tmp);
}

void main() {
  test('setChapter kicks off SynthSentence for idx 0 (D-11 pre-synth)',
      () async {
    final h = await _mkClient();
    addTearDown(() async {
      await h.client.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client,
      cache: h.cache,
      player: player,
      onSentenceStart: (_) {},
    );
    queue.setChapter(
      bookId: 'b1',
      chapterIdx: 0,
      sentences: const [Sentence('Hello world.'), Sentence('Second.')],
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.engine.generateCallCount, 1);
  });
}
