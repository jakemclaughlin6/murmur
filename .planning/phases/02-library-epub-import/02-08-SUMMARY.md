---
phase: 02-library-epub-import
plan: 08
subsystem: testing
tags: [epub, corpus, persistence, device-verification, drift]

requires:
  - phase: 02-library-epub-import/02-04
    provides: EPUB parser (parseEpub)
  - phase: 02-library-epub-import/02-05
    provides: ImportNotifier pipeline
  - phase: 02-library-epub-import/02-07
    provides: LibraryScreen composition
provides:
  - 15-EPUB synthetic corpus covering all edge cases from 02-VALIDATION.md
  - Corpus parser sweep test (LIB-03)
  - Persistence round-trip test (LIB-11)
  - Android device verification sign-off
  - Release build fixes (win32, JVM target, GoRouter deep-link redirect)
affects: [phase-03-reader]

tech-stack:
  added: []
  patterns: [synthetic-epub-corpus-builder, persistence-round-trip-test]

key-files:
  created:
    - test/fixtures/epub/corpus/_build_corpus.dart
    - test/fixtures/epub/corpus/README.md
    - test/fixtures/epub/corpus/*.epub (15 files)
    - .planning/phases/02-library-epub-import/02-DEVICE-VERIFICATION.md
  modified:
    - test/library/epub_parser_corpus_test.dart
    - test/library/persistence_test.dart
    - pubspec.yaml
    - android/build.gradle.kts
    - lib/app/router.dart

key-decisions:
  - "Synthesized all 15 corpus EPUBs rather than sourcing from Project Gutenberg — exercises identical code paths at fraction of repo size"
  - "Scaled down case 5 (20 chapters) and case 6 (5 chapters × 3 small images) — multi-chapter/image iteration is the same at any scale"
  - "Downgraded package_info_plus from ^10 to ^9 and removed win32 ^6 override — file_picker 11.0.2 Windows impl incompatible with win32 6.x, breaks AOT compilation"
  - "Added GoRouter top-level redirect for unknown URIs — Android VIEW/SEND intents push content:// URIs that GoRouter can't match"

patterns-established:
  - "Synthetic EPUB corpus: _build_corpus.dart generates test fixtures using package:archive, checked in for hermetic tests"
  - "GoRouter redirect guard: unknown deep-link URIs redirect to /library, share intents handled by receive_sharing_intent"

requirements-completed: [LIB-02, LIB-03, LIB-04, LIB-05, LIB-11]

duration: ~90min
completed: 2026-04-12
---

# Plan 02-08: Corpus Sweep + Persistence + Device Verification Summary

**15-EPUB synthetic corpus validates parser edge cases, persistence survives DB reopen, and Android device verification passes with 3 release-build fixes**

## Performance

- **Duration:** ~90 min
- **Started:** 2026-04-12
- **Completed:** 2026-04-12
- **Tasks:** 3 (1 human-action, 1 auto, 1 human-verify)
- **Files modified:** 22

## Accomplishments
- Synthesized 15-EPUB corpus covering all edge cases from 02-VALIDATION.md (standard, no-cover, no-author, UTF-8, multi-chapter, images, tables, footnotes, blockquotes, malformed XHTML, EPUB 2, spine reorder, DRM, corrupt zip, multi-cover)
- Corpus parser sweep: all 13 valid EPUBs parse correctly, DRM and corrupt entries throw expected exceptions
- Persistence round-trip: import → close DB → reopen from same file → book + chapters verified
- Full test suite: 144 tests, 0 failures
- Android device verification: 10/10 applicable checks PASS (tablet N/A, iOS deferred)

## Task Commits

1. **Task 1+2: Corpus + tests** — `5111547` (test: 15-EPUB corpus + parser sweep + persistence)
2. **Fix: win32 override** — `16da3c5` (fix: downgrade package_info_plus for release build)
3. **Fix: JVM target** — `aa6eef9` (fix: force JVM 17 on all subprojects)
4. **Fix: GoRouter deep-link** — `462be34` (fix: redirect unknown deep-link URIs to /library)

## Deviations from Plan

### Auto-fixed Issues

**1. Release build: file_picker / win32 incompatibility**
- **Found during:** Device verification (flutter run --release)
- **Issue:** file_picker 11.0.2 Windows impl uses win32 5.x API, but dependency_override forced win32 ^6.0.0. Dart AOT compiler processes all platform code during Android builds.
- **Fix:** Downgraded package_info_plus from ^10 to ^9, removed win32 override. Both packages resolve to win32 5.15.0.
- **Files modified:** pubspec.yaml, pubspec.lock

**2. Release build: receive_sharing_intent JVM target mismatch**
- **Found during:** Device verification (flutter run --release)
- **Issue:** Plugin ships Java 1.8 / Kotlin 17 mismatch in its build.gradle.
- **Fix:** Added subprojects block in root build.gradle.kts forcing JVM 17 via plugins.withId.
- **Files modified:** android/build.gradle.kts

**3. GoRouter crash on Share/Open-in intent**
- **Found during:** Device verification (open EPUB from Files app)
- **Issue:** Android VIEW intents push content:// URIs into Flutter route info. GoRouter threw "no routes for location".
- **Fix:** Added top-level redirect — unknown URIs → /library. ShareIntentListener handles the actual import separately.
- **Files modified:** lib/app/router.dart

---

**Total deviations:** 3 auto-fixed (all blocking release-build or runtime issues)
**Impact on plan:** All fixes necessary for the app to run on real hardware. No scope creep.

## Issues Encountered
- UTF-8 encoding bug in initial corpus builder (used String.codeUnits instead of utf8.encode) — fixed before commit

## User Setup Required
None.

## Next Phase Readiness
- Phase 2 is complete: EPUB import, parse, persist, browse, sort, search, delete all verified
- Phase 3 (Reader with Sentence-Span Architecture) can begin
- iOS device testing deferred per no-Mac constraint; will surface in /gsd-progress and /gsd-audit-uat

---
*Phase: 02-library-epub-import*
*Completed: 2026-04-12*
