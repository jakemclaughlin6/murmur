// lib/features/tts/providers/tts_queue_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/playback_state.dart';
import '../isolate/tts_cache_provider.dart';
import '../queue/tts_queue.dart';
import 'just_audio_provider.dart';
import 'tts_worker_provider.dart';

part 'tts_queue_provider.g.dart';

/// Constructs a `TtsQueue` bound to the current active `bookId`.
/// Chapter/sentence content is pushed by the reader through
/// `queue.setChapter(...)` (Phase 5 wiring). This provider only
/// dispatches isPlaying / speed / voiceId mutations.
@Riverpod(keepAlive: true)
Future<TtsQueue?> ttsQueue(Ref ref) async {
  final bookId = ref.watch(playbackStateProvider.select((s) => s.bookId));
  if (bookId == null) return null;

  final cache = ref.watch(ttsCacheProvider);
  final client = await ref.watch(ttsWorkerProvider(bookId).future);
  final player = ref.watch(audioPlayerProvider);
  final queue = TtsQueue(
    client: client,
    cache: cache,
    player: player,
    onSentenceStart: (idx) => ref
        .read(playbackStateProvider.notifier)
        .setSentence(idx),
  );
  ref.onDispose(() async {
    try { await queue.dispose(); } catch (_) {/* benign */}
  });

  ref.listen<PlaybackState>(playbackStateProvider, (prev, next) {
    if (next.bookId != bookId) return;
    if (prev?.isPlaying != next.isPlaying) {
      if (next.isPlaying) { queue.resume(); } else { queue.pause(); }
    }
    if (prev?.speed != next.speed) queue.setSpeed(next.speed);
    if (prev?.voiceId != next.voiceId) queue.setVoice(next.voiceId);
  });

  return queue;
}
