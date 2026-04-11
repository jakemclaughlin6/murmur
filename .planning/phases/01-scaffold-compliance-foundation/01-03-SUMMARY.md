---
phase: 01-scaffold-compliance-foundation
plan: 03
subsystem: android-compliance
tags: [android, manifest, signing, keystore, gradle, permissions, sdk-floors, ci]
dependency_graph:
  requires:
    - 01-01 (Flutter scaffold — android/app/build.gradle.kts exists)
    - 01-02 (Dependencies — pubspec.yaml declares font assets)
  provides:
    - Debug keystore committed at android/keys/debug.keystore (alias murmurdebug)
    - android/app/build.gradle.kts with applicationId, SDK floors, signing config
    - AndroidManifest.xml with Phase 4-ready foreground service permissions
    - scripts/verify_android_manifest.sh — shell assertion for permission allow-list
    - Signed debug AAB build verified: build/app/outputs/bundle/debug/app-debug.aab
  affects:
    - Plan 01-09 (CI): can now run flutter build appbundle --debug with signing
    - Plan 01-04 (iOS config): no dependency, parallel
    - Phase 4: FND-08 permissions already declared; audio_service service stanza deferred
    - Phase 7: android/keys/README.md provides rotation instructions for QAL-05
tech_stack:
  added: []
  patterns:
    - Committed debug keystore (force-tracked via git add -f) for zero-secrets CI
    - signingConfigs.debugCommitted wired to both debug + release buildTypes
    - verify_android_manifest.sh as executable shell assertion (exit 0 / non-zero)
    - compileSdk bumped to 36 to satisfy package_info_plus + shared_preferences_android plugin requirements
key_files:
  created:
    - android/keys/debug.keystore (RSA 2048, alias murmurdebug, validity 10000 days)
    - android/keys/README.md (DEBUG-ONLY warning + Phase 7 rotation guidance)
    - scripts/verify_android_manifest.sh (permission allow-list assertion)
    - assets/fonts/literata/Literata-Regular.ttf (stub — Plan 05 replaces)
    - assets/fonts/literata/Literata-Bold.ttf (stub — Plan 05 replaces)
    - assets/fonts/merriweather/Merriweather-Regular.ttf (stub — Plan 05 replaces)
    - assets/fonts/merriweather/Merriweather-Bold.ttf (stub — Plan 05 replaces)
  modified:
    - android/app/build.gradle.kts (SDK floors, signing config, compileSdk=36)
    - android/app/src/main/AndroidManifest.xml (permissions, label, cleaned up)
    - android/.gitignore (exception comment for force-tracked debug keystore)
decisions:
  - "compileSdk bumped to 36: package_info_plus 10.x and shared_preferences_android require compileSdk >= 36; plan specified 34 but installed packages demand 36 (packages updated since plan was written)"
  - "android/.gitignore has **/*.keystore glob — used git add -f to force-track debug keystore; negation pattern !keys/debug.keystore does not work against ** wildcards in git"
  - "queries block (ACTION_PROCESS_TEXT) removed from manifest — flutter create generated it for text-processing plugins but it is not needed for Phase 1's minimal app; build confirms no regression"
  - "stub .ttf font files created — pubspec.yaml declared them (Plan 02) but files were absent; Plan 05 replaces with real font binaries; stubs unblock the AAB build"
metrics:
  duration: "~6 minutes (excluding Gradle first-run downloads)"
  completed: 2026-04-11
  tasks_completed: 3
  files_created: 9
  files_modified: 3
---

# Phase 1 Plan 03: Android Compliance Configuration — Summary

**One-liner:** Committed RSA-2048 debug keystore wired into build.gradle.kts with SDK floors (minSdk=24, targetSdk=34, compileSdk=36), AndroidManifest.xml declares exactly FOREGROUND_SERVICE + FOREGROUND_SERVICE_MEDIA_PLAYBACK + POST_NOTIFICATIONS and nothing else, verify script confirms the allow-list, signed debug AAB builds at 75MB.

## What Was Built

### Task 1: Debug keystore + android/keys/README.md

Generated a reproducible RSA-2048 debug keystore using mise-managed keytool (Java 17):

- **Path:** `android/keys/debug.keystore`
- **Alias:** `murmurdebug`
- **Password (store + key):** `murmurdebug`
- **DN:** `CN=Jake McLaughlin, O=Murmur, C=US`
- **Validity:** 10,000 days
- **Keystore type:** PKCS12
- **SHA-256 fingerprint:** `1D:0F:1A:F1:1F:63:37:9E:51:45:75:47:4A:18:17:CF:7D:1D:58:E8:B5:BB:2E:76:5D:3B:13:3D:37:7B:A8:DA`

`android/keys/README.md` written with exact DEBUG-ONLY warning and Phase 7 rotation guidance.

`android/.gitignore` was amended with an exception comment — the `**/*.keystore` glob in the Flutter-generated Android gitignore blocked tracking; `git add -f` was used to force-track the one intentionally-committed debug keystore.

**Commit:** `250c569`

### Task 2: android/app/build.gradle.kts with SDK floors + signing

Overwrote `android/app/build.gradle.kts` with:

- `namespace = "dev.jmclaughlin.murmur"`
- `compileSdk = 36` (bumped from plan's 34 — see deviations)
- `minSdk = 24` (D-24)
- `targetSdk = 34` (D-25)
- `signingConfigs.debugCommitted` pointing at `../keys/debug.keystore`
- Both `debug` and `release` buildTypes wired to `debugCommitted`

`mise exec -- flutter build appbundle --debug` exits 0. Produced:
- **Path:** `build/app/outputs/bundle/debug/app-debug.aab`
- **Size:** 75MB

**Commit:** `5cae342`

### Task 3: AndroidManifest.xml + verify script

Overwrote `android/app/src/main/AndroidManifest.xml` with:

- `android:label="Murmur"` (D-02)
- `FOREGROUND_SERVICE` permission
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission
- `POST_NOTIFICATIONS` permission
- No INTERNET, READ_MEDIA_AUDIO, READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE
- No `audio_service` service stanza (deferred to Phase 4)
- Dropped `android:taskAffinity=""` and `<queries>` block from flutter create template (both benign removals — build confirmed)

`scripts/verify_android_manifest.sh` written and made executable. Output:
```
OK: AndroidManifest.xml matches Phase 1 allow-list
```

Final `flutter build appbundle --debug` after manifest changes: exits 0 in 7s (cached).

**Commit:** `772550e`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] compileSdk bumped from 34 to 36**
- **Found during:** Task 2 (first build attempt)
- **Issue:** `package_info_plus 10.x`, `shared_preferences_android`, `jni`, and `jni_flutter` all require `compileSdk >= 35` or `>= 36`. With `compileSdk = 34`, Gradle failed: `"Your project is configured to compile against Android SDK 34, but the following plugin(s) require to be compiled against a higher Android SDK version."`
- **Fix:** Set `compileSdk = 36` (the highest required). These packages were updated after the plan was written (CONTEXT.md D-25 specified SDK 34 but current published packages require 36).
- **Files modified:** `android/app/build.gradle.kts`
- **Commit:** `5cae342`

**2. [Rule 3 - Blocking] android/.gitignore **/*.keystore glob blocked keystore tracking**
- **Found during:** Task 1 (git add)
- **Issue:** Flutter's generated `android/.gitignore` contains `**/*.keystore`, which blocked `git add android/keys/debug.keystore`. The plan's acceptance criteria require the keystore to be tracked (D-04).
- **Fix:** Added exception comment to `android/.gitignore` documenting the intent, then used `git add -f` to force-track only `android/keys/debug.keystore`. A git negation pattern (`!keys/debug.keystore`) was tried first but does not work against `**` wildcards — `git add -f` is the correct approach.
- **Files modified:** `android/.gitignore`
- **Commit:** `250c569`

**3. [Rule 3 - Blocking] Stub .ttf font files created to unblock build**
- **Found during:** Task 2 (first build attempt)
- **Issue:** `pubspec.yaml` (committed in Plan 02) declares 4 font files under `assets/fonts/` but they were absent. Flutter's asset bundler failed: `"unable to locate asset entry in pubspec.yaml: assets/fonts/literata/Literata-Regular.ttf"`.
- **Fix:** Created 4 empty stub `.ttf` files. Plan 05 (fonts) replaces these with real font binaries. The stubs are zero-byte files that satisfy Flutter's asset bundler existence check.
- **Files created:** 4 stub `.ttf` files in `assets/fonts/literata/` and `assets/fonts/merriweather/`
- **Commit:** `5cae342`

**4. [Rule 1 - Bug] Removed flutter create <queries> block from manifest**
- **Found during:** Task 3 (reviewing current manifest before overwrite)
- **Issue:** The flutter-generated manifest included a `<queries>` block for `ACTION_PROCESS_TEXT` (text processing intent). The plan's exact manifest template does not include it.
- **Fix:** Followed plan's exact template (omits the `<queries>` block). Build confirmed no regression — the queries block is only relevant for apps that delegate text selection to external processors, which murmur does not do.
- **Files modified:** `android/app/src/main/AndroidManifest.xml`
- **Commit:** `772550e`

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| Empty .ttf stub | `assets/fonts/literata/Literata-Regular.ttf` | Plan 05 replaces with real Literata font |
| Empty .ttf stub | `assets/fonts/literata/Literata-Bold.ttf` | Plan 05 replaces with real Literata font |
| Empty .ttf stub | `assets/fonts/merriweather/Merriweather-Regular.ttf` | Plan 05 replaces with real Merriweather font |
| Empty .ttf stub | `assets/fonts/merriweather/Merriweather-Bold.ttf` | Plan 05 replaces with real Merriweather font |

These stubs do not block this plan's goal (signed debug AAB). They will produce a runtime font-loading error if any screen actually tries to render text in Literata or Merriweather — but Phase 1's placeholder screens (Plan 08) use real font files from Plan 05, which arrives first. No data flows to UI from these stubs.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: credential-in-source | `android/app/build.gradle.kts` | `storePassword = "murmurdebug"` and `keyPassword = "murmurdebug"` in plaintext. Accepted (T-01-05): keystore is DEBUG-ONLY, password is documented in README, not a security boundary. Phase 7 moves to GitHub Secrets env vars. |

## Verification Output

**Keystore:**
```
Keystore type: PKCS12 | 1 entry
murmurdebug, Apr. 11, 2026, PrivateKeyEntry
SHA-256: 1D:0F:1A:F1:1F:63:37:9E:51:45:75:47:4A:18:17:CF:7D:1D:58:E8:B5:BB:2E:76:5D:3B:13:3D:37:7B:A8:DA
```

**verify_android_manifest.sh:**
```
OK: AndroidManifest.xml matches Phase 1 allow-list
```

**AAB:**
```
build/app/outputs/bundle/debug/app-debug.aab — 75MB
```

## Self-Check

**Files exist:**
- `android/keys/debug.keystore` FOUND
- `android/keys/README.md` FOUND
- `android/app/build.gradle.kts` FOUND
- `android/app/src/main/AndroidManifest.xml` FOUND
- `scripts/verify_android_manifest.sh` FOUND
- `build/app/outputs/bundle/debug/app-debug.aab` FOUND
- `.planning/phases/01-scaffold-compliance-foundation/01-03-SUMMARY.md` FOUND

**Commits exist:**
- `250c569` feat(01-03): generate debug keystore and write android/keys/README.md FOUND
- `5cae342` feat(01-03): configure android/app/build.gradle.kts with SDK floors + signing FOUND
- `772550e` feat(01-03): write AndroidManifest.xml permissions + label + verify script FOUND

## Self-Check: PASSED
