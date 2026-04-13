# Phase 4: TTS Engine & Playback Foundation - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Kokoro-82M on a long-lived worker isolate reads any chapter aloud with curated voices, adjustable speed, sentence skip, background audio, and lock-screen controls — wired to the reader through a single shared `playbackStateProvider`. Covers TTS-01..10 and PBK-01/02/03/04/08/09/10/12. Sentence highlighting and auto-scroll (PBK-05/06/07) belong to Phase 5. Sleep timer (PBK-11) belongs to Phase 6.

</domain>

<decisions>
## Implementation Decisions

### Model Download UX
- **D-01:** Download prompt appears during **first-launch onboarding** — shown once, right after install, framed as "required to hear books read aloud." Not at first-play-tap, not as a passive Library banner. (Pairs with Phase 6 onboarding polish.)
- **D-02:** Wi-Fi toggle is **honor-system, not enforced**. Label it **"Prefer Wi-Fi"**, not "Wi-Fi only" — the toggle will only control auto-retry behavior on cellular, not block the download. This is deliberate: simpler code, no `connectivity_plus` dep required for v1. Honesty in the label is the cost. TTS-01 wording should be adjusted to reflect this during planning.
- **D-03:** Download is presented as a **full-screen modal** with percent + MB-of-total, cancel button, and "you can leave this screen" note. Hash-verify + atomic rename after bytes complete. Blocking is fine — this happens exactly once per install.
- **D-04:** Model is fetched **direct from k2-fsa sherpa-onnx GitHub Releases** with a **pinned SHA-256 in source**. No self-hosted mirror in v1. SHA-256 pin is the integrity defense; if upstream retags, app refuses the download until a new release pins the new hash.
- **D-05:** Download is **resumable** (HTTP Range requests, `.partial` suffix) and **cleans up partial files on failure/cancel** (TTS-04).

### Voice Picker & Previews
- **D-06:** Ship **all 11 voices from v0_19** — skip the "curation" step. PROJECT.md's "~10" was a round number; 11 is close enough and saves a voice-listening curation session. Final list verified at Phase 4 build time from `voices.bin`.
- **D-07:** Previews are **live-synthesized on first tap, then cached** as WAVs under app support dir keyed by voice-id. First tap pays ~300–800ms synth cost; subsequent taps are instant. No bundle bloat, exercises the same synthesis path as real playback (useful for shakedown).
- **D-08:** Preview sentence is a **single fixed branded sentence** (exact wording to be chosen during Phase 4, ~10–15 words, e.g., "Welcome to murmur. This is how I sound reading your books."). Same sentence for every voice so A/B comparison is fair.
- **D-09:** Voice picker lives in **two places**: (a) global default in **Settings**, (b) per-book override in a **sheet opened from the playback bar** inside the reader, with an explicit "use default" reset. PBK-04 (per-book override) is satisfied by the bar sheet; PBK-03 (curated list + <2s previews) is the same widget used in both locations.

### Worker Isolate & Latency
- **D-10:** The long-lived TTS worker isolate is **spawned on reader open and torn down on reader close** (or after a short background-timeout). Sherpa model load happens at isolate spawn. Not spawned at app start (RAM waste for users browsing library), not spawned per-play (fails TTS-10 cold-start). Release of Sherpa native resources on teardown is mandatory — matches the Riverpod 3 disposal semantics chosen in the stack.
- **D-11:** First-sentence <300ms latency (TTS-10) is achieved by **pre-synthesizing sentence 0 on chapter load**. When the reader loads a chapter (or resumes at saved position), the isolate starts synth of the first visible sentence in background. Play tap → audio is already on disk, `just_audio` starts immediately. Works across both cold and warm isolate states.
- **D-12:** **Skip-sentence mid-synthesis cancels in-flight synth** (via Sherpa Generate API cancellation hook) and starts synth of the target sentence. Partial CPU waste on the cancelled sentence (~100ms) is acceptable for responsive skip UX. **Spike requirement:** verify sherpa_onnx Flutter bindings actually expose working cancellation before committing — if they don't, fall back to "finish current, discard result." Flag this in RESEARCH.md.
- **D-13:** UI ↔ worker isolate communication uses **SendPort + Dart sealed-class command/event messages**. Commands: `SynthSentence`, `Cancel`, `SetVoice`, `Dispose`. Events: `SentenceReady(path)`, `Error(e)`, `ModelLoaded`. Pattern-match in handler. No `Map<String, dynamic>` stringly-typed messages.

### Playback Surface
- **D-14:** Playback bar is a **persistent mini-bar docked at the bottom of the reader** (~48–56px). Shows play/pause, chapter progress scrubber (PBK-01), skip ± sentence (PBK-02), and speed selector. Visible from reader open; before first play, the play button is the clear affordance.
- **D-15:** Under Phase 3 immersive mode (D-10 of Phase 3: tap-center toggles app bar), the **playback bar toggles together with the app bar** — chrome is a single concept. Lock-screen and Bluetooth controls remain functional during immersive mode, so users aren't stranded.
- **D-16:** Tablet-vs-phone: playback bar layout mirrors the chapter-navigation pattern from Phase 3 — tablet shows all controls inline (skip, scrubber, speed, voice); phone shows play/pause + scrubber + a "more" button that opens a sheet for skip/speed/voice. No divergent widget — one responsive `PlaybackBar` reading `shortestSide`.

### Lock-Screen & Audio Session
- **D-17:** Lock-screen control set is **spartan**: play/pause + next-chapter. No skip-sentence, no prev-chapter in v1 (too fine-grained for lock-screen; iOS control-budget is tight). Matches PBK-10 verbatim.
- **D-18:** Lock-screen **metadata**: book title, author, current chapter name. **Artwork**: book cover from the Phase 2 import (cached under app docs); fallback to app icon if no cover was extracted. Use `audio_service`'s `MediaItem` with `artUri: file://...`.
- **D-19:** Audio session config via `audio_session` package using the **speech playback category** (not "ambient", not "playback+mix"). **Interruptions** (incoming call, Siri, other media starting) **pause murmur and auto-resume on interruption-end** (PBK-12). No ducking — TTS under music is unintelligible. **Wired headphone unplug and Bluetooth disconnect** both trigger pause.

### Claude's Discretion
- **CD-01:** Per-book preference storage (voice, speed overrides per PBK-04). Default approach: **add `voice_id TEXT NULL` and `playback_speed REAL NULL` columns to the existing `books` Drift table via a Drift migration**. NULL = fall back to global default (from `shared_preferences`). Books imported in Phase 2 get NULL on migration, which is the correct "use default" state. No separate `book_preferences` table — overkill for two fields.
- **CD-02:** Ring-buffer / cache management (TTS-07). Synthesized sentence WAVs land under `{app_support_dir}/tts_cache/{book_id}/{chapter_idx}/{sentence_idx}.wav`. Keep last 3 played + up to 2 pre-synthesized ahead; evict older on LRU basis. Wipe the book's cache on book deletion (Phase 2 delete flow). Soft cap: ~20MB per book.
- **CD-03:** WAV header wrapping — single helper `wavWrap(Float32List pcm, int sampleRate=24000) -> Uint8List` that writes the 44-byte PCM WAV header in front of int16-converted samples. Lives in `lib/features/tts/audio/wav_wrap.dart`. Unit-tested against a known-good WAV.
- **CD-04:** Shared `playbackStateProvider` (PBK-08) — Riverpod `AsyncNotifierProvider` emitting a `PlaybackState { bookId, chapterIdx, sentenceIdx, isPlaying, speed, voiceId }`. TTS feature writes; reader feature reads. No reverse dependency (reader doesn't import `tts/`; TTS doesn't import `reader/`). Both depend on `core/playback_state.dart` only.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & Requirements
- `.planning/ROADMAP.md` §Phase 4 — goal, success criteria, requirements list
- `.planning/REQUIREMENTS.md` TTS-01..10, PBK-01/02/03/04/08/09/10/12 — acceptance criteria per requirement
- `.planning/PROJECT.md` — "neural voice, fully offline, no accounts" constraint; no-network-post-model-download hard rule
- `CLAUDE.md` §Tech Stack — sherpa_onnx ^1.12.36, just_audio ^0.10.5, audio_service ^0.18.18 pinned; Risks §1 (sherpa_onnx Flutter maturity), §2 (PCM→WAV bridging), §4 (audio_service iOS quirks)

### Prior Phase Decisions That Bind This Phase
- `.planning/phases/03-reader-with-sentence-span-architecture/03-CONTEXT.md` D-02 — `SentenceSplitter` at `lib/core/text/sentence_splitter.dart` is shared; Phase 4 hardens with 500+ fixtures (TTS-06)
- `.planning/phases/03-reader-with-sentence-span-architecture/03-CONTEXT.md` D-03 — `Sentence` model at `lib/core/text/sentence.dart` is extensible; Phase 4 may add TTS-relevant fields
- `.planning/phases/03-reader-with-sentence-span-architecture/03-CONTEXT.md` D-05/D-06 — PageView-of-chapters + lazy chapter load; TTS pre-synth (D-11) hooks into chapter-load lifecycle
- `.planning/phases/03-reader-with-sentence-span-architecture/03-CONTEXT.md` D-10 — immersive-mode tap-center hides chrome; Phase 4 D-15 extends this to the playback bar
- `.planning/phases/02-library-epub-import/02-CONTEXT.md` — `books` Drift table schema (CD-01 migration extends this); cover file storage location (D-18 artwork)
- `.planning/phases/01-scaffold-compliance-foundation/01-CONTEXT.md` — Info.plist `UIBackgroundModes: audio`, Android `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission groundwork (must verify present or add)

### External Docs
- sherpa-onnx Kokoro model docs: https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html
- sherpa-onnx GitHub releases (tts-models tag): https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models — source of `kokoro-int8-en-v0_19.tar.bz2` (SHA-256 to be pinned during Phase 4 plan)
- audio_service README — Android foreground-service + iOS background-audio setup
- audio_session README — session categories and interruption events

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/core/text/sentence_splitter.dart` (Phase 3) — splitter used at render time; Phase 4 extends its fixture suite to 500+ but does NOT fork a separate splitter
- `lib/core/text/sentence.dart` (Phase 3) — `Sentence` record consumed by both reader and TTS
- Drift `books` table (Phase 2) — extended by CD-01 migration with `voice_id`, `playback_speed` columns
- Book cover files (Phase 2) — under app docs; referenced by lock-screen `MediaItem.artUri`
- Riverpod 3 providers + code-gen pipeline (Phase 1) — `playbackStateProvider` uses the same `@riverpod` annotation pattern
- `ThemeModeProvider` / `ClayColors` (Phase 1) — playback bar inherits themes; no separate TTS theme

### Established Patterns
- **Render-time derivation**: sentence splitting runs at render time, not import time (Phase 3 D-01). TTS uses the same pattern — no pre-cooked TTS-ready blob stored in Drift
- **Feature isolation via `core/`**: reader and TTS never import each other; they share state through `core/playback_state.dart` (CD-04 enforces this at the import boundary)
- **Phone/tablet responsive via `shortestSide`**: same shortest-side-600dp split as Phase 3 (sidebar vs. drawer) applied to playback bar layout (D-16)
- **Immersive-mode chrome toggle**: Phase 3 D-10 tap-center behavior extended to the playback bar (D-15)

### Integration Points
- **Reader → TTS**: reader publishes the active `Sentence` list + `sentenceIdx` via `playbackStateProvider`; TTS reads. No direct call from reader to TTS.
- **TTS → Reader** (Phase 5 groundwork): TTS writes `sentenceIdx` to `playbackStateProvider`; reader observes for future highlight/auto-scroll. In Phase 4, this write path exists but reader has no visual response (Phase 5 adds highlight + auto-scroll).
- **Settings surface**: Phase 4 adds voice picker + speed default to Settings; Phase 6 polishes it. Keep the Phase 4 additions factored so Phase 6 can style without rewriting.
- **Onboarding surface**: Phase 4 adds the model-download onboarding step. Phase 6 onboarding polish will absorb it — factor the download flow as a widget that can be used both standalone (first-launch) and embedded in later onboarding flows.

</code_context>

<specifics>
## Specific Ideas

- **Wi-Fi honor-system**: the user deliberately chose *not* to enforce with `connectivity_plus`. Label must read "Prefer Wi-Fi" (NOT "Wi-Fi only"). During planning, update TTS-01's REQUIREMENTS.md wording to match, or note the divergence explicitly.
- **Preview sentence**: exact branded text TBD during Phase 4 build, but should be recognizably "murmur" and short enough to synth in <1s on mid-range.
- **Sherpa cancellation spike**: first work item of Phase 4 must verify `sherpa_onnx` Flutter bindings actually support synth cancellation. If not, D-12 falls back to "let current finish, discard result." This is the single highest-risk uncertainty in the phase.

</specifics>

<deferred>
## Deferred Ideas

- **Sleep timer** (PBK-11) — Phase 6, already scoped there
- **Sentence highlighting & auto-scroll** (PBK-05/06/07) — Phase 5, already scoped
- **Non-English voices** (TTS-11) — future milestone
- **Advanced voices submenu** (TTS-12, all 53+ multilingual voices) — future milestone
- **Sub-sentence streaming via generateWithCallback** (TTS-13) — Phase 7 optimization if real users report long-sentence latency
- **Self-hosted model mirror** — considered and dropped for v1 (D-04). Revisit only if upstream k2-fsa releases are retagged or 404 in practice.
- **Curation of the 11 voices down to a "featured" few** — dropped in D-06. Revisit post-launch if user feedback shows some voices are clearly worse on prose.

</deferred>

---

*Phase: 04-tts-engine-playback-foundation*
*Context gathered: 2026-04-12*
