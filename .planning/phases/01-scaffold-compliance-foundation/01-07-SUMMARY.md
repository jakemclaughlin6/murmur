---
phase: 01-scaffold-compliance-foundation
plan: 07
subsystem: crash-logging
tags: [crash-logger, jsonl, rotation, riverpod, tdd, fnd-10]
dependency_graph:
  requires: [01-02]
  provides: [CrashLogger singleton, crashLoggerProvider]
  affects: [01-08-main-dart-triple-catch-wiring]
tech_stack:
  added: []
  patterns: [JSONL-write, 1MB-rotation-rename, singleton-with-test-initializer, Riverpod-keepAlive-provider]
key_files:
  created:
    - lib/core/crash/crash_logger.dart
    - lib/core/crash/crash_logger_provider.dart
    - lib/core/crash/crash_logger_provider.g.dart
    - test/crash/crash_logger_test.dart
  modified: []
decisions:
  - CrashLoggerRef replaced with Ref (Riverpod 3 API) — plan template used Riverpod 2 convention; existing providers in project use Ref directly
metrics:
  duration: "3 minutes"
  completed: "2026-04-11T18:04:45Z"
  tasks_completed: 2
  files_created: 4
  files_modified: 0
---

# Phase 01 Plan 07: Local JSONL Crash Logger Summary

**One-liner:** Local-only JSONL crash logger with 7-field schema, 1MB rotation to single backup, and keepAlive Riverpod provider — no network path.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | CrashLogger stub + full test suite | d29bf8c | lib/core/crash/crash_logger.dart, test/crash/crash_logger_test.dart |
| 1 (GREEN) | CrashLogger full implementation | 7941f3b | lib/core/crash/crash_logger.dart |
| 2 | crashLoggerProvider + generated file | 4269823 | lib/core/crash/crash_logger_provider.dart, lib/core/crash/crash_logger_provider.g.dart |

## What Was Built

**`lib/core/crash/crash_logger.dart`** — Singleton `CrashLogger` implementing D-07 through D-10:
- `logError(Object, StackTrace, {level})` writes one JSONL line with exactly 7 fields: `ts`, `level`, `error`, `stack`, `device`, `os`, `appVersion`
- `logFlutterError(FlutterErrorDetails)` wraps the above at `level: 'flutter'`
- `_rotateIfNeeded()` renames `crashes.log` → `crashes.1.log` (overwriting any prior backup) when file reaches 1 MB, then creates a fresh `crashes.log` — max on-disk ≤ 2 MB
- Per-write `flush: true` for crash-path durability
- `initializeForTest({required Directory docs})` bypasses `path_provider` and `package_info_plus` platform channels — all 9 tests run in plain `flutter test` without test bindings
- `resetForTest()` clears the singleton between tests

**`lib/core/crash/crash_logger_provider.dart`** — `@Riverpod(keepAlive: true)` functional provider returning `CrashLogger.instance`. Plan 08's Settings placeholder can `ref.watch(crashLoggerProvider).filePath` and `.currentSize()`.

## Test Results

- **Test count:** 9 tests, all passing
- **Runtime:** ~4 seconds (includes two rotation tests writing ~8000 lines total)
- **JSONL line size observed during rotation tests:** ~700–900 bytes per line (20-frame stack trace + 7 fields)
- Lines needed to exceed 1 MB: ~1200–1400 lines; test uses 4000 to ensure rotation fires reliably

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `CrashLoggerRef` replaced with `Ref` (Riverpod 3 API)**
- **Found during:** Task 2 — `flutter analyze lib/core/crash/` reported `Undefined class 'CrashLoggerRef'`
- **Issue:** The plan's `<action>` block used `CrashLoggerRef` which was the Riverpod 2 generated ref-type convention. Riverpod 3 functional providers use `Ref` directly (as confirmed by the project's existing `app_database_provider.dart` pattern).
- **Fix:** Updated `crash_logger_provider.dart` to use `Ref ref` instead of `CrashLoggerRef ref`; regenerated `.g.dart`
- **Files modified:** `lib/core/crash/crash_logger_provider.dart`, `lib/core/crash/crash_logger_provider.g.dart`
- **Commit:** 4269823

## Known Stubs

None — all 7 JSONL fields are populated with real values in tests; `device` and `os` use test-injected strings via `initializeForTest`. Production `initialize()` populates `device` and `os` from `Platform.*` and `appVersion` from `PackageInfo.fromPlatform()`.

## Threat Flags

No new network surface introduced. Verified: `grep -rE '(http:|HttpClient|package:http|package:dio)' lib/core/crash/` returns empty. T-01-V9 mitigation is satisfied.

## Self-Check: PASSED

All 4 files exist on disk. All 3 commits (d29bf8c, 7941f3b, 4269823) verified in git log. 9/9 tests pass.
