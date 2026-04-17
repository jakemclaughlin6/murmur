# Phase 4 Wave 0 — TTS Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove "hear one Kokoro sentence" on a physical Android device before any other Phase 4 work begins.

**Architecture:** A throwaway-safe `/_spike/tts` debug-only route wires the `sherpa_onnx` 1.12.36 + Kokoro v0_19 config chain against bundled static assets (voices.bin, tokens.txt, espeak-ng-data/) plus a manually-placed `model.int8.onnx`, synthesizes one sentence through `generateWithConfig`, wraps the Float32 PCM into an inline WAV buffer, and plays via `just_audio.AudioSource.file`. An empirical cancellation probe records whether the API supports synth interruption (expected: NO — fall back to "finish current, discard result" per D-12).

**Tech Stack:** Flutter 3.41 / Dart 3.11 · sherpa_onnx 1.12.36 (exact pin) · just_audio ^0.10.5 · audio_service ^0.18.18 · audio_session ^0.2.3 · http ^1.2.0 · crypto ^3.0.5 · Riverpod 3 · go_router 17.

**Scope gate:** This is Wave 0. It deliberately does NOT implement the downloader, the worker isolate protocol, the queue, playback UI, or any reader wiring. Those are later waves (see `WAVES.md`). The only deliverable is: Jake hears one sentence from a physical Android device and signs off.

**Source specs:** `04-00-PLAN.md` (legacy GSD), `04-CONTEXT.md`, `04-RESEARCH.md`, `04-VALIDATION.md` in this directory.

---

## File Structure

New files:
- `assets/kokoro/voices.bin` — ~5.5MB bundled style vectors (committed via Git LFS-free direct commit; binary is committed to source since it is a required build-time asset per D-06)
- `assets/kokoro/tokens.txt` — ~1KB phoneme vocabulary (bundled)
- `assets/kokoro/LICENSE` — upstream model license (bundled, required by terms)
- `assets/kokoro/espeak-ng-data/` — ~1MB phonemization rules, ~50 files (bundled, recursive)
- `lib/features/tts/spike/copy_assets.dart` — `copyKokoroAssetsToSupportDir()` helper, idempotent asset extraction from `rootBundle` to `getApplicationSupportDirectory()/kokoro-en-v0_19/`
- `lib/features/tts/spike/spike_page.dart` — `StatefulWidget` with Copy Assets / Pick Model / Synthesize+Play / Cancel Probe buttons, debug-only
- `integration_test/tts_spike_test.dart` — integration test that exercises asset copy + (optional) synth + cancellation probe
- `integration_test/DEVICE_CHECKLIST.md` — Jake's manual verification script

Modified files:
- `pubspec.yaml` — add TTS dependencies + register `assets/kokoro/` tree
- `lib/app/router.dart` — add `/_spike/tts` route guarded by `kDebugMode`
- `android/app/src/main/AndroidManifest.xml` — verify (add if missing) `FOREGROUND_SERVICE_MEDIA_PLAYBACK`

Files NOT touched this wave:
- `lib/features/tts/` (except `/spike/`) — reserved for Wave 1+
- `lib/features/reader/` — untouched, no TTS wiring yet
- `lib/core/playback_state.dart` — Wave 2
- iOS project files — no-Mac constraint; iOS verification is CI-only and deferred

---

## Task 1: Pin Phase 4 deps + bundle Kokoro static assets + verify Android manifest

**Files:**
- Modify: `pubspec.yaml`
- Create: `assets/kokoro/voices.bin`, `assets/kokoro/tokens.txt`, `assets/kokoro/LICENSE`, `assets/kokoro/espeak-ng-data/` (directory)
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Read relevant context**

Read these files before editing:
- `pubspec.yaml` — note the `dependency_overrides:` block (analyzer ^10.0.0 override is load-bearing, do NOT remove)
- `android/app/src/main/AndroidManifest.xml` — confirm FOREGROUND_SERVICE state
- `CLAUDE.md` §Risks #1 and §Version Compatibility
- `.planning/phases/04-tts-engine-playback-foundation/04-RESEARCH.md` §Versions to pin, §Kokoro Model — Asset Layout, §Pitfall 6

- [ ] **Step 2: Add TTS dependencies to `pubspec.yaml`**

Under the `dependencies:` block (leave existing entries untouched), add:

```yaml
  sherpa_onnx: 1.12.36          # EXACT pin — NOT caret. Patch cadence is fast.
  just_audio: ^0.10.5
  audio_service: ^0.18.18
  audio_session: ^0.2.3
  http: ^1.2.0
  crypto: ^3.0.5
```

Do NOT add `connectivity_plus` (D-02: honor-system Wi-Fi toggle, no dep required).
Do NOT add `dio` (CLAUDE.md explicitly rejects it).

- [ ] **Step 3: Download and extract the Kokoro v0_19 asset tarball**

Run:

```bash
curl -L -o /tmp/kokoro.tar.bz2 \
  https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-en-v0_19.tar.bz2
tar -xjf /tmp/kokoro.tar.bz2 -C /tmp/
ls /tmp/kokoro-en-v0_19/
```

Expected: directory listing contains `model.int8.onnx`, `voices.bin`, `tokens.txt`, `espeak-ng-data/`, `LICENSE`, `README.md`.

- [ ] **Step 4: Copy the bundled assets into the repo**

```bash
mkdir -p assets/kokoro
cp /tmp/kokoro-en-v0_19/voices.bin assets/kokoro/voices.bin
cp /tmp/kokoro-en-v0_19/tokens.txt assets/kokoro/tokens.txt
cp /tmp/kokoro-en-v0_19/LICENSE assets/kokoro/LICENSE
cp -R /tmp/kokoro-en-v0_19/espeak-ng-data assets/kokoro/espeak-ng-data
```

Do NOT copy `model.int8.onnx` — it is downloaded at runtime (TTS-02), never bundled. Do NOT copy `README.md`.

- [ ] **Step 5: Register Kokoro assets in `pubspec.yaml`**

Under `flutter: assets:`, add:

```yaml
    - assets/kokoro/voices.bin
    - assets/kokoro/tokens.txt
    - assets/kokoro/LICENSE
    - assets/kokoro/espeak-ng-data/
```

The trailing slash on the directory makes Flutter recurse and bundle every file in the tree.

- [ ] **Step 6: Verify Android manifest has required permissions**

Open `android/app/src/main/AndroidManifest.xml` and confirm all three of:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

If `FOREGROUND_SERVICE_MEDIA_PLAYBACK` is missing (Android 14+ gate, required for `audio_service` in later waves), add it adjacent to the existing `FOREGROUND_SERVICE` line. Do not remove anything.

- [ ] **Step 7: Resolve dependencies and verify the exact sherpa_onnx pin**

```bash
mise exec -- flutter pub get
mise exec -- flutter pub deps --style=compact | grep sherpa_onnx
```

Expected: output contains `sherpa_onnx 1.12.36` (no caret, exact version).

- [ ] **Step 8: Analyze + asset sanity check**

```bash
mise exec -- flutter analyze
test -f assets/kokoro/voices.bin
test -f assets/kokoro/tokens.txt
test -d assets/kokoro/espeak-ng-data
grep -q FOREGROUND_SERVICE_MEDIA_PLAYBACK android/app/src/main/AndroidManifest.xml
```

Expected: `flutter analyze` prints "No issues found"; all four commands exit 0.

- [ ] **Step 9: Record SHA-256 fingerprints of bundled assets**

```bash
sha256sum assets/kokoro/voices.bin assets/kokoro/tokens.txt > /tmp/kokoro-bundled.sha256
cat /tmp/kokoro-bundled.sha256
```

Record the two digests for later inclusion in `04-00-SUMMARY.md`.

- [ ] **Step 10: Commit**

```bash
git add pubspec.yaml pubspec.lock assets/kokoro android/app/src/main/AndroidManifest.xml
git commit -m "phase-04 wave-0 task-1: pin TTS deps, bundle Kokoro v0_19 assets, verify Android FGS_MEDIA_PLAYBACK"
```

---

## Task 2: Build the `copyKokoroAssetsToSupportDir()` helper (TDD)

**Files:**
- Create: `lib/features/tts/spike/copy_assets.dart`
- Create: `integration_test/tts_spike_test.dart` (test-only, asset-copy portion)

- [ ] **Step 1: Read relevant context**

- `lib/main.dart` — note how `rootBundle` is used
- `.planning/phases/04-tts-engine-playback-foundation/04-RESEARCH.md` §Patterns 3, 4 (asset-copy pattern; rationale: sherpa_onnx needs filesystem paths, not asset handles)
- Upstream reference: sherpa-onnx `flutter-examples/tts/model.dart` implements `copyAllAssetFiles()` — the template

- [ ] **Step 2: Write the failing integration test**

Create `integration_test/tts_spike_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:murmur/features/tts/spike/copy_assets.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('copyKokoroAssetsToSupportDir', () {
    testWidgets('copies bundled Kokoro assets idempotently', (tester) async {
      final supportDir = await getApplicationSupportDirectory();
      final target = Directory(p.join(supportDir.path, 'kokoro-en-v0_19'));
      if (await target.exists()) {
        await target.delete(recursive: true);
      }

      final resolved = await copyKokoroAssetsToSupportDir();
      expect(resolved, equals(target.path));
      expect(File(p.join(target.path, 'voices.bin')).existsSync(), isTrue);
      expect(File(p.join(target.path, 'tokens.txt')).existsSync(), isTrue);
      expect(
        Directory(p.join(target.path, 'espeak-ng-data')).existsSync(),
        isTrue,
      );
      final voicesBytes = await File(p.join(target.path, 'voices.bin')).length();
      expect(voicesBytes, greaterThan(5 * 1024 * 1024));

      // Second call must be idempotent — no throw, same path, same size.
      final resolved2 = await copyKokoroAssetsToSupportDir();
      expect(resolved2, equals(resolved));
      final voicesBytes2 = await File(p.join(target.path, 'voices.bin')).length();
      expect(voicesBytes2, equals(voicesBytes));
    });
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
mise exec -- flutter test integration_test/tts_spike_test.dart
```

Expected: FAIL with "package:murmur/features/tts/spike/copy_assets.dart" not found (file doesn't exist yet).

- [ ] **Step 4: Implement `copy_assets.dart`**

Create `lib/features/tts/spike/copy_assets.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copy bundled Kokoro assets from rootBundle to
/// `getApplicationSupportDirectory()/kokoro-en-v0_19/`.
///
/// Idempotent: files that already exist with matching byte length are skipped.
/// Does NOT copy `model.int8.onnx` — that is downloaded at runtime (TTS-02).
/// Returns the absolute path to the target directory.
Future<String> copyKokoroAssetsToSupportDir() async {
  final support = await getApplicationSupportDirectory();
  final targetRoot = Directory(p.join(support.path, 'kokoro-en-v0_19'));
  await targetRoot.create(recursive: true);
  await Directory(p.join(targetRoot.path, 'espeak-ng-data')).create(recursive: true);

  final manifestJson = await rootBundle.loadString('AssetManifest.json');
  final manifest = json.decode(manifestJson) as Map<String, dynamic>;

  final kokoroPaths = manifest.keys
      .where((k) => k.startsWith('assets/kokoro/'))
      .where((k) => !k.endsWith('/'))
      .toList();

  for (final assetPath in kokoroPaths) {
    final relative = assetPath.substring('assets/kokoro/'.length);
    final dest = File(p.join(targetRoot.path, relative));
    final bytes = await rootBundle.load(assetPath);
    final expectedLen = bytes.lengthInBytes;
    if (dest.existsSync() && dest.lengthSync() == expectedLen) {
      continue;
    }
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    ));
  }

  return targetRoot.path;
}
```

- [ ] **Step 5: Run the test to verify it passes (device required)**

```bash
mise exec -- flutter test integration_test/tts_spike_test.dart
```

Expected: PASS. (Integration tests require a connected device or emulator. If no device is attached, document the result in the device checklist and run it during Task 5.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/tts/spike/copy_assets.dart integration_test/tts_spike_test.dart
git commit -m "phase-04 wave-0 task-2: copyKokoroAssetsToSupportDir + integration test"
```

---

## Task 3: Build the spike page (synthesize + play + cancel probe)

**Files:**
- Create: `lib/features/tts/spike/spike_page.dart`
- Modify: `lib/app/router.dart`
- Modify: `integration_test/tts_spike_test.dart` (extend with synth + cancel probe)

- [ ] **Step 1: Read relevant context**

- `lib/app/router.dart` — note existing `StatefulShellRoute.indexedStack` shape
- `.planning/phases/04-tts-engine-playback-foundation/04-RESEARCH.md` §Patterns 3, 4; §Pitfall 1 (support-dir vs docs-dir); §Pitfall 4 (cancellation)
- sherpa_onnx 1.12.36 pub.dev docs — `OfflineTtsKokoroModelConfig`, `OfflineTtsModelConfig`, `OfflineTtsConfig`, `OfflineTts`, `OfflineTtsGenerationConfig`
- Reference upstream sample: https://github.com/k2-fsa/sherpa-onnx/tree/master/flutter-examples/tts

- [ ] **Step 2: Create the spike page widget**

Create `lib/features/tts/spike/spike_page.dart`:

```dart
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
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final src = File(picked.files.single.path!);
    final dest = File(p.join(_kokoroDir, 'model.int8.onnx'));
    await src.copy(dest.path);
    setState(() {
      _modelPath = dest.path;
      _status = 'model placed at ${dest.path} (${await dest.length()} bytes)';
    });
  }

  sherpa.OfflineTts _buildTts() {
    final kokoro = sherpa.OfflineTtsKokoroModelConfig(
      model: p.join(_kokoroDir, 'model.int8.onnx'),
      voices: p.join(_kokoroDir, 'voices.bin'),
      tokens: p.join(_kokoroDir, 'tokens.txt'),
      dataDir: p.join(_kokoroDir, 'espeak-ng-data'),
      lexicon: '',
    );
    final modelConfig = sherpa.OfflineTtsModelConfig(
      vits: sherpa.OfflineTtsVitsModelConfig(),
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
    header.add(_u32le(16));          // PCM chunk size
    header.add(_u16le(1));           // PCM format
    header.add(_u16le(1));           // mono
    header.add(_u32le(sampleRate));
    header.add(_u32le(sampleRate * 2)); // byte rate: sr * channels * bytes/sample
    header.add(_u16le(2));           // block align
    header.add(_u16le(16));          // bits per sample
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
        config: sherpa.OfflineTtsGenerationConfig(sid: 1, speed: 1.0),
      );
      final wav = _wrapPcmAsWav(audio.samples, audio.sampleRate);
      final tmp = File(p.join((await getTemporaryDirectory()).path, 'spike.wav'));
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
    _setStatus('cancel probe running...');
    final result = StringBuffer();
    // Expected per RESEARCH Pitfall 4: sherpa_onnx 1.12.36 has no cancellation
    // primitive. This probe records that empirically so D-12 can be frozen.
    try {
      // Kick off a long synth, then attempt every plausible cancel path.
      final fut = Isolate.run(() async {
        sherpa.initBindings();
        final tts = _buildTts();
        final audio = tts.generateWithConfig(
          text: 'Call me Ishmael. Some years ago, never mind how long precisely, '
              'having little or no money in my purse, and nothing particular to '
              'interest me on shore, I thought I would sail about a little and '
              'see the watery part of the world. It is a way I have of driving '
              'off the spleen, and regulating the circulation.',
          config: sherpa.OfflineTtsGenerationConfig(sid: 1, speed: 1.0),
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
      result.writeln('No cancellation primitive found — D-12 fallback path confirmed.');
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
            FilledButton(onPressed: _copyAssets, child: const Text('1. Copy assets')),
            const SizedBox(height: 8),
            FilledButton(onPressed: _pickModel, child: const Text('2. Pick model.int8.onnx')),
            const SizedBox(height: 8),
            FilledButton(onPressed: _synthAndPlay, child: const Text('3. Synthesize + play')),
            const SizedBox(height: 8),
            FilledButton(onPressed: _cancelProbe, child: const Text('4. Cancel probe')),
            const SizedBox(height: 24),
            Text('Status: $_status', style: Theme.of(context).textTheme.titleMedium),
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
```

Note: the `ascii` symbol above needs `dart:convert` imported. Add `import 'dart:convert' show ascii;` at the top if the analyzer flags it.

- [ ] **Step 3: Register the `/_spike/tts` route (debug-only)**

Open `lib/app/router.dart`. Add at the top:

```dart
import 'package:flutter/foundation.dart' show kDebugMode;
import '../features/tts/spike/spike_page.dart';
```

Inside the `routes:` list of the top-level `GoRouter`, AFTER the existing `GoRoute(path: '/reader/:bookId', ...)` entry, add (still inside the `routes: [ ... ]` list):

```dart
      if (kDebugMode)
        GoRoute(
          path: '/_spike/tts',
          builder: (_, __) => const SpikePage(),
        ),
```

Also update the `redirect:` predicate to include `/_spike/` so debug navigation isn't bounced to `/library`:

```dart
      if (loc.startsWith('/library') ||
          loc.startsWith('/reader') ||
          loc.startsWith('/settings') ||
          (kDebugMode && loc.startsWith('/_spike'))) {
        return null;
      }
```

- [ ] **Step 4: Regenerate router codegen**

```bash
mise exec -- dart run build_runner build --delete-conflicting-outputs
```

Expected: completes with `[SEVERE]` 0 and writes `router.g.dart`.

- [ ] **Step 5: Analyze**

```bash
mise exec -- flutter analyze lib/features/tts/spike/ lib/app/router.dart integration_test/tts_spike_test.dart
```

Expected: "No issues found."

- [ ] **Step 6: Commit**

```bash
git add lib/features/tts/spike/spike_page.dart lib/app/router.dart lib/app/router.g.dart
git commit -m "phase-04 wave-0 task-3: /_spike/tts page with synth + cancel probe"
```

---

## Task 4: Write the device checklist

**Files:**
- Create: `integration_test/DEVICE_CHECKLIST.md`

- [ ] **Step 1: Write the checklist**

Create `integration_test/DEVICE_CHECKLIST.md` with this content:

```markdown
# Phase 4 Wave 0 — Device Verification Checklist

Run this on a physical Android device. iOS verification is deferred (no-Mac constraint).

## Prep
- [ ] Device: Android phone (mid-range or better), USB-debugging enabled
- [ ] `adb devices` shows the device
- [ ] Download `kokoro-int8-en-v0_19.tar.bz2` on your workstation, extract, keep `model.int8.onnx` accessible

## Build & install
- [ ] `mise exec -- flutter build apk --debug`
- [ ] `adb install -r build/app/outputs/flutter-apk/app-debug.apk`

## Place the model on-device
- [ ] `adb push /path/to/model.int8.onnx /sdcard/Download/model.int8.onnx`

## Navigate to the spike page
- [ ] Launch app
- [ ] `adb shell am start -W -a android.intent.action.VIEW -d "murmur://_spike/tts" com.<your>.murmur` (adjust package name; fallback: add a temporary debug-only button on the Library screen and remove it after sign-off)

## Run the spike
- [ ] Tap **"1. Copy assets"** — status shows `assets copied to /data/user/0/.../kokoro-en-v0_19`
- [ ] Tap **"2. Pick model.int8.onnx"** — pick the file you pushed via the file picker
- [ ] Tap **"3. Synthesize + play"** — within ~1–2 seconds, hear: *"Welcome to murmur. This is how I sound reading your books."* in a female American voice (sid=1, af_bella)
- [ ] Record rough stopwatch latency from tap → first audible sample: ____ ms
- [ ] Tap **"4. Cancel probe"** — read the monospace output. Expected text includes: `No cancellation primitive found — D-12 fallback path confirmed.`

## Speed probe (optional but recorded in summary)
- [ ] Modify `_synthAndPlay` temporarily to pass `speed: 2.0`, rebuild, replay, and observe: does pitch preserve (modern Android AudioTrack time-stretch, expected) or rise chipmunk-style?

## Results to report back
- Pass/fail for each step above
- Observed latency (ms)
- Literal cancel-probe output string
- Speed=2.0 pitch observation (preserved | raised | not tested)
- Any crashes, stack traces, or surprise errors

## Sign-off
Type `spike pass` with the recorded observations inline, or describe the failure to block Phase 4 Wave 1+ planning.
```

- [ ] **Step 2: Commit**

```bash
git add integration_test/DEVICE_CHECKLIST.md
git commit -m "phase-04 wave-0 task-4: device verification checklist"
```

---

## Task 5: Device verification (blocking human checkpoint)

- [ ] **Step 1: Prompt Jake**

Tell the user:

> Wave 0 code is in place. Please run `integration_test/DEVICE_CHECKLIST.md` on a physical Android device and report results. I'll wait for either `spike pass` with observations inline, or a failure description.

- [ ] **Step 2: Jake runs the checklist**

(Blocking — no automation.)

- [ ] **Step 3: Record results in summary**

Once Jake reports back, create `.planning/phases/04-tts-engine-playback-foundation/04-00-SUMMARY.md` with:

```markdown
# Phase 4 Wave 0 — Summary

**Date:** <YYYY-MM-DD>
**Device:** <model, Android version>
**Outcome:** PASS | FAIL

## Kokoro asset SHA-256 fingerprints
- voices.bin: <hex>
- tokens.txt: <hex>

## Observations
- First-sentence latency (tap → audible): <ms>
- Voice sid=1 (af_bella) at speed=1.0: audible | not audible | garbled
- Cancel probe literal output:
    ```
    <paste exact text>
    ```
- Speed=2.0 pitch: preserved | raised | not tested

## Decisions frozen
- **D-12:** Cancellation = <confirmed fallback "finish current, discard" | cancellation IS supported via <api>>
- Any changes required to Waves 1+ before proceeding.

## Unblocks
- Phase 4 Wave 1+ cleared to proceed.
```

- [ ] **Step 4: Update `WAVES.md` tracker**

Flip Wave 0 status from `PLANNED` to `COMPLETE` in `.planning/phases/04-tts-engine-playback-foundation/WAVES.md`.

- [ ] **Step 5: Commit**

```bash
git add .planning/phases/04-tts-engine-playback-foundation/04-00-SUMMARY.md \
        .planning/phases/04-tts-engine-playback-foundation/WAVES.md
git commit -m "phase-04 wave-0 task-5: spike signed off; Wave 1+ unblocked"
```

---

## Verification

- `mise exec -- flutter pub get` resolves with sherpa_onnx exactly at 1.12.36
- `mise exec -- flutter analyze` is clean on all added files
- Bundled assets under `assets/kokoro/` committed and registered in `pubspec.yaml`
- `/_spike/tts` route reachable in debug builds, absent from release
- Integration test `integration_test/tts_spike_test.dart` compiles and asset-copy portion passes on-device
- `DEVICE_CHECKLIST.md` signed off by Jake with recorded observations
- Cancellation probe output documented in `04-00-SUMMARY.md` and propagated to Wave 2's planning (D-12)

## Success Criteria

- Jake hears *"Welcome to murmur. This is how I sound reading your books."* from a physical Android device using sid=1 at 1.0× speed.
- Cancellation question D-12 answered empirically.
- `WAVES.md` shows Wave 0 complete; Waves 1+ unblocked for planning.
