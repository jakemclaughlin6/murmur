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

  test('play(0) awaits synth, calls setFile+play, pre-synths idx 1', () async {
    final h = await _mkClient();
    addTearDown(() async {
      await h.client.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    final player = FakeAudioPlayerHandle();
    final started = <int>[];
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: started.add,
    );
    queue.setChapter(bookId: 'b1', chapterIdx: 0, sentences: const [
      Sentence('A.'), Sentence('B.'), Sentence('C.'),
    ]);
    await queue.play(0);
    expect(player.calls.take(2).toList(), ['setFile', 'play']);
    expect(player.setFilePaths.single, endsWith('/0/0.wav'));
    expect(started, [0]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(h.engine.generateCallCount, 2);
  });

  test('player completion advances and pre-synths +2', () async {
    final h = await _mkClient();
    addTearDown(() async {
      await h.client.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    final player = FakeAudioPlayerHandle();
    final started = <int>[];
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: started.add,
    );
    queue.setChapter(bookId: 'b1', chapterIdx: 0, sentences: const [
      Sentence('A.'), Sentence('B.'), Sentence('C.'),
    ]);
    await queue.play(0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    player.simulateCompleted();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(started, [0, 1]);
    expect(player.setFilePaths.last, endsWith('/0/1.wav'));
    expect(h.engine.generateCallCount, 3); // 0, 1, 2
  });

  test('skipForward during inflight synth discards result wav', () async {
    final h = await _mkClient(synthDelay: const Duration(milliseconds: 100));
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: (_) {});
    addTearDown(() async {
      await queue.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    queue.setChapter(bookId: 'b1', chapterIdx: 0, sentences: const [
      Sentence('A.'), Sentence('B.'), Sentence('C.'),
    ]);
    final p = queue.play(0);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    queue.skipForward();
    await p.catchError((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(File(h.cache.pathFor('b1', 0, 0)).existsSync(), isFalse,
        reason: 'cancelled synth wav must be deleted');
  });

  test('skipBackward within ring buffer replays without new synth', () async {
    final h = await _mkClient();
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: (_) {});
    addTearDown(() async {
      await queue.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    queue.setChapter(bookId: 'b1', chapterIdx: 0, sentences: const [
      Sentence('A.'), Sentence('B.'), Sentence('C.'), Sentence('D.'),
    ]);
    await queue.play(0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    player.simulateCompleted();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final before = h.engine.generateCallCount;
    await queue.skipBackward();
    expect(h.engine.generateCallCount, before);
    expect(player.setFilePaths.last, endsWith('/0/0.wav'));
  });

  test('setSpeed forwards to player; NEVER reaches worker', () async {
    final h = await _mkClient();
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: (_) {});
    addTearDown(() async {
      await queue.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    queue.setChapter(bookId: 'b1', chapterIdx: 0,
        sentences: const [Sentence('A.')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final before = h.engine.generateCallCount;
    await queue.setSpeed(1.75);
    expect(player.setSpeedValues, [1.75]);
    expect(h.engine.generateCallCount, before,
        reason: 'TTS-09: speed never reaches worker');
  });

  test('setVoice wipes chapter cache, sends SetVoice, resynths currentIdx',
      () async {
    final h = await _mkClient();
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: (_) {});
    addTearDown(() async {
      await queue.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    queue.setChapter(bookId: 'b1', chapterIdx: 0, sentences: const [
      Sentence('A.'), Sentence('B.'),
    ]);
    await queue.play(0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(File(h.cache.pathFor('b1', 0, 0)).existsSync(), isTrue);
    await queue.setVoice('af_sarah');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.engine.lastSid, 3); // af_sarah sid = 3
  });

  test('pause/resume forward to player', () async {
    final h = await _mkClient();
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: (_) {});
    addTearDown(() async {
      await queue.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    queue.setChapter(bookId: 'b1', chapterIdx: 0,
        sentences: const [Sentence('A.')]);
    await queue.play(0);
    await queue.pause();
    await queue.resume();
    expect(player.calls, containsAll(['pause', 'play']));
  });
}
