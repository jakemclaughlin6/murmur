# Phase 2: Library & EPUB Import - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can import one or more DRM-free EPUBs (via file picker or system Share / Open-in), see them in a responsive library grid on phones and tablets, and have metadata + cover art persist across restarts — backed by a rich `Chapter { blocks: List<Block> }` intermediate representation validated against a 15-EPUB test corpus. This phase covers the full import pipeline, Drift DB schema (v1→v2 migration), EPUB parsing to Block IR, responsive grid with sort/search, context sheet, and all empty/error states.

**Explicitly out of scope for Phase 2** (belongs in later phases):
- Reader text rendering and sentence-span pipeline (Phase 3)
- TTS playback (Phase 4)
- Sentence highlighting (Phase 5)
- Bookmarks, sleep timer, onboarding, accessibility pass (Phase 6)
- Store upload (Phase 7)

</domain>

<decisions>
## Implementation Decisions

### EPUB IR Depth
- **D-01:** Phase 2 builds the **full `Chapter { blocks: List<Block> }` intermediate representation at import time** — not raw HTML strings. Block types: `paragraph`, `heading` (h1–h6), `image`, `blockquote`, `list_item`. The parser walks the XHTML DOM using `package:html`, emits typed Block records, and stores them immediately. Phase 3 gets a pre-parsed IR and focuses on rendering, not parsing.
- **D-02:** Richer EPUB constructs not covered by the five block types (tables, footnotes, sidebars) are **mapped to their nearest equivalent** at parse time (table → series of paragraphs, footnote → paragraph with a marker prefix) rather than silently dropped or stored raw. This prevents "missing content" complaints on edge-case EPUBs.
- **D-03:** Block IR is **stored as `blocks_json TEXT` in the chapters Drift table** — a JSON-serialized `List<Block>`. No separate blocks table. Each chapter row: `id`, `book_id`, `order_index`, `title` (nullable), `blocks_json`. This keeps the schema simple and avoids a per-sentence query per chapter-load in Phase 3.

### Drift Schema (v1 → v2 Migration)
- **D-04:** Phase 2 introduces the first real Drift tables: `books` and `chapters`. The Drift migration from v1 → v2 uses the **generated `drift_dev` migrations workflow** established in Phase 1 (D-17), diffing against the committed v1 schema dump in `drift_schemas/`.
- **D-05:** The `books` table minimum columns: `id` (int, PK), `title` (text), `author` (text, nullable), `file_path` (text, unique — the imported EPUB's path in app documents dir), `cover_path` (text, nullable — extracted JPEG/PNG cached to disk), `import_date` (datetime), `last_read_date` (datetime, nullable), `reading_progress_chapter` (int, nullable), `reading_progress_offset` (real, nullable — 0.0–1.0 within chapter, wired up in Phase 3).
- **D-06:** Cover images are **extracted from the EPUB at import time and written as files** to `${appDocumentsDir}/covers/{bookId}.jpg`. The `books` table stores the cover file path, not the raw bytes. `Image.file()` loads them — no `cached_network_image` needed (per D from Phase 1 CONTEXT).

### Book Card Design
- **D-07:** Cover art displayed as **full-bleed crop to fill the card's cover area** — `BoxFit.cover` centered. Clean, recognizable, consistent with standard ebook apps (Kindle, Books, Kobo).
- **D-08:** Missing cover fallback: **oat-tone `ClayColors.background` (`#FAF9F7`) fill + `Icons.menu_book_outlined` centered**, icon color `ClayColors.textTertiary`. Uses existing ClayColors constants — zero new palette decisions.
- **D-09:** Card text area shows **title (body-medium weight, `ClayColors.textPrimary`) + author (body-small, `ClayColors.textSecondary`)**. Two lines, ellipsis overflow. No third line in Phase 2.
- **D-10:** Reading progress ring: **only shown when `reading_progress_chapter` is non-null** (i.e., user has opened the book at least once in Phase 3). Unread books show no ring. Phase 2 renders the ring as a placeholder `CircularProgressIndicator(value: 0.0)` or thin arc — actual progress wiring happens in Phase 3.

### Import UX & Batch Feedback
- **D-11:** Import uses an **optimistic insert pattern**: when the user confirms file selection, each selected EPUB is immediately inserted into the library grid as a card with a **shimmer loading state** (grey animated placeholder for cover + text). Parsing runs in the background. When parsing completes for a book, the card resolves to its real cover/metadata. If parsing fails, the shimmer card transitions to an error state (brief) and is then removed from the grid.
- **D-12:** Errors surface as **one snackbar per failed book**: `'Could not import [filename] — file may be DRM-protected or corrupt.'` The snackbar has no action button. Library is unchanged for that book; other books in the batch continue normally.
- **D-13:** The import `Riverpod` provider runs parsing on a **background `Isolate`** (or `compute()`) to keep the UI at 60fps during multi-file batch import. The provider emits progress state per book.
- **D-14:** Share / Open-in (LIB-02) uses the **same import pipeline** as file picker — the app receives the EPUB file URI via platform intent/document provider, calls the same import function. No separate code path.

### Library Screen Layout
- **D-15:** Library screen chrome (top to bottom):
  1. App bar with title "Library" and import `+` icon button (trailing)
  2. Persistent search text field (full-width, below app bar, inside `SliverAppBar` or sticky header)
  3. Row of filter chips: `Recently read` | `Title` | `Author` — horizontally scrollable if needed, accent chip for active sort
  4. Responsive `SliverGrid` of book cards
- **D-16:** Grid column count via `SliverGrid.delegate` breakpoints: **2 cols on phone portrait, 3 on phone landscape, 4–6 on tablets** (4 for small tablet portrait, 6 for large tablet landscape). Breakpoints on `MediaQuery.sizeOf(context).shortestSide`: < 600 dp → phone rules, ≥ 600 dp → tablet rules.
- **D-17:** Long-press on a book card opens a **modal bottom sheet** with two options: `Book Info` (shows title, author, file size, import date, chapter count) and `Delete` (with a confirmation dialog before deletion). Swipe-to-dismiss closes the sheet.
- **D-18:** Empty library state (LIB-10) reuses the **Phase 1 placeholder** from `library_screen.dart`: `Icons.menu_book_outlined` (96px, `ClayColors.textTertiary`), headline "Your library is empty", body "Import an EPUB to start listening.", `FilledButton.icon` "Import your first book". Phase 2 wires the button to `file_picker`.

### Claude's Discretion
- Exact shimmer animation implementation (package or hand-rolled `AnimatedContainer`).
- Specific card aspect ratio (recommended: ~2:3 cover area, ~1:4 text area below).
- Exact search debounce timing (recommended: 300ms).
- Whether `reading_progress_offset` in Phase 2 is stored as a real 0.0–1.0 or deferred entirely to Phase 3 (Phase 3 will define the exact reading position model).
- EPUB parser edge-case strategy for malformed XHTML (recommended: catch exceptions per-chapter, mark that chapter's `blocks_json` as `[]` with an error flag, continue with remaining chapters rather than failing the whole book).
- Grid padding and card spacing values within quiet-library aesthetic.

</decisions>

<specifics>
## Specific Ideas

- **Quiet library aesthetic carries forward** (Phase 1 D-20): ClayColors are locked. All new UI elements (cards, chips, search field, bottom sheet) must use ClayColors constants — no new colors introduced in Phase 2 without a new CONTEXT.md decision.
- **Phase 1 library placeholder is the starting point** (D-12 from Phase 1): The existing `LibraryScreen` already has the correct empty-state structure (`Icon` + headline + body text + `FilledButton`). Phase 2 replaces its `Center` body with the real grid, keeping the empty state logic.
- **`epubx` Dart 3.11 compatibility must be verified first** (flagged in STATE.md and Phase 1 CONTEXT): The first task of Phase 2 should be a spike — import `epubx`, parse one EPUB, confirm no analyzer or runtime errors. If `epubx` fails, fall back to `package:archive` + `package:xml` + `package:html` (~200 LOC custom parser). Do not proceed to the full import pipeline until this spike passes.
- **15-EPUB test corpus**: The roadmap goal references validation against 15 EPUBs. The planner should include a task to assemble a test corpus of 15 DRM-free EPUBs covering edge cases: books with no cover, books with non-standard XHTML, very long books (>500 chapters), books with footnotes, books with embedded images.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level specs
- `.planning/PROJECT.md` — Vision, constraints, "no Mac" constraint, EPUB-only hard line, sentence-span architecture commitment, Kokoro TTS overview
- `.planning/REQUIREMENTS.md` §Library (LIB-01 through LIB-11) — All eleven LIB- items for Phase 2
- `.planning/ROADMAP.md` §"Phase 2: Library & EPUB Import" — Goal, depends-on, success criteria
- `.planning/STATE.md` — Current session state, blockers (epubx staleness flag)
- `CLAUDE.md` — Full tech stack recommendations, what-NOT-to-use list (epub_view, flutter_html, flutter_widget_from_html), risks section (epubx staleness, sherpa_onnx), GSD enforcement

### Phase 1 context (decisions that carry forward)
- `.planning/phases/01-scaffold-compliance-foundation/01-CONTEXT.md` — D-17 (Drift migration workflow), D-18/D-19/D-20 (ClayColors palette locked, quiet-library directive), D-21/D-22 (Literata + Merriweather only), D-23 (system font for chrome), D-15/D-16 (Drift schema baseline)

### Research done before Phase 1 (still relevant)
- `.planning/research/STACK.md` — `epubx` staleness risk, `package:html` parser notes, `file_picker` iOS Info.plist keys, `shared_preferences` vs Drift decision
- `.planning/research/PITFALLS.md` — EPUB messiness, sentence splitter non-triviality, known gotchas

### Phase 1 code (integration points)
- `lib/core/db/app_database.dart` — Current Drift v1 schema (empty, schemaVersion=1). Phase 2 adds tables here.
- `lib/features/library/library_screen.dart` — Existing placeholder; Phase 2 replaces body with real grid.
- `lib/core/theme/clay_colors.dart` — All theme color constants; LOCKED. Use only these in Phase 2 UI.
- `lib/app/router.dart` — go_router setup; Phase 2 adds `/reader/:bookId` route.
- `drift_schemas/` — v1 schema dump; Phase 2's migration diffs against this.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`ClayColors`** (`lib/core/theme/clay_colors.dart`) — All four theme palettes fully locked. Every color decision in Phase 2 references a `ClayColors` constant.
- **`AppDatabase`** (`lib/core/db/app_database.dart`) — Empty Drift shell at v1. Phase 2 adds `books` and `chapters` table definitions here and bumps `schemaVersion` to 2.
- **`LibraryScreen`** (`lib/features/library/library_screen.dart`) — Existing empty-state scaffold. Phase 2 replaces the `Center` child with a `CustomScrollView` + `SliverGrid`; the `FilledButton.icon` wires to real import.
- **`MurmurShellScaffold` + `NavigationBar`** (`lib/app/router.dart`) — Bottom nav already has Library / Reader / Settings destinations. Phase 2 doesn't change the nav structure.
- **`AppDatabaseProvider`** (`lib/core/db/app_database_provider.dart`) — Riverpod provider for `AppDatabase`; Phase 2 new providers watch this.

### Established Patterns
- **`@riverpod` annotations** with `riverpod_generator` + `build_runner` — all providers use generated typed providers. No hand-rolled `StateNotifierProvider`.
- **`@DriftDatabase` + generated migrations** — `drift_dev` workflow from day one (D-17). `build_runner` generates the `.g.dart` companions.
- **`@Riverpod(keepAlive: true)`** for app-lifetime singletons (router, DB). Phase 2's import service likely also `keepAlive: true`.
- **System font for UI chrome** (D-23) — app bars, buttons, chips, bottom sheets all use system font. Only reader body text uses Literata/Merriweather.

### Integration Points
- **`lib/core/db/app_database.dart`** — Add `Books` and `Chapters` table classes, bump `schemaVersion` to 2, add v1→v2 migration step.
- **`lib/app/router.dart`** — Add `/reader/:bookId` route (Phase 2 doesn't implement the reader, but the route needs to exist so book cards can tap into it as a stub in Phase 3).
- **`lib/features/library/library_screen.dart`** — Replace body with real `CustomScrollView` with `SliverAppBar`, search field, sort chips, and `SliverGrid`.
- **`lib/features/library/`** — New files: `book_card.dart`, `library_provider.dart`, `import_service.dart`, `epub_parser.dart` (or `lib/core/epub/` for the parser).
- **`assets/` or `pubspec.yaml`** — No new assets needed in Phase 2 (covers are extracted at runtime, not bundled).
- **`android/app/src/main/AndroidManifest.xml`** — Verify `READ_MEDIA_*` permissions already declared in Phase 1 (FND-08); add `android.intent.action.VIEW` intent filter for EPUB MIME type if not already present.
- **`ios/Runner/Info.plist`** — Verify `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`, `CFBundleDocumentTypes` for `org.idpf.epub-container` already present from Phase 1 (FND-07).

</code_context>

<deferred>
## Deferred Ideas

None raised during discussion — discussion stayed within phase scope.

*Out-of-scope items already deferred in Phase 1 CONTEXT that remain deferred:*
- Collections / tags / series grouping (LIB-12, per REQUIREMENTS.md — explicitly out of scope)
- Import from cloud drives via Files app (LIB-13, per REQUIREMENTS.md — explicitly out of scope)

</deferred>

---

*Phase: 02-library-epub-import*
*Context gathered: 2026-04-11*
