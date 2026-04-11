---
phase: 01-scaffold-compliance-foundation
plan: 01
subsystem: toolchain-scaffold
tags: [mise, flutter, scaffold, android, ios, bundle-id, gitignore, roadmap, requirements]
dependency_graph:
  requires: []
  provides:
    - Flutter 3.41.0 + Dart 3.11.0 toolchain pinned via mise
    - Flutter project skeleton with correct bundle IDs
    - android/ and ios/ platform directories
    - lib/main.dart (minimal stub, no counter)
    - REQUIREMENTS.md FND-06 + FND-09 amended (D-21, D-06)
    - ROADMAP.md Phase 1 success criteria 1 + 4 amended (D-05, D-06)
  affects:
    - All downstream plans (01-02 through 01-09) assume flutter create scaffold exists
    - Plan 01-03 (Android config) builds on android/app/build.gradle.kts
    - Plan 01-04 (iOS config) builds on ios/Runner.xcodeproj/project.pbxproj
    - Plan 01-05 (Theme + fonts) now targets 2 serif families per FND-06 amendment
    - Plan 01-09 (CI) targets Android AAB push + iOS workflow_dispatch per FND-09 amendment
tech_stack:
  added:
    - Flutter 3.41.0 (mise-managed, channel stable)
    - Dart 3.11.0 (ships with Flutter 3.41)
    - Android SDK 34.0.0 (mise-managed via mise-android-sdk plugin)
    - Java 17 (mise-managed)
  patterns:
    - mise for per-project toolchain isolation (no host pollution)
    - flutter create --org dev.jmclaughlin --project-name murmur --platforms=android,ios
key_files:
  created:
    - .mise.toml (Flutter 3.41.0 + Java 17 + android-sdk pins, tasks.doctor, tasks.setup-android)
    - lib/main.dart (minimal runApp stub — full wiring in Plan 08)
    - pubspec.yaml (flutter create generated)
    - pubspec.lock (dependencies resolved)
    - android/app/build.gradle.kts (applicationId = dev.jmclaughlin.murmur)
    - ios/Runner.xcodeproj/project.pbxproj (PRODUCT_BUNDLE_IDENTIFIER = dev.jmclaughlin.murmur, 6 occurrences)
    - .gitignore (flutter create generated — no *.g.dart or *.keystore patterns)
    - README.md (mise bootstrap path + Physical Device Install + Project Structure placeholders)
    - android/ (full Android platform directory)
    - ios/ (full iOS platform directory)
  modified:
    - .planning/REQUIREMENTS.md (FND-06 amended D-21, FND-09 amended D-06)
    - .planning/ROADMAP.md (Phase 1 success criteria 1 + 4 amended D-05/D-06)
decisions:
  - "flutter create --org dev.jmclaughlin --project-name murmur sets bundle IDs automatically — no hand-edits needed (confirmed: 6 occurrences in iOS, 1 in Android)"
  - "Generated .gitignore has no *.g.dart or *.keystore lines — no removal needed; plan instructions confirmed"
  - "murmur_app_spec.md was untracked before scaffold; added to git tracking in Task 3 commit"
  - "pubspec.lock committed alongside pubspec.yaml (deterministic dep resolution)"
metrics:
  duration: "~4 hours (including human verification checkpoint at Task 2)"
  completed: 2026-04-11
  tasks_completed: 4
  files_created: 70+
  files_modified: 2
---

# Phase 1 Plan 01: Toolchain & Scaffold Gate — Summary

**One-liner:** mise-pinned Flutter 3.41.0 + Dart 3.11.0 toolchain green on CachyOS, Flutter project scaffolded with `dev.jmclaughlin.murmur` bundle IDs on both platforms, counter boilerplate deleted, REQUIREMENTS/ROADMAP amended to match CONTEXT.md decisions D-06 and D-21.

## What Was Built

### Task 1: Commit .mise.toml and install toolchain
Committed `.mise.toml` pinning Flutter 3.41.0, Java 17, and android-sdk to the repo root. Toolchain installed via mise (no host pollution). mise tasks `doctor` and `setup-android` included for convenience. The `MISE_DATA_DIR` template variable was not available at the env-expansion layer — `.mise.toml` was amended (commit `f369f48`) to use `{{ env.HOME }}/.local/share/mise` instead.

**Commit:** `2fc67e2` (initial), `f369f48` (env path fix)

### Task 2: Human verification (checkpoint — approved)
Jake ran `mise exec -- flutter doctor -v` and confirmed:
- `[✓] Flutter (Channel stable, 3.41.0, on CachyOS)`
- `[✓] Android toolchain (Android SDK version 34.0.0)`
- `[✗] Chrome` and `[✗] Linux toolchain` — expected, irrelevant for Android+iOS targets
- `[✓] Connected device (1 available)` — physical Android device detected

Toolchain gate passed. User approved continuation.

### Task 3: Scaffold Flutter project and clean counter boilerplate
Ran `flutter create --org dev.jmclaughlin --project-name murmur --platforms=android,ios .` from the repo root. Flutter 3.41.0 created 75 files without touching `CLAUDE.md`, `murmur_app_spec.md`, or `.planning/`.

**Bundle ID verification:**
- `android/app/build.gradle.kts`: `applicationId = "dev.jmclaughlin.murmur"` ✓
- `ios/Runner.xcodeproj/project.pbxproj`: `dev.jmclaughlin.murmur` appears 6 times (Debug/Release/Profile × 2 each) ✓

**Boilerplate cleanup:**
- `lib/main.dart` replaced with 5-line `runApp` stub (Plan 08 will wire full ProviderScope)
- `test/widget_test.dart` deleted (referenced deleted counter widget)

**`.gitignore` check:** Generated `.gitignore` contains no `*.g.dart` or `*.keystore` patterns — no removals needed per plan instructions.

**`flutter pub get`:** Exits 0 against scaffold `pubspec.yaml`. 4 packages have newer versions but all are minor version mismatches (matcher, meta, test_api, vector_math) — Plan 02 rewrites pubspec.

**Commit:** `fb724f4`

### Task 4: Amend ROADMAP.md and REQUIREMENTS.md per D-06 and D-21
Applied exact text replacements specified in the plan:

**REQUIREMENTS.md:**
- FND-06: `3–4 curated font families` → `2 curated serif families: Literata and Merriweather` (D-21); original wording preserved as audit trail
- FND-09: `CI builds signed debug Android AAB and iOS IPA on every push` → Android-AAB-on-push + `workflow_dispatch`-only iOS xcarchive (D-06); original wording preserved; Phase 4 restore noted

**ROADMAP.md:**
- Success criterion 1: Physical iPhone install → deferred to Phase 4; Phase 1 iOS deliverable is unsigned xcarchive from `workflow_dispatch` CI
- Success criterion 4: iOS IPA on every push → workflow_dispatch xcarchive; full IPA wording restored in Phase 4

**Commit:** `b10e312`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] MISE_DATA_DIR not available as template variable in .mise.toml env block**
- **Found during:** Task 1
- **Issue:** `.mise.toml` env block used `{{ env.MISE_DATA_DIR }}` to construct `ANDROID_HOME` and `ANDROID_SDK_ROOT`, but `MISE_DATA_DIR` is not available as a template variable in the env expansion context (it's a mise internal variable, not an env var at template evaluation time)
- **Fix:** Changed both paths to use `{{ env.HOME }}/.local/share/mise` which resolves correctly on Jake's CachyOS host
- **Files modified:** `.mise.toml`
- **Commit:** `f369f48`

**2. [Rule 2 - Missing tracking] murmur_app_spec.md and pubspec.lock were untracked**
- **Found during:** Task 3 (`git status --short` showed `?? murmur_app_spec.md` and `?? pubspec.lock`)
- **Issue:** `murmur_app_spec.md` was at the repo root before scaffold but not in git. `pubspec.lock` was generated by `flutter pub get` and is needed for deterministic dep resolution.
- **Fix:** Added both to Task 3 commit for proper tracking
- **Files modified:** `murmur_app_spec.md`, `pubspec.lock` (added to tracking)
- **Commit:** `fb724f4`

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `Text('murmur')` placeholder | `lib/main.dart` | Intentional — Plan 08 replaces with ProviderScope + go_router shell. No data flows to UI from this stub. |
| `## Physical Device Install (Android)` section | `README.md` | Intentional — Plan 09 fills this in. |
| `## Project Structure` section | `README.md` | Intentional — Plan 08 fills this in. |

These stubs are intentional per the plan's `<action>` instructions and do not block the plan's goal (toolchain gate + scaffold + doc amendments).

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes were introduced. The mise plugin fetch (`curl https://mise.run | sh`) was a one-time human-executed setup step, not runtime app behavior.

## Self-Check

**Files exist:**
- `.mise.toml` ✓
- `lib/main.dart` ✓
- `pubspec.yaml` ✓
- `android/app/build.gradle.kts` ✓
- `ios/Runner.xcodeproj/project.pbxproj` ✓
- `README.md` ✓
- `.planning/REQUIREMENTS.md` (amended) ✓
- `.planning/ROADMAP.md` (amended) ✓

**Commits exist:**
- `2fc67e2` chore(01-01): commit .mise.toml toolchain pin ✓
- `f369f48` fix: use env.HOME in mise.toml env paths ✓
- `fb724f4` feat(01-01): scaffold Flutter project with correct bundle IDs ✓
- `b10e312` docs(01-01): amend REQUIREMENTS.md and ROADMAP.md per CONTEXT.md D-06 and D-21 ✓

## Self-Check: PASSED
