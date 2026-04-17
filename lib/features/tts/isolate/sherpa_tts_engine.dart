// lib/features/tts/isolate/sherpa_tts_engine.dart
//
// Stub created during Task 6. Task 7 replaces the body with the real
// sherpa_onnx adapter. This stub is intentionally non-functional so
// that `tts_worker_main.dart` compiles before the real adapter lands;
// the stub is never instantiated in tests (in-process mode uses
// FakeTtsEngine) and production only runs after Task 7 replaces it.
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/model/paths.dart';

class SherpaTtsEngine implements TtsEngine {
  SherpaTtsEngine(this.paths);
  final KokoroPaths paths;

  @override
  Future<void> load() async {
    throw UnimplementedError('SherpaTtsEngine stub — replaced in Task 7');
  }

  @override
  SynthResult generate({
    required String text,
    required int sid,
    required double speed,
  }) {
    throw UnimplementedError('SherpaTtsEngine stub — replaced in Task 7');
  }

  @override
  Future<void> dispose() async {}
}
