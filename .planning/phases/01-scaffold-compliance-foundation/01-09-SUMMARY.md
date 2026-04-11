---
phase: 01-scaffold-compliance-foundation
plan: "09"
subsystem: ci-and-docs
tags: [ci, github-actions, android, ios, readme, bundletool, workflow_dispatch]
dependency_graph:
  requires:
    - 01-03 (debug keystore + verify_android_manifest.sh)
    - 01-04 (verify_ios_plist.sh)
    - 01-08 (app shell — what CI builds)
  provides:
    - .github/workflows/ci.yml with android (push) + ios-scaffold (workflow_dispatch) jobs
    - README.md Physical Device Install section with bundletool commands
    - README.md Project Structure section documenting Phase 1 layout
  affects:
    - Phase 1 completion: CI green on main proves scaffold is reproducible on clean machines
    - Phase 4: ios-scaffold workflow_dispatch job proves unsigned .xcarchive compiles on macos-14
tech_stack:
  added:
    - GitHub Actions (subosito/flutter-action@v2, actions/setup-java@v4, actions/upload-artifact@v4)
  patterns:
    - ios-scaffold guarded by `if: github.event_name == 'workflow_dispatch'` to avoid burning macOS runner minutes on every push
    - android job runs on every push + PR (FND-09 requirement)
    - Committed debug.keystore used directly in CI — no secrets needed for debug builds
    - verify scripts called as build gates before analyze/test/build
key_files:
  created:
    - .github/workflows/ci.yml
  modified:
    - README.md
decisions:
  - "ios-scaffold job uses workflow_dispatch-only guard per D-06 — saves ~$0.08/min macOS runner cost on every push"
  - "android job triggers on both push and pull_request (not push-only) — matches FND-09 intent and catches regressions on PRs"
  - "build_runner step included in both jobs: redundant when .g.dart are committed but catches stale generated files"
metrics:
  duration: "~3 minutes"
  completed: "2026-04-11"
  tasks_completed: 2
  files_created: 1
  files_modified: 1
---

# Phase 1 Plan 09: GitHub Actions CI + README — Summary

**One-liner:** GitHub Actions CI workflow with android job (ubuntu-latest, push+PR, signed debug AAB) and ios-scaffold job (macos-14, workflow_dispatch-only, unsigned xcarchive), plus README filled in with bundletool physical-device install commands and full Phase 1 project structure tree.

## What Was Built

### Task 1: .github/workflows/ci.yml

Created `.github/workflows/ci.yml` with two jobs:

**android job (ubuntu-latest):**
- Triggers: push to main, pull_request to main, workflow_dispatch
- Steps: checkout → JDK 17 (temurin) → Flutter 3.41.0 → pub get → build_runner → `bash scripts/verify_android_manifest.sh` → flutter analyze → flutter test → `flutter build appbundle --debug` → upload `murmur-debug.aab` (14-day retention, error-if-missing)

**ios-scaffold job (macos-14):**
- Triggers: workflow_dispatch ONLY (`if: github.event_name == 'workflow_dispatch'`)
- Steps: checkout → Flutter 3.41.0 → pub get → build_runner → `bash scripts/verify_ios_plist.sh` → flutter analyze → flutter test → pod install → `flutter build ios --no-codesign --release` → xcodebuild archive (CODE_SIGN_IDENTITY="") → upload `murmur-unsigned.xcarchive` (14-day retention)

YAML validated via `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` — exits 0.

**Commit:** `0931c08`

### Task 2: README.md

Replaced Plan 01 stub README with full Phase 1 README including:

- **Bootstrap section:** preserved from Plan 01 stub, expanded with toolchain install steps
- **Running locally section:** flutter pub get, build_runner, flutter run, flutter test, flutter build appbundle
- **Physical Device Install (Android):** bundletool download (one-time), `build-apks` with `--mode=universal` + keystore args, `install-apks` on connected device; note about `flutter run --debug` as the simpler dev-loop path
- **iOS (Phase 1 status):** explains D-05/D-06 — no installable iOS build in Phase 1, unsigned xcarchive from workflow_dispatch proves compilation only, full iOS signing deferred to Phase 4
- **Continuous Integration:** describes both CI jobs (triggers, runners, artifacts)
- **Project Structure:** full annotated directory tree of Phase 1 layout (lib/, test/, assets/, drift_schemas/, scripts/, .github/workflows/, android/keys/, ios/Runner/)
- **Privacy section:** one-network-call policy, local crash log
- **License:** OFL for fonts, app license TBD

**Commit:** `90b001e`

## Deviations from Plan

None — plan executed exactly as written. Both tasks followed the plan's exact content with no issues encountered.

## Known Stubs

None. All files written are production-ready configuration. The README does document Phase 1 iOS limitation (no signed build) but this is intentional and accurate — not a stub.

## Note on First CI Run

This plan was executed locally and pushed via git. The first actual CI run will occur when the commits reach GitHub (`git push`). Expected outcome:

- **android job:** should go green assuming the committed scaffold (Plans 01-08) is complete and `flutter test` passes
- **ios-scaffold job:** will NOT run on push (workflow_dispatch-only); must be triggered manually via GitHub Actions UI "Run workflow" button
- **Known risk:** `pod install` in the ios-scaffold job may fail if `ios/Podfile.lock` is missing or out-of-sync — this is expected for Phase 1 without Mac access. The unsigned xcarchive is a Phase 1 best-effort deliverable; the android job is the primary CI gate.

## Threat Flags

None. T-01-06 (CI artifact cross-fork access) and T-01-01 (debug keystore in CI) were pre-mitigated in the threat model — no new surface introduced by this plan.

## Self-Check

**Files exist:**
- `.github/workflows/ci.yml` FOUND
- `README.md` FOUND
- `.planning/phases/01-scaffold-compliance-foundation/01-09-SUMMARY.md` FOUND

**Commits exist:**
- `0931c08` feat(01-09): add GitHub Actions CI workflow with android + ios-scaffold jobs FOUND
- `90b001e` docs(01-09): fill in README Physical Device Install + Project Structure sections FOUND

## Self-Check: PASSED
