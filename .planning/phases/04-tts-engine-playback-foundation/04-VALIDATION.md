---
phase: 04
slug: tts-engine-playback-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test + integration_test (Dart 3.11 / Flutter 3.41) |
| **Config file** | `pubspec.yaml` dev_dependencies; `integration_test/` dir (Wave 0 installs if missing) |
| **Quick run command** | `flutter test` |
| **Full suite command** | `flutter test && flutter test integration_test` |
| **Estimated runtime** | ~90 seconds (unit) + ~180 seconds (integration on device) |

---

## Sampling Rate

- **After every task commit:** Run `flutter test` (scoped to touched package if feasible)
- **After every plan wave:** Run full suite including `integration_test/`
- **Before `/gsd-verify-work`:** Full suite green + device-verification checklist signed
- **Max feedback latency:** 90 seconds for unit, 300 seconds for integration

---

## Per-Task Verification Map

*Populated by the planner during PLAN.md generation. Each task in every PLAN must appear here with its automated command, Wave-0 file dependency, and requirement ID. See Wave 0 stub list below.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-00-01 | 00 (spike) | 0 | TTS-02, TTS-03 | — | Sherpa Kokoro synth produces audible PCM on physical Android | integration | `flutter test integration_test/tts_spike_test.dart` | ❌ W0 | ⬜ pending |
| _TBD by planner_ | … | … | … | … | … | … | … | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `integration_test/tts_spike_test.dart` — Wave 0 "hear one sentence" spike harness on physical device (gates all downstream work)
- [ ] `test/features/tts/tts_service_test.dart` — stubs for TTS-02, TTS-03, TTS-04, TTS-05
- [ ] `test/features/tts/model_download_test.dart` — stubs for TTS-01 (resumable, SHA-256, Wi-Fi toggle, partial cleanup)
- [ ] `test/features/tts/pcm_wav_bridge_test.dart` — stubs for TTS-06 (float→int16→WAV header wrapper)
- [ ] `test/features/tts/voice_catalog_test.dart` — stubs for TTS-07, TTS-08 (11 voice ids, per-book overrides)
- [ ] `test/features/playback/playback_state_provider_test.dart` — stubs for PBK-01, PBK-02, PBK-08 (single coordination seam)
- [ ] `test/features/playback/speed_owner_test.dart` — stubs for PBK-03, PBK-09 (just_audio.setSpeed sole owner; length_scale==1.0 assertion)
- [ ] `integration_test/background_playback_test.dart` — stubs for PBK-04, PBK-10, PBK-12 (background, lock-screen, interruption)
- [ ] `test/architecture/no_reader_to_tts_import_test.dart` — grep-rule test enforcing no `features/reader/**` imports into `features/tts/**` (PBK-08)
- [ ] `test/helpers/fake_tts_engine.dart` — shared deterministic TTS fake (no real sherpa in unit tests)
- [ ] `integration_test/driver.dart` — integration_test harness setup

*Rationale: Wave 0 is mandatory. The "hear one sentence" spike is the single gating task per RESEARCH.md — all isolate, WAV-bridge, and audio_service work depends on it succeeding on a real device.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sentence-start latency <300ms on mid-range Android | TTS-03 | Requires physical hardware + stopwatch/trace | Install debug build on Pixel 6a-class device; tap play on seeded chapter; record trace from tap → first PCM frame emitted by player |
| Lock-screen controls show book + chapter metadata with play/pause/next-chapter on iOS and Android | PBK-10 | Requires OS lock screen UI which cannot be driven from flutter_test | Start playback, lock device, verify metadata + 3 controls visible and functional on both platforms |
| Incoming call / Siri pauses murmur and resumes cleanly | PBK-12 | Requires telephony/Siri interrupts from the OS | Trigger call on Android, Siri on iOS, during playback; verify pause on interrupt start and resume on interrupt end |
| ~10 curated voice previews sound acceptable | TTS-07 | Subjective audio quality | Ship builder listens to all 11 voice previews on headphones and speaker; flag any clipping or mispronunciation |
| Model download is resumable across network change | TTS-01 | Requires flaky network simulation on real device | Toggle airplane mode mid-download; re-enable; verify `.partial` file resumes instead of restart |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (especially spike + WAV-bridge + playbackStateProvider)
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s (integration), < 90s (unit)
- [ ] `nyquist_compliant: true` set in frontmatter after planner populates task map

**Approval:** pending
