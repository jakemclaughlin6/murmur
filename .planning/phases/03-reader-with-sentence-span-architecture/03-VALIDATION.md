---
phase: 3
slug: reader-with-sentence-span-architecture
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
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
| 03-01-01 | 01 | 1 | RDR-04 | — | N/A | unit | `flutter test test/core/text/sentence_splitter_test.dart` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | RDR-04 | — | N/A | unit | `flutter test test/core/text/sentence_test.dart` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 1 | RDR-03 | T-03-01 | Block IR decoded in try/catch | widget | `flutter test test/widget/reader/block_renderer_test.dart` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 1 | RDR-05 | — | N/A | widget | `flutter test test/widget/reader/paragraph_semantics_test.dart` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 2 | RDR-01, RDR-02 | — | N/A | widget | `flutter test test/widget/reader/reader_screen_test.dart` | ❌ W0 | ⬜ pending |
| 03-03-02 | 03 | 2 | RDR-10, RDR-12 | — | N/A | widget | Part of reader_screen_test.dart | ❌ W0 | ⬜ pending |
| 03-04-01 | 04 | 2 | RDR-11 | — | N/A | unit | `flutter test test/core/db/reading_progress_test.dart` | ❌ W0 | ⬜ pending |
| 03-05-01 | 05 | 3 | RDR-06, RDR-07 | — | N/A | widget | `flutter test test/widget/reader/font_settings_test.dart` | ❌ W0 | ⬜ pending |
| 03-06-01 | 06 | 3 | RDR-09 | — | N/A | widget | `flutter test test/widget/reader/responsive_layout_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/core/text/sentence_splitter_test.dart` — stubs for RDR-04 sentence splitting
- [ ] `test/core/text/sentence_test.dart` — stubs for RDR-04 Sentence model
- [ ] `test/widget/reader/block_renderer_test.dart` — stubs for RDR-03
- [ ] `test/widget/reader/paragraph_semantics_test.dart` — stubs for RDR-05
- [ ] `test/widget/reader/reader_screen_test.dart` — stubs for RDR-01, RDR-02, RDR-10, RDR-12
- [ ] `test/core/db/reading_progress_test.dart` — stubs for RDR-11
- [ ] `test/widget/reader/font_settings_test.dart` — stubs for RDR-06, RDR-07
- [ ] `test/widget/reader/responsive_layout_test.dart` — stubs for RDR-09

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Theme change applies to reader | RDR-08 | Existing theme tests cover data; visual appearance requires human eye | Switch all 4 themes, verify reader text + background matches ClayColors |
| 60fps scroll on mid-range phone | RDR-01 | Performance requires physical device profiling | Run profile build on physical device, check DevTools timeline |
| Immersive mode system UI hides/shows | RDR-12 | SystemChrome calls require real platform | Tap center 1/3 on physical device, verify status bar + nav bar toggle |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
