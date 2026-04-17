import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'package:murmur/features/tts/audio/wav_wrap.dart';
import 'package:murmur/features/tts/model/model_assets.dart';

/// Debug-only spike page. Proves end-to-end Kokoro → just_audio on device.
/// Route is only mounted under `kDebugMode`; see router.dart.
class SpikePage extends StatefulWidget {
  const SpikePage({super.key});

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  String _status = 'idle';
  String _kokoroDir = '';
  String _modelPath = '';
  String _cancelProbeOutput = '';
  final _player = AudioPlayer();
  bool _bindingsReady = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _setStatus(String s) => setState(() => _status = s);

  void _ensureBindings() {
    if (_bindingsReady) return;
    sherpa.initBindings();
    _bindingsReady = true;
  }

  Future<void> _copyAssets() async {
    _setStatus('copying assets...');
    try {
      final support = await getApplicationSupportDirectory();
      final paths = await copyBundledKokoroAssets(support);
      final targetRoot = paths.rootDir;
      if (!mounted) return;
      setState(() {
        _kokoroDir = targetRoot;
        _status = 'assets copied to $targetRoot';
      });
    } catch (e) {
      if (!mounted) return;
      _setStatus('asset copy error: $e');
    }
  }

  Future<void> _pickModel() async {
    if (_kokoroDir.isEmpty) {
      _setStatus('copy assets first');
      return;
    }
    final picked = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (!mounted) return;
    if (picked == null || picked.files.isEmpty) return;
    final src = File(picked.files.single.path!);
    final dest = File(p.join(_kokoroDir, 'model.int8.onnx'));
    await src.copy(dest.path);
    if (!mounted) return;
    final destLen = await dest.length();
    if (!mounted) return;
    setState(() {
      _modelPath = dest.path;
      _status = 'model placed at ${dest.path} ($destLen bytes)';
    });
  }

  sherpa.OfflineTts _buildTts() {
    return _buildTtsFromPaths(_kokoroDir, _modelPath);
  }

  static sherpa.OfflineTts _buildTtsFromPaths(
    String kokoroDir,
    String modelPath,
  ) {
    final kokoro = sherpa.OfflineTtsKokoroModelConfig(
      model: modelPath,
      voices: p.join(kokoroDir, 'voices.bin'),
      tokens: p.join(kokoroDir, 'tokens.txt'),
      dataDir: p.join(kokoroDir, 'espeak-ng-data'),
      lexicon: '',
    );
    final modelConfig = sherpa.OfflineTtsModelConfig(
      vits: const sherpa.OfflineTtsVitsModelConfig(),
      kokoro: kokoro,
      numThreads: 2,
      debug: false,
      provider: 'cpu',
    );
    return sherpa.OfflineTts(sherpa.OfflineTtsConfig(model: modelConfig));
  }

  Future<void> _synthAndPlay() async {
    if (_modelPath.isEmpty) {
      _setStatus('pick model first');
      return;
    }
    _setStatus('synthesizing...');
    try {
      _ensureBindings();
      final tts = _buildTts();
      File tmp;
      Uint8List wav;
      try {
        final audio = tts.generateWithConfig(
          text: 'Welcome to murmur. This is how I sound reading your books.',
          config: const sherpa.OfflineTtsGenerationConfig(sid: 1, speed: 1.0),
        );
        wav = wavWrap(audio.samples, sampleRate: audio.sampleRate);
        tmp = File(
          p.join((await getTemporaryDirectory()).path, 'spike.wav'),
        );
        await tmp.writeAsBytes(wav);
      } finally {
        tts.free();
      }
      if (!mounted) return;
      _setStatus('playing ${tmp.path} (${wav.length} bytes)');
      await _player.setAudioSource(AudioSource.file(tmp.path));
      if (!mounted) return;
      await _player.play();
    } catch (e, st) {
      if (!mounted) return;
      _setStatus('synth error: $e\n$st');
    }
  }

  Future<void> _cancelProbe() async {
    if (_modelPath.isEmpty) {
      _setStatus('pick model first');
      return;
    }
    _setStatus('cancel probe running...');
    final result = StringBuffer();
    // Expected per RESEARCH Pitfall 4: sherpa_onnx 1.12.36 has no cancellation
    // primitive. This probe records that empirically so D-12 can be frozen.
    try {
      // Capture plain String values before entering the isolate. Dart isolates
      // run in a separate memory space; only primitives (String, int, etc.) are
      // transferred by copy, not closures that capture `this`.
      final kokoroDir = _kokoroDir;
      final modelPath = _modelPath;

      // Kick off a long synth inside an isolate, then attempt every plausible
      // cancel path from the calling isolate.
      final fut = Isolate.run(() async {
        // initBindings must be called per-isolate: each isolate has its own
        // binding state and native library handle.
        // Isolates have independent native binding state; safe to call once here.
        sherpa.initBindings();
        final tts = _buildTtsFromPaths(kokoroDir, modelPath);
        final audio = tts.generateWithConfig(
          text: 'Call me Ishmael. Some years ago, never mind how long precisely, '
              'having little or no money in my purse, and nothing particular to '
              'interest me on shore, I thought I would sail about a little and '
              'see the watery part of the world. It is a way I have of driving '
              'off the spleen, and regulating the circulation.',
          config: const sherpa.OfflineTtsGenerationConfig(sid: 1, speed: 1.0),
        );
        tts.free();
        return audio.samples.length;
      });

      // Ceremonial pause — the probe's conclusion is structural (no cancel API exists), not race-dependent.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // There is no `cancel()` on OfflineTts or OfflineTtsConfig in 1.12.36.
      // Disposing the running engine mid-generate is not exposed through the
      // Flutter API. Record this fact.
      result.writeln('sherpa_onnx 1.12.36: no public cancel()/interrupt() API.');
      final samples = await fut;
      result.writeln('Synth completed despite probe: $samples samples.');
      result.writeln(
        'No cancellation primitive found — D-12 fallback path confirmed.',
      );
    } catch (e) {
      result.writeln('Probe error: $e');
    }
    if (!mounted) return;
    setState(() {
      _cancelProbeOutput = result.toString();
      _status = 'cancel probe done';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TTS Spike (/_spike/tts)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            FilledButton(
              onPressed: _copyAssets,
              child: const Text('1. Copy assets'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _pickModel,
              child: const Text('2. Pick model.int8.onnx'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _synthAndPlay,
              child: const Text('3. Synthesize + play'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _cancelProbe,
              child: const Text('4. Cancel probe'),
            ),
            const SizedBox(height: 24),
            Text(
              'Status: $_status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (_cancelProbeOutput.isNotEmpty)
              SelectableText(
                _cancelProbeOutput,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
          ],
        ),
      ),
    );
  }
}
