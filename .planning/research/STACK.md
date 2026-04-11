# Stack Research

**Domain:** Flutter-based offline ebook reader with on-device neural TTS (Kokoro-82M / Sherpa-ONNX), Android + iOS, phones and tablets
**Researched:** 2026-04-11
**Confidence:** HIGH on framework / state / routing / DB / audio; MEDIUM on sherpa_onnx Flutter bindings (actively-developed but young API); MEDIUM on EPUB parsing (best-in-class option is stale); HIGH on Kokoro model hosting and file sizes (verified against GitHub release assets)

---

## TL;DR

Use Flutter 3.41 / Dart 3.11 with Riverpod 3, go_router 17, Drift 2.32, file_picker 11, just_audio 0.10 + audio_service 0.18, and sherpa_onnx 1.12.x. **Do not use `epub_view`** (stale since June 2023 and depends on `flutter_html`, which is the exact HTML-opaque renderer the project has rejected). Parse EPUB with `epubx` + `package:html` and render with your own `RichText` sentence-span pipeline from Phase 3 forward. Ship the **`kokoro-int8-en-v0_19`** model family: bundle `voices.bin` (~5.5 MB) + `tokens.txt` (~1 KB) + `espeak-ng-data` (~1 MB) with the app, download only `model.int8.onnx` (~80 MB) on first launch. The spec's "~82 MB download + ~3 MB voices.bin" numbers are wrong and need correcting — actual values below.

---

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

---

## Installation

```yaml
# pubspec.yaml
environment:
  sdk: ^3.11.0
  flutter: ^3.41.0

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State
  flutter_riverpod: ^3.3.1
  riverpod_annotation: ^3.0.0

  # Routing
  go_router: ^17.2.0

  # Database
  drift: ^2.32.1
  sqlite3_flutter_libs: ^0.5.0

  # EPUB parsing (NOT epub_view — see What NOT to Use)
  epubx: ^4.0.0
  html: ^0.15.4

  # TTS + Audio
  sherpa_onnx: ^1.12.36
  just_audio: ^0.10.5
  audio_service: ^0.18.18

  # File / storage
  file_picker: ^11.0.2
  path_provider: ^2.1.5
  shared_preferences: ^2.3.0

  # Model download
  http: ^1.2.0
  crypto: ^3.0.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.13
  drift_dev: ^2.32.1
  riverpod_generator: ^4.0.3
  custom_lint: ^0.7.0
  riverpod_lint: ^3.0.0
  flutter_lints: ^5.0.0
  flutter_launcher_icons: ^0.14.0
  flutter_native_splash: ^2.4.0
```

Pin `sherpa_onnx` to an **exact** version (not `^`) given its 2–8 day release cadence; breakage is likely to come from a transient regression, not a breaking API change, and a caret range will pick up churn you didn't sign off on. Bump deliberately.

---

## Kokoro Model: Which Variant, Where From, How Big

The spec's numbers are wrong — corrected below from verified GitHub release assets (checked 2026-04-11).

### Recommended variant: `kokoro-int8-en-v0_19`

**Download URL:** `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-en-v0_19.tar.bz2`

**Compressed tarball size (verified via HEAD request):** **103,248,205 bytes ≈ 98.5 MB**

**After extraction, the directory contains:**

| File | Size (approx) | Ship with app? | Notes |
|------|---------------|----------------|-------|
| `model.int8.onnx` | ~80 MB | **No — download on first launch** | The only large file. This is the int8-quantized Kokoro-82M weights. |
| `voices.bin` | ~5.5 MB | **Yes — bundle** | Style vectors for the 11 English speakers. The spec said ~3 MB — that's wrong; it's ~5.5 MB. |
| `tokens.txt` | ~1 KB | **Yes — bundle** | Phoneme token vocabulary. |
| `espeak-ng-data/` | ~1 MB | **Yes — bundle** | Phonemization rules for English. sherpa-onnx needs this at runtime; the Flutter API takes a directory path. |
| `LICENSE`, `README.md` | trivial | Yes — bundle | Required by the model's license. |

**Bundled asset weight added to your IPA/APK: ~7 MB.** First-launch download: **~80 MB** (just `model.int8.onnx`).

### Why v0_19 (and not v1.0 or v1.1)

- **v0_19** — 11 English-only speakers, perfect match for the "~10 curated voices" commitment in PROJECT.md. Smaller model. No wasted weight on languages you're not shipping.
- **v1.0 / v1.1** (multilingual) — 53–103 speakers, adds Chinese + other languages, base model is 310 MB (int8 variant is also larger). Wrong for an English-only v1.
- **f32 / f16 / int8** — int8 is the right quantization for mobile; the quality drop is negligible at reading pace and the download size halves vs f16.

### Hosting strategy for v1

Option chosen: **bundle the static assets (voices.bin, tokens.txt, espeak-ng-data), download only `model.int8.onnx` on first launch.**

Why:
1. User gets a working app skeleton immediately after install — only one thing to download, one progress bar.
2. If the download fails or is cancelled, the app still launches and shows a clear "Download voice model (80 MB) to enable audio" state in Settings.
3. IPA/APK size impact is ~7 MB extra, which is fine.
4. You avoid shipping a fatter 98 MB tarball through a .bz2 unpack path inside the app, which is extra code and extra failure modes.

Download source: fetch directly from the GitHub release asset URL above. GitHub release assets are served via CDN (release-assets.githubusercontent.com), stable, anonymous, and high-bandwidth. No Hugging Face dependency.

**Checksum:** Record the SHA-256 of `model.int8.onnx` at app build time, pin it in source, verify after download. If it mismatches, delete and reprompt. This is the cheapest way to avoid supporting a corrupted-download bug report.

**Is the size stable?** Yes within a model version. The `kokoro-int8-en-v0_19` artifact is a pinned release asset — it does not change under you. If sherpa-onnx publishes `v0_20` or `v1_x` with different sizes, that's an opt-in upgrade via an app update, not a surprise. Pin the filename in source.

**Flutter wiring:** sherpa_onnx's `OfflineTtsKokoroModelConfig` takes separate paths for `model`, `voices`, `tokens`, and `dataDir` (the espeak-ng-data folder). Copy the bundled assets out of `rootBundle` into a writable directory on first launch (sherpa-onnx needs real filesystem paths, not asset paths), and keep the downloaded `model.int8.onnx` next to them. This works today per the official Flutter example that shipped in sherpa_onnx 1.10.42.

---

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

---

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

---

## Stack Patterns by Variant

**If `epubx` fails to build under Dart 3.11 during Phase 1:**
- Fork it locally (tiny codebase, pure Dart, no platform channels) or
- Switch to `package:archive` + `package:xml` + `package:html` and write your own EPUB parser (~200 LOC). EPUB is a zip of XHTML with an OPF manifest; it's not a rabbit hole.

**If `sherpa_onnx` Flutter bindings hit an integration wall in Phase 4:**
- First fallback: drop to the C++ API via `dart:ffi` against the `sherpa_onnx_c_api` library. More work but no Flutter-layer bugs.
- Second fallback: evaluate `kokoro_tts_flutter` as a drop-in replacement.
- Explicit non-option: OS system TTS. The spec rules this out and the product loses its differentiator if you fall back there.

**If model download is flaky for users in certain regions:**
- Add a secondary mirror on Hugging Face: `onnx-community/Kokoro-82M-ONNX` has similar artifacts. Note this would require a different file layout and checksum, so it's meaningful extra work — only do it if real user reports warrant it.

---

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| flutter_riverpod 3.3.x | riverpod_annotation 3.x, riverpod_generator 4.x, riverpod_lint 3.x | Major version alignment is strict. Don't mix v2 and v3. |
| drift 2.32.x | drift_dev 2.32.x, sqlite3_flutter_libs 0.5.x | Keep drift and drift_dev in lockstep. |
| sherpa_onnx 1.12.x | sherpa_onnx_ios (transitive), sherpa_onnx_android (transitive) | These are federated platform implementations pulled in automatically. Don't depend on them directly — let the main package do it. |
| just_audio 0.10.x | audio_service 0.18.x | just_audio's StreamAudioSource API is stable; audio_service handles the background/lock-screen layer on top of whatever AudioPlayer you supply. |
| go_router 17.x | flutter_riverpod 3.x | No special coupling — go_router is UI-layer only. |
| audio_service 0.18.x | just_audio 0.10.x, flutter ≥ 3.22 | audio_service requires a foreground service on Android 14+; check target SDK when Phase 7 ships. |

---

## Risks and Gotchas (read this before starting Phase 4)

### 1. sherpa_onnx Flutter bindings maturity (MEDIUM risk — highest in stack)

- **Signal:** Kokoro TTS Flutter example shipped in **1.10.42**. Generate API refactor happened in **1.12.31** (~6 weeks ago). Release cadence is 2–8 days between patch versions.
- **Implication:** The Flutter API is *real* and *usable*, but it is younger than the C++ core and a breaking patch-level regression is a realistic scenario. Pin exact versions. Keep a test harness — the TTS sanity test script mentioned in the spec — that can validate a new version before you upgrade.
- **Mitigation:** Build the minimal "synthesize a sentence, play it, hear it" test harness **before** wiring TTS into the full reader, as the spec's prompting strategy already recommends. Do it the day Phase 4 starts; don't wait until integration.

### 2. PCM → just_audio bridging (MEDIUM friction, not a risk)

sherpa_onnx returns raw PCM samples (typically float32 arrays at 24 kHz mono for Kokoro). `just_audio`'s `StreamAudioSource` expects byte streams with container framing, not raw PCM. Two approaches:

- **Wrap in a WAV header** (pragmatic): for each synthesized sentence, convert float PCM to int16, prepend a 44-byte WAV header, feed to `StreamAudioSource` as a single in-memory byte buffer. Simple, works, adds ~150 LOC.
- **Custom AudioSource**: write a full `StreamAudioSource` subclass that streams PCM with per-chunk WAV headers. Marginally more complex, similar performance.

Either way this glue code is not trivially obvious from the spec's one-liner "Stream PCM to `just_audio`." Budget half a day in Phase 4 for this specific integration.

### 3. epubx staleness (LOW-MEDIUM risk)

Last published June 2023. EPUB is a frozen spec so rot is unlikely in *parsing logic*, but Dart SDK compatibility is a real concern across 3 Dart minor versions. **Action:** the first thing Phase 1 does after scaffolding should be `flutter pub get` with `epubx` in the dependency list. If it resolves and builds, great. If it doesn't, immediately fork or reach for the `archive + xml + html` fallback — don't try to patch it in place.

### 4. audio_service iOS quirks (LOW-MEDIUM risk)

audio_service on iOS historically has had more setup ceremony than Android:
- `UIBackgroundModes` in Info.plist including `audio`
- A custom `AVAudioSession` category (playback, not ambient)
- Interaction with `audio_session` package for proper mixing behavior with other apps
- Handling of iOS 17+ background-task budgets

None of these are blockers but they are "the example works, my app doesn't" territory. Budget a day in Phase 4 specifically for iOS audio_service wiring, separate from TTS integration.

### 5. iOS file picker Info.plist keys (LOW risk, easy to miss)

For file_picker to surface user EPUBs from iOS Files:
- `UIFileSharingEnabled = YES`
- `LSSupportsOpeningDocumentsInPlace = YES`
- `CFBundleDocumentTypes` entry for `org.idpf.epub-container` (EPUB UTI)

Missing these means users can't import books on iOS. 10 minutes to fix; 2 hours to debug if you don't know.

### 6. Sentence splitter is not trivial

Not a stack issue but worth flagging in STACK.md since the spec calls it out: `SentenceSplitter` is pure Dart, no dependency. Do not reach for an NLP library — they don't exist in mature form for Dart and would pull in huge assets. Hand-write rules for `. ! ?`, abbreviations (Mr., Dr., Mrs., St., etc.), decimals (3.14), ellipses (...), and quoted dialog. Build it in isolation with a test corpus *before* Phase 4 integration.

### 7. Drift migrations on app updates (LOW risk, architectural awareness)

Drift migrations are schema-versioned. As soon as you ship v1.0 and start iterating, every schema change needs a migration step. Write migrations incrementally from day 1 — don't accumulate schema debt and try to migrate all at once at Phase 7.

---

## Sources

**Pub.dev package pages (verified 2026-04-11):**
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

**Sherpa-ONNX Kokoro model documentation (verified 2026-04-11):**
- [sherpa-onnx Kokoro pretrained models](https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html) — official model documentation listing v0_19 (English), v1_0 (multi-lang), v1_1 (multi-lang)
- [k2-fsa/sherpa-onnx GitHub releases](https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models) — source of model tarball downloads
- Direct HTTP HEAD verification: `kokoro-int8-en-v0_19.tar.bz2` is 103,248,205 bytes; `kokoro-en-v0_19.tar.bz2` (f32) is 319,625,534 bytes
- [k2-fsa/sherpa-onnx GitHub repo](https://github.com/k2-fsa/sherpa-onnx) — platform support matrix and architecture

**Flutter / Dart:**
- [Flutter release notes](https://docs.flutter.dev/release/release-notes) — current stable Flutter 3.41 / Dart 3.11, Feb 2026
- [State of Flutter 2026](https://devnewsletter.com/p/state-of-flutter-2026/) — ecosystem snapshot

**Confidence per source:**
- HIGH: all pub.dev version lookups (primary source)
- HIGH: Kokoro model file sizes (verified via HEAD request to actual release assets)
- HIGH: sherpa_onnx changelog Kokoro timeline (primary source changelog)
- MEDIUM: sherpa_onnx Flutter-layer maturity claims (based on changelog entries, not hands-on testing in this research phase)
- MEDIUM: epubx Dart 3.11 compatibility (not verified — must be tested in Phase 1)

---

*Stack research for: Flutter + offline neural TTS ebook reader (murmur)*
*Researched: 2026-04-11*
