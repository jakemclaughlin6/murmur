---
phase: 02-library-epub-import
plan: 04
subsystem: epub-parser
tags: [epubx, package:html, archive, image, isolate, drm, block-ir]

requires:
  - phase: 02-library-epub-import
    provides: Block IR sealed hierarchy (Paragraph/Heading/ImageBlock/Blockquote/ListItem) and block_json codec from Plan 02-02; Drift v2 schema with books + chapters tables from Plan 02-03; epubx ^4.0.0 + receive_sharing_intent ^1.8.1 Phase 1 spike verdicts

provides:
  - Pure-Dart EPUB parser — parseEpub(bytes) -> Future<ParseResult>
  - DRM detector — detectDrm(Archive) short-circuit before any XHTML work
  - Isolate wrapper — parseEpubInIsolate(bytes) via dart:isolate Isolate.run
  - ParseResult record types — ParseResult, ParsedChapter, ChapterError
  - DOM walker — parseChapterXhtml(xhtml) covers all 5 Block variants + D-02 flattening
  - Three synthetic EPUB 3 fixtures (minimal, drm_encrypted, malformed_xhtml) + rebuilder script

affects:
  - 02-05-PLAN (import service consumes parseEpubInIsolate)
  - 02-08-PLAN (15-EPUB corpus test reuses parseEpubInIsolate)
  - 03 reader (consumes chapters.blocks_json produced by this parser via Plan 05)

tech-stack:
  added:
    - archive ^3.6.1 (promoted transitive -> direct)
    - image ^3.3.0 (promoted transitive -> direct; used for JPEG cover re-encode)
  patterns:
    - "Parser purity: zero package:flutter/* imports in lib/core/epub/ so Isolate.run works without TestWidgetsFlutterBinding"
    - "Graceful per-chapter degradation: catch per-chapter XHTML errors, record ChapterError, continue with next spine item"
    - "DRM short-circuit runs on Archive BEFORE epubx touches content"
    - "Dart 3 Isolate.run over Flutter compute() to keep the call site Flutter-free"

key-files:
  created:
    - lib/core/epub/parse_result.dart
    - lib/core/epub/drm_detector.dart
    - lib/core/epub/epub_parser.dart
    - lib/core/epub/epub_parser_isolate.dart
    - test/fixtures/epub/_build_fixtures.dart
    - test/fixtures/epub/minimal.epub
    - test/fixtures/epub/drm_encrypted.epub
    - test/fixtures/epub/malformed_xhtml.epub
  modified:
    - pubspec.yaml (add archive, image)
    - pubspec.lock
    - test/library/drm_detector_test.dart (replace Wave 0 stub)
    - test/core/epub/epub_parser_test.dart (replace Wave 0 stub)
    - test/core/epub/epub_parser_isolate_test.dart (replace Wave 0 stub)

key-decisions:
  - "Make parseEpub async (Future<ParseResult>) because epubx.EpubReader.readBook is async; Isolate.run accepts FutureOr<R> so the isolate wrapper still composes"
  - "Re-encode cover image to JPEG via package:image/encodeJpg rather than extracting original bytes from the archive manifest — matches D-06 (covers stored as ${bookId}.jpg) with ~40 LOC of glue instead of a parallel cover extraction path"
  - "Parser is pure Dart with zero package:flutter/* imports so it can run inside Isolate.run without TestWidgetsFlutterBinding and is trivially unit-testable"
  - "Hand-rolled EPUB fixtures (~1.5 KB each) built by a checked-in Dart script — hermetic, regeneratable, no network fetch, no copyright cloud over the test corpus"
  - "DOM walker accepts body-level text nodes as Paragraph — research Pattern 2 only walked element children and would silently drop chapter-level raw text"
  - "Isolate wrapper uses dart:isolate Isolate.run directly, not package:flutter/foundation.dart compute(), so lib/core/epub/ stays Flutter-free"

patterns-established:
  - "Test fixtures built by a checked-in Dart script (test/fixtures/epub/_build_fixtures.dart) + checked-in .epub binaries: anyone can regenerate, nothing is guessed, CI is hermetic"
  - "Typed exceptions at the parser boundary (DrmDetectedException, EpubParseException) carry a reason String and survive isolate marshaling; tests pin both the subclass identity and the reason string so a Dart SDK regression is loud"
  - "DOM walker switch emits Block variants with normalizeWhitespace applied to .text; unknown tags best-effort-extract; script/style/meta silently dropped"

requirements-completed:
  - LIB-03
  - LIB-04

duration: ~35 min
completed: 2026-04-11
---

# Phase 2 Plan 4: EPUB Parser Core Summary

**Pure-Dart EPUB parser (epubx + package:html) that converts bytes to a Block IR `ParseResult` in a background isolate, rejects DRM-protected EPUBs up front, and degrades gracefully on malformed XHTML.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-11T21:03Z (post 02-03 handoff)
- **Completed:** 2026-04-11T~21:38Z
- **Tasks:** 3
- **Files modified:** 13 (4 created under lib/core/epub/, 3 fixtures + 1 builder created, 3 tests un-skipped, pubspec.yaml/lock updated)
- **Test delta:** +16 real tests across drm_detector_test / epub_parser_test / epub_parser_isolate_test, 3 Wave 0 stubs removed. Full suite: 74 pass / 11 skipped / 0 fail (was 55 / 14 / 0).

## Accomplishments

- Parser pipeline: `decode zip -> detectDrm -> epubx readBook -> package:html DOM walk -> cover JPEG re-encode -> ParseResult`
- All 5 Block variants emitted from real XHTML (Paragraph, Heading, ImageBlock, Blockquote, ListItem)
- D-02 flattening rules implemented: tables → row-by-row Paragraphs with `" | "` separators, footnote/note asides → `"[fn] "`-prefixed Paragraphs, div/section/article recurse, script/style silently dropped
- DRM short-circuit: `META-INF/encryption.xml` OR `META-INF/rights.xml` → `DrmDetectedException` BEFORE any XHTML is parsed (LIB-04, T-02-04-02)
- Graceful per-chapter degradation: a malformed chapter records a `ChapterError` and emits `const []` blocks — the whole book still imports
- Isolate wrapper: `parseEpubInIsolate(bytes)` = `Isolate.run(() => parseEpub(bytes))`. Both `DrmDetectedException` and `EpubParseException` verified to cross the isolate boundary intact (T-02-04-06 canary tests)
- Three synthetic EPUB 3 fixtures checked in (~1.5 KB each) plus a checked-in Dart rebuilder script so anyone can regenerate or extend them

## Task Commits

1. **Task 1: DRM detector + ParseResult + fixtures** — `87358a0` (feat)
2. **Task 2: Parser core with DOM walker** — `d090802` (feat)
3. **Task 3: Isolate wrapper** — `9592ce0` (feat)

**Plan metadata:** _(this SUMMARY.md + STATE/ROADMAP updates)_

## Files Created/Modified

### Created
- `lib/core/epub/parse_result.dart` — ParseResult / ParsedChapter / ChapterError record types
- `lib/core/epub/drm_detector.dart` — `detectDrm(Archive)` + `DrmDetectedException`
- `lib/core/epub/epub_parser.dart` — `parseEpub(bytes)` + `parseChapterXhtml(xhtml)` + `EpubParseException`
- `lib/core/epub/epub_parser_isolate.dart` — `parseEpubInIsolate(bytes)` via `dart:isolate` `Isolate.run`
- `test/fixtures/epub/_build_fixtures.dart` — hand-rolled EPUB 3 fixture builder
- `test/fixtures/epub/minimal.epub` — ~1.5 KB valid EPUB, 1 chapter, 1 paragraph, no cover
- `test/fixtures/epub/drm_encrypted.epub` — minimal + empty META-INF/encryption.xml marker
- `test/fixtures/epub/malformed_xhtml.epub` — minimal but chapter XHTML has unclosed `<em>`

### Modified
- `pubspec.yaml` — promote `archive ^3.6.1` and `image ^3.3.0` from transitive to direct deps
- `pubspec.lock` — regenerated
- `test/library/drm_detector_test.dart` — replace Wave 0 stub with 4 real tests (clean, DRM marker, empty archive, exception shape)
- `test/core/epub/epub_parser_test.dart` — replace Wave 0 stub with 12 real tests (4 fixture end-to-end + 7 DOM walker + 1 exception shape)
- `test/core/epub/epub_parser_isolate_test.dart` — replace Wave 0 stub with 3 real tests (happy path, DrmDetectedException propagation, EpubParseException propagation)

## Decisions Made

1. **`parseEpub` is async, not sync as the plan interface showed.** `epubx.EpubReader.readBook(bytes)` is `async`, and `Isolate.run` takes a `FutureOr<R>`, so making the parser return `Future<ParseResult>` composes cleanly with the isolate wrapper and avoids a pointless sync-over-async wrapper. Advisor flagged this before I started coding.
2. **Re-encode cover to JPEG via `package:image/encodeJpg` (quality 85).** epubx hands back a decoded `images.Image`, not the original bytes, so preserving the original format would require extracting from the archive manifest directly — more code. Plan 05 (D-06) writes covers to disk as `${bookId}.jpg` anyway, so JPEG is the right target format, and a ~40-LOC glue path beats a parallel cover extractor.
3. **Parser is pure Dart with zero `package:flutter/*` imports.** This makes it isolate-safe for `Isolate.run` (no `TestWidgetsFlutterBinding` needed) and means the DOM walker can be exercised directly in unit tests via `parseChapterXhtml(xhtml)` without rebuilding whole EPUBs each time.
4. **Hand-rolled fixtures built by a checked-in Dart script.** Alternatives (fetch from Project Gutenberg at test time, commit real-world EPUBs) both have footguns: network at test time breaks offline dev, real EPUBs have opaque copyright and pointer-bloat. A 4 KB builder that emits 1.5 KB fixtures is hermetic, reviewable, and regeneratable.
5. **DOM walker recurses into `nodes` not `children`.** The research Pattern 2 snippet only iterated `.children` (elements), which silently drops body-level text nodes. The implemented walker handles `dom.Text` nodes at the body level and wraps non-empty runs in `Paragraph`, matching the "text nodes outside any recognized block → wrap in Paragraph" rule from the plan's `<action>` block.
6. **Isolate wrapper uses `dart:isolate` directly, not `package:flutter/foundation.dart compute()`.** `compute()` is a thin Flutter wrapper around `Isolate.run`; going direct keeps the wrapper file Flutter-free, and test 1 runs under `flutter_test` without needing a widget binding.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `parseEpub` interface sync → async**
- **Found during:** Task 2 (parser core)
- **Issue:** The plan's `<interfaces>` block showed `ParseResult parseEpub(List<int> bytes)` (sync). But `epubx.EpubReader.readBook(bytes)` is async in epubx 4.0.0, so a sync `parseEpub` would either block the isolate or require a sync-over-async anti-pattern.
- **Fix:** Changed the signature to `Future<ParseResult> parseEpub(List<int> bytes)`. `Isolate.run` accepts `FutureOr<R>` so the isolate wrapper is unchanged. All tests use `async/await`.
- **Files modified:** `lib/core/epub/epub_parser.dart`, test files
- **Verification:** All 16 parser and isolate tests pass
- **Committed in:** `d090802` (Task 2)

**2. [Rule 3 - Blocking] Promote `archive` from transitive to direct dep**
- **Found during:** Task 1 (DRM detector)
- **Issue:** `drm_detector.dart` imports `package:archive/archive.dart` directly, but `archive` was only transitive via `epubx`. Using a transitive import is a `depend_on_referenced_packages` lint and a stability risk (an epubx internal change could drop the transitive edge).
- **Fix:** Added `archive: ^3.6.1` (matching lockfile) to `pubspec.yaml` direct deps.
- **Committed in:** `87358a0` (Task 1)

**3. [Rule 3 - Blocking] Promote `image` from transitive to direct dep**
- **Found during:** Task 2 (parser core, cover encoding)
- **Issue:** `epub_parser.dart` imports `package:image/image.dart` directly to call `encodeJpg` on epubx's `CoverImage`. Analyzer flagged `depend_on_referenced_packages`.
- **Fix:** Added `image: ^3.3.0` to `pubspec.yaml` direct deps.
- **Committed in:** `d090802` (Task 2)

**4. [Rule 1 - Bug] `const Heading(...)` in test was a compile error**
- **Found during:** Task 2 (first test run)
- **Issue:** `Heading` is not const (it has an `ArgumentError` level-range validator in its constructor, per Phase 2 Plan 02 decision), so `const Heading(level: 1, ...)` in a test expectation failed to compile.
- **Fix:** Removed the `const` keyword on that single expectation. Other `Heading` instances in the test file were inside non-const list literals and didn't need changes.
- **Committed in:** `d090802` (Task 2)

**5. [Rule 1 - Doc] Escape angle brackets in doc comment**
- **Found during:** Task 2 (post-test analyze)
- **Issue:** Analyzer warned `unintended_html_in_doc_comment` on `"<behavior>"` in the test file's dartdoc.
- **Fix:** Wrapped `<behavior>` in backticks.
- **Committed in:** `d090802` (Task 2)

---

**Total deviations:** 5 auto-fixed (1 signature-correctness, 2 missing-direct-deps, 1 const-constructor bug, 1 doc-comment lint).
**Impact on plan:** No scope creep. All deviations were either interface-spec corrections (the plan's `<interfaces>` block was aspirational, not literal), missing explicit deps, or minor test/doc fixes. No architectural changes — Rule 4 never triggered.

## Issues Encountered

- **Pre-existing warning unrelated to this plan:** `analysis_options.yaml:9:3 invalid_section_format` on the `plugins:` section. Traced via `git log analysis_options.yaml` to commit `a6f6e7f fix(01): IN-01 use bare plugin name in analysis_options plugins block` from Phase 1. Out of scope per the execute-plan scope boundary rule. Noted here for the verifier.
- **Pre-existing outdated-dep notices:** 18 packages have newer versions blocked by constraint overrides (analyzer, dart_style, win32, etc). All from Plan 02-01's documented overrides; not introduced by this plan.

## User Setup Required

None — no external service configuration required. The parser is a pure-Dart library and the fixtures are checked in.

## Next Phase Readiness

**Ready for Plan 02-05 (import service):**
- `parseEpubInIsolate(bytes)` is the canonical entry point. Import service should call it from a Riverpod notifier, catch `DrmDetectedException` and `EpubParseException` for D-12 snackbars, and write the returned `coverBytes` to `${appDocumentsDir}/covers/${bookId}.jpg` per D-06.
- `ParseResult.chapters` is already in spine order with zero-based `orderIndex`, so the import service can loop and insert `chapters` rows with no reordering work.
- `ParseResult.errors` is non-empty for books with malformed chapters — the import service should decide whether to surface this to the user (Phase 2 recommendation: import anyway, log count, no user-facing surface until Phase 6 polish).

**Also ready for Plan 02-08 (15-EPUB corpus test):**
- The corpus test can wire up `parseEpubInIsolate` against 15 real EPUBs and assert: every book parses without throwing (or throws `DrmDetectedException` for known-DRM titles), every chapter has a non-empty block list OR a matching `ChapterError`, every title is non-empty.

**Known limitations to revisit:**
- Cover extraction re-encodes via package:image, which is lossy for originally-PNG covers. If Phase 6 polish surfaces cover quality complaints, extract from the archive manifest directly (requires parsing the OPF to find the `cover-image` property).
- DOM walker doesn't recurse into `<blockquote>` children — nested block-level content in a quote is flattened to `.text`. The plan's `<action>` block explicitly scoped this as "keep it simple for Phase 2".

---

## Self-Check: PASSED

Verified:
- `lib/core/epub/parse_result.dart` — FOUND
- `lib/core/epub/drm_detector.dart` — FOUND
- `lib/core/epub/epub_parser.dart` — FOUND
- `lib/core/epub/epub_parser_isolate.dart` — FOUND
- `test/fixtures/epub/minimal.epub` — FOUND (1498 bytes)
- `test/fixtures/epub/drm_encrypted.epub` — FOUND (1622 bytes)
- `test/fixtures/epub/malformed_xhtml.epub` — FOUND (1499 bytes)
- `test/fixtures/epub/_build_fixtures.dart` — FOUND
- Commit `87358a0` (Task 1) — FOUND
- Commit `d090802` (Task 2) — FOUND
- Commit `9592ce0` (Task 3) — FOUND
- `flutter test` — 74 pass / 11 skipped / 0 fail (+19 vs baseline of 55/14/0)
- `flutter analyze` — no new issues (one pre-existing `analysis_options.yaml` warning from Phase 1, out of scope)
- Zero `package:flutter/*` imports in `lib/core/epub/` — verified by `grep -n '^import.*package:flutter' lib/core/epub/*.dart` (one doc-comment mention of `package:flutter/foundation.dart` in `epub_parser_isolate.dart` explains why this file uses `dart:isolate` directly instead of `compute()`; no actual import statement)

---

*Phase: 02-library-epub-import*
*Completed: 2026-04-11*
