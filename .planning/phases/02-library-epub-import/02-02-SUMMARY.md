---
phase: 02-library-epub-import
plan: 02
subsystem: domain-model
tags: [block-ir, sealed-class, dart3-pattern-matching, json-codec, epub, tdd, nyquist-scaffold]

# Dependency graph
requires:
  - phase: 02-library-epub-import
    provides: "Plan 02-01 dependency graph (analyzer ^10 overrides, drift_dev codegen, epubx spike PASS) — Block IR types compile under the real drift_dev pipeline"
provides:
  - "Sealed Block hierarchy (Paragraph, Heading, ImageBlock, Blockquote, ListItem) per D-01"
  - "Block <-> JSON codec with exhaustive-switch toJson and tampering-resistant fromJson per D-03"
  - "13 Wave 0 test stubs satisfying the Nyquist rule for Plans 04-08 (one per validation-map row that was missing)"
  - "Frozen persistence contract for `chapters.blocks_json`: discriminator field `type` with values paragraph/heading/image/blockquote/list_item"
affects: [02-03, 02-04, 02-05, 02-06, 02-07, 02-08, phase-03-reader]

# Tech tracking
tech-stack:
  added: []  # Plan 02-02 adds no new packages — it consumes the ones installed in Plan 02-01
  patterns:
    - "Dart 3 sealed class + exhaustive switch expression in toJson — adding a 6th variant downstream is a compile error (enforces D-01's closed set)"
    - "Hand-rolled value equality on each Block subclass (no freezed, no json_serializable — per CLAUDE.md Dart 3 preference)"
    - "Wave 0 scaffold pattern: every file listed in validation map exists as skipped stub before later plans run (Nyquist sampling)"
    - "Test stub doc-comment convention: requirement IDs + D-xx decisions + target plan referenced in file-level library-directive comment"

key-files:
  created:
    - "lib/core/epub/block.dart"
    - "lib/core/epub/block_json.dart"
    - "test/core/epub/block_json_test.dart"
    - "test/core/epub/epub_parser_test.dart"
    - "test/core/epub/epub_parser_isolate_test.dart"
    - "test/library/drm_detector_test.dart"
    - "test/library/import_service_test.dart"
    - "test/library/share_intent_test.dart"
    - "test/library/library_provider_test.dart"
    - "test/library/book_card_test.dart"
    - "test/library/library_grid_test.dart"
    - "test/library/library_search_test.dart"
    - "test/library/book_context_sheet_test.dart"
    - "test/library/library_empty_test.dart"
    - "test/library/persistence_test.dart"
    - "test/library/epub_parser_corpus_test.dart"
  modified: []

key-decisions:
  - "D-02-02-A: Heading is the one non-const Block variant. The plan's acceptance criteria simultaneously required const constructors AND ArgumentError on level out-of-range, which Dart cannot express together — a body is required to throw, and a const constructor cannot have a body. Chose behavior (runtime ArgumentError in all modes) over the const modifier. Paragraph, ImageBlock, Blockquote, and ListItem remain const. Documented in Deviations."
  - "D-02-02-B: JSON discriminator values (`paragraph`, `heading`, `image`, `blockquote`, `list_item`) are frozen persistence contract — renaming them is a Drift migration for `chapters.blocks_json`."
  - "D-02-02-C: All test files (including pure-Dart ones under test/core/epub/) use `package:flutter_test/flutter_test.dart` uniformly. The plan suggested `package:test` for pure-Dart files, but `test` is not a direct dev_dependency — only `flutter_test` is, and it re-exports `package:test`. This matches the existing project convention (test/spike/*, test/db/*, test/crash/*, test/theme/*, test/widget/*, test/fonts/* all use flutter_test)."

patterns-established:
  - "Exhaustive-switch pattern for Block codec: sealed parent + `switch (this) { Paragraph(...) => ..., Heading(...) => ..., }` with no default branch. Adding a new variant without updating the switch is a compile error."
  - "FormatException-at-decode-boundary for tampering resistance: blockFromJson rejects missing/unknown discriminators and any field with the wrong runtime type. Mitigates STRIDE T-02-02-01."
  - "Wave 0 stub convention: every stub is a single `group()` with one `test(...)`, skip-reason referencing the downstream plan number, file-level doc-comment referencing the requirement IDs and D-xx decisions."

requirements-completed: []  # LIB-03 is NOT completed by this plan. This plan delivers the TYPE CONTRACT that LIB-03 will check against; the actual 15-EPUB parser + corpus tests land in Plans 02-04 and 02-08. Marking LIB-03 done here would repeat the Plan 02-01 Deviation #4 error.

# Metrics
duration: ~20min
completed: 2026-04-11
---

# Phase 02 Plan 02-02: Block IR + Wave 0 Scaffold Summary

**Sealed `Block` hierarchy (Paragraph, Heading, ImageBlock, Blockquote, ListItem) with exhaustive-switch JSON codec, plus 13 Wave 0 test stubs that unblock the Nyquist rule for Plans 04-08.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-04-11 (immediately after Plan 02-01 completion)
- **Completed:** 2026-04-11
- **Tasks:** 2 of 2
- **Files created:** 16 (2 lib files + 14 test files, all new)
- **Files modified:** 0

## Accomplishments

- `lib/core/epub/block.dart` defines the sealed `Block` hierarchy with all five variants per D-01. Every variant has hand-rolled value equality, `hashCode`, and `toString`. Heading validates `level ∈ [1, 6]` at construction and throws `ArgumentError.value` on violation.
- `lib/core/epub/block_json.dart` implements the codec:
  - `BlockJson.toJson()` uses a Dart 3 exhaustive switch expression with no `default` branch — adding a sixth variant without updating the switch is a compile error, which is the whole point of locking D-01's closed set.
  - `blockFromJson()` rejects missing / unknown discriminators with `FormatException`, and validates every required field's runtime type — mitigates threat T-02-02-01 (Tampering of blocks_json at rest).
  - `blocksToJsonString` / `blocksFromJsonString` wrap `dart:convert` for the full round-trip through the `chapters.blocks_json` storage format.
- `test/core/epub/block_json_test.dart` has 18 tests covering: round-trips for all five variants, null-alt preservation, ordered/unordered list item, mixed-list round-trip, unknown discriminator rejection, missing type rejection, Heading level bounds (0, 7, 1..6), plus value-equality tests per variant.
- 13 Wave 0 stub files exist at the exact paths listed in 02-VALIDATION.md. Each has a file-level doc comment, a single `group()` with one or two `test(...)` entries skipped with the correct downstream plan number, and imports nothing that doesn't exist yet.
- `flutter test` — 53 pass, 14 skipped, 0 fail.
- `flutter analyze` — 2 pre-existing warnings (unchanged from Plan 02-01 end state), 0 new issues.

## Task Commits

Each task was committed atomically (single-repo, no worktrees, normal git hooks — none installed):

1. **Task 1 RED: failing Block IR round-trip tests (TDD RED)** — `6088c2b` (test)
2. **Task 1 GREEN: implement Block IR hierarchy and JSON codec (TDD GREEN)** — `3f2551e` (feat)
3. **Task 2: scaffold Wave 0 test stubs for Plans 04-08** — `9b41a57` (test)

**Plan metadata (final docs commit):** pending — created after this SUMMARY.md is written.

## Files Created/Modified

### Created (library)
- `lib/core/epub/block.dart` — Sealed `Block` hierarchy with five `final class` subclasses. Paragraph/ImageBlock/Blockquote/ListItem are const. Heading is non-const (so it can throw ArgumentError on level bounds — see deviation #1). Every subclass has operator ==, hashCode, and toString.
- `lib/core/epub/block_json.dart` — `BlockJson` extension with exhaustive `toJson()` switch, top-level `blockFromJson` / `blocksFromJsonString` / `blocksToJsonString`, and typed private helpers (`_requireString`, `_optionalString`, `_requireInt`, `_requireBool`, `_requireMap`) that throw `FormatException` with a payload pointer on any type mismatch.

### Created (tests — 14 new files)
- `test/core/epub/block_json_test.dart` — 18 behavior + equality tests for the Block codec (the only fleshed-out test file in this plan).
- `test/core/epub/epub_parser_test.dart` — Wave 0 stub → Plan 04 (LIB-03 DOM walker).
- `test/core/epub/epub_parser_isolate_test.dart` — Wave 0 stub → Plan 04 (LIB-01 isolate offload).
- `test/library/drm_detector_test.dart` — Wave 0 stub → Plan 04 (LIB-04 DRM rejection).
- `test/library/import_service_test.dart` — Wave 0 stub → Plan 05 (LIB-01 optimistic insert, LIB-04 corrupt-EPUB snackbar).
- `test/library/share_intent_test.dart` — Wave 0 stub → Plan 05 (LIB-02 Share/Open-in using receive_sharing_intent ^1.8.1, the substitution from 02-01 spike).
- `test/library/library_provider_test.dart` — Wave 0 stub → Plan 06 (LIB-07 sort chips).
- `test/library/book_card_test.dart` — Wave 0 stub → Plan 06 (LIB-06 BookCard widget D-07..D-10).
- `test/library/library_grid_test.dart` — Wave 0 stub → Plan 07 (LIB-05/10 responsive grid D-15/D-16).
- `test/library/library_search_test.dart` — Wave 0 stub → Plan 07 (LIB-08 debounced search).
- `test/library/book_context_sheet_test.dart` — Wave 0 stub → Plan 07 (LIB-09 long-press bottom sheet).
- `test/library/library_empty_test.dart` — Wave 0 stub → Plan 07 (LIB-10 empty state, D-18).
- `test/library/persistence_test.dart` — Wave 0 stub → Plan 08 (LIB-11 Drift re-hydration across restart).
- `test/library/epub_parser_corpus_test.dart` — Wave 0 stub → Plan 08 (LIB-03 15-EPUB corpus validation).

### Not created
- `test/generated_migrations/` — per plan Task 2 action, this directory is owned by Plan 02-03 via `drift_dev schema generate`, not hand-authored. Deliberately absent.

## Decisions Made

See `key-decisions` in the frontmatter. Two are worth expanding here:

**D-02-02-A: Heading is non-const.** The plan's acceptance criteria required both const constructors and `Heading.level` validation via `ArgumentError`. Dart doesn't allow a constructor body on a const constructor, so the options were (a) use `assert(...)` and throw `AssertionError` (debug-only, no release-mode check, wrong exception type), (b) drop the bounds check (breaks behavior spec), or (c) drop `const` on Heading (works in every mode). Chose (c). The only consequence is that test code constructing Headings uses `final h = Heading(...)` instead of `const Heading(...)` — a cosmetic change with no correctness impact. Documented as Rule 1 deviation below.

**D-02-02-C: Test framework uniformity.** The plan said "use package:test/test.dart only if the file is pure Dart with no Flutter imports". When the analyzer flagged `depend_on_referenced_packages` on the pure-Dart `block_json_test.dart`, inspection showed `package:test` is not a dev_dependency at all — only `flutter_test` is, and it re-exports `package:test`. Switched to flutter_test everywhere for consistency with the rest of the existing suite (test/spike, test/db, test/crash, test/theme, test/widget, test/fonts all use flutter_test). Matches the plan's fallback guidance: "When in doubt, use package:flutter_test/flutter_test.dart".

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Heading const constructor is incompatible with ArgumentError validation**
- **Found during:** Task 1 GREEN (implementing the real Heading class)
- **Issue:** The plan's acceptance criteria require "each subclass with value equality and const constructors" AND "Heading constructor rejects level < 1 or level > 6 with ArgumentError". These two requirements are mutually exclusive in Dart: `const` constructors cannot have a body, but `throw` requires a body. `assert()` is the only const-compatible check, and assertions (a) only fire in debug mode, (b) throw `AssertionError`, not `ArgumentError`. Option (a) and (b) both break the spec's behavior contract (rejects in all modes, throws ArgumentError).
- **Fix:** Dropped `const` from the Heading constructor only. Paragraph, ImageBlock, Blockquote, and ListItem remain const. Updated the three test sites that used `const Heading(...)` to `Heading(...)` (three-line diff).
- **Files modified:** lib/core/epub/block.dart, test/core/epub/block_json_test.dart
- **Verification:** All 18 tests pass, both the level-bound tests and the value-equality test for Heading. `flutter analyze` clean.
- **Committed in:** 3f2551e (Task 1 GREEN commit)

**2. [Rule 1 - Bug] package:test isn't a dev_dependency — swap to flutter_test**
- **Found during:** Task 1 GREEN (first `flutter analyze` after making tests pass)
- **Issue:** Plan Task 1 action said to use `package:test/test.dart` for pure-Dart files. Following that produced an analyzer `depend_on_referenced_packages` info diagnostic on the test file. Inspection showed `package:test` is not listed in `pubspec.yaml` dev_dependencies — only `flutter_test` is. `flutter_test` re-exports `package:test` so all `test(...)`/`group(...)`/`expect(...)` APIs still work.
- **Fix:** Changed the import in `block_json_test.dart` from `package:test/test.dart` to `package:flutter_test/flutter_test.dart`. Applied the same convention to all 13 Task 2 stubs (plan's own fallback guidance: "When in doubt, use package:flutter_test/flutter_test.dart").
- **Files modified:** test/core/epub/block_json_test.dart (all 13 Task 2 stubs were written with the correct import from the start)
- **Verification:** `flutter analyze` — 2 pre-existing warnings, 0 new issues. All tests still pass (18 Block codec tests + 53 overall).
- **Committed in:** 3f2551e (Task 1 GREEN commit, folded into the final form before commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — correctness bugs in the plan's acceptance criteria / tooling assumptions).
**Impact on plan:** Neither changes delivered surface. #1 is a one-word diff (`const` removal on Heading) that does not affect the Block IR contract — Heading is still value-equal, still round-trips, still validates bounds. #2 is an import-path fix that matches existing project convention. No scope creep, no missed requirements.

## Issues Encountered

- None. TDD RED → GREEN proceeded cleanly. The test framework decision was caught by `flutter analyze` on the first run and fixed before commit.

## User Setup Required

None — all changes are in-repo source code and tests. No external services, no env vars, no model downloads.

## Known Stubs

The 13 Wave 0 test files are stubs by design (that's their whole purpose — Nyquist scaffold). Each has:
- A single `test(...)` that is skipped with a message referencing the downstream plan that will fill it in
- No imports of types that do not yet exist
- A file-level doc comment linking it back to the requirement IDs and D-xx decisions

These are **tracked stubs, not lingering placeholder surface**. They do not reach user-facing code. The Nyquist rule in 02-VALIDATION.md exists precisely so that Plans 04-08 have existing files to fill, not blank directories to create.

## Next Phase Readiness

**Plan 02-03 (Drift schema v1→v2 migration) unblocked.** It can now:

1. Import `lib/core/epub/block.dart` and `lib/core/epub/block_json.dart` to use `blocksToJsonString` as the `TypeConverter<List<Block>, String>` for the `chapters.blocks_json` Drift column.
2. Add `Books` and `Chapters` table classes under `lib/core/db/tables/` with `blocks_json` as a TEXT column (per D-03, D-04, D-05).
3. Run `drift_dev schema dump` to commit `drift_schemas/drift_schema_v2.json`.
4. Run `drift_dev schema generate` to populate `test/generated_migrations/` (the one Wave 0 entry Plan 02-02 intentionally did not create).

**Plan 02-04 (EPUB parser)** can emit `List<Block>` directly without circular imports — `lib/core/epub/block.dart` has zero dependencies on Drift or Flutter, so any of `epub_parser.dart`, `dom_walker.dart`, etc. can live in `lib/core/epub/` alongside it.

**Plans 02-05 through 02-08** can all drop real assertions into their Wave 0 stubs (13 files) without creating them from scratch — each stub already imports `flutter_test` and has a `group()` ready to extend.

No blockers. Phase 2 is ready to proceed to Drift schema work.

## Self-Check

- `lib/core/epub/block.dart` — FOUND (137 lines, sealed class with 5 variants, Heading non-const per D-02-02-A)
- `lib/core/epub/block_json.dart` — FOUND (exhaustive switch toJson, FormatException-throwing blockFromJson, blocksToJsonString/blocksFromJsonString helpers)
- `test/core/epub/block_json_test.dart` — FOUND (18 tests, all pass under `flutter test`)
- `test/core/epub/epub_parser_test.dart` — FOUND (Plan 04 stub)
- `test/core/epub/epub_parser_isolate_test.dart` — FOUND (Plan 04 stub)
- `test/library/drm_detector_test.dart` — FOUND (Plan 04 stub)
- `test/library/import_service_test.dart` — FOUND (Plan 05 stub, 2 test entries)
- `test/library/share_intent_test.dart` — FOUND (Plan 05 stub)
- `test/library/library_provider_test.dart` — FOUND (Plan 06 stub)
- `test/library/book_card_test.dart` — FOUND (Plan 06 stub)
- `test/library/library_grid_test.dart` — FOUND (Plan 07 stub)
- `test/library/library_search_test.dart` — FOUND (Plan 07 stub)
- `test/library/book_context_sheet_test.dart` — FOUND (Plan 07 stub)
- `test/library/library_empty_test.dart` — FOUND (Plan 07 stub)
- `test/library/persistence_test.dart` — FOUND (Plan 08 stub)
- `test/library/epub_parser_corpus_test.dart` — FOUND (Plan 08 stub)
- Commit `6088c2b` (Task 1 RED) — FOUND in `git log`
- Commit `3f2551e` (Task 1 GREEN) — FOUND in `git log`
- Commit `9b41a57` (Task 2 stubs) — FOUND in `git log`
- `flutter test` — 53 pass, 14 skipped, 0 fail
- `flutter analyze` — 0 new issues (only 2 pre-existing warnings from Plan 02-01 end state)

## Self-Check: PASSED

---

*Phase: 02-library-epub-import*
*Plan: 02*
*Completed: 2026-04-11*
