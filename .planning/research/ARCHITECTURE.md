---
title: Architecture Research — murmur
domain: Flutter ebook reader with on-device neural TTS
researched: 2026-04-11
confidence: HIGH
---

# Architecture Research

**Domain:** Flutter ebook reader with on-device neural TTS (Sherpa-ONNX + Kokoro-82M), Android + iOS, phones + tablets
**Researched:** 2026-04-11
**Confidence:** HIGH on isolate + pipeline boundaries (primary-source evidence from `k2-fsa/sherpa-onnx/flutter-examples/tts/lib/isolate_tts.dart` and `flutter/sherpa_onnx/lib/src/tts.dart`). MEDIUM on StreamAudioSource PCM handling (verified API is experimental; fallback pattern recommended).

This document answers seven structural questions for `murmur`, refines the `lib/` tree proposed in `murmur_app_spec.md §4`, and draws the component boundaries and data flow that the roadmap will phase.

---

## TL;DR

1. **Feature-first is correct, with a meaningful `shared/` layer.** The spec's three-feature split (`library`, `reader`, `tts`) stands. Three refinements to the spec's tree are explicit below.
2. **The `Sentence` model lives in `shared/`, not `features/reader/`.** This is the single most important structural call in the whole project — it is what lets reader and TTS coordinate without a circular dependency.
3. **Sherpa-ONNX synthesis runs on a long-lived worker isolate**, spawned once, kept alive for the session. Verified against the official Flutter example (`isolate_tts.dart`). This is non-negotiable: the Dart `generate*` methods are synchronous and block the caller.
4. **Reader ↔ TTS coordinate through one shared Riverpod provider** — `playbackStateProvider` — exposing `currentSentenceId`, `isPlaying`, `currentChapter`. TTS writes, reader watches. No event bus, no callbacks, no direct dependency either direction.
5. **PCM → playback glue is pragmatic, not clever.** Synthesize a full sentence → wrap Float32 samples with a 44-byte WAV header → write temp file → hand to `just_audio` via `AudioSource.file`. Pre-buffer the next sentence while the current plays. Sub-sentence streaming via `generateWithCallback` is a Phase 7 optimization, not a Phase 4 requirement.
6. **One Drift database in `shared/db/`; per-feature repositories wrap DAOs.** Do not split the database class across features — Drift generates one `.g.dart` per database.
7. **Models: bundle `voices.bin` (~3MB) + `tokens.txt` (~1KB); download `kokoro-v0_19.int8.onnx` (~82MB) on first launch** to app documents directory, with integrity check + resume + re-download flow.

---

## 1. Standard Architecture

### System Overview

```
┌───────────────────────────────────────────────────────────────────┐
│                          UI (Flutter widgets)                      │
│  ┌───────────────┐   ┌──────────────┐   ┌──────────────────────┐  │
│  │ LibraryScreen │   │ ReaderScreen │   │ PlaybackBar + Sheet  │  │
│  │               │   │ ChapterPanel │   │ VoicePicker          │  │
│  │               │   │ RichText     │   │ SpeedPicker          │  │
│  └───────┬───────┘   └──────┬───────┘   └──────────┬───────────┘  │
├──────────┼──────────────────┼──────────────────────┼──────────────┤
│          │  Riverpod providers (feature-scoped + shared)          │
│  ┌───────┴───────┐   ┌──────┴───────┐    ┌─────────┴───────────┐  │
│  │ libraryProv.  │   │ readerProv.  │    │ ttsControllerProv.  │  │
│  │ importCtrl    │   │ readerCtrl   │    │ ttsQueueCtrl        │  │
│  │               │   │              │    │ voicesProv.         │  │
│  └───────┬───────┘   └──────┬───────┘    └─────────┬───────────┘  │
│          │                  │                      │              │
│          │        ┌─────────┴──────────┐           │              │
│          │        │ playbackStateProv. │◄──────────┘              │
│          │        │ (shared, one-way   │                          │
│          │        │  TTS writes,       │                          │
│          │        │  reader watches)   │                          │
│          │        └─────────┬──────────┘                          │
├──────────┼──────────────────┼─────────────────────────────────────┤
│                         Services + repositories                   │
│  ┌───────┴───────┐   ┌──────┴──────────┐   ┌───────────────────┐  │
│  │ BookRepo      │   │ ChapterRepo     │   │ TtsService        │  │
│  │ CoverCache    │   │ ProgressRepo    │   │ ModelManager      │  │
│  │ EpubImporter  │   │ BookmarkRepo    │   │ AudioController   │  │
│  └───────┬───────┘   └──────┬──────────┘   └──────────┬────────┘  │
│          │                  │                          │         │
├──────────┼──────────────────┼──────────────────────────┼─────────┤
│                     Shared infrastructure                         │
│  ┌───────┴──────────────────┴──────┐  ┌─────────────────┴──────┐  │
│  │ Drift DB (books, chapters,      │  │ Sentence model +       │  │
│  │ reading_progress, bookmarks,    │  │ sentence splitter      │  │
│  │ bookmarks, settings)            │  │ (pure Dart, tested)    │  │
│  └─────────────────────────────────┘  └────────────────────────┘  │
│  ┌───────────────────────────┐   ┌───────────────────────────┐    │
│  │ EpubParser (epub_view)    │   │ Theme + typography tokens │    │
│  └───────────────────────────┘   └───────────────────────────┘    │
├───────────────────────────────────────────────────────────────────┤
│                    Platform + native boundaries                    │
│  ┌──────────────────────────┐   ┌──────────────────────────────┐  │
│  │ TTS Worker Isolate       │   │ Background audio isolate     │  │
│  │ (sherpa_onnx OfflineTts, │   │ (audio_service MediaHandler, │  │
│  │  loaded once, PCM out)   │   │  just_audio player)          │  │
│  └──────────────────────────┘   └──────────────────────────────┘  │
│  ┌──────────────────────────┐   ┌──────────────────────────────┐  │
│  │ Filesystem               │   │ Network (ONE call, ever:     │  │
│  │ (EPUBs, covers, PCM/WAV  │   │  first-launch Kokoro model   │  │
│  │  temp, Kokoro model)     │   │  download)                   │  │
│  └──────────────────────────┘   └──────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Owns | Implementation |
|-----------|------|----------------|
| `LibraryScreen` / `ReaderScreen` / `PlaybackBar` | Widgets, user input, visual state | `ConsumerWidget`, watches Riverpod providers |
| `libraryProvider` (feature) | Library list, sort, search, import progress | `AsyncNotifier<LibraryState>` |
| `readerProvider` (feature) | Current chapter, scroll position, font/theme prefs, rendered `List<Sentence>` per chapter | `AsyncNotifier<ReaderState>` |
| `ttsControllerProvider` (feature) | Play/pause intent, voice, speed, queue cursor | `Notifier<TtsUiState>` |
| `playbackStateProvider` (**shared**) | `currentSentenceId`, `currentChapterId`, `isPlaying`, `isBuffering` | `Notifier<PlaybackState>` — the single coordination point |
| `BookRepository` | CRUD on books table, import pipeline, cover file I/O | Feature-owned (library/data) |
| `ChapterRepository` | Chapter read/parse/cache, sentence-split pipeline | Feature-owned (reader/data) |
| `TtsService` | Owns the worker isolate, send text → receive PCM, voice swap | Feature-owned (tts/data) |
| `AudioController` | `audio_service` handler, `just_audio` player, PCM → WAV → file → play | Feature-owned (tts/data) |
| `ModelManager` | Model presence check, download, storage info, re-download | Feature-owned (tts/data) |
| `MurmurDatabase` (Drift) | Single database class with all tables + DAOs | **Shared** (`shared/db/`) |
| `Sentence` model | Stable identity (`chapterId + index`), text, style runs, offset within chapter | **Shared** (`shared/domain/`) |
| `SentenceSplitter` | Pure Dart text → `List<Sentence>`; handles abbreviations, decimals, quotes | **Shared** (`shared/utils/`) |
| `EpubParser` | Wraps `epub_view` + cleanup to yield normalized chapter text | **Shared** (`shared/epub/`) |

---

## 2. Recommended Project Structure (`lib/`)

This is a refinement of `murmur_app_spec.md §4`. Three explicit changes are flagged **CHANGE** below.

```
lib/
├── main.dart
├── app/
│   ├── router.dart                  # go_router routes
│   ├── theme.dart                   # ThemeData, reader theme tokens
│   └── app_bootstrap.dart           # ProviderScope + audio_service init
│
├── shared/                          # no imports from features/
│   ├── db/
│   │   ├── database.dart            # @DriftDatabase class, all tables here
│   │   ├── tables/
│   │   │   ├── books.dart
│   │   │   ├── chapters.dart
│   │   │   ├── reading_progress.dart
│   │   │   ├── bookmarks.dart
│   │   │   └── settings.dart
│   │   └── daos/
│   │       ├── books_dao.dart
│   │       ├── progress_dao.dart
│   │       └── bookmarks_dao.dart
│   ├── domain/                      # CHANGE vs spec: Sentence lives HERE, not reader/domain/
│   │   ├── sentence.dart            # Sentence { id, chapterId, index, text, styleRuns, offset }
│   │   ├── chapter.dart             # Chapter { id, bookId, title, order, sentences }
│   │   └── style_run.dart           # StyleRun for bold/italic/size spans
│   ├── epub/
│   │   ├── epub_parser.dart         # epub_view wrapper → normalized text
│   │   └── html_normalizer.dart     # strip HTML cruft while preserving style runs
│   ├── utils/
│   │   ├── sentence_splitter.dart   # CHANGE vs spec: returns List<Sentence>, not List<String>
│   │   ├── text_cleaner.dart        # abbreviation/decimal/quote handling
│   │   └── wav_writer.dart          # Float32List + sampleRate → WAV bytes
│   ├── providers/                   # CHANGE vs spec: new folder not in the spec's tree
│   │   └── playback_state.dart      # the one cross-feature Riverpod provider
│   └── widgets/
│       ├── loading.dart
│       └── error_view.dart
│
├── features/
│   ├── library/
│   │   ├── data/
│   │   │   ├── book_repository.dart
│   │   │   ├── cover_cache.dart
│   │   │   └── epub_importer.dart
│   │   ├── domain/
│   │   │   ├── book.dart
│   │   │   └── import_state.dart
│   │   ├── providers/
│   │   │   ├── library_provider.dart
│   │   │   └── import_controller.dart
│   │   └── ui/
│   │       ├── library_screen.dart
│   │       ├── book_card.dart
│   │       ├── import_button.dart
│   │       └── empty_state.dart
│   │
│   ├── reader/
│   │   ├── data/
│   │   │   ├── chapter_repository.dart
│   │   │   └── progress_repository.dart
│   │   ├── domain/
│   │   │   ├── reader_state.dart    # NOT Sentence — that's shared
│   │   │   ├── reader_prefs.dart    # font, size, theme
│   │   │   └── bookmark.dart
│   │   ├── providers/
│   │   │   ├── reader_provider.dart
│   │   │   ├── chapter_provider.dart
│   │   │   └── bookmarks_provider.dart
│   │   └── ui/
│   │       ├── reader_screen.dart
│   │       ├── chapter_page_view.dart
│   │       ├── sentence_rich_text.dart  # THE key widget — see §3
│   │       ├── chapter_panel.dart       # tablet sidebar / phone drawer
│   │       └── reader_controls.dart
│   │
│   └── tts/
│       ├── data/
│       │   ├── tts_service.dart          # owns the worker isolate
│       │   ├── tts_isolate.dart          # isolate entry point (runs sherpa_onnx)
│       │   ├── tts_messages.dart         # SendPort request/response types
│       │   ├── model_manager.dart        # download, presence check, re-download
│       │   ├── audio_controller.dart     # audio_service + just_audio glue
│       │   └── kokoro_voices.dart        # SOURCE-OF-TRUTH list of ~10 voices
│       ├── domain/
│       │   ├── tts_state.dart
│       │   ├── voice.dart
│       │   └── sentence_queue.dart       # cursor + pre-buffer slot, uses shared Sentence
│       ├── providers/
│       │   ├── tts_controller_provider.dart
│       │   ├── voices_provider.dart
│       │   └── model_status_provider.dart
│       └── ui/
│           ├── playback_bar.dart
│           ├── voice_picker.dart
│           ├── speed_picker.dart
│           └── sleep_timer_sheet.dart
│
└── assets/                          # declared in pubspec, not Dart source
    └── models/kokoro/
        ├── voices.bin               # bundled (~3MB)
        └── tokens.txt               # bundled (~1KB)
        # kokoro-v0_19.int8.onnx lives in app documents after first-launch download
```

### Refinements explicitly disagreeing with the spec's §4 tree

1. **`Sentence` model moves from `features/reader/domain/` to `shared/domain/`.** The spec's tree tucks domain inside reader, which would force the TTS feature to import from the reader feature (or duplicate the model), creating exactly the circular dependency this document must prevent. `Sentence` is the coordination currency of the whole app — it belongs in shared.
2. **`SentenceSplitter` returns `List<Sentence>`, not `List<String>`.** The spec puts the splitter in `shared/utils/` (correct) but its natural output is raw strings. Tying it to the `Sentence` type at the splitter boundary means downstream code (reader, TTS) never sees a bare string it has to re-key. Sentence identity (`chapterId + index`) is assigned at splitter output.
3. **Add `shared/providers/playback_state.dart`.** The spec doesn't name where the cross-feature provider lives. It is not optional — without it, reader and TTS either depend on each other or communicate through an event bus (worse). One shared provider, owned by neither feature, is the right boundary.

### Structure Rationale

- **Feature-first beats layer-first for this app** because the three features are naturally independent: library can be developed, tested, and reasoned about with no knowledge of TTS; the TTS feature knows nothing about EPUBs or the library grid. Layer-first (all DAOs together, all widgets together, etc.) would collapse that locality.
- **`shared/` holds only things that ≥2 features use OR that are infrastructural in nature.** `Sentence`, the Drift database, the EPUB parser, theme tokens, and the playback coordination provider qualify. Reader-specific types (`ReaderPrefs`, `Bookmark`) do not.
- **Providers folder per feature keeps Riverpod graph readable.** Co-locating providers with their owning feature makes "who owns this state?" obvious. The one shared provider lives in `shared/providers/` precisely to signal "this is not owned by any single feature."

---

## 3. The Sentence-Span Pipeline (highest-risk section)

This is the load-bearing pipeline in `murmur`. Phase 3 of the spec calls it "a v1 architectural commitment" and it is the thing most likely to get wrong and have to rewrite.

### The pipeline, end-to-end

```
┌───────────────────────────────────────────────────────────────────┐
│ Stage 0: Book import (library feature)                            │
│   file picker → epub bytes → parse metadata/chapters → Drift      │
│   (ONE row per book, ONE row per chapter, HTML body stored)       │
└────────────────────────────────┬──────────────────────────────────┘
                                 │
┌────────────────────────────────▼──────────────────────────────────┐
│ Stage 1: Chapter load (reader feature, lazy, per chapter)         │
│   ChapterRepo.loadChapter(chapterId)                              │
│     → reads raw chapter HTML from Drift                           │
│     → EpubParser + HtmlNormalizer (shared/epub/)                  │
│       strips HTML markup but preserves style runs                 │
│       (bold ranges, italic ranges, heading boundaries)            │
│     → yields: NormalizedChapter { text: String, runs: List<Run> } │
└────────────────────────────────┬──────────────────────────────────┘
                                 │
┌────────────────────────────────▼──────────────────────────────────┐
│ Stage 2: Sentence splitting (shared/utils/sentence_splitter.dart) │
│   SentenceSplitter.split(NormalizedChapter, chapterId)            │
│     → handles: abbreviations, decimals, ellipses, quoted dialog   │
│     → assigns stable IDs: Sentence(chapterId, index: 0..N)        │
│     → carries style runs onto each Sentence (range → within)      │
│     → returns: List<Sentence>                                     │
│                                                                   │
│   Result CACHED in memory per chapter (LRU or current-only)       │
│   Never persisted — splitter is pure and fast, re-run on demand   │
└────────────────────────────────┬──────────────────────────────────┘
                                 │
                      ┌──────────┴──────────┐
                      │                     │
┌─────────────────────▼──────┐   ┌─────────▼────────────────────┐
│ Stage 3a: Reader rendering │   │ Stage 3b: TTS consumption    │
│ (features/reader/ui/)      │   │ (features/tts/data/)         │
│                            │   │                              │
│ SentenceRichText widget:   │   │ TtsQueue:                    │
│   List<Sentence>           │   │   List<Sentence>             │
│     → RichText(TextSpan[]) │   │     → cursor at N            │
│       ONE TextSpan per     │   │     → send N text to isolate │
│       sentence, keyed by   │   │     → pre-buffer N+1         │
│       sentence.id          │   │     → on N done: advance,    │
│       style runs applied   │   │       write currentSentenceId│
│       inside the span      │   │       to playbackState       │
│                            │   │                              │
│ Watches:                   │   │                              │
│   playbackState →          │   │                              │
│     highlight active       │   │                              │
│     sentence.id            │   │                              │
│                            │   │                              │
│ ScrollController →         │   │                              │
│   keep active sentence     │   │                              │
│   in viewport              │   │                              │
└────────────────────────────┘   └──────────────────────────────┘
```

### Why this boundary works

- **The reader feature renders sentences. The TTS feature synthesizes sentences. Neither one owns the `Sentence` class.** Both import it from `shared/domain/sentence.dart`. Reader never imports TTS; TTS never imports reader. There is no circular dependency.
- **Coordination runs through `playbackStateProvider` only.** TTS writes `currentSentenceId` when a sentence's audio starts playing. Reader watches `currentSentenceId` and rebuilds its `RichText` / adjusts its `ScrollController`. One-way data flow.
- **The splitter is pure and fast enough to run on the UI isolate** for a single chapter (~a few hundred sentences), so no isolate hop is needed for Stage 2. If profiling later shows a jank on chapter load, wrap `SentenceSplitter.split` in `compute()` — this is a one-line change because it's a pure function.

### Sentence identity

```dart
// shared/domain/sentence.dart
class Sentence {
  final String id;           // synthesized: "$chapterId:$index"
  final String chapterId;
  final int index;           // 0-based within chapter
  final String text;         // the text to render AND synthesize
  final List<StyleRun> styleRuns;  // bold/italic/heading ranges within text
  final int chapterOffset;   // character offset in full chapter text (for scroll math)
  const Sentence(...);
}
```

Both features reference sentences by `id`. The reader's `TextSpan` is keyed by `sentence.id`. The TTS queue's cursor is a `sentence.id`. `playbackStateProvider.currentSentenceId` is a nullable `String?`. This is the coordination currency.

### Anti-patterns rejected

- **Storing sentences in Drift.** Tempting for "resume to sentence" precision, but the splitter is deterministic: re-run it on chapter load and look up `sentence.id` instead. Drift stores `currentChapterId + currentSentenceIndex` on `reading_progress`, nothing more.
- **Sentence splitting inside the TTS isolate.** The splitter is pure and needs no native code. Keeping it on the UI isolate means the reader and TTS see the *same* `List<Sentence>` object (or an identical one), which is critical for consistency.
- **Having the reader call into the TTS feature directly to "start playing from this tap."** The tap writes an intent (`ttsControllerProvider.startFrom(sentenceId)`) — it does not directly touch the isolate or the audio player. All cross-feature calls go through providers.

---

## 4. The TTS Isolate Boundary (second-highest-risk section)

**Primary-source evidence.** This section is HIGH confidence because it is grounded in the official Flutter example — `k2-fsa/sherpa-onnx/flutter-examples/tts/lib/isolate_tts.dart` and the `OfflineTts` class in `k2-fsa/sherpa-onnx/flutter/sherpa_onnx/lib/src/tts.dart`.

### The critical fact about the sherpa_onnx Dart API

All three generation methods — `generate()`, `generateWithCallback()`, `generateWithConfig()` — are **synchronous and blocking**. Calling them on the UI isolate will stall the frame pipeline for the duration of synthesis (hundreds of milliseconds to a couple of seconds per sentence). This is not a choice. The UI isolate cannot host the TTS engine.

### The pattern

```
┌──────────────────────────┐                ┌──────────────────────────┐
│   UI isolate             │                │   TTS worker isolate     │
│                          │                │   (spawned ONCE)         │
│                          │                │                          │
│   TtsService.init()      │ ─spawn()────▶ │   _ttsIsolateEntry(port) │
│   receives isolate       │                │     load OfflineTts      │
│   SendPort               │ ◀────SendPort──│     (model load ~1-2s)   │
│                          │                │     send ready           │
│                          │                │                          │
│   TtsService             │                │   listen on receivePort  │
│   .synthesize(sentence)  │ ─TtsRequest──▶│                          │
│     waits Future         │                │   for each request:      │
│                          │                │     offlineTts           │
│                          │                │       .generateWithConfig│
│                          │                │       (text, voice,      │
│                          │                │        speed)            │
│                          │                │       → GeneratedAudio   │
│                          │                │         (Float32 samples │
│                          │                │          + sampleRate)   │
│                          │                │                          │
│                          │ ◀──TtsResult──│     send result           │
│   resolves Future        │                │                          │
│   → Uint8List wav bytes  │                │                          │
│   → just_audio.play(file)│                │                          │
└──────────────────────────┘                └──────────────────────────┘
```

### Design decisions

- **Long-lived isolate, not `compute()` per call.** The sherpa_onnx model load costs ~1–2 seconds and allocates significant memory. `compute()` would tear the model down and rebuild it for every sentence — unusable. The isolate is spawned once at app start (after model presence check) and torn down only on dispose.
- **Isolate messages are simple value types.** `TtsRequest { id, text, voiceId, speed }`, `TtsResult { id, Float32List samples, int sampleRate }`, `TtsError { id, message }`. No `SendPort` round-tripping of objects.
- **Voice swap = cheap, speed swap = zero-cost.** Kokoro's voice is a speaker ID parameter, not a model reload — changing voices in the UI just sends a different `voiceId` on the next request. Speed is a `length_scale` parameter on the request. Neither triggers a re-init.
- **Model load happens after `ModelManager` confirms the file is on disk.** The isolate entry point receives the model path as its first message. If the model isn't present, the TTS feature shows "download model" UI and never spawns the isolate.
- **Error boundary.** An exception in the isolate is caught at the isolate entry and sent back as a `TtsError`; the calling Future rejects. `TtsService` surfaces a user-visible error via the TTS controller provider. The isolate stays alive.

### What the isolate does NOT do

- **Does not split sentences.** That happens on the UI isolate in shared/utils.
- **Does not own a queue.** The queue (`features/tts/domain/sentence_queue.dart`) lives on the UI side and issues requests serially (plus a pre-buffer look-ahead). The isolate is request/response.
- **Does not play audio.** It returns samples. Playback is the UI side's job, via `audio_service` + `just_audio`.
- **Does not download the model.** `ModelManager` on the UI side handles that.

### Streaming (`generateWithCallback`) — Phase 7, not Phase 4

The Dart API exposes `generateWithCallback(text, sid, speed, int Function(Float32List samples))` which delivers partial chunks during synthesis. This could reduce sentence-start latency further. **However:**

- The method is still synchronous on the isolate side — the callback runs inline during generation.
- Routing partial chunks across the isolate boundary to a streaming `just_audio` source adds significant complexity.
- Pre-buffering the *next* sentence while the current plays already hides per-sentence latency for all but the very first sentence.
- The <300ms latency target in PROJECT.md is for first-sentence start. That is achievable with one-shot `generateWithConfig` on a Kokoro int8 model running on a mid-range CPU — the Kokoro-82M benchmark consistently lands under 300ms for short sentences.

**Recommendation:** Use `generateWithConfig` (one-shot) for Phase 4. Keep `generateWithCallback` as a Phase 7 optimization if first-sentence latency empirically misses the target.

---

## 5. Riverpod Provider Organization (hybrid)

### Layout

- **Per-feature providers** in `features/<feature>/providers/`. Each feature owns its own state and does not expose its internal providers to other features.
- **One shared provider** in `shared/providers/playback_state.dart`. This is the only cross-feature provider.

### Why hybrid beats pure-feature

If every provider were feature-scoped, there would be no legal place for `playbackStateProvider` — it would have to live inside `reader` or `tts`, creating the circular dependency this document is fighting. The hybrid approach gives "cross-feature coordination state" a named home.

### Why hybrid beats pure-global

A global provider bag encourages sloppy coupling: any UI widget can watch any state. With feature-scoped providers plus one deliberate shared provider, the "global" surface is limited to exactly the state that is genuinely cross-feature: `currentSentenceId`, `currentChapterId`, `isPlaying`, `isBuffering`.

### The shared provider

```dart
// shared/providers/playback_state.dart
class PlaybackState {
  final String? currentSentenceId;  // null when not playing
  final String? currentChapterId;
  final bool isPlaying;
  final bool isBuffering;
  const PlaybackState(...);
}

@Riverpod(keepAlive: true)
class PlaybackStateNotifier extends _$PlaybackStateNotifier {
  @override
  PlaybackState build() => const PlaybackState(...);

  void setCurrent({required String sentenceId, required String chapterId}) { ... }
  void setPlaying(bool v) { ... }
  void setBuffering(bool v) { ... }
}
```

**Write side:** only `TtsService` / `AudioController` writes to this provider. TTS is the source of truth for what is currently playing.
**Read side:** reader's `SentenceRichText` widget watches `currentSentenceId` to apply highlight; reader's `ScrollController` watches it to autoscroll; `PlaybackBar` watches `isPlaying` / `isBuffering` to render its state. Library could watch `currentChapterId` if we wanted "now playing" indicators on the library grid.

### What stays per-feature

- `libraryProvider` (the book list)
- `importControllerProvider` (import progress + errors)
- `readerProvider` (current chapter, pagination, prefs)
- `chapterProvider(chapterId)` (loaded sentences, family'd)
- `bookmarksProvider`
- `ttsControllerProvider` (user intent: play/pause, voice, speed)
- `voicesProvider` (the curated list)
- `modelStatusProvider` (download state)

### Direction of provider dependencies

```
playbackStateProvider (shared, leaf)
       ▲  written by                    ▲  watched by
       │                                │
   ttsControllerProvider ◄── consumes ── readerProvider
       │                                │
       │                                │
   tts/data/...                     reader/data/...
       │                                │
       ▼                                ▼
   shared/domain/sentence.dart     shared/domain/sentence.dart
   shared/db/database.dart          shared/db/database.dart
```

No feature imports another feature's providers. Coordination is always via shared types or the shared playback provider.

---

## 6. Drift Database Placement

### Decision: one database in `shared/db/`, per-feature repositories wrap DAOs

Drift generates one `.g.dart` file per `@DriftDatabase` class. Splitting that across features creates two bad options: either (a) multiple database classes with incompatible schemas and no cross-table queries, or (b) one database class "owned" by one feature that other features reach into, violating feature isolation. Neither works.

### The layout

```
shared/db/
├── database.dart        @DriftDatabase(tables: [...], daos: [...])
├── tables/
│   ├── books.dart
│   ├── chapters.dart
│   ├── reading_progress.dart
│   ├── bookmarks.dart
│   └── settings.dart
└── daos/
    ├── books_dao.dart
    ├── progress_dao.dart
    └── bookmarks_dao.dart
```

### How features access the database

Features never import `MurmurDatabase` directly from their UI code. They import DAOs via repositories in their own `data/` folder:

```
features/library/data/book_repository.dart
  ├─ depends on: BooksDao (from shared/db/daos/)
  └─ exposes: importBook(), listBooks(), deleteBook(), etc.

features/reader/data/chapter_repository.dart
  ├─ depends on: BooksDao + ChaptersDao + ProgressDao
  └─ exposes: loadChapter(), saveProgress(), resumePosition()
```

This gives each feature a clean API surface that hides Drift specifics, while the underlying storage remains a single coherent database. The DAO split in `shared/db/daos/` matches feature boundaries naturally, so in practice each feature "owns" one DAO even though they all live in shared.

### Drift provider

One `Provider<MurmurDatabase>` in `shared/providers/database.dart` (or inline in the bootstrap). Every repository takes the database from this provider.

---

## 7. PCM → Audio Playback Glue

This is the least glamorous and second-most-error-prone boundary. Keep it boring.

### The flow for one sentence

```
1. TtsQueue cursor points at sentence N.
2. TtsService.synthesize(sentence N) → sends request to isolate
3. Isolate returns (Float32List samples, int sampleRate)
4. shared/utils/wav_writer.dart wraps samples with a 44-byte WAV header
   → Uint8List wavBytes
5. Write wavBytes to a temp file in app cache dir:
   .../cache/tts/{sentenceId}.wav
   (deletable on app close; short-lived)
6. AudioController hands file path to just_audio:
   player.setAudioSource(AudioSource.file(path))
   player.play()
7. On player position >= sentence duration:
   playbackState.setCurrent(sentence N+1)
   TtsQueue.advance()
8. Meanwhile, step 2-5 has already run for sentence N+1 (pre-buffer)
```

### Why WAV files, not raw PCM streams

- `just_audio`'s `StreamAudioSource` is marked experimental and expects **encoded** audio with byte-range semantics (confirmed at pub.dev, `just_audio` issue #1028). Feeding it raw Float32 PCM chunks does not work without meaningful re-engineering.
- A 44-byte WAV header around Float32 samples makes the file a legal WAV that `just_audio` plays on both Android and iOS without ceremony.
- Sentence-sized WAV files are 1–5 seconds, ~100KB each. Temp-dir churn is negligible.
- Temp files auto-delete at app close (cache directory); explicit cleanup after advance is optional polish.

### Why this is fast enough

- Pre-buffering the next sentence while the current one plays means the user-perceived latency after the first sentence is zero (the next file is ready before the previous one ends).
- First-sentence latency is: (isolate send) + (model synthesis) + (WAV wrap + file write) + (just_audio prepare). On Kokoro int8 on a mid-range CPU, the synthesis is ~150–250ms for a typical sentence; everything else is single-digit milliseconds.
- The <300ms first-sentence target in PROJECT.md is achievable. If it is missed empirically, the optimizations in order are: (a) reduce first-sentence length by splitting on the first clause, (b) use `generateWithCallback` to start playing partial audio, (c) warm the isolate at app start (before the user hits play).

### `audio_service` responsibility

`audio_service` is the background audio glue. It owns:
- The `MediaHandler` that translates play/pause/seek/next/previous events from OS media controls, lock screen, and headphone buttons into calls on `AudioController`.
- The `MediaItem` metadata (book title, chapter, cover) that renders in the lock-screen widget.
- Keeping the Dart isolate alive when the app is backgrounded.

The `AudioController` implements `audio_service`'s `BaseAudioHandler`. It delegates the actual audio playback to `just_audio`, and it delegates the synthesis requests to `TtsService`. It is the only thing in the app that both speaks to the OS and touches the worker isolate indirectly.

### The audio_service lifecycle trap (Phase 4 risk)

`audio_service` spawns its own isolate on some platforms for background playback. That isolate and the TTS worker isolate are **different isolates**. Riverpod providers in the audio_service isolate are not the same instances as the ones in the UI isolate. This is a known `audio_service` gotcha.

**Mitigation:** The `AudioController` implementation runs in the UI isolate (the default `audio_service` configuration as of Flutter 3+). Avoid the "run audio handler in a separate isolate" option. All TTS state, all Riverpod state, and all `just_audio` calls happen in the same isolate — only the *sherpa_onnx synthesis* is on its dedicated worker isolate.

---

## 8. Model Asset Strategy

### What ships in the app bundle

- `assets/models/kokoro/voices.bin` (~3MB) — bundled
- `assets/models/kokoro/tokens.txt` (~1KB) — bundled

Both are declared in `pubspec.yaml` under `flutter: assets:`. These are small, never change, and must be available before any synthesis can happen.

### What downloads on first launch

- `kokoro-v0_19.int8.onnx` (~82MB) — downloaded on first launch to the app documents directory: `{appDocs}/models/kokoro/kokoro-v0_19.int8.onnx`.
- Download source: a GitHub release tag on `k2-fsa/sherpa-onnx` or a Hugging Face release URL. Hardcode a specific version — do not follow "latest" tags. Include a SHA-256 for integrity check.
- Download UI: a one-time modal at app start that explains "Download voice model (~82MB) to enable offline reading." Progress bar, cancel-to-skip, resume support.
- Re-download flow available in Settings for when the file is corrupt or the user wants to move storage.

### Why this split

- Bundling the 82MB model would inflate the app binary to ~100MB, which for a $3 paid app is a conversion killer and hits iOS cellular download limits.
- `voices.bin` and `tokens.txt` are required during TTS init and are small enough to bundle. Making them also downloadable would create a pointless failure mode ("voices download failed" before the user ever heard audio).
- Documents directory (`path_provider.getApplicationDocumentsDirectory()`) is the right place: it's backed up by default on iOS but excluded from iCloud in our config (because we don't need it synced), and it survives app updates.

### Model provider

`modelStatusProvider` exposes:

```dart
sealed class ModelStatus {
  const ModelStatus();
}
class ModelMissing extends ModelStatus { ... }
class ModelDownloading extends ModelStatus { final double progress; ... }
class ModelReady extends ModelStatus { final String path; ... }
class ModelCorrupt extends ModelStatus { ... }
```

The TTS feature refuses to spawn the worker isolate unless `ModelStatus` is `ModelReady`. The UI layer shows the appropriate onboarding/settings flow for other states.

### The privacy constraint

PROJECT.md: "Exactly one network call in the whole app — the one-time Kokoro model download on first launch." The download is the only `HttpClient` usage in the app. Add an invariant: nothing in `shared/` or `features/` imports `package:http` or `dart:io` HttpClient **except** `features/tts/data/model_manager.dart`. Enforce via a custom lint or just by code review — this is a hard architectural rule.

---

## 9. Architectural Patterns

### Pattern 1: Repository over DAO

**What:** Every feature's `data/` folder exposes repositories that hide the Drift DAOs from the rest of the feature.
**When:** Always. Riverpod providers depend on repositories, not DAOs.
**Trade-off:** Slight boilerplate; in exchange, tests can mock a repository without mocking Drift, and swapping the underlying store (if ever needed) changes one file.

### Pattern 2: Long-lived worker isolate

**What:** Spawn one isolate at feature init, keep it alive for the app session, communicate via SendPort.
**When:** Only for the TTS engine. Do not multiply isolates.
**Trade-off:** More complex than `compute()`, but mandatory because the model load cost is too high to amortize across per-call isolates.

### Pattern 3: Shared coordination provider

**What:** One Riverpod provider lives in `shared/`, written by exactly one feature, watched by others.
**When:** Only when two features must stay in sync about live state (the reader and the TTS feature must agree on "what's currently being spoken"). Do NOT use this pattern for more than one provider — proliferation of shared providers becomes a global state soup.

### Pattern 4: Pure function at the domain boundary

**What:** `SentenceSplitter.split(...)` is a pure function: input text → deterministic `List<Sentence>`. No state, no side effects, no IO.
**When:** For anything that is *logic*, not *integration*. The splitter, the WAV writer, and the HTML normalizer are all pure.
**Trade-off:** None. Pure functions are the easiest code in the codebase to test and the safest to call from anywhere — including isolates.

### Pattern 5: Sealed state classes for async UI

**What:** Model complex UI states as sealed class hierarchies (`ModelStatus`, `ImportState`, etc.) rather than multi-flag records.
**When:** For any state that has >2 meaningful variants with different associated data.
**Trade-off:** Slightly verbose, but the compiler enforces exhaustive handling in the UI — no "forgot to handle the loading case" bugs.

---

## 10. Data Flow (the two critical paths)

### Path A: Import → render

```
User taps Import
    ↓
file_picker returns URI
    ↓
EpubImporter reads bytes
    ↓
EpubParser extracts metadata + chapters (HTML stored in DB)
    ↓
CoverCache writes cover image file
    ↓
BookRepository.insertBook() → Drift books table
    ↓
libraryProvider rebuilds → LibraryScreen shows new card
    ↓
User taps book
    ↓
go_router → /reader/:bookId
    ↓
readerProvider loads Book, first chapter
    ↓
ChapterRepository.loadChapter(chapterId)
    ↓
HTML → NormalizedChapter → SentenceSplitter → List<Sentence>
    ↓
chapterProvider(chapterId) exposes List<Sentence>
    ↓
SentenceRichText builds RichText with TextSpan per sentence
    ↓
User reads
```

### Path B: Play → highlight → advance

```
User taps Play
    ↓
ttsControllerProvider.start(currentChapterId, sentenceIndex: 0)
    ↓
TtsService receives start intent
    ↓
TtsQueue.enqueue(List<Sentence> from chapterProvider)
    ↓
TtsQueue.synthesizeCurrent() → TtsService.synthesize(sentence 0)
    ↓
worker isolate: offlineTts.generateWithConfig(text, voice, speed)
    ↓
returns GeneratedAudio(Float32List samples, int sampleRate)
    ↓
UI isolate: WavWriter wraps → file write → AudioSource.file(path)
    ↓
just_audio player.setAudioSource + play
    ↓                                        │
    │                                        │ simultaneously
    │                                        ▼
    │                              TtsQueue.synthesizeNext()
    │                              (pre-buffer sentence 1)
    ▼
player onPlayerStart
    ↓
playbackStateProvider.setCurrent(sentence 0 id)
    ↓
reader's SentenceRichText rebuilds with sentence 0 highlighted
    ↓
reader's ScrollController scrolls sentence 0 into view
    ↓
player onPlaybackCompleted for sentence 0
    ↓
TtsQueue.advance() → cursor = sentence 1
    ↓
AudioController.play(pre-buffered sentence 1 file)
    ↓
playbackStateProvider.setCurrent(sentence 1 id)
    ↓ (loop)
```

---

## 11. Build Order Implications

The roadmap should phase work in a way that respects these dependencies. The shared layer comes first; features come second; cross-feature coordination comes last.

### Dependency graph (what must exist before what)

```
[Phase 1: Scaffold]
    ├── app/router, app/theme
    ├── shared/db/database.dart (empty tables)
    └── ProviderScope root
                │
                ▼
[Phase 2: Library feature]
    ├── shared/epub/epub_parser.dart
    ├── shared/db/tables/books.dart, daos/books_dao.dart
    ├── features/library/data/
    └── features/library/ui/
                │
                ▼
[Phase 3: Reader feature + THE sentence pipeline]
    ├── shared/domain/sentence.dart           ◄── STRUCTURAL LOAD-BEARING
    ├── shared/domain/chapter.dart
    ├── shared/domain/style_run.dart
    ├── shared/utils/sentence_splitter.dart   ◄── TEST IN ISOLATION FIRST
    ├── shared/epub/html_normalizer.dart
    ├── shared/db/tables/chapters.dart, reading_progress.dart
    ├── features/reader/data/chapter_repository.dart
    ├── features/reader/ui/sentence_rich_text.dart  ◄── TEST IN ISOLATION FIRST
    └── features/reader/ui/reader_screen.dart
                │
                ▼
[Phase 4: TTS feature (engine + playback)]
    ├── shared/utils/wav_writer.dart
    ├── shared/providers/playback_state.dart  ◄── THE coordination provider
    ├── features/tts/data/model_manager.dart
    ├── features/tts/data/tts_isolate.dart    ◄── SPIKE IN ISOLATION FIRST
    ├── features/tts/data/tts_service.dart
    ├── features/tts/data/audio_controller.dart
    ├── features/tts/data/kokoro_voices.dart
    ├── features/tts/domain/sentence_queue.dart
    └── features/tts/ui/playback_bar.dart
                │
                ▼
[Phase 5: Highlighting + auto-scroll]
    ├── features/reader/ui/sentence_rich_text.dart (add highlight)
    └── features/reader/providers/reader_provider.dart (watch playbackState)
      ^
      NOTE: This phase should be small — because Phase 3 built the right
      widget shape, Phase 5 adds a color and a scroll call, nothing more.
      If Phase 5 starts looking like a rewrite, Phase 3 was built wrong.
                │
                ▼
[Phase 6: Polish — bookmarks, sleep timer, onboarding]
    ├── shared/db/tables/bookmarks.dart
    └── features/reader/data/bookmarks_repository.dart
                │
                ▼
[Phase 7: Stability + distribution]
    └── Crash log, performance tuning, store metadata
```

### Load-bearing "do this first" items

These are the things to prototype in isolation before integrating, because they are the highest-risk and the most likely to require multiple iterations:

1. **`SentenceSplitter` as a pure Dart unit test.** Before any reader UI work. Test cases: abbreviations (Mr., Dr., etc.), decimals (3.14), ellipses (...), quoted dialog ("Hello." he said.), unusual Unicode quotes, headings that don't end in punctuation. Get this right once and it stays right.
2. **A throwaway `SentenceRichText` widget** in a standalone screen, rendering a hard-coded `List<Sentence>` with style runs. Verify that the `TextSpan` per sentence approach gives you the style fidelity and the line-break behavior you expect. This is where `flutter_widget_from_html` would be limiting — confirm empirically that the custom renderer gives a better result.
3. **A minimal sherpa_onnx isolate spike.** Load a Kokoro model on a worker isolate, synthesize one fixed sentence, write a WAV file, play it with `just_audio`. No UI, no queue, no Riverpod — just confirm that the model loads, the isolate pattern works, and `just_audio` plays the resulting file on both Android and iOS.

All three of these happen before Phase 3/4 proper. The spec §6 "Hard problems to break out separately" calls out exactly these three; this architecture document is agreeing emphatically.

### Risk callouts by phase

| Phase | Risk | Mitigation |
|-------|------|------------|
| 3 (Reader) | Sentence pipeline is wrong shape → Phase 5 becomes a rewrite | Build `SentenceRichText` against shared `Sentence` type from day one; write golden widget tests for a few sample chapters |
| 4 (TTS) | Isolate lifecycle (init, dispose, error) is fiddly | Copy the structure of the official `isolate_tts.dart` example verbatim; add error handling as a separate step |
| 4 (TTS) | `audio_service` background isolate gotcha | Run `AudioController` in the UI isolate (default config); do not opt into the separate-isolate mode |
| 4 (TTS) | WAV file temp cleanup → disk bloat | LRU cache with a max size, clean on app start |
| 4 (TTS) | Model download resumability / network failure | Use a chunked download library with resume; test airplane-mode-during-download |
| 5 (Highlight) | Auto-scroll fights manual scroll | "User touched scroll recently" state suppresses auto-scroll for N seconds |
| 6 (Polish) | Drift migrations when bookmarks table is added | Use Drift's schema versioning from Phase 1 even though initial schema is small |

---

## 12. Anti-Patterns

### Anti-Pattern 1: Rendering chapter HTML via a webview or HTML widget

**What people do:** Reach for `flutter_widget_from_html` or a WebView to render EPUB chapter HTML.
**Why it's wrong:** Kills sentence identity. The whole architecture hinges on `TextSpan per sentence`, and no HTML-opaque renderer gives you that.
**Instead:** Normalize HTML → plain text + style runs on import, split into sentences, render `RichText` with one `TextSpan` per `Sentence`. This is the Phase 3 commitment.

### Anti-Pattern 2: Running sherpa_onnx on the UI isolate

**What people do:** Call `tts.generateWithConfig(...)` from a Riverpod notifier during a user action.
**Why it's wrong:** The call is synchronous and takes 150–500ms per sentence. The UI isolate stalls, dropped frames, jank, scroll freezes.
**Instead:** All synthesis on a long-lived worker isolate. UI isolate only queues requests and receives results.

### Anti-Pattern 3: `compute()` per sentence

**What people do:** Wrap each `tts.generate(...)` call in `Isolate.run()` or `compute()`.
**Why it's wrong:** Model load is ~1–2s. `compute()` tears the isolate down between calls, forcing a model reload per sentence. Unusable.
**Instead:** Spawn the TTS isolate once, keep it alive for the session.

### Anti-Pattern 4: Reader imports TTS (or vice versa)

**What people do:** To highlight the current sentence, reader imports `TtsController` to ask "what's playing right now?"
**Why it's wrong:** Creates circular dependency potential, couples features, makes testing each feature in isolation harder.
**Instead:** Reader watches `playbackStateProvider`. TTS writes to `playbackStateProvider`. Neither knows about the other.

### Anti-Pattern 5: Storing every sentence as a Drift row

**What people do:** Normalize EPUBs into per-sentence rows for precise resume.
**Why it's wrong:** Drift I/O on every sentence advance; tens of thousands of rows per book; splitter changes become schema migrations.
**Instead:** Drift stores `currentChapterId` + `currentSentenceIndex`. The splitter is deterministic; re-run it on load. Precision is preserved, cost is zero.

### Anti-Pattern 6: `StreamAudioSource` with raw PCM

**What people do:** Try to pipe Float32 samples from the isolate directly into a `StreamAudioSource` for sub-sentence latency.
**Why it's wrong:** `StreamAudioSource` is experimental and expects encoded audio with byte-range semantics. Raw PCM hits platform inconsistencies. Significant engineering cost for marginal benefit.
**Instead:** Wrap synthesized PCM in a WAV header, write temp file, play via `AudioSource.file`. Pre-buffer the next sentence.

### Anti-Pattern 7: Multiple Drift database classes, one per feature

**What people do:** "Feature isolation means each feature has its own database."
**Why it's wrong:** Drift's code generation and migration system assumes one database class. Cross-feature queries become impossible. Each schema version multiplies.
**Instead:** One `MurmurDatabase` in `shared/db/`. Split access via DAOs and per-feature repositories — isolation at the API level, not the storage level.

---

## 13. Integration Points

### External services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Kokoro model host (GitHub/HF) | One HTTP GET, resume-capable, integrity-checked, in `ModelManager` only | The ONLY network call in the entire app. Invariant: no other code imports an HTTP client. |
| OS media session (Android `MediaSession`, iOS `MPNowPlayingInfoCenter`) | Via `audio_service` package | Configure `AndroidNotificationIcon`, `MediaItem` with cover art URI |

### Internal boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| UI isolate ↔ TTS worker isolate | `SendPort` with typed request/response messages | Spawned once; never recycled |
| UI ↔ `audio_service` | `audio_service` runs in the UI isolate (default config) | Do NOT enable the separate-isolate mode |
| Reader feature ↔ TTS feature | One-way via `playbackStateProvider` in `shared/` | No direct imports between features |
| `TtsQueue` ↔ `AudioController` | Direct method calls within the TTS feature | Both live in `features/tts/` |
| Features ↔ Drift | Feature repository → shared DAO → shared database | Never `MurmurDatabase` directly from UI |
| Features ↔ `Sentence` | Everyone imports `shared/domain/sentence.dart` | Coordination currency |

---

## 14. Scaling Considerations (the murmur version)

"Scale" here is not users — there is no backend. Scale is **book size and session duration**.

| Dimension | At 100 pages | At 1000 pages | At 3000+ pages |
|-----------|-------------|---------------|----------------|
| Chapters loaded in memory | Current only | Current only | Current only + LRU for prev/next |
| Sentences in memory | ~1k | ~10k | ~30k — keep only current chapter's `List<Sentence>` |
| WAV temp files | ~10s of files | Same | Same (LRU, bounded by max 50 files) |
| Drift row counts | ~100 chapter rows | ~100 chapter rows | ~200 chapter rows |
| Memory footprint | ~150MB (model + app) | ~150MB | ~150MB |

### What breaks first

1. **Loading an entire multi-thousand-page EPUB's chapters into memory eagerly.** Fix: chapter loading is lazy and keyed by `chapterId`; `chapterProvider` is a Riverpod family that is disposed when you navigate away from that chapter.
2. **TTS temp WAV files accumulating.** Fix: bounded LRU cache + cleanup on app start.
3. **2-hour session memory growth.** Fix: `Sentence` lists for chapters we've left should be disposed; profile with DevTools in Phase 7 stability work.

Performance targets from PROJECT.md (60fps reader scroll, <300ms TTS latency, no leak over 2hrs with 1000-page book) are the concrete acceptance criteria for "scaled enough."

---

## Sources

- **Primary-source evidence (HIGH confidence):**
  - [`sherpa_onnx` pub.dev package page](https://pub.dev/packages/sherpa_onnx) — package exists, Flutter bindings, version ~1.10.x
  - [`flutter/sherpa_onnx/lib/src/tts.dart` in k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx/tree/master/flutter/sherpa_onnx/lib/src) — confirmed public API: `generate()`, `generateWithCallback()`, `generateWithConfig()`, all synchronous, all returning `GeneratedAudio { Float32List samples, int sampleRate }`
  - [`flutter-examples/tts/lib/isolate_tts.dart` in k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx/tree/master/flutter-examples/tts/lib) — confirmed the `Isolate.spawn` + `SendPort` + `RootIsolateToken` pattern used by the official example
  - [sherpa-onnx Kokoro TTS docs](https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/index.html) — Kokoro-82M pretrained model availability
- **MEDIUM confidence (verified against official docs but not primary code):**
  - [`just_audio` package](https://pub.dev/packages/just_audio) — `StreamAudioSource` is experimental; encoded-audio expectation
  - [`just_audio` issue #1028](https://github.com/ryanheise/just_audio/issues/1028) — realtime PCM via `StreamAudioSource` is non-trivial; WAV-wrap approach is the practical path
  - [`audio_service` package](https://pub.dev/packages/audio_service) — background isolate configuration options
  - [Background audio in Flutter with Audio Service and Just Audio (Suragch, Medium)](https://suragch.medium.com/background-audio-in-flutter-with-audio-service-and-just-audio-3cce17b4a7d) — canonical integration walkthrough
- **Context/confirmation (MEDIUM):**
  - [Flutter App Architecture with Riverpod (Code with Andrea)](https://codewithandrea.com/articles/flutter-app-architecture-riverpod-introduction/) — feature-first conventions
  - [Flutter Riverpod Clean Architecture Template](https://dev.to/ssoad/flutter-riverpod-clean-architecture-the-ultimate-production-ready-template-for-scalable-apps-gdh) — per-feature data/domain/ui pattern
  - [`murmur_app_spec.md` §4](./../../murmur_app_spec.md) — the proposed `lib/` tree being refined here
  - [`PROJECT.md`](./../../.planning/PROJECT.md) — constraints, key decisions, non-goals

---

*Architecture research for: Flutter ebook reader with on-device neural TTS*
*Researched: 2026-04-11*
