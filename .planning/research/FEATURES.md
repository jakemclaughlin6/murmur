# Feature Research — murmur

**Domain:** Privacy-first Flutter ebook reader with on-device neural TTS (Kokoro-82M via Sherpa-ONNX), Android + iOS phones/tablets, one-time paid purchase (~$3)
**Researched:** 2026-04-11
**Confidence:** MEDIUM-HIGH (competitive landscape is well-known; Kokoro voice curation specifics are MEDIUM; user-preference assertions are inferred from review/forum evidence, not direct user research)

---

## Framing

The research task is to answer three things for three surfaces (Library, Reader, TTS) plus one cross-cutting question:

1. What's table stakes (users expect it or leave)?
2. What are real differentiators murmur should lean into?
3. What are anti-features murmur should deliberately NOT build?
4. What combinations do competitors get wrong that murmur can get right?

**The one-sentence market thesis, derived from the competitive research:** Every product in the adjacent space is either a *good reader with weak or system-TTS* (Lithium, Moon+ Reader, Librera, Yomu, KyBook, Lithium) or a *TTS-forward app with a mediocre reading experience and a subscription-or-cloud tax* (Speechify, Voice Dream Reader post-2024, NaturalReader, @Voice Aloud Reader). **murmur's opening is the uncrowded intersection: a typography-grade reader with neural-quality TTS, fully local, one-time purchase.** Every feature decision below should be evaluated against that thesis.

---

## Competitive Landscape Snapshot

| Product | What it is | TTS quality | Reader quality | Privacy | Pricing | Key failure mode murmur can exploit |
|---|---|---|---|---|---|---|
| **Voice Dream Reader** (iOS, post-2024 Applause Group) | TTS-first reader for accessibility audience | Premium voices behind paywall; cloud AI voices | Mediocre | Cloud voices are network-dependent | **Switched to $59.99/yr subscription in 2024, partial reversal after community backlash** | Subscription betrayal burned trust in the exact demographic that cares most about long-term local ownership |
| **Speechify** (iOS/Android/Web) | TTS-first productivity tool | Cloud neural | Not really a reader; document-focused | **Cloud-dependent; F rating with BBB; billing complaints on Reddit/Trustpilot** | $139/yr; "free trial" → surprise charges | Privacy-hostile, cloud-mandatory, deceptive billing — the literal opposite of murmur |
| **NaturalReader** | Cloud TTS reader | Cloud neural | Basic | Cloud-dependent | Subscription | Same pattern as Speechify |
| **@Voice Aloud Reader** (Android) | TTS layer over many formats | System TTS + BYO cloud API (Azure/Google/Polly) | Functional but dated UI | Mixed (BYO cloud keys) | Free + ads / pro | Ugly UX, system TTS ceiling, ad-supported — murmur can be the polished paid version with bundled neural quality |
| **Moon+ Reader** (Android) | Polished reader; TTS via system engine | **Capped by Android system TTS** (Google TTS / Ivona) | Excellent typography | Local library, but some features hit network | Free / Pro one-time | Can never beat system TTS ceiling; can't match Kokoro |
| **Librera** (Android) | Reader + system TTS for many formats | System TTS only | OK, but users complain about **bookmark UX and navigation friction** | Local | Free + open source + donations | Same TTS ceiling problem as Moon+; bookmark/navigation UX is a known weak spot |
| **Lithium** (Android) | Clean minimalist EPUB reader | **No TTS** | Good | Local | Free + pro | **Effectively abandoned; broken on newer Android versions** — refugee pool for murmur |
| **KyBook 3** (iOS) | Heavy-format reader with optional TTS | System TTS | Good | Local + cloud integrations (OPDS etc.) | One-time | Dev activity has slowed; UX feels dated; no neural TTS |
| **Yomu** (iOS) | Reader-first, typography-focused | **No TTS at all** | Very good | iCloud sync (pro) | Free + pro one-time | Clean reader, but listeners aren't served |

**Pattern:** Nobody in this list ships a reader-quality EPUB experience AND on-device neural TTS AND a one-time purchase AND a credible privacy posture at the same time. Voice Dream used to be closest; the 2024 subscription pivot broke the trust. That gap is murmur's product.

---

# Surface 1 — Library / Book Management

## Table Stakes (Library)

| Feature | Why expected | Complexity | Notes / In-spec? |
|---|---|---|---|
| System file picker import of EPUB | Standard import path on both platforms | LOW | **In spec** |
| Parse title, author, cover, chapter list on import | Every competitor does this; missing covers feels broken | LOW | **In spec** |
| Responsive grid of book cards (phone + tablet) | Standard library surface; grid is the genre norm | LOW | **In spec** (2/3/4/5-6 cols by form factor) |
| Sort: recently read / title / author | All competitors offer at least these three | LOW | **In spec** |
| Search by title/author | Once you have >10 books it's necessary | LOW | **In spec** |
| Long-press context menu (delete, info) | Android + iOS norm for library items | LOW | **In spec** |
| Empty state with "import your first book" CTA | Onboarding hook; looks unfinished without it | LOW | **In spec** |
| Progress indicator on each card | Users need to see which books are in-progress at a glance | LOW | **In spec** (progress ring) |
| Corrupt/invalid EPUB handled with a snackbar, not a crash | Every competitor has EPUB reliability issues; crashing kills trust | MEDIUM | **In spec** |
| Cover art cached locally for fast scroll | Re-parsing covers on every render tanks perf | LOW | **In spec** (cover cached as file) |
| Open-in / Share-to (Android intent / iOS share sheet) to import from Files, Safari, email, etc. | Table stakes on both platforms; users expect "send to murmur" from anywhere | LOW-MEDIUM | **Missing from current spec** — flag for add |

## Differentiators (Library)

| Feature | Value proposition | Complexity | Notes |
|---|---|---|---|
| **Truthful empty privacy policy** ("this app collects nothing and sends nothing") surfaced in onboarding | Direct trust signal against Voice Dream / Speechify baggage | LOW | In spec (store listing) — consider surfacing in-app too |
| Batch import (multi-select EPUBs in one picker pass) | @Voice and Moon+ do this; moving a Calibre library in = 50+ files | LOW | **Not explicit in spec** — verify `file_picker` `allowMultiple: true` is enabled |
| **OPDS catalog browsing** (import from Calibre content server, Standard Ebooks, Project Gutenberg) | Target user *already has* an EPUB library, often on Calibre. OPDS is the power-user import superhighway. KyBook 3 and Thorium support it; Moon+/Lithium don't well. | MEDIUM-HIGH | **Missing from spec.** Not v1 — but strong v1.x differentiator. See "Missing from spec" section |
| Book collections / shelves / tags | 50+ book libraries need grouping; sort alone isn't enough | MEDIUM | **Missing from spec** — v1.x candidate |

## Anti-Features (Library)

| Anti-feature | Why tempting | Why reject | Instead |
|---|---|---|---|
| Cloud library sync | "Users want to keep books across devices" | Contradicts privacy thesis; requires backend that murmur refuses to have | Encourage re-import; OPDS-to-local-Calibre is the pro path |
| In-app bookstore / discovery / recommendations | Every competitor app has tried this; revenue angle | Contradicts paid-once model; becomes an ad surface | BYO books; this is the core promise |
| Reading stats / streaks / gamification | Trendy, fits "productivity" framing | Wrong vibe (see PROJECT.md); privacy-leaky; diverts dev attention | Omit silently |
| DRM support (Adobe, LCP, Kindle) | "Support more books" | Legally hairy, platform-specific, contradicts "user-owned only" | Hard no; document in store listing |
| Non-EPUB format support (PDF, MOBI, AZW3, TXT, FB2) | Every competitor supports at least PDF | PDF alone doubles reader complexity (reflow, columns, OCR); others are niche | EPUB-only is a scoping commitment |
| MP3/M4B audiobook import | "It's an audiobook app" — users will assume | murmur *generates* audio; it's not a player. Shipping this muddies the product | Route confused users to a different app in store description |
| Automatic metadata scraping from the internet | "Fix missing covers from the web" | Requires network (breaks airplane-mode posture); requires a content API | Read what's in the EPUB; if metadata is missing, show a clear edit affordance (future) |
| Account/login for device transfer | "Makes onboarding familiar" | Core constraint violation | No accounts ever |

---

# Surface 2 — Reader / Reading Experience

## Table Stakes (Reader)

| Feature | Why expected | Complexity | Notes / In-spec? |
|---|---|---|---|
| Adjustable font size (slider or steps) | Universal. Reviews show users complain loudly when font options are limited. | LOW | **In spec** (12–28pt slider) |
| Multiple font families (serif/sans/dyslexic-friendly) | Every serious reader offers 3–5 | LOW | **In spec** (3–4 options) |
| Adjustable line spacing | Yomu, Moon+, Lithium all have it | LOW | **In spec** |
| Themes: light / sepia / dark / OLED black | Genre norm; OLED-black specifically matters on Android AMOLED | LOW | **In spec** |
| Chapter navigation (jump to TOC entry) | Without this, the book is a scroll | LOW | **In spec** (sidebar on tablet, drawer on phone) |
| Resume reading position across sessions | Breaking this is the #1 complaint in every ebook reader review | LOW | **In spec** (debounced 2s save) |
| Progress indicator ("Chapter 3 of 18 · 42%") | Both position-in-chapter and position-in-book expected | LOW | **In spec** |
| Immersive / full-screen mode (tap center to hide chrome) | Reader genre convention | LOW | **In spec** |
| Bookmarks (save position, list, jump) | Explicitly in scope per PROJECT.md | LOW-MEDIUM | **In spec** (Phase 6) |
| Smooth page turns / scroll at 60fps | Users notice jank immediately on text reading | MEDIUM | **In spec** (perf budget) |
| Landscape + portrait support on phone and tablet | Both platforms default to supporting both | LOW | **In spec** |
| Handles long chapters without memory spike | 1000-page EPUB requirement implies this | MEDIUM-HIGH | **In spec** (perf budget) |
| Custom font adjustment *persists per book* (or is global and consistent) | Moon+/Librera users complain when settings don't stick | LOW | **Implied by spec**, should verify during implementation |

## Differentiators (Reader)

| Feature | Value proposition | Complexity | Notes |
|---|---|---|---|
| **Sentence spans as a first-class data structure from day one** | Enables Phase 5 highlighting without a rewrite. Every other TTS-capable reader either doesn't highlight sentences (Moon+, Librera) or approximates badly. | HIGH | **In spec** — this is the architectural commitment |
| **Typography on par with Yomu/Lithium** in a TTS-capable app | Currently no product combines typography-grade reader with neural TTS. This IS the opening. | MEDIUM (discipline, not tech) | Implicit in spec — verify with real books during Phase 3 |
| **Phone-first-class layouts** (not tablet-with-phone-fallback) | Lithium, Yomu, KyBook are iPad-first and show it. Moon+/Librera are the opposite. | MEDIUM | **In spec** |
| **Dead-simple bookmark UX** — tap ribbon to save, drawer to jump | Librera's bookmark UX is a documented pain point (bookmarks don't visually land where you left off); a competent implementation is a direct win | LOW | **In spec** — execution matters |
| **Reading position follows TTS / TTS follows reading position** | Two-way coupling is what makes read-along feel "alive" vs feeling like two apps jammed together | MEDIUM | **In spec** |
| Paginated-swipe OR continuous-scroll as a user setting | Accommodates both mental models; most competitors pick one | LOW-MEDIUM | **In spec** |

## Anti-Features (Reader)

| Anti-feature | Why tempting | Why reject | Instead |
|---|---|---|---|
| Annotations / highlights / notes | Expected by "serious reader" users; Yomu & KyBook have them | Opens a whole category of UX scope (export, organize, edit); contradicts scoped PROJECT.md; pulls focus from the core TTS product | Bookmarks cover the "I want to come back" use case; say no to the rest |
| In-app dictionary / Wikipedia lookup | Standard on Kindle, Yomu, Apple Books | Requires network or a bundled dictionary (80–200MB); breaks airplane-mode story or doubles app size | Out. Copy-text to system dictionary is the fallback and it's fine. |
| Text-to-text translation | "Accessibility!" | Requires network or a massive bundled model | No |
| Web / HTML content import | @Voice and Speechify's core feature | Not the product; opens an infinite surface | EPUB only |
| Read-along karaoke word-level highlighting | Looks cool in demos | Kokoro doesn't expose per-word timing; would need forced alignment, which is a whole research project | Sentence-level is the right granularity and matches the architecture |
| Reflowable PDF support | "PDF is more popular than EPUB" | Reflow + OCR + column detection is a multi-phase project; will eat the roadmap | Out of scope, documented in PROJECT.md |
| Browser-like "font zoom" pinch gesture | Feels native | Conflicts with page-turn gestures; adds state to reader | Font size slider in settings, not pinch |
| HTML widget-based rendering (`flutter_widget_from_html`, `flutter_html`, webview) | "Handles any EPUB HTML for free" | Can't expose per-sentence spans; Phase 5 highlighting would require a full rewrite | Custom sentence-span renderer — already the spec commitment |

---

# Surface 3 — TTS Playback / Listening Experience

## Table Stakes (TTS)

| Feature | Why expected | Complexity | Notes / In-spec? |
|---|---|---|---|
| Play / pause | Obviously | LOW | **In spec** |
| Playback speed (0.75× to 2×) | Every TTS app has it; audiobook users lean heavily on 1.25×–1.5× | LOW | **In spec** (0.75/1/1.25/1.5/2×) |
| Background audio (keeps playing when backgrounded) | Without this, the feature is unusable for actual listening | MEDIUM | **In spec** (`audio_service`) |
| Lock screen / notification controls (play/pause, skip) | Platform norm for any audio app; users expect to control from their watch/car | MEDIUM | **In spec** (play/pause, next chapter) |
| Auto-advance across chapter boundaries | Must Just Work for long-form listening | LOW | **In spec** |
| Voice selection (at least a few voices) | Single voice feels cheap; users want to pick a voice they can tolerate for 10 hours | LOW | **In spec** (~10 curated) |
| Per-voice preview before committing | You can't pick a voice blind; every TTS app offers this | LOW | **In spec** (~2s preview button) |
| Low latency to start playback (<500ms felt, <300ms real) | Speechify / Voice Dream users complain about startup lag; kills the "tap a book, hear it" loop | MEDIUM-HIGH | **In spec** (<300ms sentence-start target; Kokoro makes this realistic) |
| **Skip sentence forward / back** | Users zone out. Scrubbing within a chapter is not precise enough. @Voice, Voice Dream, even Speechify all have sentence skip on/near the playback bar. | LOW-MEDIUM | **MISSING from current spec** — see "Missing from spec" section |
| Sleep timer with minute presets *and* end-of-chapter | Both are required; end-of-chapter is specifically cited as the preference for narrative fiction | LOW | **In spec** (15/30/45/EOC) |
| Graceful interrupt (phone call, other audio) | Platform norm; `audio_service` handles ducking | LOW-MEDIUM | **Implicit** — verify during Phase 4 |
| Stop at last sentence of book (no phantom continue) | Obvious but often broken — @Voice and Librera have reported bugs | LOW | **Implicit** |

## Differentiators (TTS)

| Feature | Value proposition | Complexity | Notes |
|---|---|---|---|
| **Bundled neural TTS (Kokoro-82M)** — no system TTS fallback, no cloud voices, no BYO API keys | This is the single biggest differentiator. Moon+, Librera, Lithium, @Voice all cap out at whatever the OS ships. Speechify/NaturalReader/Voice Dream have neural but require network. **murmur is the only one with both neural AND local on mobile.** | HIGH | **In spec** — entire Phase 4 |
| **Curated 10-voice lineup, not all 53** | Curation is a feature. 53 undifferentiated voices (what Kokoro-82M actually ships) is a worse UX than 10 good ones. Voice Dream's paywall "here are 100 cloud voices" is paradox-of-choice. | LOW (in code) + MEDIUM (in curation work, which is a one-time listening session) | **In spec.** Recommendation: pick across the published voice quality grades in Kokoro's VOICES.md, cover {US/UK} × {F/M} × {warm / crisp / authoritative} so users can find one they tolerate for 10 hours. `af_heart` and `af_bella` are the widely-praised US-female baseline; include at least one British female (`bf_emma`) and one British male (`bm_george` or `bm_lewis`) for fiction |
| **Sentence highlighting in sync with playback** | Makes read-along actually work. Voice Dream does this; most Android readers don't. The architectural commitment (sentence spans from day one) means murmur can hit this with character-timed approximation in Phase 5 without a rewrite. | HIGH (already in spec) | **In spec** (Phase 5) |
| **Instant voice-preview button on every voice in the picker** | Makes curation browsable, not dice-roll | LOW | **In spec** |
| **"Airplane mode is supported" as a stated property** | Nobody else in this space can say this honestly. Speechify cloud-fails in a plane. @Voice BYO cloud fails in a plane. Voice Dream premium voices fail in a plane. | LOW (stated) / MEDIUM (tested) | Implicit in spec — **surface this in store listing + onboarding** |
| **Two-way sync between reader scroll and TTS position** | Read-along *feels alive* when you can scroll ahead to read silently, then resume with TTS matching — or scroll via TTS and see the highlight track. | MEDIUM | **In spec** |
| Per-book voice/speed preference (remembered when reopening) | Users listening to multiple books often want a different voice per book (memoir in female voice, thriller in male voice). Global defaults alone force manual repicking. | LOW | **MISSING from spec** — see "Missing from spec" |
| Pause-on-headphone-unplug | iOS/Android norm for audio apps; tiny effort, big UX win | LOW | Implicit — verify during Phase 4 |

## Anti-Features (TTS)

| Anti-feature | Why tempting | Why reject | Instead |
|---|---|---|---|
| OS system TTS as a fallback | "What if Kokoro fails on old devices?" | Kokoro quality IS the product. A system-TTS fallback silently degrades the core value for people who won't notice; the people who will notice will be outraged the app is suddenly bad. | If a device can't run Kokoro, it's out of scope. Document minimum spec. |
| Cloud TTS (ElevenLabs, Azure, Polly) BYO or paid | "Higher quality voices for people who want them" | Breaks the privacy/airplane-mode posture for one feature; introduces key management, billing, and network dependency. Contradicts every other principle. | Neural local is already good enough per the market — Kokoro beat larger models on TTS Arena |
| **Multi-voice dialog detection** (assign different voices to narrator vs characters — @Voice's signature feature) | Sounds amazing in a demo; @Voice promotes it heavily | Requires a dialog-detection NLP pass, per-speaker voice assignment state, and mid-sentence voice switching which introduces latency spikes and breaks Kokoro's prosody. High complexity, high failure mode, distracts from core quality. @Voice users report it fires on the wrong things constantly. | One good voice per session. Users can change voices per book instead. |
| Word-level karaoke highlighting | "Voice Dream does it" | Kokoro doesn't expose per-word timing; forced alignment is a research project; character-timed approximation would look wrong at word level but is fine at sentence level | Sentence-level highlighting (already in spec) |
| Real-time voice cloning / user voice upload | Zeitgeist-y | Model-swapping at runtime, privacy minefield, distraction from core loop | Never |
| Inline voice switching per paragraph (user picks voices for a chapter) | Power-user knob | Nobody needs this, it distracts from "tap a book, hear it" | No |
| "Audiobook export" — render entire book to MP3 file | "I want to listen in my car's MP3 player" | Rendering a 12-hour book to MP3 = 45+ min of CPU pinning + storage + a whole new UX for managing exports. Also a piracy-adjacent vector that could complicate store review. | Keep TTS real-time and in-app. |
| Continuous TTS caching to disk across sessions | "Save CPU, save battery" | Kokoro is fast enough that pre-buffering one sentence ahead is sufficient; on-disk cache adds a storage management surface for marginal benefit | Pre-buffer next sentence in RAM (in spec), done |
| User-tunable Kokoro parameters (pitch, emphasis, style tokens) | "Power users love knobs" | Most combinations sound worse; curation is the feature | Curated voices as-is; speed is the only user knob |
| System notification media cover art generated per book | Obvious on lock screen | Already implicit via `audio_service` + book cover | Just ensure book cover flows through |
| In-app EQ / audio effects | "Podcast apps have them" | murmur is generating speech, not playing mastered audio; EQ on TTS output sounds terrible | No |

---

# What Competitors Get Wrong (murmur's Opening)

This is the section the task asks for most directly. Each row is a **specific combination** that's broken in the market, and what murmur's answer is.

| Combination competitors get wrong | Who does this | Why it's broken | murmur's answer |
|---|---|---|---|
| **Good reader typography + neural TTS** | *Nobody on mobile* | Reader-first apps (Yomu, Lithium, Moon+, Librera) cap out at system TTS quality. TTS-first apps (Speechify, Voice Dream, NaturalReader, @Voice) treat the reader UX as an afterthought. | murmur refuses to compromise on either — custom sentence-span renderer for typography, Kokoro-82M for voice |
| **Neural TTS + no subscription + no cloud** | Nobody | Speechify, NaturalReader, ElevenReader require cloud and/or sub. Voice Dream Reader tried subscription in 2024 and hit backlash. @Voice uses BYO cloud keys. | murmur ships Kokoro in the binary (one-time 82MB download), ~$3 one-time, no IAP, no recurring fee, no API keys |
| **TTS-capable reader + credible privacy posture** | Nobody | Speechify uploads documents; Voice Dream cloud voices hit the network; @Voice BYO keys route to third parties. The blind/accessibility community that these apps target explicitly cares about data handling. | murmur has exactly one network call (model download) and can state a truthfully empty privacy policy |
| **TTS + polished mobile-first UX** | Nobody | @Voice Aloud Reader has the closest feature set but famously dated UI. Voice Dream is iOS-accessibility-focused. Librera UI is a kitchen sink. | Flutter + Material 3 + reader-first design language; first-class on both form factors |
| **Sentence-level skip on the playback bar** | @Voice yes; Voice Dream yes; Moon+/Librera no | The two TTS-serious apps have it; the reader-serious-with-TTS apps don't. Zoning out is the main UX failure during long listens. | Add sentence skip to playback bar — this is the "missing from spec" biggest hole |
| **One-time paid trust signal** | KyBook 3, Yomu Pro, Lithium (legacy), Moon+ Pro | All of these either decayed (Lithium) or target the iPad-only reader-only audience (Yomu, KyBook). None combine one-time + TTS + neural. | Paid $3 is a *trust* signal more than a revenue play — it says "we're not baiting you for a subscription later" which is the literal Voice Dream failure mode of 2024 |
| **Sleep timer that includes end-of-chapter** | Audible yes; many TTS readers no | End-of-chapter is cited as the preferred option for fiction listeners who fall asleep; minute-only timers strand users mid-scene | murmur spec already has it (good) — surface it prominently in UI |
| **Chapter panel that doesn't feel like a pop-up** | Tablet readers split on this; phone readers universally use bottom sheets | Phone users want to flick through chapters without losing their place; Librera's bookmark navigation is a well-known sore spot | Persistent sidebar on tablet, proper slide-over drawer on phone — in spec |
| **Bookmark UX where the bookmark visually lands where you left off** | Librera specifically gets this wrong per user reviews | Bookmarks in Librera show as a list in a separate panel, not as an in-text marker — users report it's "unnecessarily complicated" to find the spot | murmur should ensure the bookmark list navigates back to exact scroll offset *and* briefly pulses the sentence when landing |

---

# Missing from Spec (Research Flags for Requirements)

These are features the competitive/user-review research surfaces that **aren't** currently in PROJECT.md or murmur_app_spec.md and should be considered before finalizing requirements.

| Feature | Why it matters | Surface | Complexity | Recommendation |
|---|---|---|---|---|
| **Sentence skip forward / back on playback bar** | Zoning out is the #1 failure mode of long TTS listening; chapter scrubber is too coarse; @Voice and Voice Dream both have this as core TTS UX | TTS | LOW-MEDIUM | **Add to table stakes before Phase 4 closes.** Implementation: move `TtsQueue` cursor ±1 sentence, restart pre-buffer |
| **Per-book TTS preferences** (voice + speed remembered per book) | Users listening to multiple books want different voices per book; global defaults force manual re-pick | TTS | LOW | **Add to v1.** Drift schema: add `preferred_voice_id` and `preferred_speed` to `books` table; fall back to global default when null |
| **Open-in / Share-to handler** (Android intent filter + iOS Share Sheet) | Users import EPUBs from email, Safari, Files, cloud drives. Without this, they must open murmur first and re-navigate. All major competitors support it. | Library | LOW-MEDIUM | **Add to v1.** Flutter has packages (`receive_sharing_intent`) and an Android intent filter in manifest; iOS Document Types in `Info.plist` |
| **Batch EPUB import** (select multiple files in one picker session) | Target user has an existing Calibre library; single-file import = 50+ taps | Library | LOW | **Add to v1.** Confirm `file_picker`'s `allowMultiple: true` and queue parsing |
| **OPDS catalog browser** (subscribe to Calibre content server, Standard Ebooks, Project Gutenberg) | Power-user import path; biggest single v1.x differentiator for the target user (people with existing EPUB libraries) | Library | MEDIUM-HIGH | **Defer to v1.x.** Not MVP. But flag: this is a high-impact post-launch feature and the architecture should not make it impossible. Read-only OPDS is much simpler than write-sync; murmur only needs read |
| **Book collections / shelves / tags** | 50+ book libraries need grouping beyond sort | Library | MEDIUM | **Defer to v1.x.** Drift schema can be forward-compatible now (add `collections` table in Phase 2 migration, don't surface UI until v1.1) |
| **Pause-on-headphone-disconnect** | Platform norm; easy to miss; `audio_service` handles it but must be verified | TTS | LOW | **Verify during Phase 4.** Not a net-new feature, but ensure the default behavior works |
| **Explicit "download Kokoro model on Wi-Fi only" toggle in onboarding** | 82MB on cellular is rude; users on metered plans will be angry | TTS / Onboarding | LOW | **Add to v1.** Checkbox defaulting to ON in the download prompt |
| **In-app link to view the local crash log** (not just generate it) | Spec mentions a local crash log; it needs a Settings entry to view/share | Settings | LOW | **Add to v1.** Reinforces the "privacy as product" story |
| **A "listening" indicator on library cards** (book currently has an active TTS session) | Two-way reader-TTS coupling means users might resume from library screen; knowing which book they were listening to matters | Library | LOW | **Nice-to-have, v1 if easy** |

---

# Rejected Features (Obvious-But-Wrong for murmur)

Features that seem like obvious additions for an ebook-reader-with-TTS but contradict murmur's constraints. Document these so they don't get re-proposed.

| Feature | Why it seems obvious | Why rejected |
|---|---|---|
| Cloud sync of library/progress/bookmarks | Standard in Kindle, Kobo, Apple Books, Yomu Pro | **Core constraint violation.** "Privacy is the product" means there is no backend, ever. Non-negotiable per PROJECT.md |
| Accounts / login | Normal for any app in 2026 | Same |
| Telemetry, analytics, crash reporting (network) | "Just Sentry, we need to know what breaks" | Same. Crash log is local-only by design |
| System TTS fallback for low-end devices | Graceful degradation | Kokoro quality IS the product. Degrading it silently ships the wrong product |
| Cloud neural voices (ElevenLabs, Azure, Polly BYO) | "Higher quality voices if users want them" | Breaks airplane-mode posture; adds billing/auth surface; contradicts one-time-paid model |
| PDF support | Most-requested format after EPUB | PDF reflow/OCR/column detection is a multi-phase project on its own. Not in v1, not in v1.x |
| MOBI/AZW3/KFX support | Amazon users will ask for it | DRM-adjacent; niche; would double parser complexity for users who should be using Kindle anyway |
| MP3/M4B audiobook import | "It's an audiobook app, right?" | murmur *generates* audio from text. It's not a player. Adding this confuses the product identity |
| Annotations / highlights / notes | Every "serious reader" app has them | Opens a whole category (annotation sync, export, edit, organize); pulls focus from TTS; explicit scoping decision in PROJECT.md |
| Reading statistics / streaks / gamification | Trendy; fits productivity framing | Wrong vibe per PROJECT.md; privacy-hostile; distracting |
| Social / sharing / export | "Let users share what they're reading" | Privacy surface; off-mission |
| In-app bookstore | Revenue hook | Becomes an ad surface; contradicts paid-once model |
| Word-level TTS highlighting | Looks amazing in demo videos | Kokoro doesn't expose per-word timing; forced alignment is a research project; would require rewriting the TTS pipeline |
| Multi-voice dialog detection (@Voice's signature) | Differentiator-looking | Requires dialog-detection NLP + per-speaker voice assignment + mid-stream voice switching. High complexity, high failure rate, distracts from core quality. @Voice users complain it mis-fires constantly |
| Desktop (macOS/Windows/Linux) builds | Flutter supports it | Not the target form factor; platform audit burden; off-mission per PROJECT.md |
| Non-English languages | Kokoro supports them | Each language needs its own sentence splitter, text normalization, and voice curation. v1 English-only is explicit scoping |
| Audiobook-to-MP3 export | "Listen in my car" | Render-a-book-to-disk is a new UX surface + storage management + possible piracy/DRM concern for store review |
| Real-time voice cloning / upload-your-voice | Zeitgeist | Model-swap at runtime, privacy minefield, distracts from core loop |
| Dictionary / translation / Wikipedia lookup | Standard on Kindle/Yomu | Requires network or bundled data (80–200MB); breaks airplane-mode promise or bloats app |
| Library widget on home screen | iOS/Android norm for reading apps (Yomu has one) | Nice but not core; defer to v1.x |

---

# Feature Dependencies

```
Sentence spans as first-class data structure (Phase 3)
    └──enables──> Sentence-level TTS highlighting (Phase 5)
    └──enables──> Sentence skip forward/back (Phase 4 or 5)
    └──enables──> Reading-position / TTS-position two-way sync
    └──enables──> Per-sentence bookmark precision

Sentence splitter (Dart, pure)
    └──required by──> TTS queue / pre-buffering
    └──required by──> Sentence-span renderer
    └──required by──> Sentence skip
    └──required by──> Highlighting

Kokoro model + SherpaOnnxService
    └──required by──> Voice preview
    └──required by──> Playback (obvious)
    └──required by──> Voice curation UI

just_audio + audio_service
    └──required by──> Background playback
    └──required by──> Lock-screen controls
    └──required by──> Sleep timer
    └──required by──> Pause-on-headphone-unplug
    └──required by──> Speed control (length_scale via Sherpa, not just_audio rate)

Drift DB (books + reading_progress tables)
    └──required by──> Library grid
    └──required by──> Resume reading
    └──required by──> Bookmarks
    └──required by──> Per-book TTS prefs (new)
    └──required by──> Future: collections/shelves

System file picker + share intent
    └──required by──> EPUB import
    └──enables──> Open-in / Share-to workflow

ModelManager (one-time download)
    └──required by──> Kokoro availability
    └──conflicts with──> "Airplane mode from minute 1" — must be a first-run-only network event
```

**Conflict to watch:** The "exactly one network call" constraint (Kokoro model download) conflicts with any feature that implies ongoing network use. Every feature proposal should be stress-tested against this: *does this ever need to touch the network after onboarding?* If yes, it either goes in v2 behind a toggle or it doesn't ship.

---

# MVP Definition

## Launch with (v1 = Phase 5 complete per spec, plus research additions)

The spec defines MVP as Phase 5 complete. Research confirms this is approximately correct. The research-driven **additions** to v1 MVP:

**Must-add to v1 (from research):**
- [ ] **Sentence skip forward/back on playback bar** — zoning out is the top UX failure for TTS listening; missing this makes listening feel fragile
- [ ] **Per-book voice/speed preferences** — trivial Drift addition, high user satisfaction
- [ ] **Open-in / Share-to handler** — platform norm; users expect to send EPUBs from Files/Safari/email
- [ ] **Batch EPUB import** — target user has existing libraries
- [ ] **Wi-Fi-only toggle on Kokoro download** — cellular respect
- [ ] **Settings entry to view/share local crash log** — reinforces privacy story

**Already in spec, confirmed correct:**
- [ ] Import DRM-free EPUBs, library grid, metadata parsing, cover caching
- [ ] Reader with font/theme/line-spacing customization
- [ ] Chapter navigation (tablet sidebar, phone drawer)
- [ ] Sentence-span renderer (Phase 3 commitment)
- [ ] Progress persistence + resume
- [ ] Bookmarks
- [ ] Kokoro TTS with ~10 curated English voices + previews
- [ ] Speed (0.75–2×) and pause/play
- [ ] Background audio + lock-screen controls
- [ ] Sentence highlighting with reader auto-scroll
- [ ] Sleep timer (minutes + end-of-chapter)
- [ ] One-time $3 paid on both stores

## Add after validation (v1.x)

Features the research supports as strong post-launch additions, triggered by user feedback or early reviews:

- [ ] **OPDS catalog browser** — biggest differentiator for power users with Calibre libraries. Trigger: user reviews mention Calibre / OPDS within 2 months
- [ ] **Book collections / shelves / tags** — trigger: reviews mention "my library is unmanageable"
- [ ] **Additional voice lineup** — add voices based on which of the initial 10 get used
- [ ] **Library widget (iOS/Android home screen)** — trigger: post-launch polish cycle
- [ ] **Home screen "resume listening" widget** — reinforces the core loop from the device OS level

## Future consideration (v2+)

Features that might be worth revisiting once product-market fit is established — but that contradict the scoping commitments and therefore need an explicit re-scoping decision:

- [ ] **Non-English languages** — Kokoro supports them; each adds a splitter + normalizer + voice curation project
- [ ] **PDF support** — requires reflow/column/OCR engine; multi-phase project
- [ ] **Annotation support** — explicit scope commitment says no; would need a re-scoping decision
- [ ] **Desktop builds** — explicit scope commitment says no
- [ ] **Word-level highlighting via forced alignment** — research project; only if Kokoro or a replacement exposes per-word timing

---

# Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority | Rationale |
|---|---|---|---|---|
| Kokoro neural TTS integration | HIGH | HIGH | **P1** | Core differentiator |
| Sentence-span renderer (Phase 3) | HIGH | HIGH | **P1** | Architectural commitment; enables everything |
| EPUB import + library grid | HIGH | MEDIUM | **P1** | Can't have a reader without books |
| Reader typography (font/theme/spacing) | HIGH | LOW-MEDIUM | **P1** | Table stakes; cheap; trust signal |
| Resume reading position | HIGH | LOW | **P1** | Top complaint when broken |
| Bookmarks | MEDIUM | LOW | **P1** | Explicit scope; cheap |
| Sleep timer (min + EOC) | HIGH (for listeners) | LOW | **P1** | Table stakes for TTS use case |
| Sentence highlighting | HIGH | HIGH | **P1** | MVP-defining feature; Phase 5 commitment |
| Background audio + lock screen | HIGH | MEDIUM | **P1** | Without this, TTS is unusable |
| **Sentence skip forward/back** | **HIGH** | **LOW-MEDIUM** | **P1 (add to spec)** | Research shows this is table stakes for TTS |
| **Per-book TTS preferences** | MEDIUM-HIGH | LOW | **P1 (add to spec)** | Cheap, delightful |
| **Open-in / Share-to** | MEDIUM-HIGH | LOW-MEDIUM | **P1 (add to spec)** | Platform norm |
| **Batch import** | MEDIUM | LOW | **P1 (add to spec)** | Target user has big libraries |
| Curated voice list (not all 53) | MEDIUM-HIGH | LOW | **P1** | Curation is a feature |
| Voice previews in picker | MEDIUM | LOW | **P1** | Can't choose blind |
| OPDS catalog browser | HIGH (for power users) | MEDIUM-HIGH | **P2 (v1.x)** | Big differentiator but not MVP |
| Book collections / shelves | MEDIUM | MEDIUM | **P2 (v1.x)** | Scales with library size |
| Home screen widgets | LOW-MEDIUM | MEDIUM | **P3** | Polish |
| PDF / MOBI support | HIGH (demand) | VERY HIGH | **NEVER v1; P3 for v2** | Explicit scope |
| Annotations | HIGH (for some users) | HIGH | **NEVER v1** | Explicit scope |
| Dialog multi-voice | LOW (actually) | HIGH | **NEVER** | Rejected feature |
| Cloud sync | Anti-value | — | **NEVER** | Constraint violation |

**Priority key:**
- **P1:** Must have for launch (v1 / Phase 5 MVP)
- **P2:** Post-launch, add once core is validated (v1.x)
- **P3:** Polish / future consideration (v2)

---

# Competitor Feature Comparison (Head-to-Head)

| Feature | Voice Dream | Speechify | @Voice | Moon+ | Librera | Lithium | Yomu | KyBook 3 | **murmur** |
|---|---|---|---|---|---|---|---|---|---|
| Local-only (no network needed after setup) | Partial | **No** | Partial (BYO) | Yes | Yes | Yes | Partial (iCloud) | Yes | **Yes** |
| Neural TTS on-device | No | No | No | No | No | — | — | — | **Yes (Kokoro)** |
| One-time purchase | No (now sub) | No | Free+ads | Yes (Pro) | Free | Free+pro | Free+pro | Yes | **Yes ($3)** |
| EPUB reader typography quality | Medium | Low | Low | **High** | Medium | **High** | **High** | High | **High (target)** |
| TTS sentence highlighting | Yes | Yes | Partial | No | No | — | — | No | **Yes** |
| Sentence skip forward/back | Yes | Yes | Yes | No | No | — | — | No | **Add to spec** |
| Sleep timer (EOC) | Yes | Partial | Yes | Partial | Yes | — | — | Yes | **Yes** |
| Background + lock-screen audio | Yes | Yes | Yes | Yes | Yes | — | — | Yes | **Yes** |
| Voice curation vs dump | Dump (cloud) | Dump | Dump | System | System | — | — | System | **Curated (~10)** |
| OPDS support | No | No | No | No | Partial | No | No | Yes | **v1.x** |
| No ads, no accounts, no tracking | Partial | **No** | Partial | Mostly | Mostly | Yes | Mostly | Yes | **Yes (strict)** |
| Phone + tablet first-class | iOS-focused | Yes | Android-focused | Android | Android | Android | iOS-focused | iOS-focused | **Both (commitment)** |

**Reading of the matrix:** There is **no row** where a single competitor matches murmur's intended column. The closest rivals are Voice Dream (good TTS + highlighting, but cloud + subscription + trust-broken in 2024) and Moon+/Librera (good local reader but locked to system TTS quality). murmur's bet is that the combination is valuable enough to justify the scoping discipline.

---

# Confidence Assessment

| Claim | Confidence | Evidence |
|---|---|---|
| Voice Dream Reader had a 2024 subscription backlash that damaged trust | **HIGH** | Multiple independent sources: Perkins School, Michael Tsai blog, AppleVis, Vision Ireland — all cover the same event |
| Speechify is cloud-dependent and has documented billing complaints | **HIGH** | BBB "F" rating, Reddit posts, Trustpilot reviews, multiple 2025 reviews document the pattern |
| @Voice Aloud Reader uses system TTS with BYO cloud keys | **HIGH** | Confirmed on Hyperionics website and Play Store listing |
| Moon+ Reader and Librera are capped by system TTS quality | **HIGH** | Both products confirm this in their own docs/FAQs (Librera explicitly) |
| Lithium is effectively abandoned | **MEDIUM-HIGH** | Community reports of breakage on newer Android; GitHub patch project exists to keep it working |
| Kokoro-82M ships ~10 voices with documented quality grades including `af_heart`, `af_bella`, `bf_emma`, `bm_george`, `bm_lewis`, etc. | **HIGH** | Confirmed via hexgrad/Kokoro-82M VOICES.md on Hugging Face |
| Kokoro beat larger TTS models on TTS Arena | **HIGH** | Confirmed in multiple 2025 reviews and the model card |
| Sentence skip forward/back is table stakes for TTS users | **MEDIUM-HIGH** | Present in Voice Dream, @Voice, Speechify; cited in user complaints about apps that lack it; inferred from "zoning out" being a universal long-form listening failure mode. Not a primary-source user study |
| Users prefer end-of-chapter sleep timer for fiction | **MEDIUM-HIGH** | Confirmed by audiobookshelf issue thread, Audible documentation, multiple audio-app guides — user behavior is well-attested |
| OPDS is a meaningful power-user import path | **HIGH** | Multiple ebook-reader stacks (Thorium, KyBook 3, Calibre-Web, KOReader) and forum discussions confirm |
| Librera has bookmark/navigation UX complaints | **MEDIUM** | Found in Slant.co review and github issues; one source per claim |
| "Batch import" and "Share-to handler" are table stakes | **MEDIUM** | Inferred from platform conventions and competitor feature sets rather than primary user research |
| Per-book voice/speed preferences are broadly wanted | **MEDIUM** | Inferred from the fact that Voice Dream has per-document voice settings and they're frequently cited in reviews. Not a primary-source user study |

**Overall confidence: MEDIUM-HIGH.** The competitive analysis is solid and well-sourced. The "table stakes" claims are mostly well-attested by competitor feature parity. Some "missing from spec" recommendations (sentence skip, per-book prefs, share intents) are inferred from reasonable platform conventions and competitor parity rather than direct user studies — they are strong recommendations, not certainties, and should be validated with early-user feedback once shipped.

---

# Sources

**Competitor research:**
- [Voice Dream Reader subscription controversy (Perkins School for the Blind)](https://www.perkins.org/resource/voice-dream-reader-subscription-controversy/)
- [Voice Dream Reader Switches to Subscriptions (Michael Tsai)](https://mjtsai.com/blog/2024/04/08/voice-dream-reader-switches-to-subscriptions/)
- [Voice Dream subscription drama explained (Vision Ireland)](https://vi.ie/voice-dream-readers-subscription-drama-explained-is-the-bubble-going-to-burst/)
- [Speechify Trustpilot reviews](https://www.trustpilot.com/review/speechify.com)
- [Speechify review (Our Code World, 2025)](https://ourcodeworld.com/articles/read/2345/honest-review-of-speechify-premium-in-2025)
- [@Voice Aloud Reader official page (Hyperionics)](https://www.hyperionics.com/atvoice/)
- [@Voice Aloud Reader on Google Play](https://play.google.com/store/apps/details?id=com.hyperionics.avar)
- [Moon+ Reader Pro on Google Play](https://play.google.com/store/apps/details?id=com.flyersoft.moonreaderp)
- [Librera Reader TTS FAQ](https://librera.mobi/faq/installation-and-configuration-of-tts/)
- [Librera Reader (Pro) review (Slant.co)](https://www.slant.co/options/19926/~librera-reader-pro-review)
- [Librera TTS feature broken issue](https://github.com/foobnix/LibreraReader/issues/1085)
- [Lithium EPUB Reader alternatives (AlternativeTo)](https://alternativeto.net/software/lithium-epub-reader/)
- [Lithium patch project (GitHub)](https://github.com/pgaskin/lithiumpatch)
- [KyBook 3 on App Store](https://apps.apple.com/us/app/kybook-3-ebook-reader/id1348198785)
- [KyBook 3 changelog](http://kybook-reader.com/changelog.html)
- [Yomu EBook Reader](https://www.yomu-reader.com/)

**Kokoro TTS:**
- [Kokoro-82M on Hugging Face (hexgrad)](https://huggingface.co/hexgrad/Kokoro-82M)
- [Kokoro VOICES.md](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md)
- [Kokoro TTS Review 2026](https://reviewnexa.com/kokoro-tts-review/)
- [Comparing TTS models (Inferless 2025)](https://www.inferless.com/learn/comparing-different-text-to-speech---tts--models-part-2)
- [Kokoro-82M analysis (Analytics Vidhya)](https://www.analyticsvidhya.com/blog/2025/01/kokoro-82m/)

**Feature conventions & ebook reader UX:**
- [Essential features for ebook reading apps (Agilie)](https://agilie.com/blog/essential-features-to-your-perfect-reading-app)
- [Must-have features for ebook reader apps (Hyperlink InfoSystem)](https://www.hyperlinkinfosystem.com/blog/must-have-features-for-an-ebook-reading-app)
- [End-of-chapter sleep timer discussion (audiobookshelf)](https://github.com/advplyr/audiobookshelf/issues/3130)
- [Audible sleep timer setup](https://www.drmare.com/drm-audiobooks/set-audible-sleep-timer.html)
- [Libby sleep timer docs](https://help.libbyapp.com/en-us/6049.htm)

**OPDS / Calibre integration:**
- [Calibre content server (official docs)](https://manual.calibre-ebook.com/server.html)
- [Thorium Reader + Calibre via OPDS (EDRLab)](https://www.edrlab.org/2022/11/14/connect-thorium-reader-to-calibre-using-opds/)
- [Calibre2opds compatible software (MobileRead Wiki)](https://wiki.mobileread.com/wiki/Calibre2opds_compatible_software)

**Project inputs:**
- `/home/jmclaughlin/projects/murmur/.planning/PROJECT.md`
- `/home/jmclaughlin/projects/murmur/murmur_app_spec.md`

---

*Feature research for: privacy-first Flutter ebook reader + on-device Kokoro neural TTS (murmur)*
*Researched: 2026-04-11*
