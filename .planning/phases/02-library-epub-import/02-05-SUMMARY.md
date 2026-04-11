---
phase: 02-library-epub-import
plan: 05
subsystem: import-pipeline
tags: [import, file-picker, share-intent, receive-sharing-intent, riverpod, drift, isolate, d-11, d-12, d-13, d-14, lib-01, lib-02, lib-04, tdd]

# Dependency graph
requires:
  - phase: 02-library-epub-import
    provides: "Plan 02-01 dep graph (receive_sharing_intent ^1.8.1 substitution, win32 override); Plan 02-02 Block IR + block_json codec; Plan 02-03 Drift v2 schema (books UNIQUE file_path, chapters ON DELETE CASCADE, PRAGMA foreign_keys ON); Plan 02-04 parseEpubInIsolate + DrmDetectedException + EpubParseException"
provides:
  - "ImportNotifier (@Riverpod keepAlive) — single pipeline for LIB-01 file picker AND LIB-02 Share/Open-in per D-14"
  - "sealed ImportState hierarchy (Parsing/Success/Failed) for Plan 07 card state rendering per D-11"
  - "appDocumentsDirProvider — Riverpod seam wrapping path_provider.getApplicationDocumentsDirectory so tests can override with a temp dir without PathProviderPlatform mocks"
  - "ShareIntentListener with abstract ShareIntentSource seam — production uses ReceiveSharingIntent; tests inject FakeShareIntentSource"
  - "Top-level /reader/:bookId GoRoute (outside StatefulShellRoute) so Plan 07 book cards navigate to a full-screen reader (Phase 3 will fill in the body)"
  - "Android intent filters for application/epub+zip (VIEW, SEND, SEND_MULTIPLE) so file browsers and Share targets route EPUBs into the import pipeline"
  - "Nyquist-rule stub un-skip: import_service_test.dart + share_intent_test.dart now carry real behavior tests"
affects: [02-06, 02-07, 02-08, phase-03-reader]

# Tech tracking
tech-stack:
  added:
    - "path ^1.9.0 (promoted transitive -> direct; used by import_service for p.join / p.basename)"
  patterns:
    - "Abstract source seam over a platform plugin (ShareIntentSource) as the Riverpod-overridable test boundary — avoids TestDefaultBinaryMessengerBinding ceremony"
    - "Separate thin file for the file_picker entry point (import_picker.dart) so tests do not transitively compile file_picker's Windows impl (incompatible with our win32 ^6.0.0 override)"
    - "Copy-before-insert rollback: destPath File.copy runs before the Drift insert; any exception during insert deletes the copied file so UNIQUE collisions never leave orphan bytes"
    - "Fire-and-forget isolate dispatch from share listener: unawaited(importFromPaths(...)) because the listener does not own the progress UI — ImportNotifier publishes its own state"
    - "Partial progress publication: state is rewritten after every file in the batch so Plan 07's shimmer cards resolve one-at-a-time as the batch progresses"

key-files:
  created:
    - "lib/features/library/import_service.dart"
    - "lib/features/library/import_service.g.dart"
    - "lib/features/library/import_picker.dart"
    - "lib/features/library/share_intent_listener.dart"
    - "lib/features/library/share_intent_listener.g.dart"
  modified:
    - "android/app/src/main/AndroidManifest.xml"
    - "lib/app/router.dart"
    - "lib/app/router.g.dart"
    - "lib/app/app.dart"
    - "lib/features/reader/reader_screen.dart"
    - "test/library/import_service_test.dart"
    - "test/library/share_intent_test.dart"
    - "pubspec.yaml"
    - "pubspec.lock"

key-decisions:
  - "D-02-05-A: Split the file_picker entry point into import_picker.dart, a separate file that the test tree does NOT import. file_picker 11.0.2 unconditionally exports its Windows impl on the VM, and that impl is incompatible with our win32 ^6.0.0 override from Plan 02-01 — so transitively importing file_picker in a pure-Dart test breaks compilation. import_picker.dart is only consumed by the UI layer; import_service.dart stays free of file_picker and is therefore loadable under flutter test against real fixture EPUBs."
  - "D-02-05-B: Abstract ShareIntentSource seam instead of setMockValues. receive_sharing_intent ^1.8.1 ships a setMockValues helper but it mutates a singleton — awkward to use inside a Riverpod ProviderContainer test setup. A one-file abstract class (ShareIntentSource) with Riverpod-provided implementation is cleaner: tests override the provider with a FakeShareIntentSource and get a deterministic stream without touching platform channels."
  - "D-02-05-C: /reader/:bookId is a sibling of StatefulShellRoute, not a sub-route of the /reader branch. Opening an actual book should hide the bottom nav (full-screen reader), which a shell sub-route would not do. The existing /reader inside the shell remains as the Phase 1 placeholder tab — Plan 07 will navigate book cards to the top-level route."
  - "D-02-05-D: appDocumentsDir is a Riverpod Future provider, not a sync accessor. Tests override with `(ref) async => tempDir` and the ImportNotifier awaits the provider.future once per batch. This sidesteps PathProviderPlatform mocking entirely and keeps the production path straightforward (getApplicationDocumentsDirectory inside a single provider body)."
  - "D-02-05-E: ImportNotifier processes paths SEQUENTIALLY (not in parallel). A 20-file batch launching 20 Isolate.run calls in parallel would thrash memory on mid-range phones; sequential processing still keeps the UI 60fps because each parse is in an isolate and the progress state is published between files."

patterns-established:
  - "Test seam pattern: any Riverpod provider wrapping a platform / plugin / path_provider surface can be overridden in ProviderContainer(overrides: [...]) with an async closure or a fake instance — no TestDefaultBinaryMessengerBinding needed"
  - "Sealed ImportState hierarchy with filename as base — Plan 07 renders shimmer/real/error cards via exhaustive switch on state"
  - "Destination path constructed from basename, never from source path (T-02-05-02 path-traversal defense) — source path exits scope as soon as bytes are read"

requirements-completed:
  - LIB-01
  - LIB-02
  - LIB-04

# Metrics
duration: ~12min
completed: 2026-04-11
---

# Phase 02 Plan 02-05: Library Import Pipeline Summary

**Single end-to-end import pipeline — file_picker and Share/Open-in both route through a Riverpod `ImportNotifier` that parses in a background isolate, writes covers under the 10 MB cap, and inserts books+chapters with the D-03 blocks_json format; DRM and corrupt EPUBs emit typed `ImportFailed` states without orphaning rows; `/reader/:bookId` stub route ready for Plan 07 card navigation.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-04-11T21:19:02Z
- **Completed:** 2026-04-11T21:30:45Z
- **Tasks:** 3 of 3
- **Files created:** 5 (import_service, import_picker, share_intent_listener, two .g.dart)
- **Files modified:** 9 (manifest, router, app, reader_screen, 2 test stubs un-skipped, pubspec.yaml/lock, router.g.dart)
- **Test delta:** 74 pass / 11 skipped → **86 pass / 8 skipped / 0 fail** (+12 real tests, 3 Nyquist stubs un-skipped)

## Accomplishments

- **Task 1 (platform + router):** AndroidManifest carries three new `<intent-filter>` blocks for `application/epub+zip` (VIEW, SEND, SEND_MULTIPLE). Top-level `/reader/:bookId` GoRoute landed as a sibling of the StatefulShellRoute. ReaderScreen gained an optional `int? bookId` parameter — when non-null it renders a Phase 2 stub ("Book #$id — Phase 3 will render this"), and when null it still renders the Phase 1 Middlemarch passage so `navigation_test` keeps passing. iOS Info.plist already had `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`, and `CFBundleDocumentTypes` for `org.idpf.epub-container` from Phase 1 FND-07 — verified with grep, no change needed.
- **Task 2 (ImportNotifier, TDD):**
  - `appDocumentsDirProvider` is a Riverpod Future seam wrapping `path_provider.getApplicationDocumentsDirectory`. Tests override with `(ref) async => tempDir`.
  - Sealed `ImportState { ImportParsing, ImportSuccess, ImportFailed }` hierarchy carries `filename` at the base, `bookId` on success, and `reason` on failure — matches the D-11 contract Plan 07 will consume.
  - `ImportNotifier.importFromPaths` seeds state with one `ImportParsing` per path (D-11 optimistic), then walks each file through: read bytes → `parseEpubInIsolate(..., timeout: 30s)` → copy to `${appDocs}/books/{basename}` → insert books row → write cover (if present, ≤10MB) → update coverPath → insert chapters with `blocksJson`. Partial progress is published after every file so Plan 07 shimmer cards resolve incrementally.
  - **Typed error mapping:** `DrmDetectedException` → `ImportFailed('DRM-protected')`, `EpubParseException` → `ImportFailed('Corrupt: …')`, `SqliteException` with UNIQUE → `ImportFailed('Already in library')`, `FileSystemException` → `ImportFailed('File error: …')`, catch-all → `ImportFailed('Unknown error')`. No exception class breaks the batch loop.
  - **Copy-before-insert rollback:** the destination EPUB bytes are copied to disk *before* the Drift insert. If the insert throws (e.g. UNIQUE collision on re-import), the copied file is deleted so orphan bytes never accumulate in `books/`.
  - **Threat mitigations:** T-02-05-02 (path traversal) — destPath always constructed from `p.basename(source)` + appDocs; source path exits scope once bytes are read. T-02-05-03 (zip bomb / parser stall) — 30s timeout on the isolate call. T-02-05-04 (cover bomb) — 10 MB cap; oversized covers skipped but book still imports. T-02-05-05 (duplicate race) — UNIQUE constraint catches second insert.
- **Task 2 test suite:** 8 behavior tests green — happy path (row + title + author + file_path inside appDocs), chapters persisted with blocks_json, no-cover leaves coverPath null, DRM rejection (no orphan row), corrupt/truncated rejection, batch `[ok, drm]` continues past failure, duplicate filename UNIQUE → "Already in library", and a sealed-class shape test.
- **Task 3 (ShareIntentListener, TDD):**
  - Abstract `ShareIntentSource { getInitialPaths, getPathStream, reset }` seam over `receive_sharing_intent` projects `SharedMediaFile` records down to `List<String>` — the listener only cares about file paths.
  - `@Riverpod(keepAlive: true) shareIntentSource` returns `const ReceiveSharingIntentSource()` in production; tests override with `FakeShareIntentSource`.
  - `@Riverpod(keepAlive: true) ShareIntentListener.build()` drains cold-start initial media (with `source.reset()` after consumption), then subscribes to the hot stream. Subscription teardown wired via `ref.onDispose`.
  - `_routeToImporter` applies a case-insensitive `.epub` suffix filter (T-02-05-01 defense-in-depth over the AndroidManifest MIME filter) and dispatches to `importProvider.notifier.importFromPaths` per D-14 single pipeline.
  - `MurmurApp.build` now does `ref.watch(shareIntentListenerProvider)` so the keepAlive provider actually instantiates at app startup. The returned `AsyncValue<void>` is intentionally discarded — observable effect is rows appearing in the importer.
- **Task 3 test suite:** 4 behavior tests green — initial EPUB imports + source.reset() called, initial non-EPUB filtered, streamed EPUB imports, streamed non-EPUB filtered. All use the Fake source.
- **Final suite:** `flutter analyze` clean (1 pre-existing `analysis_options.yaml` plugins-section warning unchanged from Phase 1). `flutter test` — 86 pass / 8 skipped / 0 fail.

## Task Commits

Each task was committed atomically on the main working tree with normal hooks (no worktrees, no --no-verify):

1. **Task 1:** `0cd717a` — `feat(02-05): Android intent filters + /reader/:bookId route stub`
2. **Task 2 RED:** `7406a8c` — `test(02-05): failing ImportNotifier tests (TDD RED)`
3. **Task 2 GREEN:** `8526d43` — `feat(02-05): ImportNotifier — parser isolate to Drift insert pipeline`
4. **Task 3 RED:** `09175e2` — `test(02-05): failing ShareIntentListener tests (TDD RED)`
5. **Task 3 GREEN:** `6d7a3c5` — `feat(02-05): ShareIntentListener — Share/Open-in wired to ImportNotifier (D-14)`

**Plan metadata (final docs commit):** pending — created after this SUMMARY.md is written.

## Files Created/Modified

### Created
- `lib/features/library/import_service.dart` — Riverpod seam (`appDocumentsDir`), sealed `ImportState`, `@Riverpod(keepAlive: true) ImportNotifier` with `importFromPaths` (no file_picker imports).
- `lib/features/library/import_picker.dart` — Thin file_picker wrapper: `pickAndImportEpubs(WidgetRef)` opens the system picker, filters to `.epub`, delegates to `importProvider.notifier.importFromPaths`. Lives in a separate file so tests never compile `file_picker`.
- `lib/features/library/import_service.g.dart` — generated riverpod code.
- `lib/features/library/share_intent_listener.dart` — Abstract `ShareIntentSource`, `ReceiveSharingIntentSource` impl, `@Riverpod shareIntentSource` provider, `@Riverpod(keepAlive: true) ShareIntentListener` with initial-media drain + hot-stream subscribe + `.epub` filter.
- `lib/features/library/share_intent_listener.g.dart` — generated riverpod code.

### Modified
- `android/app/src/main/AndroidManifest.xml` — added three `<intent-filter>` blocks (VIEW, SEND, SEND_MULTIPLE) for `application/epub+zip`. No INTERNET permission (privacy constraint preserved).
- `lib/app/router.dart` — added top-level `GoRoute('/reader/:bookId')` outside the StatefulShellRoute.
- `lib/app/router.g.dart` — hash-only regeneration from the router.dart edit.
- `lib/app/app.dart` — `MurmurApp.build` now `ref.watch(shareIntentListenerProvider)` so the listener starts at app launch.
- `lib/features/reader/reader_screen.dart` — added optional `int? bookId` parameter with branching build; when non-null renders the Phase 2 stub, when null renders the pre-existing Phase 1 sample passage. Both branches assign widget keys so tests can disambiguate.
- `test/library/import_service_test.dart` — replaced Wave 0 stub with 8 real tests (happy path × 3, failure paths × 3, duplicate × 1, sealed-class shape × 1).
- `test/library/share_intent_test.dart` — replaced Wave 0 stub with 4 real tests via `FakeShareIntentSource`.
- `pubspec.yaml` — promoted `path: ^1.9.0` from transitive to direct.
- `pubspec.lock` — regenerated.

## Decisions Made

See `key-decisions` in the frontmatter. The two worth expanding here:

**D-02-05-A (file_picker isolation):** The first GREEN attempt for Task 2 imported `package:file_picker/file_picker.dart` at the top of `import_service.dart`. The tests then failed with ~20 compile errors inside `file_picker-11.0.2/lib/src/platform/windows/file_picker_windows.dart` — the file references `win32` symbols (`TEXT`, `convertToIID`, `HRESULT`, `SIGDN.SIGDN_FILESYSPATH(..., pathPtr)`) that were renamed or removed in `win32 6.0.0`, which is exactly the version we override to in Plan 02-01 because `package_info_plus 10.0.0` requires it. `file_picker 11.0.2` pins `win32 ^5.9.0` for its Windows impl, so the override leaves its Windows code referring to a symbol set that no longer exists.

On Android and iOS this is dead code — the Windows impl is never loaded at runtime. But the Dart VM analyzer doesn't know that; `file_picker/file_picker.dart` has `export 'src/platform/windows/file_picker_windows.dart'` with no `if (dart.library.io)` guard, so any code that `import`s the top-level library pulls the Windows file into the analysis graph and compilation fails under `flutter test`.

The fix is surgical: move the file_picker entry point into its own file (`import_picker.dart`) that is only consumed by the UI layer (Plan 06 will `import` it). The test file imports only `import_service.dart`, which has no file_picker dependency, so the test VM never pulls the broken Windows path. Production code still uses file_picker exactly as intended; the only cost is one extra file and a minor organizational choice. Documented as the D-02-05-A decision so Plan 06 knows why the file exists.

**D-02-05-D (appDocumentsDir as a Future provider):** The plan's code sketch called `getApplicationDocumentsDirectory()` inline inside `importFromPaths`. That works, but tests would then need a `TestDefaultBinaryMessengerBinding` mock against `PathProviderPlatform` — 15 lines of ceremony per test. The cleaner seam is a `@Riverpod(keepAlive: true) Future<Directory> appDocumentsDir` provider; production resolves it via `path_provider`, tests override with `(ref) async => tempDir`. Same surface, zero platform-channel mocking. The Future-valued provider is intentional: the real path_provider call IS async and the test helper can still return synchronously via `async => ...`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Test compilation breaks on file_picker's Windows impl under our win32 override**
- **Found during:** Task 2 first GREEN test run
- **Issue:** Importing `package:file_picker/file_picker.dart` from `import_service.dart` causes `flutter test` to fail compilation inside `file_picker-11.0.2/lib/src/platform/windows/file_picker_windows.dart`: `The method 'TEXT' isn't defined for the type 'FilePickerWindows'`, `convertToIID`, `HRESULT`, etc. These symbols exist in `win32 5.x` but not `win32 6.x`, and we override to `win32 ^6.0.0` per Plan 02-01 because `package_info_plus 10.0.0` requires it. `file_picker 11.0.2` pins `win32 ^5.9.0`, so its Windows impl is incompatible with our override.
- **Why this doesn't affect production:** `murmur` targets Android + iOS only (PROJECT.md "No desktop"), so the Windows code path is dead code at runtime. But the Dart analyzer loads it at compile time because `file_picker/file_picker.dart` unconditionally exports the Windows impl.
- **Fix:** Split the file_picker entry point into `lib/features/library/import_picker.dart` — a tiny wrapper that UI code imports but the test tree does not. `import_service.dart` no longer imports file_picker, so tests can compile against real fixture EPUBs. Production UI code (Plan 06) imports `import_picker.dart` to get the `pickAndImportEpubs(WidgetRef)` helper.
- **Files affected:** `lib/features/library/import_service.dart` (removed file_picker import + `pickAndImport` method), `lib/features/library/import_picker.dart` (new)
- **Verification:** `flutter test test/library/import_service_test.dart` — 8 tests green. `flutter analyze` — 0 new issues.
- **Committed in:** `8526d43` (Task 2 GREEN)

**2. [Rule 3 - Blocking] `path` package not a direct dependency**
- **Found during:** Task 2 first analyze run
- **Issue:** `import_service.dart` imports `package:path/path.dart` for `p.join` and `p.basename` (T-02-05-02 basename-only destination construction). Analyzer flagged `depend_on_referenced_packages` — `path` is pulled in transitively via Drift but was never a direct dep.
- **Fix:** Added `path: ^1.9.0` to `pubspec.yaml` dependencies with a comment referencing the plan decision.
- **Committed in:** `8526d43` (Task 2 GREEN)

**3. [Rule 1 - Bug] Generated riverpod provider name stripped "Notifier" suffix**
- **Found during:** Task 2 first GREEN test run
- **Issue:** The plan's interface block used `importNotifierProvider`, but `riverpod_generator 4.0.3` drops the `Notifier` suffix when generating the provider variable: it emits `importProvider` for `class ImportNotifier`. Both the test and the `import_picker.dart` wrapper referenced the old name and failed to compile.
- **Fix:** Renamed all references from `importNotifierProvider` → `importProvider` in tests and `import_picker.dart`. The class name `ImportNotifier` is unchanged; only the provider variable shrinks.
- **Committed in:** `8526d43` (Task 2 GREEN) and `6d7a3c5` (Task 3 GREEN also references the correct name from the start)

**4. [Rule 1 - Bug] `file_picker 11.0.2` API is static methods, not `FilePicker.platform.pickFiles`**
- **Found during:** Task 2 analyzer run after moving file_picker to `import_picker.dart`
- **Issue:** The plan's code sketch used `FilePicker.platform.pickFiles(...)`, which is the file_picker 10.x API. `file_picker 11.0.2` exposes `static Future<FilePickerResult?> pickFiles(...)` directly on the `FilePicker` type.
- **Fix:** Changed the call site in `import_picker.dart` from `FilePicker.platform.pickFiles(...)` to `FilePicker.pickFiles(...)`. No behavior change.
- **Committed in:** `8526d43` (Task 2 GREEN, together with the file split)

**5. [Rule 1 - Bug] `drift.dart` import shadowed `matcher`'s `isNull` in test**
- **Found during:** Task 2 first GREEN test run
- **Issue:** `package:drift/drift.dart` exports its own `isNull` (the SQL query builder). Importing it alongside `package:flutter_test/flutter_test.dart` made the test body's `expect(book.coverPath, isNull)` ambiguous.
- **Fix:** Removed the `package:drift/drift.dart` import from the test entirely (only `NativeDatabase.memory()` from `drift/native.dart` was needed).
- **Committed in:** `8526d43` (Task 2 GREEN)

**6. [Rule 1 - Doc / lint] Test locals prefixed with underscores**
- **Found during:** Task 2 final analyze run
- **Issue:** `no_leading_underscores_for_local_identifiers` flagged `_sandbox`, `_sourceDir`, `_docsDir`, `_db`, `_container` inside the test.
- **Fix:** Renamed all five locals to drop the underscore prefix (the prefix was a habit — Dart only uses underscores as library-private markers, and a function-local identifier can't be library-private).
- **Committed in:** `8526d43` (Task 2 GREEN)

**7. [Rule 3 - Inherited] receive_sharing_intent_plus → receive_sharing_intent package substitution**
- **Status:** Inherited from Plan 02-01 deviation #1. The plan file still mentions `receive_sharing_intent_plus` in its code sketch; the task prompt flagged this explicitly. No new work was required in this plan — Plan 02-01 already updated `pubspec.yaml` and spike-notes.md. Task 3's implementation uses `package:receive_sharing_intent/receive_sharing_intent.dart` throughout.

---

**Total deviations:** 7 auto-fixed (3 Rule-3 blocking — file_picker isolation, missing direct dep, inherited package substitution; 4 Rule-1 bugs — provider name, file_picker API, drift namespace clash, test lints).
**Impact on plan:** No scope change. Every deviation is a tooling/API correction that keeps the delivered surface (ImportNotifier, ShareIntentListener, router stub) exactly as the plan specified. The file_picker split is the most structurally visible — it adds one file (`import_picker.dart`) and removes file_picker from the notifier's imports — but the runtime behavior is unchanged.

## Issues Encountered

- **Pre-existing `analysis_options.yaml` plugins-section warning.** Unchanged from Phase 1 (commit `a6f6e7f` in Plan 01-08). Out of scope per the execute-plan boundary rule.
- **Pre-existing 18-package outdated notice.** All from Plan 02-01's documented overrides; not introduced by this plan.

## User Setup Required

None. All changes are in-repo. No external services, env vars, or model downloads. On next clone, `mise exec -- flutter pub get` pulls the updated dep graph automatically.

## Known Stubs

- **`ReaderScreen(bookId: ...)` body.** The `/reader/:bookId` route renders a Scaffold with a single Center text "Book #$id — Phase 3 will render this". This is *intentional and tracked* — Plan 07's library grid will navigate book cards to this route, and Phase 3 will replace the body with the sentence-span RichText pipeline. The `bookId == null` branch still renders the Phase 1 Middlemarch sample for the shell-tab placeholder. No data is fetched for the stub, so there is nothing to wire yet.
- **`pickAndImportEpubs` is untested.** The function is a 4-line wrapper around `FilePicker.pickFiles` + `importFromPaths`, and the file_picker surface cannot be mocked inside `flutter test` because of the win32 issue described in D-02-05-A. The underlying pipeline (`importFromPaths`) is covered by 8 unit tests against real fixture EPUBs. Manual verification row in `02-VALIDATION.md` covers the picker UI path on device.

## Next Phase Readiness

**Plan 02-06 (library_provider) unblocked.** It can:
1. `db.select(db.books).watch()` as a reactive stream for the library grid — rows arrive from `importProvider` (file_picker) and `shareIntentListenerProvider` (Share/Open-in), same pipeline, same shape.
2. Import `importProvider` and overlay shimmer cards from `state<ImportParsing>` and error cards from `state<ImportFailed>` per D-11.
3. Watch for `ImportSuccess` state entries to know which freshly-inserted row to scroll to.

**Plan 02-07 (library_screen) unblocked.** It can wire:
1. The Phase 1 "Import your first book" `FilledButton.icon` to `pickAndImportEpubs(ref)` from `import_picker.dart`.
2. Book card taps to `context.go('/reader/${book.id}')` for the top-level full-screen reader stub (body lands in Phase 3).

**Plan 02-08 (persistence test + 15-EPUB corpus) unblocked.** It can:
1. Drive `importFromPaths` against a corpus directory (reuse `parseEpubInIsolate` with real fixture or corpus files).
2. Assert that deleting a book via `db.delete(db.books)` cascades to chapters (the PRAGMA from Plan 02-03 already enables this; Plan 02-05's cleanup-rollback on insert failure also respects the cascade).

**Phase 3 (reader)** inherits a `/reader/:bookId` route, a Block-IR-persisted `chapters` table, and a single reliable path from file-picker or Share → Drift rows. The reader just needs to load `chapters` rows by `bookId` and decode `blocksJson`.

No blockers.

## Self-Check: PASSED

Verified files exist:
- `lib/features/library/import_service.dart` — FOUND
- `lib/features/library/import_service.g.dart` — FOUND
- `lib/features/library/import_picker.dart` — FOUND
- `lib/features/library/share_intent_listener.dart` — FOUND
- `lib/features/library/share_intent_listener.g.dart` — FOUND

Verified commits exist in `git log`:
- `0cd717a` (Task 1) — FOUND
- `7406a8c` (Task 2 RED) — FOUND
- `8526d43` (Task 2 GREEN) — FOUND
- `09175e2` (Task 3 RED) — FOUND
- `6d7a3c5` (Task 3 GREEN) — FOUND

Verified test + analyze baseline:
- `flutter test` — **86 pass / 8 skipped / 0 fail** (+12 vs baseline 74/11)
- `flutter analyze` — 1 pre-existing warning, 0 new issues

Verified grep contracts:
- `application/epub+zip` appears 3 times in AndroidManifest.xml (VIEW, SEND, SEND_MULTIPLE)
- `org.idpf.epub-container` appears in ios/Runner/Info.plist (pre-existing, Phase 1 FND-07)
- `/reader/:bookId` appears as a top-level GoRoute in `lib/app/router.dart` outside the StatefulShellRoute
- No `android.permission.INTERNET` added to the manifest (privacy constraint preserved)

---

*Phase: 02-library-epub-import*
*Plan: 05*
*Completed: 2026-04-11*
