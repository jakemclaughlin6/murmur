---
phase: 01-scaffold-compliance-foundation
plan: 04
subsystem: ios-compliance
tags: [ios, plist, podfile, pbxproj, compliance, fnd-07, background-audio, epub-uti, export-compliance]
dependency_graph:
  requires:
    - 01-01 (Flutter scaffold — ios/Runner.xcodeproj/project.pbxproj exists)
    - 01-02 (Dependencies — no direct dependency but parallel with 01-03)
  provides:
    - ios/Runner/Info.plist with all FND-07 compliance keys
    - ios/Podfile with iOS 17.0 platform pin and post_install safety net
    - ios/Runner.xcodeproj/project.pbxproj with IPHONEOS_DEPLOYMENT_TARGET = 17.0 in all 3 configs
    - scripts/verify_ios_plist.sh — Linux-compatible shell assertion for all FND-07 keys
  affects:
    - Phase 4: UIBackgroundModes=audio already declared; audio_service will work on first install
    - Phase 2: UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace enable EPUB share/open-in flow
    - Phase 7: ITSAppUsesNonExemptEncryption=false unblocks App Store export compliance dialog
    - Plan 09 (CI): ios-scaffold job can call verify_ios_plist.sh on macos-14 runner
tech_stack:
  added: []
  patterns:
    - Linux-compatible shell assertion using grep only (no plutil) for Info.plist validation
    - iOS 17.0 deployment target set in all 3 authoritative locations (pbxproj × 3, Podfile platform, Podfile post_install)
    - UIApplicationSceneManifest preserved from Flutter 3.41 scaffold (scene lifecycle)
key_files:
  created:
    - ios/Podfile (iOS 17.0 platform pin with post_install safety net)
    - scripts/verify_ios_plist.sh (Linux-compatible FND-07 key assertion)
  modified:
    - ios/Runner/Info.plist (added all FND-07 compliance keys; UIApplicationSceneManifest preserved)
    - ios/Runner.xcodeproj/project.pbxproj (IPHONEOS_DEPLOYMENT_TARGET 13.0 → 17.0 in all 3 configs)
decisions:
  - "Flutter 3.41 default IPHONEOS_DEPLOYMENT_TARGET = 13.0 (answers research Open Question 4)"
  - "No pre-existing Podfile — Flutter 3.41 does not generate one until first iOS build; written from scratch"
  - "UIApplicationSceneManifest block preserved from flutter create output — plan template omitted it but Flutter 3.41 SceneDelegate.swift requires it"
  - "CFBundleIdentifier remains PRODUCT_BUNDLE_IDENTIFIER variable (not hard-coded)"
metrics:
  duration: "~10 minutes"
  completed: 2026-04-11
  tasks_completed: 3
  files_created: 2
  files_modified: 2
---

# Phase 1 Plan 04: iOS Compliance Configuration — Summary

**One-liner:** Info.plist declares all FND-07 compliance keys (background audio, Files.app sharing, EPUB UTI, no-exempt-crypto export declaration), IPHONEOS_DEPLOYMENT_TARGET patched from 13.0 to 17.0 in all 3 authoritative locations, Linux-compatible verify script passes.

## What Was Built

### Task 1: ios/Runner/Info.plist with all FND-07 keys

Overwrote `ios/Runner/Info.plist` adding all FND-07 compliance keys while preserving all Flutter 3.41 standard keys including `UIApplicationSceneManifest` (required for SceneDelegate; omitted from plan template but present in scaffold).

Keys added:
- `CFBundleDisplayName = Murmur` (D-02)
- `UIBackgroundModes = [audio]` — unblocks Phase 4 `audio_service`
- `UIFileSharingEnabled = true` — unblocks Phase 2 EPUB share/open-in
- `LSSupportsOpeningDocumentsInPlace = true` — unblocks Phase 2 Files.app EPUB import
- `CFBundleDocumentTypes` with `org.idpf.epub-container` — EPUB UTI registration
- `ITSAppUsesNonExemptEncryption = false` — App Store export compliance declaration

`CFBundleIdentifier` remains `$(PRODUCT_BUNDLE_IDENTIFIER)` variable — not hard-coded.

`xmllint --noout ios/Runner/Info.plist` exits 0 (valid XML).

**Commit:** `dd1c7c5`

### Task 2: IPHONEOS_DEPLOYMENT_TARGET = 17.0 in pbxproj + Podfile

**Current default recorded:** Flutter 3.41.0 scaffold sets `IPHONEOS_DEPLOYMENT_TARGET = 13.0` (answers research Open Question 4).

**pbxproj:** sed patched all 3 build configurations (Debug/Release/Profile) from `13.0` to `17.0`. 6 occurrences of `PRODUCT_BUNDLE_IDENTIFIER = dev.jmclaughlin.murmur` verified untouched.

**Podfile:** No pre-existing Podfile — Flutter 3.41 does not generate one until first iOS build. Written from scratch with:
- `platform :ios, '17.0'` (top-level minimum)
- `post_install` block's `IPHONEOS_DEPLOYMENT_TARGET = '17.0'` safety net (forces all transitive pods to the same floor)

**Commit:** `5e91267`

### Task 3: scripts/verify_ios_plist.sh

Created `scripts/verify_ios_plist.sh` with Linux-compatible verification (grep only, no `plutil`):
- Checks: `CFBundleDisplayName`, `CFBundleIdentifier` (variable form), `UIBackgroundModes[audio]`, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`, `CFBundleDocumentTypes`, `org.idpf.epub-container`, `ITSAppUsesNonExemptEncryption`
- Made executable (`chmod +x`)
- Output: `OK: ios/Runner/Info.plist has all Phase 1 FND-07 keys`

**Commit:** `82aae4e`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] UIApplicationSceneManifest block preserved from Flutter 3.41 scaffold**
- **Found during:** Task 1 (reviewing current Info.plist before overwrite)
- **Issue:** The plan's "EXACTLY the following" template omitted `UIApplicationSceneManifest` — but Flutter 3.41 scaffold generates a `SceneDelegate.swift` that requires this manifest block to launch correctly. Removing it would break iOS app startup.
- **Fix:** Added `UIApplicationSceneManifest` dict block (with `UIApplicationSupportsMultipleScenes=false`, `UISceneConfigurations`, etc.) from the current scaffold plist, placed before the FND-07 comment block.
- **Files modified:** `ios/Runner/Info.plist`
- **Commit:** `dd1c7c5`

**2. [Rule 3 - Blocking] No pre-existing Podfile to record current platform target**
- **Found during:** Task 2 Step 1 (grep on Podfile returned "file does not exist")
- **Issue:** Plan called for reading the current Podfile platform line before overwriting. Flutter 3.41 does not generate a Podfile until the first iOS build — so there was nothing to read.
- **Fix:** Skipped Step 1's Podfile grep (no file to read); wrote Podfile from scratch per Step 3. Recorded "no pre-existing Podfile" as the answer to research Open Question 4's Podfile sub-question.
- **Files modified:** None — proceeding directly to write was correct behavior
- **Commit:** `5e91267`

## Known Stubs

None. All files written are production-ready configuration (plist, pbxproj, Podfile, shell script). No UI stubs.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: export-compliance-declaration | `ios/Runner/Info.plist` | `ITSAppUsesNonExemptEncryption = false` is a legally-meaningful App Store Connect statement. T-01-07 mitigated: value is `false` (truthful for Phase 1 — no network calls). Comment in plist explains Phase 4 HTTPS model download is exempt under EAR §740.17(b). Phase 4 MUST re-verify this key before submission. |

## Verification Output

**verify_ios_plist.sh:**
```
OK: ios/Runner/Info.plist has all Phase 1 FND-07 keys
```

**IPHONEOS_DEPLOYMENT_TARGET count (should be 3):**
```
3
```

**Bundle ID count (should be 6):**
```
6
```

**Flutter 3.41 default IPHONEOS_DEPLOYMENT_TARGET:** `13.0` (answers research Open Question 4)

## Self-Check

**Files exist:**
- `ios/Runner/Info.plist` ✓
- `ios/Podfile` ✓
- `ios/Runner.xcodeproj/project.pbxproj` (modified) ✓
- `scripts/verify_ios_plist.sh` ✓
- `.planning/phases/01-scaffold-compliance-foundation/01-04-SUMMARY.md` ✓

**Commits exist:**
- `dd1c7c5` feat(01-04): write ios/Runner/Info.plist with all FND-07 compliance keys ✓
- `5e91267` feat(01-04): set IPHONEOS_DEPLOYMENT_TARGET = 17.0 in pbxproj + Podfile ✓
- `82aae4e` feat(01-04): add Linux-compatible verify_ios_plist.sh shell assertion ✓

## Self-Check: PASSED
