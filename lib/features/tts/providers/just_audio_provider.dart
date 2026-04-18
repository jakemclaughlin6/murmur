// lib/features/tts/providers/just_audio_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../queue/just_audio_player.dart';

part 'just_audio_provider.g.dart';

/// App-singleton `AudioPlayerHandle`. Disposed with the root container.
@Riverpod(keepAlive: true)
AudioPlayerHandle audioPlayer(Ref ref) {
  final h = JustAudioPlayerHandle();
  ref.onDispose(() async {
    try { await h.dispose(); } catch (_) {/* benign */}
  });
  return h;
}
