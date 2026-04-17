# Phase 4 — Wave Tracker

> Progress map across Phase 4 waves. Update after each wave signs off so that clearing context mid-phase is safe: pick up by re-reading `CLAUDE.md`, this file, the current wave's `PLAN.md`, and the relevant legacy `04-0N-PLAN.md` spec.

**Phase goal:** Kokoro-82M on a long-lived worker isolate reads any chapter aloud with curated voices, adjustable speed, sentence skip, background audio, and lock-screen controls — wired to the reader through a single shared `playbackStateProvider`. Covers TTS-01..10 and PBK-01/02/03/04/08/09/10/12.

**Planning workflow:** Convert one wave at a time from the legacy GSD XML format (`04-0N-PLAN.md`) into a checkbox-driven superpowers PLAN (`PLAN.md` at phase root, overwritten each wave). Wave 0 MUST pass before any Wave 1+ planning begins, because the sherpa_onnx Flutter bindings are the highest-risk uncertainty in the stack (CLAUDE.md §Risks #1).

## Status legend
- `PLANNED` — checkbox plan exists (`PLAN.md` on disk)
- `IN PROGRESS` — execution started, not yet signed off
- `COMPLETE` — all tasks + human checkpoints signed off, summary written
- `BLOCKED` — prior wave not complete

---

## Wave 0 — TTS Spike (gate)

**Status:** COMPLETE (2026-04-17)
**Legacy spec:** `04-00-PLAN.md`
**Current plan:** `PLAN.md` (this directory)
**Summary:** `04-00-SUMMARY.md`
**Requirements touched:** TTS-02, TTS-03, TTS-05 (spike only; full coverage lands in Waves 1–5)
**Blocking gate:** Jake signs off "spike pass" on `integration_test/DEVICE_CHECKLIST.md`. Nothing else in Phase 4 proceeds until D-12 (cancellation) is empirically answered.

**Deliverables:**
- `pubspec.yaml` TTS deps pinned (`sherpa_onnx: 1.12.36` exact)
- `assets/kokoro/` static tree (voices.bin, tokens.txt, espeak-ng-data/, LICENSE) committed
- `android/app/src/main/AndroidManifest.xml` has `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
- `lib/features/tts/spike/{copy_assets,spike_page}.dart` + `integration_test/tts_spike_test.dart` + `DEVICE_CHECKLIST.md`
- `/_spike/tts` debug-only route
- `04-00-SUMMARY.md` with asset SHA-256s, latency observation, cancel-probe output, speed-probe observation

---

## Wave 1 — Model + WAV + Splitter hardening

**Status:** COMPLETE (2026-04-17)
**Legacy specs:** `04-01-PLAN.md`, `04-02-PLAN.md`, `04-03-PLAN.md` (consolidated into `PLAN.md`)
**Current plan:** `PLAN.md` (this directory) — 10 checkbox-driven tasks
**Summary:** `04-01-SUMMARY.md`
**Requirements covered:** TTS-01, TTS-02, TTS-03, TTS-04, TTS-06, TTS-08, PBK-04 (prep)

**Scope preview (do not implement until Wave 0 passes):**
- `lib/features/tts/model/model_manifest.dart` — pinned SHA-256 for `kokoro-int8-en-v0_19.tar.bz2`, 11-voice catalog (stable `voice_id` strings, not raw sids)
- `lib/features/tts/model/paths.dart` — `kokoroDir()`, `modelFile()` helpers against `getApplicationSupportDirectory()`
- `lib/features/tts/model/model_downloader.dart` — streaming HTTP download with `Range` resume, `.partial` suffix, streaming SHA-256, size cap, cancel, hash-mismatch deletes partial
- `lib/features/tts/model/model_installer.dart` — tar.bz2 extraction with path-traversal defense, size cap, atomic rename, `model_installed` flag in shared_preferences
- `lib/features/tts/ui/model_download_modal.dart` — full-screen first-launch modal, "Prefer Wi-Fi" label (NOT "Wi-Fi only" per D-02), cancel/retry
- Update `.planning/REQUIREMENTS.md` TTS-01 wording to match honor-system toggle
- `lib/features/tts/audio/wav_wrap.dart` — the helper temporarily inlined in the spike, promoted to `CD-03` form with unit tests
- `lib/core/text/sentence_splitter.dart` — hardened to 500+ fiction fixtures (TTS-06); Phase 3 regression guard
- Drift v3 migration: add `voice_id TEXT NULL`, `playback_speed REAL NULL` columns to `books` table (CD-01)

**Planning order when unblocked:**
1. Read `04-00-SUMMARY.md` for any D-12 / speed-probe surprises that reshape Waves 2+.
2. Consolidate `04-01/02/03-PLAN.md` into a single checkbox `PLAN.md`, overwriting this directory's Wave 0 plan (Wave 0 is preserved in git history + summary).
3. Move the spike's inlined WAV helper into `lib/features/tts/audio/wav_wrap.dart` as part of this wave.

---

## Wave 2 — Isolate protocol + PlaybackState seam

**Status:** COMPLETE (2026-04-17)
**Legacy specs:** `04-04-PLAN.md`, `04-05-PLAN.md` (consolidated into `PLAN.md`)
**Current plan:** `PLAN.md` (this directory) — 11 checkbox-driven tasks
**Summary:** `04-02-SUMMARY.md`
**Requirements covered:** TTS-05, TTS-07 (cache), TTS-09, PBK-08

**Scope preview:**
- Sealed-class command/event protocol (D-13): `SynthSentence`, `Cancel`, `SetVoice`, `Dispose` / `SentenceReady(path)`, `Error(e)`, `ModelLoaded`
- `lib/features/tts/isolate/tts_client.dart` + `tts_worker_main.dart` + `sherpa_tts_engine.dart` (only file allowed to import `package:sherpa_onnx`)
- `lib/features/tts/isolate/tts_cache.dart` — LRU ring buffer, 20MB/book cap, path-traversal rejection, wipeBook hook (CD-02)
- `lib/core/playback_state.dart` — `PlaybackState { bookId, chapterIdx, sentenceIdx, isPlaying, speed, voiceId }`, `playbackStateProvider` AsyncNotifierProvider (CD-04)
- `test/architecture/feature_boundary_test.dart` — compile-time grep test: reader does not import tts/, tts does not import reader/, no analytics SDKs imported anywhere
- Consumes Wave 0's D-12 answer: if cancellation confirmed absent, the `Cancel` command is a soft cancel ("discard the next emitted `SentenceReady`")

---

## Wave 3 — Queue + just_audio player

**Status:** BLOCKED (on Wave 2 main.dart cache wiring)
**Legacy spec:** `04-06-PLAN.md`
**Requirements covered:** TTS-05, TTS-07, TTS-08, TTS-10

**Scope preview:**
- `lib/features/tts/queue/just_audio_player.dart` — `AudioPlayerHandle` wrapping `AudioSource.file` (no `StreamAudioSource`, TTS-08)
- `lib/features/tts/queue/tts_queue.dart` — pre-synth next sentence, ring buffer of last 3, skip semantics, speed owned solely by `just_audio.setSpeed()` (TTS-09: sherpa `length_scale` fixed at 1.0)
- Providers wire `playbackStateProvider` ↔ queue, worker dispose releases native

---

## Wave 4 — UI: voice picker, playback bar, per-book overrides

**Status:** BLOCKED (on Wave 3)
**Legacy spec:** `04-07-PLAN.md`
**Requirements covered:** PBK-01, PBK-02, PBK-03, PBK-04

**Scope preview:**
- Per-book override persistence + preview cache
- 11-voice picker in Settings (global default) + per-book sheet from playback bar (D-09)
- `lib/features/tts/ui/playback_bar.dart` — responsive via `shortestSide`; phone = play/pause + scrubber + "more" sheet; tablet = all inline (D-16)
- Immersive-mode integration with Phase 3's tap-center chrome toggle (D-15)

---

## Wave 5 — Background audio + lock-screen + interruption

**Status:** BLOCKED (on Wave 4)
**Legacy spec:** `04-08-PLAN.md`
**Requirements covered:** PBK-09, PBK-10, PBK-12

**Scope preview:**
- `audio_service` `BaseAudioHandler` subclass with `MediaItem` (title/author/chapter, `artUri: file://` book cover)
- Lock-screen control set: play/pause + next-chapter only (D-17)
- `audio_session` `AudioSessionConfiguration.speech()` preset, interruption → pause+auto-resume, headphone unplug / BT disconnect → pause (D-19)
- Manifest compliance test: Android FGS + iOS Info.plist `UIBackgroundModes: audio` (already present per Phase 1, verify only)

---

## Wave 6 — Latency instrumentation + Phase 4 UAT

**Status:** BLOCKED (on Wave 5)
**Legacy spec:** `04-09-PLAN.md`
**Requirements covered:** TTS-10, PBK-09, PBK-10, PBK-12

**Scope preview:**
- `tool/measure_tts_latency.dart` + `Timeline` instrumentation in queue
- `integration_test/DEVICE_UAT_04.md` + `04-HUMAN-UAT.md` covering all manual checkpoints from `04-VALIDATION.md`
- Flip `04-VALIDATION.md` frontmatter `nyquist_compliant: true` and `wave_0_complete: true`
- Jake signs off → Phase 4 closes; unblocks Phase 5 (sentence highlighting / auto-scroll)

---

## Clearing context mid-phase

If you need to `/clear` between waves, the minimum read-list to get back to useful is:

1. `CLAUDE.md` (always loaded)
2. This file (`WAVES.md`)
3. The current wave's `PLAN.md` (this directory)
4. The most recent `04-0N-SUMMARY.md` (to see what Wave 0 / prior waves actually decided — D-12 outcome, hash pins, etc.)
5. `04-CONTEXT.md` + `04-RESEARCH.md` + `04-VALIDATION.md` (reference, only dip in when the plan points at a section)
6. The legacy `04-0N-PLAN.md` files for the wave you're about to convert — treat them as specs

After clearing, run `git log --oneline -30 -- .planning/phases/04-tts-engine-playback-foundation lib/features/tts` to see what's landed.
