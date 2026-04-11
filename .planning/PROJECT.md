# murmur

## What This Is

murmur is a Flutter-based ebook reader for Android and iOS (phones and tablets) that turns EPUB files you already own into audiobooks using on-device neural TTS. It's for people who want to *listen* to books they own without handing their library, progress, or attention to a cloud service, subscription, or ad network. One-time purchase (~$3), no accounts, no backend, no telemetry.

## Core Value

You can point murmur at an EPUB and have it read to you — in a natural neural voice, fully offline, without ever creating an account. If the "tap a book, hear it read" loop doesn't feel good, nothing else matters.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

(None yet — ship to validate)

### Active

<!-- Current scope. Building toward these. The refined spec at murmur_app_spec.md is the source of truth; this section summarizes. -->

- [ ] Import DRM-free EPUBs via the system file picker and display them in a responsive library grid (phones + tablets, first-class on both)
- [ ] Parse EPUB metadata on import: title, author, cover art, chapter list — persist in local Drift DB
- [ ] Read any imported EPUB with good typography: font size, 3–4 font families, light / sepia / dark / OLED-black themes
- [ ] Chapter navigation: persistent sidebar on tablet, slide-over drawer on phone; tap-to-jump
- [ ] Reader text renders as `RichText` with **one `TextSpan` per sentence** — sentence spans are a first-class data structure from day one (commitment — see Key Decisions)
- [ ] Save reading progress to DB on page turn (debounced); resume on re-open
- [ ] Tap-center immersive mode toggles UI chrome
- [ ] Bundle Kokoro-82M voices.bin and tokens.txt; download the ~82MB int8 ONNX model on first launch via a clear one-time prompt
- [ ] Wrap Sherpa-ONNX Kokoro TTS behind a clean service with a `synthesize(String) → PCM` interface
- [ ] Sentence splitter in pure Dart: splits chapter text on `.`, `!`, `?` while handling abbreviations, decimals, quotes, etc.
- [ ] Sentence queue with pre-buffering: pre-synthesize next sentence while current one plays
- [ ] Stream PCM to `just_audio` for playback
- [ ] Playback bar: play/pause, chapter progress scrubber, speed selector (0.75× / 1× / 1.25× / 1.5× / 2×)
- [ ] Voice selector with ~10 curated English Kokoro voices, each with a short preview button
- [ ] TTS advances the reader position: as sentences complete, reader pages/scrolls to keep up
- [ ] Background audio via `audio_service`: TTS continues when app is backgrounded
- [ ] Lock screen media controls: play/pause, next chapter
- [ ] Currently-spoken sentence is visually highlighted in the reader; auto-scroll keeps it in viewport
- [ ] Bookmarks: tap to save position, list in the chapter panel/drawer, tap to jump
- [ ] Sleep timer: 15 / 30 / 45 min / end-of-chapter, with countdown shown in the playback bar
- [ ] Settings screen: font defaults, theme, TTS defaults (voice/speed), model storage info and re-download
- [ ] First-launch onboarding: model download prompt, import-first-book CTA
- [ ] Error boundaries on all async paths (import, TTS synthesis, file I/O); corrupt EPUB shows a snackbar, not a crash
- [ ] Local-only crash log the user can view and share manually (no Sentry, no Firebase, no network)
- [ ] Performance: reader scroll at 60fps on mid-range phone and tablet; TTS sentence-start latency < 300ms; no memory leak over a 2-hour session with a 1000-page EPUB
- [ ] Accessibility: semantic labels on all interactive elements, minimum 48×48px touch targets
- [ ] Signed Play Store AAB + App Store build, shipped as a paid (~$3) one-time purchase
- [ ] Store listings with phone + tablet screenshots and a truthfully-empty privacy policy

### Out of Scope

<!-- Explicit boundaries. Reasoning included to prevent re-adding. -->

- **Cloud sync of library, progress, or bookmarks** — privacy is the product; there is no backend, ever
- **Accounts, login, or any identity system** — see above
- **Telemetry, analytics, or crash reporting over the network** — both a principle and an architectural constraint
- **Non-EPUB formats (PDF, MOBI, AZW3, TXT, FB2)** — PDF alone would double reader complexity; others are niche
- **Non-English languages in v1** — keeps sentence splitting, text normalization, and voice curation tractable; can revisit post-launch
- **Audiobook (MP3 / M4B / AAC) import or playback** — murmur *generates* audio from text; it is not a general audiobook player
- **DRM'd books** — no, and never
- **Annotations, highlights, note-taking** — bookmarks only; avoids a whole category of UX scope
- **Reading stats, streaks, gamification** — wrong vibe for a focused reading app
- **Social features, sharing, export of activity** — see "privacy is the product"
- **Desktop builds (macOS / Windows / Linux)** — not the target form factor, not worth the platform burden
- **Phone OS system TTS as a fallback** — Kokoro neural quality is the differentiator; system voices are explicitly off the table

## Context

**Source spec:** `murmur_app_spec.md` at the repo root is the refined spec-driven development plan with 7 phases (Scaffold → Library → Reader → TTS → Highlighting → Polish → Distribution). This PROJECT.md is the living summary; the spec has implementation detail. MVP is Phase 5 complete.

**Technical environment:**
- Flutter + Dart, single codebase for Android and iOS
- State management: Riverpod
- Routing: go_router
- Local DB: Drift (SQLite)
- EPUB parsing: `epubx` + `package:html` with a custom sentence-span renderer (NOT `epub_view`, which transitively depends on `flutter_html`)
- TTS: `sherpa_onnx` Flutter bindings running Kokoro-82M int8 ONNX. Corrected bundle math from research: bundle `voices.bin` (~5.5MB) + `tokens.txt` (~1KB) + `espeak-ng-data/` (~1MB, required by sherpa-onnx at runtime); download `model.int8.onnx` (~80MB) on first launch with SHA-256 verification from a pinned k2-fsa GitHub release URL.
- Audio: `just_audio` via WAV-wrap + file-based `AudioSource.file` (NOT `StreamAudioSource`, which is experimental), `audio_service` for background + lock screen

**Dev environment (no host pollution):**
Jonathan is developing on Linux (CachyOS) and explicitly does not want Flutter/Dart/Android SDK installed globally on the host. Toolchain is managed via **`mise`** with a project-local `.mise.toml` (or `.tool-versions`) pinning Flutter, Dart, and Android `cmdline-tools` versions. Docker was considered and rejected: emulator-in-Docker needs KVM passthrough, real-device USB debugging needs `--privileged`, and the iOS path doesn't work in containers at all. `mise` achieves the "no host pollution" goal without the container friction that hurts Flutter mobile workflows specifically. Phase 1 will commit the `mise` config and document the setup in the README.

**iOS without a Mac:**
Jonathan does not currently own a Mac. The roadmap is built assuming iOS development routes through **GitHub Actions macOS runners** (free on public repos, ~$0.08/min private) for CI builds and TestFlight uploads until Phase 4 forces a decision about interactive iOS debugging. Phases 1–3 are iOS-agnostic and work fine in this arrangement. Phase 4 is the decision point — Sherpa-ONNX native linking + `audio_service` iOS quirks are exactly the kind of issues that are painful to debug through CI logs alone. At that point Jonathan will choose one of:
  1. Rent a cloud Mac mini (Scaleway M1, ~€0.10–0.24/hr) by the week for Phase 4 iOS debugging
  2. Buy a used Mac mini M1/M2 (~$400–600) if committed to iOS v1
  3. Defer iOS to v1.1 and ship Play Store only for v1, moving `QAL-06` (iOS App Store upload) from v1 requirements to v2

Until that decision, plan steps should NOT silently assume Mac access exists. `QAL-06` (iOS App Store upload) is the only v1 requirement that genuinely cannot happen without Mac access of some form.

**Relevant prior context:** Jonathan refined the app spec in this session — we explicitly added a Non-Goals section, committed to sentence-span rendering at Phase 3 (instead of deferring to Phase 5 and paying a rewrite), dropped `flutter_widget_from_html`, `epub_view`, and `cached_network_image` from the dependency list, and narrowed voice selection from 53 to ~10 curated English voices. Research then surfaced ~16 cross-cutting conclusions folded into REQUIREMENTS.md and ROADMAP.md.

**User feedback themes:** None yet — app has not shipped. Requirements are hypotheses until validated.

**Known issues to address:**
- Sherpa-ONNX Flutter bindings are young (1.10.42 added Kokoro example, 1.12.31 refactored the Generate API) — pin exact versions and build a TTS smoke-test harness on day 1 of Phase 4
- Sentence splitting is deceptively hard (24+ edge-case categories per PITFALLS research) — build a 500+ fixture regression suite in isolation before Phase 4
- EPUB HTML is genuinely messy; Phase 2 needs an `epubx` Dart-compatibility spike before parser code is written
- iOS paid-app review can be slower than Android; factor in for release timing
- iOS development is remote-only via CI until the Phase 4 Mac-access decision is made

## Constraints

- **Tech stack**: Flutter + Dart — single codebase lets one developer ship both stores; strong UI control needed for tablet typography
- **TTS engine**: Kokoro-82M via Sherpa-ONNX, int8 quantized — ~80MB model, sub-300ms latency, CPU-only, fully offline. System TTS is not an acceptable substitute.
- **Privacy / network**: Exactly one network call in the whole app — the one-time Kokoro model download on first launch. After that, airplane mode is a supported operating state.
- **Format**: EPUB only. DRM-free only. This is a hard line, not a "maybe later."
- **Language**: English only in v1. Non-English languages need their own splitter, normalizer, and curated voices — all out of scope for launch.
- **Distribution**: Paid one-time purchase, ~$3, Play Store + App Store. No IAP, no subscription, no free tier, no ads.
- **Form factor**: Android + iOS, phones and tablets. Phones are first-class, not a "fallback" layout. No desktop.
- **Team size**: Solo developer (Jonathan) with AI-assisted coding. Scope must fit that cadence.
- **Performance**: 60fps reader scroll on mid-range phones and tablets; TTS sentence-start latency < 300ms; no memory leaks over 2-hour sessions with 1000-page books.
- **Reader architecture**: The reader must treat sentences as a first-class data structure from Phase 3. No HTML-opaque renderers (`flutter_widget_from_html`, `flutter_html`, `epub_view`, webview). This is a commitment, not a preference — see Key Decisions.
- **Dev environment**: Flutter / Dart / Android SDK must NOT be installed globally on the Linux host. All toolchain lives under a project-local `mise` config. Docker is explicitly rejected as the sandbox. See Context → Dev environment for rationale.
- **Apple hardware**: No Mac currently available. iOS builds route through CI (GitHub Actions macOS runners) for Phases 1–3. Phase 4 forces a Mac-access decision before iOS-specific debugging begins. Plans must not silently assume a Mac exists.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter (not React Native, native, or Kotlin Multiplatform) | Single codebase, excellent tablet typography control, mature widget system, solo-developer-friendly | — Pending |
| Kokoro-82M via Sherpa-ONNX for TTS (not OS system voices, not cloud TTS) | Neural quality is the product differentiator; offline is a hard constraint; Sherpa-ONNX has official Flutter bindings | — Pending |
| EPUB only, no PDF in v1 | PDF reflow/OCR/column detection would double reader complexity; EPUB is already a rich format | — Pending |
| English only in v1 | Keeps sentence splitting, text normalization, and voice curation tractable for a solo launch | — Pending |
| ~10 curated English voices, not all 53 Kokoro speakers | Curation is a feature; 53 undifferentiated voices is a worse UX than 10 good ones | — Pending |
| Fully local: no accounts, no cloud sync, no telemetry | Both a principle and an architectural constraint — there is simply no backend | — Pending |
| One-time paid purchase (~$3), no IAP, no subscription, no free tier | Aligned with privacy-by-construction value; matches Jonathan's opinion about subscription fatigue in this category | — Pending |
| Custom sentence-span reader renderer from Phase 3 (not `flutter_widget_from_html`) | `flutter_widget_from_html` cannot expose per-sentence spans; deferring this decision to Phase 5 would force a full reader rewrite when sentence highlighting lands | — Pending |
| Phones and tablets are both first-class form factors | "Phone fallback" layouts signal an afterthought; target audience reads on whichever device is in hand | — Pending |
| Local-only crash log (no Sentry, no Firebase, no network error reporting) | Telemetry-over-the-wire contradicts the privacy promise; local log + manual share preserves user agency | — Pending |
| `mise` for per-project Flutter toolchain (not Docker, not global install) | Jonathan explicitly wants no host pollution on the Linux dev machine. Docker was considered and rejected — KVM-in-container for emulators and `--privileged` for USB ADB are friction that mise avoids entirely while still isolating deps per project | — Pending |
| No Mac yet — iOS routes through GitHub Actions CI until Phase 4 decision point | Jonathan does not currently own a Mac. Phases 1–3 are iOS-agnostic so this doesn't block progress. Phase 4 is where Sherpa-ONNX + `audio_service` iOS-specific debugging becomes painful enough to need interactive Xcode access; decision (cloud Mac / buy Mac mini / defer iOS to v1.1) deferred until Phase 4 is imminent. `QAL-06` (iOS Store upload) is the only v1 requirement at risk of moving to v1.1 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-11 after adding dev environment + no-Mac constraints*
