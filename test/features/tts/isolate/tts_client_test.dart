// test/features/tts/isolate/tts_client_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_client.dart';

import '../../../helpers/fake_tts_engine.dart';

void main() {
  late Directory tempRoot;
  late TtsCache cache;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('tts_client_test_');
    cache = TtsCache(cacheRoot: tempRoot);
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  Future<TtsClient> spawnInProc({
    FakeTtsEngine? engine,
    int initialVoiceSid = 1,
  }) {
    final fake = engine ?? FakeTtsEngine();
    return TtsClient.spawn(
      cache: cache,
      initialVoiceSid: initialVoiceSid,
      engineFactory: () => fake,
    );
  }

  test('lifecycle: spawn emits ModelLoaded, dispose emits DisposeAck', () async {
    final events = <TtsEvent>[];
    final fake = FakeTtsEngine();
    final client = await spawnInProc(engine: fake);
    final sub = client.events.listen(events.add);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events.whereType<ModelLoaded>(), hasLength(1));
    expect(fake.loaded, isTrue);

    await client.dispose();
    await sub.cancel();

    expect(events.whereType<DisposeAck>(), hasLength(1));
    expect(fake.disposed, isTrue);
  });

  test('SynthSentence writes wav and emits SentenceReady with RIFF header',
      () async {
    final client = await spawnInProc();
    final ready = client.events
        .whereType<SentenceReady>()
        .first
        .timeout(const Duration(seconds: 2));

    client.send(const SynthSentence(
      bookId: 'bookA',
      chapterIdx: 0,
      sentenceIdx: 0,
      text: 'Hello world.',
      voiceSid: 1,
    ));

    final evt = await ready;
    expect(evt.sentenceIdx, 0);
    final bytes = await File(evt.wavPath).readAsBytes();
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');

    await client.dispose();
  });

  test('sentence idx correlation across three synths', () async {
    final client = await spawnInProc();
    final collected = <int>[];
    final sub =
        client.events.whereType<SentenceReady>().listen((e) => collected.add(e.sentenceIdx));

    for (var i = 0; i < 3; i++) {
      client.send(SynthSentence(
        bookId: 'bookA',
        chapterIdx: 0,
        sentenceIdx: i,
        text: 'Sentence $i.',
        voiceSid: 1,
      ));
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();
    await client.dispose();

    expect(collected, [0, 1, 2]);
  });

  test('Cancel(idx) discards matching SentenceReady and deletes wav', () async {
    final slowFake = FakeTtsEngine(synthDelay: const Duration(milliseconds: 80));
    final client = await spawnInProc(engine: slowFake);
    final emitted = <SentenceReady>[];
    final sub = client.events.whereType<SentenceReady>().listen(emitted.add);

    client.send(const SynthSentence(
      bookId: 'bookA',
      chapterIdx: 0,
      sentenceIdx: 5,
      text: 'Will be cancelled.',
      voiceSid: 1,
    ));
    client.send(const Cancel(5));

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();
    await client.dispose();

    expect(emitted.where((e) => e.sentenceIdx == 5), isEmpty);
    final expectedPath = cache.pathFor('bookA', 0, 5);
    expect(File(expectedPath).existsSync(), isFalse);
  });

  test('SetVoice switches sid for subsequent synths', () async {
    final fake = FakeTtsEngine();
    final client = await spawnInProc(engine: fake, initialVoiceSid: 1);

    client.send(const SetVoice(7));
    client.send(const SynthSentence(
      bookId: 'bookA',
      chapterIdx: 0,
      sentenceIdx: 0,
      text: 'After SetVoice.',
      voiceSid: 7,
    ));

    await client.events
        .whereType<SentenceReady>()
        .first
        .timeout(const Duration(seconds: 2));
    expect(fake.lastSid, 7);
    await client.dispose();
  });

  test('engine error emits TtsError preserving sentenceIdx', () async {
    final fake = FakeTtsEngine(throwOnGenerate: true);
    final client = await spawnInProc(engine: fake);
    final errFut = client.events
        .whereType<TtsError>()
        .first
        .timeout(const Duration(seconds: 2));

    client.send(const SynthSentence(
      bookId: 'bookA',
      chapterIdx: 0,
      sentenceIdx: 9,
      text: 'boom',
      voiceSid: 1,
    ));

    final err = await errFut;
    expect(err.sentenceIdx, 9);
    expect(err.error, isA<StateError>());
    await client.dispose();
  });

  test('no SentenceReady events fire after DisposeAck', () async {
    final slowFake = FakeTtsEngine(synthDelay: const Duration(milliseconds: 50));
    final client = await spawnInProc(engine: slowFake);

    var ackSeen = false;
    final postAck = <TtsEvent>[];
    final sub = client.events.listen((e) {
      if (ackSeen) postAck.add(e);
      if (e is DisposeAck) ackSeen = true;
    });

    for (var i = 0; i < 3; i++) {
      client.send(SynthSentence(
        bookId: 'bookA',
        chapterIdx: 0,
        sentenceIdx: i,
        text: 'S$i',
        voiceSid: 1,
      ));
    }
    await client.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();

    expect(postAck.whereType<SentenceReady>(), isEmpty);
  });
}
