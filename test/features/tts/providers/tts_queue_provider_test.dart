// test/features/tts/providers/tts_queue_provider_test.dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/playback_state.dart';
import 'package:murmur/core/text/sentence.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_cache_provider.dart';
import 'package:murmur/features/tts/isolate/tts_client.dart';
import 'package:murmur/features/tts/providers/just_audio_provider.dart';
import 'package:murmur/features/tts/providers/tts_queue_provider.dart';
import 'package:murmur/features/tts/providers/tts_worker_provider.dart';

import '../../../helpers/fake_audio_player.dart';
import '../../../helpers/fake_tts_engine.dart';

void main() {
  test('returns null when bookId is null', () async {
    final tmp = Directory.systemTemp.createTempSync('q_null');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final container = ProviderContainer(overrides: [
      ttsCacheProvider.overrideWithValue(TtsCache(cacheRoot: tmp)),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(ttsQueueProvider.future), isNull);
  });

  test('speed mutation forwards to player; never to engine', () async {
    final tmp = Directory.systemTemp.createTempSync('q_drive');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final cache = TtsCache(cacheRoot: tmp);
    late FakeTtsEngine engine;
    final fakePlayer = FakeAudioPlayerHandle();

    final container = ProviderContainer(overrides: [
      ttsCacheProvider.overrideWithValue(cache),
      audioPlayerProvider.overrideWithValue(fakePlayer),
      ttsWorkerProvider('b1').overrideWith((ref) async => TtsClient.spawn(
            cache: cache,
            initialVoiceSid: 1,
            engineFactory: () => engine = FakeTtsEngine(),
          )),
    ]);
    addTearDown(container.dispose);

    container.read(playbackStateProvider.notifier).setBook('b1');
    final queue = await container.read(ttsQueueProvider.future);
    expect(queue, isNotNull);
    queue!.setChapter(
      bookId: 'b1', chapterIdx: 0,
      sentences: const [Sentence('A.')],
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final before = engine.generateCallCount;

    container.read(playbackStateProvider.notifier).setSpeed(1.5);
    await Future<void>.delayed(Duration.zero);

    expect(fakePlayer.setSpeedValues, [1.5]);
    expect(engine.generateCallCount, before);
  });
}
