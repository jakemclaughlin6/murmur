---
phase: 03-reader-with-sentence-span-architecture
verified: 2026-04-12T17:00:00Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
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

**Verified:** 2026-04-12T17:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Every paragraph renders as a RichText with one TextSpan per Sentence (permanent architecture) | VERIFIED | `ParagraphWidget` splits via `SentenceSplitter.split()`, maps each `Sentence` to a child `TextSpan`; `renderBlock()` routes `Paragraph` blocks through `ParagraphWidget` |
| 2 | Users can navigate between chapters (horizontal PageView on phone and tablet) | VERIFIED | `ReaderScreen` builds `PageView.builder` over chapters; `ChapterSidebar` (tablet) and `ChapterDrawer` (phone) both call `pageController.jumpToPage()` |
| 3 | Reading progress persists and resumes on reopen | VERIFIED | `ReaderNotifier.build()` reads saved `readingProgressChapter` from Drift; `ReadingProgressNotifier` debounces at 2s, flushes on `AppLifecycleState.paused` and `onDispose` |
| 4 | Responsive layout adapts to phone and tablet at the 600dp breakpoint | VERIFIED | `reader_screen.dart` branches on `MediaQuery.of(context).size.shortestSide >= 600`: tablet shows `ChapterSidebar` (300px), phone shows `ChapterDrawer` |
| 5 | Typography controls and immersive mode work in the reader | VERIFIED | `TypographySheet` exposes font-size slider (12–28pt) and font-family picker; `reader_screen.dart` uses `SystemUiMode.immersiveSticky` on center-third tap with `WidgetsBindingObserver` for cleanup |

**Score:** 5/5 truths verified (programmatically)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/core/text/sentence.dart` | Sentence data class | VERIFIED | `const Sentence(this.text)`, `operator ==`, `hashCode` — pure Dart, no Flutter deps |
| `lib/core/text/sentence_splitter.dart` | SentenceSplitter with abbreviation set | VERIFIED | `static const _abbreviations` (32 entries), `List<Sentence> split(String text)`, handles decimals and ellipses |
| `lib/core/db/app_database.dart` | Drift queries for chapters, progress, book | VERIFIED | `getChaptersForBook`, `updateReadingProgress`, `updateLastReadDate`, `Future<Book?> getBook` all present |
| `lib/core/epub/image_extractor.dart` | ImageExtractor with path traversal protection | VERIFIED | `p.canonicalize` + `p.basename` for path safety, `extractImages`, `hasExtractedImages` |
| `lib/features/reader/providers/font_settings_provider.dart` | FontSizeController (12–28pt) + FontFamilyController | VERIFIED | `minSize=12.0`, `maxSize=28.0`; `availableFamilies=['Literata','Merriweather']`; `SharedPreferences` backed |
| `lib/features/reader/widgets/block_renderer.dart` | Exhaustive Block switch with RepaintBoundary | VERIFIED | All 5 variants (Paragraph, Heading, ImageBlock, Blockquote, ListItem); 6 RepaintBoundary usages |
| `lib/features/reader/widgets/paragraph_widget.dart` | ParagraphWidget with per-sentence TextSpans and Semantics | VERIFIED | `Semantics(label: fullText)` + `ExcludeSemantics(child: RichText(...))` + one TextSpan per Sentence |
| `lib/features/reader/providers/reader_provider.dart` | ReaderNotifier async notifier keyed by bookId | VERIFIED | `@riverpod class ReaderNotifier extends _$ReaderNotifier`, auto-disposing family, `blocksFromJsonString` lazy deserialization, `on FormatException` safety |
| `lib/features/reader/providers/reader_provider.g.dart` | Riverpod codegen output | VERIFIED | Generated file present; provider name `readerProvider` (Riverpod 3 drops class suffix — documented deviation) |
| `lib/features/reader/widgets/chapter_page.dart` | ChapterPage with ListView.builder + AutomaticKeepAliveClientMixin | VERIFIED | `AutomaticKeepAliveClientMixin`, `ListView.builder`, calls `renderBlock()` per item |
| `lib/features/reader/reader_screen.dart` | Full ReaderScreen replacing Phase 2 stub | VERIFIED | Phase 2 `_samplePassage` stub fully removed; watches `readerProvider`, `fontSizeControllerProvider`, `fontFamilyControllerProvider` |
| `lib/features/reader/widgets/chapter_sidebar.dart` | Tablet sidebar (300px) with collapse toggle | VERIFIED | `width: 300`, collapse toggle via `_sidebarCollapsed` state in `reader_screen.dart` |
| `lib/features/reader/widgets/chapter_drawer.dart` | Phone slide-over chapter drawer | VERIFIED | `ChapterDrawer`, pops navigator on chapter tap |
| `lib/features/reader/widgets/typography_sheet.dart` | Typography bottom sheet with slider and picker | VERIFIED | `Slider(min: FontSizeController.minSize, max: FontSizeController.maxSize)`, `FontFamilyController.availableFamilies` iteration |
| `lib/features/reader/providers/reading_progress_provider.dart` | Debounced progress save + lifecycle flush | VERIFIED | 2s debounce timer, `flushNow()`, flush in `onDispose`, flush on `AppLifecycleState.paused` |
| `test/core/text/sentence_splitter_test.dart` | Unit tests for SentenceSplitter | VERIFIED | Present |
| `test/widget/reader/block_renderer_test.dart` | Widget tests for all 5 Block variants | VERIFIED | 7 tests, RepaintBoundary verification |
| `test/widget/reader/paragraph_semantics_test.dart` | Widget tests for Semantics + per-sentence spans | VERIFIED | 7 tests covering sentence count, semantics label, font styling, empty input |
| `test/widget/reader/reader_screen_test.dart` | Widget tests for ReaderScreen + ChapterPage | VERIFIED | 5 tests: title display, chapter content, swipe navigation, placeholder, resume position |
| `test/widget/reader/responsive_layout_test.dart` | Widget tests for tablet/phone layout | VERIFIED | 4 tests for sidebar/drawer branching + chapter navigation |
| `test/widget/reader/font_settings_test.dart` | Widget tests for typography sheet | VERIFIED | 5 tests for slider and font family picker |
| `test/core/db/reading_progress_debounce_test.dart` | Unit tests for debounce timing and flush | VERIFIED | 4 tests for debounce behavior and flush on dispose |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `reader_screen.dart` | `readerProvider` | `ref.watch(readerProvider(widget.bookId!))` | WIRED | Watches provider, handles `AsyncValue` states |
| `reader_screen.dart` | `fontSizeControllerProvider` | `ref.watch(fontSizeControllerProvider)` | WIRED | Font size applied to `renderBlock` calls |
| `reader_screen.dart` | `fontFamilyControllerProvider` | `ref.watch(fontFamilyControllerProvider)` | WIRED | Font family applied to `renderBlock` calls |
| `reader_screen.dart` | `readingProgressProvider` | `ref.read(readingProgressProvider(bookId).notifier)` | WIRED | `onScrollOffsetChanged` callback connects scroll events to provider |
| `chapter_page.dart` | `block_renderer.dart` | `renderBlock(block, ...)` in `itemBuilder` | WIRED | Each block in `ListView.builder` passes through `renderBlock` |
| `block_renderer.dart` | `paragraph_widget.dart` | `ParagraphWidget(text: text, ...)` in `Paragraph` case | WIRED | `Paragraph` variant routes to `ParagraphWidget` |
| `paragraph_widget.dart` | `sentence_splitter.dart` | `splitter.split(text)` | WIRED | Creates `SentenceSplitter` instance, maps results to TextSpans |
| `reading_progress_provider.dart` | `app_database.dart` | `_db.updateReadingProgress(...)` | WIRED | Captured eagerly in `build()`, flushed in `onDispose` and on lifecycle pause |
| `reader_provider.dart` | `app_database.dart` | `db.getChaptersForBook(bookId)`, `db.getBook(bookId)`, `db.updateLastReadDate(...)` | WIRED | All three Drift queries called in `build()` |
| `reader_screen.dart` | `chapter_sidebar.dart` / `chapter_drawer.dart` | `shortestSide >= 600` branch | WIRED | Tablet renders `ChapterSidebar`, phone renders via `ChapterDrawer` in `Drawer` slot |
| `typography_sheet.dart` | `font_settings_provider.dart` | `ref.watch(fontSizeControllerProvider)` + `.notifier` writes | WIRED | Sheet reads and writes both font controllers |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `reader_screen.dart` | `readerState.chapters` | `db.getChaptersForBook(bookId)` Drift query | Yes — queries `chapters` table ordered by `orderIndex` | FLOWING |
| `chapter_page.dart` | `blocks` | `blocksFromJsonString(chapter.contentJson)` lazy deserialization | Yes — deserializes stored EPUB content per chapter | FLOWING |
| `reading_progress_provider.dart` | `_pendingProgress` | Scroll offset callbacks from `ChapterPage` | Yes — written to Drift via `updateReadingProgress` | FLOWING |
| `font_settings_provider.dart` | `fontSizeController.state` | `SharedPreferences.getDouble('reader_font_size')` | Yes — reads persisted value, defaults to 16.0 | FLOWING |
| `reader_provider.dart` | `state.initialPage` | `db.getReadingProgress(bookId)` | Yes — reads `readingProgressChapter` from Drift | FLOWING |

### Behavioral Spot-Checks

All test files can be run with flutter test. Per CLAUDE.md, the mise-managed Flutter toolchain is used.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| SentenceSplitter unit tests | `flutter test test/core/text/` | All tests pass (verified in prior session) | PASS |
| Block renderer widget tests | `flutter test test/widget/reader/block_renderer_test.dart` | 7/7 pass | PASS |
| ParagraphWidget semantics tests | `flutter test test/widget/reader/paragraph_semantics_test.dart` | 7/7 pass | PASS |
| ReaderScreen widget tests | `flutter test test/widget/reader/reader_screen_test.dart` | 5/5 pass | PASS |
| Responsive layout tests | `flutter test test/widget/reader/responsive_layout_test.dart` | 4/4 pass | PASS |
| Font settings tests | `flutter test test/widget/reader/font_settings_test.dart` | 5/5 pass | PASS |
| Debounce tests | `flutter test test/core/db/reading_progress_debounce_test.dart` | 4/4 pass | PASS |
| Full suite | `flutter test` | 83 phase-3 tests pass; full suite green, no regressions | PASS |
| 60fps scroll on mid-range device | Physical device DevTools profiling | Cannot verify without device | SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| RDR-01 | 03-04 | Opening a book displays the first chapter | SATISFIED | `ReaderNotifier.build()` loads chapters from Drift; `ReaderScreen` initializes `PageController` at `state.initialPage` (0 for new books) |
| RDR-02 | 03-04 | Resume reading from last position | SATISFIED | `readingProgressChapter` read from Drift in `build()`; `PageController` initialized to saved chapter index |
| RDR-03 | 03-03 | 60fps scroll performance (RepaintBoundary per block) | SATISFIED (code) / NEEDS HUMAN (performance) | 6 `RepaintBoundary` usages in `block_renderer.dart`; actual fps requires device measurement |
| RDR-04 | 03-01, 03-03 | Per-sentence TextSpan architecture | SATISFIED | `SentenceSplitter` + `ParagraphWidget` produce one TextSpan per Sentence; exhaustive sealed class switch in `renderBlock()` |
| RDR-05 | 03-03 | Paragraph-level accessibility Semantics | SATISFIED | `Semantics(label: fullText)` + `ExcludeSemantics(child: RichText(...))` pattern in `ParagraphWidget` |
| RDR-06 | 03-02 | Drift reading progress queries | SATISFIED | `getChaptersForBook`, `updateReadingProgress`, `updateLastReadDate`, `getBook` all in `app_database.dart` |
| RDR-07 | 03-02, 03-05 | Font family selection (3-4 options) | SATISFIED (amended) | Implementation provides 2 families (Literata + Merriweather) per Phase 1 D-21 amendment (FND-06 formally amended; RDR-07 text not updated but `03-CONTEXT.md` documents the accepted scope reduction at line 47) |
| RDR-08 | 03-05 | Reader theme toggle (light/dark) | SATISFIED | Theme switching uses Phase 1 infrastructure (no new code required per D-16); `ThemeMode` from shared prefs wires through app-level `MaterialApp` |
| RDR-09 | 03-05 | Chapter navigation (sidebar on tablet, drawer on phone) | SATISFIED | `shortestSide >= 600` branch: `ChapterSidebar` (300px, collapsible) on tablet; `ChapterDrawer` on phone |
| RDR-10 | 03-05 | Immersive/full-screen reading mode | SATISFIED | Center-third tap zone, `SystemUiMode.immersiveSticky`, `WidgetsBindingObserver` resets on dispose/unfocus |
| RDR-11 | 03-02, 03-05 | Font size control (12-28pt) | SATISFIED | `FontSizeController` with `minSize=12.0` / `maxSize=28.0`; `TypographySheet` `Slider` uses these bounds; `SharedPreferences` persistence |
| RDR-12 | 03-05 | Reading progress persistence (debounced) | SATISFIED | 2s debounce timer; eager DB capture in `build()`; flush in `onDispose` and on `AppLifecycleState.paused` |

**RDR-07 note:** The REQUIREMENTS.md text says "3-4 bundled options" but Phase 1 design decision D-21 formally amended FND-06 to 2 families. The implementation (Literata + Merriweather) is correct per the amended scope. The RDR-07 text was not retroactively updated in REQUIREMENTS.md, but this is a documentation lag, not an implementation gap.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | — | All `return null` / `return []` / TODO occurrences reviewed; none flow to user-visible rendering without a real data source populating them | — | — |

No blockers or warnings identified. All stub-indicator grep results were either: comment text (not code), initial state overwritten by fetch/Drift query, or test helpers (not production code).

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

**Test:** Open a book, scroll to a mid-chapter position, scroll partway through, wait 3 seconds (debounce completes), close the book, reopen it.

**Expected:** The book reopens at the correct chapter and approximately the same scroll position.

**Why human:** Full lifecycle test (background flush + Drift read + PageController initialization) requires running the app on a physical device.

#### 5. Plan 05 Task 3 — Full Physical Device Checklist

**Test:** Execute all 14 steps of the Plan 05 human verification checklist on a physical Android device.

**Expected:** All items pass: sidebar visible on tablet at >=600dp, sidebar collapses and expands, phone shows drawer, chapter taps navigate correctly, current chapter highlighted, font size changes persist, font family picker works, center-third tap toggles immersive, left/right thirds do not, progress saves within 3 seconds, progress restores correctly on reopen, AppLifecycleState.paused flushes immediately.

**Why human:** Plan 05 was declared `autonomous: false` with a mandatory human verification Task 3. These behaviors span system UI, lifecycle events, and layout geometry — none are safely verified by code inspection alone.

### Gaps Summary

No gaps found. All 18 production artifacts exist, are substantive, and are wired with real data flowing. All 12 requirements (RDR-01 through RDR-12) have implementation evidence. The 83-test suite passes with no regressions.

The only outstanding items are 5 human verification tests, all of which require physical device testing and cannot be resolved programmatically. These are not gaps in the implementation — they are required validation steps for a phase that explicitly included a human checkpoint (Plan 05, Task 3) and a performance requirement (RDR-03, SC #1: 60fps on mid-range phone).

---

_Verified: 2026-04-12T17:00:00Z_
_Verifier: Claude (gsd-verifier)_
