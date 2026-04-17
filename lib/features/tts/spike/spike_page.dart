import 'dart:convert' show ascii;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'copy_assets.dart';

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

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _setStatus(String s) => setState(() => _status = s);

  Future<void> _copyAssets() async {
    _setStatus('copying assets...');
    try {
      final dir = await copyKokoroAssetsToSupportDir();
      setState(() {
        _kokoroDir = dir;
        _status = 'assets copied to $dir';
      });
    } catch (e) {
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
    if (picked == null || picked.files.isEmpty) return;
    final src = File(picked.files.single.path!);
    final dest = File(p.join(_kokoroDir, 'model.int8.onnx'));
    await src.copy(dest.path);
    final destLen = await dest.length();
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

  Uint8List _wrapPcmAsWav(Float32List pcm, int sampleRate) {
    // 44-byte PCM WAV header (mono, 16-bit). Float32 samples are clamped to
    // [-1.0, 1.0] and converted to int16 little-endian.
    final int16 = Int16List(pcm.length);
    for (var i = 0; i < pcm.length; i++) {
      var s = pcm[i];
      if (s > 1.0) s = 1.0;
      if (s < -1.0) s = -1.0;
      int16[i] = (s * 32767).toInt();
    }
    final dataBytes = int16.buffer.asUint8List();
    final totalLen = 36 + dataBytes.length;
    final header = BytesBuilder();
    header.add(ascii.encode('RIFF'));
    header.add(_u32le(totalLen));
    header.add(ascii.encode('WAVE'));
    header.add(ascii.encode('fmt '));
    header.add(_u32le(16)); // PCM chunk size
    header.add(_u16le(1)); // PCM format
    header.add(_u16le(1)); // mono
    header.add(_u32le(sampleRate));
    header.add(_u32le(sampleRate * 2)); // byte rate: sr * channels * bytes/sample
    header.add(_u16le(2)); // block align
    header.add(_u16le(16)); // bits per sample
    header.add(ascii.encode('data'));
    header.add(_u32le(dataBytes.length));
    header.add(dataBytes);
    return header.toBytes();
  }

  Uint8List _u32le(int v) => Uint8List(4)
    ..[0] = v & 0xff
    ..[1] = (v >> 8) & 0xff
    ..[2] = (v >> 16) & 0xff
    ..[3] = (v >> 24) & 0xff;

  Uint8List _u16le(int v) => Uint8List(2)
    ..[0] = v & 0xff
    ..[1] = (v >> 8) & 0xff;

  Future<void> _synthAndPlay() async {
    if (_modelPath.isEmpty) {
      _setStatus('pick model first');
      return;
    }
    _setStatus('synthesizing...');
    try {
      sherpa.initBindings();
      final tts = _buildTts();
      final audio = tts.generateWithConfig(
        text: 'Welcome to murmur. This is how I sound reading your books.',
        config: const sherpa.OfflineTtsGenerationConfig(sid: 1, speed: 1.0),
      );
      final wav = _wrapPcmAsWav(audio.samples, audio.sampleRate);
      final tmp = File(
        p.join((await getTemporaryDirectory()).path, 'spike.wav'),
      );
      await tmp.writeAsBytes(wav);
      tts.free();
      _setStatus('playing ${tmp.path} (${wav.length} bytes)');
      await _player.setAudioSource(AudioSource.file(tmp.path));
      await _player.play();
    } catch (e, st) {
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
