---
phase: 3
slug: reader-with-sentence-span-architecture
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-12
audited: 2026-04-12
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (bundled with Flutter SDK) |
| **Config file** | None needed (uses default `flutter_test` runner) |
| **Quick run command** | `flutter test test/core/text/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/core/text/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | RDR-04 | — | N/A | unit | `flutter test test/core/text/sentence_splitter_test.dart` | ✅ | ✅ green |
| 03-01-02 | 01 | 1 | RDR-04 | — | N/A | unit | `flutter test test/core/text/sentence_test.dart` | ✅ | ✅ green |
| 03-02-01 | 02 | 1 | RDR-03 | T-03-01 | Block IR decoded in try/catch | widget | `flutter test test/widget/reader/block_renderer_test.dart` | ✅ | ✅ green |
| 03-02-02 | 02 | 1 | RDR-05 | — | N/A | widget | `flutter test test/widget/reader/paragraph_semantics_test.dart` | ✅ | ✅ green |
| 03-03-01 | 03 | 2 | RDR-01, RDR-02 | — | N/A | widget | `flutter test test/widget/reader/reader_screen_test.dart` | ✅ | ✅ green |
| 03-03-02 | 03 | 2 | RDR-10, RDR-12 | — | N/A | widget | Part of reader_screen_test.dart | ✅ | ✅ green |
| 03-04-01 | 04 | 2 | RDR-11 | — | N/A | unit | `flutter test test/core/db/reading_progress_test.dart` | ✅ | ✅ green |
| 03-05-01 | 05 | 3 | RDR-06, RDR-07 | — | N/A | widget | `flutter test test/widget/reader/font_settings_test.dart` | ✅ | ✅ green |
| 03-06-01 | 06 | 3 | RDR-09 | — | N/A | widget | `flutter test test/widget/reader/responsive_layout_test.dart` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/core/text/sentence_splitter_test.dart` — RDR-04 sentence splitting
- [x] `test/core/text/sentence_test.dart` — RDR-04 Sentence model
- [x] `test/widget/reader/block_renderer_test.dart` — RDR-03
- [x] `test/widget/reader/paragraph_semantics_test.dart` — RDR-05
- [x] `test/widget/reader/reader_screen_test.dart` — RDR-01, RDR-02, RDR-10, RDR-12
- [x] `test/core/db/reading_progress_test.dart` — RDR-11
- [x] `test/widget/reader/font_settings_test.dart` — RDR-06, RDR-07
- [x] `test/widget/reader/responsive_layout_test.dart` — RDR-09

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Theme change applies to reader | RDR-08 | Existing theme tests cover data; visual appearance requires human eye | Switch all 4 themes, verify reader text + background matches ClayColors |
| 60fps scroll on mid-range phone | RDR-01 | Performance requires physical device profiling | Run profile build on physical device, check DevTools timeline |
| Immersive mode system UI hides/shows | RDR-12 | SystemChrome calls require real platform | Tap center 1/3 on physical device, verify status bar + nav bar toggle |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-04-12

---

## Validation Audit 2026-04-12

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

All 9 per-task test files exist and pass (`flutter test test/core/text/ test/widget/reader/ test/core/db/reading_progress_test.dart` → 66 tests green, ~3s). Phase 3 is Nyquist-compliant.
