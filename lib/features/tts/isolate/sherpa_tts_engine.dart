// lib/features/tts/isolate/sherpa_tts_engine.dart
import 'dart:io';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/model/paths.dart';

/// Real sherpa_onnx adapter. Only instantiated inside the worker
/// isolate. Assumes the model is already installed under
/// [paths.rootDir] (Wave 1 installer).
///
/// This is the ONLY file in `lib/` that imports `package:sherpa_onnx`.
/// `test/architecture/no_direct_network_test.dart` enforces that.
class SherpaTtsEngine implements TtsEngine {
  SherpaTtsEngine(this.paths);

  final KokoroPaths paths;
  sherpa.OfflineTts? _tts;
  bool _bindingsInitialized = false;

  @override
  Future<void> load() async {
    if (!File(paths.modelFile).existsSync()) {
      throw StateError(
        'Kokoro model missing at ${paths.modelFile} — TTS-02 installer incomplete',
      );
    }
    if (!_bindingsInitialized) {
      sherpa.initBindings();
      _bindingsInitialized = true;
    }
    final kokoro = sherpa.OfflineTtsKokoroModelConfig(
      model: paths.modelFile,
      voices: paths.voicesFile,
      tokens: paths.tokensFile,
      dataDir: paths.espeakDir,
      lexicon: '',
    );
    final modelConfig = sherpa.OfflineTtsModelConfig(
      vits: const sherpa.OfflineTtsVitsModelConfig(),
      kokoro: kokoro,
      numThreads: 2,
      debug: false,
      provider: 'cpu',
    );
    _tts = sherpa.OfflineTts(sherpa.OfflineTtsConfig(model: modelConfig));
  }

  @override
  SynthResult generate({
    required String text,
    required int sid,
    required double speed,
  }) {
    assert(speed == 1.0, 'TTS-09: length_scale must be 1.0 — use just_audio.setSpeed()');
    final tts = _tts;
    if (tts == null) throw StateError('SherpaTtsEngine.load() was not called');
    final audio = tts.generateWithConfig(
      text: text,
      config: sherpa.OfflineTtsGenerationConfig(sid: sid, speed: 1.0),
    );
    return SynthResult(audio.samples, audio.sampleRate);
  }

  @override
  Future<void> dispose() async {
    _tts?.free(); // Pitfall 8: release native state before isolate exit.
    _tts = null;
  }
}
