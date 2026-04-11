---
phase: 02-library-epub-import
plan: 01
subsystem: infra
tags: [drift, drift_dev, riverpod_generator, epubx, file_picker, html, receive_sharing_intent, build_runner, dart_style, win32, analyzer-override, spike]

# Dependency graph
requires:
  - phase: 01-scaffold-compliance-foundation
    provides: "Drift shell at schemaVersion=1, riverpod_generator + build_runner wiring, Phase 1 test suite"
provides:
  - "Phase 2 dependency set that actually resolves on pub.dev (epubx, file_picker, html, receive_sharing_intent, drift_dev)"
  - "Working drift_dev + riverpod_generator codegen chain via analyzer ^10 override"
  - "Regenerated lib/core/db/app_database.g.dart from drift_dev (replacing Phase 1 hand-crafted shim)"
  - "Empirically verified go-decision for epubx ^4.0.0 under Dart 3.11"
  - "Empirically verified go-decision for receive_sharing_intent ^1.8.1 (substitution for the non-existent _plus ^1.6.0)"
  - "Minimal deterministic EPUB fixture at test/fixtures/spike.epub for downstream parser tests"
affects: [02-02, 02-03, 02-04, 02-05, 02-06, 02-07, 02-08, phase-03-reader, phase-04-tts]

# Tech tracking
tech-stack:
  added:
    - "epubx ^4.0.0 (pure-Dart EPUB parser)"
    - "file_picker ^11.0.2 (SAF + UIDocumentPickerViewController wrapper)"
    - "html ^0.15.5 (Dart HTML5 DOM parser)"
    - "receive_sharing_intent ^1.8.1 (maintained — substituted for the non-existent receive_sharing_intent_plus ^1.6.0)"
    - "drift_dev ^2.32.1 (dev_dependencies — drift schema & migration codegen)"
  patterns:
    - "dependency_overrides as an escape valve for analyzer-ecosystem transitive conflicts (analyzer ^10, dart_style ≥3.1.4<3.1.8, win32 ^6)"
    - "Deterministic synthetic EPUB fixtures via python zipfile (mimetype stored first, EPUB 3.0 structure) — no Project Gutenberg network fetch"

key-files:
  created:
    - "test/fixtures/spike.epub"
    - "test/spike/epubx_spike_test.dart"
    - ".planning/phases/02-library-epub-import/spike-notes.md"
  modified:
    - "pubspec.yaml"
    - "pubspec.lock"
    - "lib/core/db/app_database.g.dart"

key-decisions:
  - "Substituted receive_sharing_intent ^1.8.1 for the non-existent receive_sharing_intent_plus ^1.6.0 — pub.dev marks _plus discontinued and points at the original"
  - "Pin dart_style >=3.1.4 <3.1.8 in dependency_overrides — 3.1.3 uses analyzer 8/9 API, 3.1.8 moves to analyzer ^12"
  - "Pin win32 ^6.0.0 in dependency_overrides — resolves file_picker vs package_info_plus conflict; safe because murmur targets Android+iOS only"
  - "epubx spike PASS: proceed with epubx ^4.0.0 for Plan 04 parser work, no fallback needed"
  - "receive_sharing_intent spike PASS (with substitution): LIB-02 Share / Open-in pipeline stays on the maintained package"

patterns-established:
  - "Phase 2 dependency baseline: keep epubx + html (reject epub_view, flutter_html, flutter_widget_from_html per CLAUDE.md)"
  - "Synthetic fixture pattern for EPUB tests: python zipfile + minimal EPUB 3 metadata, committed under test/fixtures/"
  - "Spike tests under test/spike/ for package-level go/no-go checks separate from behavioral tests"

requirements-completed: []  # Plan 02-01 is toolchain-unblock only. LIB-01/02/03 land in Plans 02-04..08. See Deviation #4 below.

# Metrics
duration: ~25min
completed: 2026-04-11
---

# Phase 02 Plan 02-01: Phase 2 Unblock — analyzer override + package spikes Summary

**Resolved the analyzer v9/v10 conflict with four coordinated dependency_overrides, regenerated drift's `app_database.g.dart` from the real generator, and recorded PASS verdicts for both epubx and receive_sharing_intent spikes — unblocking all remaining Plan 02-02 through 02-08 work.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-11T20:27:23Z
- **Completed:** 2026-04-11T20:52:00Z (approx)
- **Tasks:** 3 of 3
- **Files modified:** 3 (pubspec.yaml, pubspec.lock, lib/core/db/app_database.g.dart)
- **Files created:** 3 (spike fixture, spike test, spike-notes.md)

## Accomplishments

- `flutter pub get` resolves cleanly with **four** coordinated dependency_overrides (analyzer ^10, dart_style >=3.1.4<3.1.8, win32 ^6, plus the ^10 cascade). 19 dependencies added.
- `dart run build_runner build --delete-conflicting-outputs` exits 0 and regenerates 56 outputs — both `drift_dev` and `riverpod_generator` now run side-by-side on the same analyzer version without patching either upstream.
- `lib/core/db/app_database.g.dart` is now real generator output (`// GENERATED CODE - DO NOT MODIFY BY HAND`), replacing the Phase 1 hand-crafted 20-line shim.
- `flutter analyze` → 0 errors (2 pre-existing warnings, same as end-of-Phase-1). `flutter test` → all 36 tests pass (34 Phase 1 + 2 new spike tests).
- `epubx ^4.0.0` spike PASS: parses the minimal EPUB fixture, extracts `title="Spike Fixture Title"`, `author="Spike Fixture Author"`, `chapters=1`, `hasCover=false`. No analyzer errors, no runtime exceptions, no wrappers needed. Plan 04 proceeds with epubx as planned (research assumption A4 validated).
- `receive_sharing_intent ^1.8.1` spike PASS (with substitution — see Deviations): imports cleanly under `flutter_test`, compiles with no analyzer errors. LIB-02 Share / Open-in pipeline is unblocked.

## Task Commits

Each task was committed atomically (single-repo, normal git hooks):

1. **Task 1: Install Phase 2 dependencies and analyzer override** — `75029b2` (chore)
2. **Task 2: Codegen smoke test + delete hand-crafted app_database.g.dart** — `bd9b6e4` (chore)
3. **Task 3: Spike epubx + receive_sharing_intent (go/no-go)** — `08f7e65` (test)

**Plan metadata (final docs commit):** pending — created after this SUMMARY.md is written.

## Files Created/Modified

### Created
- `test/fixtures/spike.epub` — 1,570-byte minimal valid EPUB 3.0 fixture (mimetype stored first, META-INF/container.xml, OEBPS/content.opf with Dublin Core metadata, OEBPS/nav.xhtml toc, OEBPS/chapter1.xhtml with one H1 and two paragraphs). Synthesized via python `zipfile` — no network download.
- `test/spike/epubx_spike_test.dart` — Two tests: (1) epubx parses spike.epub and asserts title/author/chapters, (2) receive_sharing_intent imports cleanly.
- `.planning/phases/02-library-epub-import/spike-notes.md` — Full go/no-go verdicts with observed values, deviation rationale, and retained fallback inventory (for reference even though no fallback was triggered).

### Modified
- `pubspec.yaml` — Added 4 runtime deps + drift_dev + 3-entry dependency_overrides block (analyzer, dart_style, win32). Removed the stale "drift_dev intentionally omitted from Phase 1" comment block.
- `pubspec.lock` — 19 dependencies added (cli_util, csslib, drift_dev, epubx, file_picker, flutter_plugin_android_lifecycle, html, image, petitparser, quiver, recase, receive_sharing_intent, sqlparser, xml, plus transitives).
- `lib/core/db/app_database.g.dart` — Replaced 20-line hand-crafted shim with real `drift_dev` output (same `// GENERATED CODE - DO NOT MODIFY BY HAND` header, functionally equivalent for the zero-table v1 schema, but now under the build_runner pipeline so Plan 02-02 can add tables and regenerate).

## Decisions Made

- **D-02-01-A: Four overrides, not two.** Plan 02-01 anticipated one override (analyzer ^10). Reality required four coordinated overrides to reach a passing build: analyzer ^10, dart_style ≥3.1.4<3.1.8, win32 ^6, plus the package substitution for receive_sharing_intent. Each is individually justified (see Deviations), and together they form a single self-consistent dependency graph.
- **D-02-01-B: receive_sharing_intent (original), not _plus.** 02-RESEARCH.md assumption A2 was inverted relative to today's pub.dev reality. The maintained package is the original `receive_sharing_intent` ^1.8.1; the `_plus` fork is discontinued. LIB-02 implementation uses `package:receive_sharing_intent/receive_sharing_intent.dart`.
- **D-02-01-C: Synthetic EPUB fixture over Project Gutenberg download.** The plan's action block suggested committing "a tiny real EPUB (~50 KB) from Project Gutenberg". Instead we synthesized a 1,570-byte deterministic fixture via python zipfile. Benefits: known-answer assertions (no "what's the title of this PG book?" lookup), zero network dependency, no copyright license questions, and the fixture is visually editable by humans. The 15-EPUB validation corpus scheduled for a later Plan will cover real-world variance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Package substitution: receive_sharing_intent_plus → receive_sharing_intent**
- **Found during:** Task 1 (flutter pub get failed with "no versions match")
- **Issue:** Plan and 02-RESEARCH.md specified `receive_sharing_intent_plus: ^1.6.0`. Pub.dev returned: `_plus` latest is **1.0.1**, package is **discontinued**, `replacedBy: receive_sharing_intent`. The `^1.6.0` constraint is unsatisfiable — version 1.6.x never existed. Research assumption A2 (that `_plus` is the maintained fork) had flipped.
- **Fix:** Replaced `receive_sharing_intent_plus: ^1.6.0` with `receive_sharing_intent: ^1.8.1` in pubspec.yaml `dependencies:`. Updated the spike test's import path to `package:receive_sharing_intent/receive_sharing_intent.dart`. Same API surface, same purpose, no code elsewhere touched (nothing else imports it yet).
- **Files modified:** pubspec.yaml, test/spike/epubx_spike_test.dart
- **Verification:** pub get resolves, spike test compiles and runs, import test passes
- **Committed in:** 75029b2 (Task 1) + 08f7e65 (Task 3)

**2. [Rule 3 - Blocking] dart_style override to unblock analyzer ^10 cascade**
- **Found during:** Task 2 (first `dart run build_runner build` attempt)
- **Issue:** `dart_style 3.1.3` (pulled in transitively by build_runner's formatter) references `ParserErrorCode`, which is gone from `analyzer 10.x`. Codegen failed with `Error: The getter 'ParserErrorCode' isn't defined for the type 'DartFormatter'.` The analyzer override from Task 1 surfaced a previously-hidden transitive incompatibility.
- **Fix:** Added `dart_style: ">=3.1.4 <3.1.8"` to `dependency_overrides` in pubspec.yaml. 3.1.4 is the first version to adopt analyzer ^10; 3.1.8 moves to analyzer ^12 (re-breaking the chain). Range resolves to `dart_style 3.1.7`.
- **Files modified:** pubspec.yaml, pubspec.lock
- **Verification:** `dart run build_runner build --delete-conflicting-outputs` now exits 0, 56 outputs generated, flutter analyze clean, flutter test green.
- **Committed in:** bd9b6e4 (Task 2)

**3. [Rule 3 - Blocking] win32 override to unblock file_picker vs package_info_plus**
- **Found during:** Task 1 (second `flutter pub get` attempt, after package substitution)
- **Issue:** `file_picker 11.0.2` (every version in range) pins `win32 ^5.9.0`, but Phase 1's `package_info_plus 10.0.0` requires `win32 ^6.0.0`. These cannot coexist without an override.
- **Fix:** Added `win32: ^6.0.0` to `dependency_overrides`. Safe because murmur targets Android + iOS only (PROJECT.md Constraints: "No desktop") — the Windows FFI code path is dead code on our target platforms. Documented rationale inline in pubspec.yaml.
- **Files modified:** pubspec.yaml, pubspec.lock
- **Verification:** pub get resolves with `! win32 6.0.0 (overridden)`, spike test still passes (spike test never touches win32).
- **Committed in:** 75029b2 (Task 1)

**4. [Rule 1 - Bug] Plan frontmatter mislabelled requirements as completed**
- **Found during:** Final state update (`requirements mark-complete LIB-01 LIB-02 LIB-03`)
- **Issue:** The plan frontmatter at `.planning/phases/02-library-epub-import/02-01-PLAN.md` line 13-16 lists `requirements: [LIB-01, LIB-02, LIB-03]`. The GSD executor protocol reads that list and runs `requirements mark-complete` unconditionally — which marked all three as `[x] Complete` in REQUIREMENTS.md. But Plan 02-01's actual scope is toolchain-unblock only: (1) install Phase 2 deps, (2) run codegen, (3) package spikes. No file picker UI, no share-intent wiring, no EPUB parser is delivered here. Those features live in Plans 02-04, 02-05, 02-06, and 02-08.
- **Fix:** Reverted REQUIREMENTS.md: LIB-01, LIB-02, LIB-03 back to `[ ]` / `Pending` in both the Library checklist block and the traceability table. Also set `requirements-completed: []` in this SUMMARY.md frontmatter so downstream verifiers don't re-inherit the false mark. Leaving the plan's frontmatter `requirements:` field as-is (editing a committed plan mid-execution is out of scope) but flagging it here.
- **Files modified:** .planning/REQUIREMENTS.md, .planning/phases/02-library-epub-import/02-01-SUMMARY.md
- **Verification:** `grep "LIB-0[123]" REQUIREMENTS.md` shows `[ ]` and `Pending` for all three.
- **Committed in:** (will be part of the final docs commit)

---

**Total deviations:** 4 auto-fixed (3 Rule-3 blocking, 1 Rule-1 correctness)
**Impact on plan:** The three Rule-3 dep overrides were required to make the plan executable — Task 2 and Task 3 simply couldn't run without them. The Rule-1 requirements revert prevents a false-positive requirements-complete claim from propagating to Plans 02-02+ and to the verifier. No scope creep; no change to Plan 02-01's actual delivered surface. The net effect is that Phase 2's dependency graph is now robust against the transitive fallout of bumping analyzer, and a future update to any of the four pinned packages is a targeted single-line change with a clear rationale in the pubspec.yaml comment block.

## Issues Encountered

- **Drift "multiple databases" debug warning during `flutter test`.** Pre-existing from Phase 1 (each test creates its own `AppDatabase` over an in-memory executor, which drift flags as a possible race condition only in debug mode). Not a test failure, does not affect CI green, flagged for cleanup in a future Plan if it becomes noisy. Not introduced by this plan.

## User Setup Required

None — all changes are in-repo. `mise exec -- flutter pub get` is automatic on next clone.

## Known Stubs

None. This plan is infrastructure-only (dependency resolution + codegen + spikes). No UI, no data flow, no empty placeholders reach a user surface.

## Next Phase Readiness

**Plan 02-02 onward unblocked.** Specifically:

- `drift_dev` is installed and functional — Plan 02-02 can define `Books` and `Chapters` table classes under `lib/core/db/tables/`, bump `schemaVersion` to 2, run `drift_dev schema dump` to commit `drift_schemas/drift_schema_v2.json`, and generate step-by-step migrations.
- `file_picker`, `epubx`, `html`, `receive_sharing_intent` are importable and compile-clean — Plans 02-04 (parser), 02-05 (import service), 02-06 (library grid), 02-07 (search/sort), and 02-08 (LIB-02 Share / Open-in) can consume them without further spike work.
- `riverpod_generator` codegen still works after the analyzer override — Plan 02-05 (import service with `@riverpod(keepAlive: true)` AsyncNotifier) proceeds on the existing annotation-based pattern.
- Both unverified assumption-heavy packages (A2 `_plus` maintained claim, A4 epubx Dart 3.11 compat) have recorded go/no-go verdicts backed by empirical test runs in `test/spike/epubx_spike_test.dart`.

**No blockers.** Phase 2 is ready to proceed to table schema work.

## Self-Check: PASSED

- `pubspec.yaml` modified — FOUND
- `pubspec.lock` modified — FOUND
- `lib/core/db/app_database.g.dart` regenerated — FOUND (564 bytes, starts with `// GENERATED CODE - DO NOT MODIFY BY HAND`, no `HAND-CRAFTED` marker)
- `test/fixtures/spike.epub` — FOUND (1,570 bytes)
- `test/spike/epubx_spike_test.dart` — FOUND
- `.planning/phases/02-library-epub-import/spike-notes.md` — FOUND, no "TBD" strings
- Commit `75029b2` (Task 1) — FOUND
- Commit `bd9b6e4` (Task 2) — FOUND
- Commit `08f7e65` (Task 3) — FOUND

---

*Phase: 02-library-epub-import*
*Plan: 01*
*Completed: 2026-04-11*
