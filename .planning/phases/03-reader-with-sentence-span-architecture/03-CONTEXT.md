# Phase 3: Reader with Sentence-Span Architecture - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can open any imported EPUB on phone or tablet and read it start-to-finish with good typography, chapter navigation, and resume-on-reopen. Every paragraph is rendered as a `RichText` of one `TextSpan` per `Sentence` — the permanent reader architecture, not a Phase 5 retrofit. This phase covers: chapter loading from Block IR, sentence splitting, the `RichText` rendering pipeline, paginated chapter PageView, chapter navigation (sidebar/drawer), font/theme controls, reading progress persistence, and immersive mode.

**Requirements:** RDR-01, RDR-02, RDR-03, RDR-04, RDR-05, RDR-06, RDR-07, RDR-08, RDR-09, RDR-10, RDR-11, RDR-12

**Explicitly out of scope for Phase 3** (belongs in later phases):
- TTS synthesis, playback bar, voice selection, audio playback (Phase 4)
- Sentence highlighting, auto-scroll during TTS, two-way sync (Phase 5)
- Bookmarks (RDR-13, RDR-14), sleep timer, onboarding, accessibility pass (Phase 6)
- Store upload (Phase 7)

</domain>

<decisions>
## Implementation Decisions

### Sentence Splitting
- **D-01:** Sentence splitting happens **at render time**, not at import time. The Block IR (`blocks_json`) remains unchanged from Phase 2. When a chapter's blocks are loaded for display, each text block is run through a `SentenceSplitter` to produce `List<Sentence>` per block.
- **D-02:** Phase 3 builds a **basic `SentenceSplitter`** that splits on `.`, `!`, `?` with handling for common abbreviations (Mr., Mrs., Dr., St., U.S., etc.), decimal numbers, and ellipses. Phase 4 (TTS-06) hardens the same class with 500+ regression fixtures. The splitter lives in `lib/core/text/sentence_splitter.dart` — shared by both reader and TTS.
- **D-03:** The **`Sentence` data model** is a minimal record: `class Sentence { final String text; }`. It lives in `lib/core/text/sentence.dart`. Phase 5 may add fields for highlight state; the class is designed to be extended, not frozen.
- **D-04:** **Headings** are rendered as a single `TextSpan` (no sentence splitting) — headings are short by nature. **Blockquotes and list items** are sentence-split like paragraphs since they can contain multi-sentence text. **ImageBlocks** are rendered as `Image.file()` widgets, not `TextSpan` — they sit between paragraph RichText widgets in the ListView.

### Pagination & Scroll Model
- **D-05:** The reader uses a **horizontal `PageView` of chapters**. Each "page" in the PageView is one full chapter rendered as a vertical `ListView.builder` of paragraph `RichText` widgets inside a `RepaintBoundary`. This satisfies RDR-02 ("one chapter per page run, not a monolithic scroll") without the complexity of true page-by-page text pagination.
- **D-06:** Chapters are loaded **lazily** — only the current chapter's `blocks_json` is deserialized into `List<Block>` and then sentence-split. The PageView's `onPageChanged` triggers loading the next chapter. Adjacent chapters (prev/next) are pre-loaded in memory for smooth swiping.
- **D-07:** Font size changes **reflow immediately** within the current chapter — since each chapter is a scrollable ListView, there's no page recomputation. The font size slider (RDR-06, 12–28pt) updates a Riverpod provider that the `RichText` widgets watch.

### Chapter Navigation UX
- **D-08:** On **tablets** (shortest side >= 600dp), the reader shows a **persistent chapter sidebar (~300px)** on the left side. The sidebar lists all chapters with the current chapter highlighted using a subtle accent background tone. The sidebar is always visible — it's structural navigation, not toggleable.
- **D-09:** On **phones** (shortest side < 600dp), the reader shows a **slide-over chapter drawer** accessible from an icon in the app bar. The drawer overlays the reader content and uses the same chapter list styling as the tablet sidebar. Swipe-to-dismiss or tap-outside closes the drawer.
- **D-10:** **Immersive mode (RDR-12):** Tapping the center ~1/3 of the reader area toggles the app bar visibility. On tablet, the chapter sidebar **remains visible** during immersive mode (it's structural, not chrome). On phone, the drawer is only accessible when the app bar is visible. Future playback bar (Phase 4) will also toggle with immersive mode.

### Reading Progress Model
- **D-11:** Reading position is defined as **chapter index (int) + scroll offset fraction (0.0–1.0)** of the chapter `ListView`'s scroll extent. This maps directly to the reserved columns: `readingProgressChapter` (int) and `readingProgressOffset` (real) in the `books` table.
- **D-12:** Progress is **saved on scroll-stop after a 2-second debounce** (RDR-11). A `ScrollController` listener with a `Timer` handles the debounce. Progress is also **flushed immediately on `AppLifecycleState.paused`** (app backgrounded or killed) via a `WidgetsBindingObserver`.
- **D-13:** On book open, the reader **resumes at the saved position**: jumps to the saved chapter index in the PageView, then scrolls the chapter ListView to the saved offset fraction. First open (null progress) starts at chapter 0, offset 0.0. The `lastReadDate` column is updated on every book open.

### Font & Theme Controls
- **D-14:** Font size slider (RDR-06) is a **continuous slider from 12pt to 28pt** (not discrete steps), persisted to `shared_preferences`. The current font size is a Riverpod provider; changes apply immediately to all visible `RichText` widgets.
- **D-15:** Font family picker (RDR-07) offers **Literata and Merriweather** per Phase 1 D-21 (2 families, not 3–4). Rendered as a simple two-option selector in a settings bottom sheet or popover, with a live preview of the selected font. Persisted to `shared_preferences`.
- **D-16:** Theme switching (RDR-08) uses the **existing Phase 1 theme infrastructure** (`ThemeModeProvider`, `ClayColors`). The reader inherits the app-wide theme. No separate reader-only theme toggle — the Settings theme picker (already built in Phase 1) is the single source of truth.

### Reader Chrome & Typography Settings Access
- **D-17:** Typography controls (font size slider + font family picker) are accessed via a **bottom sheet triggered from an icon in the app bar** (e.g., `Aa` icon). This keeps the reader surface clean and puts settings one tap away. The bottom sheet is themed per ClayColors.

### Claude's Discretion
- Exact tap-zone geometry for immersive mode toggle (center ~1/3 is the guideline; exact pixel rect is implementation detail)
- `SentenceSplitter` abbreviation list completeness — start with common English abbreviations, expand as needed
- Chapter sidebar width on large tablets (300px is the floor; may widen proportionally)
- ScrollController debounce implementation (Timer-based vs stream-based)
- Exact animation for chapter drawer open/close (standard Material drawer or custom)
- Whether the font size slider shows a numeric label or just a visual preview
- ImageBlock rendering strategy (EPUB-internal images: extract from the EPUB archive and cache to temp, or read from the original EPUB on demand)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level specs
- `.planning/PROJECT.md` -- Vision, constraints, sentence-span commitment, "no Mac" constraint, tech stack
- `.planning/REQUIREMENTS.md` §Reader (RDR-01 through RDR-12) -- All twelve RDR- items for Phase 3
- `.planning/ROADMAP.md` §"Phase 3: Reader with Sentence-Span Architecture" -- Goal, depends-on, success criteria
- `.planning/STATE.md` -- Current session state
- `CLAUDE.md` -- Full tech stack, what-NOT-to-use list (flutter_html, flutter_widget_from_html, epub_view, webview), reader architecture commitment

### Phase 1 context (decisions that carry forward)
- `.planning/phases/01-scaffold-compliance-foundation/01-CONTEXT.md` -- D-18/D-19/D-20 (ClayColors palette, quiet-library), D-21/D-22 (Literata + Merriweather only, OFL, bundled .ttf), D-23 (system font for chrome)

### Phase 2 context (decisions that carry forward)
- `.planning/phases/02-library-epub-import/02-CONTEXT.md` -- D-01 (Block IR at import), D-03 (blocks_json TEXT column), D-05 (books table with reserved reading progress columns), D-06 (cover path)

### Phase 2 code (integration points the reader builds on)
- `lib/core/epub/block.dart` -- Sealed Block hierarchy (Paragraph, Heading, ImageBlock, Blockquote, ListItem)
- `lib/core/epub/block_json.dart` -- Block IR JSON codec
- `lib/core/db/tables/books_table.dart` -- Books table with readingProgressChapter/readingProgressOffset
- `lib/core/db/tables/chapters_table.dart` -- Chapters table with blocksJson column
- `lib/core/db/app_database.dart` -- Drift database with books/chapters queries
- `lib/features/reader/reader_screen.dart` -- Current Phase 2 stub (will be replaced)
- `lib/app/router.dart` -- `/reader/:bookId` route (full-screen, hides bottom nav)
- `lib/core/theme/clay_colors.dart` -- LOCKED theme palette
- `lib/core/theme/theme_mode_provider.dart` -- Existing theme state management
- `lib/core/theme/app_theme.dart` -- Theme data definitions

### Research (still relevant)
- `.planning/research/PITFALLS.md` -- Sentence splitting non-triviality, EPUB messiness
- `.planning/research/STACK.md` -- just_audio StreamAudioSource notes (relevant for Phase 4 integration awareness)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Block` sealed class** (`lib/core/epub/block.dart`) -- 5 variants (Paragraph, Heading, ImageBlock, Blockquote, ListItem) with exhaustive switching. The reader builds directly on this IR.
- **`blocksFromJsonString()` / `blocksToJsonString()`** (`lib/core/epub/block_json.dart`) -- JSON codec for loading chapter blocks from Drift.
- **`ClayColors`** (`lib/core/theme/clay_colors.dart`) -- All four theme palettes locked. Reader uses these exclusively.
- **`ThemeModeProvider`** (`lib/core/theme/theme_mode_provider.dart`) -- Existing theme state; reader inherits app-wide theme.
- **`AppDatabase`** (`lib/core/db/app_database.dart`) -- Drift DB with books + chapters tables and queries. Phase 3 adds reading-progress update queries.
- **`/reader/:bookId` route** (`lib/app/router.dart`) -- Full-screen route hiding bottom nav. Phase 3 replaces the `ReaderScreen` stub.

### Established Patterns
- **`@riverpod` code-gen** -- All providers use `riverpod_generator`. Phase 3 providers follow this pattern.
- **Sealed class exhaustive switching** -- Block IR uses Dart 3 sealed classes. Reader renderer switches exhaustively on block type.
- **Isolate.run for heavy work** -- Phase 2 uses `Isolate.run` for EPUB parsing. Phase 3 may use the same pattern if sentence splitting is heavy (likely not needed -- splitting is fast).
- **shared_preferences for simple settings** -- Theme mode already persisted this way. Font size and font family follow the same pattern.
- **Provider overrides for testing** -- Phase 2 established the pattern of Riverpod provider overrides for widget tests (spy-notifier, DB override, etc.).

### Integration Points
- **`lib/features/reader/reader_screen.dart`** -- Replace the Phase 2 stub with the real reader. The `/reader/:bookId` route already passes `bookId`.
- **`lib/core/db/app_database.dart`** -- Add queries: `getChaptersForBook(bookId)`, `updateReadingProgress(bookId, chapter, offset)`, `updateLastReadDate(bookId)`.
- **`lib/app/router.dart`** -- No changes needed; the route is already wired.
- **`lib/core/theme/`** -- Reader body text watches theme + font providers. No changes to theme infrastructure needed.
- **New files:** `lib/core/text/sentence.dart`, `lib/core/text/sentence_splitter.dart`, `lib/features/reader/` (multiple new widgets).

</code_context>

<specifics>
## Specific Ideas

- **User deferred all gray areas to sensible defaults** -- Jake said "Go with sensible defaults and what would be recommended from an ease of use perspective." All decisions above reflect standard EPUB reader patterns (horizontal chapter swiping, persistent tablet sidebar, scroll-offset resume).
- **Quiet library aesthetic carries forward** (Phase 1 D-20) -- reader chrome (app bar, bottom sheet, chapter sidebar) uses ClayColors warm neutrals. No new colors introduced.
- **Phase 3's sentence splitter is intentionally basic** -- it exists to prove the per-sentence TextSpan architecture. Phase 4 TTS-06 hardens it with 500+ fixtures. The class and location (`lib/core/text/`) are shared so Phase 4 enhances in place.
- **RDR-07 says "3-4 font families" but Phase 1 D-21 locked it to 2** -- REQUIREMENTS.md FND-06 was already amended. The font picker offers Literata and Merriweather only.

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope. User opted for sensible defaults across all areas.

*Out-of-scope items already deferred in prior phases that remain deferred:*
- Bookmarks (RDR-13, RDR-14) -- Phase 6
- Continuous-scroll reader mode (RDR-15) -- v2
- Dictionary lookup on long-press (RDR-16) -- v2
- Additional reader fonts (Atkinson Hyperlegible, Inter) -- v2 per Phase 1 D-21

</deferred>

---

*Phase: 03-reader-with-sentence-span-architecture*
*Context gathered: 2026-04-12*
