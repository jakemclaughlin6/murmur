# Phase 4 Wave 3 — Summary

**Date:** 2026-04-17
**Outcome:** PASS

## What landed

Commits since Wave 2 sign-off (`e4019c8`), oldest-first:

- `638bd0b` — plan: consolidate 04-06 into checkbox PLAN.md; flip WAVES.md → PLANNED
- `8e30c71` — task-1: bootstrap ttsCacheProvider override in main.dart
- `8705825` — task-2: AudioPlayerHandle + JustAudioPlayerHandle (TTS-08)
- `a9c41e7` — task-3: FakeAudioPlayerHandle + wrapper unit tests
- `f449358` — task-4: TtsQueue scaffold + setChapter pre-synth (D-11)
- `68765e7` — task-5: TtsQueue.play + advance-on-completion + pre-synth +1
- `4743e6e` — task-6: TtsQueue skipForward/skipBackward + ring buffer
- `c0d5a58` — task-7: TtsQueue setVoice/setSpeed/pause/resume (TTS-09)
- `4ce42ae` — task-8: ttsWorkerProvider family (D-10 spawn/dispose)
- `53da876` — task-9: audioPlayerProvider + ttsQueueProvider driver
- `ee6bfed` — fixup: serialize soft-cap work + queue-dispose in queue tests

## Queue state machine (at wave close)

```
setChapter(sentences)          → synth(0)                   # D-11 pre-synth

play(idx)  cache hit           → setFile+play; synth(idx+1)
           cache miss          → synth(idx) → Ready → setFile+play; synth(idx+1)

player.completed               → idx+1; _playIdx(idx+1) (cache hit expected); synth(idx+2)

skipForward  inflight          → client.send(Cancel(idx))            # D-12 soft cancel
                                 _awaiting[idx].completeError(_SkipCancelled)
                                 advance to idx+1; _playIdx; synth(idx+2)

skipBackward in ring (last 3)  → setFile cached wav (no new synth)
             outside ring      → _playIdx cache-miss path → synth + await

setVoice(id)                   → currentVoiceSid = sid; client.send(SetVoice)
                                 wipe {bookId}/{chapterIdx}/; _awaiting.clear
                                 _recent.clear; synth(currentIdx)

setSpeed(x)                    → player.setSpeed(x)                  # NEVER to worker
pause/resume                   → player.pause() / player.play()
dispose                        → cancel subs; drain _pendingCapWork; pause; client.dispose()
```

## Deviations from legacy spec (04-06-PLAN.md)

- **No `kokoroPathsProvider`**: the legacy spec proposed a provider that resolves Kokoro asset paths for `TtsClient.spawn`. But the Wave 2 `TtsClient.spawn` signature takes only `{cache, initialVoiceSid, engineFactory?}` — the worker isolate resolves its own paths via `getApplicationSupportDirectory()` + `KokoroPaths.forSupportDir`. Dropping the provider keeps the wiring minimal and matches what actually shipped in Wave 2.
- **`playbackStateProvider` is actually `playbackStateProvider`** (not `playbackStateNotifierProvider`): `riverpod_generator` strips the `Notifier` suffix when generating the provider for `@Riverpod class PlaybackStateNotifier`. Verified via `lib/core/playback_state.g.dart:15`.
- **`select` requires `flutter_riverpod` import**: `riverpod_annotation` does not re-export the `ProviderListenableSelect` extension. `tts_queue_provider.dart` adds `import 'package:flutter_riverpod/flutter_riverpod.dart'` alongside the annotation import.
- **`_SkipCancelled` sentinel in `skipForward`**: the legacy spec said "let inflight synth complete but discard"; we additionally propagate a cancel error to any dangling awaiter on `_awaiting[idx]` so `await queue.play(...)` doesn't hang when a skip cancels the very synth being awaited.
- **Task 5 made `_currentVoiceSid` `final`** (to silence an initial "not assigned" lint); Task 7 un-`final`ed it when adding `setVoice`. Self-correcting within the wave.
- **Soft-cap serialization (fixup commit)**: `_onSentenceReady` used `unawaited(cache.enforceSoftCap(...))`. Under full-suite parallelism, the future could resolve after a test's tmp dir was already deleted, throwing `PathNotFoundException` after the test had passed. The fix chains every soft-cap call through a single `_pendingCapWork` Future which `dispose()` awaits — production loses nothing (the work still runs in the background between sentences), and tests become deterministic.

## In-process test mode (carried from Wave 2)

All queue + driver tests use `TtsClient.spawn(engineFactory: () => FakeTtsEngine(...))`, keeping the real sherpa_onnx path (and all native FFI) out of CI. Architecture tests still enforce that `package:sherpa_onnx` is imported only by `sherpa_tts_engine.dart` + `spike_page.dart`. Real-isolate exercise of the queue is deferred to Wave 6 device UAT per `04-VALIDATION.md` row 04-04-02.

## Test footprint

- Unit/widget/integration suite: **843 tests, all passed.**
- New tests this wave:
  - `test/features/tts/isolate/tts_cache_bootstrap_test.dart` — 2 tests
  - `test/features/tts/queue/just_audio_player_test.dart` — 3 tests
  - `test/features/tts/queue/tts_queue_test.dart` — 8 tests
  - `test/features/tts/providers/tts_worker_provider_test.dart` — 1 test
  - `test/features/tts/providers/tts_queue_provider_test.dart` — 2 tests
  - **Total new: 16 tests.**
- `flutter analyze`: 9 pre-existing issues (3 warnings, 6 infos). Zero new.
- Grep guards (zero hits): `StreamAudioSource`, `ConcatenatingAudioSource` (outside the rejection comment), `length_scale` outside `sherpa_tts_engine.dart`.

## Open items for Wave 4

- **Reader-side `queue.setChapter(...)` wiring**: Phase 5 / Wave 4 must call `ref.read(ttsQueueProvider.future)` on chapter load and pass the parsed `List<Sentence>` into `queue.setChapter(bookId, chapterIdx, sentences)`. The driver doesn't do this because sentence content is reader-owned.
- **Voice picker / playback bar UI** (04-07 spec): will mutate `playbackStateProvider.setVoice/setSpeed/setPlaying`; the driver already forwards those to the queue. No queue changes expected in Wave 4.
- **`dispose()` cancels pre-synth inflight**: currently `setVoice` clears `_awaiting` without completing pending completers. If Wave 4 UI starts awaiting the result of `play()` concurrently with voice changes, consider extending the `_SkipCancelled` pattern to `setVoice` and `setChapter` invalidations for consistency.
- **Real `just_audio` device test** (tagged `device`): the legacy spec called for one tagged test exercising the real `AudioPlayer` with a tiny WAV. Deferred to Wave 6 device UAT alongside the real-isolate coverage.

## Unblocks

Wave 4 (`04-07-PLAN.md` — voice picker + playback bar + per-book overrides). Wave 4 consumes: `ttsQueueProvider` (for the reader's setChapter wiring), `playbackStateProvider` (all UI mutations), `ModelManifest.voiceCatalog` (picker entries).
