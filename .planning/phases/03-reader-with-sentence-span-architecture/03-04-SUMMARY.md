---
phase: 03-reader-with-sentence-span-architecture
plan: 04
subsystem: reader, ui
tags: [pageview, listview, riverpod, drift, reader-screen, chapter-navigation, scroll-resume]

# Dependency graph
requires:
  - phase: 03-reader-with-sentence-span-architecture
    plan: 02
    provides: Drift reading progress queries, font settings providers, ImageExtractor
  - phase: 03-reader-with-sentence-span-architecture
    plan: 03
    provides: Block-to-widget renderer (renderBlock), ParagraphWidget, SentenceSplitter
provides:
  - ReaderNotifier provider loading book + chapters from Drift with position resume
  - ReaderScreen with horizontal PageView.builder of chapters replacing Phase 2 stub
  - ChapterPage with vertical ListView.builder of rendered Block widgets
  - Lazy chapter deserialization via blocksForChapter() with FormatException safety
  - Image extraction on book open with graceful degradation
affects: [03-05, 04-tts, 05-highlighting]

# Tech tracking
tech-stack:
  added: []
  patterns: [tester.runAsync for Drift FFI in widget tests, bySemanticsLabel for RichText content assertions, AutomaticKeepAliveClientMixin for PageView child scroll preservation]

key-files:
  created:
    - lib/features/reader/providers/reader_provider.dart
    - lib/features/reader/providers/reader_provider.g.dart
    - lib/features/reader/widgets/chapter_page.dart
    - test/widget/reader/reader_screen_test.dart
  modified:
    - lib/features/reader/reader_screen.dart

key-decisions:
  - "readerProvider (generated name from @riverpod) is auto-disposing family provider keyed by bookId"
  - "Image extraction always calls extractImages (idempotent) wrapped in try-catch for test/missing-file resilience"
  - "Widget tests use tester.runAsync to resolve Drift NativeDatabase.memory() futures in FakeAsync environment"
  - "Content assertions use find.bySemanticsLabel because ParagraphWidget renders via RichText TextSpan (not Text widget)"

patterns-established:
  - "Async Riverpod provider widget testing pattern: runAsync + pump + pump for Drift FFI resolution"
  - "ConsumerStatefulWidget + PageController ??= pattern for reader screen lifecycle"

requirements-completed: [RDR-01, RDR-02]

# Metrics
duration: 8min
completed: 2026-04-12
---

# Phase 3 Plan 04: Reader Screen + Chapter PageView Summary

**Horizontal PageView reader with lazy chapter deserialization, scroll position resume, and Phase 2 stub fully replaced -- 5 widget tests passing, full suite green**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-12T14:04:45Z
- **Completed:** 2026-04-12T14:13:00Z
- **Tasks:** 2
- **Files created:** 4
- **Files modified:** 1

## Accomplishments
- ReaderNotifier loads book + chapters from Drift, resumes at saved position (D-13), extracts images
- ReaderScreen replaces Phase 2 stub with horizontal PageView.builder of chapters
- ChapterPage renders blocks via vertical ListView.builder with AutomaticKeepAliveClientMixin
- 5 widget tests covering title display, chapter content, swipe navigation, placeholder, and resume position
- Full test suite passes with no regressions (navigation_test.dart Key('reader-screen') preserved)

## Task Commits

Each task was committed atomically:

1. **Task 1: ReaderNotifier provider** - `c1b6b96` (feat)
2. **Task 2: ReaderScreen + ChapterPage + tests** - `70470cc` (feat)

**Plan metadata:** (pending final commit)

## Files Created/Modified
- `lib/features/reader/providers/reader_provider.dart` - ReaderState immutable class + ReaderNotifier async notifier
- `lib/features/reader/providers/reader_provider.g.dart` - Riverpod codegen
- `lib/features/reader/widgets/chapter_page.dart` - ChapterPage StatefulWidget with AutomaticKeepAliveClientMixin
- `lib/features/reader/reader_screen.dart` - Full reader screen replacing Phase 2 stub
- `test/widget/reader/reader_screen_test.dart` - 5 widget tests for reader screen

## Decisions Made
- Generated provider name is `readerProvider` (not `readerNotifierProvider`) -- Riverpod 3 codegen drops the class suffix
- Image extraction always runs (idempotent, no hasExtractedImages check) wrapped in try-catch for test resilience
- Widget tests use `tester.runAsync` to resolve Drift FFI queries outside FakeAsync, followed by `pump()` for widget rebuild
- Content assertions use `find.bySemanticsLabel` since ParagraphWidget renders text via RichText TextSpan, not Text widget

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed image map stub on second book open**
- **Found during:** Task 1 (code review before writing)
- **Issue:** Plan code had a TODO for rebuilding image map from existing files; on second open, hasExtractedImages returns true but imagePathMap stays empty
- **Fix:** Always call extractImages() (idempotent, overwrites existing) wrapped in try-catch
- **Files modified:** lib/features/reader/providers/reader_provider.dart
- **Committed in:** c1b6b96 (Task 1 commit)

**2. [Rule 3 - Blocking] Fixed Drift Value.ofNullable(null) assertion in tests**
- **Found during:** Task 2 (test creation)
- **Issue:** Drift rejects `Value.ofNullable(null)` for nullable columns; must use `Value.absent()` for null and `Value(x)` for non-null
- **Fix:** Conditional `readingProgressChapter != null ? Value(x) : const Value.absent()` in test helper
- **Files modified:** test/widget/reader/reader_screen_test.dart
- **Committed in:** 70470cc (Task 2 commit)

**3. [Rule 3 - Blocking] Fixed pumpAndSettle timeout on CircularProgressIndicator**
- **Found during:** Task 2 (test creation)
- **Issue:** `pumpAndSettle` never settles because CircularProgressIndicator animates continuously during async loading state
- **Fix:** Used `tester.runAsync` to resolve Drift FFI futures, then `pump()` for widget rebuild
- **Files modified:** test/widget/reader/reader_screen_test.dart
- **Committed in:** 70470cc (Task 2 commit)

**4. [Rule 3 - Blocking] Fixed find.text not finding RichText TextSpan content**
- **Found during:** Task 2 (test creation)
- **Issue:** `find.text()` only finds `Text` widgets, not `RichText` with `TextSpan` children
- **Fix:** Used `find.bySemanticsLabel()` since ParagraphWidget wraps content in `Semantics(label: text)`
- **Files modified:** test/widget/reader/reader_screen_test.dart
- **Committed in:** 70470cc (Task 2 commit)

---

**Total deviations:** 4 auto-fixed (1 bug, 3 blocking)
**Impact on plan:** All fixes necessary for correctness and test functionality. No scope creep.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Reader screen ready for Plan 05 to add chapter sidebar/drawer, typography sheet, immersive mode, and debounced progress save
- ChapterPage.onScrollOffsetChanged callback is wired but unused -- Plan 05 connects it to progress saving
- PageController and ReaderNotifier expose all state Plan 05 needs for chapter navigation UI
- No blockers for Plan 05

## Self-Check: PASSED

- All 5 files exist at expected paths
- Both commits found: c1b6b96 (Task 1), 70470cc (Task 2)
- All acceptance criteria verified
- 5/5 reader screen tests passing
- Full test suite green with no regressions
- Phase 2 stub _samplePassage fully removed
- Key('reader-screen') preserved for navigation_test.dart compatibility

---
*Phase: 03-reader-with-sentence-span-architecture*
*Completed: 2026-04-12*
