---
phase: 02-library-epub-import
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/app/router.dart
  - android/build.gradle.kts
  - pubspec.yaml
  - test/library/epub_parser_corpus_test.dart
  - test/library/persistence_test.dart
  - test/fixtures/epub/corpus/_build_corpus.dart
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the six files changed during Plan 02-08 (corpus sweep, persistence test, and release build fixes). The codebase is clean overall. The corpus builder is well-structured with correct EPUB packaging (uncompressed mimetype entry, proper OPF manifests). The persistence test correctly validates DB round-trip semantics with proper teardown ordering. The Gradle build fix for JVM 17 normalization is well-documented. One warning found in the router regarding unguarded `int.parse` on a URL path parameter.

## Warnings

### WR-01: Unguarded int.parse on route parameter can crash on malformed deep links

**File:** `lib/app/router.dart:69`
**Issue:** `int.parse(state.pathParameters['bookId']!)` throws an unhandled `FormatException` if the `bookId` segment is not a valid integer (e.g., a deep link to `/reader/abc` or `/reader/null`). The redirect guard on lines 21-29 allows any path starting with `/reader` through, including `/reader/not-a-number`. On Android, malformed intents or deep links could trigger this crash path.
**Fix:** Use `int.tryParse` with a fallback redirect to `/library`:
```dart
builder: (context, state) {
  final bookId = int.tryParse(state.pathParameters['bookId'] ?? '');
  if (bookId == null) return const LibraryScreen();
  return ReaderScreen(bookId: bookId);
},
```

---

_Reviewed: 2026-04-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
