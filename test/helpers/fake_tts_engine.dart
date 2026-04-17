// test/helpers/fake_tts_engine.dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:murmur/features/tts/isolate/messages.dart';

/// Deterministic sine-wave TTS fake.
///
/// - 24 kHz mono (matches Kokoro output shape so downstream wavWrap
///   stays exercised in tests).
/// - Duration = 100 ms per character, clamped to [100 ms, 10 s].
/// - Echoes the latest `sid` in [lastSid] for SetVoice tests.
/// - `generate` is synchronous (mirrors sherpa contract). The
///   message-loop wrapper schedules a pre-generate
///   `Future.delayed(synthDelay)` so cancel-discards tests have a race
///   window; production code has no such delay.
class FakeTtsEngine implements TtsEngine {
  FakeTtsEngine({
    this.synthDelay = Duration.zero,
    this.throwOnGenerate = false,
  });

  final Duration synthDelay;
  final bool throwOnGenerate;

  int? lastSid;
  int generateCallCount = 0;
  bool loaded = false;
  bool disposed = false;

  @override
  Future<void> load() async {
    loaded = true;
  }

  @override
  SynthResult generate({
    required String text,
    required int sid,
    required double speed,
  }) {
    assert(speed == 1.0, 'TTS-09: length_scale must be 1.0');
    generateCallCount += 1;
    lastSid = sid;
    if (throwOnGenerate) {
      throw StateError('FakeTtsEngine: forced failure for sentence "$text"');
    }
    const sampleRate = 24000;
    final durationMs = (text.length * 100).clamp(100, 10000);
    final n = (sampleRate * durationMs / 1000).round();
    final samples = Float32List(n);
    for (var i = 0; i < n; i++) {
      samples[i] = 0.5 * math.sin(2 * math.pi * 440 * i / sampleRate);
    }
    return SynthResult(samples, sampleRate);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
