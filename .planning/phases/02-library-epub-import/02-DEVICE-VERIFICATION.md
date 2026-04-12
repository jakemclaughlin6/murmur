---
phase: 02-library-epub-import
verified_by: Jake McLaughlin
verified_date: 2026-04-12
---

# Phase 2 Device Verification

## Android (physical device: 25079RPDCG)

| # | Verification | Result |
|---|-------------|--------|
| 1 | Batch file picker — 3 EPUBs → shimmer → real cards | PASS |
| 2 | Share intent from Files → Murmur → book imports | PASS |
| 3 | Open-in from file browser → Murmur → book imports | PASS |
| 4 | Grid: 2 columns phone portrait | PASS |
| 5 | Grid: 3 columns phone landscape | PASS |
| 6 | Grid: 4 columns tablet portrait | N/A (no tablet) |
| 7 | Grid: 6 columns tablet landscape | N/A (no tablet) |
| 8 | 60fps scroll with 50+ books | PASS |
| 9 | DRM rejection snackbar | PASS |
| 10 | Corrupt EPUB snackbar | PASS |
| 11 | Long-press → Delete → persists after relaunch | PASS |
| 12 | Empty state after deleting all books | PASS |

## iOS (DEFERRED)

| # | Verification | Result |
|---|-------------|--------|
| 13 | Share from Files.app | DEFERRED |
| 14 | Open-in-place from iCloud Drive | DEFERRED |
| 15 | Grid on iPad (4/6 cols) | DEFERRED |

**Deferral reason:** Jake has no Mac (per project constraint). iOS device
testing deferred to CI device-test window or when Mac access becomes
available. iOS CI workflow_dispatch builds an unsigned .xcarchive; physical
device install requires Apple Developer Program enrollment (Phase 4 scope).

## Issues Found During Verification

1. **release build: win32/file_picker incompatibility** — `file_picker 11.0.2`
   Windows impl incompatible with `win32 ^6.0.0` override. Fixed by
   downgrading `package_info_plus` to `^9.0.1` and removing the win32
   override.

2. **release build: receive_sharing_intent JVM target mismatch** — Plugin
   ships with Java 1.8 / Kotlin 17 mismatch. Fixed by forcing JVM 17 on
   all subprojects in root `build.gradle.kts`.

3. **GoRouter crash on Share/Open-in** — Android VIEW/SEND intents push
   `content://` URIs into Flutter's route information channel. GoRouter
   threw "no routes for location". Fixed by adding a top-level redirect
   that sends unknown URIs to `/library`.
