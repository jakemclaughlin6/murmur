---
phase: 01-scaffold-compliance-foundation
fixed_at: 2026-04-11T00:00:00Z
review_path: .planning/phases/01-scaffold-compliance-foundation/01-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-04-11
**Source review:** .planning/phases/01-scaffold-compliance-foundation/01-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 7 (1 Critical, 3 Warning, 3 Info)
- Fixed: 7
- Skipped: 0

## Fixed Issues

### CR-01: `drift_dev` missing from `pubspec.yaml` — build_runner cannot generate Drift code

**Files modified:** `pubspec.yaml`
**Commit:** df60ff0
**Applied fix:** Added `drift_dev: ^2.32.1` to `dev_dependencies` immediately after `build_runner: ^2.4.13`, matching the `drift: ^2.32.1` runtime dependency version as required.

### WR-01: `CrashLogger.logError` has a concurrency hazard — parallel callers can race through `_rotateIfNeeded`

**Files modified:** `lib/core/crash/crash_logger.dart`
**Commit:** 81ff58a
**Applied fix:** Added a `Future<void> _pendingWrite = Future.value()` instance field. Refactored `logError` into a thin wrapper that chains onto `_pendingWrite`, and moved the original body into a new private `_writeEntry` method. All writes are now serialized through the future chain, preventing parallel callers from racing through `_rotateIfNeeded` and hitting the double-rename `FileSystemException`.

### WR-02: `test/widget/navigation_test.dart` — temp directory created in `setUpAll` is never deleted

**Files modified:** `test/widget/navigation_test.dart`
**Commit:** 31f8241
**Applied fix:** Promoted `tempDocs` from a local variable inside `setUpAll` to a file-level `late Directory _tempDocs`. Added a `tearDownAll` that calls `CrashLogger.resetForTest()` to clear the singleton and deletes the temp directory recursively, preventing accumulation across test runs.

### WR-03: Release build type silently uses debug keystore with no guard

**Files modified:** `android/app/build.gradle.kts`
**Commit:** e0226fe
**Applied fix:** Renamed the signing config from `debugCommitted` to `debugForPhase1` in all three locations (create, debug getByName, release getByName). Added a `TODO(Phase 7 QAL-05)` comment and a `DANGER` warning on the release `buildType` making it explicit that uploading this build permanently burns the app identity.

### IN-01: `analysis_options.yaml` — version constraint in `plugins:` block may not be respected

**Files modified:** `analysis_options.yaml`
**Commit:** a6f6e7f
**Applied fix:** Changed `riverpod_lint: ^3.0.0` (key-value form) to `- riverpod_lint` (bare list entry). The Dart analysis server plugin API does not parse semver constraints in the plugins block; version resolution comes from `pubspec.yaml` dev_dependencies.

### IN-02: `settings_screen.dart` — "Diagnostics" label uses magic font size instead of theme text style

**Files modified:** `lib/features/settings/settings_screen.dart`
**Commit:** 53b7b53
**Applied fix:** Replaced `TextStyle(fontSize: 18)` with `theme.textTheme.titleLarge` on the Diagnostics section header, matching the Reader fonts header above it. Removed `const` from the outer `Padding` since the child now references a runtime theme value.

### IN-03: `lib/features/library/library_screen.dart` — `debugPrint` in production button handler

**Files modified:** `lib/features/library/library_screen.dart`
**Commit:** 24297e2
**Applied fix:** Removed the `debugPrint` call entirely. The comment `// Phase 2 wires this to the file_picker import flow.` is sufficient documentation and the line would have triggered `avoid_print: true` in CI with `--fatal-warnings`.

---

_Fixed: 2026-04-11_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
