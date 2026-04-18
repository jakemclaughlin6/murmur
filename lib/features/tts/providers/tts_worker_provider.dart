// lib/features/tts/providers/tts_worker_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../isolate/tts_cache_provider.dart';
import '../isolate/tts_client.dart';
import '../model/model_manifest.dart';

part 'tts_worker_provider.g.dart';

/// Family keyed by `bookId`. Spawns a real-isolate `TtsClient` in prod.
/// Tests override this provider per-bookId with an in-process spawn
/// that supplies a `FakeTtsEngine`.
@Riverpod(keepAlive: true)
Future<TtsClient> ttsWorker(Ref ref, String bookId) async {
  final cache = ref.watch(ttsCacheProvider);
  final sid = ModelManifest.byVoiceId(ModelManifest.defaultVoiceId)!.sid;
  final client = await TtsClient.spawn(cache: cache, initialVoiceSid: sid);
  ref.onDispose(() async {
    try { await client.dispose(); } catch (_) {/* benign on shutdown */}
  });
  return client;
}
