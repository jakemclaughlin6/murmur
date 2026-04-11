---
phase: 01-scaffold-compliance-foundation
reviewed: 2026-04-11T00:00:00Z
depth: standard
files_reviewed: 37
files_reviewed_list:
  - .mise.toml
  - README.md
  - analysis_options.yaml
  - android/app/build.gradle.kts
  - android/build.gradle.kts
  - android/keys/README.md
  - android/settings.gradle.kts
  - drift_schemas/drift_schema_v1.json
  - ios/Runner/AppDelegate.swift
  - ios/Runner/Info.plist
  - ios/Runner/SceneDelegate.swift
  - ios/RunnerTests/RunnerTests.swift
  - lib/app/app.dart
  - lib/app/router.dart
  - lib/core/crash/crash_logger.dart
  - lib/core/crash/crash_logger_provider.dart
  - lib/core/db/app_database.dart
  - lib/core/db/app_database_provider.dart
  - lib/core/theme/app_theme.dart
  - lib/core/theme/clay_colors.dart
  - lib/core/theme/murmur_theme_mode.dart
  - lib/core/theme/theme_mode_provider.dart
  - lib/features/library/library_screen.dart
  - lib/features/reader/reader_screen.dart
  - lib/features/settings/crash_log_status_tile.dart
  - lib/features/settings/settings_screen.dart
  - lib/features/settings/theme_picker.dart
  - lib/main.dart
  - pubspec.yaml
  - scripts/verify_android_manifest.sh
  - scripts/verify_ios_plist.sh
  - test/crash/crash_logger_test.dart
  - test/db/app_database_test.dart
  - test/fonts/font_bundle_test.dart
  - test/theme/app_theme_test.dart
  - test/theme/theme_persistence_test.dart
  - test/widget/navigation_test.dart
  - test/widget/provider_scope_test.dart
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-04-11
**Depth:** standard
**Files Reviewed:** 37
**Status:** issues_found

## Summary

The Phase 1 scaffold is structurally sound. Architecture decisions are correct — Riverpod with `keepAlive`, Drift with `ref.onDispose`, triple-catch in `main.dart`, JSONL rotation in `CrashLogger`, go_router `StatefulShellRoute.indexedStack`, and all Info.plist FND-07 compliance keys are present. The test suite is well-structured and tests the right things.

One critical bug was found: `drift_dev` is missing from `pubspec.yaml` dev_dependencies, which breaks `build_runner` code generation and prevents the project from compiling at all. Three warnings cover a concurrency hazard in `CrashLogger`, a missing test cleanup, and an unsafe release signing config. Three info items cover minor style inconsistencies.

## Critical Issues

### CR-01: `drift_dev` missing from `pubspec.yaml` — build_runner cannot generate Drift code

**File:** `pubspec.yaml:25`
**Issue:** `lib/core/db/app_database.dart` uses `@DriftDatabase` annotation and `part 'app_database.g.dart'`, which requires `drift_dev` to generate the `_$AppDatabase` mixin and `app_database.g.dart` file. `drift_dev` is absent from `dev_dependencies` entirely. Without it, `dart run build_runner build` will not produce the generated file, and the project will not compile. (The CLAUDE.md tech stack table lists `drift_dev` as a required dev dependency explicitly.)

**Fix:**
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.13
  drift_dev: ^2.32.1          # add this — must match drift: ^2.32.1
  riverpod_generator: ^4.0.3
  riverpod_lint: ^3.0.0
  flutter_lints: ^5.0.0
```

## Warnings

### WR-01: `CrashLogger.logError` has a concurrency hazard — parallel callers can race through `_rotateIfNeeded`

**File:** `lib/core/crash/crash_logger.dart:107-126`
**Issue:** `logError` is `async` and awaits `_rotateIfNeeded()` before writing. If two error handlers fire concurrently (e.g., `FlutterError.onError` and `PlatformDispatcher.onError` both trigger in the same microtask cycle), both callers will pass the size check inside `_rotateIfNeeded` simultaneously. Both will then attempt `_file.rename(rotated.path)` — the second rename will throw a `FileSystemException` because the source file no longer exists after the first rename, causing the crash logger itself to crash while trying to log a crash.

The `main.dart` triple-catch wraps calls in `unawaited(...)`, which means errors from the logger itself go unhandled.

**Fix:** Serialize writes through a lock. The simplest approach is a `_pendingWrite` future chain:

```dart
Future<void> _pendingWrite = Future.value();

Future<void> logError(Object error, StackTrace stack, {String level = 'error'}) async {
  _pendingWrite = _pendingWrite.then((_) => _writeEntry(error, stack, level));
  await _pendingWrite;
}

Future<void> _writeEntry(Object error, StackTrace stack, String level) async {
  // ... existing body of logError moved here
}
```

This chains all writes sequentially without a full mutex dependency.

### WR-02: `test/widget/navigation_test.dart` — temp directory created in `setUpAll` is never deleted

**File:** `test/widget/navigation_test.dart:12-17`
**Issue:** `setUpAll` creates `Directory.systemTemp.createTemp('murmur_nav_test_')` for the `CrashLogger` test initializer. There is no corresponding `tearDownAll` that deletes this directory. On repeated test runs the temp dir accumulates. More importantly, `CrashLogger.resetForTest()` is never called in a `tearDownAll`, so the singleton persists into subsequent test files if the test runner shares a process.

**Fix:**
```dart
late Directory _tempDocs;

setUpAll(() async {
  _tempDocs = await Directory.systemTemp.createTemp('murmur_nav_test_');
  CrashLogger.resetForTest();
  await CrashLogger.initializeForTest(docs: _tempDocs);
  SharedPreferences.setMockInitialValues({});
});

tearDownAll(() async {
  CrashLogger.resetForTest();
  if (_tempDocs.existsSync()) {
    await _tempDocs.delete(recursive: true);
  }
});
```

### WR-03: Release build type silently uses debug keystore with no guard

**File:** `android/app/build.gradle.kts:43-48`
**Issue:** The `release` buildType is assigned `signingConfigs.getByName("debugCommitted")` with a comment noting this is intentional for Phase 1. However there is no compile-time or CI guard that prevents a Play Store upload signed with this key. If `flutter build appbundle --release` is run and uploaded before Phase 7, the app identity is permanently burned for that package name (Google does not allow re-upload with a different cert for the same package ID). The README documents the risk but the build file provides no mechanical protection.

**Fix:** Add a Gradle task that enforces the upload keystore comes from environment variables in any non-debug variant, failing loudly if the env vars are absent. At minimum, rename the `release` signing config to `debugForPhase1` to make the intent explicit and prevent copy-paste into a real release config:

```kotlin
signingConfigs {
    create("debugForPhase1") {  // renamed — Phase 7 replaces with uploadKeystore
        storeFile = file("../keys/debug.keystore")
        storePassword = "murmurdebug"
        keyAlias = "murmurdebug"
        keyPassword = "murmurdebug"
    }
}

buildTypes {
    debug {
        signingConfig = signingConfigs.getByName("debugForPhase1")
    }
    release {
        // TODO(Phase 7 QAL-05): replace with uploadKeystore from env vars.
        // DANGER: uploading this to the Play Store permanently burns the app identity.
        signingConfig = signingConfigs.getByName("debugForPhase1")
    }
}
```

## Info

### IN-01: `analysis_options.yaml` — version constraint in `plugins:` block may not be respected

**File:** `analysis_options.yaml:8-9`
**Issue:** The `plugins:` block under `analyzer:` uses `riverpod_lint: ^3.0.0`. The Dart analysis server plugin API reads plugin names from this block, but does not parse semver constraints — the entry is interpreted as the literal plugin name `riverpod_lint: ^3.0.0` rather than `riverpod_lint` at version `^3.0.0`. The plugin version is resolved from `pubspec.yaml`'s `dev_dependencies`, not from this key. The constraint here is a no-op (and potentially misleading). The correct form is a bare plugin name.

**Fix:**
```yaml
plugins:
  - riverpod_lint
```

### IN-02: `settings_screen.dart` — "Diagnostics" label uses magic font size instead of theme text style

**File:** `lib/features/settings/settings_screen.dart:39`
**Issue:** The "Diagnostics" section header uses `TextStyle(fontSize: 18)` directly, while the "Reader fonts" header two lines above uses `theme.textTheme.titleLarge`. This is inconsistent — theme changes (font size, weight) will apply to "Reader fonts" but not "Diagnostics".

**Fix:**
```dart
Padding(
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
  child: Text(
    'Diagnostics',
    style: theme.textTheme.titleLarge,  // consistent with 'Reader fonts' above
  ),
),
```

### IN-03: `lib/features/library/library_screen.dart` — `debugPrint` in production button handler

**File:** `lib/features/library/library_screen.dart:41`
**Issue:** `debugPrint('Library: Import CTA tapped (no-op in Phase 1)')` is present in the Import button's `onPressed`. `debugPrint` is a no-op in release builds (it compiles out), so this is not a data leak, but the `analysis_options.yaml` has `avoid_print: true` which also flags `debugPrint`. This will produce an analyzer warning that blocks CI if `flutter analyze --fatal-warnings` is used.

**Fix:** Remove the `debugPrint` call entirely or wrap it in a `kDebugMode` guard:
```dart
onPressed: () {
  // Phase 2 wires this to the file_picker import flow.
  if (kDebugMode) {
    debugPrint('Library: Import CTA tapped (no-op in Phase 1)');
  }
},
```
Or simply remove the line since the comment above it is sufficient documentation.

---

_Reviewed: 2026-04-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
