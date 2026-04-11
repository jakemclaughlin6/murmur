# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-11)

**Core value:** Point murmur at an EPUB and have it read to you — in a natural neural voice, fully offline, without ever creating an account.
**Current focus:** Phase 1 — Scaffold & Compliance Foundation

## Current Position

Phase: 1 of 7 (Scaffold & Compliance Foundation)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-04-11 — Roadmap created; 72/72 v1 requirements mapped

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

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Flutter + Riverpod + go_router + Drift is the locked stack
- `epubx` + `package:html` (NOT `epub_view`) for EPUB parsing — Dart 3.11 compat must be verified as the first Phase 1 spike
- Per-paragraph `RichText` inside `ListView.builder` from Phase 3 (sentence-span architecture is non-negotiable)
- `just_audio.setSpeed()` owns runtime playback speed; Sherpa `length_scale` fixed at 1.0
- Compliance groundwork (Info.plist, manifest, CI, crash log) lands in Phase 1, not Phase 7

### Pending Todos

None yet.

### Blockers/Concerns

- `epubx` Dart 3.11 compatibility is unverified — go/no-go decision at Phase 1 exit; fallback path is roll-your-own parser with `package:archive` + `package:xml` + `package:html`
- Sherpa-ONNX Flutter bindings are actively developed but young; pin exact version and build a minimal "synthesize one sentence and hear it" harness as the first Phase 4 task
- Phase 4 concentrates 8 of 17 critical pitfalls — budget extra time; warrants `/gsd-research-phase` before planning

## Session Continuity

Last session: 2026-04-11
Stopped at: Roadmap created; PROJECT.md, REQUIREMENTS.md, and 5 research files synthesized into 7-phase plan with 72/72 v1 requirement coverage
Resume file: None
