---
phase: 1
slug: scaffold-compliance-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-11
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with Flutter 3.41 SDK; no separate install) |
| **Config file** | None — `test/` directory convention; `analysis_options.yaml` holds lint rules |
| **Quick run command** | `flutter test test/{touched_area}/ -r expanded` |
| **Full suite command** | `flutter test && flutter analyze` |
| **Estimated runtime** | ~30 seconds (full suite, Phase 1 scope) |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze && flutter test test/{touched_area}/` (< 10 s)
- **After every plan wave:** Run `flutter test && flutter analyze` (full suite)
- **Before `/gsd-verify-work`:** Full suite green + `flutter build appbundle --debug` succeeds + CI `android` job green on main + CI `ios-scaffold` job green on manual `workflow_dispatch`
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

> Populated during planning. Each PLAN.md task maps a `<task_id>` to a row here with its `<automated>` command. The orchestrator must ensure no 3 consecutive tasks lack an automated verify.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-XX-XX | XX | N | FND-01 (Android) | — | Correct bundle ID in AAB | build-assert | `flutter build appbundle --debug && unzip -p build/app/outputs/bundle/debug/app-debug.aab BundleConfig.pb \| grep dev.jmclaughlin.murmur` | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-01 (iOS) | — | CFBundleIdentifier + CFBundleDisplayName correct | shell-assert | `bash scripts/verify_ios_plist.sh` | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-02 | — | 3-tab nav works | widget | `flutter test test/widget/navigation_test.dart` | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-03 | — | Riverpod survives rebuild | widget | `flutter test test/widget/provider_scope_test.dart` | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-04 | — | Drift schemaVersion=1, no tables | unit | `flutter test test/db/app_database_test.dart` | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-05 | — | 4 themes build, system default | unit | `flutter test test/theme/app_theme_test.dart` | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-05 (persist) | — | Theme persists via shared_preferences | widget | `flutter test test/widget/theme_persistence_test.dart` | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-06 | — | Literata + Merriweather bundled | unit | `flutter test test/fonts/font_bundle_test.dart` | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-07 | V14 Config (export compliance) | Required Info.plist keys present; no misdeclared encryption flag | shell-assert | `bash scripts/verify_ios_plist.sh` | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-08 | V10 (scoped permissions) | Only required manifest permissions declared; no READ_MEDIA_AUDIO over-ask | shell-assert | `bash scripts/verify_android_manifest.sh` | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-09 (Android) | V10 (debug keystore scoped) | Signed debug AAB built on every push to main | CI-status | GitHub Actions `android` job green; artifact `murmur-debug.aab` uploaded | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-09 (iOS) | — | Unsigned xcarchive built on workflow_dispatch | CI-status | GitHub Actions `ios-scaffold` job green on manual trigger; artifact `murmur-unsigned.xcarchive` uploaded | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-10 (write) | V7 Logging, V12 Files | JSONL written locally only, hardcoded path under appDocumentsDir | unit | `flutter test test/crash/crash_logger_test.dart` (all 7 JSONL fields asserted) | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-10 (rotate) | V12 Files (footprint cap) | 1 MB cap + single `.1` rotation | unit | Same file — write >1 MB, assert `crashes.1.log` exists and `crashes.log` truncated | ❌ W0 | ⬜ pending |
| 01-XX-XX | XX | N | FND-10 (capture) | V7 Logging | FlutterError + PlatformDispatcher + runZonedGuarded all reach logger | widget | Simulate all 3 error paths, assert 3 log entries | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

All validation artifacts for Phase 1 are Wave 0 — nothing exists yet. The planner should scaffold each test file alongside the feature it verifies, not all up front.

- [ ] `test/theme/app_theme_test.dart` — all 4 ThemeData builders (FND-05)
- [ ] `test/theme/theme_persistence_test.dart` — shared_preferences round-trip (FND-05 persist)
- [ ] `test/db/app_database_test.dart` — schemaVersion=1 + empty table set (FND-04)
- [ ] `test/crash/crash_logger_test.dart` — JSONL write + rotation + 7 fields + triple-catch (FND-10)
- [ ] `test/widget/navigation_test.dart` — 3-tab nav + route preservation (FND-02)
- [ ] `test/widget/provider_scope_test.dart` — Riverpod survives widget rebuild (FND-03)
- [ ] `test/fonts/font_bundle_test.dart` — Literata + Merriweather resolve (FND-06)
- [ ] `scripts/verify_ios_plist.sh` — shell assertion for FND-07 keys (Info.plist)
- [ ] `scripts/verify_android_manifest.sh` — shell assertion for FND-08 permissions
- [ ] `.github/workflows/ci.yml` — CI definition for FND-09 (is itself the validation)
- [ ] Delete `test/widget_test.dart` — the `flutter create` default (replaced by the files above)

**Framework install:** none — `flutter_test` ships with the SDK.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| App launches on a physical Android phone with correct name + 3-tab nav | FND-01 / FND-02 (Android) | Physical device presence, real-world install loop | Connect device via USB, run `flutter run --debug`; observe launcher icon labelled **Murmur**, bundle ID `dev.jmclaughlin.murmur`, three-tab bottom nav, tap each tab and see the placeholder content render in the selected theme |
| Theme picker visually renders all 5 options and switching sticks across force-quit | FND-05 | Visual + OS-level lifecycle beyond widget test | On physical device: open Settings → Theme, tap each of System/Light/Sepia/Dark/OLED, force-quit the app, relaunch, confirm selection persisted and chrome colors match |
| Crash log `.log` file exists on device after first launch and its byte count is shown in Settings stub row | FND-10 | Physical filesystem verification; triple-catch reaches real device I/O | Force an error (debug-only dev button or `flutter run --dart-define=MURMUR_FORCE_CRASH=true`); open Settings → "Crash log" row; confirm path shown under `Application Documents Directory/crashes/crashes.log` and byte count > 0 |
| Android CI artifact installs on a physical device | FND-09 (Android) | CI artifact round-trip, not just build success | Download `murmur-debug.aab` from the latest GH Actions run, convert via `bundletool` (commands in README), run `bundletool install-apks`; observe launcher icon + launch |
| iOS xcarchive job passes manual `workflow_dispatch` trigger | FND-09 (iOS) | No signing / no install possible in Phase 1; compile success on macos-14 is the proof | Trigger the `ios-scaffold` workflow manually in GH Actions UI; confirm green run + `murmur-unsigned.xcarchive` artifact present |

*iOS physical-device install is intentionally **not** a Phase 1 requirement per D-05/D-06 — deferred to Phase 4.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags (`flutter test`, not `flutter test --watch`)
- [ ] Feedback latency < 30 s
- [ ] `nyquist_compliant: true` set in frontmatter (after planner populates task rows)

**Approval:** pending
