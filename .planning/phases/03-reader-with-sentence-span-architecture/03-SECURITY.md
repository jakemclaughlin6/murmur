---
phase: 03
slug: 03-reader-with-sentence-span-architecture
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-12
---

# Phase 03 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Block IR text -> SentenceSplitter | Text extracted from EPUB chapters flows into the splitter | Plain text, no credentials |
| EPUB zip -> ImageExtractor | Untrusted EPUB archive content extracted to local filesystem | Binary image data; filenames from attacker-controlled archive |
| shared_preferences -> FontSizeController / FontFamilyController | Persisted prefs values read back on app start | User-controlled floats and strings |
| Drift DB -> ReaderNotifier | Chapter blocksJson loaded from database | Serialized JSON, attacker-controlled if EPUB was malicious |
| Router bookId param -> ReaderScreen | URL path parameter parsed as integer | Numeric ID; attacker controls via deep link |
| User input -> font size slider | Slider drag value passed to FontSizeController | Float in arbitrary range until clamped |
| System UI mode changes -> SystemChrome | Global system chrome state mutated by reader screen | UI mode flag; leaked state affects other screens |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-03-01 | Tampering | SentenceSplitter input | accept | Splitter receives already-validated Block IR text. Malformed text produces wrong splits but cannot crash or execute code. Upstream FormatException gates in Phase 2 block_json.dart are the actual defence. | closed |
| T-03-02 | Denial of Service | SentenceSplitter huge text | accept | Phase 2 enforces per-chapter size ceiling upstream. Splitter is O(n) linear character scan — no regex backtracking. | closed |
| T-03-03 | Tampering | ImageExtractor path traversal | mitigate | `p.basename()` strips directory components from EPUB href; `p.canonicalize()` verifies output path starts with resolved imagesDir. Malicious paths (e.g. `../../etc/passwd`) are silently skipped. | closed |
| T-03-04 | Denial of Service | ImageExtractor large images | accept | EPUB images are bounded by the EPUB file size; Phase 2 import already processed and stored the file. No additional per-image size check is warranted. | closed |
| T-03-05 | Tampering | FontSizeController invalid value | mitigate | `size.clamp(minSize, maxSize)` in `FontSizeController.set()`. `FontFamilyController.set()` rejects any family not in the `availableFamilies` whitelist; state is unchanged for unknown values. | closed |
| T-03-06 | Tampering | Malformed blocks_json | mitigate | `ReaderState.blocksForChapter()` wraps `blocksFromJsonString()` in `try { } on FormatException { return []; }`. Malformed chapters render as empty — no crash, no code execution. | closed |
| T-03-07 | Tampering | ImageBlock.href path traversal in renderer | mitigate | `_ImageBlockWidget` resolves images exclusively through `imagePathMap` (produced by ImageExtractor with T-03-03 controls). No direct path construction from `href` occurs in the renderer. | closed |
| T-03-08 | Denial of Service | Book with hundreds of chapters | accept | `PageView.builder` only builds visible and adjacent pages; memory is bounded to approximately 3 chapters at a time regardless of book length. | closed |
| T-03-09 | Spoofing | Invalid bookId in URL | mitigate | `ReaderNotifier.build()` calls `db.getBook(bookId)` and throws `StateError` if the result is null. The reader screen shows an error widget; no crash or undefined navigation state occurs. | closed |
| T-03-10 | Denial of Service | Font size extreme values from slider | mitigate | `FontSizeController.minSize = 12.0` and `maxSize = 28.0` constants are used as both the clamp bounds in `set()` and the `min`/`max` on the `TypographySheet` slider, so the slider cannot produce values outside the clamped range. | closed |
| T-03-11 | Tampering | SystemChrome state leak on navigation | mitigate | `_ReaderScreenState.dispose()` unconditionally calls `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` before calling `super.dispose()`, restoring global UI mode regardless of immersive state at teardown. | closed |
| T-03-12 | Denial of Service | Progress save timer leak | mitigate | `ReadingProgressNotifier.build()` registers an `ref.onDispose` callback that calls `_debounceTimer?.cancel()` followed by `_flushPending()`. The `AppDatabase` reference is eagerly captured in `build()` to make the callback safe under Riverpod 3 disposal semantics. | closed |
| T-03-14 | Information Disclosure | Basename fallback collision in _ImageBlockWidget | accept | Basename-only fallback could show the wrong image from the same EPUB if two images share a filename. Risk is cosmetic (wrong image from the same book's own content). Mitigated by lookup priority: direct href first, then `p.normalize(href)`, then `p.basename(href)`. | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-03-01 | T-03-01 | SentenceSplitter receives pre-validated Block IR text. Worst case is incorrect sentence boundary detection (cosmetic). Cannot crash or execute code. Phase 2 FormatException gates are the upstream control. | Jake McLaughlin | 2026-04-12 |
| AR-03-02 | T-03-02 | SentenceSplitter is O(n) linear scan with no regex. Per-chapter size ceiling enforced upstream in Phase 2 import pipeline. No additional input length limit warranted. | Jake McLaughlin | 2026-04-12 |
| AR-03-03 | T-03-04 | Image data is bounded by the EPUB file already accepted during import. A malicious EPUB could have large images but this is within the accepted threat model for user-supplied EPUB files on a local device. | Jake McLaughlin | 2026-04-12 |
| AR-03-04 | T-03-08 | PageView.builder bounds chapter memory to ~3 chapters regardless of book size. No crash or runaway memory scenario exists; scrolling through a book with thousands of chapters is simply slow, not unsafe. | Jake McLaughlin | 2026-04-12 |
| AR-03-05 | T-03-14 | Basename collision can only occur between images from the same EPUB sharing a filename. The result is a wrong image displayed (cosmetic), not a path escape or data leak. Priority lookup order (direct -> normalize -> basename) minimises frequency. | Jake McLaughlin | 2026-04-12 |

---

## Unregistered Threat Flags

None. All threat flags from SUMMARY.md files map to registered threat IDs in the register above.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-12 | 13 | 13 | 0 | gsd-security-auditor (claude-sonnet-4-6) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-12
