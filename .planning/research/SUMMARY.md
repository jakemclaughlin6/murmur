# Project Research Summary

**Project:** murmur
**Domain:** Flutter ebook reader with on-device neural TTS (Kokoro-82M via Sherpa-ONNX), Android + iOS, paid one-time
**Researched:** 2026-04-11
**Confidence:** HIGH on stack, architecture, and pitfalls; MEDIUM-HIGH on features and competitive positioning

---

## Executive Summary

murmur occupies a product gap that is genuinely uncrowded: a typography-grade EPUB reader with on-device neural TTS, fully offline, one-time purchase. Every competitor is either a good reader with weak/system TTS (Lithium, Moon+, Yomu, Librera), or a TTS-forward app with a mediocre reading experience and a subscription or cloud dependency (Speechify, Voice Dream, NaturalReader). Voice Dream Reader's 2024 subscription pivot burned exactly the trust of the accessibility-heavy audience that most values long-term local ownership — this is the specific market opening murmur can step into with a $3 one-time purchase and a truthfully empty privacy policy.

The recommended implementation is: Flutter 3.41 / Dart 3.11 with Riverpod 3, go_router 17, Drift 2.32, epubx + package:html for EPUB parsing (not epub_view — see Key Findings), sherpa_onnx 1.12.x for Kokoro TTS running in a long-lived worker isolate, just_audio 0.10 + audio_service 0.18 for audio output. The architectural backbone is three features (library, reader, tts) coordinated through a single shared Riverpod provider (`playbackStateProvider`) with a shared `Sentence` domain model in `shared/domain/` — this arrangement is what prevents the reader-TTS circular dependency that is otherwise inevitable.

The three highest risks in the build are: (1) the EPUB HTML to sentence IR pipeline, which must be designed as a rich intermediate representation before Phase 3 starts or Phase 3 will require a rewrite; (2) the sherpa_onnx Flutter bindings, which are real and usable but young and must be integrated on a long-lived worker isolate from day one; and (3) Phase 4, which concentrates 8 of 17 critical pitfalls (audio session, isolate lifecycle, background audio entitlements, lock screen metadata, sample rate, gapless playback, compound speed, and native linking). Budget at least double the nominal time for Phase 4.

---

## Key Findings

### Recommended Stack

Flutter 3.41 / Dart 3.11 is the only credible choice for single-codebase Android + iOS with the per-span text control the sentence-highlight feature requires. Riverpod 3 (stable since late 2025) is the correct state management choice over BLoC at solo-developer scale; go_router 17 handles the three routes without ceremony; Drift 2.32 provides type-safe reactive SQLite with code-gen that is worth the build_runner overhead for library-grid auto-updates. For audio: just_audio 0.10 + audio_service 0.18 is the only Flutter combination that provides StreamAudioSource semantics, background audio, and lock-screen controls on both platforms.

**Critical dependency correction:** `epub_view` must not be used. It depends on `flutter_html`, which cannot expose per-sentence TextSpan handles — it is architecturally incompatible with the sentence-span renderer. The replacement is `epubx` (pure parser, exposes raw chapter XHTML as String) + `package:html` (DOM walking for the IR pipeline). `epubx` was last published June 2023; Dart 3.11 compatibility is unverified and must be the first thing confirmed in Phase 1. If it fails, fall back to `package:archive` + `package:xml` + `package:html` (~200 lines of glue code — EPUB is just a zip of XHTML).

**Core technologies:**
- `flutter_riverpod` ^3.3.1 — state management; compile-time-safe, excellent disposal semantics, no BuildContext coupling
- `go_router` ^17.2.0 — declarative routing for /library, /reader/:bookId, /settings
- `drift` ^2.32.1 — type-safe SQLite with reactive streams; single database class in `shared/db/`
- `epubx` ^4.0.0 — pure-Dart EPUB parser (NOT epub_view); exposes raw chapter XHTML for custom IR pipeline
- `package:html` ^0.15.x — lenient HTML5 DOM parser for the XHTML content documents
- `sherpa_onnx` ^1.12.36 — official Flutter bindings for Kokoro TTS; pin to exact version (not `^`), active 2-8 day release cadence
- `just_audio` ^0.10.5 + `audio_service` ^0.18.18 — audio playback and background/lock-screen layer
- `file_picker` ^11.0.2 — system file picker with EPUB extension filter, supports `allowMultiple: true`
- `crypto` ^3.0.5 — SHA-256 verification of downloaded model file
- `http` ^1.2.0 — single-use for first-launch model download; no dio needed

**Kokoro model -- corrected numbers (spec is wrong):**
The spec says "~82MB download + ~3MB voices.bin." Correct values verified against GitHub release assets (2026-04-11):
- `model.int8.onnx`: ~80MB — download on first launch only
- `voices.bin`: ~5.5MB (not 3MB) — bundle with app
- `tokens.txt`: ~1KB — bundle with app
- `espeak-ng-data/`: ~1MB — bundle with app (spec missed this entirely; sherpa-onnx requires it at runtime for English phonemization)
- Total bundled: ~7MB; total tarball: ~98.5MB

Bundle strategy: ship `voices.bin` + `tokens.txt` + `espeak-ng-data/` in the app binary; download only `model.int8.onnx` on first launch with SHA-256 verification.

### Expected Features

The spec is approximately correct on what to build. Research adds six must-have features that were missing:

**Must have (table stakes) -- additions to spec:**
- Sentence skip forward / back on the playback bar — the single biggest gap in the current spec; zoning out is the number one failure mode for long TTS listening; @Voice and Voice Dream both treat this as core TTS UX
- Per-book voice and speed preferences stored in Drift (`books` table: add `preferred_voice_id`, `preferred_speed` columns, fall back to global default when null)
- Open-in / Share-to handler — Android intent filter + iOS Document Types in Info.plist; users expect to send EPUBs from Files, Safari, email, cloud drives without opening the app first
- Batch EPUB import — `file_picker` `allowMultiple: true`; target user has existing Calibre libraries with 50+ books
- Wi-Fi-only toggle on model download — 80MB on cellular is hostile; default ON
- Settings entry to view and share the local crash log — reinforces the "privacy as product" story

**Must have (table stakes) -- already in spec, confirmed correct:**
- System file picker import, DRM detection with clear error message (not crash)
- Library grid: responsive 2-6 columns by form factor, sort by recent/title/author, search, long-press context menu
- Cover art parsed on import and cached as a resized file thumbnail
- Reader: font size/family/spacing/theme, chapter navigation, resume position, progress indicator, immersive mode
- TTS: play/pause, speed 0.75-2x, background audio, lock-screen controls, auto-advance, ~10 curated voices with previews, sleep timer (minutes + end-of-chapter)
- Sentence highlighting with auto-scroll to active sentence
- Bookmarks: save, list, jump with scroll offset precision
- First-launch onboarding + model download prompt

**Should have (differentiators):**
- Typography quality on par with Yomu/Lithium in a TTS-capable app (no competitor combines both)
- Sentence-level skip as a first-class playback control (not just chapter-level)
- Two-way coupling: reader position follows TTS, TTS can be started from any tapped sentence
- Truthfully empty privacy policy surfaced in-app onboarding (not just store listing)
- "Listening" indicator on library cards for the active book
- Bookmark UX where the jump lands at exact scroll offset and briefly pulses the sentence (Librera gets this wrong)

**Defer to v1.x:**
- OPDS catalog browser (Calibre content server, Standard Ebooks, Project Gutenberg) — highest-impact post-launch differentiator but MEDIUM-HIGH complexity
- Book collections / shelves / tags — Drift schema can be forward-compatible with a `collections` table in Phase 2 migration, no UI until v1.1
- Library home-screen widget

**Permanent anti-features (document to prevent re-proposal):**
- Cloud sync, accounts, or any backend — privacy is the product
- System TTS fallback — Kokoro quality is the differentiator; a degraded fallback ships the wrong product
- Cloud neural voices (ElevenLabs, Azure, Polly) — breaks airplane-mode posture and one-time-paid model
- Annotations / notes — scoping decision; bookmarks cover the "come back later" use case
- PDF, MOBI, or any non-EPUB format — PDF alone would double complexity
- Word-level karaoke highlighting — Kokoro does not expose per-word timing; forced alignment is a research project

### Architecture Approach

The architecture is feature-first (`library/`, `reader/`, `tts/`) with a meaningful `shared/` layer. The load-bearing structural decision is that `Sentence` lives in `shared/domain/`, not `features/reader/domain/` — this is what allows TTS to consume sentences without importing from the reader feature and prevents the circular dependency that would otherwise exist. Cross-feature coordination flows through exactly one shared Riverpod provider: `playbackStateProvider` in `shared/providers/`, which TTS writes and reader watches. There is no event bus, no callbacks, and no direct imports between features.

**Major components and their key responsibilities:**

1. `shared/domain/sentence.dart` — `Sentence { id: "$chapterId:$index", chapterId, index, text, spokenText, styleRuns, chapterOffset }`; the coordination currency of the whole app
2. `shared/utils/sentence_splitter.dart` — pure Dart, returns `List<Sentence>` (not `List<String>`); runs on UI isolate; IDs assigned here
3. `shared/providers/playback_state.dart` — single cross-feature provider; `PlaybackState { currentSentenceId?, currentChapterId?, isPlaying, isBuffering }`; TTS writes, reader + library watch
4. `shared/db/` — single Drift `@DriftDatabase` class with all tables; per-feature repositories wrap DAOs; features never import the database class directly
5. `features/tts/data/tts_service.dart` — owns the long-lived worker isolate; sends `TtsRequest { id, text, voiceId, speed }`, receives `Float32List` samples via `TransferableTypedData`
6. `features/tts/data/audio_controller.dart` — wraps samples in a 44-byte WAV header, writes to temp file, hands to `just_audio` via `AudioSource.file()`; owns the `audio_service` MediaHandler
7. `features/reader/ui/sentence_rich_text.dart` — per-paragraph `RichText` in a `ListView.builder` with `RepaintBoundary`; watches `playbackStateProvider` to apply highlight to exactly one sentence at a time

**Architecture note -- stale references in ARCHITECTURE.md:**
The architecture diagram on line 72 still references `EpubParser (epub_view)`. This is inconsistent with the package decision -- `epubx` is the correct parser. The lib/ tree (lines 211-216) also omits `espeak-ng-data/` and lists `voices.bin` as ~3MB. These are documentation artifacts that need correcting when Phase 2 starts, not structural problems.

### Critical Pitfalls

The full pitfall catalog has 32 entries across 17 critical, 10 moderate, and 5 minor. The absolute must-not-miss subset:

1. **Wrong EPUB parser** (BLOCKER) — `epub_view` is a renderer, not a parser; it depends on `flutter_html` which cannot expose per-sentence TextSpan handles. Swap to `epubx` + `package:html`. Run the spike in Phase 1: load a sample EPUB, get chapter XHTML as a String, hand it to `package:html` for DOM walking. If `epubx` fails on Dart 3.11, fork it or roll your own parser in ~200 lines.

2. **EPUB intermediate representation designed too thin** (BLOCKER) — the naive path ("list of sentences") loses heading hierarchy, paragraph breaks, blockquotes, images, footnotes, poetry formatting, and inline styling. The IR must be `Chapter { blocks: List<Block> }` where `Block` can be `Paragraph | Heading(level) | BlockQuote | Image | Separator`. Build this against a 15-EPUB test corpus (Project Gutenberg, Standard Ebooks, Leanpub, O'Reilly, Calibre-exported, iBooks-exported, EPUB 2 legacy, poetry, footnote-heavy, technical) before the renderer in Phase 3.

3. **Sherpa-ONNX synthesis on the UI isolate** (BLOCKER) — `OfflineTts.generate*()` methods are synchronous blocking FFI calls; calling them from any provider or FutureBuilder on the main isolate produces ANR dialogs on Android and watchdog timeouts on iOS. Use `Isolate.spawn()` with a `SendPort`/`ReceivePort` channel, create the `OfflineTts` handle inside the isolate (FFI handles are not transferable), and keep the isolate alive for the session. Copy the pattern from `k2-fsa/sherpa-onnx/flutter-examples/tts/lib/isolate_tts.dart` verbatim.

4. **PCM audio format mismatch** (BLOCKER) — Kokoro outputs 24kHz mono Float32; `just_audio`'s `StreamAudioSource` is experimental and unreliable for raw PCM. Use WAV-wrap + temp file + `AudioSource.file()`: convert Float32 to int16 (safer cross-platform than float WAV), prepend 44-byte WAV header (RIFF/WAVE/fmt/data, sample rate 24000, 1 ch, 16-bit PCM), write to `.../cache/tts/{sentenceId}.wav`, delete after playback advances. Use `TransferableTypedData` to move the `Float32List` across the isolate boundary without copying.

5. **iOS background audio fails silently in release builds** (BLOCKER) — requires `UIBackgroundModes: [audio]` in Info.plist, `AVAudioSession` category `.playback` via `audio_session` package, `audio_service` initialized in `main()` before `runApp`, ALL playback routed through the `audio_service` MediaHandler (not directly via just_audio). On Android 14+: `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission + foreground service type declaration. Test on physical device with phone locked for 60+ seconds; simulator lies.

6. **Per-paragraph RichText in ListView.builder, not monolithic** (BLOCKER for performance) — a single `RichText` with 2000+ TextSpans re-lays out the entire chapter on every sentence highlight change (100+ ms per update on mid-range hardware). Split into per-paragraph `RichText` widgets in a `ListView.builder` or `SliverList`; wrap the active paragraph in `RepaintBoundary`. This must be done in Phase 3, not retrofitted in Phase 5 when highlighting is added.

7. **Compound speed control** (SERIOUS) — pick exactly one owner: `just_audio.setSpeed()` for runtime speed (instant, no re-synthesis, good quality for speech at 0.75-2x), with Sherpa `length_scale` fixed at 1.0. If both layers apply the user's speed setting, a 2x request produces 4x playback. Assert in code that exactly one is non-unity.

8. **Store compliance items in Phase 1, not Phase 7** (SERIOUS, launch-blocking if missed) — `ITSAppUsesNonExemptEncryption=false` in Info.plist (must be present before any TestFlight upload), `UIBackgroundModes=audio`, `AVAudioSession` category declaration, Android `FOREGROUND_SERVICE_MEDIA_PLAYBACK` in manifest, IARC content rating prep. These block distribution; doing them in Phase 7 means the first TestFlight build in Phase 6 QA is already blocked.

---

## Implications for Roadmap

The existing 7-phase plan in the spec is approximately correct in structure but needs several targeted amendments. The following maps research findings onto the phase structure.

### Phase 1: Scaffold + Compliance Foundation
**Rationale:** Native linking, compliance declarations, and dependency validation are ship-blockers that compound in cost if discovered late. Phase 1 is the only safe time to verify `epubx` on Dart 3.11, set up CI, and plant all the Info.plist/manifest keys that TestFlight will reject without.
**Delivers:** Working app scaffold on physical device (iOS + Android), all Info.plist/manifest compliance keys planted, epubx Dart 3.11 compatibility confirmed (or fallback chosen), CI pipeline building both platforms on push, Drift schema with migration strategy initialized
**Addresses:** Store compliance before Phase 7 (Pitfalls 11, 12, 13); epubx staleness risk (Stack risk 3)
**Research additions to spec:** Add `ITSAppUsesNonExemptEncryption=false`, `UIBackgroundModes=audio`, `AVAudioSession` category, Android `FOREGROUND_SERVICE_MEDIA_PLAYBACK` to Phase 1 checklist. Set up GitHub Actions CI for iOS + Android. Confirm epubx builds; document fallback plan.
**Research flag:** This phase is well-understood. Standard patterns apply. No additional research needed.

### Phase 2: EPUB Import + Parser Foundation
**Rationale:** The IR design is the foundational decision that every downstream phase (reader rendering, TTS pipeline, sentence highlighting) depends on. Getting it wrong here causes a Phase 3 rewrite. Phase 2 must produce the complete test corpus and a validated `Chapter { blocks }` IR before any rendering begins.
**Delivers:** EPUB import pipeline (file picker, SAF copy to app documents, metadata parse, cover thumbnail cache), `Chapter { blocks: List<Block> }` IR with snapshot tests against a 15-EPUB corpus, DRM detection with clear user-facing error, batch import (`allowMultiple: true`), Open-in / Share-to handler, Drift schema including forward-compatible `collections` table and `preferred_voice_id`/`preferred_speed` columns on books
**Uses:** `epubx`, `package:html`, `file_picker`, Drift, platform intent filter / `receive_sharing_intent`
**Implements:** `shared/epub/epub_parser.dart`, `html_normalizer.dart`, `features/library/` full stack
**Avoids:** Pitfall 1 (wrong parser), Pitfall 2 (wild EPUB XHTML quirks), Pitfall 25 (Android content URIs), Pitfall 27 (cover memory)
**Research additions to spec:** 15-EPUB test corpus is a Phase 2 deliverable, not optional. IR must have a `Block` type before the chapter renderer is written. Batch import and Share-to handler belong here.
**Research flag:** `epubx` staleness creates a go/no-go decision at Phase 2 start. If `epubx` fails during Phase 1 spike, Phase 2 plan changes to roll-your-own parser. Plan for both paths.

### Phase 3: Reader Rendering
**Rationale:** The sentence-span renderer is the single biggest architectural commitment. Per-paragraph `RichText` in `ListView.builder` with `RepaintBoundary` must be the design from day one -- retrofitting this in Phase 5 when highlighting is added would require a complete reader rewrite. Accessibility must also be addressed here: `Semantics(label: fullParagraphText)` wrapper on each paragraph block so VoiceOver/TalkBack read whole paragraphs, not individual sentence spans.
**Delivers:** Per-paragraph RichText rendered inside `ListView.builder`, sentence-span data structure with stable IDs (`chapterId:index`), `SentenceSplitter` with 500+ fixture regression suite (24+ edge-case categories), reader prefs (font/theme/spacing), chapter navigation (tablet sidebar / phone drawer), reading position persistence, scroll performance at 60fps on mid-range device
**Uses:** `shared/domain/sentence.dart`, `SentenceSplitter`, `package:html` DOM walker, `ListView.builder`, `RepaintBoundary`, `Semantics`
**Implements:** `features/reader/` full stack, `shared/utils/sentence_splitter.dart`
**Avoids:** Pitfall 8 (monolithic RichText perf), Pitfall 9 (accessibility regression), Pitfall 17 (sentence index drift), Pitfall 21 (progress debounce)
**Research additions to spec:** `SentenceSplitter` must return `List<Sentence>` (not `List<String>`). 500+ fixture regression suite is a Phase 3 deliverable. Per-paragraph architecture with `RepaintBoundary` must be locked here. Add `WidgetsBindingObserver` for progress flush on `AppLifecycleState.paused`.
**Research flag:** Sentence splitter edge case depth (24+ categories) may warrant a brief sub-research pass before coding to enumerate the abbreviation gazetteer. Standard patterns otherwise.

### Phase 4: TTS Engine Integration
**Rationale:** Phase 4 is the highest-density pitfall phase in the project -- 8 of 17 critical pitfalls land here. The isolate boundary, audio session setup, PCM-to-WAV conversion, background audio entitlements, lock-screen metadata, gapless playback, sample rate handling, and native linking all require first-time-correct decisions. Retrofitting any of these after the fact is significantly more expensive than getting them right here. Everything must be tested on physical devices; simulators lie about audio session and background behavior.
**Delivers:** Long-lived TTS worker isolate (Sherpa `OfflineTts` handle created inside isolate, never on UI isolate), `TtsRequest`/`TtsResult` message protocol using `TransferableTypedData` for PCM bytes, WAV-wrap pipeline (Float32 to int16, 44-byte header, temp file, `AudioSource.file`), `audio_service` MediaHandler with book/chapter metadata and cover art, lock-screen controls (play/pause maps to TTS play/pause; skip-next/prev maps to chapter not sentence), background audio verified on physical iPhone locked for 60s, `ModelManager` with resumable download + SHA-256 verification + disk space check, Wi-Fi-only download toggle, speed control owned exclusively by `just_audio.setSpeed()` with `length_scale` fixed at 1.0, sentence skip forward/back in `TtsQueue`
**Uses:** `sherpa_onnx` (pinned exact version), `just_audio`, `audio_service`, `audio_session`, `crypto`, `http`, `TransferableTypedData`
**Implements:** `features/tts/` full stack, `shared/providers/playback_state.dart`, `shared/utils/wav_writer.dart`
**Avoids:** Pitfall 4 (synthesis on main isolate), Pitfall 5 (PCM format), Pitfall 6 (iOS background), Pitfall 7 (lock screen), Pitfall 5a (compound speed), Pitfall 14 (bundle size), Pitfall 15 (native linking), Pitfall 16 (isolate overhead)
**Research additions to spec:** Sentence skip forward/back must be implemented here (not deferred to Phase 5). Speed control decision must be documented in TtsService contract with an assertion. Pre-warm isolate when reader screen opens, not when user taps play.
**Research flag:** Phase 4 warrants a `/gsd-research-phase` call before planning. `just_audio` WAV-file vs StreamAudioSource benchmark is an open question requiring empirical testing. Sherpa `generateWithConfig` vs `generateWithCallback` approach for the pre-buffer pipeline also needs a quick investigation pass before coding begins.

### Phase 5: Sentence Highlighting + Two-Way Sync
**Rationale:** With per-paragraph RichText architecture locked in Phase 3 and `playbackStateProvider` established in Phase 4, sentence highlighting becomes a targeted optimization: watch `currentSentenceId`, find the matching paragraph, swap the TextStyle, scroll. The two-way sync (TTS advances reader, tap starts TTS from position) is the feature that makes read-along feel alive rather than two separate apps duct-taped together.
**Delivers:** Active sentence highlighted in reader as TTS plays (via `playbackStateProvider` watch), auto-scroll keeping active sentence in viewport upper-third via `Scrollable.ensureVisible()`, tap on sentence sets `ttsControllerProvider.startFrom(sentenceId)`, `spokenText` normalization field on `Sentence` (strip footnote markers, handle abbreviations for speech without changing display text), "disable sentence highlight" toggle in Settings
**Uses:** `playbackStateProvider`, `RepaintBoundary`, `Scrollable.ensureVisible()`, `GlobalKey` on active paragraph
**Implements:** Highlight + scroll logic in `sentence_rich_text.dart`, `Sentence.spokenText` field, text normalization
**Avoids:** Pitfall 17 (sentence index drift from normalization), Pitfall 9 (accessibility -- spot-check highlight contrast on all four themes)
**Research flag:** Standard patterns apply. No additional research needed.

### Phase 6: Polish, Accessibility, and Multi-Device
**Rationale:** Quality-gate before store submission. Physical device testing must happen throughout the project but this phase consolidates the multi-device matrix: phone portrait/landscape, tablet with and without sidebar, iPad split-view at 1/3 and 1/2 and full, Android foldable, text-scale accessibility, TalkBack + VoiceOver.
**Delivers:** `LayoutBuilder`-based responsive layout (not `MediaQuery.size.width`), TalkBack + VoiceOver accessibility verified (paragraph-level Semantics labels, not sentence-by-sentence), WCAG AA contrast on highlight colors across all four themes, bookmarks UI with scroll-offset-precise jump + sentence pulse, sleep timer on wall-clock time (not elapsed Timer ticks), pause-on-headphone-unplug verified, TestFlight build flowing, privacy policy drafted and hosted, store listing copy drafted with public-domain screenshots
**Avoids:** Pitfall 10 (MediaQuery layout), Pitfall 22 (sleep timer backgrounding), Pitfall 29 (dark mode mid-reading)
**Research flag:** Accessibility testing on split-view and Stage Manager requires physical device access; cannot be emulated.

### Phase 7: Distribution
**Rationale:** Upload, review, ship. Phase 1's compliance groundwork means this phase is upload-only rather than a compliance scramble. Validate bundle size, confirm AAB ABI filtering, do the final release-mode native linking verification on both platforms.
**Delivers:** Signed AAB with `abiFilters` (arm64-v8a + armeabi-v7a only), App Store IPA with App Thinning, Play Store Data Safety form and App Store privacy labels (both "no data collected"), IARC content rating (expected Everyone / 3+), Android 15 16KB page-size alignment verification on physical device, SHA-256 checksum pinned in source
**Avoids:** Pitfall 11 (export compliance), Pitfall 12 (privacy labels), Pitfall 13 (IARC), Pitfall 14 (bundle size), Pitfall 15 (native linking in release)
**Research flag:** Standard patterns. Compliance key references in STACK.md and PITFALLS.md are comprehensive.

### Phase Ordering Rationale

The 7-phase order maps to a strict dependency graph:
- Phase 1 gates everything: native build must work, epubx must resolve, compliance keys must be planted before first TestFlight
- Phase 2 must produce the `Chapter { blocks }` IR before Phase 3 can write the renderer
- Phase 3 must lock the per-paragraph RichText architecture before Phase 5 can add highlighting without a rewrite
- Phase 4 must establish `playbackStateProvider` and the isolate boundary before Phase 5 can wire two-way sync
- Phase 5 depends on both Phase 3 (IR + per-paragraph widgets) and Phase 4 (`playbackStateProvider` + sentence queue)
- Phase 6 requires working Phase 3-5 features to do meaningful accessibility and device testing
- Phase 7 is unlock-gated by Phase 6 TestFlight

### Research Flags

**Phases needing `/gsd-research-phase` before planning:**
- **Phase 2:** `epubx` go/no-go decision must be made at Phase 1 exit. If epubx fails Dart 3.11, Phase 2 plan needs a full re-estimate for the roll-your-own parser path. The 15-EPUB corpus assembly also needs a curated list of specific files.
- **Phase 4:** Highest-risk phase. Before writing any Phase 4 tasks, research the specific sherpa_onnx 1.12.x `generateWithConfig` vs `generateWithCallback` API and the `just_audio` WAV-file-vs-StreamAudioSource tradeoff empirically. The k2-fsa isolate_tts.dart example should be studied as primary source before any TTS code is written.

**Phases with standard, well-documented patterns:**
- **Phase 1:** Flutter project scaffold, Riverpod + go_router wiring, Drift initial schema -- all have extensive documentation and community examples.
- **Phase 3:** Per-paragraph ListView.builder with RichText is idiomatic Flutter. Sentence splitter is pure Dart logic. Well-understood.
- **Phase 5:** Watch a provider, update a TextStyle, scroll. Standard Riverpod + Flutter patterns.
- **Phase 6:** Responsive layout with LayoutBuilder, Semantics testing, TestFlight setup -- well-documented.
- **Phase 7:** AAB + App Thinning + store compliance -- procedural checklist. No technical unknowns.

---

## Cross-Cutting Conflicts and Tensions

These are genuine conflicts between the four research dimensions that the roadmap must resolve.

### Conflict 1: `epub_view` references in ARCHITECTURE.md vs. STACK/PITFALLS

ARCHITECTURE.md (line 72 and line 106) still references `epub_view` in its system diagram and component table. STACK.md explicitly rejects it; PITFALLS Pitfall 1a explains why it is architecturally incompatible. The ARCHITECTURE document needs a correction pass when Phase 2 starts. The parser component should read `EpubParser (epubx + package:html)`.

### Conflict 2: Model size numbers in ARCHITECTURE.md vs. STACK.md

ARCHITECTURE.md TL;DR (line 27) says `voices.bin (~3MB)` and `model (~82MB)`. STACK.md corrected these to ~5.5MB and ~80MB respectively. The ARCHITECTURE asset tree (lines 211-216) also omits `espeak-ng-data/` (~1MB). These are documentation artifacts. The canonical numbers are in STACK.md.

### Conflict 3: Sentence skip backward vs. TtsQueue forward-cursor design

FEATURES identifies sentence skip forward/back as the biggest missing table-stakes feature. ARCHITECTURE's `TtsQueue` design is a forward-cursor with a one-ahead pre-buffer; once playback of sentence N advances to N+1, the temp WAV file for N is deleted. Backward skip requires either: (a) keeping the last N WAV files instead of deleting them, or (b) re-synthesizing the previous sentence on demand. Option (a) is simpler and has negligible storage cost (a 3-second sentence WAV is ~144KB). Option (b) adds ~200-500ms latency on backward skip. Recommendation: keep the last 3 sentence WAV files in a ring buffer in the temp directory; backward skip resets the queue cursor and plays from the cached file. This design question must be resolved when Phase 4 tasks are written.

### Conflict 4: Speed control -- PITFALLS recommends `just_audio.setSpeed()`; spec says Sherpa `length_scale`

The spec and PROJECT.md describe speed as "Sherpa `length_scale` param." PITFALLS Pitfall 5a makes a clear recommendation that `just_audio.setSpeed()` is the better owner for runtime speed (instant UX, no re-synthesis delay, acceptable quality for speech at 0.75-2x) with `length_scale` fixed at 1.0. ARCHITECTURE does not weigh in. This research adopts the PITFALLS recommendation. The spec should be updated to reflect this when Phase 4 planning begins. Document the choice in `TtsService` contract with an assertion.

---

## Open Questions for Phase-by-Phase Resolution

These are unresolved design questions that must be resolved empirically or by explicit decision before the relevant phase planning.

| Question | Phase | Resolution approach |
|----------|-------|---------------------|
| Does `epubx` compile on Dart 3.11 without modification? | Phase 1 spike | Run `flutter pub get` + a 20-line load spike; fail fast and choose fork vs. roll-your-own |
| `just_audio` WAV-file-per-sentence vs. `StreamAudioSource` for gapless playback -- which approach meets <100ms inter-sentence gap target on iOS + Android? | Phase 4 spike | Benchmark both on physical device before committing to either path; WAV-file is the safer default |
| Backward sentence skip: keep last-N WAV files (ring buffer) vs. re-synthesize on demand? | Phase 4 planning | Ring buffer of last 3 sentences is the recommendation; confirm temp-dir size budget is acceptable |
| Is Kokoro `generateWithCallback` stable enough in sherpa_onnx 1.12.x to use for pre-buffering, or does Phase 4 use `generateWithConfig` (one-shot)? | Phase 4 spike | Read the 1.12.x changelog; default to `generateWithConfig` for Phase 4; `generateWithCallback` is a Phase 7 optimization if latency misses target |
| What is the audible quality of `just_audio.setSpeed()` time-stretch at 0.75x and 2x on Android ExoPlayer vs. iOS AVAudioPlayer? | Phase 4 device test | Blind listen test on both platforms; if quality is unacceptable, fall back to `length_scale` with queue flush delay |
| Which 10 Kokoro voices ship in the initial curated lineup? | Phase 4 | Listening session against Kokoro VOICES.md; starting candidates: `af_heart`, `af_bella`, `af_nova`, `af_sky` (US female), `bm_george`, `bm_lewis` (British male), `bf_emma`, `bf_isabella` (British female), `am_adam`, `am_michael` (US male) |

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All package versions verified on pub.dev 2026-04-11; Kokoro model file sizes verified via HTTP HEAD against actual GitHub release assets; sherpa_onnx changelog timeline verified as primary source |
| Features | MEDIUM-HIGH | Competitive landscape well-known from public reviews and App Store data; user preference assertions inferred from review evidence, not direct user research; sentence skip and per-book prefs as table stakes are high-confidence inferences from competitor feature sets |
| Architecture | HIGH | TTS isolate pattern grounded in official k2-fsa `isolate_tts.dart` example (primary source); Riverpod + feature-first patterns well-documented; PCM/WAV approach grounded in `just_audio` issue tracker and pub.dev API docs |
| Pitfalls | MEDIUM-HIGH | Platform/store compliance rules verified against official Apple and Google docs; Sherpa-ONNX Flutter binding failure modes are inferred from changelog analysis and known native-library Flutter plugin patterns, not direct hands-on testing of every failure path |

**Overall confidence:** HIGH

### Gaps to Address

- **`epubx` Dart 3.11 compatibility:** Not verified -- must be the first technical validation in Phase 1. All EPUB parsing planning assumes `epubx` works; if it does not, Phase 2 plan needs re-estimate for the roll-your-own path.
- **`just_audio` StreamAudioSource stability on current iOS:** The experimental status is documented but real-device behavior in just_audio 0.10.x is unverified. Phase 4 spike must benchmark WAV-file approach vs StreamAudioSource before committing.
- **Sherpa-ONNX 1.12.x Generate API stability:** The Generate API refactored in 1.12.31 is ~6 weeks old at research date. Changelog-based confidence only. Phase 4 must build a minimal TTS harness ("synthesize a sentence, play it, hear it") as the very first task.
- **Android 15 16KB page-size alignment for Sherpa-ONNX native libs:** Whether sherpa_onnx 1.12.x ships 16KB-aligned libs requires checking `readelf -l libsherpa-onnx-c-api.so` on a downloaded release. Verify in Phase 4.
- **Voice curation subjective quality:** Which 10 voices to ship requires a listening session. The six-candidate shortlist above is a starting point, not a final answer. Budget a half-day listening session as a Phase 4 deliverable.

---

## Sources

### Primary (HIGH confidence)
- pub.dev package pages for all dependencies -- version numbers, changelogs, API docs (verified 2026-04-11)
- `https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models` -- Kokoro model release assets; file sizes verified via HTTP HEAD
- `https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html` -- official model documentation
- `k2-fsa/sherpa-onnx/flutter-examples/tts/lib/isolate_tts.dart` -- primary source for TTS isolate pattern
- `k2-fsa/sherpa-onnx/flutter/sherpa_onnx/lib/src/tts.dart` -- primary source confirming synchronous blocking Dart API
- Apple Developer Documentation -- Info.plist keys, UIBackgroundModes, AVAudioSession, export compliance
- Android Developer Documentation -- foreground service types, FOREGROUND_SERVICE_MEDIA_PLAYBACK, 16KB page size

### Secondary (MEDIUM confidence)
- App Store and Google Play competitive review analysis (2026-04-11) -- competitive landscape, Voice Dream subscription pivot, @Voice and Speechify UX patterns
- `just_audio` GitHub issue #1028 -- StreamAudioSource experimental status and byte-range semantics requirement
- Flutter release notes and community ecosystem snapshot -- Flutter 3.41 / Dart 3.11 versions confirmed
- IARC questionnaire documentation -- content rating guidance for ebook reader apps

### Tertiary (LOW confidence)
- Community forum and Reddit observations about Voice Dream subscription backlash -- directional, not quantified
- User review patterns on Moon+/Librera/Lithium regarding TTS quality ceiling and bookmark UX pain -- inferred from aggregated review themes

---

*Research completed: 2026-04-11*
*Ready for roadmap: yes*
