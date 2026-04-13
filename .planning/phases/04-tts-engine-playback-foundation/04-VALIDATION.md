---
phase: 04
slug: tts-engine-playback-foundation
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-12
updated: 2026-04-13
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test + integration_test (Dart 3.11 / Flutter 3.41) |
| **Config file** | `pubspec.yaml` dev_dependencies; `integration_test/` dir |
| **Quick run command** | `flutter test` |
| **Full suite command** | `flutter test && flutter test integration_test --tags device` |
| **Estimated runtime** | ~90 seconds (unit) + ~180 seconds (integration on device) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test` (scoped to touched package if feasible).
- **After every plan wave:** Run full suite including `integration_test/` where applicable.
- **Before `/gsd-verify-work`:** Full suite green + device-verification checklist signed.
- **Max feedback latency:** 90 seconds for unit, 300 seconds for integration.

---

## Per-Task Verification Map

| Task ID   | Plan | Wave | Requirement(s)                 | Threat Ref(s)            | Secure Behavior                                                                                  | Test Type         | Automated Command                                                                                                                               | File Exists | Status     |
|-----------|------|------|--------------------------------|--------------------------|--------------------------------------------------------------------------------------------------|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|-------------|------------|
| 04-00-01 | 00   | 0    | TTS-03                         | T-04-00-01/02/04         | Deps pinned exactly; FGS_MEDIA_PLAYBACK present; Kokoro static assets bundled                    | build/grep        | `flutter pub get && flutter analyze && test -f assets/kokoro/voices.bin && grep -q FOREGROUND_SERVICE_MEDIA_PLAYBACK android/app/src/main/AndroidManifest.xml` | ✅ in-plan  | ⬜ pending |
| 04-00-02 | 00   | 0    | TTS-02, TTS-03, TTS-05         | T-04-00-02/03            | Spike page compiles; integration test analyzes cleanly; cancellation probe instrumented          | analyze + compile | `flutter analyze lib/features/tts/spike/ integration_test/tts_spike_test.dart`                                                                  | ✅ in-plan  | ⬜ pending |
| 04-00-03 | 00   | 0    | TTS-02, TTS-03                 | —                        | Physical-device spike: hear one sentence                                                         | MANUAL device     | Checkpoint — Jake runs DEVICE_CHECKLIST.md                                                                                                      | n/a         | ⬜ pending |
| 04-01-01 | 01   | 1    | TTS-03                         | T-04-01-01               | Asset copy idempotent; model-bundling guard; 11-voice catalog                                    | unit              | `flutter test test/features/tts/model/paths_test.dart test/features/tts/model/model_assets_test.dart`                                            | ✅ in-plan  | ⬜ pending |
| 04-01-02 | 01   | 1    | PBK-04                         | T-04-01-02               | Drift v3 migration round-trip (voice_id, playback_speed); PRAGMA foreign_keys intact              | unit (drift)      | `dart run build_runner build --delete-conflicting-outputs && flutter test test/core/db/migration_v3_test.dart`                                   | ✅ in-plan  | ⬜ pending |
| 04-02-01 | 02   | 1    | TTS-02, TTS-04                 | T-04-02-01/03/04/05/07   | Streaming SHA-256; Range resume; size cap; cancel; hash mismatch deletes partial                 | unit (http.MockClient) | `flutter test test/features/tts/model/model_downloader_test.dart test/features/tts/model/model_downloader_resume_test.dart`                 | ✅ in-plan  | ⬜ pending |
| 04-02-02 | 02   | 1    | TTS-02                         | T-04-02-02/03            | Tar.bz2 path-traversal defense, size cap, atomic rename, model_installed flag gate                | unit              | `flutter test test/features/tts/model/model_installer_test.dart && grep -q 'static const String archiveSha256 = .[0-9a-f]\{64\}.;' lib/features/tts/model/model_manifest.dart` | ✅ in-plan  | ⬜ pending |
| 04-02-03 | 02   | 1    | TTS-01                         | T-04-02-06               | First-launch modal; Prefer Wi-Fi label; cancel/retry UI                                          | widget            | `flutter test test/features/tts/ui/model_download_modal_test.dart && grep -q 'Prefer Wi-Fi' lib/features/tts/ui/model_download_modal.dart && ! grep -q 'Wi-Fi only' lib/features/tts/ui/model_download_modal.dart` | ✅ in-plan  | ⬜ pending |
| 04-02-04 | 02   | 1    | TTS-01                         | —                        | REQUIREMENTS.md TTS-01 reflects honor-system toggle per D-02                                     | grep              | `grep -q "Prefer Wi-Fi" .planning/REQUIREMENTS.md && ! grep -q "Wi-Fi-only toggle" .planning/REQUIREMENTS.md`                                    | ✅ in-plan  | ⬜ pending |
| 04-03-01 | 03   | 1    | TTS-08                         | T-04-03-02               | 44-byte WAV header byte-exact; clamp ±1.0; errors for empty/zero-rate                            | unit              | `flutter test test/features/tts/audio/wav_wrap_test.dart`                                                                                        | ✅ in-plan  | ⬜ pending |
| 04-03-02 | 03   | 1    | TTS-06                         | T-04-03-01               | 500+ fiction corpus; Phase 3 regression guard                                                    | unit (parametric) | `flutter test test/core/text/sentence_splitter_test.dart test/core/text/sentence_splitter_500_test.dart && test $(grep -c 'SplitCase(' test/fixtures/sentence_splitter/fiction_corpus.dart) -ge 500` | ✅ in-plan  | ⬜ pending |
| 04-04-01 | 04   | 2    | TTS-05                         | T-04-04-01/05/06         | Sealed isolate protocol; cancel-discards-result; dispose flow                                     | unit (FakeTts in-process) | `flutter test test/features/tts/isolate/tts_client_test.dart`                                                                          | ✅ in-plan  | ⬜ pending |
| 04-04-02 | 04   | 2    | TTS-05, TTS-09                 | T-04-04-02               | Real sherpa engine — compile-clean + import isolation                                             | static            | `flutter analyze lib/features/tts/isolate/ && (grep -l "package:sherpa_onnx" lib/ -r \| grep -v 'sherpa_tts_engine.dart' \| grep -v 'spike_page.dart' \| [[ -z "$(cat)" ]])` | ✅ in-plan  | ⬜ pending |
| 04-04-03 | 04   | 2    | TTS-07                         | T-04-04-03/04            | LRU + 20MB cap + wipeBook; path-traversal rejection                                               | unit              | `flutter test test/features/tts/isolate/tts_cache_test.dart`                                                                                     | ✅ in-plan  | ⬜ pending |
| 04-05-01 | 05   | 2    | PBK-08                         | —                        | PlaybackState immutable; mutations atomic                                                         | unit              | `dart run build_runner build --delete-conflicting-outputs && flutter test test/core/playback_state_test.dart`                                    | ✅ in-plan  | ⬜ pending |
| 04-05-02 | 05   | 2    | PBK-08                         | T-04-05-01/02/03         | Feature-boundary + network + sherpa + analytics-banned grep tests                                 | architecture      | `flutter test test/architecture/feature_boundary_test.dart test/architecture/no_direct_network_test.dart`                                        | ✅ in-plan  | ⬜ pending |
| 04-06-01 | 06   | 3    | TTS-08                         | T-04-06-02               | AudioPlayerHandle contract; no StreamAudioSource                                                  | unit              | `flutter test test/features/tts/queue/just_audio_player_test.dart`                                                                               | ✅ in-plan  | ⬜ pending |
| 04-06-02 | 06   | 3    | TTS-05, TTS-07, TTS-10         | T-04-06-01/04            | Queue pre-synth + ring buffer + skip semantics + speed ownership                                   | unit (fakes)      | `flutter test test/features/tts/queue/tts_queue_test.dart`                                                                                       | ✅ in-plan  | ⬜ pending |
| 04-06-03 | 06   | 3    | TTS-05, TTS-09                 | T-04-06-03               | Provider wiring drives queue via playbackStateProvider; worker dispose releases native            | unit              | `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/tts/providers/tts_queue_provider_test.dart test/architecture/feature_boundary_test.dart` | ✅ in-plan  | ⬜ pending |
| 04-07-01 | 07   | 4    | PBK-04                         | T-04-07-01/04            | Per-book + global override persistence; invalid-id fallback; clamp                                | unit (drift+prefs) | `dart run build_runner build --delete-conflicting-outputs && flutter test test/features/tts/providers/per_book_override_test.dart`              | ✅ in-plan  | ⬜ pending |
| 04-07-02 | 07   | 4    | PBK-03                         | T-04-07-02/03            | 11-voice picker; preview cache; use-default reset                                                 | widget            | `flutter test test/features/tts/ui/voice_picker_test.dart`                                                                                       | ✅ in-plan  | ⬜ pending |
| 04-07-03 | 07   | 4    | PBK-01, PBK-02                 | T-04-07-04               | Playback bar responsive; skip ± with clamping; speed picker; boundary test                        | widget + arch      | `flutter test test/features/tts/ui/playback_bar_test.dart test/features/tts/ui/playback_bar_skip_test.dart test/architecture/feature_boundary_test.dart` | ✅ in-plan  | ⬜ pending |
| 04-08-01 | 08   | 5    | PBK-09, PBK-10, PBK-12         | T-04-08-01/02/04         | Audio handler + interruption state machine                                                        | unit (fakes)      | `flutter test test/features/tts/audio/audio_handler_test.dart test/features/tts/audio/session_interruption_test.dart`                            | ✅ in-plan  | ⬜ pending |
| 04-08-02 | 08   | 5    | PBK-09, PBK-10                 | T-04-08-03/04/05         | Android manifest FGS + iOS Info.plist audio background mode                                        | static (file grep) | `flutter test test/features/tts/audio/manifest_compliance_test.dart`                                                                             | ✅ in-plan  | ⬜ pending |
| 04-09-01 | 09   | 6    | TTS-10                         | T-04-09-02               | Timeline instrumentation + latency tool compile-green                                              | analyze + unit    | `flutter analyze integration_test/phase_04_device_pack.dart tool/measure_tts_latency.dart lib/features/tts/queue/tts_queue.dart && flutter test test/features/tts/queue/tts_queue_test.dart` | ✅ in-plan  | ⬜ pending |
| 04-09-02 | 09   | 6    | TTS-10, PBK-09, PBK-10, PBK-12 | T-04-09-01               | UAT checklist committed; VALIDATION nyquist flipped                                               | file presence     | `test -f integration_test/DEVICE_UAT_04.md && test -f .planning/phases/04-tts-engine-playback-foundation/04-HUMAN-UAT.md && grep -q 'nyquist_compliant: true' .planning/phases/04-tts-engine-playback-foundation/04-VALIDATION.md` | ✅ in-plan  | ⬜ pending |
| 04-09-03 | 09   | 6    | TTS-10, PBK-09, PBK-10, PBK-12 | —                        | Jake signs off UAT pass                                                                           | MANUAL device     | Checkpoint — 04-HUMAN-UAT.md signed                                                                                                              | n/a         | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Sampling continuity check

- Waves 0–6: every wave has at least one automated `<automated>` command (including Wave 0 Task 1 and Task 2 — Task 3 is a gating manual checkpoint AFTER two automated verifies).
- No 3 consecutive tasks without an automated verify: verified by scanning the table above — the two MANUAL entries (04-00-03, 04-09-03) are each adjacent to multiple automated entries.
- Feedback latency: unit/arch tests run in <90s; integration device pack runs in <300s.

---

## Wave 0 Requirements (satisfied by 04-00-PLAN.md)

- [x] `integration_test/tts_spike_test.dart` — Wave 0 "hear one sentence" spike (04-00 Task 2)
- [x] `test/features/tts/model/model_assets_test.dart` — asset copy (04-01 Task 1)
- [x] `test/features/tts/model/model_downloader_test.dart` + `..._resume_test.dart` (04-02 Task 1)
- [x] `test/features/tts/audio/wav_wrap_test.dart` (04-03 Task 1)
- [x] `test/features/tts/isolate/tts_client_test.dart` (04-04 Task 1)
- [x] `test/features/tts/providers/per_book_override_test.dart` (04-07 Task 1)
- [x] `test/features/tts/queue/tts_queue_test.dart` (04-06 Task 2)
- [x] `test/features/tts/queue/just_audio_player_test.dart` (04-06 Task 1)
- [x] `test/features/tts/ui/playback_bar_test.dart` (04-07 Task 3)
- [x] `test/features/tts/ui/playback_bar_skip_test.dart` (04-07 Task 3)
- [x] `test/features/tts/ui/voice_picker_test.dart` (04-07 Task 2)
- [x] `test/features/tts/ui/model_download_modal_test.dart` (04-02 Task 3)
- [x] `integration_test/background_playback_test.dart` scaffold (04-09 Task 1)
- [x] `test/architecture/feature_boundary_test.dart` (04-05 Task 2) — enforces PBK-08 no-cross-import rule
- [x] `test/helpers/fake_tts_engine.dart` (04-04 Task 1)
- [x] `test/helpers/fake_audio_player.dart` (04-06 Task 1)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Covered By |
|----------|-------------|------------|-----------|
| Sentence-start latency <300ms on mid-range Android | TTS-10 | Physical hardware + trace | 04-09 Section B (+ `tool/measure_tts_latency.dart`) |
| Lock-screen controls show book + chapter metadata with play/pause/next-chapter on Android | PBK-10 | OS lock-screen UI | 04-09 Section G |
| iOS lock-screen equivalent | PBK-10 | No-Mac constraint | CI `workflow_dispatch` xcarchive only (Phase 1 D-06); deferred to Phase 7 |
| Incoming call / Siri pauses murmur and resumes cleanly | PBK-12 | Telephony | 04-09 Section H |
| ~10 curated voice previews sound acceptable | TTS-07 | Subjective audio | 04-09 Section C |
| Model download resumable across network change | TTS-04 | Flaky network on device | 04-09 Section A |
| Background playback survives app pause | PBK-09 | True OS backgrounding | 04-09 Section F |
| Headphone unplug / BT disconnect pauses | PBK-12 | Physical accessory | 04-09 Section H |
| 2× speed pitch preservation on Android | TTS-09 / Pitfall 5 | Subjective audio | 04-09 Section E |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or are explicitly-gated MANUAL checkpoints (04-00-03, 04-09-03)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 300s (integration), < 90s (unit)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** Nyquist-compliant plan set. Awaiting Wave 0 device signoff (04-00-03) before Waves 1+ execute, and final UAT signoff (04-09-03) before Phase 4 close.
