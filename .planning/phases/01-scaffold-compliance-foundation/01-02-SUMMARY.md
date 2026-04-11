---
phase: 01-scaffold-compliance-foundation
plan: 02
subsystem: dependency-toolchain
tags: [pubspec, dependencies, riverpod, drift, go_router, lint, build_runner, fonts]
dependency_graph:
  requires:
    - 01-01 (Flutter scaffold + bundle IDs)
  provides:
    - Full Phase 1 pub dependency set installed and locked
    - riverpod_generator + build_runner wired (no generated files yet — ready for Plans 05/06/08)
    - riverpod_lint active via analysis_server_plugin
    - flutter_lints baseline active
    - fonts manifest declared (Literata + Merriweather) — files land in Plan 05
    - assets/fonts/ directory structure created with OFL.txt placeholder
  affects:
    - Plan 03 (Android config): can import flutter_riverpod, go_router
    - Plan 04 (iOS config): can import flutter_riverpod, go_router
    - Plan 05 (Fonts): fonts manifest ready — drop .ttf files and they resolve
    - Plan 06 (Drift): drift runtime ready; drift_dev deferred to Plan 06 (see deviations)
    - Plan 07 (Crash log): package_info_plus, path_provider, shared_preferences ready
    - Plan 08 (Routing): go_router, flutter_riverpod ready; ProviderScope already in stub
    - Plans 05/06/08 (codegen): riverpod_generator + build_runner ready for @riverpod annotations
tech_stack:
  added:
    - flutter_riverpod 3.3.1 (state management)
    - riverpod_annotation 4.0.2 (codegen annotations)
    - riverpod_generator 4.0.3 (code generation)
    - riverpod_lint 3.1.3 (lint rules via analysis_server_plugin)
    - go_router 17.2.0 (routing)
    - drift 2.32.1 (database runtime)
    - drift_flutter 0.3.0 (SQLite bundling)
    - shared_preferences 2.5.5 (small settings)
    - path_provider 2.1.5 (platform storage paths)
    - package_info_plus 10.0.0 (crash log metadata)
    - build_runner 2.4.13 (codegen runner)
    - flutter_lints 5.0.0 (lint baseline)
  patterns:
    - riverpod_lint 3.x uses analysis_server_plugin API (not custom_lint) — plugins: block in analysis_options.yaml
    - drift_dev deferred to Plan 06 — incompatible analyzer version constraint with riverpod_generator in same pubspec
key_files:
  created:
    - assets/fonts/OFL.txt (placeholder — Plan 05 replaces with real license text)
    - assets/fonts/literata/ (directory — Plan 05 drops .ttf files here)
    - assets/fonts/merriweather/ (directory — Plan 05 drops .ttf files here)
  modified:
    - pubspec.yaml (replaced flutter create defaults with Phase 1 dependency subset + fonts manifest)
    - pubspec.lock (generated — 124 resolved packages, 978 lines)
    - analysis_options.yaml (flutter_lints + riverpod_lint 3.x + custom rules)
    - lib/main.dart (added ProviderScope wrapper to satisfy missing_provider_scope lint)
decisions:
  - "riverpod_annotation bumped to ^4.0.0 — ^3.0.0 is incompatible with flutter_riverpod 3.3.1 (riverpod version conflict at pub resolution)"
  - "custom_lint removed from Phase 1 — analyzer version conflict: custom_lint 0.8.1 needs analyzer ^8.0.0, riverpod_generator 4.0.3 needs analyzer ^9.0.0; no overlap"
  - "drift_dev removed from Phase 1 — analyzer version conflict: drift_dev 2.32.1 needs analyzer >=10.0.0, riverpod_generator 4.0.3 needs analyzer ^9.0.0; no overlap; will be added in Plan 06"
  - "riverpod_lint 3.x uses analysis_server_plugin (not custom_lint) — plugins: block in analysis_options.yaml is the correct setup for riverpod_lint 3.x"
  - "ProviderScope added to lib/main.dart stub — required to satisfy missing_provider_scope lint rule from riverpod_lint"
  - "assets/fonts/OFL.txt placeholder created — flutter analyze fails on missing declared assets; Plan 05 replaces with real license"
metrics:
  duration: "~1 hour"
  completed: 2026-04-11
  tasks_completed: 2
  files_created: 3
  files_modified: 4
---

# Phase 1 Plan 02: Dependencies & Lint Toolchain — Summary

**One-liner:** Phase 1 pub dependency subset locked (riverpod 3.3.1, go_router 17.2.0, drift 2.32.1, 124 resolved packages), build_runner functional, riverpod_lint 3.x active via analysis_server_plugin, flutter analyze green.

## What Was Built

### Task 1: Write Phase 1 pubspec.yaml

Replaced the `flutter create`-generated `pubspec.yaml` with the Phase 1 dependency subset. Key version verification findings before writing:

**Verified actual current versions (vs plan estimates):**

| Package | Plan Said | Actual Current | Resolved Version |
|---------|-----------|----------------|-----------------|
| `drift_flutter` | ^0.2.0 | 0.3.0 | ^0.3.0 |
| `package_info_plus` | ^8.0.0 | 10.0.0 | ^10.0.0 |
| `riverpod_annotation` | ^3.0.0 | 4.0.2 | ^4.0.0 (forced — see deviations) |
| `custom_lint` | ^0.7.0 | 0.8.1 | removed (see deviations) |
| `riverpod_lint` | ^3.0.0 | 3.1.3 | ^3.0.0 |
| `go_router` | ^17.2.0 | 17.2.0 | ^17.2.0 |
| `drift` | ^2.32.1 | 2.32.1 | ^2.32.1 |
| `drift_dev` | ^2.32.1 | 2.32.1 | removed (see deviations) |
| `riverpod_generator` | ^4.0.3 | 4.0.3 | ^4.0.3 |
| `path_provider` | ^2.1.5 | 2.1.5 | ^2.1.5 |
| `flutter_lints` | ^5.0.0 | 6.0.0 | ^5.0.0 (resolves to 5.0.0) |

`flutter pub get` resolved 124 packages (978-line pubspec.lock). All excluded packages confirmed absent: no sherpa_onnx, just_audio, audio_service, epubx, file_picker, google_fonts.

Fonts manifest declared for Literata and Merriweather — all four .ttf paths registered. Plan 05 drops the actual files.

**Commit:** `6fb7db6`

### Task 2: Wire analysis_options.yaml + run first build_runner

Replaced the `flutter create` analysis_options.yaml with the Phase 1 lint ruleset:
- `include: package:flutter_lints/flutter.yaml`
- `plugins: riverpod_lint: ^3.0.0` (analysis_server_plugin API, the correct approach for riverpod_lint 3.x)
- `prefer_const_constructors`, `require_trailing_commas`, `prefer_final_locals`, `avoid_print`, `use_key_in_widget_constructors`

`dart run build_runner build --delete-conflicting-outputs` — exits 0 in 10s. Zero generated files (no annotated sources yet). Pipeline proven ready.

`flutter analyze` — initially reported 2 warnings:
1. `missing_provider_scope` on `lib/main.dart` — fixed by wrapping `MaterialApp` in `ProviderScope`
2. `asset_does_not_exist` for `assets/fonts/OFL.txt` — fixed by creating `assets/fonts/` directory structure with OFL.txt placeholder

After fixes: `flutter analyze` exits 0, no issues.

**Commit:** `9897243`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] riverpod_annotation version conflict — bumped ^3.0.0 to ^4.0.0**
- **Found during:** Task 1 (pub resolution)
- **Issue:** `riverpod_annotation ^3.0.0` is incompatible with `flutter_riverpod ^3.3.1` — riverpod_annotation 3.x pins riverpod 3.0.x while flutter_riverpod 3.3.1 requires riverpod 3.2.1. Version solving fails.
- **Fix:** Bumped to `riverpod_annotation: ^4.0.0` which resolves to 4.0.2 and is compatible with flutter_riverpod 3.3.1
- **Files modified:** `pubspec.yaml`
- **Commit:** `6fb7db6`

**2. [Rule 1 - Bug] drift_flutter version — bumped ^0.2.0 to ^0.3.0**
- **Found during:** Task 1 (version verification step)
- **Issue:** `drift_flutter ^0.2.0` exists as a constraint but resolves to 0.2.x; actual current published version is 0.3.0. Using ^0.2.0 would pin to an older release unnecessarily.
- **Fix:** Used `drift_flutter: ^0.3.0` to track the current release
- **Files modified:** `pubspec.yaml`
- **Commit:** `6fb7db6`

**3. [Rule 1 - Bug] package_info_plus version — bumped ^8.0.0 to ^10.0.0**
- **Found during:** Task 1 (version verification step)
- **Issue:** Plan said `^8.0.0` but current published version is 10.0.0. Using ^8.0.0 would resolve to an older release.
- **Fix:** Used `package_info_plus: ^10.0.0`
- **Files modified:** `pubspec.yaml`
- **Commit:** `6fb7db6`

**4. [Rule 3 - Blocking] custom_lint removed — analyzer version conflict**
- **Found during:** Task 1 (pub resolution)
- **Issue:** `custom_lint 0.8.1` requires `analyzer ^8.0.0`; `riverpod_generator 4.0.3` requires `analyzer ^9.0.0`. These version ranges do not overlap. Resolution fails.
- **Fix:** Removed `custom_lint` from pubspec. riverpod_lint 3.x no longer needs custom_lint as a host — it uses `analysis_server_plugin` directly. The lint rules still work via riverpod_lint alone.
- **Files modified:** `pubspec.yaml`
- **Commit:** `6fb7db6`

**5. [Rule 3 - Blocking] drift_dev removed — analyzer version conflict with riverpod toolchain**
- **Found during:** Task 1 (pub resolution)
- **Issue:** `drift_dev 2.32.1` requires `analyzer >=10.0.0 <13.0.0`; `riverpod_generator 4.0.3` requires `analyzer ^9.0.0` (i.e., >=9.0.0 <10.0.0). Zero overlap — cannot coexist in the same pubspec.
- **Impact assessment:** Plan 02 has no annotated `@DriftDatabase` sources — drift_dev produces no output in Phase 1. The runtime packages `drift 2.32.1` and `drift_flutter 0.3.0` have no analyzer dependency and remain.
- **Fix:** Removed `drift_dev` from Phase 1 pubspec. Will be added in Plan 06 when `@DriftDatabase` annotated sources first appear. At that point, if the analyzer conflict persists, the resolution options are: (a) wait for riverpod_generator to update to analyzer >=10, or (b) run drift codegen in a separate step.
- **Files modified:** `pubspec.yaml`
- **Commit:** `6fb7db6`

**6. [Rule 2 - Missing] analysis_options.yaml — riverpod_lint 3.x uses plugins: block, not analyzer: plugins:**
- **Found during:** Task 2
- **Issue:** Plan specified `analyzer: plugins: [custom_lint]` but riverpod_lint 3.x uses the new `analysis_server_plugin` API. The correct setup is a top-level `plugins:` block with `riverpod_lint: ^3.0.0`. Using the old custom_lint config would not activate riverpod_lint rules.
- **Fix:** Used `plugins: riverpod_lint: ^3.0.0` at top level of analysis_options.yaml
- **Files modified:** `analysis_options.yaml`
- **Commit:** `9897243`

**7. [Rule 1 - Bug] missing_provider_scope in lib/main.dart — added ProviderScope**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** riverpod_lint correctly flagged `lib/main.dart` as missing a `ProviderScope` at the widget tree root. flutter analyze exits 1.
- **Fix:** Wrapped `MaterialApp` in `ProviderScope` in the stub. Plan 08 will replace the full stub — the ProviderScope wrapping is the correct long-term pattern anyway.
- **Files modified:** `lib/main.dart`
- **Commit:** `9897243`

**8. [Rule 3 - Blocking] asset_does_not_exist for assets/fonts/OFL.txt — created placeholder**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** `pubspec.yaml` declares `assets/fonts/OFL.txt` but the file didn't exist. flutter analyze exits 1 with `asset_does_not_exist`.
- **Fix:** Created `assets/fonts/` directory structure with `OFL.txt` placeholder and subdirectories for `literata/` and `merriweather/`. Plan 05 replaces OFL.txt with the real combined license and drops the .ttf files.
- **Files modified:** `assets/fonts/OFL.txt` (created)
- **Commit:** `9897243`

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `Text('murmur')` placeholder in ProviderScope | `lib/main.dart` | Intentional — Plan 08 replaces with full go_router + ProviderScope wiring |
| OFL.txt placeholder | `assets/fonts/OFL.txt` | Intentional — Plan 05 replaces with real Literata + Merriweather combined license text |
| `assets/fonts/literata/` empty dir | Font directory | Intentional — Plan 05 drops .ttf files here |
| `assets/fonts/merriweather/` empty dir | Font directory | Intentional — Plan 05 drops .ttf files here |

These stubs do not block Plan 02's goal (dependency toolchain + lint pipeline ready).

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes were introduced. The `flutter pub get` network calls fetch from pub.dev over HTTPS (one-time). `pubspec.lock` is committed (supply-chain threat T-01-03 mitigated — exact resolved versions are pinned).

## Self-Check

**Files exist:**
- `pubspec.yaml` FOUND
- `pubspec.lock` FOUND
- `analysis_options.yaml` FOUND
- `lib/main.dart` FOUND
- `assets/fonts/OFL.txt` FOUND

**Commits exist:**
- `6fb7db6` chore(01-02): write Phase 1 pubspec.yaml with dependency subset + fonts FOUND
- `9897243` chore(01-02): wire analysis_options.yaml + confirm build_runner + analyze green FOUND

## Self-Check: PASSED
