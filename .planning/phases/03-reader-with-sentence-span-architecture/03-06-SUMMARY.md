---
phase: 03-reader-with-sentence-span-architecture
plan: 06
subsystem: reader
tags: [epub, images, path-resolution, reading-progress, code-review]

# Dependency graph
requires:
  - phase: 03-reader-with-sentence-span-architecture
    provides: "ImageExtractor, block_renderer, reading progress provider"
provides:
  - "Robust EPUB image path resolution with multi-level fallback"
  - "Correct chapter attribution for scroll progress saves"
  - "Async reading progress flush with awaited DB write"
affects: [04-tts-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Multi-level image href fallback: direct -> normalize -> basename"
    - "putIfAbsent for deduplication in mapping loops"

key-files:
  created: []
  modified:
    - lib/core/epub/image_extractor.dart
    - lib/features/reader/widgets/block_renderer.dart
    - lib/features/reader/reader_screen.dart
    - lib/features/reader/providers/reading_progress_provider.dart
    - test/core/epub/image_extractor_test.dart
    - test/widget/reader/block_renderer_test.dart

key-decisions:
  - "p.normalize only collapses internal ../ on POSIX (leading ../ preserved); basename fallback is the true safety net for relative EPUB image paths"

patterns-established:
  - "Image href resolution: direct lookup -> p.normalize -> p.basename fallback chain"

requirements-completed: [RDR-04, RDR-12]

# Metrics
duration: 5min
completed: 2026-04-12
---

# Phase 03 Plan 06: Gap Closure Summary

**Fixed EPUB image rendering for relative src paths and closed three code review warnings (chapter attribution, dead ternary, unawaited DB flush)**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-12T18:32:15Z
- **Completed:** 2026-04-12T18:37:27Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- EPUB images with relative src paths (../images/fig.png) now resolve via multi-level fallback in both ImageExtractor mapping and _ImageBlockWidget lookup
- Scroll progress correctly attributes chapter index from itemBuilder (not stale closure)
- Reading progress flush awaits DB write so app-pause does not lose position
- Dead ternary in list bullet logic replaced with plain literal

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix EPUB image path resolution for relative src attributes** - `f5809e2` (fix)
2. **Task 2: Close code review warnings WR-01, WR-02, WR-03** - `3dfe9c2` (fix)

## Files Created/Modified
- `lib/core/epub/image_extractor.dart` - Added multi-level sub-path stripping loop and p.normalize mapping for relative EPUB image hrefs
- `lib/features/reader/widgets/block_renderer.dart` - Added p.normalize + p.basename fallback chain in _ImageBlockWidget; removed dead ternary in ListItem bullet
- `lib/features/reader/reader_screen.dart` - Fixed chapter index from readerState.currentChapterIndex to itemBuilder index; added unawaited() wrapper for lifecycle flush
- `lib/features/reader/providers/reading_progress_provider.dart` - Made _flushPending and flushNow async with awaited DB write
- `test/core/epub/image_extractor_test.dart` - Added tests for normalize, multi-level stripping, and basename fallback
- `test/widget/reader/block_renderer_test.dart` - Added tests for basename fallback and normalize fallback image rendering

## Decisions Made
- p.normalize on POSIX does not collapse leading `../` segments (only internal ones). The basename fallback is the true safety net for EPUB images with relative src paths like `../images/fig.png`. Both normalize and basename are kept in the fallback chain because normalize handles internal `../` (e.g., `text/../images/fig.png`) while basename handles leading `../`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Adjusted test expectations for p.normalize POSIX behavior**
- **Found during:** Task 1 (image path resolution tests)
- **Issue:** Plan assumed p.normalize('../images/fig.png') would return 'images/fig.png', but on POSIX p.normalize preserves leading ../ since there's no base to resolve against
- **Fix:** Changed test to verify internal ../ collapsing (e.g., 'OEBPS/text/../images/fig.png' -> 'OEBPS/images/fig.png') and adjusted block_renderer normalize fallback test to use internal ../ path instead
- **Files modified:** test/core/epub/image_extractor_test.dart, test/widget/reader/block_renderer_test.dart
- **Verification:** All 17 targeted tests pass; full suite of 90+ tests pass
- **Committed in:** f5809e2 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Test expectation adjustment only. The production code fallback chain works correctly -- p.normalize handles internal ../ and p.basename handles leading ../. No scope creep.

## Issues Encountered
None beyond the p.normalize POSIX behavior documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 03 reader architecture is complete with all gap closure items resolved
- All code review warnings from 03-REVIEW.md are closed
- Ready for Phase 04 TTS integration

---
*Phase: 03-reader-with-sentence-span-architecture*
*Completed: 2026-04-12*
