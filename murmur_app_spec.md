# murmur — Flutter TTS Ebook Reader
## Spec-Driven Development Plan

---

## 1. Project Overview

**Goal:** A beautiful, ad-free, fully local ebook reader for Android and iOS (phones + tablets) that turns EPUBs you already own into audiobooks using on-device neural TTS.

**Target user:** People who own EPUBs and want to listen to them as audiobooks — without handing their library to a cloud service or paying a subscription.

**Core philosophy:**
- Privacy-first: no accounts, no telemetry, no network required after initial model download. This is both a principle and a constraint — there is no backend, ever.
- Local-only by design: your library, your progress, your bookmarks all live on-device.
- Neural TTS quality: Kokoro-82M via Sherpa-ONNX, not OS system voices.
- Reader-first UI: typography and layout are primary, controls are secondary.
- Phones and tablets are both first-class; tablet layouts take advantage of the extra space, phone layouts are not afterthoughts.

**Distribution:** One-time purchase (~$3) on Play Store and App Store. No free tier, no IAP, no ads, no subscription.

---

## 1a. Non-Goals

Explicit things this app will not do, to keep scope honest:

- **No cloud sync.** Progress, bookmarks, and library live on the device they were created on.
- **No accounts or login.** Ever.
- **No telemetry or analytics**, not even anonymized.
- **No formats other than EPUB.** No PDF, MOBI, AZW3, TXT, FB2. If it's not EPUB, it's not in scope.
- **No languages other than English** in v1. Kokoro's other languages can come later if the app finds an audience.
- **No audiobook (MP3/M4B) import or playback.** This app generates audio from text; it is not a general audiobook player.
- **No DRM'd books.** Only user-owned, DRM-free EPUBs.
- **No annotations, highlights, or note-taking.** Bookmarks only.
- **No reading stats, streaks, or gamification.**
- **No social, sharing, or export of reading activity.**
- **No desktop builds** (macOS / Windows / Linux).

---

## 2. Tech Stack

| Concern | Choice | Rationale |
|---|---|---|
| Framework | Flutter (Dart) | Single codebase, excellent tablet support, strong UI control |
| TTS Engine | `sherpa_onnx` (pub.dev) | Official Flutter bindings, supports Kokoro/Piper offline |
| TTS Model | Kokoro-82M (int8 ONNX) | ~80MB, sub-0.3s latency, natural prosody, CPU-only |
| EPUB Parsing | `epub_view` + `epub_kit` | TOC, chapter extraction, metadata |
| Local DB | `drift` (SQLite) | Progress tracking, library metadata, settings |
| File Storage | `path_provider` + `flutter_file_picker` | Cross-platform file import |
| State Management | `riverpod` | Predictable, testable, Claude-friendly |
| Audio Playback | `just_audio` | Streams PCM from Sherpa-ONNX output |

---

## 3. Feature Specification

### 3.1 Library Screen
- Responsive grid: phone portrait 2 cols, phone landscape 3, tablet portrait 4, tablet landscape 5–6. Phone is first-class, not a fallback.
- Book cards: cover art, title, author, progress bar, last-read timestamp
- Import books via system file picker (EPUB only)
- Sort by: recently read, title, author, progress
- Search by title/author
- Long-press context menu: delete, book info
- Empty state with import prompt

### 3.2 Reader Screen
- Paginated horizontal swipe (like a book) OR continuous scroll — user setting
- Clean typography: font family picker, font size slider, line spacing
- Themes: light, sepia, dark, OLED black
- Chapter navigation: tablet → persistent sidebar panel; phone → slide-over drawer opened from app bar
- Progress indicator: "Chapter 3 of 18 · 42%"
- Tap center to toggle UI chrome (immersive mode)
- Bookmarks: tap ribbon icon, list in chapter panel/drawer

### 3.3 TTS Playback
- Play/pause button in floating bottom bar
- Current sentence highlighted in reader text
- Playback speed: 0.5×, 0.75×, 1×, 1.25×, 1.5×, 2×
- Voice selector: ~10 hand-curated English Kokoro voices with short preview button. The other 43 are intentionally hidden — curation is a feature, not a limitation.
- Auto-advance: TTS follows reading position, or reading position follows TTS
- Sleep timer: stop after N minutes or end of chapter
- Background audio: continues when app is backgrounded, lock screen controls

### 3.4 TTS Engine (On-Device)
- Kokoro-82M ONNX model bundled or downloaded on first launch
- English-only text normalization and sentence splitting in v1
- Sentence-boundary detection before feeding to model (NLTK-style rules in Dart)
- Stream sentences to TTS sequentially, pre-buffer next sentence while current plays
- Sentence-level highlighting: highlight current sentence during playback (character-timed approximation)
- Network is required *once* to download the model; after that, never again

### 3.5 Settings
- TTS model management: download status, storage used, re-download
- Default voice, speed, theme
- Reader font preferences
- Storage location for books
- About / licenses

---

## 4. Architecture

```
lib/
├── main.dart
├── app/
│   ├── router.dart          # go_router route definitions
│   └── theme.dart           # ThemeData, typography tokens
├── features/
│   ├── library/
│   │   ├── data/            # BookRepository, file import logic
│   │   ├── domain/          # Book model, LibraryState
│   │   └── ui/              # LibraryScreen, BookCard, ImportButton
│   ├── reader/
│   │   ├── data/            # EpubParser, ProgressRepository
│   │   ├── domain/          # ReaderState, Chapter, Bookmark
│   │   └── ui/              # ReaderScreen, PageView, ChapterSidebar
│   └── tts/
│       ├── data/            # SherpaOnnxService, ModelManager
│       ├── domain/          # TtsState, SentenceQueue
│       └── ui/              # PlaybackBar, VoiceSelector, SpeedPicker
├── shared/
│   ├── db/                  # Drift database, DAOs
│   ├── widgets/             # Shared UI components
│   └── utils/               # Sentence splitter, text cleaner
└── assets/
    └── models/              # Kokoro ONNX model files (or downloaded here)
```

---

## 5. Development Phases

---

### Phase 1 — Scaffold & Foundation
**Goal:** Running app with navigation, theme, and empty screens.

**Spec:**
- [ ] Flutter project created with correct package name (`com.yourname.murmur`)
- [ ] `go_router` configured with routes: `/library`, `/reader/:bookId`, `/settings`
- [ ] `riverpod` provider scope at root
- [ ] Theme: light and dark ThemeData defined, system-aware switching
- [ ] Typography tokens defined (font scales, reader fonts loaded as assets)
- [ ] `drift` database initialized with `books` and `reading_progress` tables
- [ ] Bottom navigation or sidebar navigation (tablet-aware layout)
- [ ] Placeholder screens for Library, Reader, Settings

**Done when:** App runs on tablet emulator, can navigate between all screens.

---

### Phase 2 — Library & Book Import
**Goal:** Import EPUBs, display them in a grid, persist metadata.

**Spec:**
- [ ] `flutter_file_picker` opens system picker filtered to `.epub`
- [ ] EPUB parsed on import: extract title, author, cover image, chapter list
- [ ] Metadata + cover stored in `drift` DB; cover cached as file
- [ ] Library grid renders `BookCard` widgets from DB
- [ ] `BookCard`: cover image, title (truncated), author, progress ring
- [ ] Sort dropdown: recent / title / author
- [ ] Search bar filters visible books
- [ ] Long-press sheet: "Book Info", "Delete"
- [ ] Empty state illustration + "Import your first book" CTA
- [ ] Error handling: corrupt EPUB shows snackbar, not crash

**Done when:** Can import 5+ EPUBs, they display correctly, persist after restart.

---

### Phase 3 — Reader Core
**Goal:** Read an EPUB with good typography, pagination, chapter navigation.

**Spec:**
- [ ] `ReaderScreen` receives `bookId`, loads chapter list
- [ ] Paginated view: `PageView` rendering chapter content. **Renderer choice is a v1 architectural commitment: sentence spans are a first-class data structure from day one.** `flutter_widget_from_html` is explicitly off the table because it cannot expose per-sentence spans. The chapter pipeline is: EPUB HTML → stripped/normalized text → list of `Sentence { id, text, styleRuns }` → `RichText` of `TextSpan` per sentence. Phase 5 highlighting drops in without a rewrite.
- [ ] Font size slider (12–28pt), font family picker (3–4 options)
- [ ] Light / sepia / dark / OLED black themes apply to reader background + text
- [ ] Chapter panel: list of chapters, tap to jump, current chapter highlighted. Persistent sidebar on tablet, slide-over drawer on phone.
- [ ] Reading progress saved to DB on page turn (debounced 2s)
- [ ] Resume position on re-open
- [ ] Tap center toggles UI chrome (app bar, bottom bar)
- [ ] Immersive/fullscreen mode when chrome hidden

**Done when:** Can read any imported EPUB comfortably from start to finish, on both phone and tablet.

---

### Phase 4 — TTS Engine Integration
**Goal:** On-device Kokoro TTS plays the book aloud.

**Spec:**
- [ ] `sherpa_onnx` package added, Kokoro-82M ONNX model assets configured
- [ ] `ModelManager`: checks if model exists, downloads if not (with progress UI), handles storage
- [ ] `SherpaOnnxService`: wraps `sherpa_onnx` Flutter API, exposes `Future<AudioData> synthesize(String text)`
- [ ] `SentenceSplitter`: pure Dart, splits chapter text into sentences at `.`, `!`, `?` boundaries (handles abbreviations, decimals)
- [ ] `TtsQueue`: manages sentence queue, pre-synthesizes next sentence while current plays
- [ ] `just_audio` player receives PCM chunks from Sherpa output
- [ ] Playback bar: play/pause, progress scrubber within chapter, speed selector
- [ ] Speed selector: 0.75×, 1×, 1.25×, 1.5×, 2× (Sherpa `length_scale` param)
- [ ] Voice selector: curated list of ~10 English Kokoro voices, each with a ~2s preview button. Voice IDs and display names live in a single source-of-truth constant so the curated set is easy to tweak.
- [ ] TTS advances reader position: as each sentence completes, reader scrolls/pages to keep up
- [ ] Background audio: `audio_service` package keeps TTS alive when app backgrounded
- [ ] Lock screen controls: play/pause, next chapter via `audio_service` media notification

**Done when:** Can start TTS on any chapter, it plays to completion, advances through book, works backgrounded.

---

### Phase 5 — Sentence Highlighting
**Goal:** Currently-spoken sentence is highlighted in the reader text.

**Spec:**
- [ ] Reader text rendered as `RichText` with `TextSpan` per sentence (not raw HTML)
- [ ] `TtsState` exposes `currentSentenceIndex`
- [ ] Reader rebuilds `RichText` when `currentSentenceIndex` changes, applying highlight color to active span
- [ ] Highlight color: theme-aware (e.g., amber 30% opacity on light, blue 30% on dark)
- [ ] Reader auto-scrolls to keep highlighted sentence in viewport (center or upper-third)
- [ ] Timing: sentence highlight advances when `just_audio` position crosses sentence boundary (estimated from character count + speed)

**Note:** Because Phase 3 committed to sentence spans as a first-class data structure, this phase adds highlighting *on top of* the existing renderer rather than refactoring it. If Phase 5 feels like it requires rewriting Phase 3, that's a signal Phase 3 was built wrong.

**Done when:** Reading along visually while TTS plays feels natural and in sync on both phone and tablet.

---

### Phase 6 — Polish & Responsive UX
**Goal:** App feels like a real product, not a prototype, on every supported form factor.

**Spec:**
- [ ] Bookmarks: tap bookmark icon to save position, list in chapter panel/drawer, tap to jump
- [ ] Sleep timer: bottom sheet selector (15 / 30 / 45 min / end of chapter), countdown shown in playback bar
- [ ] Smooth animations: page turns, panel/drawer open/close, playback bar appear/hide
- [ ] Haptic feedback on key interactions (iOS/Android)
- [ ] Layouts tested in landscape + portrait on: 5–6" phone, 10" tablet, 11" tablet, 12" tablet
- [ ] iPad split-view compatible
- [ ] Accessibility: semantic labels on all interactive elements, min touch target 48×48px
- [ ] Settings screen: font defaults, theme default, TTS defaults, model storage info
- [ ] Onboarding: first-launch flow (model download prompt, import first book)
- [ ] App icon + splash screen

**Done when:** Indistinguishable from a polished App Store app, on phone and tablet alike.

---

### Phase 7 — Stability & Paid Distribution
**Goal:** A shippable, stable paid build on both stores.

**Spec:**
- [ ] Error boundaries on all async operations (import, TTS synthesis, file I/O)
- [ ] Crash logging is local-only — errors write to an on-device log the user can view and share manually. No Sentry, Firebase Crashlytics, or any network-delivered telemetry.
- [ ] Performance: reader scroll at 60fps on mid-range phone *and* tablet, TTS latency <300ms sentence start
- [ ] Memory: test with 1000-page EPUB, no leak over 2hr session
- [ ] Android: signed AAB uploaded to Play Store as a paid app (~$3, one-time). No IAP, no subscription, no ads.
- [ ] iOS: signed build uploaded to App Store Connect as a paid app (~$3, one-time). TestFlight build for beta.
- [ ] Store listings: screenshots on phone + tablet, privacy policy that truthfully says "this app collects nothing and sends nothing"
- [ ] README with build instructions

---

## 6. Claude Code Prompting Strategy

### Starting a phase
Always open with the spec section:
```
We're starting Phase 2 of the murmur app. Here's the spec: [paste phase spec].
Before writing any code, confirm your understanding of the architecture
and what files you'll create or modify.
```

### Keeping context tight
- Keep `SPEC.md` (this file) in the repo root — reference it in prompts
- After each session, ask Claude: "Summarize what was built and what's next"
- Commit after each working milestone so Claude can diff cleanly

### Hard problems to break out separately
- Sentence splitter: ask Claude to write and test it in isolation first
- Sherpa-ONNX setup: ask Claude to start with a minimal TTS test script before integrating
- RichText sentence spans: prototype in a separate throwaway widget first

### When things go wrong
```
This isn't working: [error]. Here's the relevant code: [paste].
Don't rewrite everything — identify the minimal fix.
```

---

## 7. Key Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Navigation
  go_router: ^14.0.0
  
  # State
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  
  # EPUB
  epub_view: ^4.2.0
  
  # TTS
  sherpa_onnx: ^1.10.0
  just_audio: ^0.9.36
  audio_service: ^0.18.12
  
  # File handling
  file_picker: ^8.0.0
  path_provider: ^2.1.0
  
  # Database
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  
  # (No HTML widget library — reader uses a custom sentence-span renderer.
  #  No network image library — all covers and assets are local.)

dev_dependencies:
  drift_dev: ^2.18.0
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.0
```

---

## 8. Model Assets

Kokoro-82M ONNX files to include or download on first launch:

```
assets/models/kokoro/
├── kokoro-v0_19.int8.onnx     (~82MB — download on first launch)
├── voices.bin                  (~3MB — ship with app)
└── tokens.txt                  (~1KB — ship with app)
```

**Strategy:** Ship `voices.bin` and `tokens.txt` with the app bundle. On first launch, show a one-time "Download voice model (82MB)" prompt and fetch `kokoro-v0_19.int8.onnx` from a GitHub release or Hugging Face. Store in app documents directory.

---

## 9. MVP Definition

The app is MVP-complete after **Phase 5**:
- Import EPUBs ✓
- Read them with good typography ✓  
- Play TTS with on-device Kokoro ✓
- Sentence highlighting ✓
- No ads, no accounts, no cloud ✓

Phases 6–7 take it from MVP to product.
