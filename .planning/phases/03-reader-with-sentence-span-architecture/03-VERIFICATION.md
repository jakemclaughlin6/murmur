---
phase: 03-reader-with-sentence-span-architecture
verified: 2026-04-12T19:00:00Z
status: human_needed
score: 8/8 must-haves verified
overrides_applied: 1
overrides:
  - must_have: "User can change font family from 3-4 bundled options and see change apply immediately and persist"
    reason: "Phase 1 D-21 formally amended FND-06 to 2 curated serif families (Literata + Merriweather). Implementation ships exactly 2 families per the amended scope. RDR-07 text in REQUIREMENTS.md was not retroactively updated but 03-CONTEXT.md documents the accepted scope reduction. The change applies immediately and persists as required."
    accepted_by: "gsd-verifier"
    accepted_at: "2026-04-12T19:00:00Z"
re_verification:
  previous_status: human_needed
  previous_score: 5/5
  gaps_closed:
    - "EPUB images with relative src paths (../images/fig.png) now resolve via multi-level fallback"
    - "Scroll progress correctly attributes chapter index from itemBuilder (not stale closure)"
    - "Reading progress flush awaits DB write on app pause"
    - "Dead ternary in list bullet removed (WR-02)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "60fps reader scroll on mid-range Android phone"
    expected: "Scrolling through a chapter with 300+ blocks renders at 60fps with no jank or frame drops"
    why_human: "Performance cannot be verified without a physical device; DevTools profiling required"
  - test: "Immersive mode center-third tap on physical device"
    expected: "Tapping the center horizontal third of the screen hides/shows the app bar; tapping left/right thirds does not trigger it"
    why_human: "Tap zone geometry and visual system UI transition cannot be verified from source code alone"
  - test: "Typography sheet reflow immediacy on physical device"
    expected: "Moving the font size slider causes the chapter text to reflow in real time with no perceptible lag"
    why_human: "UI responsiveness requires device rendering measurement"
  - test: "Scroll position resume on physical device"
    expected: "Closing and reopening a book returns to the exact chapter and approximate scroll position last read"
    why_human: "End-to-end behavior across app lifecycle requires running the app on a device"
  - test: "Plan 05 Task 3 full human verification checklist (14 steps)"
    expected: "All 14 plan checklist items pass on a physical Android device: sidebar on tablet, drawer on phone, typography controls, immersive mode, progress persistence, etc."
    why_human: "Plan 05 was marked autonomous: false; Task 3 is a human-only verification checkpoint requiring a physical Android device"
---

# Phase 3: Reader with Sentence-Span Architecture — Verification Report

**Phase Goal:** Users can open any imported EPUB on phone or tablet and read it start-to-finish with good typography, chapter navigation, and resume-on-reopen — and every paragraph is rendered as a RichText of one TextSpan per Sentence (the permanent reader architecture, not a retrofit)
**Verified:** 2026-04-12T19:00:00Z
**Status:** human_needed
**Re-verification:** Yes — after Plan 06 gap closure (image path resolution + code review warnings WR-01, WR-02, WR-03)

## Goal Achievement

### Observable Truths

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | Every paragraph renders as a RichText with one TextSpan per Sentence (permanent architecture) | VERIFIED | `ParagraphWidget` splits via `splitter.split(text)`, maps each `Sentence` to a child `TextSpan` in `RichText`; `renderBlock()` routes `Paragraph` blocks through `ParagraphWidget` via exhaustive sealed switch |
| 2 | Users can navigate between chapters (horizontal PageView on phone and tablet) | VERIFIED | `ReaderScreen` builds `PageView.builder` over chapters; `ChapterSidebar` (tablet) and `ChapterDrawer` (phone) both call `_pageController?.jumpToPage(i)` |
| 3 | Reading progress persists and resumes on reopen | VERIFIED | `ReaderNotifier.build()` reads `book.readingProgressChapter` from Drift; `ReadingProgressNotifier` debounces at 2s and is now async (`Future<void> flushNow()` with `await _db.updateReadingProgress(...)`); flushes on `AppLifecycleState.paused` and `onDispose` |
| 4 | Responsive layout adapts to phone and tablet at the 600dp breakpoint | VERIFIED | `reader_screen.dart` branches on `MediaQuery.of(context).size.shortestSide >= 600`: tablet shows collapsible `ChapterSidebar` (300px), phone shows `ChapterDrawer` in `Scaffold.drawer` slot |
| 5 | Typography controls and immersive mode work in the reader | VERIFIED | `TypographySheet` exposes font-size slider (12-28pt) and font-family picker; `reader_screen.dart` uses `SystemUiMode.immersiveSticky` on center-third tap with `WidgetsBindingObserver` for cleanup; `unawaited(flushNow())` wrapper on lifecycle call site |
| 6 | EPUB images with relative src paths resolve to local files and render | VERIFIED | `_ImageBlockWidget` uses fallback chain: `imagePathMap?[href] ?? imagePathMap?[p.normalize(href)] ?? imagePathMap?[p.basename(href)]`; `ImageExtractor.extractImages()` maps normalized and multi-level stripped variants |
| 7 | Scroll progress is attributed to the correct chapter (not stale closure) | VERIFIED | `reader_screen.dart` uses `index` from `itemBuilder` parameter (not `readerState.currentChapterIndex`) in `onScrollChanged` call |
| 8 | VoiceOver/TalkBack reads paragraphs as whole units, not sentence-by-sentence | VERIFIED | `Semantics(label: text)` wraps each `ParagraphWidget` with the full paragraph text; `ExcludeSemantics(child: RichText(...))` prevents per-TextSpan screen reader noise |

**Score:** 8/8 truths verified (includes 5 regression checks + 3 Plan 06 new items)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `lib/core/text/sentence.dart` | Sentence data class | VERIFIED | `const Sentence(this.text)`, `operator ==`, `hashCode`, `toString` — pure Dart, no Flutter deps |
| `lib/core/text/sentence_splitter.dart` | SentenceSplitter with abbreviation set | VERIFIED | `static const _abbreviations` (32 entries), `List<Sentence> split(String text)`, handles decimals and ellipses via O(n) character scan |
| `lib/core/db/app_database.dart` | Drift queries for chapters, progress, book | VERIFIED | `getChaptersForBook`, `updateReadingProgress`, `updateLastReadDate`, `getBook` all present; schema remains v2 |
| `lib/core/epub/image_extractor.dart` | ImageExtractor with path traversal protection + normalize mapping | VERIFIED | `p.canonicalize` + `p.basename` path safety; now also adds `p.normalize(epubHref)` and multi-level sub-path variants via `putIfAbsent` loop |
| `lib/features/reader/providers/font_settings_provider.dart` | FontSizeController (12-28pt) + FontFamilyController | VERIFIED | `minSize=12.0`, `maxSize=28.0`; `availableFamilies=['Literata','Merriweather']`; `SharedPreferences` backed |
| `lib/features/reader/widgets/block_renderer.dart` | Exhaustive Block switch with RepaintBoundary + basename fallback | VERIFIED | All 5 variants; 6 RepaintBoundary usages; `_ImageBlockWidget` now has 3-level fallback chain including `p.normalize` and `p.basename`; dead ternary in ListItem removed (WR-02 closed) |
| `lib/features/reader/widgets/paragraph_widget.dart` | ParagraphWidget with per-sentence TextSpans and Semantics | VERIFIED | `Semantics(label: text)` + `ExcludeSemantics(child: RichText(...))` + one TextSpan per Sentence |
| `lib/features/reader/providers/reader_provider.dart` | ReaderNotifier async notifier keyed by bookId | VERIFIED | `@riverpod class ReaderNotifier extends _$ReaderNotifier`, auto-disposing family, `blocksFromJsonString` lazy deserialization, `on FormatException` safety, `updateLastReadDate` called on open |
| `lib/features/reader/providers/reader_provider.g.dart` | Riverpod codegen output | VERIFIED | Generated file present; provider name `readerProvider` (Riverpod 3 drops class suffix — documented deviation in 03-04-SUMMARY.md) |
| `lib/features/reader/widgets/chapter_page.dart` | ChapterPage with ListView.builder + AutomaticKeepAliveClientMixin | VERIFIED | `AutomaticKeepAliveClientMixin`, `ListView.builder`, calls `renderBlock()` per item, `addPostFrameCallback` for scroll restore |
| `lib/features/reader/reader_screen.dart` | Full ReaderScreen with responsive layout, immersive mode, progress wiring | VERIFIED | Phase 2 `_samplePassage` stub fully removed; watches `readerProvider`, `fontSizeControllerProvider`, `fontFamilyControllerProvider`; WR-01 fixed (`index` param); WR-03 fixed (`unawaited()` wrapper) |
| `lib/features/reader/widgets/chapter_sidebar.dart` | Tablet sidebar (300px) with collapse toggle | VERIFIED | `width: 300`, collapse toggle via `_sidebarCollapsed` state in `reader_screen.dart` |
| `lib/features/reader/widgets/chapter_drawer.dart` | Phone slide-over chapter drawer | VERIFIED | `ChapterDrawer`, `Navigator.of(context).pop()` on chapter tap |
| `lib/features/reader/widgets/typography_sheet.dart` | Typography bottom sheet with slider and picker | VERIFIED | `Slider(min: FontSizeController.minSize, max: FontSizeController.maxSize)`, `FontFamilyController.availableFamilies` iteration |
| `lib/features/reader/providers/reading_progress_provider.dart` | Debounced progress save + async lifecycle flush | VERIFIED | 2s debounce timer; `Future<void> flushNow() async` with `await _flushPending()`; `Future<void> _flushPending() async` with `await _db.updateReadingProgress(...)` (WR-03 closed) |
| `test/core/text/sentence_splitter_test.dart` | Unit tests for SentenceSplitter (21 tests) | VERIFIED | Present and passing |
| `test/widget/reader/block_renderer_test.dart` | Widget tests for all 5 Block variants + new image fallback tests | VERIFIED | 9 tests including basename fallback and normalize fallback scenarios (Plan 06 additions) |
| `test/widget/reader/paragraph_semantics_test.dart` | Widget tests for Semantics + per-sentence spans | VERIFIED | 7 tests covering sentence count, semantics label, font styling, empty input |
| `test/widget/reader/reader_screen_test.dart` | Widget tests for ReaderScreen + ChapterPage | VERIFIED | 5 tests: title display, chapter content, swipe navigation, placeholder, resume position |
| `test/widget/reader/responsive_layout_test.dart` | Widget tests for tablet/phone layout | VERIFIED | 4 tests for sidebar/drawer branching + chapter navigation + highlighting |
| `test/widget/reader/font_settings_test.dart` | Widget tests for typography sheet | VERIFIED | 5 tests for slider and font family picker |
| `test/core/db/reading_progress_debounce_test.dart` | Unit tests for debounce timing and flush | VERIFIED | 4 tests for debounce behavior and flush |
| `test/core/epub/image_extractor_test.dart` | Unit tests including relative path resolution | VERIFIED | Now includes normalize, multi-level stripping, and basename fallback tests (Plan 06 additions) |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `reader_screen.dart` | `readerProvider` | `ref.watch(readerProvider(widget.bookId!))` | WIRED | Watches provider, handles `AsyncValue` states |
| `reader_screen.dart` | `fontSizeControllerProvider` | `ref.watch(fontSizeControllerProvider)` | WIRED | Font size applied to `renderBlock` calls |
| `reader_screen.dart` | `fontFamilyControllerProvider` | `ref.watch(fontFamilyControllerProvider)` | WIRED | Font family applied to `renderBlock` calls |
| `reader_screen.dart` | `readingProgressProvider` | `ref.read(readingProgressProvider.notifier).onScrollChanged(bookId!, index, ...)` | WIRED | Uses `index` from itemBuilder (WR-01 closed) |
| `chapter_page.dart` | `block_renderer.dart` | `renderBlock(widget.blocks[index], ...)` in `itemBuilder` | WIRED | Each block in `ListView.builder` passes through `renderBlock` |
| `block_renderer.dart` | `paragraph_widget.dart` | `ParagraphWidget(text: text, ...)` in `Paragraph` case | WIRED | `Paragraph` variant routes to `ParagraphWidget` |
| `paragraph_widget.dart` | `sentence_splitter.dart` | `splitter.split(text)` | WIRED | Creates per-sentence TextSpan children |
| `reading_progress_provider.dart` | `app_database.dart` | `await _db.updateReadingProgress(...)` | WIRED | Eagerly captured in `build()`; now awaited (WR-03 closed) |
| `reader_provider.dart` | `app_database.dart` | `db.getChaptersForBook`, `db.getBook`, `db.updateLastReadDate` | WIRED | All three Drift queries called in `build()` |
| `reader_screen.dart` | `chapter_sidebar.dart` / `chapter_drawer.dart` | `shortestSide >= 600` branch | WIRED | Tablet renders `ChapterSidebar`, phone renders `ChapterDrawer` |
| `typography_sheet.dart` | `font_settings_provider.dart` | `ref.watch(fontSizeControllerProvider)` + `.notifier` writes | WIRED | Sheet reads and writes both font controllers |
| `block_renderer.dart _ImageBlockWidget` | `imagePathMap` | `imagePathMap?[href] ?? imagePathMap?[p.normalize(href)] ?? imagePathMap?[p.basename(href)]` | WIRED | 3-level fallback chain (Plan 06) |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `reader_screen.dart` | `readerState.chapters` | `db.getChaptersForBook(bookId)` Drift query | Yes — queries `chapters` table ordered by `orderIndex` | FLOWING |
| `chapter_page.dart` | `blocks` | `blocksFromJsonString(chapter.blocksJson)` lazy deserialization | Yes — deserializes stored EPUB content per chapter | FLOWING |
| `reading_progress_provider.dart` | `_pendingBookId/_pendingChapter/_pendingOffset` | Scroll offset callbacks from `ChapterPage.onScrollOffsetChanged` | Yes — written to Drift via `await _db.updateReadingProgress(...)` | FLOWING |
| `font_settings_provider.dart` | `FontSizeController.state` | `SharedPreferences.getDouble('settings.fontSize')` | Yes — reads persisted value, defaults to 18.0 | FLOWING |
| `reader_provider.dart` | `chapterIndex` (initial page) | `book.readingProgressChapter` from Drift `getBook(bookId)` | Yes — reads `readingProgressChapter` column, falls back to 0 | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Sentence model + splitter unit tests (28 tests) | `mise exec -- flutter test test/core/text/` | 28/28 pass | PASS |
| Block renderer widget tests (9 tests, includes Plan 06 image fallback) | `mise exec -- flutter test test/widget/reader/block_renderer_test.dart` | 9/9 pass | PASS |
| ParagraphWidget semantics tests (7 tests) | `mise exec -- flutter test test/widget/reader/paragraph_semantics_test.dart` | 7/7 pass | PASS |
| ReaderScreen widget tests (5 tests) | `mise exec -- flutter test test/widget/reader/reader_screen_test.dart` | 5/5 pass | PASS |
| Responsive layout tests (4 tests) | `mise exec -- flutter test test/widget/reader/responsive_layout_test.dart` | 4/4 pass | PASS |
| Font settings tests (5 tests) | `mise exec -- flutter test test/widget/reader/font_settings_test.dart` | 5/5 pass | PASS |
| Debounce tests (4 tests) | `mise exec -- flutter test test/core/db/reading_progress_debounce_test.dart` | 4/4 pass | PASS |
| Reading progress Drift tests (8 tests) | `mise exec -- flutter test test/core/db/reading_progress_test.dart` | 8/8 pass | PASS |
| Image extractor tests (includes Plan 06 path resolution) | `mise exec -- flutter test test/core/epub/image_extractor_test.dart` | all pass | PASS |
| Full targeted suite (88 tests) | `mise exec -- flutter test test/core/text/ test/widget/reader/ test/core/db/reading_progress_test.dart test/core/db/reading_progress_debounce_test.dart test/core/epub/image_extractor_test.dart test/features/reader/` | 88/88 pass | PASS |
| 60fps scroll on mid-range device | Physical device DevTools profiling | Cannot verify without device | SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| RDR-01 | 03-04 | Opening a book loads chapter list and resumes last position | SATISFIED | `ReaderNotifier.build()` loads chapters from Drift; `PageController` initialized at `book.readingProgressChapter ?? 0` |
| RDR-02 | 03-04 | Reader renders chapters as a PageView (one chapter per page) | SATISFIED | `ReaderScreen` builds `PageView.builder` over chapters; each page is a `ChapterPage` |
| RDR-03 | 03-03 | Per-paragraph RichText in ListView.builder with RepaintBoundary | SATISFIED (code) / NEEDS HUMAN (60fps) | 6 `RepaintBoundary` usages in `block_renderer.dart`; actual 60fps requires device measurement (Roadmap SC #1) |
| RDR-04 | 03-01, 03-03, 03-06 | Per-sentence TextSpan architecture (permanent, not retrofit) | SATISFIED | `SentenceSplitter` + `ParagraphWidget` produce one TextSpan per Sentence; exhaustive sealed class switch; sentence-span architecture also tested with image fallback fix in Plan 06 |
| RDR-05 | 03-03 | Paragraph-level Semantics for VoiceOver/TalkBack | SATISFIED | `Semantics(label: text)` + `ExcludeSemantics(child: RichText(...))` in `ParagraphWidget`; 7 semantics tests |
| RDR-06 | 03-02 | Font size slider (12-28pt) applies immediately and persists | SATISFIED | `FontSizeController` with `minSize=12.0`, `maxSize=28.0`; `TypographySheet` `Slider`; `SharedPreferences` persistence |
| RDR-07 | 03-02, 03-05 | Font family picker (3-4 bundled options) | SATISFIED (override) | 2 families (Literata + Merriweather) per Phase 1 D-21 amendment to FND-06; override accepted — see overrides frontmatter |
| RDR-08 | 03-05 | Theme toggle (light/sepia/dark/OLED) applies immediately and persists | SATISFIED | Phase 1 `ThemeModeController` infrastructure; `ThemeMode` from shared prefs wires through app-level `MaterialApp`; no new code required (D-16) |
| RDR-09 | 03-05 | Chapter sidebar on tablet, slide-over drawer on phone | SATISFIED | `shortestSide >= 600` branch: collapsible `ChapterSidebar` (300px) on tablet; `ChapterDrawer` on phone |
| RDR-10 | 03-05 | Chapter jump + current chapter visually highlighted | SATISFIED | Sidebar and drawer both highlight current chapter via `selected: isActive` on `ListTile`; `jumpToPage(i)` on tap |
| RDR-11 | 03-02, 03-05 | Reading progress saved on page turn, debounced at 2s, resumes on reopen | SATISFIED | 2s debounce timer; `await _db.updateReadingProgress(...)` (WR-03 fix); flushes on dispose and `AppLifecycleState.paused`; 4 debounce tests pass |
| RDR-12 | 03-05, 03-06 | Immersive mode toggle on center tap + progress flush on pause | SATISFIED | Center-third tap zone, `SystemUiMode.immersiveSticky`; `unawaited(flushNow())` on lifecycle pause (WR-03 / WR-01 fixes close both aspects) |

**RDR-07 note:** REQUIREMENTS.md text says "3-4 bundled options" but Phase 1 design decision D-21 formally amended FND-06 to 2 serif families (Literata + Merriweather). The implementation is correct per the amended scope. Override documented in frontmatter for auditability.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| None found | — | All stub indicators reviewed; none flow to user-visible rendering without real data source | — | — |

Plan 06 specifically closed WR-02 (dead ternary `ordered ? '\u2022 ' : '\u2022 '` replaced with plain literal + TODO comment). No new anti-patterns introduced.

### Human Verification Required

#### 1. 60fps Reader Scroll — Mid-Range Phone

**Test:** Open a long EPUB chapter (300+ blocks) on a mid-range Android phone (e.g., Pixel 4a or equivalent). Scroll through the chapter at various speeds.

**Expected:** Flutter DevTools Performance overlay shows 60fps sustained; no red frame indicators; no visible jank during fast flings.

**Why human:** Frame timing measurement requires a physical device and GPU profiling tools. Source code structural guarantees (RepaintBoundary per block, ListView.builder lazy build) are verified — runtime performance under load is not.

#### 2. Immersive Mode Center-Third Tap

**Test:** On a physical device, tap the left third of the screen, then the center third, then the right third, while in the reader.

**Expected:** Only the center-third tap toggles app bar visibility. Left and right thirds do not trigger immersive mode. Transition to/from `SystemUiMode.immersiveSticky` is smooth.

**Why human:** Tap zone geometry and visual system UI transitions cannot be verified from source code alone. Device pixel density and actual gesture hit areas must be confirmed in hardware.

#### 3. Typography Reflow Immediacy

**Test:** Open a chapter and open the typography sheet. Move the font size slider from minimum to maximum.

**Expected:** Text reflows in real time as the slider moves, with no noticeable lag. The chapter content visibly grows and shrinks smoothly.

**Why human:** UI rendering responsiveness under live state changes requires device measurement.

#### 4. Scroll Position Resume — End-to-End

**Test:** Open a book, scroll to a mid-chapter position, wait 3 seconds (debounce completes), close the book, reopen it.

**Expected:** The book reopens at the correct chapter and approximately the same scroll position.

**Why human:** Full lifecycle test (background flush + Drift read + PageController initialization) requires running the app on a physical device.

#### 5. Plan 05 Task 3 — Full Physical Device Checklist

**Test:** Execute all 14 steps of the Plan 05 human verification checklist on a physical Android device.

**Expected:** All items pass: sidebar visible on tablet at >=600dp, sidebar collapses and expands, phone shows drawer, chapter taps navigate correctly, current chapter highlighted, font size changes persist, font family picker works, center-third tap toggles immersive, left/right thirds do not, progress saves within 3 seconds, progress restores correctly on reopen, `AppLifecycleState.paused` flushes immediately.

**Why human:** Plan 05 was declared `autonomous: false` with a mandatory human verification Task 3. These behaviors span system UI, lifecycle events, and layout geometry — none are safely verified by code inspection alone.

### Gaps Summary

No automated gaps. All 8 observable truths are verified. All 12 requirements (RDR-01 through RDR-12) have implementation evidence with 1 override accepted (RDR-07 font family count per Phase 1 D-21 amendment). The 88-test suite passes with no regressions.

Plan 06 gap closure items are all confirmed: EPUB image relative path resolution works via the 3-level fallback chain, scroll progress uses the correct chapter index from the itemBuilder parameter, and the reading progress flush correctly awaits the Drift write before returning.

The 5 outstanding human verification items remain unchanged from the previous verification. These are required validation steps for a phase that explicitly included a mandatory human checkpoint (Plan 05 Task 3) and a performance requirement (Roadmap SC #1: 60fps on mid-range phone). They are not code gaps — they are runtime behaviors that require physical device testing.

---

_Verified: 2026-04-12T19:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Previous verification: 2026-04-12T17:00:00Z (human_needed, 5/5)_
_Re-verification triggered by: Plan 06 gap closure (commits f5809e2, 3dfe9c2)_
