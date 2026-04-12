---
phase: 03-reader-with-sentence-span-architecture
reviewed: 2026-04-12T19:45:00Z
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
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-04-12T19:45:00Z
**Depth:** standard
**Files Reviewed:** 27
**Status:** issues_found

## Summary

Phase 3 implements the reader screen with sentence-span architecture, responsive phone/tablet layouts, chapter navigation, font settings, and debounced reading progress persistence. The code quality is generally high -- the sealed Block hierarchy with exhaustive switching, the sentence splitter's character-by-character approach, and the Riverpod provider structure are all well-designed. Path traversal protection in image extraction is correctly implemented.

Three warnings were found: a bug where scroll progress is attributed to the wrong chapter when adjacent keep-alive pages scroll, dead logic in the ordered list renderer, and an unawaited Future in the progress flush path that risks data loss on app pause.

## Warnings

### WR-01: Scroll progress attributed to wrong chapter via stale closure capture

**File:** `lib/features/reader/reader_screen.dart:138-142`
**Issue:** The `onScrollOffsetChanged` callback inside `PageView.builder`'s `itemBuilder` captures `readerState.currentChapterIndex` instead of the `index` parameter from the builder. Because `ChapterPage` uses `AutomaticKeepAliveClientMixin` (line 42 of `chapter_page.dart`), adjacent chapters remain alive. When a kept-alive adjacent chapter scrolls, its `onScrollOffsetChanged` fires and reports progress against `readerState.currentChapterIndex` (the chapter the user is viewing) rather than its own `index`. This silently saves incorrect reading progress.
**Fix:**
```dart
onScrollOffsetChanged: (fraction) {
  ref
      .read(readingProgressProvider.notifier)
      .onScrollChanged(
        widget.bookId!,
        index,  // was: readerState.currentChapterIndex
        fraction,
      );
},
```

### WR-02: Ordered list items render identically to unordered -- dead ternary

**File:** `lib/features/reader/widgets/block_renderer.dart:66`
**Issue:** The expression `ordered ? '\u2022 ' : '\u2022 '` evaluates to the same bullet character on both branches. The `ordered` parameter is accepted but completely ignored, making the ternary dead logic. While the comment acknowledges this is a "future enhancement," the ternary itself is misleading -- it looks like it differentiates but does not.
**Fix:** Remove the ternary and use a plain literal. Add a TODO if ordered numbering is planned:
```dart
// TODO: render numbered items for ordered lists (future enhancement)
Text(
  '\u2022 ',
  style: TextStyle(fontSize: fontSize, color: textColor),
),
```

### WR-03: Unawaited Future in reading progress flush risks data loss on app pause

**File:** `lib/features/reader/providers/reading_progress_provider.dart:62`
**Issue:** `_flushPending()` calls `_db.updateReadingProgress(...)` without awaiting the returned `Future`. This is called from `flushNow()` which is invoked by `didChangeAppLifecycleState` when the app pauses. If the OS kills the process before the unawaited Future's database write completes, the user's reading position is lost. In the `onDispose` path this is unavoidable (sync callback), but `flushNow()` can be made async.
**Fix:** Make `_flushPending` and `flushNow` async so callers can await completion:
```dart
Future<void> flushNow() async {
  _debounceTimer?.cancel();
  await _flushPending();
}

Future<void> _flushPending() async {
  if (_pendingBookId == null ||
      _pendingChapter == null ||
      _pendingOffset == null) {
    return;
  }
  await _db.updateReadingProgress(
      _pendingBookId!, _pendingChapter!, _pendingOffset!);
  _pendingBookId = null;
  _pendingChapter = null;
  _pendingOffset = null;
}
```
Note: the `onDispose` call site cannot await, but the `didChangeAppLifecycleState` call in `reader_screen.dart:52` could then `await` or at minimum the Future is no longer silently dropped.

## Info

### IN-01: Synchronous file existence check in build method

**File:** `lib/features/reader/widgets/block_renderer.dart:165`
**Issue:** `File(localPath).existsSync()` performs synchronous I/O inside a widget's `build()` method. For image-heavy chapters or slow storage, this blocks the UI thread. Acceptable for v1 scope but worth noting for future optimization.
**Fix:** Consider caching the existence check result in the image path map at extraction time, or using a FutureBuilder pattern for image loading.

### IN-02: `_consumeTrailingWhitespace` only handles ASCII space

**File:** `lib/core/text/sentence_splitter.dart:152`
**Issue:** The whitespace consumer only checks for `' '` (0x20) and does not handle tabs, non-breaking spaces, or other Unicode whitespace characters. For EPUB content that has already been through HTML normalization this is likely fine, but raw EPUB XHTML occasionally contains `\u00A0` (non-breaking space) or `\t` between sentences.
**Fix:** If edge cases arise in real EPUBs, broaden to check `text.codeUnitAt(index) <= 0x20 || text[index] == '\u00A0'` or use a regex character class. Low priority for v1 English-only scope.

---

_Reviewed: 2026-04-12T19:45:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
