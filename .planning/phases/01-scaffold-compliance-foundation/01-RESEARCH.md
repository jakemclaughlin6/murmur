# Phase 1: Scaffold & Compliance Foundation - Research

**Researched:** 2026-04-11
**Domain:** Flutter 3.41 project scaffold + Android/iOS compliance + CI + Riverpod/Drift/go_router wiring
**Confidence:** HIGH on scaffold mechanics, pubspec, Android gradle, Info.plist keys, CI shape, crash logging pattern, font bundling. MEDIUM on mise+Android-SDK end-to-end path (documented but unverified on Jake's machine). MEDIUM-LOW on `epubx` Dart 3.11 compat (out of Phase 1 scope, flagged for Phase 2).

## Summary

Phase 1 is not a stack-invention phase — `.planning/research/STACK.md` already locks the library choices for the whole app. This research narrows the lens to **what Phase 1 actually touches**: `flutter create` output, the Phase-1-only slice of `pubspec.yaml`, Android `build.gradle(.kts)` + manifest, iOS `Info.plist` + `project.pbxproj` edits (without a Mac), `mise` toolchain, a 3-tab `StatefulShellRoute` with Riverpod 3 at root, a zero-table Drift DB with committed schema dumps, a 5-option theme picker wired through `shared_preferences`, bundled Literata + Merriweather, a JSONL crash log with 1 MB rotation, and a GitHub Actions workflow that produces a signed debug Android AAB on push to main (plus a dormant `workflow_dispatch` iOS build).

The **three highest-risk items** in Phase 1 are, in order: (1) `mise` + Android cmdline-tools setup on Linux (CachyOS), because if toolchain doesn't install cleanly nothing else can happen; (2) the iOS `pbxproj` edit without Xcode, because even though only one line changes it's the failure-without-error kind of mistake; (3) the drift v1-with-zero-tables + `drift_schemas/` dump workflow, because the planner will be tempted to skip the schema dump and that eliminates the Phase 2 safety net.

Everything else in Phase 1 is mechanical. The planner should NOT re-litigate library choices, version pins, or aesthetic direction — those are locked in CONTEXT.md and STACK.md. Research below is prescriptive.

**Primary recommendation:** Scaffold via `flutter create --org dev.jmclaughlin --project-name murmur .`, install the **Phase-1-only** dependency subset (NOT the full STACK.md list — see §User Constraints), wire Riverpod 3 via `ProviderScope` at root with `MaterialApp.router`, use `StatefulShellRoute.indexedStack` for the 3-tab bottom nav, initialize Drift at `schemaVersion: 1` with zero `@DataClassName` tables, commit a deterministic debug keystore under `android/keys/debug.keystore`, edit `ios/Runner/Info.plist` as plain XML, `sed`-patch `IPHONEOS_DEPLOYMENT_TARGET` in the Podfile + `project.pbxproj`, bundle Literata + Merriweather at Regular/Bold weights only (4 files total), wire crash logging in `lib/main.dart` via the triple-catch pattern, and ship a single GitHub Actions workflow with an Android job (push-to-main) and a `workflow_dispatch`-only iOS job.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**App identity (D-01..D-03):**
- Bundle identifier: `dev.jmclaughlin.murmur` (both Android `applicationId` and iOS `CFBundleIdentifier`) — locks store identity forever.
- Display name on home screen: **Murmur** (title case). NOT lowercase.
- Publisher / developer name: **Jake McLaughlin**.

**CI & signing (D-04..D-06):**
- Android Phase 1 uses a **debug keystore committed to the repo**. Zero secrets management. Upload-keystore + GH secrets deferred to Phase 7.
- **Apple Developer Program enrollment deferred to Phase 4.** No signing certificate, no provisioning profile, no TestFlight in Phase 1.
- **FND-09 amended for Phase 1:** on every push to main, CI produces a signed debug Android AAB that installs on a physical Android device. iOS CI is `workflow_dispatch`-only `flutter build ios --no-codesign` on `macos-14`, uploads the `.xcarchive` as workflow artifact. Full FND-09 wording restored in Phase 4.

**Crash logging (D-07..D-11):**
- Format: **JSONL** — one object per line with fields `ts` (ISO 8601), `level`, `error`, `stack`, `device`, `os`, `appVersion`.
- Rotation: single file capped at **1 MB**. On overflow, rename to `crashes.1.log` (overwriting any previous `.1`), start fresh `crashes.log`. Max on-disk footprint ≤ 2 MB.
- Path: `${appDocumentsDir}/crashes/crashes.log`. NOT cache.
- `lib/main.dart` must wire ALL THREE of: `FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded(() => runApp(...), onError)`.
- Phase 1 Settings shows a **placeholder "Crash log" row** showing only file path + byte count. Real viewer + share is Phase 6 (SET-04).

**Placeholder UI scope (D-12..D-14):**
- Library, Reader, Settings placeholders are **themed empty states with real copy**, not `Text('Library')` stubs.
- Library placeholder: Phase 2 "Import your first book" empty state illustration + CTA button, themed, `onTap` is a no-op `debugPrint`.
- Reader placeholder: **single sample paragraph** rendered via `RichText` in the currently selected reader font + theme. No sentence splitting. Prose from public-domain English (Claude's discretion, ≤150 words).
- Settings placeholder: **real working theme picker**, font-family preview row (both fonts as non-interactive samples), stub "Crash log" row.
- Theme picker is a **5-option picker**: System / Light / Sepia / Dark / OLED. System (MediaQuery.platformBrightnessOf) is the default on first launch per FND-05.
- Theme selection **persists across restarts via `shared_preferences`** under key `settings.themeMode` (string enum: `system`, `light`, `sepia`, `dark`, `oled`).

**Drift v0 schema (D-15..D-17):**
- Phase 1 ships Drift at **`schemaVersion = 1` with zero user tables**. Database file at `${appDocumentsDir}/murmur.db`.
- Settings storage: **`shared_preferences`** for key/value. Do NOT create a Drift `app_settings` table.
- Drift migrations use the generated `drift_dev` migrations workflow from day one. **Schema JSON dumps checked into `drift_schemas/`.** When Phase 2 adds tables, v1→v2 migration is generated and tested against committed v1 dump.

**Theme palette & fonts (D-18..D-23):**
- **Light theme palette: Clay neutrals ONLY.** Clay swatch palette (Matcha, Slushie, Lemon, Ube, Pomegranate, Blueberry, Dragonfruit) is **intentionally dropped**.
- Light theme foundation (LOCKED hex values):
  - `background`: `#faf9f7` (Clay "warm cream")
  - `surface`: `#ffffff` (Clay "pure white")
  - `border.default`: `#dad4c8` (Clay "oat border")
  - `border.subtle`: `#eee9df` (Clay "oat light")
  - `text.primary`: `#000000` (Clay "black")
  - `text.secondary`: `#55534e` (Clay "warm charcoal")
  - `text.tertiary`: `#9f9b93` (Clay "warm silver")
  - `accent`: TBD in planning — use **one** muted ink-dark tone such as `#02492a` (matcha-800) or `#01418d` (blueberry-800). Planner picks and locks.
- Sepia, dark, OLED themes: concrete hex TBD in planning, must satisfy:
  - Sepia: warm paper (~`#F4ECD8`), warm dark text (~`#4A3E2A`), oat-adjacent borders
  - Dark: `#121212` background (not pure black), warm off-white text, low-saturation warm grays
  - OLED: true `#000000` background, warm off-white text (slightly cooler than dark), no colored borders (single-pixel `#1a1a1a` or none)
- Overall visual feel: **"quiet library"** — cream paper, oat-toned structural lines, warm neutrals, no vivid accents. Overrides any default Material 3 color role that conflicts.
- **FND-06 amended:** "Reader font assets are bundled and loadable (**2 curated serif families: Literata and Merriweather**)." NOT 3–4. No sans-serif.
- Literata + Merriweather bundled as `.ttf` or `.otf` under `assets/fonts/`, declared in `pubspec.yaml`. **Do NOT use the `google_fonts` package at runtime** (offline requirement).
- **UI chrome uses system font** (SF Pro on iOS, Roboto on Android) via `fontFamily: null`. Only reader body uses bundled serifs.

**SDK floors (D-24..D-26):**
- Android `minSdkVersion = 24` (Android 7.0 Nougat)
- Android `targetSdkVersion = 34` (Android 14)
- Android `compileSdkVersion = 34`
- **iOS deployment target `17.0`** (deliberate — costs ~20% device coverage, accepted)

### Claude's Discretion

- Concrete hex values for sepia/dark/OLED themes within D-19 constraints.
- Exact accent color choice between `#02492a` (matcha-800), `#01418d` (blueberry-800), or a third neutral alternative.
- Placeholder sample-paragraph text for Reader (D-12); any public-domain English prose ≤150 words that flatters the serifs.
- Library empty-state illustration layout (simple SVG or Icon-based; no custom illustration needed).
- Widget structure of theme picker (`ListTile + Radio`, `SegmentedButton`, or custom `Card` selector).
- `crashes.log` line-flush strategy — default to per-write unless profiling shows a problem.

### Deferred Ideas (OUT OF SCOPE)

- Apple Developer Program enrollment + iOS signing pipeline → Phase 4.
- Real in-app crash log viewer + manual share → Phase 6 (SET-04).
- Full FND-09 wording (signed IPA on every push) → Phase 4.
- Upload keystore + GH secrets management for release signing → Phase 7 (QAL-05).
- Drift Books + Chapters tables → Phase 2.
- Drift `app_settings` table → not planned; shared_preferences owns key/value.
- Additional reader fonts (Atkinson Hyperlegible, Inter) → v2 possibility only.
- Clay swatch accent colors, Clay playful hover micro-animations → not adopted; do not surface in later phases without explicit user direction.
- Apple Team identifier in Xcode project → cannot be set in Phase 1 (no enrollment).

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FND-01 | App launches on Android and iOS from a signed build with correct bundle ID + placeholder splash/icon | §Flutter Scaffold, §Android Gradle, §iOS pbxproj/Info.plist, §CI — Note: "launches on physical iPhone" is architecturally impossible in Phase 1 per D-05; see §Physical Device Install Path for the honest wording |
| FND-02 | App navigates between Library / Reader / Settings via go_router | §go_router Shell Routing (StatefulShellRoute.indexedStack) |
| FND-03 | Riverpod provider scope installed at app root and survives hot reload | §Riverpod 3 App Root |
| FND-04 | Drift DB initializes on first launch with schema versioning wired up | §Drift v1 With Zero Tables |
| FND-05 | Light/sepia/dark/OLED themes defined; follow system theme by default | §Theme System, §Runtime Persistence via shared_preferences |
| FND-06 (amended) | 2 curated serif families bundled (Literata + Merriweather) | §Font Bundling |
| FND-07 | iOS Info.plist keys: UIBackgroundModes=audio, UIFileSharingEnabled, LSSupportsOpeningDocumentsInPlace, EPUB CFBundleDocumentTypes, ITSAppUsesNonExemptEncryption=false | §iOS Info.plist (full XML stanzas) |
| FND-08 | Android manifest: FOREGROUND_SERVICE_MEDIA_PLAYBACK + READ_MEDIA_* appropriate to target SDK | §Android Manifest Permissions |
| FND-09 (amended) | CI builds signed debug Android AAB on every push to main; iOS scaffolded as workflow_dispatch-only `flutter build ios --no-codesign` on macos-14 | §GitHub Actions CI |
| FND-10 | Local-only crash logging to on-device file, no Sentry/Firebase/network | §Crash Logging Implementation |

</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

These directives have the same authority as CONTEXT.md locked decisions. The planner must not propose anything that violates them.

- **No host pollution:** Flutter / Dart / Android SDK must NOT be installed globally on the Linux host. All toolchain lives under a project-local `mise` config. Docker is explicitly rejected.
- **GSD workflow enforcement:** All file-changing work must go through a GSD command. Planner must respect this in task breakdown (tasks invoke `/gsd-execute-phase`, not bare `Edit`/`Write`).
- **No Mac available:** iOS work routes through GitHub Actions macOS runners. Plans must NOT silently assume a Mac exists. iOS physical-device install is NOT a Phase 1 success criterion.
- **Sentence-span commitment:** Reader must treat sentences as first-class from Phase 3. Phase 1's Reader placeholder is a single static paragraph — do NOT build or prototype the sentence pipeline in Phase 1.
- **Riverpod 3 + codegen, no hand-rolled providers:** use `@riverpod` annotations via `riverpod_generator` + `build_runner`. No `StateNotifierProvider`, no `StateProvider`, no `ChangeNotifierProvider`.
- **Zero network after model download:** no Sentry, no Firebase, no analytics, no crash reporting over the wire. Local-only everything.
- **DRM-free EPUB only, English only:** not relevant to Phase 1 (no parsing yet) but informs future assumptions.

---

## Standard Stack

### Phase 1 Dependency Subset (CRITICAL: NOT the full STACK.md list)

`.planning/research/STACK.md` lists the full app's dependencies. **Phase 1 installs only the subset that Phase 1 code actually imports.** Pulling in `sherpa_onnx`, `just_audio`, `audio_service`, `epubx`, `file_picker`, `http`, `crypto` in Phase 1 adds native-linking complexity (especially `sherpa_onnx`) and pub resolution surface area for no benefit — Phase 1 code does not call any of them.

| Library | Version | Purpose | Phase 1 usage |
|---------|---------|---------|---------------|
| **flutter_riverpod** | `^3.3.1` | State management | `ProviderScope` at app root; `themeModeProvider` in Settings `[VERIFIED: STACK.md, pub.dev]` |
| **riverpod_annotation** | `^3.0.0` | `@riverpod` codegen annotations | Used by theme + app-startup providers `[VERIFIED: STACK.md]` |
| **go_router** | `^17.2.0` | Routing | `StatefulShellRoute.indexedStack` for 3-tab bottom nav `[VERIFIED: STACK.md]` |
| **drift** | `^2.32.1` | Local SQLite DB | Minimal `@DriftDatabase` at `schemaVersion: 1` `[VERIFIED: STACK.md]` |
| **drift_flutter** | `^0.2.x` | Flutter wiring for Drift (supersedes `sqlite3_flutter_libs`) | `driftDatabase()` helper + file path `[CITED: drift.simonbinder.eu/setup, github.com/simolus3/drift/issues/3702]` |
| **shared_preferences** | `^2.3.0` | Key/value for settings | `settings.themeMode` (string) `[VERIFIED: STACK.md]` |
| **path_provider** | `^2.1.5` | App documents directory | DB file path + crashes dir `[VERIFIED: STACK.md]` |
| **package_info_plus** | `^8.x` | App version string for crash log schema | Populates `appVersion` field in JSONL lines `[ASSUMED: standard Flutter package — planner should verify current major on pub.dev before pinning]` |

> **NOT in Phase 1:** `sherpa_onnx`, `just_audio`, `audio_service`, `file_picker`, `epubx`, `html`, `http`, `crypto`, `flutter_launcher_icons`, `flutter_native_splash`. These belong in Phases 2 / 4 / 7. `flutter_launcher_icons` and `flutter_native_splash` are borderline — see Note below.

**Note on icon/splash tooling:** The Phase 1 goal includes "placeholder splash / icon" (FND-01). Options:
- **Option A (recommended):** Hand-author `ic_launcher.png` + `LaunchImage.png` in the standard asset dirs, no tooling. Simpler, zero dev deps, fine for a placeholder.
- **Option B:** Pull in `flutter_launcher_icons` + `flutter_native_splash` as dev_dependencies. More flexibility but two more dev deps and two more tool runs in the setup path.
- **Recommendation:** Option A for Phase 1; re-evaluate at Phase 6 polish when Jake has a real icon design.

### Dev Dependencies (Phase 1)

| Library | Version | Purpose |
|---------|---------|---------|
| **flutter_test** | (sdk) | Widget + unit tests |
| **build_runner** | `^2.4.13` | Code generation runner for riverpod_generator + drift_dev |
| **drift_dev** | `^2.32.1` | Drift schema code generation — keep in lockstep with `drift` |
| **riverpod_generator** | `^4.0.3` | `@riverpod` codegen |
| **custom_lint** | `^0.7.0` | Plugin host for riverpod_lint |
| **riverpod_lint** | `^3.0.0` | Catches provider mistakes at analysis time |
| **flutter_lints** | `^5.0.0` | Official Flutter lint ruleset |

**Installation:**
```bash
# Scaffold generates pubspec.yaml; then edit dependencies and run:
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

**Version verification:** Before finalizing `pubspec.yaml`, the planner should run `flutter pub outdated` (or `dart pub outdated`) against the declared versions and confirm they resolve cleanly together. `[CITED: STACK.md Version Compatibility table]`

### Stack Drop from STACK.md

| STACK.md listed | Phase 1 action | Reason |
|----------------|----------------|--------|
| `sqlite3_flutter_libs: ^0.5.0` | **REPLACED with `drift_flutter`** | Per Drift setup docs (2026): starting from drift 2.32 with sqlite3 3.x, `sqlite3_flutter_libs` is deprecated (0.6.0+ is a no-op stub). `drift_flutter` is the modern recommendation and ships with NativeDatabase wiring. `[CITED: drift.simonbinder.eu/setup, pub.dev/packages/drift_flutter, github.com/simolus3/drift/issues/3702]` |
| `flutter_localizations` | DEFER to Phase 3 | Not needed for Phase 1 placeholder screens. Only matters when the reader renders real text with `TextPainter` line-breaking. |

---

## Architecture Patterns

### Recommended Project Structure (end-of-Phase-1 target)

```
murmur/                                  # repo root
├── .github/workflows/
│   └── ci.yml                          # Android push-to-main job + iOS workflow_dispatch job
├── .mise.toml                          # Flutter + Dart + Java + Android cmdline-tools pins
├── android/
│   ├── keys/
│   │   └── debug.keystore              # committed debug keystore (D-04)
│   ├── app/
│   │   ├── build.gradle.kts            # applicationId, min/target/compileSdk=24/34/34, signing
│   │   └── src/main/
│   │       ├── AndroidManifest.xml     # FND-08 permissions + foregroundServiceType
│   │       └── res/mipmap-*/           # placeholder ic_launcher
│   └── key.properties                  # points at debug.keystore (not gitignored in Phase 1)
├── ios/
│   ├── Runner/
│   │   ├── Info.plist                  # FND-07 keys + CFBundleDisplayName=Murmur
│   │   └── Assets.xcassets/            # placeholder AppIcon + LaunchImage
│   ├── Runner.xcodeproj/project.pbxproj # IPHONEOS_DEPLOYMENT_TARGET=17.0
│   └── Podfile                          # platform :ios, '17.0'
├── lib/
│   ├── main.dart                       # runZonedGuarded + FlutterError.onError + PlatformDispatcher.onError
│   ├── app/
│   │   ├── app.dart                    # MaterialApp.router + ProviderScope
│   │   └── router.dart                 # go_router StatefulShellRoute.indexedStack
│   ├── core/
│   │   ├── crash/
│   │   │   ├── crash_logger.dart       # JSONL writer + 1MB rotation
│   │   │   └── crash_logger_provider.dart  # @riverpod
│   │   ├── db/
│   │   │   ├── app_database.dart       # @DriftDatabase schemaVersion:1
│   │   │   └── app_database_provider.dart
│   │   └── theme/
│   │       ├── app_theme.dart          # light/sepia/dark/oled ThemeData builders
│   │       ├── clay_colors.dart        # D-18 neutrals + accent
│   │       ├── theme_mode_provider.dart # @riverpod backed by shared_preferences
│   │       └── text_theme.dart         # serif TextTheme for reader body only
│   └── features/
│       ├── library/library_screen.dart    # themed empty state placeholder
│       ├── reader/reader_screen.dart      # single RichText paragraph in selected font/theme
│       └── settings/
│           ├── settings_screen.dart       # theme picker, font preview, crash log row
│           ├── theme_picker.dart
│           └── crash_log_status_tile.dart
├── test/
│   ├── theme/app_theme_test.dart       # ensure all 4 themes build
│   ├── crash/crash_logger_test.dart    # write → rotate → read-back
│   ├── db/app_database_test.dart       # schemaVersion = 1
│   └── widget/navigation_test.dart     # tap each tab, state preserved
├── drift_schemas/
│   └── drift_schema_v1.json            # checked-in dump for v1
├── assets/
│   └── fonts/
│       ├── literata/
│       │   ├── Literata-Regular.ttf
│       │   └── Literata-Bold.ttf
│       ├── merriweather/
│       │   ├── Merriweather-Regular.ttf
│       │   └── Merriweather-Bold.ttf
│       └── OFL.txt                      # combined OFL attribution file
├── pubspec.yaml
├── analysis_options.yaml               # includes package:flutter_lints/flutter.yaml + riverpod_lint
├── CLAUDE.md                           # (existing)
├── README.md                            # mise setup instructions
└── .planning/...
```

### Pattern 1: `flutter create` invocation

```bash
# From the project root (which already contains CLAUDE.md, .planning/, murmur_app_spec.md).
# The `.` target tells flutter to scaffold INTO the current directory — it won't delete
# existing files, it will refuse if conflicting names exist.
flutter create \
  --org dev.jmclaughlin \
  --project-name murmur \
  --platforms=android,ios \
  --description "Offline EPUB reader with neural TTS" \
  .
```

- `--org dev.jmclaughlin` combined with `--project-name murmur` produces Android `applicationId = dev.jmclaughlin.murmur` AND iOS `CFBundleIdentifier = dev.jmclaughlin.murmur` automatically. **No separate identifier patching needed for the happy path.** `[VERIFIED: CONTEXT.md §Integration Points, Flutter CLI docs]`
- `--platforms=android,ios` skips generating desktop and web directories (out of scope per PROJECT.md constraints).
- Run from repo root; existing files (`CLAUDE.md`, `.planning/`, `murmur_app_spec.md`) are preserved.

**Immediately delete/replace after scaffold:**
| Path | Action | Reason |
|------|--------|--------|
| `lib/main.dart` (counter app) | **Replace** | Counter app boilerplate, wire actual app structure |
| `test/widget_test.dart` (counter test) | **Replace** | References the counter widget that's being deleted |
| `README.md` | **Replace** | Flutter scaffold README — swap for mise setup instructions |

### Pattern 2: `main.dart` — triple-catch error handling + ProviderScope

```dart
// Source: Flutter docs (FlutterError.onError + PlatformDispatcher.onError + runZonedGuarded
// is the canonical "catch everything" pattern) + Riverpod 3 docs (ProviderScope at root).
// https://docs.flutter.dev/testing/errors
// https://riverpod.dev/docs/introduction/getting_started
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/crash/crash_logger.dart';

Future<void> main() async {
  // Must be inside the zone so async callbacks are caught.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize the crash logger singleton (creates crashes/ dir if missing).
    final logger = await CrashLogger.initialize();

    // Sync errors from Flutter framework (build, paint, etc).
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details); // keep the debug console red
      logger.logFlutterError(details);
    };

    // Async / platform errors that escape the framework.
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logger.logError(error, stack, level: 'platform');
      return true; // marked as handled; prevents hard crash in release
    };

    runApp(const ProviderScope(child: MurmurApp()));
  }, (Object error, StackTrace stack) {
    // Zone-level catch for anything that slips through both handlers above.
    CrashLogger.instance.logError(error, stack, level: 'zone');
  });
}
```

**Why all three:** Flutter's widget pipeline errors go through `FlutterError.onError`. Async errors outside the widget tree (isolates, timers, futures with no `.catchError`) go through `PlatformDispatcher.instance.onError`. Anything still uncaught falls into the zone. This is the belt-and-suspenders pattern D-10 specifies. `[CITED: docs.flutter.dev/testing/errors]`

**ProviderScope placement:** the `ProviderScope` must be the outermost widget so it survives hot reload. Do NOT put it inside a `MaterialApp.router` `builder:` — that rebuilds on theme changes and disposes providers.

### Pattern 3: Riverpod 3 `@riverpod` theme mode provider + `shared_preferences`

```dart
// lib/core/theme/theme_mode_provider.dart
// Source: riverpod.dev v3 getting-started + SharedPreferences docs
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_mode_provider.g.dart';

/// Locked enum for persisted theme selection (D-14).
enum MurmurThemeMode { system, light, sepia, dark, oled }

extension MurmurThemeModeX on MurmurThemeMode {
  ThemeMode get platformMode => switch (this) {
    MurmurThemeMode.system => ThemeMode.system,
    MurmurThemeMode.light  => ThemeMode.light,
    MurmurThemeMode.sepia  => ThemeMode.light,  // sepia is a "light" variant
    MurmurThemeMode.dark   => ThemeMode.dark,
    MurmurThemeMode.oled   => ThemeMode.dark,
  };
}

/// SharedPreferences is async; we expose it as a Riverpod AsyncNotifier
/// so the UI can await the first load with AsyncValue.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  static const _key = 'settings.themeMode';

  @override
  Future<MurmurThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return MurmurThemeMode.values
        .firstWhere((m) => m.name == raw, orElse: () => MurmurThemeMode.system);
  }

  Future<void> set(MurmurThemeMode mode) async {
    state = AsyncData(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
```

`MaterialApp.router` consumes this:

```dart
// lib/app/app.dart (excerpt)
final modeAsync = ref.watch(themeModeControllerProvider);
return MaterialApp.router(
  title: 'Murmur',
  theme: buildLightTheme(),
  darkTheme: buildDarkTheme(),
  // Sepia + OLED are selected via builder — Flutter's ThemeMode enum only
  // has light/dark/system, so we override in the builder when the user has
  // picked sepia or oled explicitly.
  themeMode: modeAsync.valueOrNull?.platformMode ?? ThemeMode.system,
  builder: (context, child) => _SepiaOrOledOverlay(
    mode: modeAsync.valueOrNull ?? MurmurThemeMode.system,
    child: child!,
  ),
  routerConfig: ref.watch(routerProvider),
);
```

**Important v3 note:** `@Riverpod(keepAlive: true)` keeps the provider alive across rebuilds — critical for the theme controller which must not re-read `SharedPreferences` on every navigation. `[CITED: riverpod.dev/docs/providers/annotation]`

### Pattern 4: `go_router` `StatefulShellRoute.indexedStack` for 3-tab bottom nav

```dart
// lib/app/router.dart
// Source: pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html
//         github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_shell_route.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/library/library_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/settings_screen.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(RouterRef ref) => GoRouter(
  initialLocation: '/library',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MurmurShellScaffold(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/reader', builder: (_, __) => const ReaderPlaceholderScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);

class MurmurShellScaffold extends StatelessWidget {
  const MurmurShellScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell, // preserves state per branch
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Library'),
        NavigationDestination(icon: Icon(Icons.menu_book_outlined),     selectedIcon: Icon(Icons.menu_book),     label: 'Reader'),
        NavigationDestination(icon: Icon(Icons.settings_outlined),      selectedIcon: Icon(Icons.settings),      label: 'Settings'),
      ],
    ),
  );
}
```

**Critical distinction for Phase 1:** The Reader tab is a **static placeholder screen**, not the real `/reader/:bookId` route. The real parameterized reader route comes in Phase 3. Don't over-engineer — no `:bookId` param, no `extra:` book payload, no deep-link logic. The branch is just `/reader` with a hard-coded placeholder. `[ADVISOR guidance]`

**State preservation semantics:** `StatefulShellRoute.indexedStack` creates a separate `Navigator` per branch, so switching tabs preserves scroll position, form state, and widget state automatically. No `AutomaticKeepAliveClientMixin` needed. `[CITED: pub.dev go_router StatefulShellRoute docs]`

### Pattern 5: Drift v1 with zero tables + schema dump workflow

```dart
// lib/core/db/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// Intentionally empty — Phase 2 will add @DataClassName('Book') / Chapter / etc.
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // Nothing to create in v1 — no tables.
    },
    onUpgrade: (m, from, to) async {
      // Will be populated in Phase 2 (v1 -> v2).
    },
  );

  static QueryExecutor _openConnection() =>
      driftDatabase(name: 'murmur'); // ${appDocumentsDir}/murmur.db by default
}
```

**Schema dump workflow (D-17):**

```bash
# Generate the v1 schema JSON dump — checked into drift_schemas/
dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/

# This produces drift_schemas/drift_schema_v1.json — commit it.
# When Phase 2 adds tables and bumps schemaVersion to 2, run again:
# dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/
# Then:
# dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
# ... which generates test helpers that prove v1->v2 migration doesn't break the v1 dump.
```

`[CITED: drift.simonbinder.eu/migrations — schema dumps are the recommended workflow for catching breaking migrations at build_runner time]`

**Why this matters in Phase 1 even with zero tables:** establishing the `drift_schemas/` directory and the dump-on-build convention now means Phase 2's first real migration automatically has a v1 baseline to diff against. Skipping this in Phase 1 means Phase 2 starts from "v2 as v1" and loses the safety net forever. The planner will be tempted to skip the dump step because it feels redundant when there are no tables — don't.

### Pattern 6: JSONL crash logger with 1 MB rotation

```dart
// lib/core/crash/crash_logger.dart
// Source: dart:io RandomAccessFile + path_provider + package_info_plus
//         D-07..D-10 format + rotation spec
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class CrashLogger {
  CrashLogger._(this._file, this._deviceString, this._osString, this._appVersion);

  static const int _maxBytes = 1 * 1024 * 1024; // 1 MB (D-08)
  static CrashLogger? _instance;
  static CrashLogger get instance => _instance!;

  final File _file;
  final String _deviceString;
  final String _osString;
  final String _appVersion;

  static Future<CrashLogger> initialize() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/crashes');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/crashes.log');
    if (!await file.exists()) await file.create();

    final info = await PackageInfo.fromPlatform();
    _instance = CrashLogger._(
      file,
      _describeDevice(),
      _describeOs(),
      '${info.version}+${info.buildNumber}',
    );
    return _instance!;
  }

  String get filePath => _file.path;
  Future<int> currentSize() => _file.length();

  Future<void> logFlutterError(FlutterErrorDetails d) => logError(
        d.exception,
        d.stack ?? StackTrace.empty,
        level: 'flutter',
      );

  Future<void> logError(Object error, StackTrace stack, {String level = 'error'}) async {
    final line = jsonEncode({
      'ts': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'error': error.toString(),
      'stack': stack.toString(),
      'device': _deviceString,
      'os': _osString,
      'appVersion': _appVersion,
    });
    await _rotateIfNeeded();
    // Per-write flush strategy (D defaults — discretion per CONTEXT.md)
    await _file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }

  Future<void> _rotateIfNeeded() async {
    final size = await _file.length();
    if (size < _maxBytes) return;
    final rotated = File('${_file.parent.path}/crashes.1.log');
    if (await rotated.exists()) await rotated.delete();
    await _file.rename(rotated.path);
    await File(_file.path).create();
  }

  static String _describeDevice() {
    // Phase 1 keeps this simple — real device_info_plus wiring is out of scope.
    // Planner may choose to add device_info_plus if it fits the task budget,
    // but it's not required for FND-10 to pass.
    if (Platform.isAndroid) return 'android-device';
    if (Platform.isIOS) return 'ios-device';
    return Platform.operatingSystem;
  }

  static String _describeOs() =>
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
}
```

**Notes:**
- **`appVersion` source:** `package_info_plus` (added to Phase 1 pubspec). Returns `version` + `buildNumber` which map to `pubspec.yaml`'s `version: 1.0.0+1` field. `[ADVISOR recommendation]`
- **Rotation algorithm:** D-08 specifies "single file capped at 1 MB, rename to `crashes.1.log` overwriting any previous, start fresh" — the `_rotateIfNeeded()` method above implements exactly that. Max on-disk = 2 MB (1 MB fresh + 1 MB rotated).
- **Per-write flush vs batched:** D discretion — default to per-write (`flush: true`) because a crash is by definition a "fsync or lose it" moment. Batching is only a win if profiling shows write latency is a UI problem, which it won't for error-path writes.
- **Placeholder Settings row (D-11):** shows only `logger.filePath` + `await logger.currentSize()` as plain text. Rebuild the row on a `Stream.periodic(...)` every 5 seconds or just on screen build — Phase 1 doesn't need live updates.

### Anti-Patterns to Avoid

- **`BuildContext`-coupled state:** Do NOT use `InheritedWidget`-based state. Riverpod providers only. `[CITED: CLAUDE.md convention]`
- **Hand-rolled `StateNotifierProvider`:** Use `@riverpod` + `riverpod_generator`. `[CITED: CLAUDE.md convention]`
- **Putting the theme controller provider outside `ProviderScope`:** it must be inside so rebuilds don't dispose it.
- **Putting `ProviderScope` inside `MaterialApp.router`'s builder:** breaks hot-reload preservation.
- **Shipping `google_fonts` at runtime:** violates offline constraint. Use bundled `.ttf` only. `[CITED: D-22]`
- **A single Drift migration that tries to handle every future version:** Phase 1's migration strategy must be version-by-version (`onUpgrade` branches on `from`/`to`), not an opaque "run all pending SQL" blob.
- **Hard-coding the bundle ID in multiple places:** rely on `flutter create --org` having done the right thing; don't touch `android/app/build.gradle` and `ios/Runner.xcodeproj/project.pbxproj` for the bundle ID unless a verification test fails.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Key/value settings persistence | Custom JSON file in app docs | `shared_preferences` | D-14/D-16 locked; handles platform storage (NSUserDefaults / SharedPreferences) |
| 3-tab bottom nav state preservation | `IndexedStack` manual wiring | `StatefulShellRoute.indexedStack` | go_router 17 gives you parallel navigators + deep linking for free |
| Global error capture | Try/catch at every entry point | `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.instance.onError` | Three-way catch is the canonical Flutter pattern |
| Bundle ID / applicationId wiring | Hand-editing `build.gradle`, `Info.plist`, `project.pbxproj` simultaneously | `flutter create --org dev.jmclaughlin --project-name murmur` | Flutter templates it correctly across all three files in one shot |
| SQLite native library bundling on Android/iOS | `sqlite3_flutter_libs` old-style build | `drift_flutter` (which wires in sqlite3 3.x directly) | Drift 2.32+ made the old path a no-op; `drift_flutter` is the current answer |
| Theme mode persistence | Writing ThemeMode name to a file | `shared_preferences` via a `@riverpod` AsyncNotifier | Stays idiomatic and testable |
| pbxproj hand-editing from scratch | Writing a custom parser for the ASCII plist format | Direct `sed` patch of the known string (`IPHONEOS_DEPLOYMENT_TARGET = 13.0;` → `17.0;`) | Phase 1's only pbxproj change is the deployment target — one line, deterministic template |
| Reading app version for crash log | Parsing `pubspec.yaml` at runtime | `package_info_plus` | Correct platform-native version read |
| iOS default launch image | Custom storyboards | Xcode template's `LaunchImage.imageset` with a placeholder PNG | `flutter create` generates a working placeholder; replace just the PNG |

**Key insight:** Phase 1 is ~90% "edit the files Flutter generated for you" and ~10% "write code." Any temptation to replace or rewrite Flutter's generated Android/iOS templates from scratch should be pushed back — keep the blast radius minimal.

---

## Runtime State Inventory

**Phase 1 is a greenfield scaffold with no existing runtime state.** No data migration. No OS-registered tasks. No secrets that reference renamed things. The only repo-state item is the `CLAUDE.md` + `.planning/` content that must be preserved through `flutter create .`, and that is handled by running `flutter create` into an existing directory (it does not delete unrelated files).

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no databases, no Mem0, no prior app state | None |
| Live service config | None — no external services yet | None |
| OS-registered state | None — no Task Scheduler entries, no launchd, no cron | None |
| Secrets/env vars | None — no SOPS, no .env, no CI secrets yet | None |
| Build artifacts | None — no prior `build/` directory, no installed packages | None |

**Nothing found in any category — verified by inspection of project root (`ls`) which contains only `CLAUDE.md`, `murmur_app_spec.md`, `.planning/`.**

---

## Common Pitfalls

### Pitfall 1: mise Flutter plugin + Android cmdline-tools hand-off

**What goes wrong:** `mise install` succeeds on `flutter` but fails silently on the Android SDK side because `cmdline-tools` alone doesn't include `platform-tools`, `build-tools;34.0.0`, `platforms;android-34`, and a default license-acceptance run. Flutter then prints `Android SDK components are missing` when `flutter doctor` runs, and the planner thinks Phase 1 is blocked on Flutter instead of on the post-install SDK commands.

**Why it happens:** `mise-plugins/mise-flutter` is just the Flutter SDK (Flutter + bundled Dart). `mise-plugins/mise-android-sdk` is a **separate** plugin and installs only `cmdline-tools`. Everything else (`platform-tools`, `build-tools;34`, `platforms;android-34`, NDK if needed) is installed via `sdkmanager` AFTER mise has placed `cmdline-tools` in the PATH.

**How to avoid:** Phase 1's Task 1 must include, in order:
1. Install mise if not present (`curl https://mise.run | sh`)
2. Commit `.mise.toml` with `flutter` + `java` + `android-sdk` pins
3. `mise install`
4. `mise exec -- sdkmanager --licenses` (accept all)
5. `mise exec -- sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"`
6. `mise exec -- flutter doctor` — must show Android toolchain green
7. `mise exec -- flutter precache --android` — downloads Gradle dependencies to the mise cache, not the host

**Warning signs:** `flutter doctor` shows `[!] Android toolchain` or `cmdline-tools component is missing`. `./gradlew` fails with `SDK location not found`. The `ANDROID_HOME` environment variable is unset in the mise shim.

**Document in README:** exact mise setup commands and a "smoke test" command list. This is the single piece of Phase 1 Jake will hit first and the one most likely to fail.

`[CITED: github.com/mise-plugins/mise-flutter, github.com/mise-plugins/mise-android-sdk]`

### Pitfall 2: iOS `IPHONEOS_DEPLOYMENT_TARGET` lives in three places

**What goes wrong:** You update `ios/Runner/Info.plist` thinking you've set the deployment target, but the Xcode build system reads it from `project.pbxproj` + `Podfile`, not Info.plist. `flutter build ios` succeeds with the wrong target because there's no validation step, and then the CI `.xcarchive` won't actually run on iOS 17 APIs.

**Why it happens:** iOS deployment target is stored in:
1. `ios/Runner.xcodeproj/project.pbxproj` — `IPHONEOS_DEPLOYMENT_TARGET = 13.0;` (Flutter default, usually 13.0 or 12.0 depending on Flutter version)
2. `ios/Podfile` — `platform :ios, '13.0'` (Flutter default commented or set)
3. `ios/Runner/Info.plist` — `MinimumOSVersion` (auto-populated from pbxproj, but can drift)

All three must be updated to `17.0` or you get inconsistent builds. The Info.plist value is often derived, but don't count on it.

**How to avoid:** Use `sed` (or `perl -pi -e`) to patch ALL THREE in a single task step. Document the exact commands:

```bash
# Podfile — uncomment and set
sed -i "s|^# platform :ios, '.*'|platform :ios, '17.0'|" ios/Podfile
sed -i "s|^platform :ios, '.*'|platform :ios, '17.0'|" ios/Podfile

# project.pbxproj — there are typically 3 occurrences (Debug/Release/Profile)
sed -i "s|IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;|IPHONEOS_DEPLOYMENT_TARGET = 17.0;|g" ios/Runner.xcodeproj/project.pbxproj
```

Do NOT reach for the `xcodeproj` Ruby gem — adding a Ruby dependency to a Dart/Flutter project for one line of editing is over-engineering. Direct `sed` is reliable because Flutter's generated template is deterministic. `[ADVISOR recommendation]`

**Warning signs:** CI `.xcarchive` artifact builds successfully but any iOS 17-specific API is flagged unavailable at runtime. Or `pod install` in CI logs shows `[!] The platform of the target Runner (iOS 13.0) is not compatible with audio_service which requires iOS 17.0` (future Phase 4 symptom of Phase 1 oversight).

### Pitfall 3: Committing a debug keystore that's still machine-specific

**What goes wrong:** Jake generates `debug.keystore` locally with `keytool` using defaults, commits it, CI picks it up, and builds succeed — but then a teammate (or Jake from a fresh checkout) regenerates the keystore because it wasn't committed in a reproducible way, and the Play Store sees two different signatures.

**Why it happens:** Local `~/.android/debug.keystore` varies by machine. Phase 1 needs a **project-local, deterministic keystore** committed at `android/keys/debug.keystore` with a pinned key alias, password, and DN.

**How to avoid:** Generate the keystore with explicit, documented parameters:

```bash
mkdir -p android/keys
keytool -genkey -v \
  -keystore android/keys/debug.keystore \
  -alias murmurdebug \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass murmurdebug -keypass murmurdebug \
  -dname "CN=Jake McLaughlin, O=Murmur, C=US"
```

Then wire it in `android/app/build.gradle.kts`:

```kotlin
android {
    signingConfigs {
        create("debugCommitted") {
            storeFile = file("../keys/debug.keystore")
            storePassword = "murmurdebug"
            keyAlias = "murmurdebug"
            keyPassword = "murmurdebug"
        }
    }
    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debugCommitted")
        }
        release {
            signingConfig = signingConfigs.getByName("debugCommitted") // Phase 1 only
        }
    }
}
```

**Security note for Phase 7 planner:** this keystore must be REPLACED with an upload keystore + GH Secrets before any Play Store upload (D-04 defers this to Phase 7 / QAL-05). Add a Phase 7 checklist item for keystore rotation.

**Warning signs:** `.gitignore` includes `**/keystore/*` or `*.keystore` — that would silently prevent the committed debug keystore from being tracked. Check `.gitignore` AFTER `flutter create` (the default Flutter `.gitignore` ignores `/build/` and `**/android/.gradle/` but does NOT ignore `*.keystore` — verify).

### Pitfall 4: Riverpod 3 code-gen files missing from git = CI build fails

**What goes wrong:** Developer runs `dart run build_runner build` locally, everything works, but `*.g.dart` files are gitignored (because some templates gitignore them), CI checks out the repo, runs `flutter build`, and fails because `part 'theme_mode_provider.g.dart';` has no corresponding file.

**Why it happens:** Flutter templates sometimes include `*.g.dart` in `.gitignore` because teams run build_runner on every build. Riverpod 3 + `@riverpod` codegen files MUST be committed (or CI must run `build_runner` before `flutter build`).

**How to avoid:** Explicit choice at Phase 1 setup — pick one:
- **Option A:** Commit `*.g.dart` files. Remove them from `.gitignore` if present. Simpler CI, larger repo. Recommended for solo developer.
- **Option B:** Gitignore `*.g.dart`. Make CI run `dart run build_runner build --delete-conflicting-outputs` before `flutter build appbundle`. Smaller repo, extra CI step.

Pick **Option A** for Phase 1 — smaller CI, fewer moving parts. Document in README.

**Warning signs:** `flutter build appbundle` fails in CI with `Target of URI doesn't exist: 'theme_mode_provider.g.dart'` but passes locally.

### Pitfall 5: `POST_NOTIFICATIONS` runtime permission scope creep

**What goes wrong:** Phase 1 declares `POST_NOTIFICATIONS` in the Android manifest per FND-08, and the planner adds a runtime permission request flow because "Android 13+ requires it." But Phase 1 doesn't show any notifications. The permission prompt pops up on first launch, confuses the user, and implements UX that will be rewritten in Phase 4 anyway.

**Why it happens:** `POST_NOTIFICATIONS` is a runtime permission (API 33+) but **declaring it in the manifest is not the same as requesting it at runtime**. The request only needs to happen when the app actually calls `showNotification(...)`.

**How to avoid:** Phase 1 declares the permission in the manifest AND STOPS. No runtime permission request flow. No `permission_handler` dependency. The runtime request belongs in Phase 4 when `audio_service` actually needs to post lock-screen media notifications.

`[CITED: developer.android.com/develop/background-work/services/fgs/declare, ADVISOR guidance]`

### Pitfall 6: "launches on a physical iPhone" in ROADMAP.md vs. D-05/D-06 reality

**What goes wrong:** ROADMAP.md success criterion #1 for Phase 1 says "User sees the murmur app launch from a signed build on a physical iPhone and a physical Android phone." But CONTEXT.md D-05 defers Apple Developer Program enrollment to Phase 4 and D-06 amends FND-09 to make iOS CI `workflow_dispatch`-only with NO signing. **These two statements are in conflict.**

**Why it happens:** The roadmap predates the CONTEXT.md discussion where the no-Mac and no-Apple-Developer-Program decisions were finalized.

**How to avoid:** Phase 1's **actual** iOS deliverable is an unsigned `.xcarchive` artifact from a manually-triggered `workflow_dispatch` CI run. Jake cannot install it on a physical iPhone without Apple Developer Program enrollment. The planner MUST NOT include "install on physical iPhone" as a Phase 1 task — it is physically impossible. Instead:
- **Phase 1 iOS success criterion (as enforceable):** "The `workflow_dispatch` iOS CI job completes successfully on `macos-14`, produces a `.xcarchive`, uploads it as a workflow artifact, and includes the FND-07 Info.plist keys verifiable via `plutil -p`."
- **Update ROADMAP.md:** mark the "physical iPhone" wording as superseded by D-06 in a phase-transition note. Do NOT silently change the roadmap criterion — surface the discrepancy in the plan-check output.

`[ADVISOR flagged this as a roadmap-vs-context discrepancy the planner must not paper over]`

### Pitfall 7: Drift `drift_flutter` package version ambiguity

**What goes wrong:** Planner pins `drift_flutter: ^0.2.x` but the actual current version is different. `pub get` resolves to whatever's current and a minor version change breaks a helper API.

**Why it happens:** `drift_flutter` is newer than `sqlite3_flutter_libs` and its version numbering is not as stable. STACK.md predates the `drift_flutter` recommendation and lists `sqlite3_flutter_libs` instead.

**How to avoid:** Before pinning, the planner runs `flutter pub add drift_flutter --dry-run` (or `dart pub info drift_flutter`) to get the actual current version, documents it in the plan, and uses an exact pin (no `^`) for Phase 1 to avoid surprise. Re-verify at each Phase boundary.

### Pitfall 8: Fonts dropped into `assets/fonts/` without pubspec declaration

**What goes wrong:** Font files are in the right directory but `pubspec.yaml`'s `flutter: fonts:` section doesn't list them; Flutter ships the assets as bundle files but can't resolve `fontFamily: 'Literata'`; the reader falls back to system serif and the theme test passes visually while failing the "bundled font loaded" check.

**Why it happens:** Flutter requires both the `assets/` section AND the `fonts:` section to cover font files. Easy to get one without the other.

**How to avoid:** Verify the pubspec.yaml `fonts:` section at plan time. Write a unit test that loads `TextStyle(fontFamily: 'Literata')` and asserts the resolved font is not the platform default. (See Validation Architecture §Font Bundling Test.)

---

## Code Examples

### Example 1: Full Phase 1 `pubspec.yaml` (dependency + assets sections)

```yaml
# pubspec.yaml
name: murmur
description: Offline EPUB reader with on-device neural TTS.
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ^3.11.0
  flutter: ^3.41.0

dependencies:
  flutter:
    sdk: flutter

  # State
  flutter_riverpod: ^3.3.1
  riverpod_annotation: ^3.0.0

  # Routing
  go_router: ^17.2.0

  # Database
  drift: ^2.32.1
  drift_flutter: ^0.2.0   # VERIFY current version at plan time

  # Storage
  shared_preferences: ^2.3.0
  path_provider: ^2.1.5

  # Crash log metadata
  package_info_plus: ^8.0.0  # VERIFY current major at plan time

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.13
  drift_dev: ^2.32.1
  riverpod_generator: ^4.0.3
  custom_lint: ^0.7.0
  riverpod_lint: ^3.0.0
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/fonts/OFL.txt
  fonts:
    - family: Literata
      fonts:
        - asset: assets/fonts/literata/Literata-Regular.ttf
        - asset: assets/fonts/literata/Literata-Bold.ttf
          weight: 700
    - family: Merriweather
      fonts:
        - asset: assets/fonts/merriweather/Merriweather-Regular.ttf
        - asset: assets/fonts/merriweather/Merriweather-Bold.ttf
          weight: 700
```

### Example 2: `.mise.toml` — toolchain pins

```toml
# .mise.toml — committed to repo root. Phase 1 Task 1 deliverable.
[tools]
flutter = "3.41.0"          # includes bundled Dart 3.11
java = "17"                 # Android Gradle Plugin 8.x requires JDK 17
"android-sdk" = "latest"    # cmdline-tools; actual SDK components installed via sdkmanager

[env]
# These are set automatically by the mise plugins but committing the
# keys makes them visible to Jake and CI at first glance.
ANDROID_HOME = "{{ env.MISE_DATA_DIR }}/installs/android-sdk/latest"
ANDROID_SDK_ROOT = "{{ env.MISE_DATA_DIR }}/installs/android-sdk/latest"

[tasks.doctor]
run = "flutter doctor"
description = "Verify Flutter + Android toolchain"

[tasks.setup-android]
run = """
sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
"""
description = "One-time Android SDK component install + license acceptance"
```

**Source:** mise-plugins/mise-flutter README + mise-plugins/mise-android-sdk README `[CITED: github.com/mise-plugins/mise-flutter, github.com/mise-plugins/mise-android-sdk]`

### Example 3: Android `build.gradle.kts` — signing + SDK levels

```kotlin
// android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.jmclaughlin.murmur"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "dev.jmclaughlin.murmur"
        minSdk = 24
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("debugCommitted") {
            storeFile = file("../keys/debug.keystore")
            storePassword = "murmurdebug"
            keyAlias = "murmurdebug"
            keyPassword = "murmurdebug"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debugCommitted")
        }
        release {
            // Phase 1 uses the debug keystore for release too so CI can build a "signed"
            // AAB with zero secrets plumbing. Phase 7 replaces this with an upload keystore.
            signingConfig = signingConfigs.getByName("debugCommitted")
        }
    }
}

flutter {
    source = "../.."
}
```

### Example 4: `AndroidManifest.xml` — FND-08 permissions

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- FND-08: TTS foreground service permissions (declared now, used in Phase 4) -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

    <!-- Notification channel for media playback (API 33+) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <!-- NOTE: READ_MEDIA_AUDIO is for accessing device MP3s etc. — NOT relevant to murmur
         since we import EPUBs via SAF (Storage Access Framework), not MediaStore.
         FND-08 mentions "READ_MEDIA_*" but murmur's actual import path uses file_picker
         which uses ACTION_OPEN_DOCUMENT and does not need READ_MEDIA_*. Do NOT declare
         READ_MEDIA_AUDIO — it's irrelevant and would trigger a Play Store data-access
         declaration we don't need. Verified against file_picker docs. -->

    <application
        android:label="Murmur"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- Foreground service declaration for Phase 4 — scaffold now -->
        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <meta-data android:name="flutterEmbedding" android:value="2" />
    </application>
</manifest>
```

**Critical note on FND-08 wording:** FND-08 says `READ_MEDIA_*` but murmur imports EPUBs via `file_picker` → SAF (`ACTION_OPEN_DOCUMENT`), which does NOT require `READ_MEDIA_AUDIO`. Phase 1 should declare `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` + `POST_NOTIFICATIONS` only. The planner should add a note to REQUIREMENTS.md clarifying that `READ_MEDIA_*` is not needed for SAF imports. `[CITED: developer.android.com Foreground service types, file_picker package docs]`

**`com.ryanheise.audioservice.AudioService`** is the `audio_service` package's service class. **Declaring it in Phase 1 is safe (no runtime impact) even though the package isn't in pubspec yet** — but it may cause manifest-merger warnings. Alternative: defer the `<service>` stanza to Phase 4. **Recommendation: defer the `<service>` stanza to Phase 4**, keep only the permission declarations in Phase 1. FND-08 wording is "declares permissions," not "declares service." `[ADVISOR: manifest-merge with no backing package is cosmetic noise; defer]`

### Example 5: `ios/Runner/Info.plist` — FND-07 keys (full XML stanzas)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>Murmur</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>murmur</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$(FLUTTER_BUILD_NAME)</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>$(FLUTTER_BUILD_NUMBER)</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIMainStoryboardFile</key>
    <string>Main</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>CADisableMinimumFrameDurationOnPhone</key>
    <true/>
    <key>UIApplicationSupportsIndirectInputEvents</key>
    <true/>

    <!-- FND-07: required Phase 1 compliance keys -->

    <!-- Background audio for Phase 4 TTS playback -->
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>

    <!-- Files.app integration for Phase 2 EPUB import -->
    <key>UIFileSharingEnabled</key>
    <true/>
    <key>LSSupportsOpeningDocumentsInPlace</key>
    <true/>

    <!-- EPUB document type registration -->
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>EPUB</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>org.idpf.epub-container</string>
            </array>
        </dict>
    </array>

    <!-- Export compliance — truthfully "uses no non-exempt crypto" (just HTTPS for model download) -->
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
</dict>
</plist>
```

`[CITED: FND-07, developer.apple.com UTI docs for org.idpf.epub-container, STACK.md §5 iOS file picker Info.plist keys]`

### Example 6: `ios/Podfile` — iOS 17.0 platform target

```ruby
# ios/Podfile
# Phase 1 edit: uncomment and set platform to 17.0.
platform :ios, '17.0'

# Flutter-generated scaffold — leave untouched below this line.
# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end
  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end
```

The `post_install` block with `IPHONEOS_DEPLOYMENT_TARGET = '17.0'` is the **safety net** that ensures every pod (not just Runner) compiles against the iOS 17 SDK. Without it, a single transitive pod default can drop the effective deployment target. `[CITED: docs.flutter.dev/deployment/ios]`

### Example 7: `project.pbxproj` patch (sed one-liner)

```bash
# ios/Runner.xcodeproj/project.pbxproj has 3 occurrences of IPHONEOS_DEPLOYMENT_TARGET
# (Debug, Release, Profile configurations). Update all at once:
sed -i \
  "s|IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;|IPHONEOS_DEPLOYMENT_TARGET = 17.0;|g" \
  ios/Runner.xcodeproj/project.pbxproj

# Verify:
grep IPHONEOS_DEPLOYMENT_TARGET ios/Runner.xcodeproj/project.pbxproj
# Should print:
#   IPHONEOS_DEPLOYMENT_TARGET = 17.0;
#   IPHONEOS_DEPLOYMENT_TARGET = 17.0;
#   IPHONEOS_DEPLOYMENT_TARGET = 17.0;
```

`[ADVISOR: direct sed is reliable because Flutter's pbxproj template is deterministic; avoid the xcodeproj Ruby gem — no need to pull Ruby into a Dart/Flutter project for one line of editing]`

### Example 8: GitHub Actions `ci.yml`

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  android:
    name: Android (signed debug AAB)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.0'
          channel: 'stable'
          cache: true

      - name: Pub get
        run: flutter pub get

      - name: Generate code (riverpod_generator + drift_dev)
        # Only needed if *.g.dart files are gitignored (see Pitfall 4).
        # If committed, this step is a no-op and can be removed.
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test

      - name: Build signed debug AAB
        run: flutter build appbundle --debug
        # --debug uses the committed debug.keystore via signingConfig "debugCommitted"

      - name: Upload AAB artifact
        uses: actions/upload-artifact@v4
        with:
          name: murmur-debug.aab
          path: build/app/outputs/bundle/debug/app-debug.aab
          if-no-files-found: error
          retention-days: 14

  ios-scaffold:
    name: iOS (workflow_dispatch only — unsigned xcarchive)
    # iOS builds ONLY on manual trigger. Push-to-main does not run this job.
    # This is Phase 1's iOS deliverable per D-06: prove the scaffold + Info.plist keys
    # compile on macos-14, archive the .xcarchive, do NOT sign, do NOT upload to TestFlight.
    if: github.event_name == 'workflow_dispatch'
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.0'
          channel: 'stable'
          cache: true

      - name: Pub get
        run: flutter pub get

      - name: Generate code
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Pod install
        run: cd ios && pod install

      - name: Build iOS (unsigned)
        run: flutter build ios --no-codesign --release

      - name: Archive xcarchive
        run: |
          xcodebuild \
            -workspace ios/Runner.xcworkspace \
            -scheme Runner \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            -archivePath build/ios/Runner.xcarchive \
            archive \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO

      - name: Upload xcarchive
        uses: actions/upload-artifact@v4
        with:
          name: murmur-unsigned.xcarchive
          path: build/ios/Runner.xcarchive
          retention-days: 14
```

**Notes on CI:**
- `actions/checkout@v4`, `actions/setup-java@v4`, `subosito/flutter-action@v2`, `actions/upload-artifact@v4` are current as of 2026 `[CITED: github.com/subosito/flutter-action README]`
- `subosito/flutter-action@v2` caches pub + Flutter SDK automatically via `cache: true` — no manual `actions/cache` step needed.
- **Caching Gradle separately** is worth skipping in Phase 1. subosito caches Flutter which is the long pole; Gradle cache is a marginal win that adds complexity. Revisit if Phase 1 CI runs exceed 10 minutes.
- **iOS job `if:` guard** is the right way to make the job `workflow_dispatch`-only while keeping it in the same workflow file. Alternative is a separate `ios.yml` with only `on: workflow_dispatch` — both are acceptable, single-file is simpler.

### Example 9: Clay-neutrals `ThemeData` builder

```dart
// lib/core/theme/clay_colors.dart
import 'package:flutter/material.dart';

/// D-18 locked values — Clay neutrals only. No swatch palette.
class ClayColors {
  static const background = Color(0xFFFAF9F7); // warm cream
  static const surface    = Color(0xFFFFFFFF); // pure white
  static const borderDefault = Color(0xFFDAD4C8); // oat border
  static const borderSubtle  = Color(0xFFEEE9DF); // oat light
  static const textPrimary   = Color(0xFF000000);
  static const textSecondary = Color(0xFF55534E); // warm charcoal
  static const textTertiary  = Color(0xFF9F9B93); // warm silver

  /// D-18: planner picks between matcha800 / blueberry800 / a third neutral.
  /// Recommendation below: matcha-800 — subtle, warmer than blueberry.
  static const accent = Color(0xFF02492A); // Clay matcha-800
}

ThemeData buildLightTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: ClayColors.background,
  colorScheme: ColorScheme.light(
    primary: ClayColors.accent,
    onPrimary: Colors.white,
    surface: ClayColors.surface,
    onSurface: ClayColors.textPrimary,
    secondary: ClayColors.textSecondary,
    onSecondary: Colors.white,
    surfaceContainerHighest: ClayColors.borderSubtle,
    outline: ClayColors.borderDefault,
  ),
  textTheme: _baseTextTheme(ClayColors.textPrimary, ClayColors.textSecondary),
  dividerTheme: const DividerThemeData(color: ClayColors.borderSubtle, thickness: 1),
);

TextTheme _baseTextTheme(Color primary, Color secondary) => TextTheme(
  // Chrome uses system font (D-23): fontFamily NOT set — resolves to platform default.
  headlineMedium: TextStyle(color: primary, fontWeight: FontWeight.w600),
  titleLarge: TextStyle(color: primary),
  bodyLarge: TextStyle(color: primary),
  bodyMedium: TextStyle(color: secondary),
);
```

**Accent recommendation (Claude's discretion per D-18):** `#02492a` (matcha-800). Rationale: the blueberry-800 `#01418d` is cooler and fights the warm-cream background; matcha-800 sits better in the oat-toned ecosystem and still reads as "ink-dark" rather than "green." Planner should lock this in the plan unless Jake requests otherwise.

**Sepia / dark / OLED themes (TBD with proposed values for planner to lock):**

```dart
// Proposals within D-19 constraints — planner locks concrete values.
class SepiaColors {
  static const background = Color(0xFFF4ECD8); // warm paper
  static const surface    = Color(0xFFFAF4E1);
  static const textPrimary   = Color(0xFF4A3E2A); // warm dark brown
  static const textSecondary = Color(0xFF6B5C42);
  static const borderDefault = Color(0xFFD9CDB1);
  static const accent = Color(0xFF8B6F3F); // warm amber-ink
}

class DarkColors {
  static const background = Color(0xFF121212);
  static const surface    = Color(0xFF1C1C1C);
  static const textPrimary   = Color(0xFFF5EFE2); // warm off-white
  static const textSecondary = Color(0xFFB3AA9A);
  static const borderDefault = Color(0xFF2A2A2A);
  static const accent = Color(0xFF4A8F5F); // warm muted matcha echo
}

class OledColors {
  static const background = Color(0xFF000000); // true black
  static const surface    = Color(0xFF0A0A0A);
  static const textPrimary   = Color(0xFFEDE6D4); // slightly cooler than dark per D-19
  static const textSecondary = Color(0xFFA39C8C);
  static const borderDefault = Color(0xFF1A1A1A); // near-invisible hairline
  static const accent = Color(0xFF4A8F5F);
}
```

---

## Font Bundling

### Sourcing Literata + Merriweather

| Font | OFL source | Download approach |
|------|------------|-------------------|
| **Literata** | `https://github.com/googlefonts/literata` — official Google Fonts repo, releases at `/releases` | Download the latest stable release zip, extract `static/Literata-Regular.ttf` and `static/Literata-Bold.ttf` from the release artifact |
| **Merriweather** | `https://github.com/google/fonts/tree/main/ofl/merriweather` — official Google Fonts repo directory | Download `Merriweather-Regular.ttf` and `Merriweather-Bold.ttf` directly from the repo tree |
| **OFL license** | Same repos — `OFL.txt` file at the root of each font's directory | Concatenate or reference both; commit at `assets/fonts/OFL.txt` |

`[CITED: github.com/googlefonts/literata, github.com/google/fonts/tree/main/ofl/merriweather]`

### Phase 1 Weight Policy

**Bundle Regular (400) + Bold (700) ONLY per family.** 4 files total:
- `Literata-Regular.ttf`
- `Literata-Bold.ttf`
- `Merriweather-Regular.ttf`
- `Merriweather-Bold.ttf`

**Why this subset:**
- Phase 1 needs: one sample paragraph in Reader placeholder + a non-interactive font preview row in Settings. Regular is the only weight used in both.
- Bold is included because `ThemeData.textTheme` reserves bold as the natural emphasis weight and the test suite should prove the app can resolve `FontWeight.w700`.
- Italic (400i/700i) adds two more files (~300KB each) for NO Phase 1 render path. Defer to Phase 3 when the EPUB `<em>` tag matters.
- All weights would add ~16 files and ~2 MB to the APK for negligible Phase 1 gain.

**Filename convention:** match the original Google Fonts filenames exactly (`{Family}-{Style}.ttf`) — keeps OFL attribution straightforward and makes future weight additions trivial.

`[ADVISOR recommendation: Regular + Bold = 4 files for Phase 1]`

---

## State of the Art

| Old approach (pre-2026) | Current approach | When changed | Impact on Phase 1 |
|--------|---------|--------------|---------|
| `sqlite3_flutter_libs` for bundled SQLite | `drift_flutter` (which handles sqlite3 3.x via modern build hooks) | Drift 2.32 (early 2026) | Use `drift_flutter`, NOT `sqlite3_flutter_libs`. STACK.md is stale on this. |
| `ShellRoute` with manual `IndexedStack` | `StatefulShellRoute.indexedStack` with per-branch Navigators | go_router 10+ | Use `StatefulShellRoute.indexedStack` for state-preserving bottom nav |
| Riverpod 2 `StateNotifierProvider` | Riverpod 3 `@riverpod class` with codegen | Riverpod 3.0 (late 2025) | Use `@riverpod` + riverpod_generator only; `StateNotifierProvider` is legacy |
| Manual `FlutterErrorDetails → Sentry.captureException` wiring | Local-only `runZonedGuarded` + JSONL writer | — | Project constraint; use the triple-catch + local JSONL pattern |
| `flutter_launcher_icons` required for icons | Optional — hand-authored `ic_launcher.png` is fine for placeholder | — | Option A recommended for Phase 1 |
| `flutter_tts` for TTS | `sherpa_onnx` + Kokoro model | — | Irrelevant to Phase 1, but note: do NOT reach for `flutter_tts` even as a placeholder |

**Deprecated / outdated:**
- **`sqlite3_flutter_libs` 0.5.x** — starting with 0.6.0 the package is a no-op stub; `drift_flutter` is the recommended path `[CITED: github.com/simolus3/drift/issues/3702]`
- **STACK.md line 84 `sqlite3_flutter_libs: ^0.5.0`** — outdated; supersede with `drift_flutter`. Add a note to STACK.md (or leave it for the Phase 2 research pass to correct).
- **`package:drift/native.dart` manual `NativeDatabase()` wiring** — still works, but `drift_flutter`'s `driftDatabase(name: 'murmur')` helper is cleaner and adds the app-documents path default for free.

---

## Environment Availability

Probed on Jake's machine (Linux / CachyOS) — this is the "will Phase 1 actually start" check.

| Dependency | Required by | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mise` | Toolchain pin | **UNKNOWN** — planner must probe | — | Install via `curl https://mise.run \| sh` at Phase 1 Task 1 |
| `mise-flutter` plugin | Flutter install | UNKNOWN | — | `mise plugin install flutter https://github.com/mise-plugins/mise-flutter.git` |
| `mise-android-sdk` plugin | Android cmdline-tools | UNKNOWN | — | `mise plugin install android-sdk https://github.com/mise-plugins/mise-android-sdk.git` |
| Java 17 | Android Gradle Plugin 8.x | Available via mise (`java@17`) | — | — |
| Git | Source control | PRESUMED available (repo exists) | — | — |
| Ruby + CocoaPods | iOS `pod install` in CI | macos-14 runner has it pre-installed | — | — on CI; not needed locally |
| `keytool` | Debug keystore generation | Bundled with JDK 17 (mise-installed) | — | — |
| `sed` | pbxproj + Podfile patches | Linux standard utility | — | `perl -pi -e` as fallback |
| Physical Android device | Smoke test install | UNKNOWN (Jake has one per CONTEXT.md wording) | — | Install via `adb install build/app/outputs/bundle/debug/app-debug.aab` after `bundletool build-apks --mode=universal` |
| Physical iPhone | iOS install | **Unusable in Phase 1** per D-05 | — | Not applicable — iOS deliverable is CI `.xcarchive` only |
| Mac | Interactive iOS dev | **NOT AVAILABLE** per PROJECT.md | — | All iOS work routes through macos-14 CI |

**Missing dependencies with fallback:** mise itself (installable one-liner), mise-flutter plugin, mise-android-sdk plugin — all fallbacks are `mise plugin install` commands.

**Missing dependencies with NO fallback:** Apple Developer Program enrollment — but this is deferred to Phase 4 by D-05, so it's not a Phase 1 blocker.

**Blocking unknowns the planner must resolve in Task 1:**
1. Is mise installed? If not, install.
2. Does `mise install` (after committing `.mise.toml`) succeed on CachyOS? CachyOS is Arch-based — mise should work fine but has not been verified for this project specifically.
3. Does `mise exec -- flutter doctor` show green Android toolchain after running `sdkmanager --licenses` + `sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"`?

If any of those fail, Phase 1 is blocked on tooling, not code. Task 1 should be a standalone "environment ready" verification gate.

---

## Validation Architecture

Phase 1's requirements are all verifiable — no "inspect visually and hope" tests. Every FND-XX has a corresponding automated check. This section maps requirements → test types → commands.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter 3.41 SDK; no separate install) |
| Config file | None — `test/` directory convention, `analysis_options.yaml` for lint |
| Quick run command | `flutter test test/theme/app_theme_test.dart -r expanded` |
| Full suite command | `flutter test` |
| Widget test command | `flutter test test/widget/` |
| Analyzer command | `flutter analyze` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test type | Automated command | Test file exists? |
|--------|----------|-----------|-------------------|-------------------|
| FND-01 (Android) | App launches with correct bundle ID | Build-output assertion | `flutter build appbundle --debug && unzip -p build/app/outputs/bundle/debug/app-debug.aab BundleConfig.pb \| grep dev.jmclaughlin.murmur` | Wave 0 |
| FND-01 (iOS) | CI xcarchive compiles with correct bundle ID + CFBundleDisplayName=Murmur | CI assertion step | `plutil -p ios/Runner/Info.plist \| grep -E 'CFBundleDisplayName.*Murmur'` | Wave 0 |
| FND-02 | go_router navigates between 3 tabs | Widget test | `flutter test test/widget/navigation_test.dart` (tap each NavigationBar destination, verify route) | Wave 0 |
| FND-03 | Riverpod survives hot reload | Widget test | `flutter test test/widget/provider_scope_test.dart` (pumpWidget, read provider, pumpWidget again, provider preserved) | Wave 0 |
| FND-04 | Drift DB initializes at schemaVersion=1 | Unit test | `flutter test test/db/app_database_test.dart` — `expect(db.schemaVersion, 1)` + `expect(await db.customSelect('SELECT name FROM sqlite_master WHERE type=?', [Variable('table')]).get(), isEmpty)` | Wave 0 |
| FND-05 | 4 themes defined, system is default | Unit test | `flutter test test/theme/app_theme_test.dart` — builds each ThemeData, asserts non-null, asserts default MurmurThemeMode.system | Wave 0 |
| FND-05 (persist) | Theme persists across restart | Widget test with fake prefs | `flutter test test/widget/theme_persistence_test.dart` — set pref, recreate app, assert same theme | Wave 0 |
| FND-06 | Literata + Merriweather loaded from bundle | Unit test | `flutter test test/fonts/font_bundle_test.dart` — `await loadFontFromAsset('Literata')`; assert `TextStyle(fontFamily: 'Literata')` resolves | Wave 0 |
| FND-07 | iOS Info.plist keys present | CI shell assertion | `bash scripts/verify_ios_plist.sh` (grep for each required key) | Wave 0 |
| FND-08 | Android manifest permissions declared | CI shell assertion | `bash scripts/verify_android_manifest.sh` (grep for each permission) | Wave 0 |
| FND-09 | Android CI produces signed AAB on push to main | CI job status | GitHub Actions `android` job green; artifact `murmur-debug.aab` uploaded | Wave 0 (in ci.yml) |
| FND-09 | iOS CI produces xcarchive on workflow_dispatch | CI job status | GitHub Actions `ios-scaffold` job green on manual trigger; artifact `murmur-unsigned.xcarchive` uploaded | Wave 0 (in ci.yml) |
| FND-10 | Crash log writes JSONL to file | Unit test | `flutter test test/crash/crash_logger_test.dart` — trigger error, assert file contains valid JSONL with all 7 fields | Wave 0 |
| FND-10 (rotation) | 1 MB rotation works | Unit test | Same file — write > 1 MB of errors, assert `crashes.1.log` exists and `crashes.log` was truncated | Wave 0 |
| FND-10 (triple-catch) | All 3 error paths are captured | Widget test | Simulate FlutterError, PlatformDispatcher error, and zone error; assert all 3 reach the logger | Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter analyze && flutter test test/{touched_area}/` (quick feedback — < 10 s for a single area)
- **Per wave merge:** `flutter test && flutter analyze` (full suite — ~30 s for Phase 1)
- **Phase gate:** full suite green + `flutter build appbundle --debug` succeeds + CI Android job green on main + `workflow_dispatch` iOS job manually run and green

### Wave 0 Gaps

Every test file listed above is a Wave 0 gap — **nothing exists yet**. The planner should treat Wave 0 as "scaffold tests alongside the feature they verify," not "write all tests up front." Test files to create:

- [ ] `test/theme/app_theme_test.dart` — all 4 ThemeData builders, covers FND-05
- [ ] `test/theme/theme_persistence_test.dart` — shared_preferences round-trip
- [ ] `test/db/app_database_test.dart` — schemaVersion + empty table set, covers FND-04
- [ ] `test/crash/crash_logger_test.dart` — JSONL write + rotation + 7 fields + triple-catch, covers FND-10
- [ ] `test/widget/navigation_test.dart` — 3-tab bottom nav + route preservation, covers FND-02
- [ ] `test/widget/provider_scope_test.dart` — Riverpod survives widget rebuild, covers FND-03
- [ ] `test/fonts/font_bundle_test.dart` — Literata + Merriweather resolve, covers FND-06
- [ ] `scripts/verify_ios_plist.sh` — shell assertion for FND-07 keys
- [ ] `scripts/verify_android_manifest.sh` — shell assertion for FND-08 permissions
- [ ] `.github/workflows/ci.yml` — CI definition for FND-09 (itself the validation for FND-09)
- [ ] `test/widget_test.dart` — the `flutter create` default test (delete-and-replace)

**Framework install:** none needed — `flutter_test` ships with the SDK. Wave 0 tasks only need to create the test files, not bootstrap a test harness.

---

## Security Domain

Phase 1 has minimal security surface — no user data, no network, no auth. ASVS categories mostly don't apply. The small surface that does exist:

### Applicable ASVS Categories

| ASVS Category | Applies | Standard control |
|---------------|---------|-----------------|
| V2 Authentication | no | No accounts, no login, no tokens — ever per PROJECT.md constraint |
| V3 Session Management | no | No sessions |
| V4 Access Control | no | No user roles, single-user app |
| V5 Input Validation | minimal | Only the theme picker enum (`MurmurThemeMode.values.firstWhere`) — already safely parsed. No user text input in Phase 1. |
| V6 Cryptography | no | No crypto in Phase 1 (model SHA-256 check is Phase 4) |
| V7 Error Handling & Logging | **yes** | Local JSONL crash log; MUST NOT include PII or user content (Phase 1 placeholder has no user content, so this is structural). Log writes are local file I/O only — no network transmission path exists. |
| V8 Data Protection | minimal | shared_preferences is not encrypted but only stores `themeMode` — not sensitive |
| V9 Communication | no | No network calls in Phase 1 |
| V10 Malicious Code | **yes** | Committed debug keystore MUST NOT be reused as release keystore in Phase 7 — flag in Phase 7 plan |
| V11 Business Logic | no | No business logic in Phase 1 |
| V12 Files & Resources | **yes** | Crash log file path traversal impossible (hardcoded to `${appDocumentsDir}/crashes/`); font assets are read-only bundle reads |
| V13 API | no | No API surface |
| V14 Configuration | **yes** | ITSAppUsesNonExemptEncryption=false is a truthful export compliance declaration; must remain true after Phase 4 (HTTPS model download is exempt) |

### Known Threat Patterns for this Phase

| Pattern | STRIDE | Standard mitigation |
|---------|--------|---------------------|
| Debug keystore leaked to release build | Spoofing (store listing impersonation) | Phase 7 must rotate keystore; committed keystore flagged as debug-only in `android/keys/README.md` |
| Crash log contains user data | Information disclosure | Phase 1 has no user data to leak — structurally safe. Phase 6 viewer must not expose log to external apps without explicit user action (SET-04) |
| Compromised dependency in pub.lock | Tampering (supply chain) | Use `dart pub deps` + pin exact versions for packages with non-trivial version churn; commit `pubspec.lock` |
| Manifest permission over-request | Violation of "only what's needed" principle | READ_MEDIA_AUDIO is NOT declared (not needed — see Pitfall §Android Manifest) |
| Signing key committed in plaintext | Information disclosure | Only the debug keystore is committed; password is documented as `murmurdebug` in README; Phase 7 rotates to CI secrets |
| CI leaks artifacts to PRs from forks | Information disclosure | `actions/upload-artifact@v4` scopes artifacts to the workflow run; default GH permissions don't leak them cross-fork |

**Security posture for Phase 1:** small surface, mostly defended by the "no network, no accounts, no data" project constraints. The only real risk is Phase 7 forgetting to rotate the committed debug keystore. Add a mandatory checklist item to Phase 7's plan.

---

## Physical Device Install Path

**Android (works in Phase 1):** After `flutter build appbundle --debug` produces `build/app/outputs/bundle/debug/app-debug.aab`, the AAB format is NOT directly installable via `adb install`. Jake has two options:

1. **Preferred:** use `flutter run --debug` or `flutter install` — these use the APK pipeline under the hood and install directly on a connected device via ADB. This is the actual "does it launch on my Android phone" loop.
2. **AAB→APK conversion (for validating CI output):** use `bundletool`:

```bash
# Download bundletool once:
curl -L https://github.com/google/bundletool/releases/latest/download/bundletool-all.jar -o bundletool.jar

# Convert AAB to universal APK and install:
java -jar bundletool.jar build-apks \
  --bundle=build/app/outputs/bundle/debug/app-debug.aab \
  --output=build/app/outputs/bundle/debug/app.apks \
  --mode=universal \
  --ks=android/keys/debug.keystore \
  --ks-pass=pass:murmurdebug \
  --ks-key-alias=murmurdebug \
  --key-pass=pass:murmurdebug

java -jar bundletool.jar install-apks \
  --apks=build/app/outputs/bundle/debug/app.apks
```

Document both in README. Phase 1 success check = "app launches on Jake's physical Android phone with the Murmur name and the 3-tab bottom nav working."

**iOS (NOT possible in Phase 1 — see Pitfall §6):** Without Apple Developer Program enrollment (deferred to Phase 4 per D-05), no physical iPhone install path exists. The iOS deliverable is a CI `.xcarchive` artifact that compiles on `macos-14`, proves the Info.plist keys and deployment target are correct, and cannot be installed anywhere. This is by design. The Phase 1 roadmap criterion "launches on a physical iPhone" is superseded by D-06 and must be updated in ROADMAP.md during the Phase 1 → Phase 2 transition.

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | `package_info_plus` current major is 8.x | §Phase 1 Dependency Subset | Low — planner should verify on pub.dev at plan time; wrong version is a one-line fix |
| A2 | `drift_flutter` current version is around 0.2.x | §Phase 1 Dependency Subset, §Pitfall 7 | Low — planner should run `dart pub info drift_flutter` and pin exactly |
| A3 | `flutter_lints` 5.0.0 is current | §Dev Dependencies | Low — lint rule compatibility only |
| A4 | CachyOS (Arch-based) works with mise Flutter plugin without quirks | §Pitfall 1 | MEDIUM — if mise-flutter fails on CachyOS, Phase 1 is blocked on tooling, not code; fallback is manual Flutter install to `~/.local/share/flutter` (violates no-host-pollution but is the last resort) |
| A5 | `com.ryanheise.audioservice.AudioService` manifest stanza can be safely deferred to Phase 4 | §Example 4 AndroidManifest.xml | Low — deferring only costs a tiny Phase 4 merge; not deferring adds harmless manifest noise in Phase 1 |
| A6 | `FOREGROUND_SERVICE_MEDIA_PLAYBACK` declaration without a backing service implementation is manifest-merger-safe in Phase 1 | §Android Manifest Permissions | Low — permissions without declared services are standard; no crash, no warning |
| A7 | `StatefulShellRoute.indexedStack` supports `NavigationBar` (Material 3) without custom wiring in go_router 17.2 | §Pattern 4 | Low — both are Material 3 primitives and are demonstrated in the official go_router example; stale doc risk only |
| A8 | Flutter 3.41's default iOS deployment target is 13.0 (not 17.0) so the `sed` patch is needed | §Example 7 sed command | MEDIUM — if Flutter 3.41 already defaults to iOS 17, the sed patch is a harmless no-op (matches nothing, changes nothing). Verify by inspecting the generated `project.pbxproj` immediately after `flutter create` and adjust the patch script if necessary |
| A9 | `subosito/flutter-action@v2` supports `cache: true` + Flutter 3.41 pinning | §Example 8 CI | Low — subosito is the de facto standard; the README documents both features |
| A10 | `sdkmanager --licenses` can be automated via `yes \| sdkmanager --licenses` in CI contexts | §Pitfall 1 mise setup | Low — standard Android SDK install practice |
| A11 | `drift_dev schema dump` writes to the specified output directory without needing an existing schema | §Pattern 5 Drift | Low — verified by Drift docs; the empty v1 schema case is the trivial case |

**Non-empty assumptions log means Phase 1 has verifiable items the planner should confirm before task commits. Highest priority: A4 (mise on CachyOS), A8 (Flutter 3.41 default iOS target). The rest are low-risk pub.dev version bumps.**

---

## Open Questions

1. **Does `mise-flutter` install Flutter 3.41 cleanly on CachyOS?**
   - What we know: mise-flutter plugin exists and is maintained; CachyOS is Arch-based, which mise supports broadly.
   - What's unclear: Jake's specific CachyOS setup; no empirical verification.
   - Recommendation: Phase 1 Task 1 is a standalone "tooling gate" — `.mise.toml` + `mise install` + `flutter doctor green`. If this fails, stop and triage before any code is written.

2. **Is `epubx` Dart 3.11 compatible?**
   - What we know: `epubx` last published June 2023, targets Dart 2.12+. EPUB spec is frozen, so the parsing logic is stable.
   - What's unclear: whether Dart SDK breakage across minor versions has landed since 2023.
   - Recommendation: **OUT OF PHASE 1 SCOPE.** `epubx` is not in Phase 1's dependency set. STACK.md already flags this as a Phase 2 go/no-go decision. Do NOT block Phase 1 on this check.

3. **Should the Clay accent color be matcha-800, blueberry-800, or a third neutral?**
   - What we know: D-18 lists both candidates; Jake is ambivalent; Claude's discretion applies.
   - What's unclear: only personal preference.
   - Recommendation: plan uses matcha-800 `#02492a` (warmer, harmonizes with cream background) unless Jake overrides during plan review.

4. **Does `flutter create` in Flutter 3.41 default to iOS 13, 14, or 17?**
   - What we know: Historical default has been 12.0 or 13.0; Flutter docs say "iOS 13+".
   - What's unclear: whether Flutter 3.41 bumped the default.
   - Recommendation: Phase 1 Task 2 inspects `ios/Runner.xcodeproj/project.pbxproj` immediately after `flutter create` to record the actual default, then applies the sed patch. If the default is already 17.0, the patch is a no-op.

5. **Does the planner commit `*.g.dart` files or run `build_runner` in CI?**
   - What we know: Both are valid. Solo developer + low CI time budget argues for committing.
   - What's unclear: Jake's preference.
   - Recommendation: commit `*.g.dart`. Simpler CI, simpler contributor flow, minor repo size cost.

---

## Sources

### Primary (HIGH confidence)

- `.planning/phases/01-scaffold-compliance-foundation/01-CONTEXT.md` — user-locked decisions D-01 through D-26
- `.planning/REQUIREMENTS.md` — FND-01 through FND-10 (amended by D-06 and D-21)
- `.planning/research/STACK.md` — full stack research (versions, compatibility, rejected packages)
- `.planning/PROJECT.md` — project constraints (no host pollution, no Mac, sentence-span commitment)
- `.planning/ROADMAP.md` — Phase 1 goal + success criteria
- `CLAUDE.md` — tech stack, what-not-to-use list, project conventions
- [pub.dev drift package](https://pub.dev/packages/drift) — 2.32.1, setup docs
- [drift.simonbinder.eu/setup](https://drift.simonbinder.eu/setup/) — drift_flutter vs sqlite3_flutter_libs guidance
- [github.com/simolus3/drift/issues/3702](https://github.com/simolus3/drift/issues/3702) — confirms drift_flutter is the current recommendation and sqlite3_flutter_libs 0.6.0+ is a no-op stub
- [pub.dev go_router StatefulShellRoute class docs](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html) — official API reference
- [github.com/flutter/packages go_router stateful_shell_route example](https://github.com/flutter/packages/blob/main/packages/go_router/example/lib/stateful_shell_route.dart) — canonical indexedStack example
- [developer.android.com foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types) — Android 14 FOREGROUND_SERVICE_MEDIA_PLAYBACK requirements
- [developer.android.com declare foreground services](https://developer.android.com/develop/background-work/services/fgs/declare) — manifest declarations
- [github.com/subosito/flutter-action](https://github.com/subosito/flutter-action) — GitHub Actions Flutter setup
- [github.com/mise-plugins/mise-flutter](https://github.com/mise-plugins/mise-flutter) — Flutter plugin for mise
- [github.com/mise-plugins/mise-android-sdk](https://github.com/mise-plugins/mise-android-sdk) — Android SDK plugin for mise
- [github.com/googlefonts/literata](https://github.com/googlefonts/literata) — Literata OFL source
- [github.com/google/fonts/tree/main/ofl/merriweather](https://github.com/google/fonts/tree/main/ofl/merriweather) — Merriweather OFL source
- [docs.flutter.dev/deployment/ios](https://docs.flutter.dev/deployment/ios) — iOS deployment target via Podfile post_install
- [github.com/CocoaPods/Xcodeproj](https://github.com/CocoaPods/Xcodeproj) — (referenced but NOT recommended for Phase 1)

### Secondary (MEDIUM confidence)

- [dev.to GoRouter 2026 advanced tutorial](https://dev.to/techwithsam/gorouter-advanced-tutorial-2026-bottom-nav-nested-routes-auth-redirects-typed-navigation-31d) — 2026 bottom nav example (web search, verified against official docs)
- [codewithandrea.com Flutter Bottom Navigation with GoRouter](https://codewithandrea.com/articles/flutter-bottom-navigation-bar-nested-routes-gorouter/) — standard implementation pattern
- [Medium: Guide to Foreground Services on Android 14](https://medium.com/@domen.lanisnik/guide-to-foreground-services-on-android-9d0127dc8f9a) — Android 14 foreground service changes (cross-verified with developer.android.com)

### Tertiary (LOW confidence — needs validation at plan time)

- Exact current version of `drift_flutter` (pinned assumption A2)
- Exact current version of `package_info_plus` (pinned assumption A1)
- Exact Flutter 3.41 default `IPHONEOS_DEPLOYMENT_TARGET` (assumption A8)
- CachyOS + mise-flutter empirical compatibility (assumption A4)

---

## Metadata

**Confidence breakdown:**
- Standard Stack (Phase 1 subset): **HIGH** — derived from locked CONTEXT.md decisions + verified STACK.md with one documented upgrade (drift_flutter over sqlite3_flutter_libs)
- Architecture Patterns (ProviderScope + StatefulShellRoute + Drift v1 + crash logger): **HIGH** — all canonical patterns from official docs
- Android Gradle + Manifest: **HIGH** — verified against Android 14 official docs
- iOS Info.plist + pbxproj edits: **MEDIUM-HIGH** — keys are verified, the sed-patch approach for deployment target is advisor-recommended (not empirically tested on Flutter 3.41's exact template)
- CI (GitHub Actions shape): **HIGH** — subosito/flutter-action + actions/upload-artifact are current standards
- mise toolchain: **MEDIUM** — plugin existence verified, end-to-end success on CachyOS unverified (A4)
- Crash logging implementation: **HIGH** — triple-catch pattern is the canonical Flutter docs answer
- Pitfalls: **HIGH** — pitfalls 1–4 and 6–8 are sourced from CLAUDE.md/STACK.md + advisor review; pitfall 5 is canonical Android docs
- Validation Architecture: **HIGH** — every Phase 1 requirement maps to a concrete automated check

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (stack is stable but `drift_flutter` and `package_info_plus` versions should be re-verified at plan time; mise plugins and go_router move fast enough that anything older than 30 days should be re-checked)

## RESEARCH COMPLETE

**Phase:** 1 — Scaffold & Compliance Foundation
**Confidence:** HIGH

### Key Findings

- **Phase 1 uses a NARROW dependency subset, not the full STACK.md list.** Pulling `sherpa_onnx`, `just_audio`, `audio_service`, `epubx`, `file_picker`, `http`, `crypto` into Phase 1 adds native-linking and build complexity for zero Phase 1 code use. Phase 1 pubspec has only 8 dependencies + 7 dev dependencies.
- **`drift_flutter` supersedes `sqlite3_flutter_libs`** per 2026 Drift docs — STACK.md is stale on this one line. Use `drift_flutter` with `driftDatabase(name: 'murmur')` helper.
- **Three Phase 1 risks in order of severity:** (1) mise + Android cmdline-tools end-to-end on CachyOS is the biggest "does anything work" gate; (2) `IPHONEOS_DEPLOYMENT_TARGET` lives in three files (Podfile + pbxproj + derived Info.plist) and must be updated in all via `sed`; (3) committing the Drift v1 schema dump in Phase 1 is easy to skip but locks in the Phase 2 migration safety net.
- **The roadmap's "launches on physical iPhone" Phase 1 criterion is impossible** per D-05 (no Apple Developer Program) + D-06 (iOS CI is unsigned-only). Phase 1's iOS deliverable is a `.xcarchive` CI artifact. The planner must not paper over this discrepancy; it surfaces in the plan-check output.
- **Font bundling policy for Phase 1:** Regular (400) + Bold (700) only per family = 4 .ttf files total. Italic defers to Phase 3. Sourced from `github.com/googlefonts/literata` and `github.com/google/fonts/tree/main/ofl/merriweather`.
- **Crash logging shape:** `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.instance.onError` all three wired in `lib/main.dart` around `runApp`. JSONL writer with per-write flush + 1 MB rotation via atomic rename. `package_info_plus` provides `appVersion`.
- **CI shape:** single `.github/workflows/ci.yml` with two jobs — Android on `ubuntu-latest` + `push` trigger (builds signed debug AAB), iOS on `macos-14` with `if: github.event_name == 'workflow_dispatch'` guard (builds unsigned `.xcarchive`, no TestFlight).
- **Validation architecture is non-hand-wavy:** every FND-01..FND-10 maps to a concrete command (flutter_test unit/widget test, CI job status, or shell assertion on manifest/plist). 11 test files + 2 shell scripts are Wave 0 gaps.
- **READ_MEDIA_AUDIO should NOT be declared** — murmur imports EPUBs via SAF (`file_picker` → `ACTION_OPEN_DOCUMENT`), not MediaStore. FND-08's "READ_MEDIA_*" wording is overly broad; the Phase 1 plan should note this and correct REQUIREMENTS.md.

### File Created

`/home/jmclaughlin/projects/murmur/.planning/phases/01-scaffold-compliance-foundation/01-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard Stack (Phase 1 subset) | HIGH | Locked decisions + verified STACK.md |
| Architecture Patterns | HIGH | Canonical docs + riverpod_generator + go_router StatefulShellRoute |
| Android Gradle + Manifest | HIGH | Android 14 official docs verified |
| iOS Info.plist + pbxproj | MEDIUM-HIGH | Keys verified; sed patch advisor-recommended but not empirically tested on Flutter 3.41 template |
| mise toolchain | MEDIUM | Plugins exist; end-to-end CachyOS path unverified |
| Crash logging | HIGH | Canonical triple-catch pattern |
| Validation architecture | HIGH | Every req maps to a concrete command |

### Open Questions (need planner confirmation)

1. mise + mise-flutter + mise-android-sdk end-to-end works on CachyOS (Task 1 is a tooling gate)
2. Flutter 3.41's actual default `IPHONEOS_DEPLOYMENT_TARGET` (verify immediately after `flutter create`)
3. Accent color: matcha-800 vs blueberry-800 (recommendation: matcha-800)
4. Commit `*.g.dart` vs run build_runner in CI (recommendation: commit)
5. `drift_flutter` and `package_info_plus` exact current versions at plan time

### Ready for Planning

Research complete. Planner can now create PLAN.md files for Phase 1 tasks. Recommended task breakdown hint (NOT the plan — planner owns task structure): Task 1 = mise tooling gate, Task 2 = flutter create + strip boilerplate, Task 3 = pubspec + build_runner, Task 4 = theme system + Clay colors, Task 5 = go_router + ProviderScope + placeholder screens, Task 6 = Drift v1 + schema dump, Task 7 = shared_preferences theme persistence, Task 8 = crash logger + triple-catch, Task 9 = Android manifest + debug keystore + build.gradle.kts, Task 10 = iOS Info.plist + Podfile + pbxproj sed, Task 11 = fonts bundling, Task 12 = tests (Wave 0 gaps), Task 13 = CI workflow, Task 14 = README with mise setup, Task 15 = physical device smoke test.
