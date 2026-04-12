# Phase 3: Reader with Sentence-Span Architecture - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 03-reader-with-sentence-span-architecture
**Areas discussed:** Sentence splitting strategy, Pagination & scroll model, Chapter navigation UX, Reading progress model

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Sentence splitting strategy | How Block text becomes List<Sentence>, split timing, data model shape, handling of non-paragraph blocks | |
| Pagination & scroll model | PageView computation, font-size reflow, chapter loading strategy | |
| Chapter navigation UX | Sidebar vs drawer, immersive mode interaction, current-chapter highlight | |
| Reading progress model | Position definition, debounce behavior, flush-on-background, DB column wiring | |

**User's choice:** "Go with sensible defaults and what would be recommended from an ease of use perspective"
**Notes:** User deferred all four areas to Claude's recommended defaults in a single response. No individual area discussion was needed.

---

## All Areas (Bulk Default Selection)

All gray areas were resolved via Claude's recommended defaults per user instruction. No individual trade-off discussions occurred.

**Decisions made:**
- Sentence splitting at render time, basic splitter in Phase 3, hardened in Phase 4
- Horizontal PageView of chapters with vertical ListView per chapter
- Persistent sidebar on tablet, slide-over drawer on phone
- Chapter index + scroll fraction for reading progress, 2s debounce + flush on pause
- Font controls via bottom sheet from app bar icon
- Existing theme infrastructure reused (no separate reader theme)

## Claude's Discretion

- Tap-zone geometry for immersive mode
- SentenceSplitter abbreviation list
- Chapter sidebar width scaling on large tablets
- ScrollController debounce implementation
- Chapter drawer animation
- Font size slider label format
- ImageBlock rendering strategy

## Deferred Ideas

None raised during discussion.
