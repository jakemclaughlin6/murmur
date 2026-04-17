# Requirements: murmur

**Defined:** 2026-04-11
**Core Value:** Point murmur at an EPUB and have it read to you — in a natural neural voice, fully offline, without ever creating an account.

## v1 Requirements

Scope for initial paid release (~$3 one-time) on Google Play Store and Apple App Store. Every requirement is user-centric, testable, and atomic. Categories follow the feature surfaces identified in research.

### Foundation

Scaffolding and compliance groundwork that must land in Phase 1 so later phases aren't blocked at submission time.

- [x] **FND-01**: App launches on Android and iOS from a signed build with the correct bundle ID (`com.yourname.murmur`) and a placeholder splash / icon
- [ ] **FND-02**: App navigates between Library, Reader, and Settings routes using go_router
- [ ] **FND-03**: Riverpod provider scope is installed at the app root and survives hot reload
- [ ] **FND-04**: Drift database initializes on first launch with schema versioning wired up for future migrations
- [ ] **FND-05**: Light, sepia, dark, and OLED-black themes are defined and follow the system theme by default
- [ ] **FND-06** (amended per Phase 1 D-21): Reader font assets are bundled and loadable — **2 curated serif families: Literata and Merriweather**, Regular (400) + Bold (700) weights each, OFL-licensed, bundled as .ttf under `assets/fonts/`. No sans-serif in v1. (Original wording: "3–4 curated font families.")
- [ ] **FND-07**: iOS Info.plist declares `UIBackgroundModes: audio`, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`, EPUB `CFBundleDocumentTypes`, and `ITSAppUsesNonExemptEncryption=false`
- [ ] **FND-08**: Android manifest declares `FOREGROUND_SERVICE_MEDIA_PLAYBACK` and `READ_MEDIA_*` permissions appropriate to the target SDK
- [ ] **FND-09** (amended per Phase 1 D-06): CI (GitHub Actions) builds a signed debug Android AAB on every push to main using a committed debug keystore, and provides a `workflow_dispatch`-only iOS scaffold job that runs `flutter build ios --no-codesign` on `macos-14` and uploads the resulting `.xcarchive` as a workflow artifact. Full FND-09 wording ("signed Android AAB and iOS IPA on every push") is restored in Phase 4 once Apple Developer Program enrollment lands. Original wording: "CI builds signed debug Android AAB and iOS IPA on every push to main."
- [ ] **FND-10**: Local-only crash logging writes errors to an on-device log file (no Sentry, no Firebase, no network)

### Library

EPUB import, persistence, and browsing. Responsive for phones + tablets.

- [x] **LIB-01**: User can import one or more DRM-free EPUB files via the system file picker (batch import)
- [x] **LIB-02**: User can import an EPUB via Share / Open-in intent from another app (iOS document provider + Android `ACTION_VIEW`)
- [x] **LIB-03**: Importer parses EPUB metadata (title, author, cover image, chapter list) and persists to Drift DB on a 15-EPUB test corpus without crashes
- [x] **LIB-04**: Corrupt or DRM'd EPUB import surfaces a friendly snackbar error and leaves the library unchanged
- [x] **LIB-05**: User sees a responsive library grid — 2 cols on phone portrait, 3 on phone landscape, 4–6 on tablets
- [x] **LIB-06**: Each book card shows cover art, title, author, and a reading-progress ring
- [x] **LIB-07**: User can sort the library by recently read, title, or author
- [x] **LIB-08**: User can search the library by title or author
- [x] **LIB-09**: User can long-press a book to open a context sheet with "Book Info" and "Delete"
- [x] **LIB-10**: Empty library state shows an illustration and an "Import your first book" CTA
- [x] **LIB-11**: Library state persists across app restarts

### Reader

Reading experience with sentence-span rendering baked in from day one.

- [x] **RDR-01**: Opening a book loads its chapter list and resumes the user's last reading position (or start of book if first open)
- [x] **RDR-02**: Reader renders chapters as a `PageView` of paginated content — one chapter per page run, not a monolithic scroll
- [x] **RDR-03**: Chapter text is rendered via per-paragraph `RichText` inside a `ListView.builder` with `RepaintBoundary` around each paragraph
- [x] **RDR-04**: Every visible paragraph is composed of one `TextSpan` per `Sentence`, from a shared `Sentence` data model (sentence-span rendering is the permanent reader architecture, not a Phase 5 retrofit)
- [x] **RDR-05**: `Semantics` is applied at the paragraph level so VoiceOver / TalkBack read paragraphs, not sentence-by-sentence
- [x] **RDR-06**: User can change font size via a slider (12–28pt) and see the change apply immediately
- [x] **RDR-07**: User can pick a font family from 3–4 bundled options
- [x] **RDR-08**: User can switch between light, sepia, dark, and OLED-black reader themes and the change persists
- [x] **RDR-09**: Tablet layouts show a persistent chapter sidebar (~300px) on the left; phone layouts show a slide-over chapter drawer opened from the app bar
- [x] **RDR-10**: User can tap a chapter in the sidebar/drawer to jump; the current chapter is visually highlighted
- [x] **RDR-11**: Reading progress is saved to Drift DB on page turn, debounced at 2 seconds, and correctly resumes on reopen
- [x] **RDR-12**: Tapping the center of the reader toggles app-bar and playback-bar chrome (immersive mode)
- [ ] **RDR-13**: User can tap a ribbon icon to save the current position as a bookmark and see it listed in the chapter panel/drawer
- [ ] **RDR-14**: Tapping a bookmark jumps to its saved position

### TTS Engine

On-device Kokoro-82M synthesis with sentence-level control and pre-buffering.

- [ ] **TTS-01**: On first launch, user sees a one-time "Download voice model (~80MB)" prompt with a "Prefer Wi-Fi" honor-system toggle that defaults to ON — the app does not enforce network type
- [ ] **TTS-02**: Model download fetches `model.int8.onnx` from a pinned URL, verifies its SHA-256, and stores it under app documents
- [ ] **TTS-03**: `voices.bin`, `tokens.txt`, and `espeak-ng-data/` are bundled with the app (no network fetch)
- [ ] **TTS-04**: If the model download fails or is interrupted, the user sees a recoverable retry flow; partial files are cleaned up
- [ ] **TTS-05**: TTS synthesis runs on a long-lived worker Dart isolate; the UI isolate never calls Sherpa-ONNX synchronous APIs
- [ ] **TTS-06**: `SentenceSplitter` in pure Dart splits chapter text into `List<Sentence>` and passes a 500+ fixture test suite drawn from real English fiction (abbreviations, decimals, ellipses, dialogue, em-dashes, curly/straight quotes, Unicode whitespace)
- [ ] **TTS-07**: `TtsQueue` pre-synthesizes the next sentence while the current sentence plays, keeps the last 3 played sentences in a ring buffer to support backward skip
- [ ] **TTS-08**: Kokoro output (24 kHz Float32 mono) is wrapped in a WAV container per sentence and fed to `just_audio` via `AudioSource.file` (no `StreamAudioSource`)
- [ ] **TTS-09**: Sherpa `length_scale` is fixed at 1.0; runtime playback speed is owned exclusively by `just_audio.setSpeed()`
- [ ] **TTS-10**: First-sentence playback starts within 300ms of pressing play on a mid-range device

### TTS Playback

Controls, coordination, and listening UX.

- [ ] **PBK-01**: Playback bar exposes play/pause, a chapter progress scrubber, and a speed selector (0.75× / 1× / 1.25× / 1.5× / 2×)
- [ ] **PBK-02**: User can skip forward one sentence and back one sentence from the playback bar
- [ ] **PBK-03**: User can select a voice from a curated list of ~10 English Kokoro voices, each with a short (<2s) preview button
- [ ] **PBK-04**: User can set per-book voice and per-book playback speed preferences that override the global defaults
- [ ] **PBK-05**: As each sentence completes, the reader automatically advances (page or scroll) to keep the active sentence on screen
- [ ] **PBK-06**: The currently-spoken sentence is visually highlighted in the reader with theme-appropriate color and contrast
- [ ] **PBK-07**: The reader auto-scrolls so the highlighted sentence stays in the viewport (center or upper third)
- [ ] **PBK-08**: Reader and TTS coordinate via a single shared `playbackStateProvider` — no direct feature-to-feature imports
- [ ] **PBK-09**: Audio continues playing when the app is backgrounded (iOS and Android)
- [ ] **PBK-10**: Lock screen / notification media controls show current book + chapter and support play/pause and next-chapter via `audio_service`
- [ ] **PBK-11**: Sleep timer offers 15 / 30 / 45 minute and "end of chapter" options with countdown shown in the playback bar
- [ ] **PBK-12**: Audio session interruptions (incoming call, Siri, other app playback) pause murmur and resume cleanly on interruption end

### Settings

Global configuration surface.

- [ ] **SET-01**: User can set default font size, font family, and theme from Settings and see them applied on the next book open
- [ ] **SET-02**: User can set default voice and default playback speed from Settings
- [ ] **SET-03**: Settings shows TTS model status (installed / not installed), storage used, and a "Re-download model" button
- [ ] **SET-04**: Settings has a "Crash log" entry that opens the local crash log file for viewing and manual share
- [ ] **SET-05**: Settings has an About screen with version, license acknowledgments (Flutter, Sherpa-ONNX, Kokoro, etc.), and a truthful privacy statement

### Onboarding

First-launch experience.

- [ ] **ONB-01**: First-launch flow walks the user through model download (with "Prefer Wi-Fi" honor-system toggle) and importing their first EPUB
- [ ] **ONB-02**: After onboarding, the library opens in its empty state with a clear "Import your first book" CTA if no book was imported

### Quality & Distribution

Non-feature guarantees required to ship.

- [ ] **QAL-01**: Reader scrolls at 60fps on a mid-range phone and mid-range tablet profile build with a 1000-page EPUB loaded
- [ ] **QAL-02**: A 2-hour continuous TTS playback session shows no measurable memory leak on iOS and Android
- [ ] **QAL-03**: All interactive elements have semantic labels and a minimum 48×48px touch target
- [ ] **QAL-04**: Every phase is tested on at least one physical iOS device and one physical Android device before being marked done
- [ ] **QAL-05**: A signed Android AAB is uploaded to the Play Store as a paid app at ~$3 with IARC content rating completed and privacy labels declaring "Data Not Collected"
- [ ] **QAL-06**: A signed iOS build is uploaded to App Store Connect as a paid app at ~$3 with export compliance answered, age rating set, and privacy labels declaring "Data Not Collected"
- [ ] **QAL-07**: Store listings include phone + tablet screenshots and a truthful privacy policy
- [ ] **QAL-08**: README documents the full local build flow for both platforms including Sherpa-ONNX native linking notes

## v2 Requirements

Acknowledged post-launch scope. Not in the v1 roadmap.

### Catalog

- **CAT-01**: OPDS catalog browsing for Calibre / Thorium-compatible libraries (highest-impact post-launch differentiator for power users)

### Library Organization

- **LIB-12**: Collections / tags / series grouping beyond flat sort
- **LIB-13**: Import from cloud drives (Dropbox, iCloud Drive) via system Files app (read-only, no API tokens)

### Reader

- **RDR-15**: Continuous-scroll reader mode as an alternative to paginated
- **RDR-16**: Dictionary lookup on long-press

### TTS

- **TTS-11**: Non-English Kokoro language support (pairs with its own sentence splitter per language)
- **TTS-12**: More than 10 voices exposed in an "Advanced voices" submenu
- **TTS-13**: Sub-sentence streaming via `generateWithCallback` (Phase 7 optimization)

### Export

- **EXP-01**: Export synthesized audio as a single MP3/M4B per chapter or book (fully local, no upload)

## Out of Scope

Explicit exclusions. Reasoning included to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Accounts / login / any identity system | Privacy is the product; no backend, ever |
| Cloud sync of library, progress, or bookmarks | Same — fully local is the whole value prop |
| Telemetry, analytics, crash reporting over the network | Principle AND architectural constraint |
| Non-EPUB formats (PDF, MOBI, AZW3, TXT, FB2) | PDF alone would double reader complexity; others are niche |
| Non-English languages in v1 | Needs its own splitter / normalizer / voices; defer to v2 |
| Audiobook (MP3 / M4B / AAC) import or playback | murmur *generates* audio from text; not a general audiobook player |
| DRM'd books | No, and never |
| Annotations, highlights, note-taking | Bookmarks only — avoids a whole category of scope |
| Reading stats, streaks, gamification | Wrong vibe for a focused reading app |
| Social features, sharing, export of activity | See "privacy is the product" |
| Desktop builds (macOS / Windows / Linux) | Not the target form factor, not worth the platform burden |
| Phone OS system-TTS fallback | Kokoro neural quality is the differentiator; system voices are explicitly off the table |
| Per-dialogue multi-voice synthesis (@Voice style) | High complexity, high failure rate, distracts from core quality |
| OS system voice fallback if Kokoro fails | Fail loudly instead — system voices would degrade the value prop silently |
| `flutter_widget_from_html` / `flutter_html` / `webview_flutter` as reader renderer | Cannot expose per-sentence spans; contradicts the sentence-span architectural commitment |
| `epub_view` package | Transitively depends on `flutter_html` — same reason as above |
| `StreamAudioSource` for real-time PCM streaming | Experimental, unstable on real devices; use WAV-wrap + file-based `AudioSource.file` instead |
| Sherpa `length_scale` for runtime speed | Compound-speed trap with `just_audio.setSpeed()`; one owner only |

## Traceability

Every v1 requirement maps to exactly one phase. Populated by the roadmapper on 2026-04-11.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FND-01 | Phase 1 | Complete |
| FND-02 | Phase 1 | Pending |
| FND-03 | Phase 1 | Pending |
| FND-04 | Phase 1 | Pending |
| FND-05 | Phase 1 | Pending |
| FND-06 | Phase 1 | Pending |
| FND-07 | Phase 1 | Pending |
| FND-08 | Phase 1 | Pending |
| FND-09 | Phase 1 | Pending |
| FND-10 | Phase 1 | Pending |
| LIB-01 | Phase 2 | Complete |
| LIB-02 | Phase 2 | Complete |
| LIB-03 | Phase 2 | Complete |
| LIB-04 | Phase 2 | Complete |
| LIB-05 | Phase 2 | Complete |
| LIB-06 | Phase 2 | Complete |
| LIB-07 | Phase 2 | Complete |
| LIB-08 | Phase 2 | Complete |
| LIB-09 | Phase 2 | Complete |
| LIB-10 | Phase 2 | Complete |
| LIB-11 | Phase 2 | Complete |
| RDR-01 | Phase 3 | Complete |
| RDR-02 | Phase 3 | Complete |
| RDR-03 | Phase 3 | Complete |
| RDR-04 | Phase 3 | Complete |
| RDR-05 | Phase 3 | Complete |
| RDR-06 | Phase 3 | Complete |
| RDR-07 | Phase 3 | Complete |
| RDR-08 | Phase 3 | Complete |
| RDR-09 | Phase 3 | Complete |
| RDR-10 | Phase 3 | Complete |
| RDR-11 | Phase 3 | Complete |
| RDR-12 | Phase 3 | Complete |
| RDR-13 | Phase 6 | Pending |
| RDR-14 | Phase 6 | Pending |
| TTS-01 | Phase 4 | Pending |
| TTS-02 | Phase 4 | Pending |
| TTS-03 | Phase 4 | Pending |
| TTS-04 | Phase 4 | Pending |
| TTS-05 | Phase 4 | Pending |
| TTS-06 | Phase 4 | Pending |
| TTS-07 | Phase 4 | Pending |
| TTS-08 | Phase 4 | Pending |
| TTS-09 | Phase 4 | Pending |
| TTS-10 | Phase 4 | Pending |
| PBK-01 | Phase 4 | Pending |
| PBK-02 | Phase 4 | Pending |
| PBK-03 | Phase 4 | Pending |
| PBK-04 | Phase 4 | Pending |
| PBK-05 | Phase 5 | Pending |
| PBK-06 | Phase 5 | Pending |
| PBK-07 | Phase 5 | Pending |
| PBK-08 | Phase 4 | Pending |
| PBK-09 | Phase 4 | Pending |
| PBK-10 | Phase 4 | Pending |
| PBK-11 | Phase 6 | Pending |
| PBK-12 | Phase 4 | Pending |
| SET-01 | Phase 6 | Pending |
| SET-02 | Phase 6 | Pending |
| SET-03 | Phase 6 | Pending |
| SET-04 | Phase 6 | Pending |
| SET-05 | Phase 6 | Pending |
| ONB-01 | Phase 6 | Pending |
| ONB-02 | Phase 6 | Pending |
| QAL-01 | Phase 6 | Pending |
| QAL-02 | Phase 6 | Pending |
| QAL-03 | Phase 6 | Pending |
| QAL-04 | Phase 6 | Pending |
| QAL-05 | Phase 7 | Pending |
| QAL-06 | Phase 7 | Pending |
| QAL-07 | Phase 7 | Pending |
| QAL-08 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 72 total
- Mapped to phases: 72
- Unmapped: 0

**Per-phase requirement counts:**

| Phase | Count | Requirements |
|-------|-------|--------------|
| Phase 1: Scaffold & Compliance Foundation | 10 | FND-01..10 |
| Phase 2: Library & EPUB Import | 11 | LIB-01..11 |
| Phase 3: Reader with Sentence-Span Architecture | 12 | RDR-01..12 |
| Phase 4: TTS Engine & Playback Foundation | 18 | TTS-01..10, PBK-01, PBK-02, PBK-03, PBK-04, PBK-08, PBK-09, PBK-10, PBK-12 |
| Phase 5: Sentence Highlighting & Two-Way Sync | 3 | PBK-05, PBK-06, PBK-07 |
| Phase 6: Polish, Accessibility & Ship Readiness | 14 | RDR-13, RDR-14, PBK-11, SET-01..05, ONB-01, ONB-02, QAL-01..04 |
| Phase 7: Paid Distribution | 4 | QAL-05, QAL-06, QAL-07, QAL-08 |

---
*Requirements defined: 2026-04-11*
*Last updated: 2026-04-11 — traceability populated by roadmapper (72/72 v1 requirements mapped)*
