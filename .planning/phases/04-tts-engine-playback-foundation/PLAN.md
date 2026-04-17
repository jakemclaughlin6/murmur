# Phase 4 Wave 3 — Queue + just_audio player

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the playback engine: pre-synth ring-buffered `TtsQueue` driven by `playbackStateProvider`, playing one WAV per sentence through a `just_audio` wrapper, with worker lifecycle tied to the active `bookId` (D-10) and native resources released on dispose (Pitfall 8).

**Architecture:** Three layers. (1) `AudioPlayerHandle` — abstract DI seam over `just_audio.AudioPlayer` using `AudioSource.file` only (TTS-08: no `StreamAudioSource`, no `ConcatenatingAudioSource`). (2) `TtsQueue` — orchestrator that owns sentence-idx advance, pre-synth of `+1` (D-11), a 3-entry played-sentence ring buffer for instant back-skip, soft-cancel bookkeeping for forward-skip (D-12 + Pitfall 4), and delegates speed to the player alone (TTS-09: sherpa `length_scale` pinned to 1.0). (3) Riverpod providers — `ttsWorkerProvider(bookId)` family (spawn/dispose), `audioPlayerProvider` (app-singleton handle), `ttsQueueProvider` (driver that `ref.listen(playbackStateProvider, ...)` and dispatches). Tests use the Wave 2 `FakeTtsEngine` via `TtsClient.spawn(engineFactory: ...)` + a `FakeAudioPlayerHandle` — no device, no sherpa.

**Tech Stack:** Dart 3.11, `just_audio ^0.10.5`, Riverpod 3 + `riverpod_annotation ^3.0`, `flutter_test`, Wave 2's `TtsClient` / `TtsCache` / `PlaybackStateNotifier`, Wave 2's `FakeTtsEngine` + `SynthDelayed`.

**Requirements covered:** TTS-05 (pre-synth one-ahead), TTS-07 (cache hit path), TTS-08 (file-backed playback), TTS-09 (speed guard), TTS-10 (<300ms first-sentence latency via pre-synth of sentence 0).

**Wave prerequisites (already landed):**
- Wave 0 D-12: sherpa_onnx 1.12.36 has no cancel API → `Cancel` is soft-cancel; client already owns `_pendingDiscard` + on-disk WAV cleanup in `tts_client.dart`.
- Wave 2: sealed `TtsCommand`/`TtsEvent` (`messages.dart`), `TtsClient.spawn({cache, initialVoiceSid, engineFactory?})`, `TtsCache` (`pathFor` / `markRecentlyUsed` / `evictLru` / `enforceSoftCap` / `wipeBook`), `ttsCacheProvider` (sync, throws until overridden) + `ttsCacheAsyncProvider` (async initializer), `PlaybackState { bookId, chapterIdx, sentenceIdx, isPlaying, speed, voiceId }` + `playbackStateProvider` with `setSentence`/`setChapter`/`setBook`/`setPlaying`/`setSpeed`/`setVoice`, `ModelManifest.voiceCatalog` + `defaultVoiceId = 'af_bella'` + `byVoiceId(id)`, `Sentence(text)` from `lib/core/text/sentence.dart`.

**Non-goals (later waves):** Voice picker + playback bar UI (Wave 4), background audio + lock-screen (Wave 5), latency instrumentation + UAT (Wave 6). This wave drives the queue purely through `playbackStateProvider` mutations — UI will ride on top later.

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `lib/features/tts/queue/just_audio_player.dart` | `AudioPlayerHandle` interface + `JustAudioPlayerHandle` prod impl (file-backed, completion-stream exposed) |
| `lib/features/tts/queue/tts_queue.dart` | `TtsQueue` orchestrator: pre-synth, ring buffer, skip semantics, cache enforcement |
| `lib/features/tts/providers/tts_worker_provider.dart` | `ttsWorker(bookId)` family — spawns `TtsClient`, disposes on `ref.onDispose` |
| `lib/features/tts/providers/just_audio_provider.dart` | `audioPlayer` keepAlive provider — app-singleton `AudioPlayerHandle` |
| `lib/features/tts/providers/tts_queue_provider.dart` | `ttsQueue` keepAlive provider — composes worker + cache + player + listens to playback state |
| `test/helpers/fake_audio_player.dart` | `FakeAudioPlayerHandle` — records call log, programmable `simulateCompleted()` |
| `test/features/tts/queue/just_audio_player_test.dart` | Unit tests against `FakeAudioPlayerHandle` (CI) |
| `test/features/tts/queue/tts_queue_test.dart` | In-process `TtsClient` + `FakeTtsEngine` + `FakeAudioPlayerHandle` coverage of all queue behaviors |
| `test/features/tts/providers/tts_worker_provider_test.dart` | Verifies override hook + teardown |
| `test/features/tts/providers/tts_queue_provider_test.dart` | `ProviderContainer` overrides drive playback state, assert queue reacts |
| `test/features/tts/isolate/tts_cache_bootstrap_test.dart` | Locks the `ttsCacheProvider` override contract |

### Modified files

| Path | Change |
|---|---|
| `lib/main.dart` | Resolve `ttsCacheAsyncProvider.future` pre-`runApp`, add `ttsCacheProvider.overrideWithValue(cache)` to the `ProviderScope` overrides (prerequisite from Wave 2) |

---

## Invariants (carry forward from Wave 0/1/2)

- `package:sherpa_onnx` import set: `sherpa_tts_engine.dart` + `spike_page.dart` only. Architecture test `test/architecture/no_direct_network_test.dart` fails the build otherwise.
- `package:http` import: `model_downloader.dart` only.
- Path literal `kokoro-en-v0_19` lives only in `lib/features/tts/model/paths.dart`.
- `bookId` cache keys are `String` (library passes `bookId.toString()` — Drift PK is `int`). TtsQueue takes `String bookId`.
- `sherpa.generate(..., speed: 1.0)` — asserted in `FakeTtsEngine` and `SherpaTtsEngine`. Queue must NEVER send a non-1.0 speed to the worker.
- One WAV per `setFile` (TTS-08). No `ConcatenatingAudioSource`. No `StreamAudioSource`.

---

## Task 1: Bootstrap `ttsCacheProvider` override in `main.dart`

**Files:**
- Modify: `lib/main.dart`
- Create: `test/features/tts/isolate/tts_cache_bootstrap_test.dart`

- [ ] **Step 1: Write the contract test**

```dart
// test/features/tts/isolate/tts_cache_bootstrap_test.dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_cache_provider.dart';

void main() {
  test('ttsCacheProvider throws UnimplementedError before override', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(() => container.read(ttsCacheProvider), throwsUnimplementedError);
  });

  test('overrideWithValue makes ttsCacheProvider return the provided cache', () {
    final dir = Directory.systemTemp.createTempSync('cache_bootstrap');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final cache = TtsCache(cacheRoot: dir);
    final container = ProviderContainer(overrides: [
      ttsCacheProvider.overrideWithValue(cache),
    ]);
    addTearDown(container.dispose);
    expect(container.read(ttsCacheProvider), same(cache));
  });
}
```

- [ ] **Step 2: Run tests — expected PASS (locking Wave 2 contract)**

Run: `just test test/features/tts/isolate/tts_cache_bootstrap_test.dart`
Expected: 2 tests pass.

- [ ] **Step 3: Wire the override into `main.dart`**

Add to imports:

```dart
import 'features/tts/isolate/tts_cache_provider.dart';
```

Before `runApp`, resolve the cache future using a throwaway bootstrap container; then pass the resolved value as an override on the real `ProviderScope`:

```dart
    final bootstrapContainer = ProviderContainer();
    final ttsCache =
        await bootstrapContainer.read(ttsCacheAsyncProvider.future);
    bootstrapContainer.dispose();

    runApp(
      ProviderScope(
        overrides: [
          importPickerCallbackProvider.overrideWithValue(
            (ref) => import_picker.pickAndImportEpubs(ref),
          ),
          ttsCacheProvider.overrideWithValue(ttsCache),
        ],
        child: const MurmurApp(),
      ),
    );
```

- [ ] **Step 4: Verify analyze + full suite**

Run: `just analyze && just test`
Expected: 9 pre-existing analyze issues unchanged; all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/features/tts/isolate/tts_cache_bootstrap_test.dart
git commit -m "phase-04 wave-3 task-1: bootstrap ttsCacheProvider override in main.dart"
```

---

## Task 2: `AudioPlayerHandle` interface + `JustAudioPlayerHandle` prod impl

**Files:**
- Create: `lib/features/tts/queue/just_audio_player.dart`

- [ ] **Step 1: Write the production file**

```dart
// lib/features/tts/queue/just_audio_player.dart
import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// DI seam over a single-source audio player. TTS-08: one WAV per
/// `setFile`; no StreamAudioSource, no ConcatenatingAudioSource.
/// TTS-09: `setSpeed` here is the sole runtime speed knob — sherpa
/// `length_scale` stays at 1.0.
abstract class AudioPlayerHandle {
  Future<void> setFile(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setSpeed(double s);
  Future<void> seek(Duration d);
  Stream<bool> get isPlayingStream;

  /// Emits once each time the currently-loaded source reaches
  /// `ProcessingState.completed`.
  Stream<void> get completedStream;

  Future<void> dispose();
}

/// Production impl over `just_audio.AudioPlayer`. `completedStream`
/// is derived from `playerStateStream` filtered to
/// `processingState == completed`, de-duplicated so a single source
/// only fires one event (just_audio emits `completed` for as long as
/// the player stays in that state).
class JustAudioPlayerHandle implements AudioPlayerHandle {
  JustAudioPlayerHandle([AudioPlayer? inner])
      : _player = inner ?? AudioPlayer() {
    _sub = _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed &&
          !_firedForCurrent) {
        _firedForCurrent = true;
        _completedCtl.add(null);
      }
    });
  }

  final AudioPlayer _player;
  late final StreamSubscription<PlayerState> _sub;
  final _completedCtl = StreamController<void>.broadcast();
  bool _firedForCurrent = true; // no source yet → nothing to complete

  @override
  Future<void> setFile(String path) async {
    _firedForCurrent = false;
    await _player.setAudioSource(AudioSource.file(path));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setSpeed(double s) => _player.setSpeed(s);

  @override
  Future<void> seek(Duration d) => _player.seek(d);

  @override
  Stream<bool> get isPlayingStream => _player.playingStream;

  @override
  Stream<void> get completedStream => _completedCtl.stream;

  @override
  Future<void> dispose() async {
    await _sub.cancel();
    await _completedCtl.close();
    await _player.dispose();
  }
}
```

- [ ] **Step 2: Verify it compiles clean**

Run: `just analyze`
Expected: no new issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/tts/queue/just_audio_player.dart
git commit -m "phase-04 wave-3 task-2: AudioPlayerHandle + JustAudioPlayerHandle (TTS-08)"
```

---

## Task 3: `FakeAudioPlayerHandle` + wrapper unit tests

**Files:**
- Create: `test/helpers/fake_audio_player.dart`
- Create: `test/features/tts/queue/just_audio_player_test.dart`

- [ ] **Step 1: Write the fake**

```dart
// test/helpers/fake_audio_player.dart
import 'dart:async';

import 'package:murmur/features/tts/queue/just_audio_player.dart';

/// Records every call and lets tests trigger completion synchronously.
class FakeAudioPlayerHandle implements AudioPlayerHandle {
  final List<String> calls = [];
  final List<String> setFilePaths = [];
  final List<double> setSpeedValues = [];
  final _completedCtl = StreamController<void>.broadcast();
  final _playingCtl = StreamController<bool>.broadcast();
  bool disposed = false;

  void simulateCompleted() => _completedCtl.add(null);

  @override
  Future<void> setFile(String path) async {
    calls.add('setFile');
    setFilePaths.add(path);
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _playingCtl.add(true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playingCtl.add(false);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _playingCtl.add(false);
  }

  @override
  Future<void> setSpeed(double s) async {
    calls.add('setSpeed');
    setSpeedValues.add(s);
  }

  @override
  Future<void> seek(Duration d) async {
    calls.add('seek');
  }

  @override
  Stream<bool> get isPlayingStream => _playingCtl.stream;

  @override
  Stream<void> get completedStream => _completedCtl.stream;

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    disposed = true;
    await _completedCtl.close();
    await _playingCtl.close();
  }
}
```

- [ ] **Step 2: Write tests for the fake + wrapper contract**

```dart
// test/features/tts/queue/just_audio_player_test.dart
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_audio_player.dart';

void main() {
  test('records setFile path and play call', () async {
    final fake = FakeAudioPlayerHandle();
    await fake.setFile('/tmp/a.wav');
    await fake.play();
    expect(fake.calls, ['setFile', 'play']);
    expect(fake.setFilePaths, ['/tmp/a.wav']);
  });

  test('simulateCompleted drives completedStream', () async {
    final fake = FakeAudioPlayerHandle();
    final events = <void>[];
    final sub = fake.completedStream.listen(events.add);
    fake.simulateCompleted();
    fake.simulateCompleted();
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 2);
    await sub.cancel();
  });

  test('setSpeed records value; dispose sets disposed', () async {
    final fake = FakeAudioPlayerHandle();
    await fake.setSpeed(1.75);
    await fake.dispose();
    expect(fake.setSpeedValues, [1.75]);
    expect(fake.disposed, isTrue);
  });
}
```

Note: real `just_audio.AudioPlayer` device coverage is deferred to Wave 6 device UAT per `04-VALIDATION.md` — Wave 3 CI stays headless via the fake, mirroring Wave 2's in-process `TtsClient` discipline.

- [ ] **Step 3: Run tests**

Run: `just test test/features/tts/queue/just_audio_player_test.dart`
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add test/helpers/fake_audio_player.dart test/features/tts/queue/just_audio_player_test.dart
git commit -m "phase-04 wave-3 task-3: FakeAudioPlayerHandle + wrapper unit tests"
```

---

## Task 4: `TtsQueue` scaffold + `setChapter` pre-synth (D-11)

**Files:**
- Create: `lib/features/tts/queue/tts_queue.dart`
- Create: `test/features/tts/queue/tts_queue_test.dart`

- [ ] **Step 1: Write the failing test for pre-synth of idx 0**

```dart
// test/features/tts/queue/tts_queue_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/text/sentence.dart';
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_client.dart';
import 'package:murmur/features/tts/queue/tts_queue.dart';

import '../../../helpers/fake_audio_player.dart';
import '../../../helpers/fake_tts_engine.dart';

class _Harness {
  _Harness(this.client, this.cache, this.engine, this.tmp);
  final TtsClient client;
  final TtsCache cache;
  final FakeTtsEngine engine;
  final Directory tmp;
}

Future<_Harness> _mkClient({Duration synthDelay = Duration.zero}) async {
  final tmp = Directory.systemTemp.createTempSync('tts_queue_test');
  final cache = TtsCache(cacheRoot: tmp);
  late FakeTtsEngine engine;
  final client = await TtsClient.spawn(
    cache: cache,
    initialVoiceSid: 1,
    engineFactory: () => engine = FakeTtsEngine(synthDelay: synthDelay),
  );
  await client.events.whereType<ModelLoaded>().first;
  return _Harness(client, cache, engine, tmp);
}

void main() {
  test('setChapter kicks off SynthSentence for idx 0 (D-11 pre-synth)',
      () async {
    final h = await _mkClient();
    addTearDown(() async {
      await h.client.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client,
      cache: h.cache,
      player: player,
      onSentenceStart: (_) {},
    );
    queue.setChapter(
      bookId: 'b1',
      chapterIdx: 0,
      sentences: const [Sentence('Hello world.'), Sentence('Second.')],
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.engine.generateCallCount, 1);
  });
}
```

- [ ] **Step 2: Run test — expected FAIL**

Run: `just test test/features/tts/queue/tts_queue_test.dart`
Expected: fails — `TtsQueue` not defined.

- [ ] **Step 3: Implement `TtsQueue` scaffold**

```dart
// lib/features/tts/queue/tts_queue.dart
import 'dart:async';
import 'dart:io';

import 'package:murmur/core/text/sentence.dart';
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_client.dart';
import 'package:murmur/features/tts/model/model_manifest.dart';
import 'package:murmur/features/tts/queue/just_audio_player.dart';

/// Orchestrator: TtsClient + TtsCache + AudioPlayerHandle.
/// Driven by `ttsQueueProvider`; the reader calls `setChapter(...)`
/// on chapter load.
class TtsQueue {
  TtsQueue({
    required this.client,
    required this.cache,
    required this.player,
    required this.onSentenceStart,
  }) {
    _eventSub =
        client.events.whereType<SentenceReady>().listen(_onSentenceReady);
    _completedSub =
        player.completedStream.listen((_) => _onPlayerCompleted());
  }

  final TtsClient client;
  final TtsCache cache;
  final AudioPlayerHandle player;
  final void Function(int sentenceIdx) onSentenceStart;

  String? _bookId;
  int _chapterIdx = 0;
  int _currentIdx = 0;
  int _currentVoiceSid =
      ModelManifest.byVoiceId(ModelManifest.defaultVoiceId)!.sid;
  List<Sentence> _sentences = const [];

  static const int _ringSize = 3;
  final List<int> _recent = [];
  final Map<int, Completer<String>> _awaiting = {};

  StreamSubscription<SentenceReady>? _eventSub;
  StreamSubscription<void>? _completedSub;
  bool _disposed = false;

  void setChapter({
    required String bookId,
    required int chapterIdx,
    required List<Sentence> sentences,
  }) {
    _bookId = bookId;
    _chapterIdx = chapterIdx;
    _sentences = sentences;
    _currentIdx = 0;
    _recent.clear();
    _awaiting.clear();
    if (sentences.isNotEmpty) _requestSynth(0);
  }

  void _requestSynth(int idx) {
    if (_bookId == null) return;
    if (idx < 0 || idx >= _sentences.length) return;
    if (_awaiting.containsKey(idx)) return;
    if (File(cache.pathFor(_bookId!, _chapterIdx, idx)).existsSync()) return;
    _awaiting[idx] = Completer<String>();
    client.send(SynthSentence(
      bookId: _bookId!,
      chapterIdx: _chapterIdx,
      sentenceIdx: idx,
      text: _sentences[idx].text,
      voiceSid: _currentVoiceSid,
    ));
  }

  void _onSentenceReady(SentenceReady e) {
    final c = _awaiting.remove(e.sentenceIdx);
    if (c != null && !c.isCompleted) c.complete(e.wavPath);
    if (_bookId != null) {
      cache.markRecentlyUsed(_bookId!, _chapterIdx, e.sentenceIdx);
      cache.evictLru(_bookId!, _chapterIdx);
      unawaited(cache.enforceSoftCap(_bookId!));
    }
  }

  void _onPlayerCompleted() {
    // Filled in by Task 5.
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _eventSub?.cancel();
    await _completedSub?.cancel();
    try { await player.pause(); } catch (_) {/* benign */}
    await client.dispose();
  }
}
```

- [ ] **Step 4: Run test — expected PASS**

Run: `just test test/features/tts/queue/tts_queue_test.dart`
Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tts/queue/tts_queue.dart test/features/tts/queue/tts_queue_test.dart
git commit -m "phase-04 wave-3 task-4: TtsQueue scaffold + setChapter pre-synth (D-11)"
```

---

## Task 5: `play()` + advance-on-completion + pre-synth `+1`

**Files:**
- Modify: `lib/features/tts/queue/tts_queue.dart`
- Modify: `test/features/tts/queue/tts_queue_test.dart`

- [ ] **Step 1: Add failing tests**

Append inside `main()` in the test file:

```dart
  test('play(0) awaits synth, calls setFile+play, pre-synths idx 1', () async {
    final h = await _mkClient();
    addTearDown(() async {
      await h.client.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    final player = FakeAudioPlayerHandle();
    final started = <int>[];
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: started.add,
    );
    queue.setChapter(bookId: 'b1', chapterIdx: 0, sentences: const [
      Sentence('A.'), Sentence('B.'), Sentence('C.'),
    ]);
    await queue.play(0);
    expect(player.calls.take(2).toList(), ['setFile', 'play']);
    expect(player.setFilePaths.single, endsWith('/0/0.wav'));
    expect(started, [0]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(h.engine.generateCallCount, 2);
  });

  test('player completion advances and pre-synths +2', () async {
    final h = await _mkClient();
    addTearDown(() async {
      await h.client.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    final player = FakeAudioPlayerHandle();
    final started = <int>[];
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: started.add,
    );
    queue.setChapter(bookId: 'b1', chapterIdx: 0, sentences: const [
      Sentence('A.'), Sentence('B.'), Sentence('C.'),
    ]);
    await queue.play(0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    player.simulateCompleted();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(started, [0, 1]);
    expect(player.setFilePaths.last, endsWith('/0/1.wav'));
    expect(h.engine.generateCallCount, 3); // 0, 1, 2
  });
```

- [ ] **Step 2: Implement `play()` + advance**

Add to `TtsQueue` (replacing the stub `_onPlayerCompleted`):

```dart
  Future<void> play(int fromIdx) async {
    if (_bookId == null) return;
    if (fromIdx < 0 || fromIdx >= _sentences.length) return;
    _currentIdx = fromIdx;
    await _playIdx(fromIdx);
    _requestSynth(fromIdx + 1);
  }

  Future<void> _playIdx(int idx) async {
    final path = cache.pathFor(_bookId!, _chapterIdx, idx);
    String wav;
    if (File(path).existsSync()) {
      wav = path;
    } else {
      _requestSynth(idx);
      wav = await _awaiting[idx]!.future;
    }
    await player.setFile(wav);
    await player.play();
    _rememberRecent(idx);
    onSentenceStart(idx);
  }

  void _rememberRecent(int idx) {
    _recent.remove(idx);
    _recent.add(idx);
    while (_recent.length > _ringSize) _recent.removeAt(0);
  }
```

Replace `_onPlayerCompleted`:

```dart
  void _onPlayerCompleted() {
    if (_disposed || _bookId == null) return;
    final next = _currentIdx + 1;
    if (next >= _sentences.length) return;
    _currentIdx = next;
    unawaited(_playIdx(next).then((_) => _requestSynth(next + 1)));
  }
```

- [ ] **Step 3: Run tests**

Run: `just test test/features/tts/queue/tts_queue_test.dart`
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/features/tts/queue/tts_queue.dart test/features/tts/queue/tts_queue_test.dart
git commit -m "phase-04 wave-3 task-5: TtsQueue.play + advance-on-completion + pre-synth"
```

---

## Task 6: `skipForward` / `skipBackward` (ring buffer + soft-cancel)

**Files:**
- Modify: `lib/features/tts/queue/tts_queue.dart`
- Modify: `test/features/tts/queue/tts_queue_test.dart`

- [ ] **Step 1: Add failing tests**

Append:

```dart
  test('skipForward during inflight synth discards result wav', () async {
    final h = await _mkClient(synthDelay: const Duration(milliseconds: 100));
    addTearDown(() async {
      await h.client.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: (_) {});
    queue.setChapter(bookId: 'b1', chapterIdx: 0, sentences: const [
      Sentence('A.'), Sentence('B.'), Sentence('C.'),
    ]);
    final p = queue.play(0);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    queue.skipForward();
    await p.catchError((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(File(h.cache.pathFor('b1', 0, 0)).existsSync(), isFalse,
        reason: 'cancelled synth wav must be deleted');
  });

  test('skipBackward within ring buffer replays without new synth', () async {
    final h = await _mkClient();
    addTearDown(() async {
      await h.client.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: (_) {});
    queue.setChapter(bookId: 'b1', chapterIdx: 0, sentences: const [
      Sentence('A.'), Sentence('B.'), Sentence('C.'), Sentence('D.'),
    ]);
    await queue.play(0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    player.simulateCompleted();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final before = h.engine.generateCallCount;
    await queue.skipBackward();
    expect(h.engine.generateCallCount, before);
    expect(player.setFilePaths.last, endsWith('/0/0.wav'));
  });
```

- [ ] **Step 2: Implement skip methods**

Add to `TtsQueue`:

```dart
  void skipForward() {
    if (_bookId == null) return;
    final inflight = _currentIdx;
    if (_awaiting.containsKey(inflight)) {
      client.send(Cancel(inflight));
      _awaiting.remove(inflight);
    }
    final next = _currentIdx + 1;
    if (next >= _sentences.length) return;
    _currentIdx = next;
    unawaited(_playIdx(next).then((_) => _requestSynth(next + 1)));
  }

  Future<void> skipBackward() async {
    if (_bookId == null) return;
    final prev = _currentIdx - 1;
    if (prev < 0) return;
    _currentIdx = prev;
    await _playIdx(prev);
    _requestSynth(prev + 1);
  }
```

`_playIdx` already re-synths on cache miss, so back-skips past the ring take the synth path automatically.

- [ ] **Step 3: Run tests**

Run: `just test test/features/tts/queue/tts_queue_test.dart`
Expected: 5 tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/features/tts/queue/tts_queue.dart test/features/tts/queue/tts_queue_test.dart
git commit -m "phase-04 wave-3 task-6: TtsQueue skipForward/skipBackward + ring buffer"
```

---

## Task 7: `setVoice` / `setSpeed` / `pause` / `resume`

**Files:**
- Modify: `lib/features/tts/queue/tts_queue.dart`
- Modify: `test/features/tts/queue/tts_queue_test.dart`

- [ ] **Step 1: Add failing tests**

Append:

```dart
  test('setSpeed forwards to player; NEVER reaches worker', () async {
    final h = await _mkClient();
    addTearDown(() async {
      await h.client.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: (_) {});
    queue.setChapter(bookId: 'b1', chapterIdx: 0,
        sentences: const [Sentence('A.')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final before = h.engine.generateCallCount;
    await queue.setSpeed(1.75);
    expect(player.setSpeedValues, [1.75]);
    expect(h.engine.generateCallCount, before,
        reason: 'TTS-09: speed never reaches worker');
  });

  test('setVoice wipes chapter cache, sends SetVoice, resynths currentIdx',
      () async {
    final h = await _mkClient();
    addTearDown(() async {
      await h.client.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: (_) {});
    queue.setChapter(bookId: 'b1', chapterIdx: 0, sentences: const [
      Sentence('A.'), Sentence('B.'),
    ]);
    await queue.play(0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(File(h.cache.pathFor('b1', 0, 0)).existsSync(), isTrue);
    await queue.setVoice('af_sarah');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.engine.lastSid, 3); // af_sarah sid = 3
  });

  test('pause/resume forward to player', () async {
    final h = await _mkClient();
    addTearDown(() async {
      await h.client.dispose();
      if (h.tmp.existsSync()) h.tmp.deleteSync(recursive: true);
    });
    final player = FakeAudioPlayerHandle();
    final queue = TtsQueue(
      client: h.client, cache: h.cache, player: player,
      onSentenceStart: (_) {});
    queue.setChapter(bookId: 'b1', chapterIdx: 0,
        sentences: const [Sentence('A.')]);
    await queue.play(0);
    await queue.pause();
    await queue.resume();
    expect(player.calls, containsAll(['pause', 'play']));
  });
```

- [ ] **Step 2: Implement the methods**

Add to `TtsQueue`:

```dart
  Future<void> setSpeed(double s) async {
    await player.setSpeed(s);
  }

  Future<void> setVoice(String voiceId) async {
    final entry = ModelManifest.byVoiceId(voiceId);
    if (entry == null) return;
    _currentVoiceSid = entry.sid;
    client.send(SetVoice(entry.sid));
    if (_bookId != null) {
      final dir = Directory(
          '${cache.cacheRoot.path}/${_bookId!}/$_chapterIdx');
      if (dir.existsSync()) {
        try { await dir.delete(recursive: true); } catch (_) {/* benign */}
      }
      _awaiting.clear();
      _recent.clear();
      _requestSynth(_currentIdx);
    }
  }

  Future<void> pause() async { await player.pause(); }
  Future<void> resume() async { await player.play(); }
```

- [ ] **Step 3: Run tests**

Run: `just test test/features/tts/queue/tts_queue_test.dart`
Expected: 8 tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/features/tts/queue/tts_queue.dart test/features/tts/queue/tts_queue_test.dart
git commit -m "phase-04 wave-3 task-7: TtsQueue setVoice/setSpeed/pause/resume (TTS-09)"
```

---

## Task 8: `ttsWorkerProvider` family

**Files:**
- Create: `lib/features/tts/providers/tts_worker_provider.dart`
- Create: `test/features/tts/providers/tts_worker_provider_test.dart`

- [ ] **Step 1: Write the provider**

```dart
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
```

- [ ] **Step 2: Run codegen**

Run: `just gen`
Expected: `tts_worker_provider.g.dart` generated; zero errors.

- [ ] **Step 3: Write the override test**

```dart
// test/features/tts/providers/tts_worker_provider_test.dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_cache_provider.dart';
import 'package:murmur/features/tts/isolate/tts_client.dart';
import 'package:murmur/features/tts/providers/tts_worker_provider.dart';

import '../../../helpers/fake_tts_engine.dart';

void main() {
  test('ttsWorker(bookId) honors override → in-process client', () async {
    final tmp = Directory.systemTemp.createTempSync('worker_test');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final cache = TtsCache(cacheRoot: tmp);

    final container = ProviderContainer(overrides: [
      ttsCacheProvider.overrideWithValue(cache),
      ttsWorkerProvider('b1').overrideWith(
        (ref) async => TtsClient.spawn(
          cache: cache,
          initialVoiceSid: 1,
          engineFactory: () => FakeTtsEngine(),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final client = await container.read(ttsWorkerProvider('b1').future);
    await client.events.whereType<ModelLoaded>().first;
    expect(client, isA<TtsClient>());
  });
}
```

- [ ] **Step 4: Run test + analyze**

Run: `just test test/features/tts/providers/tts_worker_provider_test.dart && just analyze`
Expected: 1 test passes; no new analyze issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/tts/providers/tts_worker_provider.dart \
        lib/features/tts/providers/tts_worker_provider.g.dart \
        test/features/tts/providers/tts_worker_provider_test.dart
git commit -m "phase-04 wave-3 task-8: ttsWorkerProvider family (D-10 spawn/dispose)"
```

---

## Task 9: `audioPlayerProvider` + `ttsQueueProvider` driver

**Files:**
- Create: `lib/features/tts/providers/just_audio_provider.dart`
- Create: `lib/features/tts/providers/tts_queue_provider.dart`
- Create: `test/features/tts/providers/tts_queue_provider_test.dart`

- [ ] **Step 1: Write `audioPlayerProvider`**

```dart
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
```

- [ ] **Step 2: Write `ttsQueueProvider`**

```dart
// lib/features/tts/providers/tts_queue_provider.dart
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
  final bookId = ref.watch(
      playbackStateNotifierProvider.select((s) => s.bookId));
  if (bookId == null) return null;

  final cache = ref.watch(ttsCacheProvider);
  final client = await ref.watch(ttsWorkerProvider(bookId).future);
  final player = ref.watch(audioPlayerProvider);
  final queue = TtsQueue(
    client: client,
    cache: cache,
    player: player,
    onSentenceStart: (idx) => ref
        .read(playbackStateNotifierProvider.notifier)
        .setSentence(idx),
  );
  ref.onDispose(() async {
    try { await queue.dispose(); } catch (_) {/* benign */}
  });

  ref.listen<PlaybackState>(playbackStateNotifierProvider, (prev, next) {
    if (next.bookId != bookId) return;
    if (prev?.isPlaying != next.isPlaying) {
      if (next.isPlaying) { queue.resume(); } else { queue.pause(); }
    }
    if (prev?.speed != next.speed) queue.setSpeed(next.speed);
    if (prev?.voiceId != next.voiceId) queue.setVoice(next.voiceId);
  });

  return queue;
}
```

- [ ] **Step 3: Run codegen**

Run: `just gen`
Expected: both `.g.dart` files generated; zero errors.

- [ ] **Step 4: Write the driver test**

```dart
// test/features/tts/providers/tts_queue_provider_test.dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/playback_state.dart';
import 'package:murmur/core/text/sentence.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_cache_provider.dart';
import 'package:murmur/features/tts/isolate/tts_client.dart';
import 'package:murmur/features/tts/providers/just_audio_provider.dart';
import 'package:murmur/features/tts/providers/tts_queue_provider.dart';
import 'package:murmur/features/tts/providers/tts_worker_provider.dart';

import '../../../helpers/fake_audio_player.dart';
import '../../../helpers/fake_tts_engine.dart';

void main() {
  test('returns null when bookId is null', () async {
    final tmp = Directory.systemTemp.createTempSync('q_null');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final container = ProviderContainer(overrides: [
      ttsCacheProvider.overrideWithValue(TtsCache(cacheRoot: tmp)),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(ttsQueueProvider.future), isNull);
  });

  test('speed mutation forwards to player; never to engine', () async {
    final tmp = Directory.systemTemp.createTempSync('q_drive');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final cache = TtsCache(cacheRoot: tmp);
    late FakeTtsEngine engine;
    final fakePlayer = FakeAudioPlayerHandle();

    final container = ProviderContainer(overrides: [
      ttsCacheProvider.overrideWithValue(cache),
      audioPlayerProvider.overrideWithValue(fakePlayer),
      ttsWorkerProvider('b1').overrideWith((ref) async => TtsClient.spawn(
            cache: cache,
            initialVoiceSid: 1,
            engineFactory: () => engine = FakeTtsEngine(),
          )),
    ]);
    addTearDown(container.dispose);

    container.read(playbackStateNotifierProvider.notifier).setBook('b1');
    final queue = await container.read(ttsQueueProvider.future);
    expect(queue, isNotNull);
    queue!.setChapter(
      bookId: 'b1', chapterIdx: 0,
      sentences: const [Sentence('A.')],
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final before = engine.generateCallCount;

    container.read(playbackStateNotifierProvider.notifier).setSpeed(1.5);
    await Future<void>.delayed(Duration.zero);

    expect(fakePlayer.setSpeedValues, [1.5]);
    expect(engine.generateCallCount, before);
  });
}
```

- [ ] **Step 5: Run tests + architecture + analyze; commit**

Run: `just test test/features/tts/providers test/architecture && just analyze`
Expected: all tests pass; architecture boundaries green; no new analyze issues.

```bash
git add lib/features/tts/providers/just_audio_provider.dart \
        lib/features/tts/providers/just_audio_provider.g.dart \
        lib/features/tts/providers/tts_queue_provider.dart \
        lib/features/tts/providers/tts_queue_provider.g.dart \
        test/features/tts/providers/tts_queue_provider_test.dart
git commit -m "phase-04 wave-3 task-9: audioPlayerProvider + ttsQueueProvider driver"
```

---

## Task 10: Full-suite verify + wave sign-off

**Files:**
- Modify: `.planning/phases/04-tts-engine-playback-foundation/WAVES.md`
- Create: `.planning/phases/04-tts-engine-playback-foundation/04-03-SUMMARY.md`

- [ ] **Step 1: Full suite + analyze**

Run: `just test && just analyze`
Expected: all tests pass (~841 total); zero new analyze issues vs the Wave 2 baseline of 9.

- [ ] **Step 2: Grep guards**

Run each; all MUST return empty:

```bash
grep -rn "StreamAudioSource" lib/ test/
grep -rn "ConcatenatingAudioSource" lib/ test/
grep -rn "length_scale" lib/ | grep -v 'sherpa_tts_engine.dart'
```

- [ ] **Step 3: Write `04-03-SUMMARY.md`**

Record: commits landed, protocol/queue state-machine notes, any surprises in just_audio completion semantics, final test footprint, open items for Wave 4 (voice picker + playback bar UI will need `ttsQueueProvider` direct read for `setChapter(...)` wiring from the reader; no changes to the queue interface expected).

- [ ] **Step 4: Flip WAVES.md**

Update the Wave 3 block:

```
## Wave 3 — Queue + just_audio player

**Status:** COMPLETE (<YYYY-MM-DD>)
**Legacy spec:** `04-06-PLAN.md`
**Current plan:** `PLAN.md` (this directory)
**Summary:** `04-03-SUMMARY.md`
```

And flip Wave 4 from `BLOCKED (on Wave 3)` → `BLOCKED (on Wave 4 prep)` or leave as-is pending planning.

- [ ] **Step 5: Commit**

```bash
git add .planning/phases/04-tts-engine-playback-foundation/WAVES.md \
        .planning/phases/04-tts-engine-playback-foundation/04-03-SUMMARY.md
git commit -m "phase-04 wave-3 task-10: full suite verify + wave sign-off"
```

---

## Verification

- `just test` — full suite green (≈841 tests).
- `just analyze` — no new issues vs Wave 2 baseline (9 pre-existing).
- `grep -rn "StreamAudioSource\|ConcatenatingAudioSource" lib/ test/` — zero hits.
- `grep -rn "length_scale" lib/` — only `sherpa_tts_engine.dart`.
- `test/architecture/feature_boundary_test.dart` + `test/architecture/no_direct_network_test.dart` — both green.

## Success criteria

- Queue is driven purely through `playbackStateProvider` mutations for isPlaying/speed/voice; chapter changes flow via the reader calling `queue.setChapter(...)` (Phase 5 wiring).
- Skip-forward during inflight synth deletes the stale WAV via `TtsClient._pendingDiscard`.
- Skip-backward within the last 3 played sentences replays from cache without new synth; outside it, re-synths.
- `setSpeed` never reaches the worker (TTS-09).
- `setVoice` invalidates the current chapter's cache dir so the new voice takes effect immediately.
- `main.dart` resolves the TTS cache before `runApp`, satisfying the Wave 2 open item.
