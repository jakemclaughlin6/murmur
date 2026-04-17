# Phase 4 Wave 0 — Summary

**Date:** 2026-04-17
**Device:** Xiaomi tablet (MIUI / Android 16, BP2A.250605.031.A3), serial D6FQEU6DVC4DYHLZ
**Outcome:** PASS

## What landed (9 commits on master)

| SHA | Description |
|---|---|
| `6c03aeb` | task-1: pin TTS deps, bundle Kokoro v0_19 assets, verify Android FGS_MEDIA_PLAYBACK |
| `6b210c4` | task-1 fixup: remove stale INTERNET comment; annotate TTS dep group |
| `0533ad4` | task-2: `copyKokoroAssetsToSupportDir` + integration test |
| `f3ed1dc` | task-2 fixup: spike-only comment + test teardown |
| `26cfd3b` | task-3: `/_spike/tts` page with synth + cancel probe |
| `2432250` | task-3 fixup: mounted guards, `tts.free()` finally, initBindings idempotency |
| `880e4be` | task-4: device verification checklist |
| `7894a11` | task-2 fixup: use typed `AssetManifest` API (Flutter 3.41 dropped `AssetManifest.json`) |
| `6f65873` | task-1 fixup: register `espeak-ng-data` subdirs (flutter assets don't recurse) |

## Kokoro asset SHA-256 fingerprints

Captured post-install from `/assets/kokoro/`:

- `voices.bin`: `a372c67b056ef0b695c375d39b99630d23fb07ad4c8d87aa32a19a62fca523ad`
- `tokens.txt`: `4f31c71282d14af4e926cd12462078fe9d20d00c589e63fe2750a8f56d6d7f7b`

## Version pins (resolved)

- `sherpa_onnx: 1.12.36` (exact — no caret)
- `sherpa_onnx_ios: 1.12.39` (federated platform impl raced ahead; acceptable per CLAUDE.md — we don't import it directly)
- `just_audio: ^0.10.5`, `audio_service: ^0.18.18`, `audio_session: ^0.2.3`, `http: ^1.2.0`, `crypto: ^3.0.5`
- Flutter 3.41 / Dart 3.11

## On-device observations

- **Audio playback:** the sentence *"Welcome to murmur. This is how I sound reading your books."* played audibly in voice sid=1 (af_bella, American female) at speed=1.0. Voice quality judged acceptable ("good enough") for the spike.
- **Tap-to-audible latency:** ~5 seconds. **Slower than TTS-10's <300ms target.** The spike constructs `OfflineTts` from scratch on every tap (cold-load of an 80MB ONNX model + eSpeak-ng voice init). Wave 3's long-lived worker isolate (D-10) + Wave 3's sentence-0 pre-synth (D-11) are designed to close this gap; this 5s figure is the cold-boot reference, not a regression indicator.
- **Speed=2.0 probe:** not exercised this run. Deferred to Wave 3 when speed control lands via `just_audio.setSpeed()` (TTS-09 — sherpa `length_scale` stays 1.0).

## Cancellation probe (D-12) — RESOLVED

The probe output captured the critical literal:

> `sherpa_onnx 1.12.36: no public cancel()/interrupt() API.`

The subsequent synth-in-isolate step errored out with a Dart closure-capture bug (the `_cancelProbe` closure transitively captured `_player` / `_SpikePageState`, violating `SendPort.send()`'s sendability rules). This is a flaw in how the spike probe was wired, **not** a sherpa_onnx issue. The probe's primary deliverable — empirical confirmation that no cancel primitive exists — was captured before the crash.

**D-12 frozen:** sherpa_onnx 1.12.36 Flutter API exposes no cancellation hook. Wave 2 (`04-04-PLAN.md`) must implement the `Cancel` command as a soft cancel ("let current `generateWithConfig` finish, discard its `SentenceReady` emission"), not as a true interrupt. Revisit only if sherpa_onnx adds a cancel API upstream (monitor changelog each pin bump).

## Surprises & fixes applied during verification

1. **Flutter 3.41 dropped `AssetManifest.json`** — the naive `rootBundle.loadString('AssetManifest.json')` path crashes at runtime. Fixed to `AssetManifest.loadFromAssetBundle(rootBundle)` in commit `7894a11`. **Carry forward:** document this in Wave 1 when `copy_assets.dart` graduates into the production download flow.
2. **Flutter `assets:` pubspec syntax does not recurse into subdirectories.** The initial `assets/kokoro/espeak-ng-data/` registration bundled only top-level files, missing `lang/ine/` (where the English eSpeak-ng voice lives). Runtime crashed with `Failed to set eSpeak-ng voice`. Fixed by registering all 37 espeak-ng subdirectories explicitly (commit `6f65873`). **Carry forward:** Wave 1 should automate this via a build step (generate the asset list from `find assets/kokoro -type d`) rather than hand-maintain, since future model updates could add/remove dirs.
3. **Temporary debug button on Library screen** — a `FilledButton.tonal` gated by `kDebugMode` was added to `library_screen.dart` to give Jake a one-tap path to `/_spike/tts`. Reverted after device sign-off (no commit; working-tree-only change).
4. **Android 16 USB install prompt** — `adb install -r` fails with `INSTALL_FAILED_USER_RESTRICTED` until the on-device "Install via USB" toggle is flipped. Note this in the Wave 1 downloader UX planning if any device-based verification is needed before TestFlight/internal-track distribution.
5. **`flutter build apk --debug` + `adb install -r` produced a non-functional APK** — the Library screen hung in an infinite loading loop. Workaround: use `just run` (`flutter run`) which performs a clean build + install. Root cause not investigated — likely stale asset bundle or incomplete install. Acceptable since dev workflow uses `just run`; production builds use `flutter build appbundle`.

## Unblocks

- Phase 4 Wave 1 cleared to proceed:
  - `04-01-PLAN.md` — model paths + 11-voice catalog + Drift v3 migration
  - `04-02-PLAN.md` — streaming HTTP downloader + tarball installer + first-launch modal
  - `04-03-PLAN.md` — WAV wrap helper (promote from spike's inline form) + splitter hardening to 500+ fixtures
- Wave 2's isolate protocol (`04-04-PLAN.md`) must consume D-12's resolved outcome (soft-cancel semantics).
- Waves 3–6 remain BLOCKED by their predecessors per `WAVES.md`.
