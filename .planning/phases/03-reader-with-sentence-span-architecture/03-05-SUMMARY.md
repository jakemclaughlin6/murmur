---
phase: 03-reader-with-sentence-span-architecture
plan: 05
subsystem: ui
tags: [flutter, riverpod, responsive-layout, reader-chrome, typography, immersive-mode, progress-persistence, drift]

# Dependency graph
requires:
  - phase: 03-04
    provides: ReaderScreen with PageView + ChapterPage, ReaderNotifier provider
provides:
  - Responsive chapter navigation (tablet sidebar / phone drawer)
  - Collapsible chapter sidebar on tablet
  - Typography bottom sheet (font size slider + font family picker)
  - Immersive mode toggle on center-third tap
  - Debounced reading progress persistence with lifecycle flush
affects: [04-tts-integration, 05-audio-playback]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Debounced progress save with eager DB capture for safe Riverpod disposal"
    - "Responsive breakpoint at shortestSide >= 600dp for tablet vs phone layout"
    - "WidgetsBindingObserver for AppLifecycleState.paused flush"
    - "Center-third tap zone for immersive mode toggle"

key-files:
  created:
    - lib/features/reader/widgets/chapter_sidebar.dart
    - lib/features/reader/widgets/chapter_drawer.dart
    - lib/features/reader/widgets/typography_sheet.dart
    - lib/features/reader/providers/reading_progress_provider.dart
    - test/widget/reader/responsive_layout_test.dart
    - test/widget/reader/font_settings_test.dart
    - test/core/db/reading_progress_debounce_test.dart
  modified:
    - lib/features/reader/reader_screen.dart

key-decisions:
  - "Eager DB capture in ReadingProgressNotifier.build() because ref.read is forbidden in Riverpod 3 onDispose callbacks"
  - "onDispose flushes pending progress to prevent silent data loss on reader teardown"
  - "Chapter swipe records progress at offset 0.0 so position is never stale after navigation"
  - "Collapsible sidebar uses AppBar toggle icon (menu/menu_open) independent of immersive mode state"

patterns-established:
  - "Debounced save with eager resource capture: capture DB ref in build(), flush in onDispose"
  - "Responsive layout: shortestSide >= 600dp breakpoint, Row with sidebar vs drawer"
  - "Immersive mode: center-third tap zone, SystemUiMode.immersiveSticky, reset in dispose"

requirements-completed: [RDR-08, RDR-09, RDR-10, RDR-11, RDR-12]

# Metrics
duration: 15min
completed: 2026-04-12
---

# Phase 3 Plan 05: Reader Chrome Summary

**Responsive chapter navigation (collapsible tablet sidebar + phone drawer), typography controls, immersive mode, and debounced reading progress persistence with lifecycle flush**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-12T16:00:00Z
- **Completed:** 2026-04-12T16:15:00Z
- **Tasks:** 3 (2 pre-checkpoint + 2 post-checkpoint bug fixes)
- **Files modified:** 8

## Accomplishments
- Tablet shows persistent 300px chapter sidebar with collapse toggle; phone shows slide-over drawer
- Typography bottom sheet with font size slider (12-28pt) and font family picker (Literata/Merriweather)
- Immersive mode toggles app bar on center-third tap with proper SystemChrome cleanup
- Reading progress debounced at 2s with immediate flush on app pause and provider disposal
- Fixed resume-on-reopen bug: progress now flushes on dispose and records chapter swipes

## Task Commits

Each task was committed atomically:

1. **Task 1: Chapter sidebar (tablet) + chapter drawer (phone) + responsive ReaderScreen layout** - `344fe2d` (feat)
2. **Task 2: Typography bottom sheet + immersive mode + progress save** - `d14466f` (feat)
3. **Bug fix: Reading position resume** - `33e1f8d` (fix)
4. **Feature: Collapsible chapter sidebar** - `1681c84` (feat)

## Files Created/Modified
- `lib/features/reader/widgets/chapter_sidebar.dart` - Persistent 300px chapter sidebar for tablet layout
- `lib/features/reader/widgets/chapter_drawer.dart` - Slide-over chapter drawer for phone layout
- `lib/features/reader/widgets/typography_sheet.dart` - Bottom sheet with font size slider and font family picker
- `lib/features/reader/providers/reading_progress_provider.dart` - Debounced progress save with 2s timer and lifecycle flush
- `lib/features/reader/reader_screen.dart` - Responsive layout, immersive mode, progress wiring, collapsible sidebar
- `test/widget/reader/responsive_layout_test.dart` - 4 tests for tablet/phone layout + chapter navigation
- `test/widget/reader/font_settings_test.dart` - 5 tests for typography sheet controls
- `test/core/db/reading_progress_debounce_test.dart` - 4 tests for debounce timing and flush behavior

## Decisions Made
- Eager DB capture in ReadingProgressNotifier.build() because ref.read is forbidden inside Riverpod 3 onDispose callbacks -- this is a Riverpod 3-specific pattern that future providers with disposal side-effects must follow
- Chapter swipe (onPageChanged) records progress at offset 0.0 so exiting after a swipe without scrolling still persists the correct chapter position
- Collapsible sidebar state is independent of immersive mode -- user's collapse preference persists when toggling immersive

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Reading progress not flushed on provider disposal**
- **Found during:** Task 3 (human verification)
- **Issue:** ReadingProgressNotifier.onDispose cancelled the timer but did not call _flushPending(), silently dropping any buffered progress when the reader screen tore down
- **Fix:** Added _flushPending() call after _debounceTimer?.cancel() in onDispose callback; also added onScrollChanged(bookId, index, 0.0) in onPageChanged so chapter swipes are recorded
- **Files modified:** lib/features/reader/providers/reading_progress_provider.dart, lib/features/reader/reader_screen.dart
- **Verification:** Existing debounce tests pass; test in isolation confirms resume
- **Committed in:** 33e1f8d

**2. [Rule 2 - Missing Critical] Tablet sidebar not collapsible**
- **Found during:** Task 3 (human verification)
- **Issue:** Persistent 300px sidebar had no hide/show mechanism -- user feedback requested collapsible sidebar
- **Fix:** Added _sidebarCollapsed state with AppBar toggle button (menu/menu_open icons); sidebar and divider conditionally rendered
- **Files modified:** lib/features/reader/reader_screen.dart
- **Verification:** All 227 tests pass including responsive layout tests
- **Committed in:** 1681c84

---

**Total deviations:** 2 auto-fixed (1 bug, 1 missing functionality)
**Impact on plan:** Both fixes necessary for correct user experience. No scope creep.

## Issues Encountered
None beyond the two bugs found during human verification.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 3 reader is feature-complete: EPUB parsing, sentence-span rendering, chapter navigation, typography controls, immersive mode, and progress persistence all working
- Ready for Phase 4 TTS integration (sherpa_onnx + Kokoro model)
- Reader architecture exposes per-sentence TextSpans which Phase 4 will use for highlight-during-playback

## Self-Check: PASSED

All 8 key files verified present. All 4 commit hashes verified in git log.

---
*Phase: 03-reader-with-sentence-span-architecture*
*Completed: 2026-04-12*
