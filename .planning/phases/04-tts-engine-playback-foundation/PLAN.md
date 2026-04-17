# Phase 4 Wave 2 — Isolate Protocol + PlaybackState Seam

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the long-lived TTS worker isolate (D-10, D-13) with a sealed-class command/event protocol, an LRU sentence WAV cache (CD-02), and the `playbackStateProvider` coordination seam (CD-04) — all behind grep-enforced architectural boundaries (PBK-08).

**Architecture:** One protocol file (sealed commands + events + `TtsEngine` interface) consumed by both an in-process test path (FakeTtsEngine) and a real isolate path (SherpaTtsEngine). Client owns cancel-discards-result bookkeeping (D-12 soft cancel). Cache is a pure-Dart utility keyed on `(bookId, chapterIdx, sentenceIdx)` routed through `KokoroPaths`-style discipline. PlaybackState is a plain immutable + `@Riverpod(keepAlive:true)` Notifier in `lib/core/` — no feature imports cross the reader↔tts boundary.

**Tech Stack:** Dart 3.11 `sealed class`, Flutter `Isolate.spawn` + `BackgroundIsolateBinaryMessenger`, `sherpa_onnx 1.12.36` (isolated to one file), `riverpod_annotation ^3.0`, `path ^1.9`, `flutter_test`.

**Requirements covered:** TTS-05, TTS-07 (cache), TTS-09 (speed guard), PBK-08.

**Wave prerequisites (already landed):**
- Wave 0 D-12 resolved: sherpa_onnx 1.12.36 has **no cancel API** → `Cancel` is soft-cancel (discard the next emitted `SentenceReady`).
- Wave 1: `KokoroPaths` (single `kokoro-en-v0_19` path source), `ModelManifest` (11-voice catalog + `defaultVoiceId = 'af_bella'`), `wavWrap(Float32List, {sampleRate=24000})` (CD-03), `copyBundledKokoroAssets`, `books.voice_id` + `books.playback_speed` columns (CD-01).

**Non-goals (later waves):** `just_audio` playback queue (Wave 3), speed/skip UI (Wave 3/4), `audio_service` + lock-screen (Wave 5), latency instrumentation (Wave 6).

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `lib/features/tts/isolate/messages.dart` | Sealed `TtsCommand` / `TtsEvent` hierarchies + `TtsEngine` interface + `SynthResult` + `TtsEngineFactory` typedef |
| `lib/features/tts/isolate/tts_client.dart` | UI-side handle. Two execution modes (in-process for tests, isolate for prod). Owns cancel-discards-result bookkeeping |
| `lib/features/tts/isolate/tts_worker_main.dart` | Top-level static isolate entry (`ttsWorkerMain`). Initializes `BackgroundIsolateBinaryMessenger`, hosts the shared message loop used by both modes |
| `lib/features/tts/isolate/sherpa_tts_engine.dart` | The **only** file in `lib/` that imports `package:sherpa_onnx`. Implements `TtsEngine` against `OfflineTts.generateWithConfig` |
| `lib/features/tts/isolate/tts_cache.dart` | LRU ring (5 live entries per chapter) + 20MB soft cap per book + `wipeBook` + path-traversal rejection |
| `lib/features/tts/isolate/tts_cache_provider.dart` (+ `.g.dart`) | Riverpod `ttsCacheProvider` (override-required) + `ttsCacheAsyncProvider` for startup bootstrap |
| `lib/core/playback_state.dart` (+ `.g.dart`) | `PlaybackState` immutable + `@Riverpod(keepAlive:true) class PlaybackStateNotifier` |
| `test/helpers/fake_tts_engine.dart` | Deterministic in-process `TtsEngine` for unit tests |
| `test/features/tts/isolate/tts_client_test.dart` | Protocol + lifecycle + cancel-discards tests via in-process mode |
| `test/features/tts/isolate/tts_cache_test.dart` | LRU, soft-cap, wipeBook, path-traversal tests |
| `test/features/library/delete_book_wipes_cache_test.dart` | Integration: `LibraryNotifier.deleteBook` calls `TtsCache.wipeBook` |
| `test/core/playback_state_test.dart` | Record equality, copyWith sentinel, notifier mutations |
| `test/architecture/feature_boundary_test.dart` | Grep: reader↔tts isolation + core-is-standalone |
| `test/architecture/no_direct_network_test.dart` | Grep: only model_downloader imports `package:http`; only sherpa_tts_engine + spike_page import `package:sherpa_onnx`; no analytics SDKs |

### Modified files

| Path | Change |
|---|---|
| `lib/features/library/library_provider.dart` | `deleteBook` also calls `ttsCacheProvider.wipeBook(bookId.toString())` |
| `lib/features/tts/spike/spike_page.dart` | Replace inlined `_wrapPcmAsWav` with `wavWrap` from `lib/features/tts/audio/wav_wrap.dart` |

---

## Task 1: Sealed message protocol + TtsEngine interface

**Files:**
- Create: `lib/features/tts/isolate/messages.dart`

Pure-Dart; no Flutter / sherpa_onnx imports. Establishes the message surface every other file consumes.

- [ ] **Step 1: Write the file**

```dart
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
```

- [ ] **Step 2: Analyze**

Run: `just analyze`
Expected: no new warnings/errors beyond the 9 pre-existing Wave 1 issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/tts/isolate/messages.dart
git commit -m "phase-04 wave-2 task-1: sealed TtsCommand/TtsEvent + TtsEngine interface"
```

---

## Task 2: FakeTtsEngine test double

**Files:**
- Create: `test/helpers/fake_tts_engine.dart`

Deterministic in-process fake. Never touches sherpa. Implements a public `SynthDelayed` marker declared in `tts_worker_main.dart` (Task 5) so the shared message loop can honor a programmable delay without production code importing anything test-flavored.

This file is written now but will be edited in Task 5 once `SynthDelayed` exists. For now, we keep the class body self-contained with a local duck-typed interface that Task 5 will upgrade.

- [ ] **Step 1: Write the fake**

```dart
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
```

- [ ] **Step 2: Analyze**

Run: `just analyze`
Expected: no new issues.

- [ ] **Step 3: Commit**

```bash
git add test/helpers/fake_tts_engine.dart
git commit -m "phase-04 wave-2 task-2: FakeTtsEngine deterministic test double"
```

---

## Task 3: TtsCache — write failing tests first

**Files:**
- Create: `test/features/tts/isolate/tts_cache_test.dart`

- [ ] **Step 1: Write the tests**

```dart
// test/features/tts/isolate/tts_cache_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';

void main() {
  late Directory tempRoot;
  late TtsCache cache;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('tts_cache_test_');
    cache = TtsCache(cacheRoot: tempRoot);
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  test('pathFor creates parent dirs and returns expected structure', () {
    final path = cache.pathFor('bookA', 3, 7);
    expect(path, endsWith('bookA/3/7.wav'));
    expect(Directory('${tempRoot.path}/bookA/3').existsSync(), isTrue);
  });

  test('pathFor rejects bookId with traversal or separators', () {
    expect(() => cache.pathFor('..', 0, 0), throwsArgumentError);
    expect(() => cache.pathFor('a/b', 0, 0), throwsArgumentError);
    expect(() => cache.pathFor('../evil', 0, 0), throwsArgumentError);
    expect(() => cache.pathFor(r'a\b', 0, 0), throwsArgumentError);
    expect(() => cache.pathFor('', 0, 0), throwsArgumentError);
    expect(() => cache.pathFor('.', 0, 0), throwsArgumentError);
  });

  test('LRU keeps 5 most-recent per chapter, deletes the rest', () async {
    for (var i = 0; i < 7; i++) {
      final p = cache.pathFor('bookA', 0, i);
      await File(p).writeAsBytes(List.filled(1024, i & 0xff));
      cache.markRecentlyUsed('bookA', 0, i);
    }
    cache.evictLru('bookA', 0);

    final surviving = Directory('${tempRoot.path}/bookA/0')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(surviving, {'2.wav', '3.wav', '4.wav', '5.wav', '6.wav'});
  });

  test('soft cap evicts oldest mtime until under 20MB', () async {
    const mb = 1024 * 1024;
    for (var i = 0; i < 25; i++) {
      final p = cache.pathFor('bookA', 0, i);
      await File(p).writeAsBytes(List.filled(mb, 0));
      await File(p).setLastModified(
        DateTime.fromMillisecondsSinceEpoch(1700000000000 + i * 1000),
      );
    }
    await cache.enforceSoftCap('bookA');
    final total = await cache.totalBytesFor('bookA');
    expect(total, lessThanOrEqualTo(20 * mb));
    expect(File(cache.pathFor('bookA', 0, 0)).existsSync(), isFalse);
    expect(File(cache.pathFor('bookA', 0, 24)).existsSync(), isTrue);
  });

  test('wipeBook deletes bookId subtree only', () async {
    await File(cache.pathFor('bookA', 0, 0))
        .writeAsBytes(List.filled(1024, 0));
    await File(cache.pathFor('bookB', 0, 0))
        .writeAsBytes(List.filled(1024, 0));

    await cache.wipeBook('bookA');

    expect(Directory('${tempRoot.path}/bookA').existsSync(), isFalse);
    expect(File(cache.pathFor('bookB', 0, 0)).existsSync(), isTrue);
  });

  test('wipeBook rejects traversal input', () async {
    expect(() => cache.wipeBook('..'), throwsArgumentError);
    expect(() => cache.wipeBook('a/b'), throwsArgumentError);
    expect(() => cache.wipeBook(''), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Run — expect compile failure**

Run: `just test test/features/tts/isolate/tts_cache_test.dart`
Expected: FAIL — `tts_cache.dart` does not exist.

---

## Task 4: Implement TtsCache

**Files:**
- Create: `lib/features/tts/isolate/tts_cache.dart`

- [ ] **Step 1: Write the cache**

```dart
// lib/features/tts/isolate/tts_cache.dart
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Synthesized-sentence WAV cache (CD-02).
///
/// Layout: `{cacheRoot}/{bookId}/{chapterIdx}/{sentenceIdx}.wav`.
///
/// - LRU ring per (bookId, chapterIdx): keep last 3 played + up to 2
///   pre-synth = 5 live entries; evict the rest.
/// - Soft cap: 20MB per book. Transient overage during pre-synth is
///   fine; enforcement runs after each SentenceReady.
/// - `wipeBook` is called from the Phase 2 delete flow.
class TtsCache {
  TtsCache({required this.cacheRoot});

  final Directory cacheRoot;
  static const int softCapBytes = 20 * 1024 * 1024;
  static const int liveEntriesPerChapter = 5;

  final Map<String, LinkedHashMap<int, DateTime>> _lru = {};

  static void _requireSafeBookId(String bookId) {
    if (bookId.isEmpty ||
        bookId == '.' ||
        bookId == '..' ||
        bookId.contains('/') ||
        bookId.contains(r'\') ||
        bookId.contains('\x00')) {
      throw ArgumentError.value(
        bookId,
        'bookId',
        'must not contain path separators or traversal segments',
      );
    }
  }

  String pathFor(String bookId, int chapterIdx, int sentenceIdx) {
    _requireSafeBookId(bookId);
    if (chapterIdx < 0 || sentenceIdx < 0) {
      throw ArgumentError('chapterIdx and sentenceIdx must be >= 0');
    }
    final dir = Directory(p.join(cacheRoot.path, bookId, '$chapterIdx'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return p.join(dir.path, '$sentenceIdx.wav');
  }

  void markRecentlyUsed(String bookId, int chapterIdx, int sentenceIdx) {
    _requireSafeBookId(bookId);
    final key = '$bookId:$chapterIdx';
    final map = _lru.putIfAbsent(key, () => LinkedHashMap<int, DateTime>());
    map.remove(sentenceIdx);
    map[sentenceIdx] = DateTime.now();
  }

  void evictLru(String bookId, int chapterIdx) {
    _requireSafeBookId(bookId);
    final key = '$bookId:$chapterIdx';
    final map = _lru[key];
    if (map == null) return;
    while (map.length > liveEntriesPerChapter) {
      final oldestIdx = map.keys.first;
      map.remove(oldestIdx);
      final f = File(p.join(
        cacheRoot.path,
        bookId,
        '$chapterIdx',
        '$oldestIdx.wav',
      ));
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {/* benign */}
      }
    }
  }

  Future<int> totalBytesFor(String bookId) async {
    _requireSafeBookId(bookId);
    final bookDir = Directory(p.join(cacheRoot.path, bookId));
    if (!bookDir.existsSync()) return 0;
    var total = 0;
    await for (final e in bookDir.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<void> enforceSoftCap(String bookId) async {
    _requireSafeBookId(bookId);
    final bookDir = Directory(p.join(cacheRoot.path, bookId));
    if (!bookDir.existsSync()) return;
    final files = <File>[];
    await for (final e in bookDir.list(recursive: true, followLinks: false)) {
      if (e is File) files.add(e);
    }
    files.sort((a, b) =>
        a.statSync().modified.compareTo(b.statSync().modified));

    var total = 0;
    for (final f in files) {
      total += await f.length();
    }
    var i = 0;
    while (total > softCapBytes && i < files.length) {
      final len = await files[i].length();
      try {
        await files[i].delete();
        total -= len;
      } catch (_) {/* benign */}
      i++;
    }
  }

  Future<void> wipeBook(String bookId) async {
    _requireSafeBookId(bookId);
    final bookDir = Directory(p.join(cacheRoot.path, bookId));
    if (bookDir.existsSync()) {
      await bookDir.delete(recursive: true);
    }
    _lru.removeWhere((k, _) => k.startsWith('$bookId:'));
  }
}
```

- [ ] **Step 2: Run tests — expect PASS**

Run: `just test test/features/tts/isolate/tts_cache_test.dart`
Expected: all 6 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/features/tts/isolate/tts_cache.dart test/features/tts/isolate/tts_cache_test.dart
git commit -m "phase-04 wave-2 task-4: TtsCache LRU + soft cap + wipeBook"
```

---

## Task 5: TtsClient — write failing tests first

**Files:**
- Create: `test/features/tts/isolate/tts_client_test.dart`

All tests use in-process mode (no `Isolate.spawn`). They drive the shape of the client.

- [ ] **Step 1: Write the tests**

```dart
// test/features/tts/isolate/tts_client_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_client.dart';

import '../../../helpers/fake_tts_engine.dart';

void main() {
  late Directory tempRoot;
  late TtsCache cache;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('tts_client_test_');
    cache = TtsCache(cacheRoot: tempRoot);
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  Future<TtsClient> spawnInProc({
    FakeTtsEngine? engine,
    int initialVoiceSid = 1,
  }) {
    final fake = engine ?? FakeTtsEngine();
    return TtsClient.spawn(
      cache: cache,
      initialVoiceSid: initialVoiceSid,
      engineFactory: () => fake,
    );
  }

  test('lifecycle: spawn emits ModelLoaded, dispose emits DisposeAck', () async {
    final events = <TtsEvent>[];
    final fake = FakeTtsEngine();
    final client = await spawnInProc(engine: fake);
    final sub = client.events.listen(events.add);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(events.whereType<ModelLoaded>(), hasLength(1));
    expect(fake.loaded, isTrue);

    await client.dispose();
    await sub.cancel();

    expect(events.whereType<DisposeAck>(), hasLength(1));
    expect(fake.disposed, isTrue);
  });

  test('SynthSentence writes wav and emits SentenceReady with RIFF header',
      () async {
    final client = await spawnInProc();
    final ready = client.events
        .whereType<SentenceReady>()
        .first
        .timeout(const Duration(seconds: 2));

    client.send(const SynthSentence(
      bookId: 'bookA',
      chapterIdx: 0,
      sentenceIdx: 0,
      text: 'Hello world.',
      voiceSid: 1,
    ));

    final evt = await ready;
    expect(evt.sentenceIdx, 0);
    final bytes = await File(evt.wavPath).readAsBytes();
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');

    await client.dispose();
  });

  test('sentence idx correlation across three synths', () async {
    final client = await spawnInProc();
    final collected = <int>[];
    final sub =
        client.events.whereType<SentenceReady>().listen((e) => collected.add(e.sentenceIdx));

    for (var i = 0; i < 3; i++) {
      client.send(SynthSentence(
        bookId: 'bookA',
        chapterIdx: 0,
        sentenceIdx: i,
        text: 'Sentence $i.',
        voiceSid: 1,
      ));
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();
    await client.dispose();

    expect(collected, [0, 1, 2]);
  });

  test('Cancel(idx) discards matching SentenceReady and deletes wav', () async {
    final slowFake = FakeTtsEngine(synthDelay: const Duration(milliseconds: 80));
    final client = await spawnInProc(engine: slowFake);
    final emitted = <SentenceReady>[];
    final sub = client.events.whereType<SentenceReady>().listen(emitted.add);

    client.send(const SynthSentence(
      bookId: 'bookA',
      chapterIdx: 0,
      sentenceIdx: 5,
      text: 'Will be cancelled.',
      voiceSid: 1,
    ));
    client.send(const Cancel(5));

    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();
    await client.dispose();

    expect(emitted.where((e) => e.sentenceIdx == 5), isEmpty);
    final expectedPath = cache.pathFor('bookA', 0, 5);
    expect(File(expectedPath).existsSync(), isFalse);
  });

  test('SetVoice switches sid for subsequent synths', () async {
    final fake = FakeTtsEngine();
    final client = await spawnInProc(engine: fake, initialVoiceSid: 1);

    client.send(const SetVoice(7));
    client.send(const SynthSentence(
      bookId: 'bookA',
      chapterIdx: 0,
      sentenceIdx: 0,
      text: 'After SetVoice.',
      voiceSid: 7,
    ));

    await client.events
        .whereType<SentenceReady>()
        .first
        .timeout(const Duration(seconds: 2));
    expect(fake.lastSid, 7);
    await client.dispose();
  });

  test('engine error emits TtsError preserving sentenceIdx', () async {
    final fake = FakeTtsEngine(throwOnGenerate: true);
    final client = await spawnInProc(engine: fake);
    final errFut = client.events
        .whereType<TtsError>()
        .first
        .timeout(const Duration(seconds: 2));

    client.send(const SynthSentence(
      bookId: 'bookA',
      chapterIdx: 0,
      sentenceIdx: 9,
      text: 'boom',
      voiceSid: 1,
    ));

    final err = await errFut;
    expect(err.sentenceIdx, 9);
    expect(err.error, isA<StateError>());
    await client.dispose();
  });

  test('no SentenceReady events fire after DisposeAck', () async {
    final slowFake = FakeTtsEngine(synthDelay: const Duration(milliseconds: 50));
    final client = await spawnInProc(engine: slowFake);

    var ackSeen = false;
    final postAck = <TtsEvent>[];
    final sub = client.events.listen((e) {
      if (ackSeen) postAck.add(e);
      if (e is DisposeAck) ackSeen = true;
    });

    for (var i = 0; i < 3; i++) {
      client.send(SynthSentence(
        bookId: 'bookA',
        chapterIdx: 0,
        sentenceIdx: i,
        text: 'S$i',
        voiceSid: 1,
      ));
    }
    await client.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();

    expect(postAck.whereType<SentenceReady>(), isEmpty);
  });
}
```

- [ ] **Step 2: Run — expect compile failure**

Run: `just test test/features/tts/isolate/tts_client_test.dart`
Expected: FAIL — `tts_client.dart` does not exist.

---

## Task 6: Worker main + TtsClient implementation

**Files:**
- Create: `lib/features/tts/isolate/tts_worker_main.dart`
- Create: `lib/features/tts/isolate/tts_client.dart`
- Modify: `test/helpers/fake_tts_engine.dart` (implement `SynthDelayed` marker)

- [ ] **Step 1: Write `tts_worker_main.dart` with shared loop + isolate entry + public SynthDelayed marker**

```dart
// lib/features/tts/isolate/tts_worker_main.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:murmur/features/tts/audio/wav_wrap.dart';
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/sherpa_tts_engine.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/model/paths.dart';

/// Bootstrap payload crossed via `Isolate.spawn`. All fields are
/// primitives / SendPort / RootIsolateToken so they survive cross-
/// isolate copy.
class TtsWorkerBootstrap {
  final RootIsolateToken rootToken;
  final SendPort toClient;
  final int initialVoiceSid;
  const TtsWorkerBootstrap({
    required this.rootToken,
    required this.toClient,
    required this.initialVoiceSid,
  });
}

/// Marker implemented only by test fakes. The shared message loop
/// consults it to honor a programmable pre-generate delay. The real
/// SherpaTtsEngine does NOT implement this, so production has zero
/// inserted latency.
abstract class SynthDelayed {
  Duration get synthDelay;
}

/// Top-level isolate entry (must be static).
///
/// Pitfall 1: BackgroundIsolateBinaryMessenger.ensureInitialized MUST
/// run before any plugin call. Pitfall 8: engine resources MUST be
/// released before Isolate.exit.
Future<void> ttsWorkerMain(TtsWorkerBootstrap args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootToken);

  final supportDir = await getApplicationSupportDirectory();
  final kokoroPaths = KokoroPaths.forSupportDir(supportDir.path);
  final cacheRoot = Directory('${supportDir.path}/tts_cache');
  if (!cacheRoot.existsSync()) cacheRoot.createSync(recursive: true);
  final cache = TtsCache(cacheRoot: cacheRoot);

  final engine = SherpaTtsEngine(kokoroPaths);
  try {
    await engine.load();
  } catch (e) {
    args.toClient.send(TtsError(null, e));
    Isolate.exit(args.toClient, const DisposeAck());
  }
  args.toClient.send(const ModelLoaded());

  final recv = ReceivePort();
  args.toClient.send(recv.sendPort);

  final cmdStream = recv.cast<TtsCommand>();
  await runSharedMessageLoop(
    engine: engine,
    cache: cache,
    commands: cmdStream,
    emit: args.toClient.send,
    initialVoiceSid: args.initialVoiceSid,
  );

  recv.close();
  Isolate.exit(args.toClient, const DisposeAck());
}

/// Shared message loop used by both the in-process (tests) and isolate
/// (prod) paths. Returns when Dispose arrives (after emitting
/// DisposeAck).
Future<void> runSharedMessageLoop({
  required TtsEngine engine,
  required TtsCache cache,
  required Stream<TtsCommand> commands,
  required void Function(TtsEvent) emit,
  required int initialVoiceSid,
}) async {
  var currentSid = initialVoiceSid;

  await for (final msg in commands) {
    switch (msg) {
      case SetVoice(:final sid):
        currentSid = sid;
      case Cancel():
        break; // D-12 soft cancel: client discards the matching SentenceReady.
      case SynthSentence(
          :final bookId,
          :final chapterIdx,
          :final sentenceIdx,
          :final text
        ):
        try {
          if (engine is SynthDelayed &&
              (engine as SynthDelayed).synthDelay > Duration.zero) {
            await Future<void>.delayed((engine as SynthDelayed).synthDelay);
          }
          final r = engine.generate(text: text, sid: currentSid, speed: 1.0);
          final bytes = wavWrap(r.samples, sampleRate: r.sampleRate);
          final path = cache.pathFor(bookId, chapterIdx, sentenceIdx);
          await File(path).writeAsBytes(bytes, flush: true);
          emit(SentenceReady(sentenceIdx, path));
        } catch (e) {
          emit(TtsError(sentenceIdx, e));
        }
      case Dispose():
        await engine.dispose();
        emit(const DisposeAck());
        return;
    }
  }
}
```

- [ ] **Step 2: Update FakeTtsEngine to implement SynthDelayed**

Edit `test/helpers/fake_tts_engine.dart`. Add import:
```dart
import 'package:murmur/features/tts/isolate/tts_worker_main.dart';
```
Change the class header from:
```dart
class FakeTtsEngine implements TtsEngine {
```
to:
```dart
class FakeTtsEngine implements TtsEngine, SynthDelayed {
```
Add `@override` on the existing `synthDelay` field:
```dart
  @override
  final Duration synthDelay;
```

- [ ] **Step 3: Write `tts_client.dart`**

```dart
// lib/features/tts/isolate/tts_client.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_worker_main.dart';

/// UI-side handle to the TTS worker.
///
/// Two modes:
///   - In-process (tests): engineFactory != null. No Isolate.spawn;
///     the shared message loop runs on the calling isolate via a
///     StreamController.
///   - Isolate (prod): engineFactory == null. Spawns a real isolate
///     running `ttsWorkerMain`.
class TtsClient {
  TtsClient._({
    required this.cache,
    required StreamController<TtsEvent> events,
    required void Function(TtsCommand) sendRaw,
    required Set<int> pendingDiscard,
    required Future<void> Function() teardown,
  })  : _events = events,
        _sendRaw = sendRaw,
        _pendingDiscard = pendingDiscard,
        _teardown = teardown;

  final TtsCache cache;
  final StreamController<TtsEvent> _events;
  final void Function(TtsCommand) _sendRaw;
  final Set<int> _pendingDiscard;
  final Future<void> Function() _teardown;

  Stream<TtsEvent> get events => _events.stream;

  static Future<TtsClient> spawn({
    required TtsCache cache,
    required int initialVoiceSid,
    TtsEngineFactory? engineFactory,
  }) {
    if (engineFactory != null) {
      return _spawnInProcess(
        cache: cache,
        initialVoiceSid: initialVoiceSid,
        engineFactory: engineFactory,
      );
    }
    return _spawnIsolate(cache: cache, initialVoiceSid: initialVoiceSid);
  }

  /// Shared filter: swallow SentenceReady for cancelled sentences and
  /// delete the wav on disk.
  static void _emitFiltered({
    required TtsEvent e,
    required Set<int> pendingDiscard,
    required StreamController<TtsEvent> sink,
  }) {
    if (e is SentenceReady && pendingDiscard.remove(e.sentenceIdx)) {
      try {
        final f = File(e.wavPath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {/* benign */}
      return;
    }
    if (sink.isClosed) return;
    sink.add(e);
  }

  static Future<TtsClient> _spawnInProcess({
    required TtsCache cache,
    required int initialVoiceSid,
    required TtsEngineFactory engineFactory,
  }) async {
    final cmdCtl = StreamController<TtsCommand>();
    final evtCtl = StreamController<TtsEvent>.broadcast();
    final pendingDiscard = <int>{};
    final engine = engineFactory();

    // Emit ModelLoaded after engine.load() so the test observing the
    // lifecycle sees the same order as the isolate path.
    final loopDone = () async {
      await engine.load();
      _emitFiltered(
        e: const ModelLoaded(),
        pendingDiscard: pendingDiscard,
        sink: evtCtl,
      );
      await runSharedMessageLoop(
        engine: engine,
        cache: cache,
        commands: cmdCtl.stream,
        emit: (e) => _emitFiltered(
          e: e,
          pendingDiscard: pendingDiscard,
          sink: evtCtl,
        ),
        initialVoiceSid: initialVoiceSid,
      );
    }();

    return TtsClient._(
      cache: cache,
      events: evtCtl,
      sendRaw: cmdCtl.add,
      pendingDiscard: pendingDiscard,
      teardown: () async {
        await loopDone;
        await cmdCtl.close();
        await evtCtl.close();
      },
    );
  }

  static Future<TtsClient> _spawnIsolate({
    required TtsCache cache,
    required int initialVoiceSid,
  }) async {
    final fromWorker = ReceivePort();
    final rootToken = RootIsolateToken.instance!;
    final evtCtl = StreamController<TtsEvent>.broadcast();
    final pendingDiscard = <int>{};

    SendPort? toWorker;
    final toWorkerReady = Completer<SendPort>();

    final sub = fromWorker.listen((dynamic msg) {
      if (msg is SendPort) {
        toWorker = msg;
        if (!toWorkerReady.isCompleted) toWorkerReady.complete(msg);
        return;
      }
      if (msg is TtsEvent) {
        _emitFiltered(e: msg, pendingDiscard: pendingDiscard, sink: evtCtl);
      }
    });

    final iso = await Isolate.spawn<TtsWorkerBootstrap>(
      ttsWorkerMain,
      TtsWorkerBootstrap(
        rootToken: rootToken,
        toClient: fromWorker.sendPort,
        initialVoiceSid: initialVoiceSid,
      ),
      errorsAreFatal: true,
      debugName: 'tts-worker',
    );

    try {
      await toWorkerReady.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      iso.kill(priority: Isolate.immediate);
      await sub.cancel();
      fromWorker.close();
      await evtCtl.close();
      throw StateError('TTS worker failed to start within 30s');
    }

    return TtsClient._(
      cache: cache,
      events: evtCtl,
      sendRaw: (cmd) => toWorker?.send(cmd),
      pendingDiscard: pendingDiscard,
      teardown: () async {
        await sub.cancel();
        fromWorker.close();
        await evtCtl.close();
      },
    );
  }

  void send(TtsCommand cmd) {
    if (cmd is Cancel) {
      _pendingDiscard.add(cmd.sentenceIdx);
    }
    _sendRaw(cmd);
  }

  /// Sends Dispose, awaits DisposeAck (with a 2 s safety timeout),
  /// then tears down.
  Future<void> dispose() async {
    final ackFut = events
        .firstWhere((e) => e is DisposeAck)
        .timeout(const Duration(seconds: 2), onTimeout: () => const DisposeAck());
    _sendRaw(const Dispose());
    await ackFut;
    await _teardown();
  }
}
```

- [ ] **Step 4: Run Task 5 tests**

Run: `just test test/features/tts/isolate/tts_client_test.dart`
Expected: all 7 tests PASS.

If the Cancel-discard test is flaky, verify:
- `_pendingDiscard` is the same `Set<int>` used by `_emitFiltered` at emit time.
- `send(Cancel)` adds to the set synchronously (it does — `_sendRaw` runs after set.add).

- [ ] **Step 5: Commit**

```bash
git add lib/features/tts/isolate/tts_worker_main.dart lib/features/tts/isolate/tts_client.dart test/helpers/fake_tts_engine.dart test/features/tts/isolate/tts_client_test.dart
git commit -m "phase-04 wave-2 task-6: TtsClient (in-process + isolate modes) + shared message loop"
```

> Note: `tts_worker_main.dart` will fail to analyze until `sherpa_tts_engine.dart` exists (Task 7). Expect the commit's pre-hook to surface an analyze error pointing at that import. If your pre-commit hook blocks on `flutter analyze`, either fold Task 7 into this commit or use the workflow described in Task 7 Step 1 below which keeps this commit deferred until the adapter lands.

**Alternative ordering if `flutter analyze` is a pre-commit gate:** skip Step 5 above and go to Task 7, then run `git add` for both Task 6 + Task 7's files together and use the Task 6 commit message for one combined commit. The plan below assumes the pre-commit hook runs tests only — adjust as your local setup requires.

---

## Task 7: SherpaTtsEngine adapter + spike wavWrap migration

**Files:**
- Create: `lib/features/tts/isolate/sherpa_tts_engine.dart`
- Modify: `lib/features/tts/spike/spike_page.dart`

- [ ] **Step 1: Write the adapter**

```dart
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
```

- [ ] **Step 2: Migrate spike_page.dart to the shared wavWrap**

Edit `lib/features/tts/spike/spike_page.dart`:

1. Add import after the existing `wav_wrap`-adjacent imports:
   ```dart
   import 'package:murmur/features/tts/audio/wav_wrap.dart';
   ```
2. Remove the line `import 'dart:convert' show ascii;` (only used by the inlined helper).
3. Delete the three helpers (`_wrapPcmAsWav`, `_u32le`, `_u16le`).
4. In `_synthAndPlay`, change:
   ```dart
   wav = _wrapPcmAsWav(audio.samples, audio.sampleRate);
   ```
   to:
   ```dart
   wav = wavWrap(audio.samples, sampleRate: audio.sampleRate);
   ```

- [ ] **Step 3: Verify sherpa_onnx import isolation**

Run:
```bash
grep -lRE "^import 'package:sherpa_onnx/" lib/
```
Expected output exactly (two lines, order may vary):
```
lib/features/tts/isolate/sherpa_tts_engine.dart
lib/features/tts/spike/spike_page.dart
```

- [ ] **Step 4: Analyze**

Run: `just analyze`
Expected: 9 pre-existing issues remain; no new ones.

- [ ] **Step 5: Run the full unit suite so far**

Run: `just test`
Expected: green across `tts_cache_test.dart`, `tts_client_test.dart`, all Wave 1 tests, and existing Phase 2/3 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/features/tts/isolate/sherpa_tts_engine.dart lib/features/tts/spike/spike_page.dart
git commit -m "phase-04 wave-2 task-7: SherpaTtsEngine adapter; spike uses shared wavWrap"
```

---

## Task 8: Wire TtsCache into the book-delete flow

**Files:**
- Create: `lib/features/tts/isolate/tts_cache_provider.dart`
- Create: `lib/features/tts/isolate/tts_cache_provider.g.dart` (generated)
- Modify: `lib/features/library/library_provider.dart`
- Create: `test/features/library/delete_book_wipes_cache_test.dart`

- [ ] **Step 1: Write the provider**

```dart
// lib/features/tts/isolate/tts_cache_provider.dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:murmur/features/tts/isolate/tts_cache.dart';

part 'tts_cache_provider.g.dart';

/// App-wide singleton TtsCache rooted at `{appSupport}/tts_cache/`.
///
/// Production wiring (Wave 3 queue bootstrap) awaits
/// [ttsCacheAsyncProvider] at app startup and overrides this sync
/// provider with the resolved value. Tests override directly.
@Riverpod(keepAlive: true)
TtsCache ttsCache(Ref ref) {
  throw UnimplementedError(
    'ttsCacheProvider must be overridden at app startup; see '
    'ttsCacheAsyncProvider.future (Wave 3 adds main.dart wiring).',
  );
}

@Riverpod(keepAlive: true)
Future<TtsCache> ttsCacheAsync(Ref ref) async {
  final support = await getApplicationSupportDirectory();
  final root = Directory(p.join(support.path, 'tts_cache'));
  if (!root.existsSync()) root.createSync(recursive: true);
  return TtsCache(cacheRoot: root);
}
```

- [ ] **Step 2: Generate**

Run: `just gen`
Expected: produces `lib/features/tts/isolate/tts_cache_provider.g.dart`.

- [ ] **Step 3: Write failing integration test**

```dart
// test/features/library/delete_book_wipes_cache_test.dart
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/db/app_database_provider.dart';
import 'package:murmur/features/library/library_provider.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_cache_provider.dart';

void main() {
  late Directory tempRoot;
  late TtsCache cache;
  late AppDatabase db;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('wipe_test_');
    cache = TtsCache(cacheRoot: tempRoot);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  test('deleteBook invokes TtsCache.wipeBook(bookId.toString())', () async {
    final id = await db.into(db.books).insert(
          BooksCompanion.insert(
            title: 'Moby-Dick',
            author: const Value('Herman Melville'),
            filePath: '/tmp/moby.epub',
            importedAt: DateTime.now(),
          ),
        );

    final wavPath = cache.pathFor(id.toString(), 0, 0);
    await File(wavPath).writeAsBytes(List.filled(64, 0));
    expect(File(wavPath).existsSync(), isTrue);

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      ttsCacheProvider.overrideWithValue(cache),
    ]);
    addTearDown(container.dispose);

    await container.read(libraryProvider.notifier).deleteBook(id);

    expect(File(wavPath).existsSync(), isFalse);
    expect(
      Directory('${tempRoot.path}/$id').existsSync(),
      isFalse,
      reason: 'Book subtree should be removed',
    );
  });
}
```

**Caveat — verify test fixture shape before running:** the test uses `AppDatabase.forTesting(...)` and inserts via `BooksCompanion.insert`. If Wave 1's Drift v3 schema requires additional non-nullable columns, match the signatures of existing Phase 2 tests (for example `test/db/app_database_test.dart`) — adjust only the `insert` argument list, never the production schema.

- [ ] **Step 4: Run — expect FAIL (deleteBook does not yet wipe cache)**

Run: `just test test/features/library/delete_book_wipes_cache_test.dart`
Expected: FAIL — file still exists after `deleteBook`.

- [ ] **Step 5: Modify `library_provider.dart`**

Edit `lib/features/library/library_provider.dart`. Add imports at the top of the imports block (alongside the existing `../../core/db/...` imports):
```dart
import '../tts/isolate/tts_cache.dart';
import '../tts/isolate/tts_cache_provider.dart';
```

In the `deleteBook` method, after the `if (row == null) return;` guard and **before** `await (db.delete(db.books)...).go();`, insert:

```dart
    // Best-effort TTS cache wipe (CD-02). Run before the DB delete so
    // a mid-op crash leaves an orphan cache (disk bloat only) rather
    // than a ghost cache for a recycled rowid.
    try {
      final cache = ref.read(ttsCacheProvider);
      await cache.wipeBook(bookId.toString());
    } catch (_) {
      // Provider not overridden (uncommon test path) or wipe failed —
      // non-fatal.
    }
```

- [ ] **Step 6: Run test — expect PASS**

Run: `just test test/features/library/delete_book_wipes_cache_test.dart`
Expected: PASS.

- [ ] **Step 7: Run the full library test folder for regressions**

Run: `just test test/features/library/`
Expected: all green. If an existing `deleteBook` test breaks because it uses a `ProviderContainer` without the `ttsCacheProvider` override, the try/catch already swallows the `UnimplementedError` — the test should still pass. If it does not, add `ttsCacheProvider.overrideWithValue(TtsCache(cacheRoot: ...))` to that test's container.

- [ ] **Step 8: Commit**

```bash
git add lib/features/tts/isolate/tts_cache_provider.dart lib/features/tts/isolate/tts_cache_provider.g.dart lib/features/library/library_provider.dart test/features/library/delete_book_wipes_cache_test.dart
git commit -m "phase-04 wave-2 task-8: LibraryNotifier.deleteBook wipes tts cache"
```

---

## Task 9: PlaybackState + PlaybackStateNotifier

**Files:**
- Create: `lib/core/playback_state.dart`
- Create: `lib/core/playback_state.g.dart` (generated)
- Create: `test/core/playback_state_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/core/playback_state_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/playback_state.dart';

void main() {
  group('PlaybackState', () {
    test('idle defaults', () {
      const s = PlaybackState.idle();
      expect(s.bookId, isNull);
      expect(s.chapterIdx, 0);
      expect(s.sentenceIdx, 0);
      expect(s.isPlaying, false);
      expect(s.speed, 1.0);
      expect(s.voiceId, 'af_bella');
    });

    test('equality + hashCode cover all fields', () {
      const a = PlaybackState(
        bookId: '1',
        chapterIdx: 2,
        sentenceIdx: 3,
        isPlaying: true,
        speed: 1.25,
        voiceId: 'am_adam',
      );
      const b = PlaybackState(
        bookId: '1',
        chapterIdx: 2,
        sentenceIdx: 3,
        isPlaying: true,
        speed: 1.25,
        voiceId: 'am_adam',
      );
      const c = PlaybackState(
        bookId: '1',
        chapterIdx: 2,
        sentenceIdx: 4,
        isPlaying: true,
        speed: 1.25,
        voiceId: 'am_adam',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('copyWith preserves unset fields', () {
      const base = PlaybackState.idle();
      final next = base.copyWith(sentenceIdx: 7);
      expect(next.sentenceIdx, 7);
      expect(next.bookId, base.bookId);
      expect(next.voiceId, base.voiceId);
    });

    test('copyWith clears bookId only when allowNullBookId: true', () {
      const base = PlaybackState(
        bookId: 'x',
        chapterIdx: 3,
        sentenceIdx: 4,
        isPlaying: true,
        speed: 1.0,
        voiceId: 'af',
      );
      final cleared = base.copyWith(bookId: null, allowNullBookId: true);
      expect(cleared.bookId, isNull);

      final preserved = base.copyWith();
      expect(preserved.bookId, 'x');
    });
  });

  group('PlaybackStateNotifier', () {
    ProviderContainer makeContainer() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('build returns idle', () {
      final c = makeContainer();
      expect(c.read(playbackStateProvider), const PlaybackState.idle());
    });

    test('setSentence updates only sentenceIdx', () {
      final c = makeContainer();
      c.read(playbackStateProvider.notifier).setSentence(9);
      expect(c.read(playbackStateProvider).sentenceIdx, 9);
      expect(c.read(playbackStateProvider).chapterIdx, 0);
    });

    test('setBook resets chapter/sentence; re-setBook resets again', () {
      final c = makeContainer();
      final n = c.read(playbackStateProvider.notifier);
      n.setSentence(5);
      n.setChapter(3);
      n.setBook('b1');
      expect(c.read(playbackStateProvider).bookId, 'b1');
      expect(c.read(playbackStateProvider).chapterIdx, 0);
      expect(c.read(playbackStateProvider).sentenceIdx, 0);

      n.setSentence(8);
      n.setBook('b2');
      expect(c.read(playbackStateProvider).bookId, 'b2');
      expect(c.read(playbackStateProvider).sentenceIdx, 0);
    });

    test('setSpeed clamps to [0.5, 3.0]', () {
      final c = makeContainer();
      final n = c.read(playbackStateProvider.notifier);
      n.setSpeed(2.5);
      expect(c.read(playbackStateProvider).speed, 2.5);
      n.setSpeed(5.0);
      expect(c.read(playbackStateProvider).speed, 3.0);
      n.setSpeed(0.1);
      expect(c.read(playbackStateProvider).speed, 0.5);
    });

    test('setVoice + setPlaying', () {
      final c = makeContainer();
      final n = c.read(playbackStateProvider.notifier);
      n.setVoice('bm_lewis');
      n.setPlaying(true);
      final s = c.read(playbackStateProvider);
      expect(s.voiceId, 'bm_lewis');
      expect(s.isPlaying, true);
    });

    test('two rapid mutations emit two distinct states', () {
      final c = makeContainer();
      final states = <PlaybackState>[];
      c.listen<PlaybackState>(
        playbackStateProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      final n = c.read(playbackStateProvider.notifier);
      n.setSentence(1);
      n.setSentence(2);
      expect(states.map((s) => s.sentenceIdx).toList(), [0, 1, 2]);
    });
  });
}
```

- [ ] **Step 2: Run — expect compile failure**

Run: `just test test/core/playback_state_test.dart`
Expected: FAIL (files don't exist).

- [ ] **Step 3: Implement PlaybackState + Notifier**

```dart
// lib/core/playback_state.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playback_state.g.dart';

/// Immutable playback cursor shared between reader and TTS (CD-04 / PBK-08).
///
/// Reader reads; TTS writes. Neither feature imports the other.
class PlaybackState {
  final String? bookId;
  final int chapterIdx;
  final int sentenceIdx;
  final bool isPlaying;
  final double speed;
  final String voiceId;

  const PlaybackState({
    required this.bookId,
    required this.chapterIdx,
    required this.sentenceIdx,
    required this.isPlaying,
    required this.speed,
    required this.voiceId,
  });

  const PlaybackState.idle()
      : bookId = null,
        chapterIdx = 0,
        sentenceIdx = 0,
        isPlaying = false,
        speed = 1.0,
        voiceId = 'af_bella';

  /// [allowNullBookId] distinguishes "leave bookId alone" from
  /// "explicitly clear it". Default false preserves existing bookId.
  PlaybackState copyWith({
    String? bookId,
    bool allowNullBookId = false,
    int? chapterIdx,
    int? sentenceIdx,
    bool? isPlaying,
    double? speed,
    String? voiceId,
  }) {
    return PlaybackState(
      bookId: allowNullBookId ? bookId : (bookId ?? this.bookId),
      chapterIdx: chapterIdx ?? this.chapterIdx,
      sentenceIdx: sentenceIdx ?? this.sentenceIdx,
      isPlaying: isPlaying ?? this.isPlaying,
      speed: speed ?? this.speed,
      voiceId: voiceId ?? this.voiceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackState &&
          bookId == other.bookId &&
          chapterIdx == other.chapterIdx &&
          sentenceIdx == other.sentenceIdx &&
          isPlaying == other.isPlaying &&
          speed == other.speed &&
          voiceId == other.voiceId;

  @override
  int get hashCode =>
      Object.hash(bookId, chapterIdx, sentenceIdx, isPlaying, speed, voiceId);

  @override
  String toString() =>
      'PlaybackState(bookId: $bookId, ch: $chapterIdx, sent: $sentenceIdx, '
      'playing: $isPlaying, speed: $speed, voice: $voiceId)';
}

/// Coordination seam between reader and TTS. keepAlive ensures the
/// cursor survives widget rebuilds for the reader session.
@Riverpod(keepAlive: true)
class PlaybackStateNotifier extends _$PlaybackStateNotifier {
  @override
  PlaybackState build() => const PlaybackState.idle();

  void setSentence(int i) => state = state.copyWith(sentenceIdx: i);

  void setChapter(int i, {int sentence = 0}) =>
      state = state.copyWith(chapterIdx: i, sentenceIdx: sentence);

  void setBook(String? bookId) {
    if (state.bookId == bookId) return;
    state = state.copyWith(
      bookId: bookId,
      allowNullBookId: bookId == null,
      chapterIdx: 0,
      sentenceIdx: 0,
    );
  }

  void setPlaying(bool p) => state = state.copyWith(isPlaying: p);

  void setSpeed(double s) =>
      state = state.copyWith(speed: s.clamp(0.5, 3.0).toDouble());

  void setVoice(String v) => state = state.copyWith(voiceId: v);
}
```

- [ ] **Step 4: Generate**

Run: `just gen`
Expected: creates `lib/core/playback_state.g.dart` exposing `playbackStateProvider`.

- [ ] **Step 5: Run tests — expect PASS**

Run: `just test test/core/playback_state_test.dart`
Expected: 10 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/playback_state.dart lib/core/playback_state.g.dart test/core/playback_state_test.dart
git commit -m "phase-04 wave-2 task-9: PlaybackState + playbackStateProvider (CD-04/PBK-08)"
```

---

## Task 10: Architecture boundary tests

**Files:**
- Create: `test/architecture/feature_boundary_test.dart`
- Create: `test/architecture/no_direct_network_test.dart`

Structural enforcement of PBK-08 + the no-analytics / single-downloader / single-sherpa-importer rules. Grep-based — fast, flake-free, no dev deps.

- [ ] **Step 1: Write feature_boundary_test.dart**

```dart
// test/architecture/feature_boundary_test.dart
//
// Enforces PBK-08: reader and tts features never import each other.
// Both depend on lib/core/playback_state.dart as the coordination seam.
// Also enforces that lib/core/** is feature-free.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<List<File>> _dartFiles(String dir) async {
  final result = <File>[];
  final d = Directory(dir);
  if (!d.existsSync()) return result;
  await for (final e in d.list(recursive: true, followLinks: false)) {
    if (e is File &&
        e.path.endsWith('.dart') &&
        !e.path.endsWith('.g.dart') &&
        !e.path.endsWith('.freezed.dart')) {
      result.add(e);
    }
  }
  return result;
}

void main() {
  test('features/reader/** does NOT import features/tts/**', () async {
    final offenders = <String>[];
    for (final f in await _dartFiles('lib/features/reader')) {
      final src = await f.readAsString();
      if (RegExp(r'''import\s+['"][^'"]*features/tts/''').hasMatch(src)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Reader must not import TTS; use lib/core/playback_state.dart');
  });

  test('features/tts/** does NOT import features/reader/**', () async {
    final offenders = <String>[];
    for (final f in await _dartFiles('lib/features/tts')) {
      final src = await f.readAsString();
      if (RegExp(r'''import\s+['"][^'"]*features/reader/''').hasMatch(src)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'TTS must not import Reader; use lib/core/playback_state.dart');
  });

  test('lib/core/** does NOT import features/**', () async {
    final offenders = <String>[];
    for (final f in await _dartFiles('lib/core')) {
      final src = await f.readAsString();
      if (RegExp(r'''import\s+['"][^'"]*features/''').hasMatch(src)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'lib/core/** must remain free of feature imports');
  });
}
```

- [ ] **Step 2: Write no_direct_network_test.dart**

```dart
// test/architecture/no_direct_network_test.dart
//
// Enforces:
// 1. package:http is imported only by the model downloader.
// 2. package:sherpa_onnx is imported only by the sherpa adapter and
//    the debug spike page.
// 3. No analytics / crash / telemetry SDKs anywhere in lib/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<List<File>> _dartFiles(String dir) async {
  final result = <File>[];
  await for (final e in Directory(dir).list(recursive: true, followLinks: false)) {
    if (e is File &&
        e.path.endsWith('.dart') &&
        !e.path.endsWith('.g.dart') &&
        !e.path.endsWith('.freezed.dart')) {
      result.add(e);
    }
  }
  return result;
}

void main() {
  test('package:http imported ONLY by model_downloader.dart', () async {
    final offenders = <String>[];
    for (final f in await _dartFiles('lib')) {
      final src = await f.readAsString();
      if (RegExp(r'''import\s+['"]package:http/''').hasMatch(src)) {
        if (!f.path.replaceAll(r'\', '/').endsWith('/model_downloader.dart')) {
          offenders.add(f.path);
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Only model_downloader may make network calls');
  });

  test('package:sherpa_onnx imported ONLY by sherpa_tts_engine.dart + spike_page.dart',
      () async {
    const allowed = <String>{
      'lib/features/tts/isolate/sherpa_tts_engine.dart',
      'lib/features/tts/spike/spike_page.dart',
    };
    final offenders = <String>[];
    for (final f in await _dartFiles('lib')) {
      final src = await f.readAsString();
      if (RegExp(r'''import\s+['"]package:sherpa_onnx/''').hasMatch(src)) {
        if (!allowed.contains(f.path.replaceAll(r'\', '/'))) {
          offenders.add(f.path);
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'sherpa_onnx must be isolated to the engine adapter');
  });

  test('no analytics/telemetry/crashlytics packages in lib/', () async {
    const banned = [
      'firebase',
      'sentry',
      'crashlytics',
      'amplitude',
      'mixpanel',
      'segment',
      'posthog',
    ];
    final offenders = <String>[];
    for (final f in await _dartFiles('lib')) {
      final src = (await f.readAsString()).toLowerCase();
      for (final b in banned) {
        if (src.contains('package:$b')) offenders.add('${f.path} imports $b');
      }
    }
    expect(offenders, isEmpty,
        reason: 'PROJECT.md bans all analytics/telemetry SDKs');
  });
}
```

- [ ] **Step 3: Run both tests**

Run: `just test test/architecture/feature_boundary_test.dart test/architecture/no_direct_network_test.dart`
Expected: 6 tests PASS.

If any fails, fix the offending import in source — NEVER relax the test.

- [ ] **Step 4: Commit**

```bash
git add test/architecture/feature_boundary_test.dart test/architecture/no_direct_network_test.dart
git commit -m "phase-04 wave-2 task-10: architecture boundary tests (reader↔tts, network, sherpa, analytics)"
```

---

## Task 11: Wave 2 sign-off — full suite + summary + WAVES.md flip

**Files:**
- Create: `.planning/phases/04-tts-engine-playback-foundation/04-02-SUMMARY.md`
- Modify: `.planning/phases/04-tts-engine-playback-foundation/WAVES.md`

- [ ] **Step 1: Run the full test suite**

Run: `just test`
Expected: all tests green. No regressions in Wave 1 tests (model, installer, splitter, wav_wrap, drift migrations, library, widget, navigation).

If anything outside this wave regresses, investigate and fix — do not suppress.

- [ ] **Step 2: Run analyze**

Run: `just analyze`
Expected: 9 pre-existing issues remain; no new ones.

- [ ] **Step 3: Write summary**

Create `.planning/phases/04-tts-engine-playback-foundation/04-02-SUMMARY.md` with sections:
- **Date / Outcome** — today's date, PASS
- **What landed** — commit-by-commit list (tasks 1–10)
- **Protocol surface** — final sealed `TtsCommand` / `TtsEvent` class list
- **In-process test-mode rationale** — why we avoided a real isolate in unit tests (speed, determinism, no plugin binding setup; real-isolate coverage deferred to Wave 6 device UAT)
- **Deviations from 04-04 + 04-05 legacy specs** — any naming/path differences vs the legacy XML specs (e.g. `tts_worker_main.dart` vs legacy `tts_worker.dart`; `ttsCacheAsyncProvider` split)
- **Open items for Wave 3** — `ttsCacheProvider` override wiring in `main.dart` (deferred to Wave 3 queue plan); `TtsClient` isolate mode only exercised on device in Wave 6
- **Test footprint** — counts for unit/arch tests added, total suite green count

- [ ] **Step 4: Flip WAVES.md**

Edit `.planning/phases/04-tts-engine-playback-foundation/WAVES.md`. Replace the Wave 2 heading block:

From:
```
## Wave 2 — Isolate protocol + PlaybackState seam

**Status:** BLOCKED (on Wave 1)
**Legacy specs:** `04-04-PLAN.md`, `04-05-PLAN.md`
**Requirements covered:** TTS-05, TTS-07 (cache), TTS-09, PBK-08
```

To:
```
## Wave 2 — Isolate protocol + PlaybackState seam

**Status:** COMPLETE (YYYY-MM-DD)
**Legacy specs:** `04-04-PLAN.md`, `04-05-PLAN.md` (consolidated into `PLAN.md`)
**Current plan:** `PLAN.md` (this directory) — 11 checkbox-driven tasks
**Summary:** `04-02-SUMMARY.md`
**Requirements covered:** TTS-05, TTS-07 (cache), TTS-09, PBK-08
```

(Replace `YYYY-MM-DD` with the actual sign-off date.)

Also flip the Wave 3 status note from `BLOCKED (on Wave 2)` to `BLOCKED (on Wave 2 main.dart cache wiring)` — this makes it explicit that Wave 3 must add the startup override before the queue can consume the cache.

- [ ] **Step 5: Commit**

```bash
git add .planning/phases/04-tts-engine-playback-foundation/WAVES.md .planning/phases/04-tts-engine-playback-foundation/04-02-SUMMARY.md
git commit -m "phase-04 wave-2 task-11: sign-off + summary + WAVES.md status flip"
```

---

## Self-Review

**1. Spec coverage:**
- 04-04 Task 1 (messages + FakeTtsEngine + TtsClient with DI seam) → Tasks 1, 2, 5, 6.
- 04-04 Task 2 (real TtsWorker + SherpaTtsEngine) → Tasks 6 (worker loop + isolate entry) + 7 (adapter).
- 04-04 Task 3 (TtsCache + wipeBook hook) → Tasks 3 + 4 + 8.
- 04-05 Task 1 (PlaybackState + notifier + tests) → Task 9.
- 04-05 Task 2 (boundary + network + analytics tests) → Task 10.
- Wave 1 spike wavWrap migration → Task 7 Step 2.
- D-12 soft-cancel semantics → Task 1 messages + Task 6 `_pendingDiscard` + Task 5 test.
- CD-02 (20MB cap, LRU, wipeBook, path-traversal) → Tasks 3 + 4 + 8.
- TTS-09 guard (`speed == 1.0`) → Task 7 assertion + Task 2 assertion.
- PBK-08 structural enforcement → Task 10.
- Pitfall 1 (BackgroundIsolateBinaryMessenger) → Task 6 `ttsWorkerMain`.
- Pitfall 8 (engine dispose before isolate exit) → Task 7 `SherpaTtsEngine.dispose` + Task 6 `runSharedMessageLoop` Dispose branch + `Isolate.exit` ordering.

**2. Placeholder scan:** No TBDs, no "TODO", no "implement later", no "add error handling", no "similar to Task N". Every code step ships complete code.

**3. Type consistency:**
- `TtsCache.pathFor(String bookId, int chapterIdx, int sentenceIdx)` — consistent across Tasks 3, 4, 6, 8.
- `SynthSentence` field names (`bookId`, `chapterIdx`, `sentenceIdx`, `text`, `voiceSid`) — consistent across Tasks 1, 5, 6.
- `PlaybackState.copyWith(..., bool allowNullBookId = false)` sentinel — consistent across Task 9 class + tests.
- `SynthDelayed` marker — declared once in `tts_worker_main.dart` (Task 6 Step 1), implemented by `FakeTtsEngine` (Task 6 Step 2), consulted in `runSharedMessageLoop` (Task 6 Step 1).
- `ttsCacheProvider` (sync, override-required) vs `ttsCacheAsyncProvider` (async initializer) — naming consistent across Task 8 provider file + library-test override + library_provider consumer.

**4. Known non-issues flagged for Wave 3:**
- `ttsCacheProvider` throws `UnimplementedError` if read without an override. Production `main.dart` wiring (await `ttsCacheAsyncProvider.future`, then override the sync provider) lands in Wave 3 when the queue + just_audio player need the cache. Tests override directly (see Task 8). This is deliberate — Wave 2's scope is coordination + protocol + cache; app-wide Riverpod wiring belongs with the consumer in Wave 3.
- The real `Isolate.spawn` path is not unit-tested (plugin bindings + native sherpa make that brittle in unit tests). It runs against real sherpa, i.e. device-only, consistent with `04-VALIDATION.md` row 04-04-02 (static analysis + grep) + Wave 6 device UAT coverage.

---

## Execution Handoff

**Plan complete and saved to `.planning/phases/04-tts-engine-playback-foundation/PLAN.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per task with the superpowers:subagent-driven-development skill, review between tasks, fast iteration. Natural fit for 11 focused tasks where each one is self-contained.

**2. Inline Execution** — execute tasks in this session using superpowers:executing-plans, batch with checkpoints at Tasks 4, 8, 10, 11 for review.

**Which approach?**
