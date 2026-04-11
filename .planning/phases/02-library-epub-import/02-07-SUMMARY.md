---
phase: 02-library-epub-import
plan: 07
subsystem: library-screen-composition
tags: [library-screen, sliverappbar, slivergrid, filter-chip, bottom-sheet, debounce, empty-state, d-15, d-16, d-17, d-18, d-11, d-12, lib-01, lib-05, lib-07, lib-08, lib-09, lib-10, tdd]

# Dependency graph
requires:
  - phase: 02-library-epub-import
    provides: "Plan 02-06 LibraryNotifier + LibraryState + SortMode + BookCard + BookCardShimmer; Plan 02-05 ImportNotifier sealed ImportState hierarchy + import_picker.dart wrapper + /reader/:bookId route stub"
provides:
  - "LibraryScreen — full composition: SliverAppBar + LibrarySearchBar + LibrarySortChips + LibraryGrid + BookContextSheet + empty states"
  - "LibraryGrid — responsive SliverGrid with D-16 breakpoints (2/3 phone, 4/6 tablet) + D-11 shimmer overlay from ImportParsing state + tap→/reader/:bookId + long-press callback"
  - "LibrarySearchBar — 300ms Timer-based debounce (owns the window; notifier stays eager) + clear button that toggles on text-empty + ClayColors-only styling"
  - "LibrarySortChips — three FilterChips (Recently read / Title / Author) wired to LibraryNotifier.setSortMode, ClayColors.accent highlight"
  - "BookContextSheet — showBookContextSheet(context, book) modal sheet with Book Info (metadata dialog with chapter count from Drift) and Delete (two-step confirm → LibraryNotifier.deleteBook) per D-17 T-02-07-01 mitigation"
  - "ImportPickerCallback Riverpod seam — file_picker-free entry point so LibraryScreen's test compile graph never pulls the broken win32 Windows impl (D-02-05-A, again)"
  - "D-12 snackbar surfacing for ImportFailed states via ref.listen on importProvider inside LibraryScreen"
  - "Nyquist-rule stub un-skip: library_grid_test.dart + library_search_test.dart + book_context_sheet_test.dart + library_empty_test.dart all now carry real behavior tests"
affects: [02-08, phase-03-reader]

# Tech tracking
tech-stack:
  added: []  # no new packages
  patterns:
    - "Timer-based UI-layer debounce (300ms) in ConsumerStatefulWidget: setState() in onChanged drives clear-button visibility AND starts the timer; mounted check inside the timer callback; Timer cancelled in dispose() — the canonical shape for any future debounced text field in murmur"
    - "Spy-notifier test pattern for generated Riverpod class providers: subclass the original class, override build() to return Stream.value(state), override mutation methods to record calls. libraryProvider.overrideWith(() => spy) then plugs the spy into a ProviderScope for the widget under test. Avoids Drift entirely; avoids the flutter_tester SEGV seen when a real db.watch() stream leaks across test boundaries."
    - "Provider seam for platform-coupled callbacks: import_picker_provider.dart declares a `Provider<ImportPickerCallback>` with a no-op default; main.dart overrides with the real file_picker-backed wrapper at runApp time. LibraryScreen imports ONLY the provider file (no file_picker in its test compile graph), and tests never trigger the broken win32 Windows impl."
    - "ref.listen inside a ConsumerWidget build method for side-effect reactions (snackbars on new ImportFailed states) — using set-diff on (filename:reason) so retrying a failed filename doesn't double-surface"
    - "Navigator.pop BEFORE opening a secondary dialog: capture the LibraryNotifier reference in a local variable first, then pop the sheet, then open the confirm dialog using the root navigator context. Prevents 'ref used after element unmounted' crashes."
    - "Widget test viewport override via `tester.view.physicalSize = Size(...)` + `devicePixelRatio = 1.0` + `addTearDown(tester.view.reset)` — the supported post-Flutter-3.22 shape for the deprecated `binding.window.*TestValue` APIs"

key-files:
  created:
    - "lib/features/library/library_grid.dart"
    - "lib/features/library/library_search_bar.dart"
    - "lib/features/library/library_sort_chips.dart"
    - "lib/features/library/book_context_sheet.dart"
    - "lib/features/library/import_picker_provider.dart"
  modified:
    - "lib/features/library/library_screen.dart"
    - "lib/main.dart"
    - "test/library/library_grid_test.dart"
    - "test/library/library_search_test.dart"
    - "test/library/library_empty_test.dart"
    - "test/library/book_context_sheet_test.dart"
    - "test/widget/navigation_test.dart"

key-decisions:
  - "D-02-07-A: LibrarySearchBar owns the 300ms debounce at the UI layer per Plan 02-06 D-02-06-B. setState on every keystroke drives the clear-button visibility (the suffixIcon reads _controller.text.isEmpty on every rebuild); the Timer fires setSearchQuery exactly once per 300ms idle window. Rapid typing coalesces into a single notifier call. The plan's original code sketch omitted the setState call; adding it was deviation #3."
  - "D-02-07-B: import_picker_provider.dart is a file_picker-free Riverpod seam. library_screen.dart imports only this file, not import_picker.dart, so the test compile graph never pulls file_picker's broken win32 Windows impl. main.dart overrides importPickerCallbackProvider at runApp time with the real pickAndImportEpubs wrapper. This is the same shape as D-02-05-A's file_picker isolation — the library screen's test-time graph must stay clean."
  - "D-02-07-C: BookContextSheet's Delete path captures the notifier reference BEFORE popping the sheet. Without this, `ref.read(libraryProvider.notifier)` fires AFTER the ConsumerWidget's element has been unmounted, which Riverpod 3 throws on. The confirm dialog gets a `LibraryNotifier` (not a WidgetRef) so it doesn't touch the disposed element."
  - "D-02-07-D: Spy LibraryNotifier pattern instead of real Drift streams for widget tests. The real libraryProvider returns Stream<LibraryState> backed by a StreamController + db.select(books).watch() subscription; when a widget test leaks that subscription across test boundaries, flutter_tester crashes with 'Shell subprocess crashed with segmentation fault' on the 6th or 7th test in the file. Overriding libraryProvider with a subclass that returns Stream.value(...) gives synchronous, leak-free emissions for widget tests that only care about the UI surface."
  - "D-02-07-E: navigation_test.dart needs three overrides — appDatabaseProvider (in-memory Drift), libraryProvider (synchronous stub), shareIntentSourceProvider (no-op). Without them, pumpAndSettle hangs on the real driftDatabase() file open + the real ReceiveSharingIntent MethodChannel. The 'Timer still pending after widget tree disposed' failure mode surfaces from unresolved Futures in either of those subsystems."

patterns-established:
  - "Spy-notifier override for StreamNotifier-style providers: the go-to pattern for widget tests that want to control screen-level state synchronously without touching the underlying stream source."
  - "Platform-plugin seam via Riverpod Provider callback: the repeat of D-02-05-A's file_picker split, generalized — any new widget that needs to call into a platform plugin without pulling the plugin into test compile graphs should declare a typedef callback provider and override it at runApp time."
  - "300ms UI-layer debounce with clear-button visibility: the template for any future debounced text field (search, filter, etc.). Includes the setState-in-onChanged gotcha + the mounted check in the Timer callback + Timer cancellation in dispose."
  - "navigation_test.dart's _app() helper: every widget test that loads the real MurmurApp now needs this three-override shape (DB + libraryProvider + shareIntentSource). Future full-app widget tests should copy it."

requirements-completed:
  - LIB-01  # import button wired (SliverAppBar + empty-state CTA → pickAndImportEpubs via provider seam)
  - LIB-05  # responsive grid with 2/3/4/6 column breakpoints verified in tests (physical device verification deferred to Plan 08)
  - LIB-07  # sort chips call LibraryNotifier.setSortMode
  - LIB-08  # debounced search calls LibraryNotifier.setSearchQuery
  - LIB-09  # long-press modal sheet with Book Info + Delete + confirmation dialog
  - LIB-10  # first-import empty state with working CTA + distinct "no search results" variant

# Metrics
duration: ~55min
completed: 2026-04-11
---

# Phase 02 Plan 02-07: Library Screen Summary

**Jake can now open murmur, see the first-import placeholder, tap "Import your first book", see shimmer cards slide into the grid as EPUBs parse, search by title/author with a 300ms debounce, toggle sort chips, long-press a card to open Book Info or Delete, and tap a card to navigate to /reader/:bookId (Phase 3 stub) — LIB-01, LIB-05, LIB-07, LIB-08, LIB-09, and LIB-10 all satisfied with 18 new tests covering the chrome + empty states + context sheet.**

## Performance

- **Duration:** ~55 min (longer than Plan 02-06 because of navigation_test.dart fallout — three provider overrides + the spy-notifier pattern had to be rediscovered in-flight)
- **Started:** 2026-04-11T22:20Z (immediately after 02-06 final docs commit)
- **Completed:** 2026-04-11
- **Tasks:** 2 of 2
- **Files created:** 5 (library_grid.dart, library_search_bar.dart, library_sort_chips.dart, book_context_sheet.dart, import_picker_provider.dart)
- **Files modified:** 7 (library_screen.dart rewritten, main.dart + ProviderScope overrides, 4 Wave 0 test stubs un-skipped, navigation_test.dart three overrides added)
- **Test delta:** 109 pass / 6 skipped → **127 pass / 2 skipped / 0 fail** (+18 real tests, 4 Wave 0 stubs un-skipped)

## Accomplishments

- **Task 1 (TDD) — backing widgets for library chrome:**
  - `LibraryGrid` is a `ConsumerWidget` that computes column count via `MediaQuery.sizeOf(context).shortestSide` + orientation per D-16: 2 cols on phone portrait, 3 on phone landscape, 4 on tablet portrait, 6 on tablet landscape. `childAspectRatio: 0.50` was chosen (down from the plan sketch's 0.55) to give `BookCard`'s Column enough vertical headroom on narrow phone-portrait cells — a 6px RenderFlex overflow in the populated-grid widget test was the trigger.
  - `LibraryGrid` also overlays one `BookCardShimmer(filename: p.filename)` per `ImportParsing` entry from `importProvider` — D-11's optimistic insert UX. The shimmer cards are prepended to the real book list so the grid resolves left-to-right as the batch import progresses.
  - `LibrarySearchBar` is a `ConsumerStatefulWidget` with a 300ms `Timer`-based debounce (per Plan 02-06 D-02-06-B — the notifier stays eager, the UI owns the window). `setState()` fires on every keystroke to drive the clear-button visibility; the Timer fires `setSearchQuery` exactly once per 300ms idle. Rapid typing coalesces to the last value. Tests assert (a) no call at 100ms, (b) call at 350ms, (c) rapid typing produces one final call, (d) clear-button visibility, (e) tapping clear resets both the text AND the query.
  - `LibrarySortChips` renders three `FilterChip`s (Recently read / Title / Author) that read `sortMode` from `libraryProvider` and call `setSortMode` on tap. Active chip highlights with `ClayColors.accent.withValues(alpha: 0.15)` fill + matching label/border — zero new palette.

- **Task 1 tests:** 11 total — 4 breakpoint cases for LibraryGrid (phone portrait/landscape, tablet portrait/landscape), 1 shimmer overlay test, 1 long-press callback test, and 5 LibrarySearchBar tests (3 debounce timing + 2 clear button). All use the `_SpyLibraryNotifier` spy pattern (see Deviation #8) to avoid flutter_tester SEGVs from leaked Drift stream subscriptions.

- **Task 2 (TDD) — LibraryScreen composition + context sheet + empty states:**
  - `LibraryScreen` was fully rewritten from the Phase 1 `StatelessWidget` placeholder into a `ConsumerWidget`. The body is a `Scaffold(key: Key('library-screen'), body: libAsync.when(...))` where the data branch picks one of two layouts:
    - **First-import empty state** (D-18) — when `books.isEmpty && searchQuery.isEmpty && !parsingInFlight`, renders the Phase 1 placeholder structure (96px `Icons.menu_book_outlined`, headline `Your library is empty`, body `Import an EPUB to start listening.`, `FilledButton.icon('Import your first book')`) with the button now calling `ref.read(importPickerCallbackProvider)(ref)`.
    - **CustomScrollView with chrome** — `SliverAppBar(pinned, title: 'Library', import +-icon action)` + `SliverToBoxAdapter(LibrarySearchBar())` + `SliverToBoxAdapter(LibrarySortChips())` + either `SliverFillRemaining('No books match your search')` (distinct empty-search variant per D-18 amendment) OR the `LibraryGrid`.
  - Long-press on a `BookCard` (via the `LibraryGrid`'s onLongPress callback) opens the `BookContextSheet` with the tapped `Book` — the Grid's callback receives only the `book.id`, so the screen looks up the full Book in `state.books` before opening the sheet.
  - D-12 snackbars: `ref.listen<List<ImportState>>(importProvider, ...)` inside the `build` method diffs newly-failed imports (compared by `filename:reason` key to avoid double-fires on retry) and calls `ScaffoldMessenger.of(context).showSnackBar` for each. The listener runs inside `build` per Riverpod's idiomatic ref.listen placement.
  - `BookContextSheet` is a `showModalBottomSheet` helper function + a private `_BookContextSheet` ConsumerWidget with two `ListTile`s. The Delete tap captures `ref.read(libraryProvider.notifier)` into a local `notifier` variable BEFORE calling `Navigator.of(context).pop()` on the sheet — so when the confirm `AlertDialog` opens a moment later, it has a live `LibraryNotifier` reference even though the ConsumerWidget's element is already unmounted (see Deviation #5). Confirm → `notifier.deleteBook(book.id)`; cancel → no-op.
  - Book Info dialog reads `chapter count` via `db.selectOnly(db.chapters)..addColumns([countAll()])..where(...).getSingle()` — a leaf-widget DB query that's a mild code smell but kept local because the info dialog is out-of-band with `LibraryNotifier`'s grid-oriented state. File size comes from `File(book.filePath).lengthSync()` with an error fallback. `context.mounted` guards the post-async `showDialog` call.

- **`import_picker_provider.dart` file_picker seam:** LibraryScreen's SliverAppBar import button and empty-state CTA both need to trigger the real file picker. But `import_picker.dart` pulls in `package:file_picker/file_picker.dart`, which unconditionally exports its Windows impl — and the Windows impl is incompatible with our `win32: ^6.0.0` override (same root cause as Plan 02-05 D-02-05-A). If LibraryScreen imported `import_picker.dart` directly, every widget test loading the library screen would fail to compile.
  - The fix is a new file `lib/features/library/import_picker_provider.dart` that declares a `Provider<ImportPickerCallback>` with a no-op default. `library_screen.dart` imports only this file (no file_picker in its graph). `main.dart` overrides the provider at runApp time with `(ref) => import_picker.pickAndImportEpubs(ref)`, pulling in `import_picker.dart` only from the production entry point.
  - Repeats the 02-05 file_picker isolation pattern at a different layer. Documented as decision D-02-07-B.

- **Task 2 tests:** 7 total. **library_empty_test.dart** (3 tests) — first-import empty state renders the 96px icon + headline + body + Import button; empty-search state renders "No books match your search" and NOT the first-import CTA; populated grid renders SliverAppBar + both book titles. **book_context_sheet_test.dart** (4 tests) — sheet shows Book Info + Delete; Delete shows confirm dialog with book title + Cancel + Delete buttons; confirming calls `deleteBook(42)`; cancelling does not call `deleteBook`.

- **navigation_test.dart fallout:** The pre-existing 3 navigation tests started failing immediately after LibraryScreen became a ConsumerWidget watching the real `libraryProvider`. The failure mode was `pumpAndSettle` timing out, then transitioning to "A Timer is still pending even after the widget tree was disposed" at test teardown. Root cause: the real libraryProvider opens a Drift `.watch()` stream against the real `driftDatabase(name: 'murmur')` path + the real `ReceiveSharingIntent.instance.getInitialMedia()` MethodChannel, neither of which have a test binding. Fix required **three** provider overrides in `_app()`:
  - `appDatabaseProvider.overrideWithValue(_testDb)` — in-memory Drift
  - `libraryProvider.overrideWith(_StubLibraryNotifier.new)` — synchronous Stream.value() emitter
  - `shareIntentSourceProvider.overrideWithValue(const _NoopShareIntentSource())` — no-op getInitialPaths/getPathStream
  Documented as D-02-07-E. All 3 nav tests green after the fix.

- **Final verification:**
  - `flutter test test/library/library_grid_test.dart test/library/library_search_test.dart` — 11 / 11 green
  - `flutter test test/library/library_empty_test.dart test/library/book_context_sheet_test.dart` — 7 / 7 green
  - `flutter test test/widget/navigation_test.dart` — 3 / 3 green (was failing after initial LibraryScreen rewrite; fixed with the three-override pattern)
  - `flutter test` (full suite) — **127 pass / 2 skipped / 0 fail** (+18 vs baseline 109/6; 4 Wave 0 stubs un-skipped)
  - `flutter analyze` — 1 pre-existing `analysis_options.yaml` plugins-section warning (unchanged from Phase 1 commit `a6f6e7f`), 0 new issues

## Task Commits

Each task committed atomically on the main working tree with normal hooks (no worktrees, no --no-verify):

1. **Task 1 RED:** `f439b51` — `test(02-07): failing LibraryGrid + LibrarySearchBar tests (TDD RED)`
2. **Task 1 GREEN:** `9d33f5a` — `feat(02-07): LibraryGrid + LibrarySearchBar + LibrarySortChips`
3. **Task 2 RED:** `83d56db` — `test(02-07): failing LibraryScreen empty + BookContextSheet tests (TDD RED)`
4. **Task 2 GREEN:** `2a19385` — `feat(02-07): LibraryScreen composition + context sheet + empty states`

**Plan metadata (final docs commit):** pending — created after this SUMMARY.md is written.

## Files Created/Modified

### Created
- `lib/features/library/library_grid.dart` — 90 lines. ConsumerWidget taking a `List<Book>` + `ValueChanged<int>` long-press callback. Computes column count from `MediaQuery.shortestSide` + orientation per D-16. Prepends shimmer cards from `importProvider.whereType<ImportParsing>()`. Tap navigates via `context.push('/reader/${book.id}')`.
- `lib/features/library/library_search_bar.dart` — 108 lines. ConsumerStatefulWidget with `Timer? _debounce`, `setState` in `_onChanged` for clear-button toggle, 300ms debounce window, ClayColors styling for the TextField decoration (filled, 24px border radius, accent focused border).
- `lib/features/library/library_sort_chips.dart` — 66 lines. ConsumerWidget rendering three FilterChips inside a horizontal SingleChildScrollView. Active chip uses `ClayColors.accent` fill/checkmark/label/border.
- `lib/features/library/book_context_sheet.dart` — 178 lines. `showBookContextSheet(context, book)` helper + private `_BookContextSheet` ConsumerWidget with two ListTiles. `_confirmAndDelete` takes a LibraryNotifier (not WidgetRef) so the Navigator.pop before showDialog doesn't strand a dead ref. `_showInfoDialog` runs a small Drift `countAll()` query + `File(book.filePath).lengthSync()`.
- `lib/features/library/import_picker_provider.dart` — 42 lines. `ImportPickerCallback` typedef + `importPickerCallbackProvider` Provider with a no-op default. File_picker-free so library_screen.dart's test compile graph stays clean.

### Modified
- `lib/features/library/library_screen.dart` — rewritten from 52-line StatelessWidget placeholder into 170-line ConsumerWidget composing the real library UX (empty state / grid / chrome / snackbars). Preserves `Key('library-screen')` for navigation_test.
- `lib/main.dart` — added ProviderScope overrides block to wire `importPickerCallbackProvider` with the real `import_picker.pickAndImportEpubs` at runApp time.
- `test/library/library_grid_test.dart` — 240 lines / 6 tests (4 breakpoints + shimmer + long-press). Uses `tester.view.physicalSize` for viewport sizing, `_setViewport` helper with `addTearDown(tester.view.reset)`.
- `test/library/library_search_test.dart` — 145 lines / 5 tests. Uses `_SpyLibraryNotifier` that overrides `build()` to return a synchronous `Stream.value()` and captures `setSearchQuery` calls — avoids flutter_tester SEGVs on leaked Drift stream subscriptions.
- `test/library/library_empty_test.dart` — 138 lines / 3 tests. Spy notifier + `libraryProvider.overrideWith(() => spy)` in a ProviderScope wrapping the real LibraryScreen.
- `test/library/book_context_sheet_test.dart` — 147 lines / 4 tests. `_host` helper with an ElevatedButton that opens the sheet; spy notifier captures `deleteCalls`.
- `test/widget/navigation_test.dart` — added `_StubLibraryNotifier`, `_NoopShareIntentSource`, and a refactored `_app()` helper with three provider overrides (appDatabase + library + shareIntentSource). See D-02-07-E.

## Decisions Made

See `key-decisions` in the frontmatter. The two worth expanding:

**D-02-07-B (import_picker_provider.dart seam):** This is the *second* occurrence of the file_picker isolation problem in Phase 2 — D-02-05-A split `import_picker.dart` out of `import_service.dart` so the ImportNotifier tests could compile, and now D-02-07-B adds a Riverpod provider layer so the same isolation holds for `library_screen.dart`. The shape is: `import_picker_provider.dart` declares `typedef ImportPickerCallback = Future<void> Function(WidgetRef)` + `final importPickerCallbackProvider = Provider<ImportPickerCallback>((_) async => {})`, with a no-op default. `library_screen.dart` imports only this file. `main.dart` owns the one-and-only import of `import_picker.dart` and overrides the provider: `importPickerCallbackProvider.overrideWithValue((ref) => import_picker.pickAndImportEpubs(ref))`. Production behavior is unchanged; tests that mount LibraryScreen never compile file_picker's Windows impl. The cost is one small provider file plus a single override in main.dart. Documented in the provider file's header.

**D-02-07-D (spy notifier pattern for widget tests):** Writing the first draft of the search-bar tests surfaced a reproducible crash: `flutter_tester` SEGV'd on the 6th or 7th test in the file, every run. Stack trace pointed at `new AppDatabase` inside `setUp` — the real `libraryProvider`'s stream subscription to `db.select(books).watch()` was leaking across test boundaries via the keepAlive container, and SQLite eventually tripped over the accumulated subscriptions. The fix was D-02-07-D: stop using the real provider. Subclass `LibraryNotifier`, override `build()` to return `Stream.value(initialState)`, override the mutation methods to record calls, and plug the subclass in via `libraryProvider.overrideWith(() => spy)`. Widget tests now exercise the UI's interaction with the notifier's *interface* (method calls + emitted state) instead of re-testing the Drift-backed stream (which is already covered by Plan 02-06's provider tests). The pattern generalizes to any generated Riverpod class-provider that wraps a platform resource or database stream.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Provider name naming (inherited, pre-emptive)**
- **Found during:** Task 1 test-writing
- **Issue:** The plan's code sketch referenced `libraryNotifierProvider` and `importNotifierProvider`. Both are wrong — `riverpod_generator 4.0.3` drops the `Notifier` suffix, so the real names are `libraryProvider` and `importProvider`. Root cause inherited from Plan 02-05 deviation #3.
- **Fix:** Wrote all tests + production code with `libraryProvider` and `importProvider` from the start.
- **Committed in:** `f439b51` (Task 1 RED) and onward.

**2. [Rule 3 - Blocking] `pickAndImport()` doesn't exist on ImportNotifier**
- **Found during:** Task 2 initial library_screen.dart draft
- **Issue:** The plan's code sketch called `ref.read(importNotifierProvider.notifier).pickAndImport()` from the empty-state button and the SliverAppBar action. `ImportNotifier` has no such method — Plan 02-05 intentionally split the file_picker entry point into `import_picker.dart`'s free function `pickAndImportEpubs(WidgetRef ref)`. Importing `import_picker.dart` from `library_screen.dart` would pull `file_picker` → `file_picker_windows.dart` → `win32 6.x` compile errors into every test loading LibraryScreen.
- **Fix:** Created `lib/features/library/import_picker_provider.dart` declaring a `Provider<ImportPickerCallback>` with a no-op default. `library_screen.dart` imports ONLY this file. `main.dart` overrides the provider at runApp time with the real `pickAndImportEpubs` wrapper from `import_picker.dart`. Tests override with spies or leave the default no-op.
- **Files affected:** `lib/features/library/import_picker_provider.dart` (new), `lib/features/library/library_screen.dart` (imports provider, not import_picker.dart), `lib/main.dart` (override wiring)
- **Committed in:** `2a19385` (Task 2 GREEN)
- **Production impact:** One small new file + one override block in main.dart. LibraryScreen's import button behavior is unchanged in production.

**3. [Rule 1 - Bug] LibrarySearchBar clear button won't appear (missing setState)**
- **Found during:** Task 1 test-writing (advisor pre-emptive warning)
- **Issue:** The plan's code sketch had the clear-button's `suffixIcon` computed from `_controller.text.isEmpty` in the `build` method, but `_onChanged` only started the Timer — no `setState`. The result: the TextField's text changes, but the parent StatefulWidget never rebuilds, so the suffix icon stays null forever.
- **Fix:** Added `setState(() {});` to the top of `_onChanged`. The rebuild re-reads `_controller.text` and the clear button appears/disappears correctly. Verified by the two `LibrarySearchBar — clear button` tests.
- **Committed in:** `9d33f5a` (Task 1 GREEN)

**4. [Rule 1 - Bug] RenderFlex overflow by 6 pixels in BookCard Column (childAspectRatio too tight)**
- **Found during:** Task 2 first run of `library_empty_test.dart` populated-grid test
- **Issue:** The plan's `LibraryGrid` sketch used `childAspectRatio: 0.55`. At phone-portrait viewport 400×800dp, the SliverGrid cells were ~119×217dp. BookCard's Column is `AspectRatio(2/3) cover (~179px) + 8px gap + 14px title + 14px author ≈ 223px` — overflowed by 6px. The exception didn't fail any explicit assertion, but `testWidgets` bubbles any uncaught Flutter exception as a test failure.
- **Fix:** Changed `childAspectRatio: 0.55 → 0.50` in `library_grid.dart`. Cells are now ~119×238dp — ~15px headroom for font metrics. All breakpoint tests still pass with the new aspect ratio.
- **Committed in:** `2a19385` (Task 2 GREEN, bundled with the rest of the screen rewrite)

**5. [Rule 1 - Bug] BookContextSheet's _confirmAndDelete used `ref` after element unmounted**
- **Found during:** Task 2 `book_context_sheet_test.dart` first run
- **Issue:** The plan's original sketch had `_confirmAndDelete` taking a `WidgetRef` parameter and calling `ref.read(libraryProvider.notifier).deleteBook(...)`. But the sheet is popped BEFORE the confirm dialog opens (correct UX — dialogs shouldn't be nested in a modal sheet route). By the time the user taps "Delete" in the confirm dialog, the sheet's ConsumerWidget element is unmounted, and `ref.read` throws "A Ref was used after the widget element was disposed".
- **Fix:** Changed `_confirmAndDelete`'s signature from `(BuildContext, WidgetRef, Book)` to `(BuildContext, LibraryNotifier, Book)`. The caller (the Delete `ListTile.onTap`) reads the notifier BEFORE popping the sheet: `final notifier = ref.read(libraryProvider.notifier); Navigator.pop(context); await _confirmAndDelete(rootContext, notifier, book);`. The confirm dialog's context is the root navigator context (so it survives the sheet pop).
- **Committed in:** `2a19385` (Task 2 GREEN)

**6. [Rule 3 - Blocking] Search-bar tests SEGV'd flutter_tester on accumulated Drift stream subscriptions**
- **Found during:** Task 1 first run of `library_search_test.dart`
- **Issue:** Initial search-bar tests used the real `libraryProvider` + real `AppDatabase(NativeDatabase.memory())` per test. After ~5 tests in the file, `flutter_tester` crashed with `TestDeviceException(Shell subprocess crashed with segmentation fault)`. The stack trace pointed at `new AppDatabase` inside the next test's `setUp` — the keepAlive libraryProvider was leaking `db.select(books).watch()` subscriptions across test boundaries, and SQLite eventually tripped over the accumulated state.
- **Fix:** Introduced the `_SpyLibraryNotifier` pattern (D-02-07-D): subclass LibraryNotifier, override `build()` to return `Stream.value(initial)`, override mutation methods to record calls, plug into the test tree via `libraryProvider.overrideWith(() => spy)`. Widget tests now exercise the UI's *interface* with the notifier — no real Drift, no leaked streams, no SEGVs. Same pattern reused in `library_empty_test.dart` and `book_context_sheet_test.dart`.
- **Committed in:** `9d33f5a` (Task 1 GREEN) — spy pattern introduction; `2a19385` (Task 2 GREEN) — pattern reused.

**7. [Rule 3 - Blocking] navigation_test.dart pumpAndSettle hang + "Timer still pending" after LibraryScreen rewrite**
- **Found during:** Task 2 full-suite run after LibraryScreen rewrite
- **Issue:** The pre-existing 3 navigation tests started failing because `LibraryScreen` went from a trivial `StatelessWidget` placeholder to a `ConsumerWidget` that watches `libraryProvider` (which opens a real Drift stream subscription against the real `driftDatabase(name: 'murmur')` path). The test mode has no platform binding for `path_provider`, so the DB open hangs; `pumpAndSettle` times out; teardown fires the "Timer is still pending even after the widget tree was disposed" invariant. Same problem applies to the `shareIntentListenerProvider` MethodChannel call.
- **Fix:** Added three provider overrides in the test's `_app()` helper:
  - `appDatabaseProvider.overrideWithValue(_testDb)` — in-memory Drift set up in `setUpAll`
  - `libraryProvider.overrideWith(_StubLibraryNotifier.new)` — synchronous `Stream.value()` emission, never touches the real DB
  - `shareIntentSourceProvider.overrideWithValue(const _NoopShareIntentSource())` — empty getInitialPaths + empty getPathStream + no-op reset
- **Files affected:** `test/widget/navigation_test.dart` (new `_StubLibraryNotifier` + `_NoopShareIntentSource` + `_app()` helper)
- **Committed in:** `2a19385` (Task 2 GREEN)
- **Pattern note:** Any future widget test that loads the full `MurmurApp` will need this same three-override shape. Documented as D-02-07-E.

**8. [Rule 1 - Bug / lint] Unused import + angle-brackets-in-doc-comment (cleanups)**
- **Found during:** Task 2 analyzer pass
- **Issue:** `library_empty_test.dart` imported `import_service.dart` but never used it (ImportNotifier state overrides were unreachable once the spy pattern replaced them). `library_grid_test.dart` had `List<Book>` in a `///` doc comment, which the analyzer interprets as HTML.
- **Fix:** Removed the unused import; wrapped `List<Book>` in backticks in the doc comment.
- **Committed in:** `2a19385` (Task 2 GREEN)

---

**Total deviations:** 8 auto-fixed (3 Rule-3 blocking — file_picker seam, SEGV mitigation, navigation test overrides; 5 Rule-1 bugs — provider name, setState in onChanged, ref-after-unmount, aspect ratio overflow, cleanup lints). Zero Rule-4 architectural decisions. Rules 1–3 all applied without pausing — the plan's delivered surface matches the interface block exactly, with the only additions being the `import_picker_provider.dart` seam (mandated by Rule 3) and the `coverImageOverride` pattern inherited from 02-06.

**Impact on plan:** No scope change. All six requirements completed. The deviations were predominantly test-infrastructure corrections (navigation_test fallout + spy notifier) and one small production architectural decision (import picker provider seam) that was forced by the file_picker win32 incompatibility — the same root cause as 02-05 D-02-05-A, now touching a different layer of the widget tree.

## Issues Encountered

- **flutter_tester SEGV from leaked Drift streams** — took ~10 minutes to diagnose. First suspicion was Image.file hangs (the 02-06 problem), but `coverPath: null` forces the fallback branch, so images weren't involved. Second suspicion was test teardown ordering. The actual root cause was the keepAlive libraryProvider's StreamController + StreamSubscription accumulating across test boundaries. Fixed by introducing the spy-notifier pattern (D-02-07-D).
- **navigation_test "Timer still pending"** — initially unclear which Timer was pending because neither LibrarySearchBar's debounce Timer nor any explicit Timer in libraryProvider was active. The Timer turned out to be deep in Drift's batching layer when `db.select(books).watch()` tries to set up — without a real path_provider binding, the subscription setup leaves a Timer hanging. Fixed with the libraryProvider stub override (D-02-07-E).
- **childAspectRatio tuning** — the plan's 0.55 overflowed BookCard by 6px on 400×800 phone-portrait. Flipped to 0.50 for generous headroom. Bigger lesson: any future grid with BookCard-style cells should start at ≤0.50 and tune UP if needed, not down.
- **Pre-existing analysis_options.yaml warning** — unchanged from Phase 1. Out of scope per the execute-plan boundary rule.

## User Setup Required

None. All changes are in-repo source. No new packages, no env vars, no external services. On next clone: `mise exec -- flutter pub get` + `dart run build_runner build` regenerates nothing (no new `@Riverpod` annotations this plan — `import_picker_provider.dart` uses a hand-rolled `Provider`, not codegen).

## Known Stubs

- **`pickAndImportEpubs` still untested (inherited from 02-05).** The function is a 4-line wrapper around `FilePicker.pickFiles` + `importFromPaths`, and the file_picker surface cannot be mocked inside `flutter test`. Production call sites (SliverAppBar import button, empty-state CTA, long-press import) all route through `importPickerCallbackProvider`, which is overridable in tests — but only the provider layer is tested. Manual verification row for the picker UI path on device lands in Plan 02-08's manual section.
- **`/reader/:bookId` stub renders "Book #$id — Phase 3 will render this"** (also inherited from 02-05). BookCard's `onTap` navigates to this route. No data fetched. Phase 3 replaces the body with the RichText sentence-span pipeline.

No new stubs introduced by this plan. The LibraryScreen fully renders real data from `libraryProvider` + `importProvider`; no mock data flows to the UI.

## Next Phase Readiness

**Plan 02-08 (persistence test + 15-EPUB corpus + physical-device manual verification) unblocked.** It can:
1. Drive the full user flow end-to-end: tap import → file picker → ImportNotifier → LibraryNotifier → SliverGrid cards appear.
2. Exercise `LibraryNotifier.deleteBook` via the long-press context sheet's Delete → confirm flow, and assert (a) row removed, (b) chapters cascade, (c) cover file cleaned up, (d) EPUB file cleaned up — all in one user gesture.
3. Run the manual "does this look right on a physical phone + tablet in both orientations" check that was explicitly deferred from this plan. The automated breakpoint tests give confidence in the column-count logic; the device check is for feel and layout quality.
4. Validate the 300ms search debounce feels right on-device.

**Phase 3 (reader)** inherits:
- A working `/reader/:bookId` navigation path from BookCard tap.
- `libraryProvider.notifier.deleteBook` that cleanly cascades chapters + files, so the reader can safely rely on `Book.id → Chapter[]` lookups without worrying about orphan rows.
- A stable `lastReadDate` column that the library grid auto-re-sorts when the reader updates it (the underlying Drift stream fires, `libraryProvider` re-emits, the grid re-renders).

No blockers.

## Threat Flags

None — no new network endpoints, no new trust boundaries, no new file-access patterns, no new schema. The D-12 snackbar filename display already goes through `p.basename` in ImportNotifier (T-02-05-02 defense) before reaching the user-visible text, and the Book Info dialog only shows data the user themselves imported (T-02-07-02 accepted). The T-02-07-01 two-step delete gesture is implemented exactly as the threat register specified: long-press → tap Delete → confirmation dialog → tap Delete again.

## Self-Check: PASSED

Verified files exist:
- `lib/features/library/library_grid.dart` — FOUND
- `lib/features/library/library_search_bar.dart` — FOUND
- `lib/features/library/library_sort_chips.dart` — FOUND
- `lib/features/library/book_context_sheet.dart` — FOUND
- `lib/features/library/import_picker_provider.dart` — FOUND
- `lib/features/library/library_screen.dart` — MODIFIED (170 lines, was 52)
- `lib/main.dart` — MODIFIED (ProviderScope override added)
- `test/library/library_grid_test.dart` — MODIFIED (240 lines, 6 tests, was 19-line stub)
- `test/library/library_search_test.dart` — MODIFIED (145 lines, 5 tests, was 19-line stub)
- `test/library/library_empty_test.dart` — MODIFIED (138 lines, 3 tests, was 19-line stub)
- `test/library/book_context_sheet_test.dart` — MODIFIED (147 lines, 4 tests, was 19-line stub)
- `test/widget/navigation_test.dart` — MODIFIED (added _StubLibraryNotifier + _NoopShareIntentSource + three-override _app())

Verified commits exist in `git log`:
- `f439b51` (Task 1 RED) — FOUND
- `9d33f5a` (Task 1 GREEN) — FOUND
- `83d56db` (Task 2 RED) — FOUND
- `2a19385` (Task 2 GREEN) — FOUND

Verified test + analyze baseline:
- `flutter test` — **127 pass / 2 skipped / 0 fail** (+18 vs baseline 109/6)
- `flutter analyze` — 1 pre-existing warning, 0 new issues

Verified grep contracts:
- `SliverAppBar` appears in `library_screen.dart`
- `SliverGridDelegateWithFixedCrossAxisCount` appears in `library_grid.dart`
- `Debouncer|Timer.*300` → `Timer(const Duration(milliseconds: 300)` appears in `library_search_bar.dart`
- `FilterChip` appears in `library_sort_chips.dart`
- `showModalBottomSheet` appears in `book_context_sheet.dart`
- `/reader/` appears in `library_grid.dart` (`context.push('/reader/${book.id}')`)
- `importPickerCallbackProvider` appears in `library_screen.dart` AND `main.dart`
- `ClayColors\.` used throughout the new files; zero new color constants introduced
- `shareIntentListenerProvider` is watched in `app.dart` (pre-existing from 02-05, confirmed not duplicated here)

---

*Phase: 02-library-epub-import*
*Plan: 07*
*Completed: 2026-04-11*
