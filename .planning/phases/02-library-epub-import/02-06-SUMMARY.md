---
phase: 02-library-epub-import
plan: 06
subsystem: library-state-and-atomic-widgets
tags: [riverpod, drift, stream, sort, search, book-card, shimmer, d-07, d-08, d-09, d-10, d-11, d-15, lib-06, lib-07, lib-08, tdd]

# Dependency graph
requires:
  - phase: 02-library-epub-import
    provides: "Plan 02-03 Drift v2 schema (books table + last_read_date + coverPath columns, chapters ON DELETE CASCADE + PRAGMA foreign_keys ON); Plan 02-05 ImportNotifier populates books table via single pipeline"
provides:
  - "LibraryNotifier — @Riverpod(keepAlive: true) Stream<LibraryState> watching db.select(db.books).watch() with in-memory sort + search + delete"
  - "LibraryState immutable snapshot: {books, sortMode, searchQuery} — Plan 07 renders from this single source"
  - "SortMode enum: recentlyRead (DESC nulls last), title (A-Z), author (A-Z nulls last)"
  - "setSortMode / setSearchQuery mutations re-emit immediately (no debounce — Plan 07's text field owns 300ms)"
  - "deleteBook: row + chapters cascade + best-effort cover + EPUB file cleanup"
  - "BookCard widget — atomic grid tile (2:3 cover, D-07/08/09/10 visual spec)"
  - "BookCard.coverImageOverride — test seam for Image.file widget-test hang mitigation"
  - "BookCardShimmer widget — hand-rolled ShaderMask animation (no shimmer package)"
  - "Nyquist-rule stub un-skip: library_provider_test.dart + book_card_test.dart now carry real behavior tests"
affects: [02-07, phase-03-reader]

# Tech tracking
tech-stack:
  added: []  # no new packages
  patterns:
    - "Stream<LibraryState> @Riverpod class with manual StreamController + db.watch() subscription + ref.onDispose teardown — the shape needed when mutations must re-emit without re-querying Drift"
    - "Test-level re-emission capture: container.listen(libraryProvider, cb, fireImmediately: true) + Completer waiting for a predicate — the only reliable way to assert sort/search re-emission order (container.read(.future) resolves the first emission only)"
    - "ImageProvider test seam: nullable coverImageOverride field on a StatelessWidget is the minimal-surface workaround for Image.file's widget-test decoder hang. MemoryImage in tests, FileImage in production"
    - "Hand-rolled ShaderMask shimmer via AnimationController.repeat() + AnimatedBuilder — ~40 LOC, zero-dep, uses only ClayColors constants"
    - "Nulls-last sort via '\\uFFFF' sentinel for string columns; explicit null checks for DateTime columns"

key-files:
  created:
    - "lib/features/library/library_provider.dart"
    - "lib/features/library/library_provider.g.dart"
    - "lib/features/library/book_card.dart"
    - "lib/features/library/book_card_shimmer.dart"
  modified:
    - "test/library/library_provider_test.dart"
    - "test/library/book_card_test.dart"

key-decisions:
  - "D-02-06-A: LibraryNotifier caches the latest raw Drift snapshot in _latestRaw and re-applies sort+search on every mutation — avoids round-tripping the DB for UI-local state changes. Sort/search are pure in-memory operations over ~100 Book records; Drift is the source of truth only for row identity."
  - "D-02-06-B: No debouncing at the provider layer. Plan 07's TextField owns the 300ms debounce (per 02-CONTEXT Claude's Discretion note) because the debounce window is a UI concern and belongs where the TextField lives. Keeping the provider eager makes it trivial to test and keeps re-emission semantics simple."
  - "D-02-06-C: coverImageOverride test seam is a one-field nullable ImageProvider on BookCard. Production call sites (Plan 07) never pass it; tests inject MemoryImage to sidestep the well-known Image.file + testWidgets decoder hang. This is minimum-viable production surface — documented as a test seam in code — and avoids the alternative of runAsync + precacheImage gymnastics that still hang intermittently."
  - "D-02-06-D: Stream-based notifier uses a manual StreamController because @Riverpod streams emit on every downstream mutation via 'update the StreamController', not via 'return a new Stream'. The build() method subscribes once to db.select(books).watch() and bridges emissions into the controller; mutations then call _emit() which publishes a new LibraryState synchronously. ref.onDispose cancels the subscription AND closes the controller."
  - "D-02-06-E: Nulls-last strategy differs by column type. For author (String?) we use the '\\uFFFF' sentinel which sorts after any real string in ASCII order — English-only v1 makes this safe. For lastReadDate (DateTime?) we use explicit null checks because DateTime has no sentinel-like max value that is both cheap and locale-independent."

patterns-established:
  - "Provider-state test harness: container.listen with a Completer + predicate is the GSD pattern for asserting stream provider re-emission after a notifier mutation. Any future provider that exposes a Stream<...> and a mutation method inherits this as the go-to test shape."
  - "Sealed / enum-driven switch in Riverpod notifier _emit() — exhaustive switch on SortMode with no default branch means adding a new mode forces a compile-time update, protecting future sort additions from silent omission."
  - "Test seam via nullable override field on a StatelessWidget: low-friction pattern for widgets that wrap platform-plugin or async-I/O primitives (Image.file, File, etc.) without introducing a full DI framework."
  - "No-shimmer-package ShaderMask shimmer: 40 LOC, zero new dependency, uses only locked theme colors — the default approach for any future shimmer need in murmur."

requirements-completed:
  - LIB-06
  - LIB-07
  - LIB-08

# Metrics
duration: ~50min
completed: 2026-04-11
---

# Phase 02 Plan 02-06: Library Provider + BookCard/BookCardShimmer Summary

**Backing layer for the library grid — LibraryNotifier (@Riverpod Stream) wraps `db.select(books).watch()` with in-memory sort (recentlyRead / title / author, nulls-last) + case-insensitive search (title | author) + deleteBook that cascades chapters and cleans up cover + EPUB files on disk; BookCard (atomic 2:3 tile with D-07 full-bleed cover, D-08 fallback icon, D-09 typography, D-10 conditional progress ring) and BookCardShimmer (hand-rolled ShaderMask, zero dep, only ClayColors) are ready for Plan 07 to compose into SliverGrid.**

## Performance

- **Duration:** ~50 min (longer than Plan 02-05 because of the Image.file widget-test hang diagnosis + rework)
- **Started:** 2026-04-11T21:34Z (right after 02-05 final docs commit)
- **Completed:** 2026-04-11
- **Tasks:** 2 of 2
- **Files created:** 4 (library_provider.dart + .g.dart, book_card.dart, book_card_shimmer.dart)
- **Files modified:** 2 (library_provider_test.dart, book_card_test.dart — both Wave 0 stubs un-skipped)
- **Test delta:** 86 pass / 8 skipped → **109 pass / 6 skipped / 0 fail** (+23 real tests, 2 Nyquist stubs un-skipped)

## Accomplishments

- **Task 1 (LibraryNotifier, TDD):**
  - `LibraryNotifier` is a `@Riverpod(keepAlive: true)` class-style notifier whose `build()` returns a `Stream<LibraryState>` backed by a manual `StreamController`. On build, it subscribes to `db.select(db.books).watch()` and bridges every Drift emission into `_emit()`, which applies the current sort + search state and pushes a new `LibraryState` onto the controller.
  - `SortMode` enum is exhaustively switched inside `_emit()`: `recentlyRead` sorts `lastReadDate` DESC with nulls last (never-read books at the bottom), `title` sorts A-Z with `String.compareTo`, `author` sorts A-Z using a `'\uFFFF'` sentinel so null authors land last in one comparator pass.
  - Search filters case-insensitive on either title OR author substring (toLowerCase + contains). Empty query short-circuits to the raw list.
  - `setSortMode` and `setSearchQuery` guard against no-op changes and re-emit from `_latestRaw` (the cached Drift snapshot) without round-tripping the DB — the data did not change, only the view over it.
  - `deleteBook` fetches the row first (so we have the cover + EPUB paths), deletes the row (chapters cascade via Plan 02-03's `PRAGMA foreign_keys = ON`), then best-effort deletes the cover file and the EPUB file. Deletion of a missing id is a silent no-op. All file-cleanup errors are swallowed because the DB is the source of truth and an orphan file is a disk-bloat concern, not a correctness failure.
  - `ref.onDispose` cancels the subscription AND closes the controller — prevents the "controller never closed" leak on provider teardown.
- **Task 1 test suite:** 12 behavior tests green — initial build (empty + seeded), 3 sort modes, 3 search cases (title match, author match, clear), 4 deleteBook cases (removal, chapter cascade, cover file cleanup, missing-id no-op). The test harness uses `container.listen(libraryProvider, ...)` + `Completer` + predicate because `container.read(.future)` only resolves the first emission, which cannot assert re-emission ordering across mutations.
- **Task 2 (BookCard + BookCardShimmer, TDD):**
  - `BookCard` is a const-constructible `StatelessWidget` taking a `Book`, optional `onTap`, optional `onLongPress`, and an optional `coverImageOverride` (test seam — see Deviation #4). Layout is `InkWell > Column` with:
    - `AspectRatio(2/3) > Stack(StackFit.expand)` for the cover area (D-07 full-bleed)
    - Inside the Stack: `_buildCover()` + `Positioned(bottom:6, right:6) SizedBox(20x20) CircularProgressIndicator(value: readingProgressOffset ?? 0.0)` conditional on `readingProgressChapter != null` (D-10)
    - `SizedBox(h:8)` gap + `Padding+Text` title (body-medium, textPrimary, maxLines:1, ellipsis) + optional `Padding+Text` author (body-small, textSecondary, maxLines:1, ellipsis) — the author row is omitted entirely when `book.author == null` per D-09 ("no 'Unknown' placeholder row").
  - `_buildCover` selects among three branches: test override → `Image(image: override)`, else cover path → `Image.file(File(coverPath))`, else → `_buildFallback()`. All three use `errorBuilder` to degrade corrupt/missing images to the fallback (T-02-06-01 mitigation).
  - `_buildFallback` is `Container(color: ClayColors.background) > Center > Icon(menu_book_outlined, size:48, color: ClayColors.textTertiary)` per D-08. Zero new colors.
  - `BookCardShimmer` is a minimal `StatefulWidget` with `SingleTickerProviderStateMixin`. `initState` creates an `AnimationController(duration: 1400ms)..repeat()`, `dispose` disposes it. `build` wraps an `AnimatedBuilder` around a `ShaderMask` whose `LinearGradient` sweeps `ClayColors.borderSubtle → ClayColors.background → ClayColors.borderSubtle` across the card bounds, driven by `Alignment(-1 - 2t, 0)` / `Alignment(1 - 2t, 0)`. The shaded tree is three placeholder rectangles (cover, title line, short author line) — same 2:3 ratio as `BookCard` so the grid transition is seamless when the shimmer resolves to a real card.
- **Task 2 test suite:** 11 behavior tests green — 2 cover art (fallback when coverPath null + Image with BoxFit.cover when override is present), 3 typography (title style, author style, author-row-omitted), 2 progress ring (present when readingProgressChapter != null, absent when null), 2 interaction (onTap + onLongPress), 2 shimmer (frames render without exception + dispose on unmount with `takeException()` null guard).
- **Final verification:**
  - `flutter test test/library/library_provider_test.dart` — 12 / 12 green
  - `flutter test test/library/book_card_test.dart` — 11 / 11 green
  - `flutter test` (full suite) — **109 pass / 6 skipped / 0 fail** (+23 real tests vs 86/8 baseline; 2 Wave 0 stubs un-skipped)
  - `flutter analyze` — 1 pre-existing warning (`analysis_options.yaml` plugins section, unchanged from Plan 01-08), 0 new issues

## Task Commits

Each task was committed atomically on the main working tree with normal hooks (no worktrees, no --no-verify):

1. **Task 1 RED:** `cd95de2` — `test(02-06): failing LibraryNotifier tests (TDD RED)`
2. **Task 1 GREEN:** `699a22c` — `feat(02-06): LibraryNotifier — reactive Drift stream with sort + search + delete`
3. **Task 2 RED:** `15d0e57` — `test(02-06): failing BookCard + BookCardShimmer tests (TDD RED)`
4. **Task 2 GREEN:** `86a38e6` — `feat(02-06): BookCard + BookCardShimmer atomic widgets`

**Plan metadata (final docs commit):** pending — created after this SUMMARY.md is written.

## Files Created/Modified

### Created
- `lib/features/library/library_provider.dart` — 206 lines. `SortMode` enum (3 variants), immutable `LibraryState` snapshot with `copyWith`, `@Riverpod(keepAlive: true)` `LibraryNotifier` with `_latestRaw` cache + manual `StreamController` bridge + `_emit()` applying sort/search + `setSortMode` / `setSearchQuery` / `deleteBook` mutations + `ref.onDispose` teardown.
- `lib/features/library/library_provider.g.dart` — Generated riverpod code exporting `libraryProvider` (`_$libraryProviderHash`, the usual shape).
- `lib/features/library/book_card.dart` — 149 lines. Documented `StatelessWidget` with `coverImageOverride` test seam (nullable `ImageProvider`), `_buildCover` three-branch selector (override / FileImage / fallback), `_buildFallback` D-08 container + icon. Zero package imports beyond Flutter material + `dart:io` (for `File` in production branch) + local `app_database.dart` + `clay_colors.dart`.
- `lib/features/library/book_card_shimmer.dart` — 107 lines. `StatefulWidget` + `_BookCardShimmerState` with `SingleTickerProviderStateMixin`, `AnimationController(1400ms).repeat()`, `AnimatedBuilder` + `ShaderMask` + `LinearGradient` sweep. Only `ClayColors.borderSubtle` and `ClayColors.background` constants; no new palette.

### Modified
- `test/library/library_provider_test.dart` — replaced 19-line Wave 0 stub with 272 lines / 12 real tests. Per-test in-memory `NativeDatabase.memory()` + `ProviderContainer` override of `appDatabaseProvider`. `waitForState(predicate)` helper wraps `container.listen` + `Completer` so the tests can assert re-emission order after `setSortMode` / `setSearchQuery`.
- `test/library/book_card_test.dart` — replaced 19-line Wave 0 stub with 246 lines / 11 real tests. `_wrap()` helper gives widgets a 140×280 SizedBox (280 prevents the 2:3 cover + gap + two text rows from overflowing the 240 flex budget the first draft used). `makeBook()` constructs Books via the Drift-generated constructor directly so tests don't touch the import pipeline. `_onePixelPng` byte literal backs the `MemoryImage` override test.

## Decisions Made

See `key-decisions` in frontmatter. The two worth expanding:

**D-02-06-C (`coverImageOverride` test seam):** The plan's original test sketch called for `Image.file` in widget tests against a real 1×1 PNG written to `Directory.systemTemp`. This is a well-documented Flutter testing footgun: `FileImage`'s async decode schedules frame callbacks that interact with `testWidgets`'s FakeAsync-backed frame scheduler and never resolve, causing the test to hang for 90+ seconds until the outer `timeout` kills it. Multiple mitigation attempts failed:
- Skipping the second `tester.pump()` call (advisor's first recommendation) — still hung inside `pumpWidget` itself.
- Wrapping `pumpWidget` in `tester.runAsync(() async { ... })` (advisor's fallback) — still hung; the fake scheduler is scoped to the entire `testWidgets` call and `runAsync` only gives the body real Timer access, not the binding.
- A structural `build()` + queue-walker approach that never mounted Image.file — introduced a different hang (the structural walker itself, likely on a widget-tree cycle through Positioned/ProxyWidget recursion).

The pragmatic fix is a one-field nullable `ImageProvider` override on `BookCard`. Tests pass `MemoryImage(_onePixelPng)` and the `_buildCover` method picks the override branch, which uses `Image(image: MemoryImage)` — MemoryImage resolves synchronously in widget tests because its "decode" is a pure byte-array parse with no file-system or network I/O. Production code (Plan 07's SliverGrid) leaves `coverImageOverride` null and gets the real `Image.file(File(coverPath))` path. The production surface grows by exactly one nullable field, documented in code as a test seam. This is cheaper than any DI framework and cheaper than the `runAsync`/`precacheImage` gymnastics.

**D-02-06-D (manual StreamController bridge in the notifier):** The Riverpod `StreamNotifier` class-style pattern returns a `Stream<T>` from `build()` and the framework listens to it. But our notifier needs to re-emit on `setSortMode` / `setSearchQuery` mutations WITHOUT the underlying Drift stream firing (the DB data didn't change, only the view over it did). A plain `db.select(books).watch()` stream doesn't meet that requirement — there is no way to synthesize an extra emission. So `build()` creates an internal `StreamController<LibraryState>`, subscribes to `db.select(books).watch()` as an upstream source, and calls `_emit()` inside the listener. Mutations call `_emit()` directly to push a fresh state. `ref.onDispose` cancels the upstream subscription and closes the controller, preventing the "StreamController not closed" leak that would otherwise accumulate across test runs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `libraryNotifierProvider` → `libraryProvider` (riverpod_generator 4 naming)**
- **Found during:** Task 1 test-writing (pre-emptively caught before RED, per advisor's pre-start warning)
- **Issue:** The plan's interface sketch and the test's `container.read(...)` calls used `libraryNotifierProvider`, but `riverpod_generator 4.0.3` drops the `Notifier` suffix when generating the provider variable — it emits `libraryProvider` for `class LibraryNotifier`. This is the same root cause as Plan 02-05 deviation #3 (`importProvider` from `ImportNotifier`), inherited across the whole codebase as the project's naming convention.
- **Fix:** Wrote the test with `libraryProvider` from the start (Plan 02-05 precedent referenced). The class name `LibraryNotifier` is unchanged.
- **Committed in:** `cd95de2` (Task 1 RED)

**2. [Rule 1 - Bug] `AsyncValue.valueOrNull` does not exist in riverpod 3.2.1**
- **Found during:** Task 1 first GREEN test run
- **Issue:** The test's `waitForState` helper called `next.valueOrNull` on an `AsyncValue<LibraryState>`. Riverpod 3.2.1 exposes `value` as a nullable getter on the base `AsyncValue` type (returns `ValueT?`), which is the correct name — `valueOrNull` is the Riverpod 2.x name and was renamed in 3.x.
- **Fix:** Changed `next.valueOrNull` → `next.value`. The semantics (`returns T? or null if not a value state`) are identical in Riverpod 3.
- **Files modified:** `test/library/library_provider_test.dart`
- **Committed in:** `699a22c` (Task 1 GREEN, bundled with the implementation)

**3. [Rule 1 - Bug / lint] Unnecessary `flutter_riverpod` import**
- **Found during:** Task 1 `flutter analyze` after first GREEN
- **Issue:** `library_provider.dart` imported both `flutter_riverpod/flutter_riverpod.dart` and `riverpod_annotation/riverpod_annotation.dart`, but every symbol used (`Ref`, `StreamController`, etc.) is re-exported by `riverpod_annotation`. Analyzer flagged `unnecessary_import`.
- **Fix:** Removed the `flutter_riverpod` import.
- **Committed in:** `699a22c` (Task 1 GREEN)

**4. [Rule 3 - Blocking] `Image.file` hangs in `testWidgets` under FakeAsync**
- **Found during:** Task 2 first GREEN test run
- **Issue:** The plan's test called `Image.file` via a real 1×1 PNG written to a temp directory. `FileImage`'s async decode schedules frame callbacks that interact with `testWidgets`'s FakeAsync-backed frame scheduler and never resolve. The first test hung for 90 seconds at the first `pumpWidget` call before the outer `timeout 90` killed it. `runAsync` + `precacheImage` workarounds still hung; only dropping `Image.file` from the test path resolved it.
- **Fix:** Added a `coverImageOverride` nullable `ImageProvider` field to `BookCard`. Production (Plan 07) leaves it null and gets `Image.file`; tests pass `MemoryImage(_onePixelPng)` and `_buildCover` takes the override branch with `Image(image: override)`. MemoryImage's synchronous byte-decode plays nicely with `testWidgets`. Documented as "test seam" in the field's docstring.
- **Files modified:** `lib/features/library/book_card.dart` (+9 lines for the field + override branch), `test/library/book_card_test.dart` (rewrote the failing test to use the override)
- **Verification:** 11 / 11 book card tests green in 2 seconds (previously hung indefinitely).
- **Committed in:** `86a38e6` (Task 2 GREEN)
- **Production impact:** One nullable field on `BookCard`, one extra branch in `_buildCover` (`if (coverImageOverride != null) ... else if (book.coverPath != null) ...`). Call sites that don't opt in get bit-for-bit the same behavior as the plan's original sketch. The cost is ~9 lines of production code for a 11-test suite that runs in 2 seconds instead of blocking forever.

**5. [Rule 1 - Bug] RenderFlex overflow in widget test `_wrap` helper**
- **Found during:** Task 2 first GREEN test run (in the logged exception before the Image.file hang)
- **Issue:** The `_wrap` helper gave BookCard a 140×240 SizedBox. BookCard's layout is `AspectRatio(2/3) > 210px cover + 8px gap + ~14px title + ~12px author = ~244px`, which overflowed the 240px flex budget by ~14px and threw a RenderFlex-overflow debug exception. The exception was non-fatal (layout still ran) but polluted test output.
- **Fix:** Increased the `_wrap` SizedBox height from 240 to 280, giving generous headroom.
- **Files modified:** `test/library/book_card_test.dart` (2 lines)
- **Committed in:** `86a38e6` (Task 2 GREEN)

### Inherited from Plan 02-05

- The `libraryProvider` vs `libraryNotifierProvider` naming convention was already established in Plan 02-05 deviation #3 (`importProvider` from `ImportNotifier`). Listed as Deviation #1 above for self-containment, but the root cause is the riverpod_generator 4.0.3 "drop Notifier suffix" rule, not new behavior introduced by this plan.

---

**Total deviations:** 5 auto-fixed (3 Rule-1 bugs + 1 Rule-1 test-env layout + 1 Rule-3 blocking test framework hang).
**Impact on plan:** The plan's delivered surface (`LibraryNotifier` + `BookCard` + `BookCardShimmer`) matches the interface block exactly. The only production change outside the sketch is the `coverImageOverride` test seam on `BookCard`, which is a one-field nullable addition documented as a test-only hook. No scope change; no requirement change.

## Issues Encountered

- **`Image.file` widget-test hang diagnosis took ~20 minutes** — ran two failed fix attempts (skip second pump, runAsync wrapper, structural walker) before settling on the test seam. The root cause (FakeAsync-scoped frame scheduler cannot complete FileImage decode) is well known in the Flutter issue tracker but not in the plan's code sketch. Logged as D-02-06-C so future Image-loading widgets inherit the pattern.
- **Multiple orphaned `flutter_tester` processes** left from failed hanging tests during diagnosis — cleaned up via `pkill` before the final successful runs. Not a regression in the plan's deliverables.
- **Pre-existing `analysis_options.yaml` plugins-section warning** unchanged from Phase 1 commit `a6f6e7f`. Out of scope per the execute-plan boundary rule.

## User Setup Required

None. All changes are in-repo source. No new packages, no env vars, no external services. On next clone, `mise exec -- flutter pub get` pulls the existing dep graph and `dart run build_runner build` regenerates the new `library_provider.g.dart`.

## Known Stubs

- **None from this plan.** `LibraryNotifier` emits real Drift-backed state, `BookCard` renders real book data, `BookCardShimmer` renders an animated placeholder. The `coverImageOverride` test seam is a seam, not a stub — production call sites leave it null and get `Image.file`.

## Next Phase Readiness

**Plan 02-07 (library_screen) unblocked.** It can wire:
1. `ref.watch(libraryProvider)` as the `SliverGrid`'s data source — `LibraryState.books` is already filtered + sorted.
2. Three `FilterChip` widgets for `SortMode.recentlyRead` / `title` / `author`, each calling `ref.read(libraryProvider.notifier).setSortMode(...)`. The active chip highlights from `state.sortMode`.
3. A `TextField` with a 300ms `Timer`-based debounce calling `setSearchQuery`. The provider emits eagerly; the debounce is purely a UI concern.
4. `BookCard` as the grid tile with `onTap: () => context.go('/reader/${book.id}')` and `onLongPress: () => showModalBottomSheet(...)` for the D-17 context sheet.
5. `BookCardShimmer(filename: ...)` overlaid for each `ImportParsing` entry in the `importProvider` state (Plan 02-05's sealed `ImportState` hierarchy).
6. Delete flow via `ref.read(libraryProvider.notifier).deleteBook(bookId)` from the context sheet's Delete action.

**Plan 02-08 (persistence test + 15-EPUB corpus)** can now assert that deleting a book via `libraryProvider.notifier.deleteBook(id)` (a) removes the row, (b) cascades chapters, (c) cleans up the cover file, and (d) cleans up the EPUB file — all in one call.

**Phase 3 (reader)** inherits the stable `lastReadDate` column that `LibraryNotifier.SortMode.recentlyRead` already sorts by. When Phase 3 wires up the real reader, updating `lastReadDate` causes `LibraryNotifier` to automatically re-emit (via the underlying Drift stream) and the library grid re-sorts itself on next build.

No blockers.

## Threat Flags

None — no new network endpoints, auth paths, file-access patterns, or schema changes at trust boundaries. The `coverImageOverride` seam operates entirely within the existing `Book.coverPath` trust boundary (validated at import time). `deleteBook`'s best-effort file cleanup uses paths that came from the DB, which themselves came from the import pipeline's `p.basename`-scoped destPath construction (T-02-05-02 still applies).

## Self-Check: PASSED

Verified files exist:
- `lib/features/library/library_provider.dart` — FOUND
- `lib/features/library/library_provider.g.dart` — FOUND
- `lib/features/library/book_card.dart` — FOUND
- `lib/features/library/book_card_shimmer.dart` — FOUND
- `test/library/library_provider_test.dart` — MODIFIED (272 lines, 12 tests)
- `test/library/book_card_test.dart` — MODIFIED (246 lines, 11 tests)

Verified commits exist in `git log`:
- `cd95de2` (Task 1 RED) — FOUND
- `699a22c` (Task 1 GREEN) — FOUND
- `15d0e57` (Task 2 RED) — FOUND
- `86a38e6` (Task 2 GREEN) — FOUND

Verified test + analyze baseline:
- `flutter test` — **109 pass / 6 skipped / 0 fail** (+23 vs baseline 86/8)
- `flutter analyze` — 1 pre-existing warning, 0 new issues

Verified grep contracts:
- `db\.select\(.*books` appears in `library_provider.dart` (Drift stream)
- `ClayColors\.` appears in `book_card.dart` (textPrimary, textSecondary, textTertiary, background, borderSubtle, accent)
- `ClayColors\.` appears in `book_card_shimmer.dart` (borderSubtle, background)
- `Image\.file` appears in `book_card.dart` (production branch of `_buildCover`)
- No `shimmer:` package import anywhere
- No new color constants introduced (only existing `ClayColors.*`)

---

*Phase: 02-library-epub-import*
*Plan: 06*
*Completed: 2026-04-11*
