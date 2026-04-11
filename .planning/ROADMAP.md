# Roadmap: murmur

## Overview

murmur ships in seven phases from a signed, compliance-ready scaffold (Phase 1) through library + EPUB import (Phase 2), a sentence-span reader committed to its permanent architecture from day one (Phase 3), on-device Kokoro-82M TTS with background audio and lock-screen control (Phase 4), two-way sentence highlighting and auto-scroll (Phase 5), polish + bookmarks + settings + onboarding + accessibility (Phase 6), and paid-app distribution on Play Store + App Store (Phase 7). The MVP is Phase 5 complete; Phases 6–7 take it from MVP to product. Every phase is tested on at least one physical iOS device and one physical Android device before being marked done, and compliance groundwork (Info.plist keys, manifest permissions, CI, local crash log) lands in Phase 1 so Phase 7 is upload-only.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Scaffold & Compliance Foundation** - Signed app scaffold with routing, DB, themes, and all store-compliance groundwork (completed 2026-04-11)
- [ ] **Phase 2: Library & EPUB Import** - Import EPUBs, parse them into a rich block IR, browse in a responsive grid
- [ ] **Phase 3: Reader with Sentence-Span Architecture** - Read any EPUB on phone or tablet with per-sentence TextSpan rendering from day one
- [ ] **Phase 4: TTS Engine & Playback Foundation** - Kokoro-82M on a worker isolate plays any chapter with background audio and lock-screen controls
- [ ] **Phase 5: Sentence Highlighting & Two-Way Sync** - The currently-spoken sentence is highlighted and kept in view; tap a sentence to start TTS there
- [ ] **Phase 6: Polish, Accessibility & Ship Readiness** - Bookmarks, sleep timer, settings, onboarding, accessibility, and multi-device matrix
- [ ] **Phase 7: Paid Distribution** - Signed AAB + IPA uploaded as a paid ~$3 app with privacy labels declaring "Data Not Collected"

## Phase Details

### Phase 1: Scaffold & Compliance Foundation
**Goal**: A signed Flutter app that launches on physical iOS and Android devices, navigates between placeholder Library / Reader / Settings routes, and has every compliance key and CI hook the later phases will need.
**Depends on**: Nothing (first phase)
**Requirements**: FND-01, FND-02, FND-03, FND-04, FND-05, FND-06, FND-07, FND-08, FND-09, FND-10
**Success Criteria** (what must be TRUE):
  1. User sees the murmur app launch from a signed debug build on a physical Android phone, with the correct bundle ID `dev.jmclaughlin.murmur`, display name `Murmur`, and a placeholder icon and splash. iOS physical-device install is superseded by Phase 1 D-05/D-06 and deferred to Phase 4 — the Phase 1 iOS deliverable is an unsigned `.xcarchive` from the `workflow_dispatch` CI job, not a device install.
  2. User can navigate between Library, Reader, and Settings placeholder screens via go_router, and hot reload preserves Riverpod state
  3. User can switch between light, sepia, dark, and OLED-black reader themes in the placeholder Settings and see the app chrome follow the system theme by default
  4. On every push to main, CI produces a signed debug Android AAB that is downloadable as a workflow artifact and installable on a physical Android device via bundletool. iOS CI is scaffolded as a manual `workflow_dispatch` job producing an unsigned `.xcarchive` — the full "signed IPA on every push" wording is restored in Phase 4 when Apple Developer Program enrollment lands.
  5. When a thrown exception occurs anywhere in the app, the error is written to an on-device crash log file (no network, no third-party SDK) that can later be surfaced in Settings
**Plans**: 9 plans (5 waves)
**Plans**:
- [x] 01-01-PLAN.md — Toolchain & scaffold gate (mise + flutter create + amendments)
- [x] 01-02-PLAN.md — Dependencies + codegen bootstrap (pubspec + analysis_options)
- [x] 01-03-PLAN.md — Android platform config (gradle + keystore + manifest)
- [x] 01-04-PLAN.md — iOS platform config (Info.plist + pbxproj + Podfile)
- [x] 01-05-PLAN.md — Theme system + fonts (4 ThemeData + Literata/Merriweather)
- [x] 01-06-PLAN.md — Drift database v1 (schemaVersion=1, zero tables, schema dump)
- [x] 01-07-PLAN.md — Crash logger (JSONL + 1MB rotation + triple-catch helpers)
- [x] 01-08-PLAN.md — App shell (main.dart + router + placeholder screens)
- [x] 01-09-PLAN.md — CI workflow + README (Android push + iOS workflow_dispatch)
**UI hint**: yes

### Phase 2: Library & EPUB Import
**Goal**: Users can import one or more DRM-free EPUBs (via file picker or system Share / Open-in), see them in a responsive library grid on phones and tablets, and have metadata + cover art persist across restarts — backed by a rich `Chapter { blocks: List<Block> }` intermediate representation validated against a 15-EPUB test corpus.
**Depends on**: Phase 1
**Requirements**: LIB-01, LIB-02, LIB-03, LIB-04, LIB-05, LIB-06, LIB-07, LIB-08, LIB-09, LIB-10, LIB-11
**Success Criteria** (what must be TRUE):
  1. User can import one or more DRM-free EPUBs via the system file picker in a single action (batch import), and can also import an EPUB by tapping Share / Open-in from another app (Files, Safari, email)
  2. After import, the library grid shows each book with cover art, title, author, and a progress ring — 2 columns on phone portrait, 3 on phone landscape, 4–6 on tablets — and survives an app restart
  3. User can sort the library by recently read / title / author, search by title or author, and long-press a book to open a "Book Info" / "Delete" context sheet
  4. When a corrupt or DRM'd EPUB is imported, the user sees a friendly snackbar explaining the error and the library is unchanged (no crash)
  5. With an empty library, the user sees an illustration and a clear "Import your first book" CTA
**Plans**: TBD
**UI hint**: yes

### Phase 3: Reader with Sentence-Span Architecture
**Goal**: Users can open any imported EPUB on phone or tablet and read it start-to-finish with good typography, chapter navigation, and resume-on-reopen — and every paragraph is rendered as a `RichText` of one `TextSpan` per `Sentence` (the permanent reader architecture, not a retrofit).
**Depends on**: Phase 2
**Requirements**: RDR-01, RDR-02, RDR-03, RDR-04, RDR-05, RDR-06, RDR-07, RDR-08, RDR-09, RDR-10, RDR-11, RDR-12
**Success Criteria** (what must be TRUE):
  1. Opening a book loads its chapter list and resumes the user's last reading position (or start of book on first open), and the reader scrolls at 60fps on a mid-range phone
  2. User can change font size (12–28pt), font family (3–4 bundled options), and theme (light/sepia/dark/OLED) and see the change apply immediately and persist across opens
  3. User can jump to any chapter via a persistent sidebar on tablet or a slide-over drawer on phone, with the current chapter visually highlighted
  4. VoiceOver and TalkBack read paragraphs as whole paragraphs (not sentence-by-sentence) because `Semantics` wraps each paragraph block
  5. Tapping the center of the reader toggles immersive mode; reading progress auto-saves on page turn (debounced 2s) and flushes on `AppLifecycleState.paused`
**Plans**: 8 plans
- [x] 02-01-PLAN.md — Toolchain unblock (analyzer override + Phase 2 deps) + epubx/share-intent spikes
- [x] 02-02-PLAN.md — Block IR sealed hierarchy + JSON codec + Wave 0 test scaffolding
- [ ] 02-03-PLAN.md — Drift v2 schema (Books + Chapters) + generated migration test
- [ ] 02-04-PLAN.md — EPUB parser core (DOM walker) + DRM detector + Isolate wrapper
- [ ] 02-05-PLAN.md — ImportNotifier + Android intent filter + iOS doc types + /reader/:bookId stub + Share intent listener
- [ ] 02-06-PLAN.md — LibraryNotifier (sort/search) + BookCard + BookCardShimmer
- [ ] 02-07-PLAN.md — LibraryScreen composition (SliverAppBar + search + chips + grid + context sheet + empty states)
- [ ] 02-08-PLAN.md — 15-EPUB corpus sweep + persistence round-trip + device verification checkpoint
**UI hint**: yes

### Phase 4: TTS Engine & Playback Foundation
**Goal**: Users can tap play on any chapter and hear it read aloud by Kokoro-82M with a curated voice, adjust speed, skip sentences, keep listening with the app backgrounded, and control playback from the lock screen — with synthesis running on a long-lived worker isolate and audio flowing through a WAV-wrap pipeline to `just_audio` + `audio_service`.
**Depends on**: Phase 3
**Requirements**: TTS-01, TTS-02, TTS-03, TTS-04, TTS-05, TTS-06, TTS-07, TTS-08, TTS-09, TTS-10, PBK-01, PBK-02, PBK-03, PBK-04, PBK-08, PBK-09, PBK-10, PBK-12
**Success Criteria** (what must be TRUE):
  1. On first launch after install, user sees a one-time "Download voice model (~80MB)" prompt with a Wi-Fi-only toggle defaulting ON; download is resumable, SHA-256-verified, and partial files are cleaned up on failure
  2. User taps play on any chapter and hears the first sentence within 300ms on a mid-range device; synthesis runs on a worker isolate and the UI remains responsive
  3. User can play / pause, scrub within the chapter, change speed (0.75×–2×), skip forward one sentence, skip back one sentence, pick from ~10 curated English voices with <2s previews, and set per-book voice and speed overrides
  4. Audio keeps playing with the app backgrounded on both iOS and Android, the lock screen shows book + chapter metadata with play/pause and next-chapter controls, and an incoming call or Siri pauses murmur and resumes cleanly on interruption end
  5. Reader and TTS coordinate through exactly one shared `playbackStateProvider` — no direct feature-to-feature imports — and `just_audio.setSpeed()` is the single owner of runtime speed (Sherpa `length_scale` is fixed at 1.0, asserted in code)
**Plans**: TBD
**UI hint**: yes

### Phase 5: Sentence Highlighting & Two-Way Sync
**Goal**: The currently-spoken sentence is visually highlighted in the reader and kept in the viewport automatically, and tapping any sentence starts TTS from there — making read-along feel alive rather than two separate features duct-taped together.
**Depends on**: Phase 3, Phase 4
**Requirements**: PBK-05, PBK-06, PBK-07
**Success Criteria** (what must be TRUE):
  1. As TTS plays, the active sentence is highlighted in the reader with theme-appropriate color and WCAG-AA contrast across all four themes (light / sepia / dark / OLED)
  2. As each sentence completes, the reader auto-pages or auto-scrolls so the active sentence stays in the viewport upper-third without jitter on a mid-range device
  3. Tapping any sentence in the reader starts TTS from that sentence (two-way sync — TTS follows reader, reader follows TTS)
**Plans**: TBD
**UI hint**: yes

### Phase 6: Polish, Accessibility & Ship Readiness
**Goal**: The app feels like a real product on every supported form factor — bookmarks, sleep timer, full settings surface, first-launch onboarding, accessibility, a 2-hour leak-free listening session, and a TestFlight build flowing — ready for store upload.
**Depends on**: Phase 5
**Requirements**: RDR-13, RDR-14, PBK-11, SET-01, SET-02, SET-03, SET-04, SET-05, ONB-01, ONB-02, QAL-01, QAL-02, QAL-03, QAL-04
**Success Criteria** (what must be TRUE):
  1. User can tap a ribbon icon to bookmark the current position, see bookmarks listed in the chapter panel / drawer, and tap any bookmark to jump to its exact scroll offset (with a brief pulse on the landed sentence)
  2. User can start a sleep timer (15 / 30 / 45 min / end-of-chapter) and see a countdown in the playback bar; the timer fires correctly even if the device is backgrounded or locked
  3. User can set default font / theme / voice / speed, view TTS model install status and storage usage, re-download the model, open and share the local crash log, and read the licenses and truthful privacy statement from Settings
  4. First-launch onboarding walks the user through model download (with Wi-Fi-only toggle) and importing their first EPUB, then lands them on a library either populated or showing the empty-state CTA
  5. All interactive elements have semantic labels and minimum 48×48px touch targets; a 2-hour continuous TTS playback session with a 1000-page EPUB shows no measurable memory leak on both a physical iOS and a physical Android device; the reader holds 60fps on mid-range phone and tablet profile builds
**Plans**: TBD
**UI hint**: yes

### Phase 7: Paid Distribution
**Goal**: A signed Android AAB and a signed iOS build are live on the Play Store and App Store Connect as a paid ~$3 one-time purchase with privacy labels declaring "Data Not Collected," store listings with phone + tablet screenshots, and a README documenting the full local build flow.
**Depends on**: Phase 6
**Requirements**: QAL-05, QAL-06, QAL-07, QAL-08
**Success Criteria** (what must be TRUE):
  1. A signed Android AAB is uploaded to the Play Store as a paid app at ~$3 with IARC content rating completed and the Data Safety form declaring "Data Not Collected"
  2. A signed iOS build is uploaded to App Store Connect as a paid app at ~$3 with export compliance answered (`ITSAppUsesNonExemptEncryption=false`), age rating set, and privacy labels declaring "Data Not Collected"
  3. Store listings on both stores include phone + tablet screenshots and a truthful privacy policy
  4. The repository README documents the full local build flow for Android and iOS including Sherpa-ONNX native linking notes and model SHA-256 pinning
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Scaffold & Compliance Foundation | 9/9 | Complete   | 2026-04-11 |
| 2. Library & EPUB Import | 0/TBD | Not started | - |
| 3. Reader with Sentence-Span Architecture | 0/TBD | Not started | - |
| 4. TTS Engine & Playback Foundation | 0/TBD | Not started | - |
| 5. Sentence Highlighting & Two-Way Sync | 0/TBD | Not started | - |
| 6. Polish, Accessibility & Ship Readiness | 0/TBD | Not started | - |
| 7. Paid Distribution | 0/TBD | Not started | - |

---
*Roadmap created: 2026-04-11*
*Total v1 requirements mapped: 72 / 72*
