---
phase: 01-scaffold-compliance-foundation
verified: 2026-04-11T19:30:00Z
status: human_needed
score: 9/10 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Install signed debug AAB on a physical Android phone and confirm the app launches with display name Murmur, bundle ID dev.jmclaughlin.murmur, navigates the 3-tab shell, and the theme picker persists across restarts"
    expected: "App launches, tabs switch correctly, theme persists after force-close and reopen"
    why_human: "Physical device install cannot be verified from CI or code inspection alone; success criterion #1 explicitly requires a physical Android device"
  - test: "Trigger the workflow_dispatch CI job on GitHub and confirm the ios-scaffold job produces an uploadable unsigned .xcarchive artifact"
    expected: "ios-scaffold job completes successfully on macos-14 and uploads murmur-unsigned.xcarchive"
    why_human: "Requires a GitHub Actions run on a macOS runner; cannot be confirmed from code inspection"
---

# Phase 01: Scaffold & Compliance Foundation — Verification Report

**Phase Goal:** Land a compilable, compliant Flutter scaffold — no content, no logic — just the skeleton every subsequent phase builds on. (ROADMAP: "A signed Flutter app that launches on physical iOS and Android devices, navigates between placeholder Library / Reader / Settings routes, and has every compliance key and CI hook the later phases will need.")

**Verified:** 2026-04-11T19:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Signed debug build launches on physical Android phone with bundle ID `dev.jmclaughlin.murmur`, display name `Murmur`, placeholder icon and splash | ? HUMAN NEEDED | `flutter build appbundle --debug` succeeds (✓); applicationId=`dev.jmclaughlin.murmur` in build.gradle.kts (✓); android:label="Murmur" in manifest (✓); physical device install not verified |
| 2 | User can navigate between Library, Reader, and Settings placeholder screens via go_router; hot reload preserves Riverpod state | ✓ VERIFIED | `StatefulShellRoute.indexedStack` with 3 branches wired in `lib/app/router.dart`; `ProviderScope` wraps `runApp` in `lib/main.dart`; 4/4 widget tests pass (navigation_test + provider_scope_test) |
| 3 | User can switch between light, sepia, dark, and OLED-black themes; Settings works; app chrome follows system theme by default | ✓ VERIFIED | 4 `ThemeData` builders in `lib/core/theme/app_theme.dart`; `ThemeModeController` persists via `shared_preferences`; 5-option `RadioGroup` theme picker in `SettingsScreen`; 13 passing unit/widget tests confirm persistence |
| 4 | CI produces signed debug Android AAB on every push to main; iOS CI is `workflow_dispatch`-only producing unsigned `.xcarchive` | ? HUMAN NEEDED | `.github/workflows/ci.yml` is substantive and correctly structured (android job on push+PR, ios-scaffold job guarded by `workflow_dispatch` only); verify scripts pass locally; actual CI run on GitHub not confirmed |
| 5 | Thrown exceptions anywhere in the app are written to an on-device crash log (no network, no third-party SDK) | ✓ VERIFIED | Triple-catch wired in `lib/main.dart` (`FlutterError.onError` + `PlatformDispatcher.instance.onError` + `runZonedGuarded`); `CrashLogger` writes JSONL with all 7 D-07 fields; 1MB rotation verified; 11 passing crash tests |

**Score:** 3/5 truths fully verified, 2/5 require human confirmation (both are physical/CI environment checks, not code defects)

### Per-Requirement Checks (FND-01 through FND-10)

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| FND-01 | App launches with correct bundle ID on signed build | ? HUMAN NEEDED | Bundle ID correct in code; physical device launch not confirmed |
| FND-02 | go_router 3-tab navigation | ✓ VERIFIED | `StatefulShellRoute.indexedStack` wired; 3 navigation tests pass |
| FND-03 | Riverpod ProviderScope at app root, survives hot reload | ✓ VERIFIED | `ProviderScope` outermost widget; `provider_scope_test.dart` passes; `@Riverpod(keepAlive: true)` on router |
| FND-04 | Drift database initializes with schema versioning | ✓ VERIFIED | `AppDatabase` with `schemaVersion=1`, zero tables; `drift_schema_v1.json` dumped; 3 DB tests pass |
| FND-05 | Light, sepia, dark, OLED-black themes defined | ✓ VERIFIED | 4 `buildXxxTheme()` functions in `app_theme.dart`; 8 theme unit tests pass |
| FND-06 (amended) | Literata + Merriweather bundled as TTF (Regular + Bold each) | ✓ VERIFIED | 4 TTF files present in `assets/fonts/`; declared in `pubspec.yaml`; `font_bundle_test.dart` (4 tests) verifies each file loads and is >10KB |
| FND-07 | iOS Info.plist: `UIBackgroundModes: audio`, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`, EPUB `CFBundleDocumentTypes`, `ITSAppUsesNonExemptEncryption=false` | ✓ VERIFIED | All 5 keys present in `ios/Runner/Info.plist`; `scripts/verify_ios_plist.sh` passes |
| FND-08 | Android manifest foreground service permissions | PARTIAL | `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` + `POST_NOTIFICATIONS` declared; `READ_MEDIA_*` intentionally omitted (SAF import path does not require it — documented in manifest); REQUIREMENTS.md wording ("declares READ_MEDIA_*") has not been formally amended like FND-06/FND-09 were |
| FND-09 (amended) | CI: signed debug AAB on push + workflow_dispatch iOS xcarchive | ? HUMAN NEEDED | Workflow YAML correctly structured; actual CI run not confirmed |
| FND-10 | Local-only crash logging to on-device file | ✓ VERIFIED | `CrashLogger` writes JSONL to `${appDocumentsDir}/crashes/crashes.log`; no network; no third-party SDK; 11 unit tests pass |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.mise.toml` | Flutter 3.41 + Java 17 + android-sdk toolchain pin | ✓ VERIFIED | Contains `flutter = "3.41.0"`, `java = "17"`, `android-sdk = "16.0"` |
| `lib/main.dart` | Triple-catch + CrashLogger.initialize + ProviderScope + runApp | ✓ VERIFIED | 47 lines; `runZonedGuarded` wraps all; `FlutterError.onError` + `PlatformDispatcher.instance.onError` wired |
| `lib/app/app.dart` | MurmurApp ConsumerWidget consuming theme provider | ✓ VERIFIED | `MaterialApp.router` wired to `themeModeControllerProvider`; 4-branch theme switch |
| `lib/app/router.dart` | `StatefulShellRoute.indexedStack` 3-branch nav | ✓ VERIFIED | 3 `StatefulShellBranch` entries; `@Riverpod(keepAlive: true)` |
| `lib/core/theme/app_theme.dart` | 4 ThemeData builder functions | ✓ VERIFIED | `buildLightTheme()`, `buildSepiaTheme()`, `buildDarkTheme()`, `buildOledTheme()` all present and substantive |
| `lib/core/theme/theme_mode_provider.dart` | Persistence via shared_preferences | ✓ VERIFIED | `ThemeModeController` with `set()` writing to prefs under `settings.themeMode` |
| `lib/core/crash/crash_logger.dart` | JSONL + 1MB rotation + 7-field schema | ✓ VERIFIED | 162 lines; `maxBytes = 1MB`; `jsonlFields` set with all 7 fields; rotation logic present |
| `lib/core/db/app_database.dart` | Drift v1, zero tables, schemaVersion=1 | ✓ VERIFIED | `@DriftDatabase(tables: [])`, `schemaVersion => 1` |
| `android/app/build.gradle.kts` | applicationId + signing + SDK floors | ✓ VERIFIED | `applicationId = "dev.jmclaughlin.murmur"`; `signingConfigs.debugCommitted`; `minSdk=24, targetSdk=34, compileSdk=36` |
| `android/app/src/main/AndroidManifest.xml` | Foreground service permissions, display name Murmur | ✓ VERIFIED | Required permissions present; `android:label="Murmur"` |
| `ios/Runner/Info.plist` | FND-07 compliance keys | ✓ VERIFIED | All 5 required keys/values confirmed by `verify_ios_plist.sh` |
| `.github/workflows/ci.yml` | Android (push) + iOS (workflow_dispatch) jobs | ✓ VERIFIED | 122 lines; android job on push+PR; ios-scaffold guarded by `workflow_dispatch` check |
| `assets/fonts/literata/Literata-{Regular,Bold}.ttf` | Real TTF files >10KB | ✓ VERIFIED | Files exist; font_bundle_test confirms loadability and size |
| `assets/fonts/merriweather/Merriweather-{Regular,Bold}.ttf` | Real TTF files >10KB | ✓ VERIFIED | Files exist; font_bundle_test confirms loadability and size |
| `drift_schemas/drift_schema_v1.json` | Schema dump with `entities: []` | ✓ VERIFIED | File exists; contains `"entities": []` |
| `android/keys/debug.keystore` | RSA-2048 committed debug keystore | ✓ VERIFIED | File present at `android/keys/debug.keystore` |
| `scripts/verify_android_manifest.sh` | Permission allow-list assertion script | ✓ VERIFIED | Executable; exits 0 on current manifest |
| `scripts/verify_ios_plist.sh` | Info.plist compliance assertion script | ✓ VERIFIED | Executable; exits 0 on current Info.plist |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/main.dart` | `CrashLogger.initialize()` | called before `runApp` | ✓ WIRED | Line 18: `await CrashLogger.initialize()` before `runApp` |
| `lib/main.dart` | `ProviderScope` | outermost widget wrapping `MurmurApp` | ✓ WIRED | Line 35: `runApp(const ProviderScope(child: MurmurApp()))` |
| `lib/main.dart` | triple-catch | `FlutterError.onError` + `PlatformDispatcher.instance.onError` + `runZonedGuarded` | ✓ WIRED | All three catch paths present and call `CrashLogger.instance.logError` |
| `lib/app/app.dart` | `themeModeControllerProvider` | `ref.watch` in ConsumerWidget | ✓ WIRED | `final modeAsync = ref.watch(themeModeControllerProvider)` |
| `lib/app/router.dart` | 3 screen files | imported and wired into `StatefulShellBranch` | ✓ WIRED | Library/Reader/Settings imports at top; each branch routes to correct screen |
| theme_picker → `themeModeControllerProvider` | `.set(mode)` on user tap | `RadioGroup` + `ref.read` | ✓ WIRED (by SUMMARY) | Plan 08 SUMMARY confirms wiring; theme persistence tests (5 passing) confirm the provider writes to SharedPreferences |
| `AppDatabase` | `drift_flutter` | `driftDatabase(name: 'murmur')` | ✓ WIRED | Line 32: `static QueryExecutor _openConnection() => driftDatabase(name: 'murmur')` |

### Data-Flow Trace (Level 4)

Phase 1 placeholder screens render static/hardcoded content by design (Phase 1 goal is "no content, no logic — just the skeleton"). Data flow verification is not applicable for this phase — the Library shows a hardcoded empty state, the Reader shows a hardcoded Middlemarch passage, and Settings renders provider state. The theme persistence flow (user taps → `set()` → SharedPreferences → survives restart) is verified by 5 passing unit tests.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All tests pass | `mise exec -- flutter test` | 33/33 passing | ✓ PASS |
| No analysis issues | `mise exec -- flutter analyze` | "No issues found!" | ✓ PASS |
| Debug AAB compiles | `flutter build appbundle --debug` | "Built build/app/outputs/bundle/debug/app-debug.aab" | ✓ PASS |
| Android manifest allow-list | `bash scripts/verify_android_manifest.sh` | "OK: AndroidManifest.xml matches Phase 1 allow-list" | ✓ PASS |
| iOS Info.plist keys | `bash scripts/verify_ios_plist.sh` | "OK: ios/Runner/Info.plist has all Phase 1 FND-07 keys" | ✓ PASS |
| iOS bundle ID in pbxproj | `grep -c 'PRODUCT_BUNDLE_IDENTIFIER.*dev.jmclaughlin.murmur' ios/Runner.xcodeproj/project.pbxproj` | 6 occurrences (≥3 required) | ✓ PASS |

### Requirements Coverage

| Requirement | Phase | Description | Status | Evidence |
|-------------|-------|-------------|--------|----------|
| FND-01 | 1 | App launches with correct bundle ID | ? HUMAN | Bundle ID verified in code; physical launch pending |
| FND-02 | 1 | go_router 3-tab navigation | ✓ SATISFIED | StatefulShellRoute.indexedStack + 3 nav tests |
| FND-03 | 1 | Riverpod ProviderScope at root | ✓ SATISFIED | ProviderScope outermost widget; provider_scope_test |
| FND-04 | 1 | Drift DB schema versioning | ✓ SATISFIED | schemaVersion=1; schema dump; 3 DB tests |
| FND-05 | 1 | 4 reader themes defined | ✓ SATISFIED | 4 ThemeData builders; 8 theme tests |
| FND-06 | 1 | Literata + Merriweather bundled | ✓ SATISFIED | 4 TTF files; pubspec declares them; 4 font tests |
| FND-07 | 1 | iOS Info.plist compliance keys | ✓ SATISFIED | All 5 keys present; verify script passes |
| FND-08 | 1 | Android manifest permissions | PARTIAL | FOREGROUND_SERVICE + POST_NOTIFICATIONS present; READ_MEDIA_* intentionally omitted (SAF path); REQUIREMENTS.md wording not amended |
| FND-09 | 1 | CI: Android push + iOS dispatch | ? HUMAN | Workflow YAML correct; actual CI run not confirmed |
| FND-10 | 1 | Local crash logging | ✓ SATISFIED | CrashLogger with JSONL; no network; 11 unit tests |

### Anti-Patterns Found

| File | Pattern | Severity | Assessment |
|------|---------|----------|------------|
| `lib/features/library/library_screen.dart` | `debugPrint` no-op CTA handler | ℹ️ Info | Intentional Phase 1 placeholder per D-12; Phase 2 wires file_picker |
| `lib/features/reader/reader_screen.dart` | Hardcoded Middlemarch text | ℹ️ Info | Intentional Phase 1 placeholder per D-12; Phase 3 replaces with sentence-span EPUB rendering |
| `lib/app/router.dart` | Reader route at `/reader` (no `:bookId` param) | ℹ️ Info | Phase 1 design — reader is a placeholder screen; Phase 2/3 will add book ID routing |

No blockers. All "stubs" are intentional scaffolding with documented handoffs.

### FND-08 Deviation Note

REQUIREMENTS.md FND-08 says the manifest "declares `FOREGROUND_SERVICE_MEDIA_PLAYBACK` and `READ_MEDIA_*` permissions appropriate to the target SDK." The manifest intentionally omits `READ_MEDIA_*` because murmur imports EPUBs via the Storage Access Framework (SAF / `ACTION_OPEN_DOCUMENT`), not via MediaStore — declaring `READ_MEDIA_*` would be a false permission over-request. This is the correct technical decision and is documented in the manifest itself (`01-RESEARCH.md §Example 4`).

However, unlike FND-06 and FND-09, FND-08 was not formally amended in REQUIREMENTS.md to reflect this decision. This is a documentation gap, not a code defect.

**Suggestion:** Amend FND-08 in REQUIREMENTS.md to: "Android manifest declares `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, and `POST_NOTIFICATIONS` permissions; `READ_MEDIA_*` is intentionally omitted because EPUBs are imported via SAF (ACTION_OPEN_DOCUMENT), not MediaStore."

### Human Verification Required

#### 1. Physical Android Device Launch

**Test:** Build the signed debug AAB (`flutter build appbundle --debug`), install on a physical Android phone via bundletool or direct APK, and verify:
- App icon appears on home screen
- Display name shows "Murmur" (not "murmur" or the package name)
- App launches without crash
- Bottom navigation shows Library / Reader / Settings tabs
- Tapping each tab switches the content area
- In Settings, tapping a theme option changes the app chrome immediately
- Force-close and reopen — selected theme persists

**Expected:** All of the above work correctly on a physical mid-range Android device.
**Why human:** Success criterion #1 requires a physical device install. `flutter build appbundle --debug` is verified (✓) but that is not a substitute for an actual device install.

#### 2. GitHub Actions CI Run

**Test:** Push a commit to the `main` branch and verify:
- The `android` job completes successfully
- `murmur-debug.aab` is available as a downloadable workflow artifact (14-day retention)
- Trigger the `ios-scaffold` job via `workflow_dispatch` from the Actions tab
- The `ios-scaffold` job completes successfully on `macos-14`
- `murmur-unsigned.xcarchive` is available as a downloadable workflow artifact

**Expected:** Both jobs green; both artifacts downloadable.
**Why human:** CI requires pushing to GitHub and reviewing the Actions tab; cannot be confirmed from local code inspection.

---

## Overall Assessment

Phase 01 has delivered a substantively complete, well-tested Flutter scaffold. The code is not a placeholder — every required file is real, wired, and tested:

- 33/33 automated tests pass
- `flutter analyze` reports no issues
- `flutter build appbundle --debug` succeeds
- All compliance scripts pass
- The triple-catch crash logger, theme system, Drift database, font bundle, routing, and CI workflow are all present and functional

The two human verification items are environment checks (physical device + CI run), not code defects. The FND-08 documentation gap is minor (the code is correct; only the REQUIREMENTS.md wording needs updating).

**Recommendation: Phase 01 is ready to proceed to Phase 02** once the physical Android device install is confirmed. The CI run can be confirmed as part of the first push after Phase 02 work begins.

---

_Verified: 2026-04-11T19:30:00Z_
_Verifier: Claude (gsd-verifier)_
