---
phase: 1
slug: scaffold-compliance-foundation
status: planned
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-11
updated: 2026-04-11
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with Flutter 3.41 SDK; no separate install) |
| **Config file** | None — `test/` directory convention; `analysis_options.yaml` holds lint rules |
| **Quick run command** | `mise exec -- flutter test test/{touched_area}/ -r expanded` |
| **Full suite command** | `mise exec -- flutter test && mise exec -- flutter analyze` |
| **Estimated runtime** | ~30 seconds (full suite, Phase 1 scope) |

---

## Sampling Rate

- **After every task commit:** `mise exec -- flutter analyze && mise exec -- flutter test test/{touched_area}/` (< 10 s)
- **After every plan wave:** `mise exec -- flutter test && mise exec -- flutter analyze` (full suite)
- **Before `/gsd-verify-work`:** Full suite green + `mise exec -- flutter build appbundle --debug` succeeds + CI `android` job green on main + CI `ios-scaffold` job green on manual `workflow_dispatch`
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

> Populated during planning. Each row maps a `<task_id>` (plan-task) to the `<automated>` command the task declares, the requirement it covers, and any STRIDE threat reference.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | FND-01 (toolchain gate) | T-01-03 | mise pinned, no host pollution | shell-assert | `mise exec -- flutter doctor \| grep -qE "\\[✓\\] Android toolchain"` | ✅ | ⬜ pending |
| 01-01-02 | 01 | 1 | FND-01 (human verify) | — | Jake confirms mise doctor green | checkpoint:human-verify | manual `mise exec -- flutter doctor -v` review | ✅ | ⬜ pending |
| 01-01-03 | 01 | 1 | FND-01 (scaffold) | T-01-04 | .gitignore clean for .g.dart + .keystore | shell-assert | `grep -q 'dev.jmclaughlin.murmur' android/app/build.gradle.kts && mise exec -- flutter pub get` | ✅ | ⬜ pending |
| 01-01-04 | 01 | 1 | FND-06/FND-09 (amendments) | — | Roadmap-vs-CONTEXT discrepancy resolved | shell-assert | `grep -q 'FND-06.*amended per Phase 1 D-21' .planning/REQUIREMENTS.md && grep -q 'FND-09.*amended per Phase 1 D-06' .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |
| 01-02-01 | 02 | 2 | (infra — pubspec) | T-01-03 | Exact dep pins; fonts declared | shell-assert | `mise exec -- flutter pub get` + pubspec grep allow/deny list | ✅ W0 | ⬜ pending |
| 01-02-02 | 02 | 2 | (infra — analysis + codegen) | — | flutter_lints + custom_lint wired | shell-assert | `mise exec -- dart run build_runner build --delete-conflicting-outputs && mise exec -- flutter analyze` | ✅ W0 | ⬜ pending |
| 01-03-01 | 03 | 3 | FND-01 (Android signing) | T-01-01, T-01-05 | Deterministic committed debug keystore | shell-assert | `mise exec -- keytool -list -keystore android/keys/debug.keystore -storepass murmurdebug \| grep -q 'PrivateKeyEntry'` | ✅ W0 | ⬜ pending |
| 01-03-02 | 03 | 3 | FND-01 (Android build) | — | Correct SDK floors + bundle ID | build-assert | `mise exec -- flutter build appbundle --debug && test -f build/app/outputs/bundle/debug/app-debug.aab` | ✅ W0 | ⬜ pending |
| 01-03-03 | 03 | 3 | FND-08 | T-01-04 (V10 least privilege) | Exact manifest allow-list, no READ_MEDIA_AUDIO | shell-assert | `bash scripts/verify_android_manifest.sh` | ✅ W0 | ⬜ pending |
| 01-04-01 | 04 | 3 | FND-07 (plist keys) | T-01-07 (V14 export compliance) | All FND-07 keys present | shell-assert | `grep -q '<string>Murmur</string>' ios/Runner/Info.plist && grep -q 'UIBackgroundModes' ios/Runner/Info.plist && grep -q 'org.idpf.epub-container' ios/Runner/Info.plist` | ✅ W0 | ⬜ pending |
| 01-04-02 | 04 | 3 | FND-01 (iOS deployment target) | — | IPHONEOS_DEPLOYMENT_TARGET=17.0 in all 3 places | shell-assert | `grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 17.0;' ios/Runner.xcodeproj/project.pbxproj \| awk '$1>=3{exit 0}{exit 1}'` | ✅ W0 | ⬜ pending |
| 01-04-03 | 04 | 3 | FND-07 (verify script) | T-01-07 | Linux-compat shell assertion | shell-assert | `bash scripts/verify_ios_plist.sh` | ✅ W0 | ⬜ pending |
| 01-05-01 | 05 | 3 | FND-05 (4 themes + enum) | — | Locked Clay hex values + 5-value enum | unit | `mise exec -- flutter test test/theme/app_theme_test.dart -r expanded` | ✅ W0 | ⬜ pending |
| 01-05-02 | 05 | 3 | FND-05 (persistence) | T-01-V8 | shared_preferences round-trip; invalid fallback | widget | `mise exec -- flutter test test/theme/theme_persistence_test.dart -r expanded` | ✅ W0 | ⬜ pending |
| 01-05-03 | 05 | 3 | FND-06 | — | Literata + Merriweather bundled (R+B) | unit | `mise exec -- flutter test test/fonts/font_bundle_test.dart -r expanded` | ✅ W0 | ⬜ pending |
| 01-06-01 | 06 | 3 | FND-04 | T-01-08 (V12 files) | schemaVersion=1 + zero user tables | unit | `mise exec -- flutter test test/db/app_database_test.dart -r expanded` | ✅ W0 | ⬜ pending |
| 01-06-02 | 06 | 3 | FND-04 (schema baseline) | — | Committed v1 JSON for Phase 2 migration diff | shell-assert | `test -f drift_schemas/drift_schema_v1.json && python3 -c "import json; json.load(open('drift_schemas/drift_schema_v1.json'))"` | ✅ W0 | ⬜ pending |
| 01-06-03 | 06 | 3 | FND-04 (provider) | — | @riverpod keepAlive with onDispose close | static-analyze | `mise exec -- flutter analyze lib/core/db/` | ✅ W0 | ⬜ pending |
| 01-07-01 | 07 | 3 | FND-10 (write+rotate+triple-catch) | T-01-02 (V7 logging), T-01-08 (V12 files), T-01-V9 (no network) | 7-field JSONL, 1MB rotation, all 3 levels | unit | `mise exec -- flutter test test/crash/crash_logger_test.dart -r expanded` | ✅ W0 | ⬜ pending |
| 01-07-02 | 07 | 3 | FND-10 (provider) | — | @riverpod wrapper for Settings consumption | static-analyze | `mise exec -- flutter analyze lib/core/crash/` | ✅ W0 | ⬜ pending |
| 01-08-01 | 08 | 4 | FND-01, FND-02, FND-03 | T-01-V7 | main.dart triple-catch + ProviderScope + router | widget | `mise exec -- flutter test test/widget/navigation_test.dart test/widget/provider_scope_test.dart -r expanded` | ✅ W0 | ⬜ pending |
| 01-08-02 | 08 | 4 | FND-05 (chrome rendering) | — | Library + Reader placeholders themed, Reader uses Literata RichText | static-analyze | `mise exec -- flutter analyze lib/features/library/ lib/features/reader/` | ✅ W0 | ⬜ pending |
| 01-08-03 | 08 | 4 | FND-05 (Settings picker) | T-01-V5 | 5-option RadioListTile + crash log status + font preview | static-analyze | `mise exec -- flutter analyze lib/features/settings/ && mise exec -- flutter test test/widget/ -r expanded` | ✅ W0 | ⬜ pending |
| 01-09-01 | 09 | 5 | FND-09 (amended) | T-01-06 (CI artifact scoping) | Two-job CI with correct triggers and verify gates | shell-assert | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` + `grep` assertions | ✅ W0 | ⬜ pending |
| 01-09-02 | 09 | 5 | FND-09 (README handoff) | — | Physical device install path documented | shell-assert | `grep -q '## Physical Device Install (Android)' README.md && grep -q 'bundletool' README.md` | ✅ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Nyquist compliance:** Every task has an automated verify command OR is an explicit human-verify checkpoint (task 01-01-02 only). No 3 consecutive tasks are without automated verify — the longest gap is 1 (the checkpoint in Plan 01).

---

## Wave 0 Requirements

All validation artifacts for Phase 1 are Wave 0 — nothing exists yet. The planner scaffolds each test file alongside the feature it verifies, not all up front. Each Wave 0 artifact is owned by exactly one plan.

| Wave 0 Artifact | Owning Plan |
|-----------------|-------------|
| `test/theme/app_theme_test.dart` | 01-05 (Task 1) |
| `test/theme/theme_persistence_test.dart` | 01-05 (Task 2) |
| `test/db/app_database_test.dart` | 01-06 (Task 1) |
| `test/crash/crash_logger_test.dart` | 01-07 (Task 1) |
| `test/widget/navigation_test.dart` | 01-08 (Task 1) |
| `test/widget/provider_scope_test.dart` | 01-08 (Task 1) |
| `test/fonts/font_bundle_test.dart` | 01-05 (Task 3) |
| `scripts/verify_ios_plist.sh` | 01-04 (Task 3) |
| `scripts/verify_android_manifest.sh` | 01-03 (Task 3) |
| `.github/workflows/ci.yml` | 01-09 (Task 1) |
| Delete `test/widget_test.dart` | 01-01 (Task 3) |

**Framework install:** none — `flutter_test` ships with the SDK.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| mise + Android toolchain green on CachyOS | FND-01 toolchain gate | Jake's specific host config, one-time setup verification | Task 01-01-02 human-verify checkpoint. Run `mise exec -- flutter doctor -v` and confirm all rows show `[✓]`, not `[!]` or `[✗]` |
| App launches on physical Android with correct name + 3-tab nav | FND-01 / FND-02 (Android) | Physical device presence, real-world install loop | Connect device via USB, `mise exec -- flutter run --debug`; launcher icon labelled **Murmur**, bundle ID `dev.jmclaughlin.murmur`, 3 NavigationBar destinations, each tab renders placeholder content in selected theme |
| Theme picker visually renders 5 options and switches stick across force-quit | FND-05 | Visual + OS-level lifecycle beyond widget test | On physical device: Settings → Theme, tap each of System/Light/Sepia/Dark/OLED, force-quit, relaunch, confirm selection persisted |
| Crash log `.log` file exists on device after first launch and its byte count is shown in Settings stub row | FND-10 | Physical filesystem verification; triple-catch reaches real device I/O | Force an error (dev-only trigger TBD); open Settings → "Crash log" row; confirm path shown under Application Documents Directory/crashes/crashes.log and byte count > 0 |
| Android CI artifact installs on physical device | FND-09 (Android) | CI artifact round-trip, not just build success | Download `murmur-debug.aab` from latest GH Actions run; convert via `bundletool` (README §Physical Device Install); run `bundletool install-apks`; launcher icon appears |
| iOS `ios-scaffold` job passes manual `workflow_dispatch` trigger | FND-09 (iOS) | No signing / no install possible in Phase 1 per D-05/D-06; compile on macos-14 is the proof | Trigger the `ios-scaffold` workflow manually in GH Actions UI; green run + `murmur-unsigned.xcarchive` artifact present |

*iOS physical-device install is intentionally **not** a Phase 1 requirement per D-05/D-06 — deferred to Phase 4.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify OR are explicit human-verify checkpoints (only 01-01-02)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING test file references
- [x] No watch-mode flags (`flutter test`, not `flutter test --watch`)
- [x] Feedback latency < 30 s for the full suite
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** planned (pending execution)
