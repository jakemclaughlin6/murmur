# Phase 4: TTS Engine & Playback Foundation — Research

**Researched:** 2026-04-12
**Domain:** On-device neural TTS (Kokoro/Sherpa-ONNX) + isolate orchestration + background audio + lock-screen media controls
**Confidence:** HIGH on stack and audio surface; MEDIUM on sherpa_onnx Flutter API details (verified against the upstream example, but young API); LOW on cancellation support (verified absent in official example — D-12 needs to change).

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Model Download UX**
- **D-01:** Download prompt appears during first-launch onboarding — shown once, right after install, framed as "required to hear books read aloud." Not at first-play-tap, not as a passive Library banner.
- **D-02:** Wi-Fi toggle is honor-system, not enforced. Label it **"Prefer Wi-Fi"** (not "Wi-Fi only"). No `connectivity_plus` dep. TTS-01 wording must be adjusted by planner to reflect this.
- **D-03:** Download is a full-screen modal with percent + MB-of-total, cancel button, and "you can leave this screen" note. Hash-verify + atomic rename after bytes complete.
- **D-04:** Model fetched direct from k2-fsa sherpa-onnx GitHub Releases with a pinned SHA-256 in source. No self-hosted mirror in v1.
- **D-05:** Download is resumable (HTTP Range + `.partial` suffix) and cleans up partial files on failure/cancel.

**Voice Picker & Previews**
- **D-06:** Ship all 11 voices from v0_19 — skip curation. Verified at build time against `voices.bin`.
- **D-07:** Previews are live-synthesized on first tap, then cached as WAVs under app support dir keyed by voice-id.
- **D-08:** Preview sentence is a single fixed branded sentence (~10–15 words, exact wording TBD in Phase 4).
- **D-09:** Voice picker lives in two places: (a) global default in Settings, (b) per-book override in a sheet opened from the playback bar inside the reader, with explicit "use default" reset.

**Worker Isolate & Latency**
- **D-10:** Long-lived TTS worker isolate spawned on reader open, torn down on reader close (or after a short background-timeout). Sherpa model load at isolate spawn. Release of Sherpa native resources on teardown is mandatory.
- **D-11:** First-sentence <300ms latency (TTS-10) achieved by pre-synthesizing sentence 0 on chapter load.
- **D-12:** Skip-sentence mid-synthesis cancels in-flight synth — **Spike requirement:** verify sherpa_onnx Flutter bindings actually expose cancellation; fall back to "let current finish, discard" if not.
- **D-13:** UI ↔ worker isolate communication uses SendPort + Dart sealed-class command/event messages (`SynthSentence`, `Cancel`, `SetVoice`, `Dispose` / `SentenceReady(path)`, `Error(e)`, `ModelLoaded`). No `Map<String, dynamic>`.

**Playback Surface**
- **D-14:** Persistent mini-bar docked at the bottom of the reader (~48–56px). Play/pause, chapter scrubber (PBK-01), skip ± sentence (PBK-02), speed selector.
- **D-15:** Playback bar toggles together with the app bar under immersive mode (Phase 3 D-10). Lock-screen and Bluetooth controls remain functional.
- **D-16:** Phone shows play/pause + scrubber + "more" sheet (skip/speed/voice). Tablet shows all inline. One responsive `PlaybackBar` reading `shortestSide`.

**Lock-Screen & Audio Session**
- **D-17:** Lock-screen controls: play/pause + next-chapter only. No skip-sentence, no prev-chapter in v1.
- **D-18:** Lock-screen metadata: book title, author, chapter name. Artwork: book cover from Phase 2 import, fallback to app icon. `MediaItem.artUri = file://...`.
- **D-19:** Audio session uses the **speech** category via `audio_session`. Interruptions pause + auto-resume. No ducking. Headphone unplug + BT disconnect pause.

### Claude's Discretion
- **CD-01:** Per-book prefs = two nullable columns on `books` Drift table (`voice_id TEXT NULL`, `playback_speed REAL NULL`). NULL = fall back to global default.
- **CD-02:** Ring-buffer cache at `{app_support_dir}/tts_cache/{book_id}/{chapter_idx}/{sentence_idx}.wav`. Keep last 3 played + up to 2 pre-synthesized. LRU eviction, soft cap ~20MB per book. Wipe on book delete.
- **CD-03:** `wavWrap(Float32List pcm, int sampleRate=24000) -> Uint8List` helper at `lib/features/tts/audio/wav_wrap.dart`. Unit-tested.
- **CD-04:** `playbackStateProvider` = Riverpod `AsyncNotifierProvider` emitting `PlaybackState { bookId, chapterIdx, sentenceIdx, isPlaying, speed, voiceId }`. TTS writes, reader reads. Boundary enforced: neither feature imports the other — both depend on `core/playback_state.dart`.

### Deferred Ideas (OUT OF SCOPE)
- Sleep timer (PBK-11) → Phase 6
- Sentence highlighting & auto-scroll (PBK-05/06/07) → Phase 5
- Non-English voices (TTS-11) → future
- Advanced voices submenu (TTS-12) → future
- Sub-sentence streaming via `generateWithCallback` (TTS-13) → Phase 7
- Self-hosted mirror
- Voice curation
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TTS-01 | First-launch model download prompt with Wi-Fi toggle | §Model Download, §Don't Hand-Roll (use `package:http` streaming + SHA-256 verify) |
| TTS-02 | Fetch `model.int8.onnx` from pinned URL, SHA-256 verify, store under app docs | §Model Download — URL pattern + hash protocol |
| TTS-03 | Bundle `voices.bin`, `tokens.txt`, `espeak-ng-data/` in-app | §Asset Bundling |
| TTS-04 | Resumable download with cleanup on fail/cancel | §Model Download — HTTP Range + `.partial` + atomic rename |
| TTS-05 | Synthesis runs on long-lived worker isolate | §Isolate Architecture |
| TTS-06 | `SentenceSplitter` passes 500+ fixture test suite | §Splitter Hardening — extends Phase 3 splitter |
| TTS-07 | `TtsQueue` pre-synth next + ring buffer of last 3 | §Pre-synth + ring buffer |
| TTS-08 | Kokoro 24kHz Float32 mono → WAV-wrapped → `AudioSource.file` (not StreamAudioSource) | §WAV Wrapping, §just_audio bridge |
| TTS-09 | Sherpa `length_scale=1.0`, only `just_audio.setSpeed()` owns speed | §Speed Ownership |
| TTS-10 | First-sentence playback <300ms of play tap | §Latency strategy (pre-synth + warm isolate) |
| PBK-01 | Playback bar: play/pause, chapter scrubber, speed selector | §Playback Bar composition |
| PBK-02 | Skip forward/back one sentence | §Skip semantics + cancellation spike |
| PBK-03 | Voice picker with <2s previews | §Preview strategy |
| PBK-04 | Per-book voice + speed overrides | §Drift migration (CD-01) |
| PBK-08 | Shared `playbackStateProvider` coordinates reader ↔ TTS | §Coordination seam |
| PBK-09 | Audio continues when backgrounded | §audio_service setup |
| PBK-10 | Lock-screen controls + book/chapter metadata | §MediaItem + BaseAudioHandler |
| PBK-12 | Audio session interruption handling | §audio_session speech category |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **No network after model download.** One HTTP call only; then airplane-mode is a supported state. [VERIFIED: CLAUDE.md]
- **No OS system TTS fallback.** If Kokoro fails, fail loudly. [VERIFIED: CLAUDE.md — "Out of Scope"]
- **Pin exact sherpa_onnx version.** 6 patch releases in ~3 weeks; API refactored in 1.12.31. [VERIFIED: CLAUDE.md §Risks]
- **No StreamAudioSource.** Use WAV-wrap + `AudioSource.file`. [VERIFIED: CLAUDE.md + REQUIREMENTS TTS-08]
- **Sherpa `length_scale` fixed at 1.0; `just_audio.setSpeed()` is sole speed owner.** Compound-speed trap. [VERIFIED: CLAUDE.md + TTS-09]
- **No `flutter_tts`.** [VERIFIED: CLAUDE.md]
- **No Firebase/Sentry/Crashlytics/analytics.** Local crash log only. [VERIFIED: CLAUDE.md]
- **No `dio`.** Use `package:http` streaming for the model download. [VERIFIED: CLAUDE.md]
- **Info.plist needs `UIBackgroundModes: audio`.** (Already added Phase 1 FND-07 — planner should verify presence, not re-add.) [VERIFIED: Phase 1 FND-07]
- **Android manifest needs `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.** (Phase 1 FND-08 — verify.) [VERIFIED: Phase 1 FND-08]
- **Paragraph `Semantics`, not sentence.** [VERIFIED: RDR-05, already landed Phase 3] — TTS must not add sentence-level `Semantics` that would break VoiceOver/TalkBack.
- **Flutter 3.41 / Dart 3.11** pinned via mise. [VERIFIED: pubspec.yaml]

## Summary

Phase 4 is the highest-risk phase in the stack. It introduces four new concerns simultaneously: (1) downloading and hash-verifying an ~80MB model from the public internet exactly once, (2) loading a native-backed TTS engine (`sherpa_onnx`) inside a long-lived worker isolate, (3) bridging Float32 PCM samples into `just_audio` via an in-memory WAV container, and (4) wiring `audio_service` + `audio_session` so audio survives backgrounding and coexists with phone calls, Siri, and Bluetooth. Each of these is solved with well-known patterns — the risk is in the integration, not the pieces.

The upstream `sherpa-onnx/flutter-examples/tts` implementation is the load-bearing reference for Kokoro config, isolate shape, and the `generateWithConfig` API. The verified API is **synchronous-blocking** inside the isolate and **has no cancellation primitive** — this invalidates the optimistic assumption in D-12. Planner should plan for the fallback path ("let current finish, discard result") as the primary implementation, then treat a true cancellation hook as a post-MVP optimization.

Every external dep is pinned (Flutter 3.41 / sherpa_onnx 1.12.36 / just_audio 0.10.5 / audio_service 0.18.18 / audio_session 0.2.3). The only net-new packages this phase adds are `sherpa_onnx`, `just_audio`, `audio_service`, `audio_session`, `http`, and `crypto`.

**Primary recommendation:** Gate Phase 4 on a Wave 0 **"hear one sentence" integration spike** before building any playback bar, settings, or onboarding UI. The spike's single success criterion: a standalone test page synthesizes and plays a sentence through `just_audio` end-to-end on a physical Android device. Every other decision in this phase depends on that working.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| sherpa_onnx | ^1.12.36 | Kokoro neural TTS bindings | Only maintained Flutter path to on-device neural TTS with Kokoro. Official `k2-fsa` maintainer, federated iOS/Android impls. [VERIFIED: pub.dev 2026-04-08, Apr 2026] |
| just_audio | ^0.10.5 | Audio playback | De-facto Flutter audio player. Supports `AudioSource.file` which is what the WAV-wrap path feeds. [VERIFIED: CLAUDE.md + pubspec pin intent] |
| audio_service | ^0.18.18 | Background audio + lock-screen controls | Only viable Flutter package for `MediaBrowserService` + `MPNowPlayingInfoCenter`. [VERIFIED: pub.dev + CLAUDE.md] |
| audio_session | ^0.2.3 | AVAudioSession / AudioFocus config + interruption events | Partners with audio_service. Provides `AudioSessionConfiguration.speech()` preset + `interruptionEventStream` + `becomingNoisyEventStream`. [VERIFIED: pub.dev 2026-04] |
| http | ^1.2.0 | Model download | Stdlib-grade, streaming + Range requests supported, no transitive bloat. [CITED: CLAUDE.md "Gotchas → use package:http, not dio"] |
| crypto | ^3.0.5 | SHA-256 of downloaded model | Stdlib-grade, streaming Digest sink means we can hash while writing. [CITED: CLAUDE.md §Risks #1] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| path_provider | ^2.1.5 (already in pubspec) | `getApplicationSupportDirectory()` for model files, cache | Required by sherpa_onnx — it needs file paths, not asset handles. |
| shared_preferences | ^2.3.0 (already in pubspec) | Global defaults: `default_voice_id`, `default_speed`, `model_installed_flag` | Small scalars, avoid Drift ceremony. |
| flutter_riverpod | ^3.3.1 (already) | `playbackStateProvider`, TTS worker provider, model-download provider | Same pattern as prior phases. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| sherpa_onnx bindings | `dart:ffi` direct to `sherpa_onnx_c_api` | More work, no Flutter-layer bugs. Keep as fallback only. [CITED: CLAUDE.md §Risks #1] |
| sherpa_onnx | `kokoro_tts_flutter` community package | Smaller userbase, less battle-testing. Second fallback. [CITED: CLAUDE.md] |
| WAV-wrap + `AudioSource.file` | `StreamAudioSource` with per-chunk PCM | Explicitly rejected (TTS-08, REQUIREMENTS.md OOS). Unstable on real devices. [VERIFIED: REQUIREMENTS.md] |
| `package:http` streaming | `dio` | `dio` is overkill for one download. [CITED: CLAUDE.md] |

### Versions to pin in pubspec
```yaml
dependencies:
  sherpa_onnx: 1.12.36        # EXACT — not ^. Patch cadence is too fast.
  just_audio: ^0.10.5
  audio_service: ^0.18.18
  audio_session: ^0.2.3
  http: ^1.2.0
  crypto: ^3.0.5
```
`sherpa_onnx` must be an **exact pin**, not caret. The Generate API refactored in 1.12.31; a future patch regression is a real risk per CLAUDE.md §Risks #1.

## Kokoro Model — Asset Layout

`kokoro-int8-en-v0_19.tar.bz2` [VERIFIED via CLAUDE.md HEAD-check: 103,248,205 bytes] expands to:

```
kokoro-en-v0_19/
├── model.int8.onnx          ~80 MB   ← DOWNLOADED on first launch
├── voices.bin               ~5.5 MB  ← BUNDLED in app
├── tokens.txt               ~1 KB    ← BUNDLED
├── espeak-ng-data/          ~1 MB    ← BUNDLED (directory of ~50 files)
├── LICENSE
└── README.md
```

**Bundled vs downloaded rationale:**
- Only `model.int8.onnx` is large enough to matter for APK/IPA size. Bundling it blows past Google Play's 150 MB AAB limit uncompressed.
- Everything else (~6.5 MB total) is small and static. Bundling removes a failure mode.
- Runtime layout: after download, everything sits under `<ApplicationSupportDirectory>/kokoro-en-v0_19/` so sherpa_onnx sees one directory tree. The bundled assets are **copied from `rootBundle` to app support on first run** — sherpa_onnx requires real filesystem paths (cannot read from the Flutter asset bundle directly). [VERIFIED from official flutter-examples/tts/model.dart: `copyAllAssetFiles()`]

### 11 voices (sids 0–10) [VERIFIED: k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html]

| sid | name | | sid | name |
|-----|------|-|-----|------|
| 0 | af | | 6 | am_michael |
| 1 | af_bella | | 7 | bf_emma |
| 2 | af_nicole | | 8 | bf_isabella |
| 3 | af_sarah | | 9 | bm_george |
| 4 | af_sky | | 10 | bm_lewis |
| 5 | am_adam | | | |

Prefix legend: `a*` = American, `b*` = British; `f_` = female, `m_` = male; `af`/`am`/`bf`/`bm` alone = generic of that cohort.

**Voice picker mapping:** expose human-readable labels in UI (e.g., "Bella (American, female)"), store `sid` (int) plus `voice_id` (stable string e.g. `"af_bella"`) in Drift. Store the string id, not the int — sids could re-order in a future model.

### Download URL (v1 plan)
Base URL pattern: `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-en-v0_19.tar.bz2` [CITED: CLAUDE.md + confirmed via k2-fsa docs]

**Planner action:** Pin the exact SHA-256 of the `.tar.bz2` in source (e.g., `lib/features/tts/model/model_manifest.dart`). The SHA must be captured **as a build-time step during Phase 4** — download once, run `shasum -a 256`, commit the hex digest. If upstream retags, the hash mismatch refuses the download until a code change rolls a new hash. `[ASSUMED]` — exact current SHA is not pinned in research; must be captured during implementation.

**Download protocol:** single `.tar.bz2`, not the raw `model.int8.onnx`. Extract with `package:archive` (already a direct dep) into a `.partial/` directory, verify SHA of the archive (not just the .onnx), then atomic-rename to the final directory on success.

## Architecture Patterns

### Recommended feature layout
```
lib/
├── core/
│   ├── playback_state.dart            # PlaybackState record + playbackStateProvider (CD-04 seam)
│   └── text/
│       ├── sentence.dart              # from Phase 3
│       └── sentence_splitter.dart     # from Phase 3 — Phase 4 hardens fixtures
├── features/
│   ├── tts/
│   │   ├── model/
│   │   │   ├── model_manifest.dart    # URL + pinned SHA-256 + voice catalog
│   │   │   ├── model_downloader.dart  # http streaming + hash + .partial + resume
│   │   │   └── model_assets.dart      # copy bundled voices.bin/tokens.txt/espeak-ng-data to app support
│   │   ├── isolate/
│   │   │   ├── messages.dart          # sealed-class commands + events (D-13)
│   │   │   ├── tts_worker.dart        # isolate entry point — owns OfflineTts
│   │   │   └── tts_client.dart        # UI-side handle: spawn, send, listen, dispose
│   │   ├── queue/
│   │   │   ├── tts_queue.dart         # pre-synth next + LRU ring buffer of last 3
│   │   │   └── tts_cache.dart         # {app_support}/tts_cache/{book}/{chapter}/{sentence}.wav
│   │   ├── audio/
│   │   │   ├── wav_wrap.dart          # CD-03: Float32 → int16 → 44-byte WAV header
│   │   │   ├── audio_handler.dart     # audio_service BaseAudioHandler subclass
│   │   │   └── audio_session_setup.dart  # audio_session speech category + interruption wiring
│   │   ├── providers/
│   │   │   ├── tts_worker_provider.dart   # Riverpod — spawns/disposes worker per reader
│   │   │   ├── voice_provider.dart        # resolves effective voice (per-book override → default)
│   │   │   └── speed_provider.dart        # same
│   │   └── ui/
│   │       ├── playback_bar.dart
│   │       ├── voice_picker_sheet.dart
│   │       ├── speed_picker.dart
│   │       └── model_download_modal.dart
│   └── reader/                         # NO imports from tts/ — reader only reads playbackStateProvider
└── ...
```

### Pattern 1: PlaybackState as single coordination seam (PBK-08 / CD-04)
```dart
// lib/core/playback_state.dart
class PlaybackState {
  final String? bookId;
  final int chapterIdx;
  final int sentenceIdx;
  final bool isPlaying;
  final double speed;
  final String voiceId;
  // ...
}

@riverpod
class PlaybackStateNotifier extends _$PlaybackStateNotifier {
  @override
  PlaybackState build() => const PlaybackState.idle();
  void setSentence(int i) => state = state.copyWith(sentenceIdx: i);
  // TTS calls setSentence; reader watches. No reverse dependency.
}
```
**Boundary contract:** reader imports `core/playback_state.dart` only. TTS writes; reader reads. Add a lint-enforced rule (simple string-grep in CI) that `lib/features/reader/**.dart` must not contain `features/tts`.

### Pattern 2: Isolate command/event protocol (D-13)
```dart
// lib/features/tts/isolate/messages.dart
sealed class TtsCommand {}
final class SynthSentence extends TtsCommand {
  final String text;
  final int sentenceIdx;  // for correlation
  final int voiceSid;
  SynthSentence(this.text, this.sentenceIdx, this.voiceSid);
}
final class Cancel extends TtsCommand {
  final int sentenceIdx;
  Cancel(this.sentenceIdx);
}
final class SetVoice extends TtsCommand { final int sid; SetVoice(this.sid); }
final class Dispose extends TtsCommand {}

sealed class TtsEvent {}
final class ModelLoaded extends TtsEvent {}
final class SentenceReady extends TtsEvent {
  final int sentenceIdx;
  final String wavPath;
  SentenceReady(this.sentenceIdx, this.wavPath);
}
final class TtsError extends TtsEvent {
  final int? sentenceIdx;
  final Object error;
  TtsError(this.sentenceIdx, this.error);
}
```
Pattern-match in `tts_client.dart` and worker handler. No `Map<String,dynamic>`.

**Critical isolate setup steps** (from upstream flutter-examples/tts/isolate_tts.dart [VERIFIED]):
1. `BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken)` — required for `path_provider` and `shared_preferences` to work inside the isolate.
2. Inside isolate: call `getApplicationSupportDirectory()` for model paths (don't pass paths from UI isolate — isolate boundaries can stale path strings on iOS backgrounding).
3. Construct `OfflineTtsKokoroModelConfig → OfflineTtsModelConfig → OfflineTtsConfig → sherpa_onnx.OfflineTts(config)`.
4. Post `ModelLoaded` to UI only after the config object is fully built.

### Pattern 3: Sherpa Kokoro config construction [VERIFIED from flutter-examples/tts/model.dart]
```dart
final kokoro = sherpa_onnx.OfflineTtsKokoroModelConfig(
  model: '$appSupport/kokoro-en-v0_19/model.int8.onnx',
  voices: '$appSupport/kokoro-en-v0_19/voices.bin',
  tokens: '$appSupport/kokoro-en-v0_19/tokens.txt',
  dataDir: '$appSupport/kokoro-en-v0_19/espeak-ng-data',
  lexicon: '',
);
final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
  vits: sherpa_onnx.OfflineTtsVitsModelConfig(),
  kokoro: kokoro,
  numThreads: 2,         // 2 is the upstream default; revisit on low-end devices
  debug: false,          // false in prod
  provider: 'cpu',       // CPU-only per constraint
);
final tts = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model: modelConfig));
```
### Pattern 4: Synthesize and WAV-wrap
```dart
final genConfig = sherpa_onnx.OfflineTtsGenerationConfig(
  sid: voiceSid,
  speed: 1.0,             // TTS-09: ALWAYS 1.0. Asserted in code.
);
final audio = tts.generateWithConfig(text: sentence, config: genConfig);
// audio.samples: Float32List, audio.sampleRate: int (24000 for Kokoro)
final wavBytes = wavWrap(audio.samples, sampleRate: audio.sampleRate);
final path = '$cacheDir/$bookId/$chapterIdx/$sentenceIdx.wav';
await File(path).writeAsBytes(wavBytes, flush: true);
// Post SentenceReady(sentenceIdx, path) back to UI.
```

### Pattern 5: WAV header (CD-03)
44-byte PCM WAV header layout (little-endian):
```
RIFF (4) | size-8 (4 LE) | WAVE (4) | fmt  (4) | 16 (4 LE) | 1 (2 LE) | channels=1 (2 LE)
| sampleRate (4 LE) | byteRate=SR*2 (4 LE) | blockAlign=2 (2 LE) | bitsPerSample=16 (2 LE)
| data (4) | dataSize (4 LE) | <int16 samples>
```
Convert Float32 → int16 with `(f.clamp(-1.0, 1.0) * 32767).toInt()`. Never skip the clamp — Kokoro occasionally overshoots ±1.0 on fricatives and the integer wraparound produces audible clicks.

### Pattern 6: just_audio feed
```dart
final player = AudioPlayer();
await player.setSpeed(userSpeed);       // TTS-09: the only speed knob
await player.setAudioSource(AudioSource.file(path));
await player.play();
```
Per-sentence `setAudioSource` is cheap enough at 24kHz/mono. Do **not** use `ConcatenatingAudioSource` for the sentence queue — it makes skip-sentence fiddly and fights the pre-synth queue. Simpler model: one sentence per `AudioPlayer` cycle, listen for `ProcessingState.completed`, then advance `sentenceIdx` and set the next source.

### Pattern 7: audio_service integration [VERIFIED from pub.dev/packages/audio_service]
Subclass `BaseAudioHandler` (or `BaseAudioHandler` with the `SeekHandler` mixin). Inside the handler:
- `play()`, `pause()` forward to the internal `AudioPlayer` AND update `playbackState`.
- `skipToNext()` = next chapter (PBK-10).
- Keep a single `MediaItem` current: `mediaItem.add(MediaItem(id: bookId, title: bookTitle, artist: author, album: chapterName, artUri: Uri.file(coverPath)))`.
- `playbackState.add(PlaybackState(controls: [MediaControl.play, MediaControl.pause, MediaControl.skipToNext], ...))`.

Init in `main.dart`:
```dart
final handler = await AudioService.init(
  builder: () => MurmurAudioHandler(),
  config: const AudioServiceConfig(
    androidNotificationChannelId: 'dev.jmclaughlin.murmur.audio',
    androidNotificationChannelName: 'Playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  ),
);
```

### Pattern 8: audio_session speech category (PBK-12)
```dart
final session = await AudioSession.instance;
await session.configure(const AudioSessionConfiguration.speech());
session.interruptionEventStream.listen((e) {
  if (e.begin) {
    audioHandler.pause();
  } else if (e.type == AudioInterruptionType.pause || e.type == AudioInterruptionType.unknown) {
    audioHandler.play();     // auto-resume (D-19)
  }
});
session.becomingNoisyEventStream.listen((_) => audioHandler.pause());
```
[VERIFIED from pub.dev/packages/audio_session Apr 2026 listing]

### Anti-Patterns to Avoid
- **Don't use `StreamAudioSource`** — rejected by TTS-08 and CLAUDE.md. WAV-wrap + file is correct.
- **Don't call `generateWithConfig` on the UI isolate** — TTS-05 forbids it; it will jank the reader.
- **Don't cache WAVs forever** — CD-02 ring buffer with LRU + soft cap.
- **Don't use sherpa `length_scale` for user speed** — TTS-09 compound-speed trap.
- **Don't pass a path from UI isolate into the worker isolate's sherpa setup on iOS** — resolve inside the worker. [CITED: upstream example pattern]
- **Don't add `Semantics` at sentence level** — RDR-05 says paragraph-level. TTS reads the sentence text out loud; it should not change accessibility tree.
- **Don't `connectivity_plus` gate the download** — D-02 explicitly went honor-system.
- **Don't build a `BehaviorSubject` ad-hoc for `playbackState`** — Riverpod AsyncNotifier only (CD-04).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Neural TTS | Custom ONNX inference | `sherpa_onnx` | Phonemization + voice blending + token decoding is thousands of LOC. |
| Background audio on Android | Custom `Service` | `audio_service` | FG service + notification channels + MediaSession is platform-specific and version-sensitive. |
| Lock-screen controls on iOS | `MPNowPlayingInfoCenter` via method channel | `audio_service` | Already handles it. |
| Audio session category / interruption | Custom platform channel | `audio_session` | AVAudioSession + AudioManager focus is subtle; `AudioSessionConfiguration.speech()` has the right defaults. |
| WAV encoder | Custom bit-twiddling | `wav_wrap.dart` helper we write (CD-03) | This is the one we DO roll — it's 40 lines, well-bounded, unit-testable. The alternative (`package:wav`) is overkill for a 44-byte header. |
| Resumable HTTP download | Custom `Socket` code | `package:http` `Client.send(Request)` + `Range: bytes=...` header | `http` streams body; combine with `IOSink` to write to `.partial` with a periodic flush. |
| Hashing while streaming | Post-download hash re-read | `crypto.Sha256().convert(bytes)` or `crypto.AccumulatorSink<Digest>()` | Hash incrementally as bytes arrive; verify before rename. |
| tar.bz2 extraction | Custom bz2 | `package:archive` (already direct dep) | Handles both tar and bz2 via `BZip2Decoder` + `TarDecoder`. |

## Common Pitfalls

### Pitfall 1: `BackgroundIsolateBinaryMessenger` not initialized in worker
**What goes wrong:** `path_provider` / `shared_preferences` throw `MissingPluginException` the first time the worker isolate runs.
**Why:** Spawned isolates don't share the root isolate's platform-channel binding.
**Avoid:** At the top of the isolate entry point: `BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken)` where `rootIsolateToken = RootIsolateToken.instance!` is passed in via `Isolate.spawn`'s message.
**Warning sign:** Spike crashes on second-run after Flutter release mode.

### Pitfall 2: Kokoro `model.int8.onnx` file is ~80MB, ApplicationDocumentsDirectory might be iCloud-synced on iOS
**What goes wrong:** iCloud backs up the model file, consuming user iCloud quota.
**Why:** On iOS, `getApplicationDocumentsDirectory()` is backed up. `getApplicationSupportDirectory()` is NOT backed up — and is where upstream `sherpa-onnx` places models.
**Avoid:** Always use `getApplicationSupportDirectory()` for model + cache. Document as `lib/features/tts/model/paths.dart`. [VERIFIED: upstream model.dart uses `getApplicationSupportDirectory()`]

### Pitfall 3: SHA-256 verify AFTER write, not during
**What goes wrong:** Corrupted partial file gets SHA'd, passes (because we're SHAing exactly what's on disk), and we load a broken ONNX.
**Why:** Hash must be computed over the trusted bytes we receive from the network, then compared to the pinned digest BEFORE moving the file into place. Hashing the final written file defends against nothing the network could do, only against disk corruption.
**Avoid:** Pipe bytes through `crypto.Sha256().convert()` via a transformer at the same moment they're written to `.partial`. Verify digest, then atomic-rename. [CITED: CLAUDE.md §Risks]

### Pitfall 4: No cancellation in `sherpa_onnx.OfflineTts.generateWithConfig`
**What goes wrong:** D-12 assumed a `cancel()` API exists. **Verified absent** in the upstream flutter-examples [VERIFIED from tts.dart review above]. Calling `generateWithConfig` blocks the isolate until the full sentence is synthesized.
**Why:** Sherpa Generate API is synchronous from Dart's POV; the C++ side has no interrupt hook exposed via FFI.
**Avoid:** Treat D-12's "cancel in-flight" as the ambition, implement the fallback ("let current finish, discard result, start next") as the v1 path. Skip latency becomes ≤ (remaining synth time of current sentence). For a typical 10-word sentence on mid-range hardware this is ≤ 400ms — acceptable.
**Planner action:** Remove "cancel in-flight" from the plan's success criteria. Add a clear fallback behavior spec. If sherpa_onnx adds a cancel primitive in a future patch, revisit post-MVP.

### Pitfall 5: `just_audio.setSpeed()` pitch-distorts TTS at >1.5×
**What goes wrong:** Default just_audio speed uses platform native pitch-compensated algorithms, but on Android `SoundPool`-style fallback paths (or older Android versions) it pitches up the voice.
**Why:** Platform-specific resampler behavior. iOS uses AVAudioEngine (pitch-preserved); Android uses ExoPlayer `PlaybackParameters` which IS pitch-preserved on modern versions, but not always.
**Avoid:** Phase 4 testing must include a 2× speed check on both a recent Pixel and a real iOS device. If pitch distortion appears on Android, set `AudioPipeline` on ExoPlayer with `SonicAudioProcessor`. [ASSUMED — Android-specific behavior; validate on device during spike.]

### Pitfall 6: Android 14 foreground-service-type requirement
**What goes wrong:** Android 14+ requires `foregroundServiceType="mediaPlayback"` AND the `FOREGROUND_SERVICE_MEDIA_PLAYBACK` runtime permission declaration; otherwise the service is killed immediately.
**Why:** Android 14 tightened FG-service abuse mitigations.
**Avoid:** Verify Phase 1 FND-08 actually declared `FOREGROUND_SERVICE_MEDIA_PLAYBACK` in manifest. audio_service 0.18.18 already expects this. [VERIFIED: pub.dev audio_service docs]

### Pitfall 7: iOS UIBackgroundModes+ audio session category mismatch
**What goes wrong:** `UIBackgroundModes = [audio]` is in Info.plist, but AVAudioSession category is `ambient` or `playback+mix`, so iOS pauses audio when screen locks.
**Why:** Both need to agree. `AudioSessionConfiguration.speech()` uses `.playback` category which is correct.
**Avoid:** Configure audio_session BEFORE the first play call. [CITED: CLAUDE.md §Risks #4]

### Pitfall 8: Dart `Isolate` memory is not reclaimed when the isolate exits, unless explicitly
**What goes wrong:** Long-lived worker isolate holds ~200MB (model weights) resident. On reader close, the isolate must `exit()` AND the receiving `ReceivePort`s must `.close()`, AND `OfflineTts.free()` must be called before the isolate exits.
**Why:** `OfflineTts.free()` releases the native C++ state. Without it, RAM stays leaked until process death.
**Avoid:** `Dispose` command → worker calls `_tts.free()` → worker posts `Dispose.ack` → worker calls `Isolate.exit()`. UI side closes its `ReceivePort` on ack receipt. Wire `ref.onDispose` in Riverpod provider to send Dispose.

### Pitfall 9: Sentence splitter regression between Phase 3 and Phase 4
**What goes wrong:** Phase 4 extends the fixture set to 500+; new cases break existing behavior.
**Why:** The splitter is shared — reader (Phase 3) and TTS both consume it. Changes bleed into the reader.
**Avoid:** Run the full Phase 3 splitter test suite before and after the Phase 4 fixture expansion. Any delta requires explicit acknowledgement in the plan. [CITED: Phase 3 D-02]

### Pitfall 10: `voices.bin` file size is ~5.5MB, not ~3MB (CLAUDE.md correction)
**What goes wrong:** APK size estimates under-count by ~2.5MB.
**Avoid:** Budget correctly. Bundled assets = voices.bin (~5.5MB) + tokens.txt (~1KB) + espeak-ng-data (~1MB) = ~6.5MB added to the app binary. [VERIFIED: CLAUDE.md]

## Runtime State Inventory

> Phase 4 is mostly greenfield, but it adds persistent state — inventoried here so future refactors don't miss it.

| Category | Items | Action |
|----------|-------|--------|
| Stored data | (1) `books.voice_id TEXT NULL`, `books.playback_speed REAL NULL` — Drift migration adds. (2) `shared_preferences` keys: `default_voice_id`, `default_speed`, `model_installed_flag`. (3) Filesystem: `<appSupport>/kokoro-en-v0_19/` (model + bundled assets), `<appSupport>/tts_cache/{book}/{chapter}/{sentence}.wav` (ring buffer). | Drift migration bumps schemaVersion; stepByStep handler adds the two columns. Existing books get NULL = use default. |
| Live service config | None — no external services. | None. |
| OS-registered state | (1) Android: foreground service `com.ryanheise.audioservice.AudioService` + notification channel `dev.jmclaughlin.murmur.audio`. (2) iOS: `AVAudioSession` category set per reader session. | Verify Phase 1 manifest already declares service; add notification channel ID declaration if not present. |
| Secrets/env vars | None — no API keys, no tokens. | None. |
| Build artifacts | Bundled assets under `assets/kokoro/` (voices.bin, tokens.txt, espeak-ng-data/*). Pubspec `flutter: assets:` section must list them. | Add to pubspec.yaml `flutter.assets` list; ship test checks that each asset is reachable via `rootBundle.load`. |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Internet (one-time) | Model download | Expected at first launch | — | Retry flow (TTS-04) + descriptive error |
| ~85MB free disk | Model + cache | Expected | — | Error modal if insufficient |
| ONNX runtime (bundled by sherpa_onnx) | TTS synthesis | ✓ (transitive via sherpa_onnx) | — | — |
| espeak-ng data | Kokoro phonemization | ✓ (we bundle it) | — | — |
| physical Android device | QAL-04 on-device test | Jake has one [VERIFIED: memory file] | — | — |
| physical iOS device | Phase 4 iOS validation | ✗ (per no-Mac constraint) | — | CI-only for iOS this phase; real iOS testing deferred or via borrowed device |

**Missing with fallback:**
- iOS physical-device validation — continues under workflow_dispatch xcarchive CI (Phase 1 D-06 pattern).

**Missing without fallback:** None that block v1 Phase 4 implementation of the Android path.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` 3.41 + `test` (bundled) |
| Config file | `analysis_options.yaml` (existing) |
| Quick run command | `flutter test test/features/tts/ -x` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TTS-01 | First-launch download modal appears once; honors Prefer Wi-Fi label | widget + integration | `flutter test test/features/tts/ui/model_download_modal_test.dart` | ❌ Wave 0 |
| TTS-02 | Model URL fetches, SHA-256 verifies, stored under `<appSupport>/kokoro-en-v0_19/` | unit (mocked http) | `flutter test test/features/tts/model/model_downloader_test.dart` | ❌ Wave 0 |
| TTS-03 | `voices.bin`, `tokens.txt`, `espeak-ng-data/*` bundled and copyable to app support | asset test | `flutter test test/features/tts/model/model_assets_test.dart` | ❌ Wave 0 |
| TTS-04 | Interrupted download cleans `.partial`, resumable via Range | unit (mocked http) | `flutter test test/features/tts/model/model_downloader_resume_test.dart` | ❌ Wave 0 |
| TTS-05 | Synthesis runs on worker isolate; UI isolate never calls sherpa directly | lint rule + unit | `flutter test test/features/tts/isolate/tts_client_test.dart` + grep CI | ❌ Wave 0 |
| TTS-06 | `SentenceSplitter` passes 500+ fixtures | unit (parametric) | `flutter test test/core/text/sentence_splitter_500_test.dart` | ⚠ Extend existing |
| TTS-07 | Queue pre-synth next + ring buffer last 3 + LRU eviction + 20MB soft cap | unit | `flutter test test/features/tts/queue/tts_queue_test.dart` | ❌ Wave 0 |
| TTS-08 | `wavWrap(Float32List, 24000)` produces a byte-exact 44-byte header + int16 PCM; WAV plays via just_audio | unit + manual | `flutter test test/features/tts/audio/wav_wrap_test.dart` | ❌ Wave 0 |
| TTS-09 | `length_scale=1.0` asserted; UI speed only flows via `just_audio.setSpeed()` | unit (grep + assertion test) | `flutter test test/features/tts/audio/speed_ownership_test.dart` | ❌ Wave 0 |
| TTS-10 | First-sentence latency <300ms | manual-only on device | (device script, not automated) | n/a |
| PBK-01 | Playback bar renders play/pause + scrubber + speed selector | widget | `flutter test test/features/tts/ui/playback_bar_test.dart` | ❌ Wave 0 |
| PBK-02 | Skip ± sentence updates `playbackStateProvider.sentenceIdx` correctly | widget + notifier | `flutter test test/features/tts/ui/playback_bar_skip_test.dart` | ❌ Wave 0 |
| PBK-03 | Voice picker lists 11 voices, preview plays <2s, cached on second tap | widget + integration | `flutter test test/features/tts/ui/voice_picker_test.dart` | ❌ Wave 0 |
| PBK-04 | Per-book voice + speed persist to Drift `books.voice_id`/`books.playback_speed` | drift + provider | `flutter test test/features/tts/providers/per_book_override_test.dart` | ❌ Wave 0 |
| PBK-08 | `playbackStateProvider` is single coordination seam; reader does not import `features/tts/**` | static (grep in CI) + provider | `flutter test test/core/playback_state_test.dart` + grep rule | ❌ Wave 0 |
| PBK-09 | Audio continues when backgrounded | manual-only on device | (device script) | n/a |
| PBK-10 | Lock-screen shows title/author/chapter + play/pause/next-chapter | manual-only on device | (device script) | n/a |
| PBK-12 | Interruption → pause → auto-resume via audio_session mock | unit | `flutter test test/features/tts/audio/session_interruption_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/features/tts/ -x` (fast)
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green + device checklist signed off before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/features/tts/ui/*` — widget test harness (playback bar, voice picker, download modal)
- [ ] `test/features/tts/model/*` — model downloader + assets tests
- [ ] `test/features/tts/isolate/*` — isolate client tests (worker mocked via test-double that responds to commands without spawning a real isolate — real isolate behavior gets a separate integration test)
- [ ] `test/features/tts/queue/*` — queue + cache LRU tests
- [ ] `test/features/tts/audio/*` — wav_wrap + speed ownership + session
- [ ] `test/features/tts/providers/*` — per-book override tests
- [ ] `test/core/playback_state_test.dart` — seam tests
- [ ] `test/core/text/sentence_splitter_500_test.dart` — extended fixture suite (replaces/augments existing `sentence_splitter_test.dart`)
- [ ] CI rule: grep `features/reader/**.dart` for `features/tts` → fail build (enforces PBK-08 boundary)

**Framework install:** none — `flutter_test` already present.

## Code Examples

See Patterns 1–8 above. All reference implementations are either:
- Verified against upstream `k2-fsa/sherpa-onnx/flutter-examples/tts` (Patterns 2–4), or
- Standard patterns from `audio_service` / `audio_session` pub.dev docs (Patterns 7–8).

## State of the Art

| Old | Current | Changed | Impact |
|-----|---------|---------|--------|
| `tts.generate(text, sid, speed)` positional API | `tts.generateWithConfig(text, config: OfflineTtsGenerationConfig(sid, speed, silenceScale))` | sherpa_onnx 1.12.31 (~Mar 2026) | Use only the post-refactor API. [VERIFIED: flutter-examples/tts.dart Apr 2026] |
| Android < 14 foreground services | Android 14+ requires `foregroundServiceType="mediaPlayback"` + matching permission | Android 14 release | Must declare both or service is killed. |
| `StreamAudioSource` for PCM streaming | WAV-wrap + `AudioSource.file` | just_audio 0.10.x | Stream source is experimental; file source is stable. [VERIFIED: REQUIREMENTS.md TTS-08] |

**Deprecated/outdated:**
- Any sherpa_onnx code <1.12.31 using the old positional `generate()` signature.
- Any guide suggesting `flutter_tts` for neural voices (out of scope).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | sherpa_onnx 1.12.36 Flutter API still matches the 1.12.31 Generate API refactor signature | Pattern 3, 4 | Wave 0 spike fails immediately; fallback to FFI or `kokoro_tts_flutter`. Hours, not days, to detect. |
| A2 | SHA-256 of `kokoro-int8-en-v0_19.tar.bz2` not pinned in this research — must be captured during implementation | §Download URL | Low. Capturing the hash is a one-line implementation step. |
| A3 | Android `just_audio.setSpeed(2.0)` preserves pitch on all supported Android versions | Pitfall 5 | Moderate. Needs on-device validation; may require custom `AudioPipeline`. |
| A4 | `connectivity_plus` can be safely omitted (honor-system per D-02) | §User Constraints | None — accepted by user. |
| A5 | `voices.bin` single file contains all 11 voice style vectors (not 11 separate files) | §Asset Layout | Low. Verified by official docs layout. |
| A6 | `audio_service` 0.18.18 still compatible with just_audio 0.10.5 in 2026 | §Version Compatibility | Low. Both active packages, well-known pairing. [VERIFIED: CLAUDE.md version compat table] |
| A7 | The pinned GitHub Release URL for kokoro-int8-en-v0_19.tar.bz2 is stable and won't 404 | §Download URL | Moderate. Mitigation: user-facing retry + detailed error. Self-hosted mirror explicitly deferred (D-04). |

## Open Questions (RESOLVED)

1. **Does `sherpa_onnx` 1.12.36 expose ANY cancellation hook?** — RESOLVED via 04-00 Task 3 device spike; fallback "discard-on-completion" path committed in 04-04 must_haves; 04-00 Task 3 gate re-opens D-12 if a primitive is found.
   - What we know: upstream `flutter-examples/tts` does not demonstrate one. `generateWithConfig` appears synchronous.
   - What's unclear: is there a newer method signature (`generateWithCallback` is mentioned for TTS-13) that supports early-exit?
   - Recommendation: Wave 0 spike writes a no-UI test that calls `generateWithConfig` for a long (~20-word) sentence and attempts to interrupt. If impossible, lock D-12's fallback as v1 behavior.

2. **Preview sentence exact wording** — RESOLVED: preview sentence committed to `ModelManifest.previewSentence` in 04-01.
   - CONTEXT says "TBD during Phase 4 build."
   - Recommendation: planner picks one, commits to source with a comment flagging it's reviewable. Candidate: "Welcome to murmur. This is how I sound reading your books." (14 words, brand-forward, mix of short + long vowels for voice differentiation.)

3. **Notification channel name + icon** — RESOLVED: channel name `Playback`, icon `mipmap/ic_launcher` in 04-08 Task 1.
   - Required by audio_service on Android.
   - Recommendation: `'Playback'` channel name, `@mipmap/ic_launcher` icon (existing from Phase 1). Planner confirms during plan.

4. **On-device cold-start latency target on low-end Android** — RESOLVED: measured in 04-09 Section B via `tool/measure_tts_latency.dart`.
   - TTS-10 says <300ms on mid-range. Budget for entry-level phones is unspecified.
   - Recommendation: measure during spike; if entry-level blows past 500ms, document in PROJECT.md and move on — spec says "mid-range."

## Security Domain

> CLAUDE.md + config show no `security_enforcement` key; treating as default (enabled for the parts that apply).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (no accounts, ever) |
| V3 Session Management | no | — |
| V4 Access Control | no | — (local-only, no server) |
| V5 Input Validation | partial | Validate model SHA-256 (TTS-02); validate EPUB-derived text before passing into sherpa (already handled Phase 2 DOM sanitization — sentences are safe strings) |
| V6 Cryptography | yes | `crypto.Sha256` for model integrity; do NOT roll custom hash code |
| V8 Data Protection | partial | No PII is ever collected. Model file is not sensitive; cache is not sensitive. Nothing to protect but also nothing to leak. |

### Known Threat Patterns for {stack}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Model substitution attack (upstream GitHub replaces the tarball with malicious ONNX) | Tampering | Pin SHA-256 in source; refuse to install on hash mismatch; user sees "model verification failed, update required" error. |
| Path traversal via filename in tarball | Tampering | `package:archive` TarDecoder accepts arbitrary filenames; validate each entry's path is inside the extraction root before writing (same defense Phase 3 used for image paths). |
| MITM on first download | Tampering | HTTPS only (`https://github.com/...`); system trust store; SHA-256 is belt-and-braces. |
| Denial-of-service via oversized download | Availability | Cap download at 150MB (model is ~103MB; anything larger = bail). |
| Local WAV file pollution | Availability | Cache cap (20MB per book, CD-02) + wipe on book delete. |
| Sensitive text in logs | Information Disclosure | Don't log sentence text at INFO level. Crash logger already configured to stay local-only per Phase 1. |

## Sources

### Primary (HIGH)
- `CLAUDE.md` — project-specific tech stack research (pinned versions, risks, gotchas, version compat matrix)
- `.planning/PROJECT.md` — privacy + network constraints
- `.planning/REQUIREMENTS.md` — TTS-* / PBK-* acceptance criteria
- `.planning/phases/04-tts-engine-playback-foundation/04-CONTEXT.md` — locked decisions D-01..D-19 + CD-01..CD-04
- `.planning/phases/03-reader-with-sentence-span-architecture/03-CONTEXT.md` — Sentence model, splitter seam, immersive mode semantics
- `.planning/phases/02-library-epub-import/02-CONTEXT.md` — `books` Drift table schema and cover path
- `.planning/phases/01-scaffold-compliance-foundation/01-CONTEXT.md` — Info.plist + manifest baseline
- pub.dev/packages/sherpa_onnx — 1.12.36, 2026-04-08 [WebFetch]
- pub.dev/packages/audio_service — 0.18.18 [WebFetch]
- pub.dev/packages/audio_session — 0.2.3 [WebFetch]
- github.com/k2-fsa/sherpa-onnx/flutter-examples/tts/lib/model.dart — Kokoro config construction [WebFetch]
- github.com/k2-fsa/sherpa-onnx/flutter-examples/tts/lib/tts.dart — `generateWithConfig` API + absence of cancel [WebFetch]
- github.com/k2-fsa/sherpa-onnx/flutter-examples/tts/lib/isolate_tts.dart — isolate pattern [WebFetch]
- k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html — voice catalog [WebFetch]

### Secondary (MEDIUM)
- CLAUDE.md claim that `voices.bin` is ~5.5MB (not 3MB) — correcting earlier PROJECT.md figure
- Android 14 FGS requirements — well-known, not re-verified this session

### Tertiary (LOW) — flagged for validation during spike
- Exact Android pitch-preservation behavior of `just_audio.setSpeed()` across Android versions (Pitfall 5)
- Current SHA-256 of `kokoro-int8-en-v0_19.tar.bz2` (Assumption A2)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions verified against pub.dev 2026-04
- Architecture: HIGH — Patterns 2–4 verified against upstream official example
- Isolate shape: HIGH — verified against official isolate_tts.dart
- Cancellation support: HIGH (negative claim) — verified absent in official example
- Pitfalls: MEDIUM-HIGH — mixture of verified-upstream-patterns and experience-based warnings
- On-device behavior (latency, pitch preservation): LOW — must be measured during Wave 0 spike

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (30 days — sherpa_onnx release cadence means this should be re-verified if implementation slips past mid-May)
