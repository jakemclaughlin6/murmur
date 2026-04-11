# Phase 1: Scaffold & Compliance Foundation - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

A signed Flutter app that launches on a physical iPhone and a physical Android phone, navigates between placeholder Library / Reader / Settings routes via go_router, has Riverpod 3 scope at the app root surviving hot reload, has Drift initialized at schema_version=1 (no tables yet), defines and renders all four reader themes (light/sepia/dark/OLED) in Settings, bundles reader fonts, declares every store-compliance key later phases need, wires local-only crash logging, and produces a signed Android AAB from CI on every push to main. Scope anchor: FND-01 through FND-10 — **with two amendments locked below** (FND-06, FND-09).

**Explicitly out of scope for Phase 1** (belongs in later phases):
- Any EPUB import, parsing, or library grid work (Phase 2)
- Reader text rendering, sentence-span pipeline, font-size slider (Phase 3)
- Kokoro TTS engine, model download prompt, audio playback (Phase 4)
- Sentence highlighting, two-way TTS ↔ reader sync (Phase 5)
- Bookmarks, sleep timer, onboarding flow, accessibility pass (Phase 6)
- Store upload, paid pricing, privacy labels (Phase 7)

</domain>

<decisions>
## Implementation Decisions

### App Identity
- **D-01:** Bundle identifier is `dev.jmclaughlin.murmur` for both Android `applicationId` and iOS `CFBundleIdentifier`. Locks store identity forever.
- **D-02:** Display name on the home screen is **Murmur** (title case). Do not use all-lowercase branding on the launcher icon label, even though internal docs use "murmur."
- **D-03:** Publisher / developer name for store listings and signing artifacts is **Jake McLaughlin**. Use this in the Android signing config, iOS Xcode project team field, and all future store metadata.

### CI & Signing
- **D-04:** Android signing uses a **debug keystore committed to the repo** at Phase 1. Reproducible, zero secrets management, good enough for "signed debug AAB" wording of FND-09. Upload-keystore + GH secrets path is deferred to Phase 7.
- **D-05:** **Apple Developer Program enrollment is deferred to Phase 4.** Phase 1 does not acquire a signing certificate, provisioning profile, or TestFlight access. This aligns with the "no Mac, Phase 4 is the decision point" section in PROJECT.md.
- **D-06 (FND-09 amendment):** FND-09 is narrowed for Phase 1 to **"on every push to main, CI produces a signed debug Android AAB that installs successfully on a physical Android device. iOS CI is scaffolded as a `workflow_dispatch`-only job that runs `flutter build ios --no-codesign` on a GitHub-hosted macOS runner and uploads the `.xcarchive` as a workflow artifact — no real signing, no device install, no TestFlight."** The full FND-09 wording ("signed Android AAB and iOS IPA on every push") is restored in Phase 4 once Apple Developer Program is active. Update REQUIREMENTS.md FND-09 to reflect the two-stage delivery.

### Crash Logging (FND-10)
- **D-07:** Crash log format is **JSONL** — one JSON object per line with fields: `ts` (ISO 8601), `level`, `error` (message), `stack` (multi-line string with `\n` preserved inside the JSON string), `device` (model string), `os` (platform + version), `appVersion` (from pubspec). Structured now so the Phase 6 Settings viewer can filter and render selectively instead of regex-parsing text.
- **D-08:** Rotation policy is **single file capped at 1 MB**: writes go to `crashes.log`; on overflow, rename to `crashes.1.log` (overwriting any previous `.1` file), then start a fresh `crashes.log`. Keep exactly one old file. Max on-disk footprint ≤ 2 MB.
- **D-09:** Crash log path is `${appDocumentsDir}/crashes/crashes.log`. Do not put it under cache — cache can be evicted by the OS.
- **D-10:** Global error capture in `lib/main.dart` wraps `runApp()` with all three of: `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `runZonedGuarded(() => runApp(...), onError)`. Standard Dart belt-and-suspenders "catch everything" pattern; prevents silent async failures.
- **D-11:** Phase 1 lands a **placeholder "Crash log" row in Settings** that shows only the file path and its current byte count as plain text (proves the pipeline works end-to-end on a physical device). The real in-app viewer + manual-share button is Phase 6 scope (SET-04) and is **not** built in Phase 1.

### Placeholder UI Scope
- **D-12:** Library, Reader, and Settings placeholder screens are **themed empty states with real copy, not blank `Text('Library')` stubs**. Specifically:
  - **Library placeholder:** Shows the Phase 2 "Import your first book" empty state illustration + CTA button. The CTA button is present and themed but its `onTap` is a no-op with a `debugPrint` (real wiring lands in Phase 2). This scaffolds the empty-state component Phase 2 will reuse.
  - **Reader placeholder:** Shows a single sample paragraph rendered via `RichText` in the currently selected reader font and theme (no sentence splitting yet — just one prose paragraph, a real sentence of Middlemarch or similar public-domain text). Proves fonts and themes are visibly applied and gives a preview of Phase 3's rendering pipeline shape.
  - **Settings placeholder:** Has a **real working theme picker**, a font-family preview row (shows both fonts as non-interactive samples), and the stub "Crash log" row from D-11.
- **D-13:** The Settings theme picker is a **5-option picker: System / Light / Sepia / Dark / OLED**. "System" follows the OS (`MediaQuery.platformBrightnessOf`) and is the default on first launch per FND-05. The other four lock the app to that specific theme regardless of OS setting.
- **D-14:** Theme selection **persists across app restarts via `shared_preferences`** under key `settings.themeMode` (string enum: `system`, `light`, `sepia`, `dark`, `oled`). This is Phase 1's smoke test that state persistence works end-to-end — not just Riverpod in-memory state.

### Drift v0 Schema
- **D-15:** Phase 1 ships Drift at **schema_version = 1 with no user tables**. The generated database class exists, is initialized on first launch at `${appDocumentsDir}/murmur.db`, and registers `schemaVersion: 1` — but defines zero `@DataClassName` tables. This proves the Drift toolchain, build_runner pipeline, and database file path all work without dragging Phase 2's book/chapter schema forward.
- **D-16:** Settings storage uses **`shared_preferences`** for simple key/value (theme mode, onboarding-complete flag). Drift is reserved for domain data (books, chapters, progress, bookmarks) starting in Phase 2. Do not create a Drift `app_settings` table.
- **D-17:** Drift migrations use the **generated `drift_dev` migrations workflow** from day one, with schema JSON dumps checked into `drift_schemas/`. When Phase 2 adds its first real tables, the migration from v1 → v2 will be generated and tested against the committed v1 schema dump, catching breaking changes at build-runner time. This is rigorous up front but eliminates a huge class of migration bugs later.

### Theme Palette & Fonts
- **D-18:** The **light theme palette is pulled from the Clay design system's neutral base only** — the playful swatch palette (Matcha, Slushie, Lemon, Ube, Pomegranate, Dragonfruit, Blueberry) is **intentionally dropped**. The goal is "quiet library" feel, not Clay's warm/playful B2B personality. Light theme foundation:
  - `background`: `#faf9f7` (Clay "warm cream" — paper canvas)
  - `surface`: `#ffffff` (Clay "pure white" — cards)
  - `border.default`: `#dad4c8` (Clay "oat border")
  - `border.subtle`: `#eee9df` (Clay "oat light")
  - `text.primary`: `#000000` (Clay "black")
  - `text.secondary`: `#55534e` (Clay "warm charcoal")
  - `text.tertiary`: `#9f9b93` (Clay "warm silver")
  - `accent`: TBD in planning — **do not adopt Clay's swatch palette**. If an accent is needed (e.g., for the "active chapter" highlight in Phase 3 or the theme-picker selected state in Phase 1), use a single muted ink-dark tone such as `#02492a` (Clay "matcha-800") or `#01418d` (Clay "blueberry-800"). Planner picks one during Phase 1 planning and locks it.
- **D-19:** Sepia, dark, and OLED themes are adapted by the planner to harmonize with the Clay-neutrals light theme. Concrete hex values are TBD in planning but must satisfy:
  - **Sepia:** warm paper tone (~`#F4ECD8` or similar), warm dark text (~`#4A3E2A`), oat-adjacent borders
  - **Dark:** near-black background (`#121212` recommended), warm off-white text, low-saturation warm grays
  - **OLED:** true `#000000` background for pixel-off on AMOLED, warm off-white text (slightly cooler than dark theme's to avoid crushing), no colored borders (single-pixel `#1a1a1a` or none)
- **D-20:** The overall visual feel is **"quiet library"** — cream paper, oat-toned structural lines, warm neutrals, no vivid accents. This is the single most important aesthetic direction for the entire app and overrides any default Material 3 color roles where they conflict.
- **D-21 (FND-06 amendment):** FND-06 originally reads "Reader font assets are bundled and loadable (3–4 curated font families)." This is **narrowed to "Reader font assets are bundled and loadable (2 curated serif families: Literata and Merriweather)."** Rationale: Jake picked two serifs explicitly; adding a sans-serif was offered (Atkinson Hyperlegible for accessibility, Inter for neutral) and declined. Update REQUIREMENTS.md FND-06 to reflect the narrower scope. Note: accessibility-focused users who need a distinctive sans may surface this as a v2 request; track as a deferred idea.
- **D-22:** **Literata** and **Merriweather** are both OFL-licensed, bundled as `.ttf` or `.otf` under `assets/fonts/`, and declared in `pubspec.yaml`. Use Google Fonts downloads pinned to specific versions; do not use the `google_fonts` package at runtime (offline requirement — no network).
- **D-23:** UI chrome (app bars, buttons, Settings rows, dialogs) uses the **system font** — SF Pro on iOS, Roboto on Android — via Flutter's default `fontFamily: null`. Only the reader body text uses the bundled serifs. This keeps the chrome feeling native on each platform and doesn't compete with the reader's typography.

### Android & iOS SDK Floors
- **D-24:** Android `minSdkVersion = 24` (Android 7.0 Nougat). Covers ~98% of active devices.
- **D-25:** Android `targetSdkVersion = 34` (Android 14). Required for Play Store uploads as of August 2024 and necessary for the `FOREGROUND_SERVICE_MEDIA_PLAYBACK` declaration in FND-08 to work as designed. Phase 1 must also set `compileSdkVersion = 34`.
- **D-26:** iOS deployment target is **`17.0`**. This is a deliberate choice despite costing ~20% device coverage (~80% of active devices). Accepted trade-off: a cleaner baseline, simpler lifecycle handling, no backfill code for older iOS behaviors. Document this in REQUIREMENTS.md for future reference — if Phase 7 store-submission feedback shows the coverage loss hurting sales, revisit in a v1.1 compat plan.

### Claude's Discretion
- Concrete hex values for sepia / dark / OLED themes within the constraints of D-19.
- Exact accent color choice between the two Clay "dark swatch" candidates in D-18, or a third neutral alternative if neither feels right in context.
- Placeholder sample-paragraph text for the Reader placeholder (D-12); pick any public-domain English prose, ≤150 words, that flatters the fonts.
- Exact layout of the Library empty-state illustration (simple SVG or Icon-based — no need for a custom illustration in Phase 1).
- Widget-level structure of the theme picker (ListTile + Radio, SegmentedButton, or custom Card selector).
- `crashes.log` line-flush strategy (per-write vs batched) — default to per-write unless profiling shows it's a problem.

### Folded Todos
*None — there are no existing todos in the backlog to fold into this phase.*

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level specs
- `.planning/PROJECT.md` — Vision, core value, requirements list, out-of-scope list, dev environment (mise, no Docker), "no Mac" constraint, key decisions including sentence-span commitment
- `.planning/REQUIREMENTS.md` §Foundation (FND-01 through FND-10) — All ten FND- items for Phase 1. **Note: FND-06 and FND-09 are amended by this CONTEXT.md — see D-06 and D-21.**
- `.planning/ROADMAP.md` §"Phase 1: Scaffold & Compliance Foundation" — Goal, depends-on, success criteria
- `.planning/STATE.md` — Current session state
- `CLAUDE.md` — Project-level agent instructions, full tech stack recommendations, what-not-to-use list, risks section, GSD workflow enforcement note

### Design reference (user-selected during discussion)
- `.planning/research/CLAY-DESIGN.md` — Full Clay design system spec (saved locally during discussion). **Use only the neutral base (§2 "Neutral Scale (Warm)" and §2 "Surface & Border") for the light theme, per D-18. Do NOT adopt the vivid swatch palette (Matcha / Slushie / Lemon / Ube / Pomegranate / Blueberry / Dragonfruit) or Clay's playful hover micro-animations.**

### Research done before Phase 1
- `.planning/research/STACK.md` — Detailed stack comparison, version pinning rationale, risks (sherpa_onnx maturity, epubx staleness, iOS audio_service quirks, iOS Info.plist keys)
- `.planning/research/ARCHITECTURE.md` — Architectural patterns
- `.planning/research/FEATURES.md` — Feature-level research
- `.planning/research/PITFALLS.md` — Sentence splitting, EPUB messiness, other known gotchas
- `.planning/research/SUMMARY.md` — Cross-cutting conclusions

### External (do not read without network access)
- Flutter 3.41 release notes — target Flutter version
- Riverpod 3.3 migration guide — Phase 1 installs Riverpod 3 fresh, no v2 → v3 migration to worry about
- Drift 2.32 migration docs — required reading before writing any `@DriftDatabase` schema or migration code

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
**None — this is a brand-new Flutter project.** Phase 1 is the scaffold; there are no existing widgets, hooks, utilities, routes, providers, or DB schemas to reuse. The project root currently contains only `CLAUDE.md`, `murmur_app_spec.md`, and the `.planning/` directory.

### Established Patterns
- **GSD workflow enforcement** (from CLAUDE.md): all file-changing work must go through a GSD command. Planning agent must respect this in task breakdown.
- **mise for toolchain** (from PROJECT.md): Phase 1 commits a `.mise.toml` pinning Flutter, Dart, and Android `cmdline-tools` versions. No host Flutter install. Document the setup in README.
- **No host pollution** hard constraint — every tool must install via mise, not via apt/snap/brew/asdf/direct.
- **Riverpod 3 + code generation** (from CLAUDE.md stack) — `@riverpod` annotations with `riverpod_generator` + `build_runner`. Do not hand-roll `StateNotifierProvider` or `StateProvider`; use generated typed providers throughout.

### Integration Points
- **`flutter create --org dev.jmclaughlin --project-name murmur .`** is the Phase 1 origin command. This produces `applicationId = dev.jmclaughlin.murmur` (Android) and `CFBundleIdentifier = dev.jmclaughlin.murmur` (iOS) automatically. Run from the project root.
- **`android/app/build.gradle`** — configure `applicationId`, `minSdkVersion=24`, `targetSdkVersion=34`, `compileSdkVersion=34`, signing config pointing at the committed debug keystore.
- **`android/app/src/main/AndroidManifest.xml`** — declare FND-08 permissions: `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS` (API 33+), `READ_MEDIA_*` variants appropriate to target SDK (`READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE` depending on API level), foreground service type declaration.
- **`ios/Runner/Info.plist`** — declare FND-07 keys: `UIBackgroundModes=audio`, `UIFileSharingEnabled=YES`, `LSSupportsOpeningDocumentsInPlace=YES`, `CFBundleDocumentTypes` entry for `org.idpf.epub-container`, `ITSAppUsesNonExemptEncryption=false`, deployment target `17.0`.
- **`ios/Runner.xcodeproj/project.pbxproj`** — bundle ID `dev.jmclaughlin.murmur`, deployment target `17.0`. This will be a pain to do without Xcode; plan to edit directly or use `xcodeproj` Ruby gem + a scripted patch.
- **`pubspec.yaml`** — assets: `assets/fonts/literata/` and `assets/fonts/merriweather/` (specific weights TBD in planning); font family declarations.
- **GitHub Actions workflow `.github/workflows/ci.yml`** — Android build job using `ubuntu-latest`, iOS scaffold job using `macos-14` with `workflow_dispatch` trigger only.

</code_context>

<specifics>
## Specific Ideas

- **"Quiet library" aesthetic direction (D-20)** is the single most important visual brief for the whole project. Cream paper, oat borders, warm neutrals, no vivid accents — carry this forward into every later phase's UI work. Phase 2 library grid, Phase 3 reader chrome, Phase 6 polish pass all need to harmonize with this direction.
- **Clay neutrals only (D-18)** is a deliberate editorial choice. The user saw Clay's full swatch palette described and explicitly rejected pulling the swatches through. Do not surface Matcha/Slushie/etc as "future accent opportunities" in later phases unless the user revisits.
- **iOS 17.0 minimum (D-26)** is a user-knowing-the-tradeoff choice, not an oversight. Don't second-guess it or propose lowering it in later phases without explicit user direction.
- **Apple Developer Program on hold (D-05)** — no signing work, no TestFlight setup, no fastlane match, no `ios/fastlane/Appfile`, no `Match.md` until Phase 4. Phase 1 iOS work is pure Info.plist + Xcode project config + a dormant CI job.

</specifics>

<deferred>
## Deferred Ideas

These came up during discussion but belong in other phases or are out of Phase 1 scope. Do not lose them.

- **Apple Developer Program enrollment + full iOS signing pipeline** — Phase 4 decision point per PROJECT.md. Involves either renting a cloud Mac mini (Scaleway M1), buying a used Mac mini M1/M2, or deferring iOS to v1.1. Decision belongs in the Phase 4 discussion, not Phase 1.
- **Real in-app crash log viewer + manual share button** — Phase 6 (SET-04). Phase 1 only lands a stub row.
- **Full FND-09 wording restored** (signed IPA on every push to main) — Phase 4 once iOS signing exists.
- **Upload keystore + GH secrets management for Android release signing** — Phase 7 (QAL-05). Phase 1 uses a debug keystore only.
- **Drift Books + Chapters tables** — Phase 2 will add them; Phase 1's schema is deliberately empty.
- **Drift `app_settings` table** — not planned; `shared_preferences` owns simple key/value. Flag this decision if a future phase wants to migrate settings into the DB for reactive streaming.
- **Additional reader fonts** (Atkinson Hyperlegible for accessibility, Inter for neutral sans) — explicitly offered, declined. Track as a v2 possibility if store feedback surfaces demand, especially from low-vision users. FND-06 was amended to "2 curated serif families" specifically because of this trade.
- **Clay swatch accent colors** (Matcha-800, Slushie-800, Lemon-700, Ube-800, Pomegranate-400, Blueberry-800) — intentionally not adopted; "quiet library" feel overrides. Do not surface in later phases without explicit user direction.
- **Clay playful hover micro-animations** (rotateZ(-8deg), translateY(-80%), hard offset shadows) — incompatible with "quiet library" feel. Do not adopt.
- **Apple Developer Program Team identifier in Xcode project** — cannot be set in Phase 1 (no enrollment); leave the team field empty or use a personal dev team string; re-set during Phase 4 enrollment work.

### Reviewed Todos (not folded)
*None — there were no todos to review.*

</deferred>

---

*Phase: 01-scaffold-compliance-foundation*
*Context gathered: 2026-04-11*
