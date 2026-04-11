# Phase 2 Spike Results

**Date:** 2026-04-11
**Ran by:** execute-plan Task 3 of 02-01-PLAN.md
**Toolchain:** Flutter 3.41.0 / Dart 3.11.0 (via mise)

## epubx ^4.0.0 Dart 3.11 compatibility — VERDICT: PASS

- **Fixture:** `test/fixtures/spike.epub` (1,570 bytes, synthesized locally via
  Python `zipfile` — a minimal valid EPUB 3.0 with `mimetype` stored first,
  `META-INF/container.xml`, `OEBPS/content.opf` with Dublin Core metadata,
  `OEBPS/nav.xhtml` (toc), and a single `OEBPS/chapter1.xhtml` chapter. No
  network fetch; deterministic assertions against hand-known title/author.
  Fallback over Project Gutenberg download per advisor guidance — keeps the
  fixture under source control and avoids a drive-by network call.)
- **EpubReader.readBook returned:**
  - Title: `Spike Fixture Title`
  - Author: `Spike Fixture Author`
  - Chapters: `1`
  - hasCover: `false` (fixture has no cover — covered in 15-EPUB corpus later)
- **Analyzer:** clean (`flutter analyze` reports 0 errors; only 2 pre-existing
  warnings unrelated to epubx)
- **Runtime:** no exceptions; `EpubReader.readBook` resolved synchronously-ish
  with proper metadata extraction

**Decision:** Proceed with epubx ^4.0.0. Dart 3.11 compatibility is verified
empirically for the minimal-EPUB happy path. The 15-EPUB corpus test in a
later Plan will catch any edge cases (malformed XHTML, EPUB 2 vs 3 quirks,
large books) — but the package itself imports, compiles, and runs under
Flutter 3.41 / Dart 3.11 without patches or wrappers.

## receive_sharing_intent ^1.8.1 availability — VERDICT: PASS (with package substitution)

- **Pub.dev resolution:** success
- **Dart import:** `package:receive_sharing_intent/receive_sharing_intent.dart`
  resolves and the spike test compiles with the import at file top
- **Analyzer:** clean (no diagnostics from this import path)
- **Runtime:** not exercised (plugins using platform channels don't run under
  `flutter_test` without `TestDefaultBinaryMessengerBinding` mocking). The
  spike only verifies the Dart/analyzer surface. Actual Share-intent wiring
  is deferred to the LIB-02 implementation plan.

### Deviation: package substitution (Rule 3 — blocking dep did not exist)

The plan specified `receive_sharing_intent_plus ^1.6.0`. During Task 1
`flutter pub get` failed with "no versions match" for that constraint.
Investigation against pub.dev's API revealed:

- `receive_sharing_intent_plus` latest version is **1.0.1**, not 1.6.x. The
  package is marked **discontinued** on pub.dev, with an explicit
  `replacedBy: receive_sharing_intent` hint. 02-RESEARCH.md assumption A2
  (that `_plus` is the maintained fork) was inverted at some point between
  the research window and today — the original `receive_sharing_intent`
  package is **maintained** (latest 1.8.1) and the `_plus` fork is the one
  that has stalled.
- Substituted `receive_sharing_intent: ^1.8.1` in `pubspec.yaml`. Same
  purpose, same API shape (the `_plus` fork inherited its API from the
  original), no downstream code written yet so no refactor cost.

**Decision:** Proceed with `receive_sharing_intent ^1.8.1` in place of
`receive_sharing_intent_plus`. LIB-02 plan remains on track; the import
surface in later plans will use
`package:receive_sharing_intent/receive_sharing_intent.dart`.

## Additional Deviation: dart_style override (Rule 3 — analyzer cascade)

While validating Task 2 codegen, the `analyzer: ^10.0.0` override surfaced a
second transitive conflict: `dart_style 3.1.3` (pulled in by build_runner
tooling) references `ParserErrorCode`, a symbol from the analyzer 8/9-era
API. Under analyzer 10 that symbol is gone and codegen fails at the
formatter step.

**Fix:** Added `dart_style: ">=3.1.4 <3.1.8"` to `dependency_overrides`.
dart_style 3.1.4 is the first version to adopt analyzer ^10.0.0; 3.1.8 moves
to analyzer ^12 which would re-break the chain. Pinning the range resolves
to `dart_style 3.1.7`, which codegens cleanly and matches the analyzer 10.x
surface.

**Decision:** Keep the override. Plan 02-02 and later can remove it if
upstream dart_style drops analyzer 10 support, but for now it's part of the
stable Phase 2 dependency set.

## Additional Deviation: win32 override (Rule 3 — desktop-only transitive)

`file_picker 11.0.2` pins `win32 ^5.9.0` but `package_info_plus 10.0.0`
(already in Phase 1) requires `win32 ^6.0.0`. murmur targets Android + iOS
only (PROJECT.md Constraints: "No desktop"), so the Windows win32 code path
is never executed at runtime. Added `win32: ^6.0.0` to `dependency_overrides`
to unblock resolution — safe because the Windows FFI surface is dead code
on our target platforms.

## Fallback plans

Both primary verdicts are PASS. No fallback work required for Plans 02-02
through 02-08. Original fallback inventory retained for reference:

- **epubx FAIL (not triggered)** → implement ~200 LOC custom parser using
  package:archive + package:xml (for content.opf) + package:html (for
  chapter XHTML). Estimated +3-4 hours to Plan 04.
- **receive_sharing_intent FAIL (not triggered)** → evaluate `app_links`
  package (URL-intent handler) or write a MethodChannel wrapper in Plan 05.
  Estimated +1-2 hours to Plan 05.
