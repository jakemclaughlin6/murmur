---
phase: 02-library-epub-import
verified: 2026-04-12T22:00:00Z
status: human_needed
score: 11/11 must-haves verified
overrides_applied: 0
human_verification:
  - test: "iOS Share from Files.app and Open-in-place from iCloud Drive"
    expected: "EPUB imports correctly via share sheet on iOS device"
    why_human: "No Mac available; iOS device testing requires physical device. Deferred per project constraint."
  - test: "Tablet grid: 4-column portrait and 6-column landscape"
    expected: "Grid renders correct column count on tablet form factor"
    why_human: "No tablet device available for verification. Code logic correct (tested with viewport override), physical hardware needed for full sign-off."
deferred:
  - truth: "iOS share intent and Open-in-place work on device"
    addressed_in: "Phase 4 (iOS App Store distribution)"
    evidence: "02-DEVICE-VERIFICATION.md explicitly defers iOS to Phase 4 CI device-test window; no-Mac constraint documented in project CLAUDE.md"
---

# Phase 02: Library + EPUB Import Verification Report

**Phase Goal:** Users can import one or more DRM-free EPUBs (via file picker or system Share / Open-in), see them in a responsive library grid on phones and tablets, and have metadata + cover art persist across restarts — backed by a rich `Chapter { blocks: List<Block> }` intermediate representation validated against a 15-EPUB test corpus.
**Verified:** 2026-04-12T22:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can import EPUB via file picker (LIB-01) | VERIFIED | `import_service.dart`: `importFromPaths()` calls `parseEpubInIsolate` + Drift insert; `import_picker.dart` wraps `FilePicker.platform.pickFiles`; `importPickerCallbackProvider` wired in LibraryScreen |
| 2 | User can import EPUB via Share / Open-in intent (LIB-02) | VERIFIED | Android manifest has 3 intent-filter blocks for `application/epub+zip` (VIEW, SEND, SEND_MULTIPLE); `share_intent_listener.dart` wired via `ref.watch(shareIntentListenerProvider)` in `app.dart:25` |
| 3 | DRM EPUBs are rejected with user-facing feedback (LIB-04) | VERIFIED | `epub_parser.dart:77-79`: `detectDrm(archive)` throws `DrmDetectedException` before any XHTML walk; `import_service.dart:163-164` maps to `ImportFailed(filename, 'DRM-protected')`; LibraryScreen snackbar surfaced via `ref.listen` |
| 4 | Block IR captures all 5 content types from EPUB XHTML (LIB-03) | VERIFIED | `epub_parser.dart` `_walkBlocks()`: Paragraph (`<p>`), Heading (`<h1>`-`<h6>`), ImageBlock (`<img>`), Blockquote (`<blockquote>`), ListItem (`<ul>/<ol>`+`<li>`) all emitted; table rows → Paragraph; footnotes → Paragraph with `[fn]` prefix |
| 5 | Metadata and covers persist across app restarts (LIB-11) | VERIFIED | `persistence_test.dart` verifies import → DB close → reopen → book + chapters intact; `books_table.dart`: 9-column schema with `filePath UNIQUE`, `coverPath`; cover written to `covers/{bookId}.jpg` |
| 6 | Schema is version 2 with v1→v2 migration (LIB-05) | VERIFIED | `app_database.dart:30`: `schemaVersion => 2`; `drift_schema_v2.json` (234 lines) checked in; `schema_v1_to_v2_test.dart` passes (test 143-144 in run) |
| 7 | Library grid is responsive with D-16 breakpoints (LIB-06) | VERIFIED | `library_grid.dart` `_columnCount()`: phone portrait=2, phone landscape=3, tablet portrait=4, tablet landscape=6; `tester.view.physicalSize` override used in widget tests; test +108 confirms 2-col phone portrait |
| 8 | Sort by recently-read, title, author (LIB-07) | VERIFIED | `library_provider.dart` `SortMode` enum + `_emit()` switch: `recentlyRead` (lastReadDate DESC, nulls-last), `title` (A-Z), `author` (A-Z, `\uFFFF` sentinel for null); `LibrarySortChips` wired to `setSortMode` |
| 9 | Search filters by title and author (LIB-08) | VERIFIED | `library_provider.dart:116-122`: `setSearchQuery` filters `_latestRaw` by `title.contains(query) || author.contains(query)`; `LibrarySearchBar` debounces 300ms; test +100-107 verifies debounce behavior |
| 10 | Long-press context sheet with Delete confirmation (LIB-09) | VERIFIED | `book_context_sheet.dart` wired via `showBookContextSheet`; `library_screen.dart:111-121`: long-press on BookCard opens sheet; tests +109-112 verify sheet shows, +116-118 verify delete dialog; `deleteBook` cascades via FK ON DELETE CASCADE |
| 11 | Empty states render correctly (LIB-10) | VERIFIED | `library_screen.dart:73-77`: first-import empty state (`_EmptyFirstImport`) when no books + no query + no import in flight; `library_screen.dart:96-108`: "No books match your search" when hasQuery but no results; tests +113-116 and +119-129 verify both variants |

**Score:** 11/11 truths verified

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | iOS share intent and Open-in-place | Phase 4 | 02-DEVICE-VERIFICATION.md defers iOS to CI device-test window; no-Mac constraint in CLAUDE.md |
| 2 | Tablet 4/6-column grid on physical hardware | Phase 4 | No tablet device available; code logic verified via viewport override in widget tests |

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/core/epub/block.dart` | Sealed class hierarchy (5 Block types) | VERIFIED | Exists, substantive (per 02-02-SUMMARY: 137 lines); 5 variants: Paragraph, Heading, ImageBlock, Blockquote, ListItem |
| `lib/core/epub/block_json.dart` | JSON codec for Block IR | VERIFIED | Exists; imported by `import_service.dart:40` and used at line 261 (`blocksToJsonString`) |
| `lib/core/epub/epub_parser.dart` | DOM walker with package:html | VERIFIED | 323 lines; imports `package:html/dom.dart` and `package:html/parser.dart`; `_walkBlocks()` handles all 5 Block types + table + footnote + recursive div/section |
| `lib/core/epub/epub_parser_isolate.dart` | Isolate.run wrapper | VERIFIED | 35 lines; `Isolate.run(() => parseEpub(bytes))`; Flutter-free |
| `lib/core/epub/drm_detector.dart` | DRM detection before parse | VERIFIED | Called at `epub_parser.dart:77` before any XHTML walk |
| `lib/core/epub/parse_result.dart` | ParseResult + ParsedChapter types | VERIFIED | Imported throughout import pipeline |
| `lib/core/db/tables/books_table.dart` | 9-column Books table | VERIFIED | 34 lines; all 9 columns present including `filePath UNIQUE` |
| `lib/core/db/tables/chapters_table.dart` | Chapters table with blocks_json | VERIFIED | Per 02-03-SUMMARY; blocks_json TEXT column |
| `lib/core/db/schema_versions.dart` | v1→v2 migration | VERIFIED | 208 lines; `schemaVersion => 2`; migration strategy defined |
| `drift_schemas/drift_schema_v2.json` | Drift schema snapshot | VERIFIED | 234 lines, checked in |
| `lib/features/library/import_service.dart` | Full import pipeline (LIB-01+LIB-02) | VERIFIED | 274 lines; calls `parseEpubInIsolate`, Drift insert, cover write; all error cases handled |
| `lib/features/library/share_intent_listener.dart` | Share intent handler | VERIFIED | Wired via `shareIntentListenerProvider` in `app.dart:25` |
| `lib/features/library/library_provider.dart` | Reactive Drift stream + sort/search | VERIFIED | 214 lines; `db.select(db.books).watch()` drives `StreamController`; sort + search in `_emit()` |
| `lib/features/library/book_card.dart` | BookCard with cover + metadata | VERIFIED | Per 02-06-SUMMARY: 149 lines with `coverImageOverride` test seam |
| `lib/features/library/book_card_shimmer.dart` | ShaderMask shimmer | VERIFIED | Per 02-06-SUMMARY: 107 lines; hand-rolled ShaderMask shimmer |
| `lib/features/library/library_grid.dart` | Responsive SliverGrid | VERIFIED | 95 lines; D-16 breakpoints; shimmer prepend; tap→`/reader/:bookId` |
| `lib/features/library/library_screen.dart` | Full LibraryScreen composition | VERIFIED | 175 lines; CustomScrollView + SliverAppBar + SearchBar + SortChips + Grid; both empty states; snackbar on import fail |
| `lib/features/library/book_context_sheet.dart` | Long-press context sheet with delete | VERIFIED | Wired in library_screen.dart:119; tests confirm dialog |
| `lib/app/router.dart` | `/reader/:bookId` route + redirect | VERIFIED | GoRoute at line 66-72; top-level redirect for unknown URIs at lines 21-29 |
| `android/app/src/main/AndroidManifest.xml` | 3 intent-filter blocks for epub | VERIFIED | Lines 57, 65, 73: `application/epub+zip` in VIEW, SEND, SEND_MULTIPLE intent-filters |
| `test/fixtures/epub/corpus/*.epub` | 15-EPUB synthetic corpus | VERIFIED | `ls` confirms 15 files; synthesized via `_build_corpus.dart` using `package:archive` |
| `test/library/epub_parser_corpus_test.dart` | Corpus parser sweep (LIB-03) | VERIFIED | Exists; test +130 in run confirms corpus test passes |
| `test/library/persistence_test.dart` | Persistence round-trip (LIB-11) | VERIFIED | Exists; test +141-142 confirm LIB-11 passes |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `LibraryScreen` | `libraryProvider` | `ref.watch(libraryProvider)` | WIRED | `library_screen.dart:56`; data flows to book list and empty state logic |
| `LibraryGrid` | `importProvider` | `ref.watch(importProvider)` | WIRED | `library_grid.dart:59`; `ImportParsing` entries become shimmer cards |
| `LibraryScreen` | `importProvider` | `ref.listen(importProvider, ...)` | WIRED | `library_screen.dart:38`; `ImportFailed` entries surface as snackbars |
| `LibraryScreen` | `importPickerCallbackProvider` | `ref.read(importPickerCallbackProvider)(ref)` | WIRED | `library_screen.dart:75, 90`; file picker wired to import pipeline |
| `import_service.dart` | `parseEpubInIsolate` | `await parseEpubInIsolate(bytes)` | WIRED | `import_service.dart:205`; result used at line 207+ |
| `import_service.dart` | Drift `db.books.insert` | `db.into(db.books).insert(...)` | WIRED | `import_service.dart:221`; result `bookId` used for cover and chapters |
| `import_service.dart` | `blocksToJsonString` | `blocksToJsonString(ch.blocks)` | WIRED | `import_service.dart:261`; serialized into `ChaptersCompanion.blocksJson` |
| `app.dart` | `shareIntentListenerProvider` | `ref.watch(shareIntentListenerProvider)` | WIRED | `app.dart:25`; boots share intent pipeline at app startup |
| `epub_parser.dart` | `detectDrm` | `if (detectDrm(archive)) throw DrmDetectedException` | WIRED | `epub_parser.dart:77-79`; DRM check before any XHTML walk |
| `library_provider.dart` | `db.select(db.books).watch()` | `_subscription = db.select(db.books).watch().listen(...)` | WIRED | `library_provider.dart:94`; stream drives `StreamController` which is returned to Riverpod |
| `router.dart` | `/reader/:bookId` | `GoRoute(path: '/reader/:bookId', ...)` | WIRED | `router.dart:66-72`; `bookId` parsed from path parameters |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `LibraryScreen` | `state.books` | `db.select(db.books).watch()` via `LibraryNotifier._emit()` | Yes — reactive Drift query on real SQLite table | FLOWING |
| `LibraryGrid` | `books` prop | `state.books` from `libraryProvider` | Yes — passed from LibraryScreen data state | FLOWING |
| `LibraryGrid` (shimmer) | `parsing` | `importProvider` `whereType<ImportParsing>()` | Yes — populated during actual import pipeline | FLOWING |
| `BookCard` | `book` (title, author, cover) | `Book` row from Drift | Yes — direct Drift data class with real columns | FLOWING |

---

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite (144 tests) | `mise exec -- flutter test` | `+144: All tests passed!` | PASS |
| Static analysis | `mise exec -- flutter analyze` | 1 warning: `invalid_section_format` in `analysis_options.yaml:9` (riverpod_lint `plugins:` block — known quirk, not a code defect) | PASS |
| 15 corpus EPUBs present | `ls test/fixtures/epub/corpus/*.epub \| wc -l` | 15 | PASS |
| Drift schema v2 JSON | `ls drift_schemas/drift_schema_v2.json` | 234 lines | PASS |
| Android epub intent-filters | grep `application/epub+zip` in AndroidManifest.xml | 3 matches (VIEW, SEND, SEND_MULTIPLE) | PASS |
| GoRouter deep-link redirect | grep `redirect:` in router.dart | Top-level redirect for unknown URIs present | PASS |

---

## Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| LIB-01 | Import EPUB via file picker | SATISFIED | `import_service.dart` `importFromPaths()`; `import_picker.dart` wraps FilePicker; wired in LibraryScreen |
| LIB-02 | Import via Share / Open-in | SATISFIED | Android manifest intent-filters; `share_intent_listener.dart`; wired at `app.dart:25` |
| LIB-03 | Block IR + corpus validation (13 valid EPUBs parse, 2 throw) | SATISFIED | `epub_parser.dart` walks all 5 Block types; `epub_parser_corpus_test.dart` passes |
| LIB-04 | DRM rejection | SATISFIED | `detectDrm` before XHTML walk; `DrmDetectedException` → `ImportFailed`; snackbar shown |
| LIB-05 | Schema v2 with migration | SATISFIED | `schemaVersion => 2`; `drift_schema_v2.json`; v1→v2 migration test passes |
| LIB-06 | Responsive grid (D-16 breakpoints) | SATISFIED | `library_grid.dart` `_columnCount()`: 2/3/4/6 columns; widget tests with viewport override pass |
| LIB-07 | Sort by recently-read / title / author | SATISFIED | `SortMode` enum in `library_provider.dart`; `LibrarySortChips` calls `setSortMode` |
| LIB-08 | Search by title and author | SATISFIED | `setSearchQuery` filters by both; `LibrarySearchBar` debounces 300ms |
| LIB-09 | Long-press context sheet + delete | SATISFIED | `book_context_sheet.dart`; delete with confirmation dialog; ON DELETE CASCADE via FK |
| LIB-10 | Empty states (first-import + no-results) | SATISFIED | Two distinct empty states in `library_screen.dart`; both widget-tested |
| LIB-11 | Persistence round-trip | SATISFIED | `persistence_test.dart` verifies import → DB close → reopen → data intact |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `analysis_options.yaml` | 9 | `invalid_section_format` (riverpod_lint `plugins:` block format) | Info | Known quirk of riverpod_lint 3.x/analysis_server_plugin migration — not a code defect, no functional impact |

No STUB, MISSING, or ORPHANED artifacts found. No TODO/FIXME/placeholder code stubs. All "placeholder" text in source files refers to intentional ShaderMask shimmer cards or empty-state UI (correct behavior, not incomplete implementation).

---

## Human Verification Required

### 1. iOS Share from Files.app

**Test:** On a physical iOS device, long-press an EPUB file in Files.app and tap "Share" → select Murmur from the share sheet.
**Expected:** EPUB imports, metadata appears in library grid within a few seconds.
**Why human:** No Mac available (project constraint); iOS device testing requires physical hardware. CI builds `.xcarchive` but physical device install requires Apple Developer Program enrollment (Phase 4 scope).

### 2. iOS Open-in-place from iCloud Drive

**Test:** On a physical iOS device, tap an EPUB in Files.app/iCloud Drive → "Open in..." → Murmur.
**Expected:** EPUB imports and appears in library grid.
**Why human:** Same constraint as above — no Mac, no iOS device for physical verification.

### 3. Tablet Grid Columns on Physical Hardware

**Test:** Open the app on a tablet in portrait and landscape orientation.
**Expected:** Portrait shows 4 columns, landscape shows 6 columns.
**Why human:** No tablet device available. The `_columnCount()` logic uses `shortestSide >= 600` breakpoint — code is correct and widget-tested with `tester.view.physicalSize` viewport override, but physical hardware verification is the gold standard.

---

## Gaps Summary

No gaps found. All 11 observable truths are VERIFIED against actual implementation code. Three items are deferred to human verification due to hardware constraints (iOS device, Mac, tablet), not code deficiencies.

The single analyzer warning (`invalid_section_format` in `analysis_options.yaml`) is a known artifact of the riverpod_lint 3.x `plugins:` section format and has no functional impact.

**Test suite:** 144 tests, 0 failures, 0 errors.

---

_Verified: 2026-04-12T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
