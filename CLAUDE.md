<!-- GSD:project-start source:PROJECT.md -->
## Project

**murmur**

murmur is a Flutter-based ebook reader for Android and iOS (phones and tablets) that turns EPUB files you already own into audiobooks using on-device neural TTS. It's for people who want to *listen* to books they own without handing their library, progress, or attention to a cloud service, subscription, or ad network. One-time purchase (~$3), no accounts, no backend, no telemetry.

**Core Value:** You can point murmur at an EPUB and have it read to you — in a natural neural voice, fully offline, without ever creating an account. If the "tap a book, hear it read" loop doesn't feel good, nothing else matters.

### Constraints

- **Tech stack**: Flutter + Dart — single codebase lets one developer ship both stores; strong UI control needed for tablet typography
- **TTS engine**: Kokoro-82M via Sherpa-ONNX, int8 quantized — ~80MB model, sub-300ms latency, CPU-only, fully offline. System TTS is not an acceptable substitute.
- **Privacy / network**: Exactly one network call in the whole app — the one-time Kokoro model download on first launch. After that, airplane mode is a supported operating state.
- **Format**: EPUB only. DRM-free only. This is a hard line, not a "maybe later."
- **Language**: English only in v1. Non-English languages need their own splitter, normalizer, and curated voices — all out of scope for launch.
- **Distribution**: Paid one-time purchase, ~$3, Play Store + App Store. No IAP, no subscription, no free tier, no ads.
- **Form factor**: Android + iOS, phones and tablets. Phones are first-class, not a "fallback" layout. No desktop.
- **Team size**: Solo developer (Jonathan) with AI-assisted coding. Scope must fit that cadence.
- **Performance**: 60fps reader scroll on mid-range phones and tablets; TTS sentence-start latency < 300ms; no memory leaks over 2-hour sessions with 1000-page books.
- **Reader architecture**: The reader must treat sentences as a first-class data structure from Phase 3. No HTML-opaque renderers (`flutter_widget_from_html`, `flutter_html`, webview). This is a commitment, not a preference — see Key Decisions.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## TL;DR
## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Flutter** | 3.41.x (stable, Feb 2026) | UI framework | Single codebase for Android + iOS phones/tablets is the constraint. Flutter's widget system gives the fine-grained typography control the reader needs (per-span text styling for sentence highlighting), and its rendering engine hits 60 fps on mid-range hardware. Alternatives (React Native, KMP+Compose) lack Flutter's per-span text primitives or force two UI codebases. |
| **Dart** | 3.11.x | Language | Ships with Flutter 3.41. Dart 3's sound null safety, pattern matching, and records make the sentence-model data classes and repository layer pleasant. Pub workspaces (Dart 3.6+) is useful if the project later splits shared code. |
| **flutter_riverpod** | ^3.3.1 | State management | Compile-time-safe providers, no `BuildContext` coupling, excellent testability, and Riverpod's `AsyncValue` maps naturally onto every async boundary in this app (import, EPUB parse, TTS synthesis, audio state). Riverpod 3 (stable since late 2025) fixes the rough edges of 2.x — notably better disposal semantics, which matter for a TTS service that must fully release native resources on screen teardown. Confirming the leaning: **yes, Riverpod, not BLoC or Provider**. BLoC's boilerplate is a tax with no payoff at this codebase size; Provider lacks the compile-time guarantees you'll want when refactoring. |
| **riverpod_annotation + riverpod_generator** | ^3.0.x / ^4.0.3 | Code-gen for Riverpod | The `@riverpod` annotation generates typed, auto-disposing providers with zero boilerplate. Optional but recommended — makes providers read like async functions. Requires `build_runner`. |
| **go_router** | ^17.2.0 | Routing | Declarative, URL-driven routing that plays well with Riverpod. Deep-linking is free (helpful for "resume last book" from a launcher shortcut later). Handles the three routes you need — `/library`, `/reader/:bookId`, `/settings` — without ceremony. Confirming the leaning: **yes, go_router**. The only real alternative is Flutter's Navigator 2.0 directly (too much boilerplate) or `auto_route` (more features than you need, heavier build_runner cost). |
| **Drift** | ^2.32.1 | Local SQLite DB | Type-safe SQL, compile-time-checked queries, first-class Riverpod integration, reactive streams for "library grid auto-updates when books import." Far better than raw `sqflite` for any schema more than 2 tables. Confirming the leaning: **yes, Drift**. Companion packages required: `drift_flutter` (or `sqlite3_flutter_libs` — see below), `drift_dev` (dev dep), `build_runner` (dev dep). |
| **sqlite3_flutter_libs** | ^0.5.x | Bundled SQLite binary | Ships a recent SQLite with every Flutter build so you're not at the mercy of whatever iOS/Android ship. Required by Drift on mobile unless you use `drift_flutter` which wraps it. |
| **epubx** | ^4.0.0 (Jun 2023 — flagged) | Pure-Dart EPUB parser | EPUB is a zip of XHTML + OPF/NCX metadata. `epubx` extracts metadata (title, author, cover), the chapter list, and raw per-chapter HTML/XHTML strings without imposing a renderer. That is exactly the shape you need to feed your own HTML→sentence-span pipeline. **Staleness risk: the package has not been updated since June 2023. EPUB is a frozen spec, and a pure parser with no rendering layer has very little surface area for rot, but Dart 3.11 compatibility must be verified during Phase 1 scaffold.** If it fails, the fallback is either forking the package (small codebase) or rolling your own parser using `dart:io` + `package:archive` + `package:xml` + `package:html` — EPUB is fundamentally a zip of XHTML, which is ~150 lines of glue. |
| **package:html** | ^0.15.x | Dart HTML5 parser | `epubx` gives you per-chapter XHTML as a raw string. You need a DOM parser to walk it, strip/normalize, extract text runs with styling metadata (bold/italic/headings), and emit `Sentence { id, text, styleRuns }` records. `package:html` is the official Dart team's HTML5 parser — the right tool. Pair with `package:html/parser.dart` and `package:html/dom.dart`. |
| **sherpa_onnx** | ^1.12.36 | On-device neural TTS | Official Flutter bindings for the k2-fsa/sherpa-onnx C++ library. Kokoro TTS support landed in **1.10.40** (C++/Python), a Flutter example shipped in **1.10.42**, and 1.12.31 refactored to a new "Generate API" — you should target the post-refactor API. Release cadence is extremely active (6 patch versions in ~3 weeks in April 2026), which is simultaneously a good sign (engaged maintainer) and a stability flag (pin exact versions, review changelogs between bumps). **This is the single biggest risk in the stack — see Risks section.** |
| **just_audio** | ^0.10.5 | Audio playback | Feature-rich Flutter audio player. Supports custom `StreamAudioSource` for byte-stream input — which is how you get PCM from sherpa_onnx into the player. Confirming the leaning: **yes, just_audio**. Note the non-obvious glue required (PCM→WAV wrapping, see Gotchas). |
| **audio_service** | ^0.18.18 | Background audio + lock-screen controls | Wraps the platform-specific background-playback and media-notification APIs on both Android and iOS. Partners with just_audio by running your audio handler in an isolate. Both platforms support play/pause, next/prev, and media metadata on the lock screen. iOS requires `UIBackgroundModes: audio` in Info.plist. Confirming the leaning: **yes, audio_service**. No realistic alternative — this is the de facto Flutter solution. |
| **file_picker** | ^11.0.2 | System file picker | Opens the native file chooser with extension filtering. Supports `.epub` via its `FileType.custom` with `allowedExtensions: ['epub']`. Works on both Android (SAF) and iOS (UIDocumentPickerViewController). Confirming the leaning: **yes, file_picker**. Note: on iOS you need the `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` Info.plist keys if you also want users to drop EPUBs into the app's Files folder. |
| **path_provider** | ^2.1.x | Platform storage paths | Standard way to get the app documents directory for storing the downloaded model, cover cache, and the Drift DB file. Trivial, boring, required. |
### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **package:archive** | ^3.x | Zip parsing | Only if `epubx` turns out to be incompatible and you roll your own EPUB parser. |
| **package:xml** | ^6.x | XML parsing | Same fallback scenario — needed for parsing `content.opf` and `toc.ncx` if rolling your own. |
| **crypto** | ^3.x | Hashing | Use SHA-256 to verify the downloaded Kokoro model file matches a known hash before moving it into place. Avoids the "half-downloaded model gets loaded and crashes" failure mode. Recommend pinning a known-good hash in source. |
| **http** | ^1.x | Model download | Single-use: downloads `model.int8.onnx` on first launch. Standard Dart `http` package is fine — no need for dio. Stream to disk with a progress callback, write to a `.partial` file, verify hash, rename on success. |
| **shared_preferences** | ^2.x | Small settings | For "has the model been downloaded," "last-used theme," onboarding-complete flag. Drift is overkill for one-off bools. Some teams put these in a Drift `settings` table for consistency — either is fine; shared_preferences is less ceremony. |
| **flutter_localizations** | (bundled) | Locale / text direction | Needed for correct text rendering even though v1 is English-only — sets the `Directionality` and `Locale` so `TextPainter` line-breaking behaves. |
### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| **drift_dev** | Code-gen for Drift schema | Dev dependency. Runs via build_runner. |
| **riverpod_generator** | Code-gen for Riverpod | Dev dependency. Runs via build_runner. |
| **build_runner** | Code generation runner | Dev dependency. Run `dart run build_runner watch --delete-conflicting-outputs` during development. |
| **custom_lint + riverpod_lint** | Lint rules for Riverpod | Catches common provider mistakes at analysis time. Highly recommended — Riverpod's best feedback loop. |
| **flutter_launcher_icons** | App icon generation | Dev-time only. Generates all icon sizes from a single source image. |
| **flutter_native_splash** | Splash screen generation | Dev-time only. Same idea, splash screens. |
| **very_good_analysis** or **flutter_lints** | Lint ruleset | Pick one. `flutter_lints` is the official baseline; `very_good_analysis` is stricter. Solo developer — either works. |
## Installation
# pubspec.yaml
## Kokoro Model: Which Variant, Where From, How Big
### Recommended variant: `kokoro-int8-en-v0_19`
| File | Size (approx) | Ship with app? | Notes |
|------|---------------|----------------|-------|
| `model.int8.onnx` | ~80 MB | **No — download on first launch** | The only large file. This is the int8-quantized Kokoro-82M weights. |
| `voices.bin` | ~5.5 MB | **Yes — bundle** | Style vectors for the 11 English speakers. The spec said ~3 MB — that's wrong; it's ~5.5 MB. |
| `tokens.txt` | ~1 KB | **Yes — bundle** | Phoneme token vocabulary. |
| `espeak-ng-data/` | ~1 MB | **Yes — bundle** | Phonemization rules for English. sherpa-onnx needs this at runtime; the Flutter API takes a directory path. |
| `LICENSE`, `README.md` | trivial | Yes — bundle | Required by the model's license. |
### Why v0_19 (and not v1.0 or v1.1)
- **v0_19** — 11 English-only speakers, perfect match for the "~10 curated voices" commitment in PROJECT.md. Smaller model. No wasted weight on languages you're not shipping.
- **v1.0 / v1.1** (multilingual) — 53–103 speakers, adds Chinese + other languages, base model is 310 MB (int8 variant is also larger). Wrong for an English-only v1.
- **f32 / f16 / int8** — int8 is the right quantization for mobile; the quality drop is negligible at reading pace and the download size halves vs f16.
### Hosting strategy for v1
## Alternatives Considered
| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| **epubx + custom renderer** | `flutter_epub_viewer` | Only if you abandon the sentence-span commitment and accept a WebView-based reader. This package wraps epub.js inside flutter_inappwebview — great for a general EPUB reader app, fundamentally incompatible with `RichText`-based sentence highlighting. Not for murmur. |
| **epubx + custom renderer** | Roll-your-own parser (`archive` + `xml` + `html`) | Fallback if `epubx` fails under Dart 3.11 during Phase 1. EPUB is a zip of XHTML + an OPF manifest + an NCX TOC — maybe 200 lines of Dart. Keep this in your back pocket; don't start here. |
| **sherpa_onnx** | `kokoro_tts_flutter` package | This is a community-maintained Flutter port of Kokoro TTS that uses onnxruntime directly and its own G2P engine. It bypasses sherpa-onnx entirely. Consider only if sherpa_onnx Flutter bindings prove unworkable — but sherpa-onnx is the better bet: larger community, more platforms, deeper TTS track record, and direct C++ backing. The kokoro_tts_flutter package has a much smaller user base and less battle-testing. |
| **Riverpod** | BLoC / Cubit | BLoC makes sense for teams of 5+ where the boilerplate is a feature (enforces separation). Overkill for solo. |
| **Riverpod** | Provider | Provider is what Riverpod replaced. No reason to pick it in 2026 for a greenfield project. |
| **go_router** | `auto_route` | auto_route wins if you want nested tab navigation with type-safe args across dozens of routes. You have three routes. go_router. |
| **Drift** | `sqflite` + hand-written SQL | Use sqflite if the team has allergic reactions to code generation. The type safety and reactive streams from Drift are worth build_runner's tax, especially for the "library grid auto-updates when import completes" UX. |
| **Drift** | `isar` | Isar is fast but has had a rocky maintenance story (original author stepped back, revival attempts ongoing). Drift is the safer bet in 2026. |
| **just_audio + audio_service** | `audioplayers` | audioplayers is simpler but lacks the `StreamAudioSource` primitive you need to feed PCM from sherpa-onnx. Dead end for this project. |
| **file_picker** | `flutter_document_picker` | file_picker is more active and has better iOS support in 2026. |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **`epub_view`** | Last published June 2023 (no updates in ~3 years), **depends on `flutter_html`** which is exactly the HTML-opaque renderer murmur has rejected. Using epub_view bakes flutter_html into your dependency tree and gives you a rendered widget you can't introspect for per-sentence spans. This is not a "compatible with extra work" situation — it's architecturally incompatible with the Phase 3 commitment. | `epubx` (pure parser, no rendering layer) + `package:html` + your own `RichText` pipeline. |
| **`flutter_html`** | Produces an opaque widget tree from HTML. Cannot expose per-sentence `TextSpan` handles. Custom widget factories can be written but they fight the library's design. Also has historically had perf issues on long chapters. Already explicitly rejected in the spec. | Parse HTML with `package:html`, walk the DOM yourself, emit your own `Sentence → List<TextSpan>` records. |
| **`flutter_widget_from_html`** | Same fundamental problem as `flutter_html` — opaque rendering, no per-sentence handles. Explicitly rejected in PROJECT.md. | Same as above. |
| **`webview_flutter` as a reader renderer** | Works, but you lose native scrolling physics, native text selection, per-span styling, and you pay a ~30–50 MB runtime memory hit per reader instance. A WebView reader is a different product than what murmur is targeting. | Native `RichText` pipeline. |
| **`flutter_tts`** | Wraps platform system TTS. The spec explicitly rules out OS system voices — Kokoro neural quality is the differentiator. | `sherpa_onnx` + Kokoro. |
| **`cached_network_image`** | All cover images are local files extracted from imported EPUBs. There is no network to cache. PROJECT.md already dropped this. | Plain `Image.file()` against a path from Drift. |
| **`sqflite`** directly | Usable but you lose Drift's type safety and reactive streams for a small boilerplate win. | Drift. |
| **`hive`** | Was popular but has maintenance questions in 2026, and its lack of SQL means the library-grid query patterns (sort by title/author/recent/progress) get clumsy. | Drift. |
| **Firebase / Sentry / Crashlytics / any analytics SDK** | Architectural NO — PROJECT.md makes zero-network-after-model-download a hard constraint. Adding any of these silently violates the privacy promise the product is built on. | Local-only on-device crash log the user can manually share. |
| **`dio`** | Overkill for a single download call and adds transitive dependencies you don't need. | `package:http` streaming to disk with progress callback. |
| **BLoC** | More boilerplate than this app needs at solo-developer scale. | Riverpod. |
| **`flutter_bloc_generator` / `freezed`-everywhere** | Not wrong, just heavy. freezed is fine for a dozen sealed classes; don't freezed every model. | Dart 3 records + sealed classes in stdlib cover 80% of use cases. |
## Stack Patterns by Variant
- Fork it locally (tiny codebase, pure Dart, no platform channels) or
- Switch to `package:archive` + `package:xml` + `package:html` and write your own EPUB parser (~200 LOC). EPUB is a zip of XHTML with an OPF manifest; it's not a rabbit hole.
- First fallback: drop to the C++ API via `dart:ffi` against the `sherpa_onnx_c_api` library. More work but no Flutter-layer bugs.
- Second fallback: evaluate `kokoro_tts_flutter` as a drop-in replacement.
- Explicit non-option: OS system TTS. The spec rules this out and the product loses its differentiator if you fall back there.
- Add a secondary mirror on Hugging Face: `onnx-community/Kokoro-82M-ONNX` has similar artifacts. Note this would require a different file layout and checksum, so it's meaningful extra work — only do it if real user reports warrant it.
## Version Compatibility
| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| flutter_riverpod 3.3.x | riverpod_annotation 3.x, riverpod_generator 4.x, riverpod_lint 3.x | Major version alignment is strict. Don't mix v2 and v3. |
| drift 2.32.x | drift_dev 2.32.x, sqlite3_flutter_libs 0.5.x | Keep drift and drift_dev in lockstep. |
| sherpa_onnx 1.12.x | sherpa_onnx_ios (transitive), sherpa_onnx_android (transitive) | These are federated platform implementations pulled in automatically. Don't depend on them directly — let the main package do it. |
| just_audio 0.10.x | audio_service 0.18.x | just_audio's StreamAudioSource API is stable; audio_service handles the background/lock-screen layer on top of whatever AudioPlayer you supply. |
| go_router 17.x | flutter_riverpod 3.x | No special coupling — go_router is UI-layer only. |
| audio_service 0.18.x | just_audio 0.10.x, flutter ≥ 3.22 | audio_service requires a foreground service on Android 14+; check target SDK when Phase 7 ships. |
## Risks and Gotchas (read this before starting Phase 4)
### 1. sherpa_onnx Flutter bindings maturity (MEDIUM risk — highest in stack)
- **Signal:** Kokoro TTS Flutter example shipped in **1.10.42**. Generate API refactor happened in **1.12.31** (~6 weeks ago). Release cadence is 2–8 days between patch versions.
- **Implication:** The Flutter API is *real* and *usable*, but it is younger than the C++ core and a breaking patch-level regression is a realistic scenario. Pin exact versions. Keep a test harness — the TTS sanity test script mentioned in the spec — that can validate a new version before you upgrade.
- **Mitigation:** Build the minimal "synthesize a sentence, play it, hear it" test harness **before** wiring TTS into the full reader, as the spec's prompting strategy already recommends. Do it the day Phase 4 starts; don't wait until integration.
### 2. PCM → just_audio bridging (MEDIUM friction, not a risk)
- **Wrap in a WAV header** (pragmatic): for each synthesized sentence, convert float PCM to int16, prepend a 44-byte WAV header, feed to `StreamAudioSource` as a single in-memory byte buffer. Simple, works, adds ~150 LOC.
- **Custom AudioSource**: write a full `StreamAudioSource` subclass that streams PCM with per-chunk WAV headers. Marginally more complex, similar performance.
### 3. epubx staleness (LOW-MEDIUM risk)
### 4. audio_service iOS quirks (LOW-MEDIUM risk)
- `UIBackgroundModes` in Info.plist including `audio`
- A custom `AVAudioSession` category (playback, not ambient)
- Interaction with `audio_session` package for proper mixing behavior with other apps
- Handling of iOS 17+ background-task budgets
### 5. iOS file picker Info.plist keys (LOW risk, easy to miss)
- `UIFileSharingEnabled = YES`
- `LSSupportsOpeningDocumentsInPlace = YES`
- `CFBundleDocumentTypes` entry for `org.idpf.epub-container` (EPUB UTI)
### 6. Sentence splitter is not trivial
### 7. Drift migrations on app updates (LOW risk, architectural awareness)
## Sources
- [sherpa_onnx on pub.dev](https://pub.dev/packages/sherpa_onnx) — version 1.12.36, published ~3 days ago, active development
- [sherpa_onnx changelog](https://pub.dev/packages/sherpa_onnx/changelog) — Kokoro support added in 1.10.40, Flutter example in 1.10.42, Generate API refactor in 1.12.31
- [flutter_riverpod on pub.dev](https://pub.dev/packages/flutter_riverpod) — version 3.3.1, Feb 2026
- [go_router on pub.dev](https://pub.dev/packages/go_router) — version 17.2.0, April 2026
- [drift on pub.dev](https://pub.dev/packages/drift) — version 2.32.1, March 2026
- [just_audio on pub.dev](https://pub.dev/packages/just_audio) — version 0.10.5, supports StreamAudioSource
- [audio_service on pub.dev](https://pub.dev/packages/audio_service) — version 0.18.18
- [file_picker on pub.dev](https://pub.dev/packages/file_picker) — version 11.0.2, April 2026
- [epub_view on pub.dev](https://pub.dev/packages/epub_view) — version 3.2.0, LAST PUBLISHED JUNE 2023, depends on flutter_html — REJECTED
- [epubx on pub.dev](https://pub.dev/packages/epubx) — version 4.0.0, June 2023, pure parser exposing raw HTML chapters
- [riverpod_generator on pub.dev](https://pub.dev/packages/riverpod_generator) — version 4.0.3
- [sherpa-onnx Kokoro pretrained models](https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html) — official model documentation listing v0_19 (English), v1_0 (multi-lang), v1_1 (multi-lang)
- [k2-fsa/sherpa-onnx GitHub releases](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models) — source of model tarball downloads
- Direct HTTP HEAD verification: `kokoro-int8-en-v0_19.tar.bz2` is 103,248,205 bytes; `kokoro-en-v0_19.tar.bz2` (f32) is 319,625,534 bytes
- [k2-fsa/sherpa-onnx GitHub repo](https://github.com/k2-fsa/sherpa-onnx) — platform support matrix and architecture
- [Flutter release notes](https://docs.flutter.dev/release/release-notes) — current stable Flutter 3.41 / Dart 3.11, Feb 2026
- [State of Flutter 2026](https://devnewsletter.com/p/state-of-flutter-2026/) — ecosystem snapshot
- HIGH: all pub.dev version lookups (primary source)
- HIGH: Kokoro model file sizes (verified via HEAD request to actual release assets)
- HIGH: sherpa_onnx changelog Kokoro timeline (primary source changelog)
- MEDIUM: sherpa_onnx Flutter-layer maturity claims (based on changelog entries, not hands-on testing in this research phase)
- MEDIUM: epubx Dart 3.11 compatibility (not verified — must be tested in Phase 1)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
