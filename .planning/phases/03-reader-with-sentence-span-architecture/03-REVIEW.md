---
phase: 03-reader-with-sentence-span-architecture
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 27
files_reviewed_list:
  - lib/core/db/app_database.dart
  - lib/core/epub/image_extractor.dart
  - lib/core/text/sentence.dart
  - lib/core/text/sentence_splitter.dart
  - lib/features/reader/providers/font_settings_provider.dart
  - lib/features/reader/providers/font_settings_provider.g.dart
  - lib/features/reader/providers/reader_provider.dart
  - lib/features/reader/providers/reader_provider.g.dart
  - lib/features/reader/providers/reading_progress_provider.dart
  - lib/features/reader/reader_screen.dart
  - lib/features/reader/widgets/block_renderer.dart
  - lib/features/reader/widgets/chapter_drawer.dart
  - lib/features/reader/widgets/chapter_page.dart
  - lib/features/reader/widgets/chapter_sidebar.dart
  - lib/features/reader/widgets/paragraph_widget.dart
  - lib/features/reader/widgets/typography_sheet.dart
  - test/core/db/reading_progress_debounce_test.dart
  - test/core/db/reading_progress_test.dart
  - test/core/epub/image_extractor_test.dart
  - test/core/text/sentence_splitter_test.dart
  - test/core/text/sentence_test.dart
  - test/features/reader/font_settings_provider_test.dart
  - test/widget/reader/block_renderer_test.dart
  - test/widget/reader/font_settings_test.dart
  - test/widget/reader/paragraph_semantics_test.dart
  - test/widget/reader/reader_screen_test.dart
  - test/widget/reader/responsive_layout_test.dart
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 27
**Status:** issues_found

## Summary

Reviewed all 27 source and test files for the Phase 3 reader with sentence-span architecture. The overall implementation is solid: the sentence-span `RichText` pipeline is correctly wired, the Riverpod providers follow established patterns, the path traversal mitigation in `ImageExtractor` is implemented correctly with `p.basename` stripping plus `p.canonicalize` verification, and the test suite covers the critical paths across DB, TTS-splitter, widget, and integration layers.

Two warnings were identified: a fire-and-forget `_flushPending()` call inside the synchronous `ref.onDispose()` callback that can silently drop a position save on navigation-driven teardown, and a dead `ordered` field in `ListItem` rendering that produces wrong output for numbered EPUB lists. Three info items cover a fragile path-string-splitting pattern, a TODO comment, and a minor whitespace narrowness in the sentence splitter.

## Warnings

### WR-01: `_flushPending()` called fire-and-forget in `onDispose` — progress lost on navigation teardown

**File:** `lib/features/reader/providers/reading_progress_provider.dart:33-34`

**Issue:** `_flushPending()` is `async Future<void>`. Inside `ref.onDispose()` — a synchronous callback — it is called without `await`, discarding the returned `Future`. When the user navigates away from the reader without the app first transitioning through `AppLifecycleState.paused` (e.g., tapping the back button or switching routes), the provider is disposed and the pending DB write is silently abandoned. The `flushNow()` → `await _flushPending()` path in `reader_screen.dart:54` works for the pause lifecycle, but navigation-driven teardown is a gap: any scroll progress accumulated since the last debounce fire (up to 2 seconds) is lost.

**Fix:** The `onDispose` callback is fundamentally synchronous — it cannot `await`. The reliable fix is to eagerly persist the three pending fields to `shared_preferences` synchronously on each `onScrollChanged` call (no async), so that any subsequent app launch can recover them regardless of whether the Drift write completes. For a minimal change, document the known gap explicitly:

```dart
ref.onDispose(() {
  _debounceTimer?.cancel();
  // Note: _flushPending() is async but onDispose cannot await it.
  // Progress in the last ~2s window before navigation may be lost.
  // T-04 tracking: persist to shared_preferences synchronously as a backup.
  _flushPending(); // ignore: unawaited_futures
});
```

### WR-02: `ordered` field in `ListItem` is dead — ordered lists render as unordered bullets

**File:** `lib/features/reader/widgets/block_renderer.dart:60-82`

**Issue:** The `ListItem` branch destructures `ordered: final ordered` on line 60 but never references it. The `Text` widget on line 68 unconditionally shows `'\u2022 '` for every list item regardless of whether the EPUB source was `<ol>` or `<ul>`. EPUBs with numbered lists produce visually and semantically incorrect output. The TODO on line 67 acknowledges future numbering work, but the unused binding makes the code misleading — the `ordered` field appears handled but is not.

**Fix:** At minimum, distinguish the two cases so ordered lists are at least visually differentiated, even before proper counter tracking is implemented:

```dart
ListItem(text: final text, ordered: final ordered) => RepaintBoundary(
  child: Padding(
    padding: const EdgeInsets.only(left: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TODO: replace '1.' with real index when renderBlock gains context
        Text(
          ordered ? '1. ' : '\u2022 ',
          style: TextStyle(fontSize: fontSize, color: textColor),
        ),
        Expanded(
          child: ParagraphWidget(
            text: text,
            fontFamily: fontFamily,
            fontSize: fontSize,
            textColor: textColor,
            splitter: effectiveSplitter,
          ),
        ),
      ],
    ),
  ),
),
```

For proper per-item numbering, `renderBlock` needs an optional `listIndex` parameter or the list rendering needs to move to a higher-level widget that can maintain counter state.

## Info

### IN-01: Fragile manual path splitting for book directory derivation

**File:** `lib/features/reader/providers/reader_provider.dart:93-95`

**Issue:** `book.filePath.lastIndexOf('/')` with a `> 0` guard is used to derive the book's parent directory. A file at a root path such as `/book.epub` has `lastSlash == 0`, which fails the `> 0` guard and silently skips image extraction. The `path` package is already a dependency (used in `image_extractor.dart`).

**Fix:**

```dart
import 'package:path/path.dart' as p;

if (book.filePath.isNotEmpty) {
  try {
    final bookDir = p.dirname(book.filePath);
    // p.dirname returns '.' for bare filenames; skip those
    if (bookDir != '.') {
      imagePathMap = await ImageExtractor.extractImages(
        epubFilePath: book.filePath,
        outputDir: bookDir,
      );
    }
  } on Exception {
    // File missing or unreadable — degrade to no images
  }
}
```

### IN-02: TODO comment for ordered list numbering left in production code

**File:** `lib/features/reader/widgets/block_renderer.dart:67`

**Issue:** A `// TODO: render numbered items for ordered lists (future enhancement)` comment sits alongside the dead `ordered` field described in WR-02 above. Once WR-02 is addressed, this TODO should be updated to reference the specific work remaining (i.e., passing an index through to `renderBlock`) rather than being an open-ended note.

### IN-03: `_consumeTrailingWhitespace` only handles ASCII space

**File:** `lib/core/text/sentence_splitter.dart:150-154`

**Issue:** The method checks only for `' '` (U+0020). Normalized EPUB content processed through the HTML pipeline is typically fine, but raw EPUB XHTML can contain non-breaking spaces (U+00A0), tabs, or other Unicode whitespace between sentences. These characters would not be consumed, leaving them attached to the start of the next sentence's text and potentially causing unexpected behavior in downstream TTS phonemization.

**Fix:** Broaden the check. The Phase 4 sentence-splitter hardening pass (noted in the splitter's own docstring) is the right place to address this with regression fixtures:

```dart
int _consumeTrailingWhitespace(String text, int index) {
  while (index < text.length) {
    final cu = text.codeUnitAt(index);
    // ASCII space, tab, CR, LF, non-breaking space (U+00A0)
    if (cu == 0x20 || cu == 0x09 || cu == 0x0D || cu == 0x0A || cu == 0xA0) {
      index++;
    } else {
      break;
    }
  }
  return index;
}
```

---

_Reviewed: 2026-04-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
