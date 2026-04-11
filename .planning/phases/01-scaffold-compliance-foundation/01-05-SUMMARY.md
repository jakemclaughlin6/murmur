---
phase: 01-scaffold-compliance-foundation
plan: "05"
subsystem: ui
tags: [theme, fonts, riverpod, shared_preferences, literata, merriweather]

requires:
  - phase: 01-scaffold-compliance-foundation
    provides: pubspec.yaml with flutter_riverpod, shared_preferences, riverpod_generator; build_runner pipeline green; font manifest declared

provides:
  - 4 ThemeData builders (Light/Sepia/Dark/OLED) with locked Clay-neutrals hex palette
  - MurmurThemeMode enum (5 values: system/light/sepia/dark/oled)
  - ThemeModeController @riverpod AsyncNotifier with shared_preferences persistence
  - Real Literata + Merriweather font files (Regular + Bold) in assets/fonts/
  - 17 passing tests covering themes, persistence round-trip, and font bundle loading

affects: [01-08-app-shell, reader-typography, settings-screen]

tech-stack:
  added: [shared_preferences (runtime), riverpod_generator (codegen)]
  patterns: [@riverpod AsyncNotifier for persistent settings, keepAlive: true for app-lifetime providers]

key-files:
  created:
    - lib/core/theme/clay_colors.dart
    - lib/core/theme/murmur_theme_mode.dart
    - lib/core/theme/app_theme.dart
    - lib/core/theme/theme_mode_provider.dart
    - lib/core/theme/theme_mode_provider.g.dart
    - assets/fonts/literata/Literata-Regular.ttf
    - assets/fonts/literata/Literata-Bold.ttf
    - assets/fonts/merriweather/Merriweather-Regular.ttf
    - assets/fonts/merriweather/Merriweather-Bold.ttf
    - test/theme/app_theme_test.dart
    - test/theme/theme_persistence_test.dart
    - test/fonts/font_bundle_test.dart
  modified:
    - assets/fonts/OFL.txt (stub → real license text)

key-decisions:
  - "Clay cream #FAF9F7, matcha-800 accent #02492A, sepia #F4ECD8, dark #121212, OLED #000000 (D-18/D-19)"
  - "System chrome uses platform system font (D-23) — only body text uses Literata/Merriweather"
  - "ThemeModeController is keepAlive: true — shared_preferences is app-lifetime state"
  - "Persistence key: settings.themeMode; invalid stored values fall back to MurmurThemeMode.system"
  - "Fonts: Literata for light/sepia, Merriweather for dark/OLED (both declared in pubspec, Plan 08 picks per theme)"

patterns-established:
  - "@riverpod AsyncNotifier + keepAlive: true for app-lifetime persistent settings"
  - "ClayColors class holds all locked palette constants — no hex literals in theme builders"

requirements-completed: [FND-06]

duration: 35min
completed: 2026-04-11
---

# Phase 01-05: Theme System + Fonts Summary

**4-theme Clay palette system with Riverpod persistence and real Literata/Merriweather font bundle — 17/17 tests passing.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-04-11
- **Tasks:** 3/3
- **Files modified:** 13

## Accomplishments

- `clay_colors.dart` — all D-18/D-19 palette constants in one place; no hex literals leak into theme builders
- `murmur_theme_mode.dart` — 5-value enum with `platformMode` (sepia→light, oled→dark for `MaterialApp.themeMode`) and `displayLabel` extension
- `app_theme.dart` — 4 `ThemeData` builders + `themeFor()` helper; system font for chrome (D-23), reader font selection deferred to Plan 08
- `theme_mode_provider.dart` + `.g.dart` — `@Riverpod(keepAlive: true)` `AsyncNotifier`; reads on build, writes on `set()`, corrupt stored values fall back to `system`
- Real TTF files: Literata (Regular 320KB, Bold 320KB), Merriweather (Regular 80KB, Bold 80KB) — replaces stubs from Plan 03

## Tests

| Suite | Tests | Result |
|-------|-------|--------|
| app_theme_test.dart | 8 | PASS |
| theme_persistence_test.dart | 5 | PASS |
| font_bundle_test.dart | 4 | PASS |
| **Total** | **17** | **PASS** |

## Issues Encountered

None. Content filtering interrupted the agent's response after all work was complete; orchestrator committed task 3 and created SUMMARY manually.

## Self-Check: PASSED
