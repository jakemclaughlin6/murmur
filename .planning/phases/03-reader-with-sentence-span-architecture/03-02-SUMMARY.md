---
phase: 03-reader-with-sentence-span-architecture
plan: 02
subsystem: database, reader
tags: [drift, riverpod, shared-preferences, epub-images, reading-progress, font-settings]

# Dependency graph
requires:
  - phase: 02-library-epub-import
    provides: Books/Chapters Drift tables with readingProgressChapter/readingProgressOffset columns
  - phase: 01-scaffold-compliance-foundation
    provides: ThemeModeController pattern for shared_preferences-backed Riverpod providers
provides:
  - Drift query methods for reading progress (getChaptersForBook, updateReadingProgress, updateLastReadDate, getBook)
  - FontSizeController and FontFamilyController Riverpod providers persisted to shared_preferences
  - ImageExtractor utility for EPUB inline image extraction with path traversal protection
affects: [03-03, 03-04, 03-05, 04-tts]

# Tech tracking
tech-stack:
  added: []
  patterns: [hide drift isNull/isNotNull in test imports to avoid matcher collision]

key-files:
  created:
    - lib/core/epub/image_extractor.dart
    - lib/features/reader/providers/font_settings_provider.dart
    - lib/features/reader/providers/font_settings_provider.g.dart
    - test/core/db/reading_progress_test.dart
    - test/core/epub/image_extractor_test.dart
    - test/features/reader/font_settings_provider_test.dart
  modified:
    - lib/core/db/app_database.dart

key-decisions:
  - "Drift import needs `hide isNull, isNotNull` in tests to avoid collision with matcher package"
  - "ImageExtractor uses basename + canonicalize double defense for path traversal (T-03-03)"
  - "FontFamilyController silently rejects unknown families rather than throwing"

patterns-established:
  - "shared_preferences-backed Riverpod async notifier pattern for reader settings"
  - "Drift query methods added to AppDatabase without schema version bump when no table changes"

requirements-completed: [RDR-06, RDR-07, RDR-11]

# Metrics
duration: 5min
completed: 2026-04-12
---

# Phase 3 Plan 02: Reader Data Layer Summary

**Drift reading progress queries, font settings providers (12-28pt / Literata+Merriweather), and EPUB image extractor with path traversal protection -- 23 tests passing**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-12T13:52:58Z
- **Completed:** 2026-04-12T13:58:20Z
- **Tasks:** 2
- **Files created:** 6
- **Files modified:** 1

## Accomplishments
- 4 Drift query methods on AppDatabase for reading progress (no schema bump needed)
- FontSizeController (12-28pt, clamped) and FontFamilyController (Literata/Merriweather whitelist) with shared_preferences persistence
- ImageExtractor resolves EPUB-internal image hrefs to local paths with basename + canonicalize path traversal defense
- 23 tests total: 8 reading progress, 5 image extractor, 10 font settings

## Task Commits

Each task was committed atomically:

1. **Task 1: Drift reading progress queries + image extractor** - `4a6f7c5` (feat)
2. **Task 2: Font settings Riverpod providers** - `550bfe8` (feat)

**Plan metadata:** (pending final commit)

## Files Created/Modified
- `lib/core/db/app_database.dart` - Added getChaptersForBook, updateReadingProgress, updateLastReadDate, getBook
- `lib/core/epub/image_extractor.dart` - EPUB image extraction with path traversal protection (T-03-03)
- `lib/features/reader/providers/font_settings_provider.dart` - FontSizeController + FontFamilyController
- `lib/features/reader/providers/font_settings_provider.g.dart` - Riverpod codegen
- `test/core/db/reading_progress_test.dart` - 8 tests for Drift reading progress queries
- `test/core/epub/image_extractor_test.dart` - 5 tests for hasExtractedImages + path traversal
- `test/features/reader/font_settings_provider_test.dart` - 10 tests for font size/family providers

## Decisions Made
- Drift `isNull`/`isNotNull` collides with `matcher` package in test files; resolved with `hide` import directive
- ImageExtractor uses double defense: `p.basename()` strips directory components, then `p.canonicalize()` verifies output stays within target dir
- FontFamilyController silently rejects unknown family names (returns without state change) rather than throwing -- matches ThemeModeController's graceful degradation pattern

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed Drift/matcher isNull import collision**
- **Found during:** Task 1 (reading progress tests)
- **Issue:** `drift/drift.dart` exports `isNull` and `isNotNull` which collide with `flutter_test` matcher equivalents
- **Fix:** Added `hide isNull, isNotNull` to the Drift import in the test file
- **Files modified:** test/core/db/reading_progress_test.dart
- **Verification:** All 8 tests compile and pass
- **Committed in:** 4a6f7c5 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Minor import fix required for compilation. No scope creep.

## Issues Encountered
None beyond the import collision documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Reading progress queries ready for Plan 03 (reader screen) to call on book open and scroll-stop
- Font providers ready for Plan 03/04 to wire into RichText widget styling
- ImageExtractor ready for Plan 03 block renderer to resolve ImageBlock.href to file paths
- No blockers for Plan 03

## Self-Check: PASSED

- All 7 files exist at expected paths
- Both commits found: 4a6f7c5 (Task 1), 550bfe8 (Task 2)
- All acceptance criteria verified
- 23/23 tests passing
- schemaVersion remains 2 (no bump)

---
*Phase: 03-reader-with-sentence-span-architecture*
*Completed: 2026-04-12*
