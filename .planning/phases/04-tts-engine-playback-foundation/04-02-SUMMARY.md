# Phase 4 Wave 2 — Summary

**Date:** 2026-04-17
**Outcome:** PASS

## What landed

Commits since Wave 1 sign-off (`dd77a64`), oldest-first:

- `7cb2100` — task-1: sealed TtsCommand/TtsEvent protocol + TtsEngine interface (`messages.dart`)
- `adc9fb8` — task-2: `FakeTtsEngine` deterministic test double
- `29c285a` — task-4: `TtsCache` (LRU + 20MB soft cap + `wipeBook` + path-traversal defense) + 6 unit tests
- `6c4b962` — task-6: `TtsClient` (in-process + isolate modes) + `tts_worker_main.dart` (shared message loop, `SynthDelayed` marker, `ttsWorkerMain` entry) + `sherpa_tts_engine.dart` stub + `FakeTtsEngine` `SynthDelayed` implementation + 7 protocol tests
- `c15979f` — task-7: `SherpaTtsEngine` adapter (real sherpa_onnx) replaces stub; spike migrates to shared `wavWrap`
- `897713f` — task-8: `ttsCacheProvider` + `ttsCacheAsyncProvider` + `LibraryNotifier.deleteBook` wipes tts cache (+ integration test)
- `ebf65d2` — task-9: `PlaybackState` + `playbackStateProvider` — CD-04/PBK-08 coordination seam
- `8d4f97a` — task-10: architecture boundary tests (3 feature-boundary + 3 no-direct-network grep tests)

## Protocol surface

Final sealed hierarchies (from `lib/features/tts/isolate/messages.dart`):

- `sealed class TtsCommand` → `SynthSentence`, `Cancel`, `SetVoice`, `Dispose`
- `sealed class TtsEvent` → `ModelLoaded`, `SentenceReady`, `TtsError`, `DisposeAck`
- `abstract class TtsEngine` (load/generate/dispose) + `SynthResult(samples, sampleRate)` + `TtsEngineFactory` typedef

## In-process test mode rationale

Unit tests exercise the full client/worker protocol without `Isolate.spawn` by running `runSharedMessageLoop` on the calling isolate via a `StreamController<TtsCommand>`. Benefits:

- No `BackgroundIsolateBinaryMessenger` / `rootIsolateToken` setup required in tests.
- Deterministic via `FakeTtsEngine` (no sherpa_onnx, no FFI).
- Cancel-discards timing is reproducible via `SynthDelayed.synthDelay`.
- Real-isolate coverage is deferred to Wave 6 device UAT — consistent with `04-VALIDATION.md` row 04-04-02 (which requires only `flutter analyze` + grep boundary for the real isolate path).

## Deviations from legacy specs

- **Worker file named `tts_worker_main.dart`** (not `tts_worker.dart` per legacy 04-04). Matches the user's kickoff prompt naming; `ttsWorkerMain` is the top-level entry symbol.
- **`TtsClient.events` returns a `TtsEventStream` wrapper** (not raw `Stream<TtsEvent>`). Reason: Dart `Stream` has no built-in `whereType<T>()` method, so the wrapper exposes `whereType<S extends TtsEvent>()` and `listen(...)` as thin forwarders over `_events.stream`. Alternative (use `package:async` or `.where().cast()`) was judged more intrusive than a 20-line wrapper.
- **`SherpaTtsEngine` stub landed in Task 6**, real adapter in Task 7. Needed so `tts_worker_main.dart` compiles before the real adapter exists. Stub throws `UnimplementedError`; never instantiated in tests (in-process mode uses `FakeTtsEngine`).
- **`ttsCacheProvider` is a sync `@Riverpod` throwing `UnimplementedError`; `ttsCacheAsyncProvider` is the async initializer.** Production `main.dart` wiring (await async future, override sync provider) deferred to Wave 3 queue consumer. Tests override the sync provider directly.
- **`BooksCompanion.insert` uses `importDate:`** (not `importedAt:` as the plan said); there is no `AppDatabase.forTesting` factory, the task used `AppDatabase(NativeDatabase.memory())` to match existing DB test pattern.

## Test footprint

- Unit/widget/integration suite: **827 tests, all passed**.
- New tests this wave:
  - `test/features/tts/isolate/tts_cache_test.dart` — 6 tests
  - `test/features/tts/isolate/tts_client_test.dart` — 7 tests
  - `test/features/library/delete_book_wipes_cache_test.dart` — 1 test
  - `test/core/playback_state_test.dart` — 10 tests
  - `test/architecture/feature_boundary_test.dart` — 3 tests
  - `test/architecture/no_direct_network_test.dart` — 3 tests
  - **Total new: 30 tests**
- `flutter analyze`: 9 pre-existing issues (3 warnings, 6 infos). Zero new. (An unused import of `tts_cache.dart` in `library_provider.dart` introduced by task-8 was removed during Wave 2 sign-off before the commit.)

## Open items for Wave 3

- **`main.dart` TtsCache override**: Wave 3 queue consumer must `await ref.read(ttsCacheAsyncProvider.future)` at app startup and call `ProviderContainer.overrideWithValue` on `ttsCacheProvider`. Until that lands, `ref.read(ttsCacheProvider)` throws — `LibraryNotifier.deleteBook`'s try/catch swallows the exception so the library delete path still works without cache wipe in production (worst case: orphan cache on disk, non-fatal).
- **Real-isolate TtsClient exercise**: Only in-process path is unit-tested. Real `Isolate.spawn + SherpaTtsEngine` runs against sherpa_onnx, i.e. device-only. Wave 6 device UAT covers this per 04-VALIDATION.md row 04-04-02.
- **Cancel set never drains on success**: `_pendingDiscard` is cleared per-idx only when a `SentenceReady` arrives; if a Cancel(N) is sent and no synth for N is ever emitted, the set retains an orphaned entry. Bounded growth is O(Cancel-without-synth) — not a memory concern for reasonable usage, but worth noting for Wave 3 queue review.

## Unblocks

Wave 3 (`04-06-PLAN.md` — queue + just_audio player). Wave 3 must bootstrap `ttsCacheProvider` in `main.dart` before reading it from the queue.
