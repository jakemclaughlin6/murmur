# Pitfalls Research — murmur

**Domain:** Flutter ebook reader with on-device neural TTS (Kokoro via Sherpa-ONNX), EPUB-only, offline, paid one-time app
**Researched:** 2026-04-11
**Confidence:** MEDIUM–HIGH (Sherpa-ONNX Flutter bindings less battle-tested; platform/store rules verified against official docs)

Scope note: the spec already flags sentence splitting, Sherpa-ONNX setup, and sentence-span RichText rendering as the three known-hard areas. This document catalogs what *else* will bite, organized by domain: EPUB parsing, sentence splitting edge cases, Sherpa-ONNX on mobile, audio stack, responsive UX, store/compliance, and the RichText + scroll combination.

Severity legend: **BLOCKER** (ship-stopper, causes rewrite) · **SERIOUS** (causes bad reviews or major rework) · **ANNOYANCE** (polish-level, fixable late).

---

## Critical Pitfalls

### Pitfall 1: EPUB HTML entering the pipeline instead of plain text + style runs

**What goes wrong:**
The naive path is "parse EPUB → hand HTML string to a renderer." Phase 3 already bans `flutter_widget_from_html`, but there's a subtler version: extracting innerText with a regex or a half-baked HTML → TextSpan converter and discovering mid-Phase 5 that chapter structure (headings, paragraph breaks, blockquotes, italics, footnote markers, drop caps, centered poetry, inline images, SVG, `<ruby>` furigana, MathML) is either lost or corrupted. Then the sentence-span data structure has to be rebuilt on top of a richer intermediate, and every downstream feature (search, progress, highlighting) is re-validated.

**Why it happens:**
Developers treat EPUB as "just a zip of HTML" and underestimate how much real-world EPUB HTML relies on CSS, inline styles, embedded fonts, and non-standard elements. `epub_view`'s built-in renderer handles many cases but is opaque — swapping to a custom sentence-span renderer means re-solving image handling, heading hierarchy, footnotes, code blocks, and inline formatting from scratch.

**How to avoid:**
Define the intermediate representation **before writing the parser**. It must be richer than "list of sentences" — something like:

```
Chapter {
  blocks: List<Block>  // Paragraph, Heading(level), BlockQuote, Image, Separator, CodeBlock, List(ordered/unordered), Poetry
}
Block {
  sentences: List<Sentence>
}
Sentence {
  id: String
  runs: List<StyleRun>  // each run carries text + (italic|bold|emph|code|link|footnote-ref|drop-cap)
}
```

Write a fixture suite of 10+ real EPUBs (public domain Project Gutenberg, Standard Ebooks, a Leanpub sample, a translated novel, a poetry collection, a technical book with code, a book with footnotes, a book with inline images) and make the parser round-trip them to this IR with snapshot tests **before** building the renderer. Budget 2–3 days for this — not 2 hours.

**Warning signs:**
- "I'll strip HTML with a regex"
- `Sentence { text: String }` with no style information
- Intermediate representation has no `Block` type, just a flat list of sentences
- First EPUB tested is Project Gutenberg plain text (too clean to reveal problems)
- Chapter renderer has a special-case branch for `<img>` (should be a first-class Block)

**Phase to address:** **Phase 3** — this IR is the foundation for the reader AND the TTS pipeline. If Phase 3 ships without it, Phase 4 (TTS) and Phase 5 (highlight) both inherit the technical debt.

**Severity:** **BLOCKER** — getting the IR wrong forces a Phase 3 rewrite.

---

### Pitfall 2: EPUBs in the wild are XHTML-strict but inconsistently so

**What goes wrong:**
Real EPUB content is nominally XHTML (well-formed XML), but publishers ship files that mix:
- XML namespaces on every element (`<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">`) that trip up naive HTML parsers
- Namespaced attributes (`epub:type="footnote"`, `xml:lang="fr"`)
- Self-closing tags (`<br/>`, `<img/>`) that non-XML parsers don't like
- Entity references (`&nbsp;`, `&mdash;`, named entities not in HTML5) that break strict XML parsers
- Mixed-case tags in older EPUB 2 files
- `<?xml ... ?>` and `<!DOCTYPE ...>` prologues
- Non-UTF-8 encoding declarations (rare but real — Latin-1 in Project Gutenberg conversions)
- Obfuscated fonts (EPUB 3 IDPF obfuscation, Adobe obfuscation) that look like corrupt binaries

If the chosen parser is strict XML, it chokes on HTML entities; if it's lenient HTML, it breaks on namespaces. Either way, import fails silently or renders garbage.

**Why it happens:**
There is no "EPUB-in-the-wild" test corpus; each publisher has quirks. EPUB 2 and EPUB 3 have different rules, and content documents from older books predate the spec tightening.

**How to avoid:**
- Use an HTML5-tolerant parser (Dart's `html` package is lenient; `xml` is strict — do not use `xml` for content documents)
- Normalize at the import boundary: parse with `html`, extract text + tags with known semantics, discard namespaces, re-encode as UTF-8
- On import failure, never crash — surface a user-facing "This EPUB uses an unsupported feature: [what]" message and log it to the local crash log
- Explicitly detect and reject DRM'd EPUBs (look for `META-INF/rights.xml` or `META-INF/encryption.xml` containing DRM algorithms, not just font obfuscation) with a clear "This book is DRM-protected; murmur only opens DRM-free EPUBs" message — critical for App Store review
- Distinguish font obfuscation (IDPF/Adobe, legal, resolvable) from actual DRM (Adobe ADEPT, B&N, Amazon): font obfuscation is in `encryption.xml` but references specific resources; real DRM wraps `OEBPS/` content
- Assemble a test corpus of 15+ EPUBs covering: Project Gutenberg, Standard Ebooks, Leanpub, O'Reilly, a Kobo-exported EPUB, a Calibre-converted EPUB, an iBooks-exported EPUB, an EPUB 2 legacy file, an EPUB 3 with MathML, a RTL (Arabic/Hebrew) file, a poetry collection, a book with footnotes

**Warning signs:**
- Parser is `package:xml` instead of `package:html`
- Code path that treats EPUB content as a `String` of HTML and feeds it to one function
- No test EPUBs from more than one publisher
- Import is green on a Calibre-generated file and nothing else
- DRM detection relies on filename or extension

**Phase to address:** **Phase 2** (import + parse) with regression fixtures carried into Phase 3.

**Severity:** **SERIOUS** — one unreadable EPUB per user = uninstall.

---

### Pitfall 3: Sentence splitter built and tested only on well-formed prose

**What goes wrong:**
The spec calls out abbreviations and decimals, but the long tail of English sentence boundaries is much deeper. Categories that will break a naive `[.!?]\s+[A-Z]` splitter:

1. **Abbreviations at end of sentence:** "She earned her Ph.D. Tomorrow she starts." — "Ph.D." is not a sentence end, but "Ph.D." followed by a sentence IS.
2. **Titles + names:** "Dr. Smith arrived." vs. "Mr. Jones, Mrs. Kim, and Dr. Smith arrived."
3. **Geographic abbreviations:** "Washington, D.C. is the capital."
4. **Initials:** "J.R.R. Tolkien wrote..."
5. **Decimal numbers:** "The value is 3.14 meters."
6. **URLs and filenames:** "Visit example.com. Then download murmur.app."
7. **Ellipsis as trailing speech:** "He said, 'I don't... I can't...'" — ellipsis can be mid-sentence or terminal, depending on what follows
8. **Ellipsis as omission in quotation:** "...the greatest speech ever given."
9. **Question/exclamation inside quotes followed by lowercase:** `"Really?" she asked.` — this is ONE sentence, not two
10. **Question/exclamation inside quotes followed by capital:** `"Really?" She turned away.` — this is arguably two
11. **Em dash interruption:** `"I was going to—" He stopped.` — ambiguous
12. **Multiple sentence terminators:** "Wait!!! Don't go!" — collapse or preserve?
13. **Bullet lists rendered as prose:** "The steps are: 1. Open app. 2. Select book."
14. **Chapter headings with no terminator:** "Chapter 1" — not a sentence but needs to be spoken with a pause
15. **Poetry line breaks:** line break ≠ sentence end in verse
16. **Blockquote attribution:** `"To be or not to be." — Shakespeare`
17. **Footnote markers:** "The result was unexpected.¹ Further study..." — the superscript must not break the sentence
18. **Roman numerals as section numbers:** "See Section IV. The conclusion..."
19. **Measurements:** "He was 6 ft. 2 in. tall." — "in." is a dead trap
20. **Honorifics in dialogue:** "'Yes, Mr. President.' He saluted."
21. **Abbreviations followed by lowercase:** "The meeting is at 10 a.m. tomorrow." — correctly NOT a split
22. **Curly vs. straight quotes:** `"` (U+201C) vs. `"` (U+0022) — splitter must handle both
23. **Non-breaking spaces, thin spaces, zero-width joiners:** common in professionally-typeset EPUBs
24. **French/Spanish quote marks carried over in loanwords:** `« comme ça »`

**Why it happens:**
The test cases in splitter development are usually contrived English sentences from blog posts. Real books contain dialogue, poetry, footnotes, and publishing-house typography conventions that never appear in toy examples.

**How to avoid:**
- Build the splitter against a **fixture file of 500+ real sentences** extracted from 10+ real EPUBs, with hand-annotated boundaries. This is the regression suite.
- Use a protect-then-split approach: replace known non-boundary dots (abbreviations from a gazetteer, decimals via regex, URLs via regex, ellipses as `…` or `...`, initials) with sentinel characters, split on `.!?`, restore sentinels.
- Gazetteer: curate an English abbreviation list (200+ entries: Mr, Mrs, Ms, Dr, Jr, Sr, St, Ave, Blvd, Rd, Ph.D, M.D, B.A, M.A, B.S, Ph, e.g, i.e, etc, vs, viz, cf, Inc, Corp, Co, Ltd, U.S, U.K, E.U, a.m, p.m, approx, est, No, vol, ch, pp, fig, Prof, Rev, Hon, Gen, Col, Capt, Lt, Sgt, Cpl, Pvt, Jan, Feb, Mar, Apr, Jun, Jul, Aug, Sep, Sept, Oct, Nov, Dec, Mon, Tue, Wed, Thu, Fri, Sat, Sun, ft, in, lb, oz, kg, km, cm, mm, mi, mph, kph, et al, ibid, op cit, cf, approx). Store in a single Dart constant so it's tweakable.
- Handle quoted-dialogue terminators: if a `.!?` is immediately followed by `"` or `'` or `"` or `'`, include the closing quote in the current sentence and decide boundary based on next non-whitespace character (uppercase → new sentence, lowercase → same sentence).
- Ellipsis: treat `...` and `…` as a *non-terminal* by default; only split after an ellipsis when followed by a clear sentence start (capital letter + space).
- Emit empty-sentence-safe output: never return a zero-length sentence (TTS will crash or produce silence).
- Build a debug mode that highlights sentence boundaries in the reader so mistakes are visible.
- Profile the splitter on full chapters: must split a 50-page chapter in <50ms or Phase 3 page load stutters.

**Warning signs:**
- Splitter tests use only sentences written for the test file
- No test involving the string `Mr.` or `Ph.D.` or `"Really?" she asked.`
- Splitter uses Dart `String.split()` anywhere
- No benchmark for full-chapter split time
- Output contains zero-length or whitespace-only sentences

**Phase to address:** **Phase 4**, but prototype and test in isolation as the spec says — this is a standalone library. Start it before touching Sherpa-ONNX so it can be hardened against a fixture suite.

**Severity:** **SERIOUS** — every user will notice when "Dr. Smith" is spoken as two sentences.

---

### Pitfall 4: Sherpa-ONNX model loaded on the main isolate

**What goes wrong:**
Kokoro-82M int8 is ~82 MB. Loading the ONNX model via the sherpa_onnx Flutter binding on the main isolate blocks the UI thread for 1–5 seconds (device-dependent — older Android mid-rangers with eMMC storage can be worse). The user taps Play, the app freezes, ANR dialogs fire on Android 13+, and on iOS the launch time counts toward the watchdog timeout if you load on startup.

**Why it happens:**
Flutter tutorials for sherpa_onnx show `TtsOffline.create(config)` called from a regular provider or future builder. The binding does FFI → native model load synchronously, and FFI calls run on whatever isolate invokes them.

**How to avoid:**
- Load the model in a dedicated long-lived background isolate, NOT via `compute()` (which spawns and tears down an isolate per call — the model would have to reload every synthesis).
- Use `Isolate.spawn()` with a `SendPort`/`ReceivePort` command channel, or package `flutter_isolate` / `worker_manager` for pre-built lifecycle handling.
- The synthesis isolate owns the `OfflineTts` handle for its lifetime; the UI sends `{sentence, voiceId, speed}` messages, receives `Float32List` PCM chunks.
- Critical caveat: Sherpa-ONNX Flutter binding's FFI handles are NOT transferable between isolates — **create the handle in the isolate that will use it**, not in the main isolate and pass it over.
- Show a progress indicator during first-time load ("Preparing voice…") — it WILL take 1–3s on cold start even on a good phone.
- Pre-warm: start loading the model immediately when the reader screen opens (not when the user taps Play) so the first tap is instant.
- On Android, pin the isolate's thread priority lower than UI (Sherpa-ONNX is CPU-bound and can starve the rasterizer).

**Warning signs:**
- TTS service is a regular `Provider` or `FutureProvider` with no isolate
- `compute()` is used to call `synthesize()` (will reload model every call)
- Profile shows 1–5 second UI freeze on first Play tap
- Android logcat shows `ANR in com.yourname.murmur`
- iOS shows `Application main thread hang detected`
- `TtsOffline` handle is cached in a top-level variable

**Phase to address:** **Phase 4** — the architecture must be isolate-native from day one; retrofitting isolates later is painful because every method signature changes.

**Severity:** **BLOCKER** — UI freeze on the primary interaction.

---

### Pitfall 5: Sample rate / audio format mismatch between Kokoro and just_audio

**What goes wrong:**
Kokoro via Sherpa-ONNX outputs **24000 Hz mono Float32** samples (verified against k2-fsa sherpa documentation and flutter_kokoro_tts reference). `just_audio` can't play a raw `Float32List` — it wants a source (URI, asset, bytes of a container format). You have three hostile options:

1. **Write PCM to temp WAV file per sentence:** latency hit (file I/O per sentence), wear on flash storage over a 2-hour session, leaks if temp files not cleaned.
2. **In-memory WAV bytes via `AudioSource.uri(Uri.dataFromBytes(...))`:** works for one-shot but allocates per sentence and doesn't stream gaplessly.
3. **Custom StreamAudioSource:** required for gapless pre-buffered playback, but getting it right with PCM of varying sentence lengths is fiddly — and `StreamAudioSource` on iOS historically has had buffering quirks.

If you pick #1 or #2 naively, the <300ms sentence-start latency target dies.

**Why it happens:**
Tutorials and blog posts show TTS demos that generate one sentence, wrap in a WAV header, play once, done. Queueing and gapless playback of back-to-back PCM chunks is qualitatively different and rarely documented.

**How to avoid:**
- Benchmark three approaches on real devices in Phase 4 before committing
- For continuous playback, implement a custom `StreamAudioSource` that wraps a WAV-header-prefixed byte stream and yields chunks as sentences are synthesized. Test on an iPhone (not just simulator — iOS audio routing is different).
- Alternative: one pre-generated WAV per sentence, rely on just_audio's gapless concatenation via `ConcatenatingAudioSource` with pre-buffered sources. This is simpler but has a 5–30ms gap between items depending on iOS version.
- Always wrap Float32 output in a proper 44-byte WAV header with `RIFF`/`WAVE`/`fmt `/`data` chunks; sample rate 24000, 1 channel, 32-bit float format (IEEE float = WAVE_FORMAT_IEEE_FLOAT, code `0x0003`) OR convert to 16-bit PCM (code `0x0001`) — be consistent, some just_audio/native players are pickier about float WAV than int16 WAV, so int16 is safer cross-platform.
- If converting to int16: clamp + scale `int16 = (float * 32767).clamp(-32768, 32767)`, then write as little-endian.
- Clean up temp files aggressively — delete each sentence's file after it plays past, not at chapter end.
- Test: play a full 30-minute chapter and confirm audible sentence gaps are <100ms and no memory growth.

**Warning signs:**
- `just_audio` receives `AudioSource.file(path)` per sentence with no concatenation plan
- Float32List is passed to just_audio without conversion to int16
- No WAV header — just raw PCM bytes
- Gap between sentences is >200ms
- Disk usage grows monotonically during playback
- Audio plays on Android but not iOS (or vice versa) — format code mismatch

**Phase to address:** **Phase 4** — this is the core audio path; do it right first.

**Severity:** **BLOCKER** — if this is wrong the TTS UX is broken.

---

### Pitfall 6: iOS background audio not surviving app backgrounding

**What goes wrong:**
User taps Play, locks phone, audio stops after ~30 seconds. Or: audio plays fine while phone unlocked, silences the moment the screen turns off. Root causes, any of which is individually sufficient:

1. `UIBackgroundModes` missing `audio` in `Info.plist` (not an entitlement — it's an Info.plist array key)
2. `AVAudioSession` category not set to `.playback` (defaults to `.soloAmbient` which silences on lock)
3. `audio_service` not actually started — `AudioService.init()` not awaited before first playback
4. `just_audio` used directly instead of going through `audio_service`'s handler — the audio pipeline has no media session, so iOS kills it
5. Background audio works, but when an interruption occurs (phone call, Siri, another audio app), the session never resumes because `AVAudioSessionInterruptionNotification` isn't handled
6. Debug build works (Xcode keeps the process alive), release build doesn't (the missing entitlement finally matters)

**Why it happens:**
The Flutter audio story is a stack of layers (just_audio → audio_service → AVAudioEngine/AudioSession on iOS or ExoPlayer/MediaSession on Android) and every layer has its own configuration. Miss one and background audio silently fails.

**How to avoid:**
- In `ios/Runner/Info.plist` add:
  ```xml
  <key>UIBackgroundModes</key>
  <array><string>audio</string></array>
  ```
- Configure `AVAudioSession` explicitly via the `audio_session` package (shared dependency of just_audio and audio_service): category `.playback`, options `.duckOthers` or `.mixWithOthers` depending on UX preference.
- Initialize `audio_service` at app startup (in `main()` before `runApp`), not lazily when TTS first plays.
- Route ALL playback through the `audio_service` handler. Do not call `just_audio` directly from UI — the handler owns the player.
- Subscribe to `AudioSession.instance.interruptionEventStream` and pause/resume on interruption begin/end.
- Test: on physical iPhone, play audio, lock phone for 60 seconds, unlock, confirm audio continued. Also: play audio, get interrupted by a phone call, confirm resume after call.
- Test on iPad with split-view and stage manager: audio must survive being in a non-focused window.
- On Android, add `<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>` and `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>` (required since Android 14) to `AndroidManifest.xml`. Android 14+ also requires declaring the foreground service type on the service element.
- On Android, target Android 15's `POST_NOTIFICATIONS` runtime permission for the media notification (prompt user on first playback).

**Warning signs:**
- TTS stops when phone locks
- Works in debug, fails in release
- Android 14+ logcat shows `ForegroundServiceStartNotAllowedException`
- iOS console shows `Audio session deactivated`
- No media notification on lock screen

**Phase to address:** **Phase 4** (background audio is in the Phase 4 spec). Verify on physical devices — simulators lie about audio session behavior.

**Severity:** **BLOCKER** — half the app's value proposition is "listen while doing something else."

---

### Pitfall 7: Lock screen metadata and playback position drift

**What goes wrong:**
Background audio works, but the lock screen shows a generic "Playing" title, the progress bar is stuck at 0, next/previous buttons do the wrong thing, or the scrubber doesn't let the user seek. Also: when TTS switches sentences, the lock screen doesn't update, and when the user hits "next track" it plays the next *sentence* instead of the next *chapter*.

**Why it happens:**
`audio_service` requires you to explicitly call `mediaItem.add(...)` and `playbackState.add(...)` on every meaningful state change. The default behavior is a stale item forever. Also: TTS has two competing notions of "track" — the sentence (technical unit) and the chapter (user-facing unit).

**How to avoid:**
- Decide the contract: MediaItem represents the **chapter**, not the sentence. Title = chapter title, artist = book author, album = book title, artwork = cover image.
- Emit `playbackState.add(...)` when play/pause/seek/buffering occurs.
- Emit `mediaItem.add(newItem)` when the active chapter changes, with a new duration (estimated from total text length and speaking rate).
- Map lock-screen controls: play/pause → TTS play/pause; skip-next → next chapter; skip-previous → previous chapter or restart current chapter. Do NOT map these to next/previous sentence (confuses users).
- Map the lock-screen scrubber to position within the current chapter. Since TTS progress is estimated (character-timed approximation per spec 3.4), expose a best-effort position and update it at sentence boundaries.
- Set the `MediaItem.artUri` to a `file://` path of the cached cover image — NOT an asset URI (iOS lock screen won't load asset URIs; Android is less picky).
- Test: playing, lock the phone, scrub via lock screen, confirm position updates. Also: skip next, confirm it goes to next chapter not next sentence.

**Warning signs:**
- Lock screen shows "Unknown Title" or "audio_service"
- Lock screen scrubber doesn't move
- Cover art is missing on lock screen
- Pressing "next" on lock screen plays 1 second of audio (next sentence) and stops

**Phase to address:** **Phase 4** (lock screen controls are in Phase 4 spec).

**Severity:** **SERIOUS** — tops bad-review lists for audio apps.

---

### Pitfall 8: Per-sentence RichText rebuilds tanking scroll performance

**What goes wrong:**
Phase 5 highlights the current sentence by rebuilding the chapter's `RichText` with a different background on the active span. If the chapter is rendered as one big `RichText` of 2000+ spans, every sentence change forces Flutter to re-layout the entire chapter (because RichText lays out all its spans in one pass). On a 300-sentence chapter this is 100+ ms per update, and auto-scroll + highlight updates become jerky.

Also: scrolling a `SingleChildScrollView` containing one giant RichText never recycles offscreen content — the full paragraph tree stays in memory — so a 50k-word chapter uses significant RAM and has no "jump to position" optimization.

**Why it happens:**
RichText is a leaf render object that lays out all spans together. There's no viewport recycling below the RichText level. And `TextSpan` is immutable — changing style requires constructing a new span tree, which triggers the full layout.

**How to avoid:**
- **Split chapters into per-paragraph `RichText` widgets**, rendered inside a `ListView.builder` or `CustomScrollView` with `SliverList`. Viewport recycling works at the widget level, so only visible paragraphs are laid out.
- Each paragraph holds 1–10 sentence spans; when the active sentence changes, only the paragraph containing the old sentence and the paragraph containing the new sentence rebuild.
- Use `const` TextStyles aggressively — create them once per theme and reference, never reconstruct in build methods.
- Store sentence style *deltas* (active vs. inactive) as two precomputed `TextStyle` instances per theme, picked with a simple ternary in build.
- Use `RepaintBoundary` around the paragraph that contains the active sentence so highlight changes don't repaint the rest of the viewport.
- Use `Selectable` widgets sparingly or not at all in the reader — `SelectionArea` + per-paragraph RichText causes selection overlays to track every span and hurts frame time. If text selection is wanted, wrap the whole ListView in one `SelectionArea`.
- For auto-scroll: use `Scrollable.ensureVisible()` with a GlobalKey on the active paragraph, with `alignment: 0.3` (upper-third); animate at 300–500ms curve.
- Benchmark on a real mid-range Android (not a flagship, not a simulator): scroll a 400-paragraph chapter, confirm 60fps in devtools.
- Benchmark: 2-hour playback on a 1000-page EPUB in release mode, measure RSS; flag >300 MB as a leak.

**Warning signs:**
- Chapter rendered as `RichText(text: TextSpan(children: [...]))` with a huge flat children list
- `SingleChildScrollView` wrapping the chapter content
- DevTools frame graph shows regular jank at sentence boundaries
- Memory grows over a reading session (leak indicator — probably accumulated sentence caches or uncleaned temp WAV files)
- No `RepaintBoundary` anywhere in the reader

**Phase to address:** **Phase 3** for the per-paragraph slice architecture, **Phase 5** for highlight-specific rebuild optimization, **Phase 7** for profile-mode memory validation.

**Severity:** **BLOCKER** for performance target (60fps + no memory leak over 2 hr).

---

### Pitfall 9: Accessibility regression from per-sentence spans

**What goes wrong:**
Splitting a paragraph into N sentence spans can confuse TalkBack (Android) and VoiceOver (iOS): they may read each span as a separate element, pause between sentences, or fail to aggregate the paragraph for screen-reader-driven reading. Users who rely on the OS reader can get a worse experience than the default `Text` widget — ironic in a reading app.

Also: custom highlight colors must meet WCAG contrast against the four themes (light, sepia, dark, OLED black). Amber-30% on sepia is unreadable.

**Why it happens:**
Sentence spans are a rendering optimization; accessibility wasn't the use case designed for. Flutter's accessibility tree flattens `TextSpan` children by default, but `WidgetSpan` and interactive spans break the flattening.

**How to avoid:**
- Use `TextSpan` (not `WidgetSpan`) for sentence segments — WidgetSpan each become their own accessibility node.
- Set `Semantics(label: fullParagraphText, child: RichText(...))` at the paragraph level with the aggregated plain text, and mark the RichText with `excludeFromSemantics: false` — this gives screen readers a clean "whole paragraph" label while preserving the visual spans.
- Test with TalkBack on Android and VoiceOver on iOS: swipe through the reader and confirm each paragraph reads as one block.
- Highlight contrast: test each theme with a WCAG AA contrast checker. Amber-30% is typically fine on light but fails on sepia; use theme-specific highlight colors.
- Minimum 48×48 tap targets on all interactive chrome (already in spec) — validate with the Flutter inspector's "Select widget mode."
- Provide a "disable sentence highlight" toggle in settings — some users may prefer classic reading without the moving highlight (it can be motion-sickness-inducing).

**Warning signs:**
- TalkBack reads one sentence at a time and pauses
- `WidgetSpan` used for sentence segments
- No `Semantics` wrapper on paragraphs
- Highlight color is a single constant regardless of theme
- No accessibility test in the QA pass

**Phase to address:** **Phase 6** (responsive UX and accessibility), with spot checks in **Phase 3** and **Phase 5**.

**Severity:** **SERIOUS** — App Store reviewers sometimes flag accessibility, and the target audience (people who listen to books) overlaps with vision-impaired users.

---

### Pitfall 10: MediaQuery-based responsive layout breaking in split-view

**What goes wrong:**
Using `MediaQuery.of(context).size.width` to decide "phone vs tablet layout" breaks on iPad split view and Android multi-window: an iPad in 1/3 split-view reports width ~400dp even though the device is a tablet, so the app renders the phone layout — but then the user expands split-view to 1/2 and the layout doesn't reflow. Or worse: MediaQuery reports the screen size while the actual render area is smaller, so content overflows.

**Why it happens:**
MediaQuery reports the logical screen in some Flutter versions, the safe area in others, and behavior has changed across Flutter 3.x minor versions. `LayoutBuilder` reports the actual constraints at that point in the widget tree, which is what you almost always want.

**How to avoid:**
- Use `LayoutBuilder` for layout decisions (phone vs tablet vs tablet-split), not MediaQuery.
- Use `MediaQuery` only for device properties that genuinely belong to the device (text scale, platform brightness, insets, accessibility flags).
- Define breakpoints as `constraints.maxWidth < 600` for phone-like, `< 900` for tablet-portrait-like, `>= 900` for tablet-landscape.
- Test on: iPad with split-view at 1/3 and 1/2 and full; iPad with Slide Over; Android foldable with hinge posture; Samsung DeX mode.
- Test text scale: set iOS Dynamic Type to largest, confirm reader and playback controls still fit.
- Enable `iPadMultitaskingSupport` in Info.plist (required for Stage Manager to treat the app as a citizen).
- Ensure `Scaffold`'s body is driven by LayoutBuilder so the chapter panel (sidebar vs drawer) swaps when constraints change, not just on first build.

**Warning signs:**
- `if (MediaQuery.of(context).size.width > 600)` pattern in layout code
- No LayoutBuilder in the main reader scaffold
- Sidebar doesn't swap to drawer when app is resized
- iPad in split-view shows the phone layout even at 50% width

**Phase to address:** **Phase 1** (scaffold: nav drawer/sidebar) and **Phase 3** (reader layout) and **Phase 6** (multi-device testing).

**Severity:** **SERIOUS** — iPad power users are in the target market.

---

### Pitfall 11: Missing export compliance declaration on App Store

**What goes wrong:**
First TestFlight or App Store upload is rejected or stuck in "Missing Compliance" because `ITSAppUsesNonExemptEncryption` is not set. The app uses HTTPS to download the Kokoro model, which Apple's encryption export regulations technically cover. Without the declaration, every build upload triggers the "Export Compliance" questionnaire. With the wrong declaration, builds are rejected or require uploading annual self-classification reports.

**Why it happens:**
Apple requires compliance info for any app "that uses, accesses, contains, implements, or incorporates encryption." HTTPS counts. The app plainly qualifies for the standard exemption (only using encryption for authentication/HTTPS/standard iOS-provided crypto), but you have to *declare* it.

**How to avoid:**
- Add to `ios/Runner/Info.plist`:
  ```xml
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  ```
  This is correct **because** murmur only uses encryption for HTTPS (the model download) and standard iOS APIs — it does not implement, incorporate, or ship proprietary encryption algorithms. ONNX model weights are not encryption.
- Cross-check: the app does not ship or use cryptographic algorithms beyond standard HTTPS and OS-provided crypto. Confirmed — Sherpa-ONNX and ONNX runtime do not perform encryption.
- If there's any doubt, the conservative path is `<true/>` + the annual self-classification exemption — but this triggers extra paperwork with no benefit for a pure-HTTPS app.
- For the Kokoro download, use a simple HTTPS URL from a stable host (GitHub release, Hugging Face, or your own static host). Do NOT serve the model over plain HTTP (will be blocked by ATS anyway).

**Warning signs:**
- App Store Connect shows "Missing Compliance" on every build
- TestFlight users can't install the build
- `ITSAppUsesNonExemptEncryption` missing from Info.plist
- Anyone proposing to "encrypt the model file for anti-piracy" — don't, it changes the compliance answer

**Phase to address:** **Phase 7** (distribution) but set the Info.plist key early so TestFlight builds flow in Phase 6 for QA.

**Severity:** **ANNOYANCE → SERIOUS** if it blocks launch day.

---

### Pitfall 12: Privacy labels (App Store) / Data safety form (Play Store) filled incorrectly

**What goes wrong:**
You submit with a privacy label claiming "no data collected," then reviewer rejects because the app uses HTTPS (misclassified as "connecting to external servers for data collection") or because a SDK silently collects data (audio_service? Flutter engine diagnostics? Firebase pulled in as a transitive dependency?). The rejection cycle is 24–48 hours each, and fixing labels after launch is allowed but feels unprofessional.

**Why it happens:**
Privacy labels conflate "sends bytes over network" with "collects user data." The Kokoro model download is a network call; a careless answer says "yes we contact servers" and reviewers assume telemetry. Also, Flutter engine and some plugins (even innocuous ones) may contribute SDK disclosures.

**How to avoid:**
- For App Store: in App Store Connect, complete App Privacy with "Data Not Collected." Apple's definition of "collect" is "transmit data off the device in a way that's used for tracking, advertising, or analytics by you or your third parties." A one-time model download is not collection. State this clearly in App Review Notes.
- For Play Store: Data Safety form — mark all categories as "No" (not collected, not shared). Under "Security practices," enable "Data is encrypted in transit" (true — HTTPS) and "I can request data deletion" (trivially true — it's all local, uninstall deletes).
- Audit `pubspec.lock` for any plugin that phones home. The listed deps (go_router, riverpod, drift, file_picker, path_provider, sherpa_onnx, just_audio, audio_service, epub_view) should all be clean, but verify: grep for `http`, `firebase`, `analytics`, `crashlytics`, `sentry`, `google_`, `facebook` in resolved dependencies.
- Flutter engine: Dart VM does not send analytics in release builds. Safe.
- In App Review Notes for both stores, write a one-sentence description: "This app makes exactly one network request in its lifetime: a one-time HTTPS download of a voice synthesis model on first launch. No accounts, no telemetry, no analytics, no ads, no tracking."
- Write a privacy policy (required for paid apps on both stores) that truthfully says the same thing. Host it on a GitHub Pages or a static page.
- Privacy policy URL is REQUIRED on both stores — don't forget it.

**Warning signs:**
- Privacy policy URL is blank
- Data Safety form marks "collects personal info" because the question seemed to mean "holds user books on device"
- `http` package used for anything other than the model download
- Any Firebase or Crashlytics plugin in pubspec.yaml (spec says no — verify)
- Review rejection mentioning privacy label inconsistency

**Phase to address:** **Phase 7** (distribution) — but the privacy policy and store listing copy should be drafted in Phase 6 so Phase 7 is upload-only.

**Severity:** **SERIOUS** — launch-blocking if rejected.

---

### Pitfall 13: Content rating (IARC) questionnaire answered without thinking

**What goes wrong:**
IARC questionnaire asks "does your app contain user-generated content," "does it access the internet," etc. Honest answers push the rating from 3+ to Teen or higher, which hurts discoverability. Also: the content of the ebooks users import isn't rated by murmur itself, but reviewers may ask.

**Why it happens:**
The questionnaire is aggressive — "connects to the internet" alone can bump ratings. For a book-rendering app, the IARC questions about user-generated content are ambiguous (users import files, but don't share them).

**How to avoid:**
- Google Play: content rating required by Jan 31 2026 (verified — recent policy update). Complete the IARC questionnaire: for murmur, expected rating is "Everyone / 3+" because the app contains no violence, sexual content, or gambling and only connects to the internet once for a model download.
- Answer honestly: the one-time model download is a "fixed, curated connection" not an "unrestricted internet browser." Explain in the free-text field that the single network call is a TTS model download with no user data exchanged.
- User-imported ebooks: the app does not curate or distribute content. Answer "no user-generated content" with note: "Users import their own DRM-free EPUB files from device storage; no content is shared, uploaded, or distributed by the app."
- App Store: similar questionnaire. Age rating likely 4+. Do not overclaim — reviewers verify.
- Do NOT advertise murmur as "read any book" implying piracy. Store listing must clearly say "DRM-free EPUBs that you already own" to avoid a DMCA-adjacent rejection.

**Warning signs:**
- Listing copy says "read any ebook"
- Screenshots show copyrighted content (use public-domain books like Alice in Wonderland, Moby Dick, Pride and Prejudice)
- Age rating comes back as Teen unexpectedly
- Reviewer question about "how does the app prevent piracy"

**Phase to address:** **Phase 7** (distribution).

**Severity:** **ANNOYANCE** unless misclassified, then **SERIOUS**.

---

### Pitfall 14: Code-signing and app size due to bundled model assets

**What goes wrong:**
Even though the 82 MB model is downloaded at runtime, `voices.bin` (~3 MB) and `tokens.txt` (~1 KB) are bundled — plus the Sherpa-ONNX native libraries (`libsherpa-onnx-c-api.so` per ABI on Android, framework on iOS), plus ONNX Runtime native libs. The total bundle can exceed 100 MB before any code. Google Play has a 200 MB APK/AAB limit (assets beyond that need Play Asset Delivery). iOS has different cellular download thresholds (200 MB for cellular download without warning). Also: large `.onnx` files bundled in iOS app bundle must be code-signed at each submit — tooling sometimes drops signatures on binary assets.

**Why it happens:**
Sherpa-ONNX native libraries include ONNX Runtime which is ~20 MB per architecture. Android multi-arch builds ship arm64-v8a, armeabi-v7a, x86_64 — potentially 60 MB just for native libs. iOS fat binary is ~30–40 MB.

**How to avoid:**
- **Android:** Enable `abiFilters` in `build.gradle` to ship arm64-v8a + armeabi-v7a only (drop x86_64 for production; emulators use AAB splits). Use Android App Bundle (AAB) so Play delivers architecture-specific APKs — cuts per-device size in half.
- **iOS:** Use App Thinning via Xcode's default settings; no manual action, but verify the distribution IPA is thinned.
- Confirm bundle size before release: `flutter build appbundle --release --split-per-abi` then check sizes; target <50 MB per-device install.
- Do NOT bundle the 82 MB ONNX model in the app — it stays a runtime download. The spec already says this — verify it's actually not in assets.
- Code-signing: for iOS, ensure `voices.bin` and `tokens.txt` are in the Runner bundle's Resources and get signed during the archive process. If a custom build phase copies them, verify signatures with `codesign -dv` after archive.
- Use File Provider or Documents folder for the downloaded model so it's not in the signed bundle (downloaded-at-runtime assets don't need to be signed).
- First-launch model download UX: show download size clearly (82 MB), progress bar with resumability, disk space check before start (need 2× model size for download + unpack if unpacked).
- Model download must be resumable across app restarts — users will background the app mid-download.
- Serve over HTTPS with a checksum (SHA-256) verified after download; reject mismatches.
- Have a backup mirror URL.

**Warning signs:**
- `flutter build appbundle` produces a >100 MB AAB
- Assets folder contains `.onnx` files
- First launch stalls on a flaky model download with no retry
- iOS build error: "code object is not signed at all" for voices.bin

**Phase to address:** **Phase 4** (model download flow) and **Phase 7** (distribution bundle size).

**Severity:** **SERIOUS** — bundle bloat and download failures kill first impressions.

---

### Pitfall 15: Sherpa-ONNX native library linking / build failures on iOS

**What goes wrong:**
The Sherpa-ONNX Flutter binding is less battle-tested than the C++ core. iOS builds can fail with linker errors for ONNX Runtime symbols, missing `module.modulemap`, `Undefined symbol: _OrtCreateEnv`, or issues with the XCFramework not being embedded. Android sometimes has issues with 16KB page size (Android 15 requirement for 2026 app updates) — older ONNX Runtime native libs may not be built with 16KB alignment and fail verification.

Also: iOS CocoaPods integration — the sherpa_onnx_ios plugin requires specific Podfile settings and can conflict with just_audio's iOS target version.

**Why it happens:**
Native-library Flutter plugins live at the intersection of Flutter tooling, iOS Xcode conventions, and the plugin author's build system. Bugs here show up rarely but are painful to debug.

**How to avoid:**
- Lock to a specific sherpa_onnx version in pubspec.yaml (not `^1.10.0` — pin to exact). Upgrade deliberately.
- On iOS: set Podfile `platform :ios, '13.0'` or higher (just_audio and audio_service both require iOS 13+). Run `pod install --repo-update` after any dependency change.
- On Android: target SDK 35 (Android 15), minimum SDK 24 (required by most modern plugins). Enable 16KB page size alignment via `android.defaults.buildfeatures.buildconfig=true` and verify the ONNX Runtime native lib is 16KB-aligned. If not, bump to a Sherpa-ONNX version that ships aligned libs, or accept that the app is not compliant with the Aug 2025 Play Store requirement for 16KB targeting (check current enforcement date).
- Test a release build on a physical Android 15 device.
- Set up CI (GitHub Actions) to build iOS and Android on every push — catches native linking failures immediately. Solo devs skip CI at their peril with this dependency stack.
- Have a fallback plan: if Sherpa-ONNX Flutter binding breaks on a critical platform update, be ready to wrap the C++ API directly via FFI as a last resort (time-consuming but possible).

**Warning signs:**
- Release build fails on iOS after working in debug
- `flutter run` works, `flutter build ipa` doesn't
- Android 15 device shows "This app isn't compatible with your device" post-install
- Cryptic `Undefined symbol` linker errors
- Pod install stuck on dependency resolution

**Phase to address:** **Phase 4** (first integration) and **Phase 7** (release builds + store compliance).

**Severity:** **BLOCKER** if it hits at release time.

---

### Pitfall 16: Isolate communication overhead eating the <300ms latency budget

**What goes wrong:**
Architecture is correct (synthesis isolate, UI isolate), but the message-passing overhead — serializing/deserializing sentence strings going one way and PCM bytes going the other — is nontrivial. A Float32List of 5 seconds of 24kHz audio is 480 KB; copying that across isolates per sentence at 120k+ sentences per book adds up. More critically, the round-trip `{send sentence, receive PCM, hand to just_audio}` can exceed the 300ms target if not pipelined.

**Why it happens:**
Dart isolates pass messages by copy (not reference) for non-transferable types. The sentence pipeline must be designed as a pipeline, not a request-response.

**How to avoid:**
- Use `TransferableTypedData` to move `Float32List` bytes between isolates without copying (zero-copy transfer).
- Pipeline: the synthesis isolate generates sentence N+1 while the UI plays sentence N. The queue is always one ahead.
- Keep the message payload small: send sentence *IDs* (lookup by ID in a shared Drift-backed or isolate-owned cache), receive payload IDs + transferable bytes.
- Pre-warm: when reader screen opens, synthesize sentence 0 so tap-Play is instant.
- Benchmark latency end-to-end: from `play()` invocation to first audio frame, on a cold model (first synthesis) and warm (subsequent). Target <300ms warm, <3s cold.
- Cache synthesized PCM for the next 2–3 sentences in memory (ring buffer, cap at ~5 MB) so quick pauses/resumes don't re-synthesize.
- Benchmark: the Kokoro-82M int8 latency is sub-0.3s for synthesis itself per the model card — isolate overhead is the risk, not the model.

**Warning signs:**
- `play()` to first-audio latency >500ms in profile mode
- `Float32List` appears in message payloads without `TransferableTypedData`
- Synthesis and playback are strictly sequential (next sentence starts synthesizing only after previous finishes playing)
- Unpausing has a noticeable delay

**Phase to address:** **Phase 4**, verify in **Phase 7** against the performance targets.

**Severity:** **BLOCKER** for hitting the <300ms spec target.

---

### Pitfall 17: Reader text normalization changing sentence indices

**What goes wrong:**
Chapter text for rendering ("with typography") and chapter text for TTS ("spoken prose") diverge over time. The reader strips HTML, preserves quotes, shows footnote markers, renders italics. TTS needs: no footnote markers (can't read "¹"), expanded abbreviations ("Dr." → "Doctor" — or not, depending on preference), numbers read as words or digits, currency ("$5" → "five dollars"), dates ("10/3/2024" → "October third"), Roman numerals ("Chapter IV" → "Chapter four"). If normalization lives in the TTS pipeline only, the sentence indices in the rendered text may not match the sentence indices in the spoken text — meaning highlight jumps to the wrong sentence.

**Why it happens:**
Text normalization is usually an afterthought bolted onto the TTS input. Nobody thinks about it until highlighting drifts mid-chapter.

**How to avoid:**
- Keep sentences as a shared data structure. Normalization is a transformation from `Sentence.text` (displayed) → `Sentence.spokenText` (fed to TTS). Both strings live on the same object; the sentence index is stable.
- Normalization rules for English v1:
  - Strip footnote markers (characters with superscript Unicode: `¹²³`, or `<sup>` elements from IR)
  - Expand common abbreviations for speech: Dr → Doctor, Mr → Mister, Mrs → Missus, Ms → Miz, St → Saint (when followed by a capitalized name) or Street (when following a number)
  - Numbers: leave as-is for Kokoro — it handles numbers tolerably. Test "1,000", "3.14", "1995", "10:30 am" and confirm prosody is acceptable; add targeted rules only if specific failures occur.
  - Decide: expand or not? Err on minimal normalization — Kokoro's training data includes numbers and common abbreviations. Over-normalization risks sounding stilted.
- Test normalization against a chapter with heavy abbreviation use (a Victorian novel: "Mr. Darcy said to Mrs. Bennet..."). Listen, adjust rules, iterate.
- Log normalization substitutions so users can report mispronunciations.

**Warning signs:**
- Sentence index in reader doesn't match what's currently spoken
- TTS reads "dee ar" for "Dr."
- Highlighted sentence jumps two ahead mid-chapter

**Phase to address:** **Phase 4** (synthesis pipeline) and **Phase 5** (highlight sync verification).

**Severity:** **SERIOUS**.

---

### Pitfall 1a: Using `epub_view` as a parser when it's actually a renderer

**What goes wrong:**
The spec lists `epub_view + epub_kit` as the EPUB dependency, but `epub_view` is primarily a **viewer widget** — it renders chapters internally to its own widget tree and does not necessarily expose raw XHTML of each chapter as a string or DOM for downstream custom rendering. If Phase 2 adopts `epub_view` for import metadata and Phase 3 later tries to build a sentence-span IR on top of the same package, the discovery that `epub_view` doesn't expose the raw chapter bytes happens mid-Phase 3 and forces a dependency swap — right after the fixture suite and parser were written against its API. Worst case: Phase 3 is half-rewritten to use `epubx` or raw zip extraction.

**Why it happens:**
`epub_view` looks like "the EPUB package for Flutter" on pub.dev and conflates two concerns (parsing + rendering). The package that does pure parsing — `epubx` (Dart port of the C# `EpubReader`) — is less visible. The spec was written before the architectural commitment to sentence-span rendering; the dependency choice is an artifact of earlier assumptions.

**How to avoid:**
Before writing any parser code in Phase 2, **verify empirically** that the chosen package exposes raw chapter XHTML (as `String` or bytes) for custom parsing. Write a 20-line spike that:
1. Loads a sample EPUB
2. Gets chapter content as XHTML text (not as a widget, not as a rendered RichText)
3. Hands it to `package:html` for custom DOM walking

If `epub_view` can't do step 2, replace it with:
- **`epubx`** — pure-Dart EPUB parser, exposes manifest, spine, chapter XHTML as `String`, TOC from `nav.xhtml`/`toc.ncx`. This is the likely correct choice.
- **Direct zip extraction via `package:archive`** + XML parsing of `META-INF/container.xml` and the OPF file + `package:html` for content documents. Maximum control, more code.

Do not commit to `epub_view` in pubspec.yaml until the spike confirms it can be used as a parser, not a renderer. Update the spec and PROJECT.md if the dependency changes.

**Warning signs:**
- Phase 2 pubspec contains `epub_view` but no code calls into it for raw chapter text
- Chapter content is retrieved as a `Widget`, not a `String`
- The only examples of `epub_view` usage in the wild use `EpubView` widget directly (rendering), not a chapter bytes API
- Phase 3 code contains a comment like `// TODO: figure out how to get raw HTML from epub_view`

**Phase to address:** **Phase 2 (import + parse)** — spike and decide before writing the parser. This is a dependency-architecture decision that must be made early.

**Severity:** **BLOCKER** — wrong choice here cascades into a Phase 3 rewrite.

---

### Pitfall 5a: Compound speed control (Sherpa `length_scale` × just_audio `speed`)

**What goes wrong:**
Phase 4 spec says speed uses "Sherpa `length_scale` param." But `just_audio` also has a `setSpeed()` API that changes playback speed after synthesis. If someone wires BOTH — passing `length_scale` to Sherpa *and* `speed` to just_audio — user sets 2× and gets 4× (2 × 2) because each layer applies its own factor. Or: user sets 1.5× in UI, code forwards it to only one of the two layers, and the speed setting silently does nothing the next time the user thinks they changed it.

There's a deeper design question: which layer *should* own speed? They have different tradeoffs:

| Approach | Pros | Cons |
|----------|------|------|
| Sherpa `length_scale` only | Highest audio quality (prosody is generated at target speed); no post-processing artifacts | Speed change requires re-synthesis of queued sentences — 1–3s delay when user changes speed; already-cached PCM at old speed must be discarded |
| just_audio `setSpeed` only | Instant speed change (no re-synthesis); cached PCM is reusable | 2× playback has slight "chipmunk" prosody on some devices; quality varies by platform audio engine (iOS uses AVAudioPlayer time-stretch which is decent; Android varies by ExoPlayer version) |
| Both layered | Never acceptable | Compound bug |

**Why it happens:**
Devs wire speed through the UI state provider, hand it to both the TTS service (which passes it to Sherpa) and the audio service (which applies it to just_audio) without noticing. Each looks correct in isolation. The test case is a single speed value (1×) where the compound has no visible effect.

**How to avoid:**
- **Pick one owner for speed.** Recommendation: use `just_audio.setSpeed()` for runtime speed control (instant UX, no re-synthesis, matches user expectation from podcast apps). Keep Sherpa `length_scale` fixed at 1.0 during synthesis. Quality on just_audio's time-stretch is good enough for spoken word at 0.75×–2×.
- Alternative: use Sherpa `length_scale` but *always* keep just_audio speed at 1.0, and accept that speed changes flush the pre-buffer queue and require a 1–2 sentence re-synthesize delay. Only pick this if blind listening tests reveal just_audio's time-stretch is audibly bad on target devices.
- Document the choice in code and spec. Add an assertion in the audio service that `just_audio.speed == 1.0` if `length_scale != 1.0` (or vice versa).
- Never expose two speed knobs in the UI.
- Test: user sets 2× in UI, measure actual wall-clock playback time of a 30-second sentence; must be ~15 seconds, not ~7.5 seconds.

**Warning signs:**
- Both `SherpaOnnxService.synthesize(text, speed: ...)` and `AudioHandler.setSpeed(...)` are called from the same user action
- A single "speed" value flows through two separate layers
- User reports "speed feels too fast" but spec says it should be 2×
- Queued pre-buffered sentences play at the wrong speed after a speed change (old `length_scale` baked in)
- Speed setting appears to "stick" on some sentences and not others

**Phase to address:** **Phase 4** — make the decision the day speed control is wired, document it in the TTS service contract.

**Severity:** **SERIOUS** — compound bug is immediately visible; ownership confusion creates subtle speed-change latency issues.

---

## Moderate Pitfalls

### Pitfall 18: First-chapter page-break handling

**What goes wrong:**
EPUB chapter files sometimes start with a half-title, epigraph, or decorative element that is NOT the chapter title. Naive extraction uses the first `<h1>` as the chapter name, missing the actual chapter 1. Or: a book's "Preface" and "Prologue" get lumped into chapter 1 because the TOC references them as separate entries but they share an HTML file.

**How to avoid:**
Trust the EPUB's `<spine>` and `toc.ncx`/`nav.xhtml` for chapter boundaries, not HTML heading inference. `epub_view` / `epub_kit` should expose these — use them.

**Phase:** Phase 2–3. **Severity:** ANNOYANCE.

---

### Pitfall 19: Font embedding causing rendering issues

**What goes wrong:**
Some EPUBs embed fonts (often obfuscated). Loading obfuscated fonts in a custom renderer requires deobfuscation per the IDPF spec. Easier path: ignore embedded fonts entirely and use the app's 3–4 bundled reader fonts (spec is already this way).

**How to avoid:**
Explicitly discard `@font-face` rules and font files in EPUB parsing. Document that murmur uses its own curated fonts.

**Phase:** Phase 2. **Severity:** ANNOYANCE.

---

### Pitfall 20: Image loading from EPUB manifest paths

**What goes wrong:**
EPUB HTML `<img src="../images/foo.jpg">` uses paths relative to the containing XHTML file. Naive image loaders look for `foo.jpg` in the root. Images don't render.

**How to avoid:**
Resolve image paths relative to the spine item's path. Cache extracted images as files in app documents directory; reference by file URI in the rendered IR.

**Phase:** Phase 2–3. **Severity:** ANNOYANCE.

---

### Pitfall 21: Reading progress debounce losing the last page

**What goes wrong:**
Spec says "debounced 2s" — but if the user closes the app within 2 seconds of a page turn, progress isn't saved.

**How to avoid:**
Add `WidgetsBindingObserver` and flush the debounce on `AppLifecycleState.paused`, `.inactive`, and `.detached`. Save synchronously before backgrounding.

**Phase:** Phase 3. **Severity:** ANNOYANCE.

---

### Pitfall 22: Sleep timer not actually sleeping

**What goes wrong:**
Sleep timer uses a `Timer` that pauses when the app is backgrounded on iOS. User starts timer at 30 min, backgrounds the app, comes back 45 min later, TTS is still playing.

**How to avoid:**
Schedule the sleep timer against wall-clock time (`DateTime`-based), not elapsed Timer ticks. On app resume, check if the sleep time has passed.

**Phase:** Phase 6. **Severity:** ANNOYANCE.

---

### Pitfall 23: Voice preview audio files approach

**What goes wrong:**
Voice preview button plays a pre-recorded 2-second sample per voice. Options: (a) bundle 10 WAV files (~2 MB total), (b) synthesize on demand. Bundling is simpler but static; on-demand shows real quality but has latency.

**How to avoid:**
Synthesize preview on demand using the same `synthesize()` pipeline. Cache the first preview per voice after first play. Use a fixed preview sentence ("The quick brown fox jumps over the lazy dog. This is a sample of my voice.") stored as a constant.

**Phase:** Phase 4. **Severity:** ANNOYANCE.

---

### Pitfall 24: Drift migration plan missing

**What goes wrong:**
v1.0 ships with schema version 1. A month later, a bookmark feature or a new column is needed. Users with v1.0 upgrade and their DB breaks because no migration was written.

**How to avoid:**
Use Drift's `MigrationStrategy` from day one. Write the no-op v1 migration, then grow schemas via `onUpgrade`. Every schema change bumps the version and adds a migration step. Test migrations with a seeded v1 DB file.

**Phase:** Phase 1 (initial setup) and Phase 7 (release discipline).

**Severity:** ANNOYANCE → SERIOUS if shipped wrong.

---

### Pitfall 25: File picker returning content URIs, not file paths (Android)

**What goes wrong:**
On Android, `file_picker` returns a content:// URI pointing to a SAF document, not a real file path. Trying to open it with `File(path).readAsBytes()` crashes. Also: the URI is a transient grant — once the app is restarted, the grant may be gone.

**How to avoid:**
Copy imported EPUBs to the app's own documents directory on import. Store the local path in the DB, never the original URI. Never retain content:// URIs across sessions.

**Phase:** Phase 2. **Severity:** SERIOUS on Android.

---

### Pitfall 26: iPadOS Stage Manager / external display

**What goes wrong:**
App runs on iPad with Stage Manager, user attaches an external display, app window moves or duplicates, audio routing gets confused, lock screen / now-playing shows on both displays inconsistently.

**How to avoid:**
Don't over-engineer for this edge case in v1. Test that the app doesn't crash on external display attach. Audio routing should follow iOS's current output device via `AVAudioSession`.

**Phase:** Phase 6 (validate), **Severity:** ANNOYANCE.

---

### Pitfall 27: Cover image memory on library screen

**What goes wrong:**
Library grid with 100+ books loads all covers at full resolution, RAM pressure spikes, scroll stutters.

**How to avoid:**
Cache resized cover thumbnails (~200×300px) as files in app documents. Render with `Image.file` from the cached path. Use `cacheWidth`/`cacheHeight` on Image to avoid decoding full-res bitmaps.

**Phase:** Phase 2. **Severity:** ANNOYANCE.

---

## Minor Pitfalls

### Pitfall 28: Haptics on iPad
Some iPads don't have the taptic engine. `HapticFeedback.lightImpact()` is a no-op on those — fine, no handling needed, but don't rely on haptics as the only feedback.

### Pitfall 29: Dark mode system toggle mid-reading
If user toggles system dark mode while reading, theme swap must not lose scroll position or highlighted sentence.

### Pitfall 30: Very long sentences (>500 chars)
Some 19th-century prose has sentences longer than Kokoro's context window. Test with Moby Dick or Proust; either chunk long sentences at comma boundaries before synthesis or hard-cap at ~400 chars.

### Pitfall 31: Empty chapters
Some EPUBs have "chapters" that are just a title image (e.g., Part dividers). TTS queue should skip zero-content chapters gracefully.

### Pitfall 32: Tab character and weird whitespace
EPUBs can contain tabs, no-break spaces, em-spaces. Normalize whitespace at parse time; pure Dart `\s` regex covers these but `trim()` doesn't handle U+00A0 reliably — use a Unicode-aware normalizer.

### Pitfall 33: First-run model download on metered connection
User on cellular taps "download model," burns 82 MB. Show an explicit "Downloading 82 MB — Wi-Fi recommended" warning. Check connectivity type via `connectivity_plus` (need to add this dep) and warn on cellular.

### Pitfall 34: Signing key loss
Android signing keys lost = new app, not an update. Store the keystore in a password manager or secure cloud on day one.

### Pitfall 35: Crash log PII
Local crash logs may contain file paths with the user's username. If the user shares the log, that's disclosure. Sanitize paths before writing to the shareable log.

### Pitfall 36: Kokoro mispronunciation of character names
Kokoro doesn't know how "Hermione" or "Faramir" are pronounced. This is inherent to non-phoneme-input neural TTS. Set expectations in the store listing: "voice quality is best on standard English text; character names in fiction may vary."

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Use `flutter_widget_from_html` for reader, plan to swap for sentence spans later | Phase 3 ships in 2 days | Phase 5 becomes a full reader rewrite; sentence-span IR has to be retrofitted; highlighting delayed by weeks | **Never** — explicit spec commitment forbids this |
| Hard-code a 50-item abbreviation list and ship | Splitter done in an hour | Every Victorian novel sounds broken; bad reviews mention "it reads Mr. as two sentences" | Only as a stub during Phase 4 prototyping; must be expanded before Phase 5 |
| Use `compute()` for TTS synthesis (model reloads every call) | No isolate architecture needed | 1–3s latency on every synthesis, 80 MB model re-deserialized repeatedly, battery drain | **Never** |
| Bundle the 82 MB model in assets instead of runtime download | No download flow needed | App bundle exceeds 100 MB, Play Store AAB limits hit, iOS cellular install warnings, slow first launch | Only for internal builds during Phase 4 development |
| Single global RichText for whole chapter | Simpler Phase 3 | 60fps target impossible, memory leaks, highlight-rebuild cost prohibitive | **Never** past Phase 3 early prototypes |
| Skip physical device testing until Phase 7 | Faster iteration in emulator | Background audio, file picker, Sherpa-ONNX linking, audio session issues all discovered in Phase 7 | **Never** — physical device test at every phase |
| Skip CI, build manually | No setup time | iOS build breaks between commits undetected; Android 16KB alignment regressions missed | Only for solo dev with religious local-build discipline, which is rare |
| Use the built-in `epub_view` renderer in Phase 2, swap in Phase 3 | Phase 2 library screen faster to prototype | Two reader code paths briefly exist; limited exposure | Acceptable if Phase 3 is immediate — do not defer |
| One preview recording per voice bundled as MP3 | No synthesis at preview time | Stale — preview may not reflect actual synthesis quality | Acceptable post-MVP if on-demand synthesis is too slow |
| Privacy policy as a one-pager `docs/privacy.html` in the repo | Free hosting via GitHub Pages | None | **Always acceptable** for this product |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Sherpa-ONNX Flutter binding | Load on main isolate; use `compute()` per call | Dedicated long-lived synthesis isolate, `Isolate.spawn()`, handle created in the isolate |
| Kokoro ONNX model | Ship in assets | Runtime HTTPS download to documents dir, checksum-verified, resumable |
| just_audio + PCM | Feed raw Float32List | Wrap in WAV header (int16 PCM, 24000 Hz, mono), use StreamAudioSource for gapless |
| audio_service | Init lazily from a provider | `await AudioService.init(...)` in `main()` before `runApp` |
| audio_service media item | Set once, ignore updates | Update `mediaItem` on chapter change, `playbackState` on every play/pause/seek |
| EPUB content parsing | `package:xml` strict parser | `package:html` lenient parser; fallback to XML only for `container.xml` and OPF |
| Drift schema | No migration plan | `MigrationStrategy` from v1, versioned schemas, test DB upgrades |
| file_picker on Android | Read from returned URI directly | Copy to app documents dir on import |
| iOS background audio | Assume "it works in dev" | Test release build on physical device, lock screen, interruptions |
| MediaQuery for layout | Global screen size check | `LayoutBuilder` at the scaffold level |
| RichText highlighting | One giant RichText per chapter | Per-paragraph RichText in ListView.builder, RepaintBoundary on active paragraph |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Monolithic chapter RichText | Jank on highlight updates, slow scroll | Per-paragraph RichText in ListView.builder | Chapters >200 sentences; any long-form content |
| Model load on main isolate | UI freeze on first Play, ANR | Background isolate, pre-warm on reader open | First synthesis after app launch |
| Float32List copy across isolates | Latency >300ms, GC pauses | `TransferableTypedData` for PCM transfer | Any long reading session (accumulated GC) |
| Synthesize-then-play strict serialization | Gaps between sentences, cold-start per sentence | Pipeline: synthesize N+1 while playing N | Normal playback flow |
| Cover image full-res decode | Library stutter, RAM spike | Cached thumbnails, `cacheWidth`/`cacheHeight` | Library >50 books |
| No viewport recycling in reader | Memory grows with chapter length; slow scroll-to-position | ListView.builder / Sliver-based reader | Chapters >100 pages |
| Rebuild whole reader on highlight change | Jank at every sentence boundary | Isolate rebuild to the active paragraph only | Any Phase 5 playback |
| WAV file per sentence on flash | Disk thrash, eventual wear | In-memory buffers or memory-mapped temp files, aggressive cleanup | Long (2hr+) sessions |
| Unbounded sentence cache | Memory leak, OOM | Ring buffer, cap at 5 MB | Long reading sessions |
| Debounced progress saves lost on kill | Position loss after crash or fast-quit | Flush on lifecycle pause | Daily; every user at some point |

---

## Security / Privacy Mistakes

This app has an unusually simple threat model: no network, no accounts, no telemetry. But:

| Mistake | Risk | Prevention |
|---------|------|------------|
| Accidentally including Firebase / Crashlytics / Sentry as transitive dependency | Privacy label lie, store rejection, contradicts core value | Audit `pubspec.lock` before each release; grep for known telemetry SDKs |
| Logging user file paths or book titles to the local crash log without sanitization | User shares log publicly, leaks reading habits | Sanitize log output: strip usernames from paths, hash book identifiers |
| Downloading model over HTTP or without checksum | MITM model replacement, arbitrary code via ONNX runtime bugs | HTTPS only, SHA-256 verification, fail-closed on mismatch |
| Serving model from a URL that can be revoked | First-launch breakage months later | Pin to a specific GitHub release URL or host on own static storage |
| Reading arbitrary files via the file picker | SAF content:// URI confusion on Android | Validate file is a zip with EPUB mimetype before parsing; reject non-EPUB |
| Storing reading progress with device-identifying information | Privacy regression | DB rows keyed on local book ID only, no device ID anywhere |
| Leaving debug menus or telemetry toggles in release | Accidental shipping of dev telemetry | Release build flags, pre-release smoke test |
| Allowing the app to be installed on rooted/jailbroken devices and assuming local storage is secure | Not a security claim this app makes | Document honestly: "data is stored on device without encryption; same as any standard app" |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Making the user download the 82 MB model before they can import a book | Bounces new users | Let users browse library, prompt model download only when they hit Play on a book |
| Silent model download failure on first launch | User has an app that can import books but never speaks | Explicit progress UI, clear error states, retry button, manual re-download in settings |
| No indication that TTS is warming up (cold-start latency) | User taps Play, waits 2 seconds of silence, taps Play again | "Preparing voice…" spinner until first audio frame |
| Highlight animation that's too aggressive | Eye fatigue, motion sickness | Subtle background color, no scale/bold changes, option to disable |
| Auto-scroll centering vs. upper-third | Centering feels twitchy, users skip ahead | Upper-third (0.3 alignment) feels like natural reading |
| Showing 53 Kokoro voices instead of curated 10 | Decision paralysis | Already in spec — 10 curated |
| Voice preview doesn't convey the actual reading voice | User picks voice based on preview, hates it on a real paragraph | Use a more representative preview sentence (narrative prose, not "the quick brown fox") |
| Immersive mode on tap-center but also on every scroll | Chrome flickers on every scroll | Tap-center only; chrome persists during scroll |
| Sleep timer shows "30:00" and counts up | Users confused if it's counting up or down | Count down with visible decreasing time |
| No "continue reading" state on app launch | User has to navigate to library → find book → tap | Launch directly into the last-read book if progress exists |
| Chapter list shows chapter numbers only | Users scanning for "chapter about X" can't find it | Show chapter titles from TOC, not "Chapter 12" |
| No error recovery for failed EPUB import | User gives up after one failure | Snackbar with "why it failed" + "try another file," never crash |
| Storage usage opaque | User can't tell how much space 20 books takes | Settings screen shows model size, book storage, total |

---

## "Looks Done But Isn't" Checklist

Verification during Phase 7 (before submission):

- [ ] **Reader:** Renders 10+ real EPUBs from varied publishers without visible corruption — verify with fixture corpus
- [ ] **Sentence splitter:** Passes all 500+ fixture sentences — verify against regression suite, no zero-length sentences in output
- [ ] **TTS playback:** Starts within 300ms of Play tap in warm state — measure with profile build on physical device
- [ ] **Background audio:** Survives 60 seconds of screen off on iOS release build — test on physical iPhone
- [ ] **Background audio:** Survives a phone call interruption — test on physical device
- [ ] **Lock screen controls:** Show book title, author, cover art — verify on iOS lock screen, Android media notification
- [ ] **Lock screen scrubber:** Updates as TTS progresses — verify physically
- [ ] **Highlight sync:** Stays within 1 sentence of actual speech for full chapter — listen to 10-minute chapter
- [ ] **Auto-scroll:** Keeps active sentence in upper third without jitter — visual inspection on phone and tablet
- [ ] **Chapter navigation:** TOC uses real chapter titles from EPUB navigation, not heading inference
- [ ] **Memory:** 2-hour playback on 1000-page EPUB stays under 300 MB — check with DevTools profile
- [ ] **Scroll performance:** 60fps on mid-range Android (Pixel 6a / Galaxy A54 class) during reader scroll — DevTools frame graph
- [ ] **Responsive layout:** iPad split-view at 1/3 uses phone-like layout, at 1/2 uses tablet layout — physical test
- [ ] **Accessibility:** TalkBack reads paragraphs as one block, not sentence-by-sentence
- [ ] **Accessibility:** VoiceOver navigates chapter list and playback controls correctly
- [ ] **Import:** Content URIs on Android copy to app storage; work after app restart
- [ ] **Model download:** Resumable across app restart; checksum verified
- [ ] **Progress save:** Survives force-quit immediately after page turn
- [ ] **Privacy policy:** Hosted URL is live and correctly matches store listing
- [ ] **Export compliance:** `ITSAppUsesNonExemptEncryption=false` in Info.plist
- [ ] **Android manifest:** `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission present, foreground service type declared
- [ ] **iOS Info.plist:** `UIBackgroundModes` array contains `audio`
- [ ] **Bundle size:** Per-device install <60 MB (not counting model download)
- [ ] **First launch:** Model download UI clear, offers Wi-Fi warning on cellular, resumable
- [ ] **Error paths:** Every async call in import / TTS / file I/O has a try/catch that surfaces user-visible errors, not crashes
- [ ] **Crash log:** Shareable from settings, sanitized of PII
- [ ] **Drift migration:** Version 1 migration strategy defined (even as no-op)
- [ ] **Physical devices tested:** Low-end Android (<$200), high-end Android, iPhone SE or mini, iPhone Pro, iPad mini, iPad Pro
- [ ] **Store listing:** Screenshots use public domain books only
- [ ] **Store listing:** Content rating (IARC + App Store) matches truthful questionnaire answers
- [ ] **Keystore backed up:** Android signing key saved to password manager + offline backup
- [ ] **No telemetry dependencies:** `pubspec.lock` grepped for firebase, crashlytics, sentry, analytics, google_ — all absent

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| EPUB IR too flat (Pitfall 1) | HIGH | Pause feature work, redesign IR, migrate Phase 3 renderer, re-verify fixtures, redo Phase 4 sentence binding |
| Sentence splitter wrong on a class of inputs | LOW | Add test case, tune gazetteer/rules, re-run fixture suite |
| Model load on main isolate (Pitfall 4) | MEDIUM | Extract TTS service into isolate-based architecture, migrate service interface, re-test latency budget |
| Background audio broken in release (Pitfall 6) | LOW–MEDIUM | Info.plist / AndroidManifest fix, rebuild, re-test on physical device — usually 1 session |
| Per-sentence rebuild jank (Pitfall 8) | MEDIUM | Refactor monolithic RichText into ListView.builder of per-paragraph RichText, add RepaintBoundary |
| Store rejection for privacy label (Pitfall 12) | LOW | Fix labels in store console, resubmit — 24–48 hr delay |
| Store rejection for missing export compliance (Pitfall 11) | LOW | Add Info.plist key, rebuild, resubmit — 24 hr delay |
| Sherpa-ONNX native linking breaks on new Flutter version (Pitfall 15) | HIGH | Pin to last working Flutter/sherpa versions, file upstream issue, hold off on toolchain upgrade |
| Model download URL goes dead | MEDIUM | Mirror fallback baked in from day one; if not, emergency app update with new URL |
| Memory leak over long session | MEDIUM | Profile with DevTools memory view, find retain cycles, add RepaintBoundaries, cap caches |
| iOS privacy label rejected post-launch | LOW | Clarify language, resubmit; no build required for label-only changes |
| App Store 4+ age rating challenged (DRM concerns) | MEDIUM | Update listing copy to emphasize DRM-free user-owned content, add clarification to App Review Notes, resubmit |

---

## Pitfall-to-Phase Mapping

| Pitfall | Severity | Prevention Phase | Verification |
|---------|----------|------------------|--------------|
| 1. EPUB HTML leaking past parse boundary | BLOCKER | Phase 3 | IR type definition review + fixture snapshot tests |
| 1a. `epub_view` is a renderer, not a parser | BLOCKER | Phase 2 | Pre-parser spike confirms raw-XHTML access or swap to `epubx` |
| 2. Malformed EPUB XHTML variants | SERIOUS | Phase 2 | Fixture corpus of 15+ real EPUBs parses without error |
| 3. Sentence splitter edge cases | SERIOUS | Phase 4 (prototype in isolation first) | 500+ fixture sentence regression suite passes |
| 4. Sherpa-ONNX on main isolate | BLOCKER | Phase 4 | Cold-start and warm latency benchmarks <3s / <300ms |
| 5. PCM/sample rate mismatch with just_audio | BLOCKER | Phase 4 | Gapless playback verified on iOS + Android |
| 5a. Compound speed (Sherpa × just_audio) | SERIOUS | Phase 4 | Single owner for speed, assertion in code, wall-clock playback test |
| 6. iOS background audio not surviving lock | BLOCKER | Phase 4 | Physical device lock-screen test |
| 7. Lock screen metadata drift | SERIOUS | Phase 4 | Manual lock-screen control test matrix |
| 8. RichText rebuild tanking scroll | BLOCKER | Phase 3 (architecture) + Phase 5 (verify) + Phase 7 (profile) | 60fps benchmark on mid-range Android |
| 9. Accessibility regression from per-sentence spans | SERIOUS | Phase 6 | TalkBack/VoiceOver walkthrough |
| 10. MediaQuery-based layout breaking split-view | SERIOUS | Phase 1 + Phase 3 + Phase 6 | iPad split-view test matrix |
| 11. Missing export compliance declaration | ANNOYANCE→SERIOUS | Phase 7 (set in Phase 1) | Info.plist audit |
| 12. Privacy labels misfilled | SERIOUS | Phase 7 | Label audit + App Review Notes |
| 13. Content rating misanswered | ANNOYANCE | Phase 7 | IARC questionnaire review |
| 14. Bundle size / asset signing | SERIOUS | Phase 4 + Phase 7 | `flutter build appbundle` size check |
| 15. Sherpa-ONNX native linking failures | BLOCKER | Phase 4 + Phase 7 | CI builds iOS + Android on every push |
| 16. Isolate message overhead eating latency | BLOCKER | Phase 4 | TransferableTypedData used for PCM; latency benchmark |
| 17. Reader/TTS text normalization divergence | SERIOUS | Phase 4 + Phase 5 | Single sentence object with displayText + spokenText |
| 18. Chapter naming from wrong source | ANNOYANCE | Phase 2–3 | TOC-based chapter list |
| 19. Font embedding issues | ANNOYANCE | Phase 2 | Bundled reader fonts only |
| 20. EPUB image paths | ANNOYANCE | Phase 2–3 | Relative path resolution |
| 21. Progress save debounce loss | ANNOYANCE | Phase 3 | Lifecycle flush on paused state |
| 22. Sleep timer drift | ANNOYANCE | Phase 6 | Wall-clock timer |
| 23. Voice preview strategy | ANNOYANCE | Phase 4 | On-demand synthesis |
| 24. Drift migrations | ANNOYANCE→SERIOUS | Phase 1 + Phase 7 | Migration strategy present from v1 |
| 25. Android content URI handling | SERIOUS | Phase 2 | Import copies to app documents |
| 26. iPadOS multitasking edge cases | ANNOYANCE | Phase 6 | Smoke test, no crashes |
| 27. Cover image memory | ANNOYANCE | Phase 2 | Thumbnail cache |

---

## Sources

- [Flutter RichText class documentation](https://api.flutter.dev/flutter/widgets/RichText-class.html) — per-render-object layout behavior
- [sherpa_onnx Flutter package on pub.dev](https://pub.dev/packages/sherpa_onnx) — official bindings
- [Sherpa-ONNX Flutter docs](https://k2-fsa.github.io/sherpa/onnx/flutter/index.html) — integration guide and platform notes
- [k2-fsa/sherpa-onnx GitHub](https://github.com/k2-fsa/sherpa-onnx) — source, ONNX Runtime native lib packaging
- [flutter_kokoro_tts package](https://libraries.io/pub/flutter_kokoro_tts) — Kokoro output format confirmation (24000 Hz Float32)
- [audio_service package](https://pub.dev/packages/audio_service) — background audio architecture
- [just_audio_background package](https://pub.dev/packages/just_audio_background) — background playback add-on
- [just_audio package](https://pub.dev/packages/just_audio) — StreamAudioSource docs
- [Apple: Complying with Encryption Export Regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations) — export compliance requirements
- [Apple: ITSAppUsesNonExemptEncryption](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption) — Info.plist key reference
- [Apple: App Store Connect Export Compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/) — questionnaire path
- [Google Play: Content Ratings help](https://support.google.com/googleplay/android-developer/answer/9898843) — IARC questionnaire
- [Google Play: Developer Program Policy](https://support.google.com/googleplay/android-developer/answer/16852659) — Jan 2026 policy effective date
- [EPUB 3.3 spec (W3C)](https://www.w3.org/TR/epub-33/) — namespace and XHTML requirements
- [Readium architecture: Parsing EPUB Metadata](https://readium.org/architecture/streamer/parser/metadata.html) — real-world EPUB parsing considerations
- [Grammarly Engineering: How to Split Sentences](https://www.grammarly.com/blog/engineering/how-to-split-sentences/) — abbreviation and dialogue edge cases

Confidence notes:
- **HIGH:** App Store export compliance, iOS Info.plist keys, Kokoro sample rate (verified across multiple sources), EPUB parsing semantics, RichText rebuild semantics.
- **MEDIUM:** Sherpa-ONNX Flutter binding isolate behavior (documented in changelog + community reports; no authoritative API doc on handle transferability — treat as "probably not transferable, verify empirically in Phase 4"); Android 16KB alignment enforcement date (check closer to release).
- **LOW→MEDIUM:** Specific IARC rating outcome (depends on questionnaire answers, verified at submission only); exact latency figures for model cold-start (device-dependent, must be measured).

---
*Pitfalls research for: murmur — Flutter offline TTS ebook reader*
*Researched: 2026-04-11*
