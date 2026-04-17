// lib/features/tts/isolate/messages.dart
import 'dart:typed_data';

/// Command sent UI → worker. Sealed: pattern-match in handlers (D-13).
sealed class TtsCommand {
  const TtsCommand();
}

final class SynthSentence extends TtsCommand {
  final String bookId;
  final int chapterIdx;
  final int sentenceIdx;
  final String text;
  final int voiceSid;
  const SynthSentence({
    required this.bookId,
    required this.chapterIdx,
    required this.sentenceIdx,
    required this.text,
    required this.voiceSid,
  });
}

/// Soft cancel (D-12): client discards the next `SentenceReady(sentenceIdx)`
/// the worker emits. sherpa_onnx 1.12.36 has no interrupt primitive.
final class Cancel extends TtsCommand {
  final int sentenceIdx;
  const Cancel(this.sentenceIdx);
}

final class SetVoice extends TtsCommand {
  final int sid;
  const SetVoice(this.sid);
}

final class Dispose extends TtsCommand {
  const Dispose();
}

/// Event worker → UI. Sealed.
sealed class TtsEvent {
  const TtsEvent();
}

final class ModelLoaded extends TtsEvent {
  const ModelLoaded();
}

final class SentenceReady extends TtsEvent {
  final int sentenceIdx;
  final String wavPath;
  const SentenceReady(this.sentenceIdx, this.wavPath);
}

final class TtsError extends TtsEvent {
  final int? sentenceIdx;
  final Object error;
  const TtsError(this.sentenceIdx, this.error);
}

final class DisposeAck extends TtsEvent {
  const DisposeAck();
}

/// Contract implemented by the real sherpa adapter and the test fake.
abstract class TtsEngine {
  Future<void> load();
  SynthResult generate({
    required String text,
    required int sid,
    required double speed,
  });
  Future<void> dispose();
}

class SynthResult {
  final Float32List samples;
  final int sampleRate;
  const SynthResult(this.samples, this.sampleRate);
}

typedef TtsEngineFactory = TtsEngine Function();
