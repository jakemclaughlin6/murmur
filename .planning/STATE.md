---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: "Completed 02-05-PLAN.md (ImportNotifier + ShareIntentListener + /reader/:bookId stub)"
last_updated: "2026-04-11T21:34:18.886Z"
last_activity: 2026-04-11
progress:
  total_phases: 7
  completed_phases: 1
  total_plans: 17
  completed_plans: 14
  percent: 82
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-11)

**Core value:** Point murmur at an EPUB and have it read to you — in a natural neural voice, fully offline, without ever creating an account.
**Current focus:** Phase 02 — library-epub-import

## Current Position

Phase: 02 (library-epub-import) — EXECUTING
Plan: 6 of 8
Status: Ready to execute
Last activity: 2026-04-11

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| — | — | — | — |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01-scaffold-compliance-foundation P01 | ~4 hours | 4 tasks | 72 files |
| Phase 02-library-epub-import P01 | 25m | 3 tasks | 6 files |
| Phase 02-library-epub-import P02 | 20m | 2 tasks | 16 files |
| Phase 02-library-epub-import P03 | 25m | 2 tasks | 11 files |
| Phase 02 P02-04 | ~35m | 3 tasks | 13 files |
| Phase 02-library-epub-import P05 | 12m | 3 tasks | 14 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Flutter + Riverpod + go_router + Drift is the locked stack
- `epubx` + `package:html` (NOT `epub_view`) for EPUB parsing — Dart 3.11 compat must be verified as the first Phase 1 spike
- Per-paragraph `RichText` inside `ListView.builder` from Phase 3 (sentence-span architecture is non-negotiable)
- `just_audio.setSpeed()` owns runtime playback speed; Sherpa `length_scale` fixed at 1.0
- Compliance groundwork (Info.plist, manifest, CI, crash log) lands in Phase 1, not Phase 7
- [Phase 01-scaffold-compliance-foundation]: flutter create --org dev.jmclaughlin sets bundle IDs automatically — 6 occurrences in iOS pbxproj, no hand-edits needed
- [Phase 01-scaffold-compliance-foundation]: MISE_DATA_DIR not available as template var in .mise.toml env block — use {{ env.HOME }}/.local/share/mise instead
- [Phase 01-scaffold-compliance-foundation]: FND-06 amended (D-21): 2 serif families (Literata + Merriweather) not 3-4; FND-09 amended (D-06): Android AAB on push + iOS workflow_dispatch xcarchive
- [Phase 02-library-epub-import]: Four coordinated dependency_overrides unblock Phase 2: analyzer ^10, dart_style >=3.1.4<3.1.8, win32 ^6 (mobile-only), plus substitution of receive_sharing_intent_plus (discontinued) → receive_sharing_intent ^1.8.1
- [Phase 02-library-epub-import]: epubx ^4.0.0 spike PASS under Dart 3.11 (minimal EPUB fixture, clean parse); receive_sharing_intent ^1.8.1 spike PASS (imports clean); both research assumptions A2 and A4 resolved, Plan 04 parser and LIB-02 share-intent both proceed as planned
- [Phase 02-library-epub-import]: Block IR sealed class with 5 variants (Paragraph/Heading/ImageBlock/Blockquote/ListItem); exhaustive-switch JSON codec with FormatException tampering gate; Heading is the one non-const variant because const + ArgumentError are mutually exclusive in Dart
- [Phase 02-library-epub-import]: Drift v2 schema landed (books + chapters per D-03/D-05); stepByStep migration wired; PRAGMA foreign_keys=ON in beforeOpen is mandatory for ON DELETE CASCADE to fire
- [Phase 02]: EPUB parser returns Future<ParseResult> because epubx readBook is async; Isolate.run accepts FutureOr<R> so the isolate wrapper composes cleanly
- [Phase 02]: lib/core/epub/ is pure Dart with zero package:flutter/* imports so the parser runs under Isolate.run without a TestWidgetsFlutterBinding and is directly unit-testable
- [Phase 02]: Cover art re-encoded to JPEG via package:image (quality 85) because epubx returns a decoded Image not raw bytes; D-06 writes covers as ${bookId}.jpg anyway so JPEG is the right target
- [Phase 02-library-epub-import]: Plan 02-05 D-02-05-A: split file_picker entry into import_picker.dart because file_picker 11.0.2's Windows impl uses win32 5.x symbols incompatible with our win32 ^6.0.0 override; keeps tests compilable against real fixture EPUBs
- [Phase 02-library-epub-import]: Plan 02-05 D-02-05-B: ShareIntentSource abstract seam (not setMockValues) — Riverpod-overridable test boundary is cleaner than mutating a plugin singleton
- [Phase 02-library-epub-import]: Plan 02-05 D-02-05-D: appDocumentsDir is a Riverpod Future provider wrapping path_provider so tests override via ProviderContainer(overrides:) without TestDefaultBinaryMessengerBinding

### Pending Todos

None yet.

### Blockers/Concerns

- `epubx` Dart 3.11 compatibility is unverified — go/no-go decision at Phase 1 exit; fallback path is roll-your-own parser with `package:archive` + `package:xml` + `package:html`
- Sherpa-ONNX Flutter bindings are actively developed but young; pin exact version and build a minimal "synthesize one sentence and hear it" harness as the first Phase 4 task
- Phase 4 concentrates 8 of 17 critical pitfalls — budget extra time; warrants `/gsd-research-phase` before planning

## Session Continuity

Last session: 2026-04-11T21:34:08.348Z
Stopped at: Completed 02-05-PLAN.md (ImportNotifier + ShareIntentListener + /reader/:bookId stub)
Resume file: None
