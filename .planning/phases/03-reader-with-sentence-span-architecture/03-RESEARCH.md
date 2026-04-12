# Phase 3: Reader with Sentence-Span Architecture - Research

**Researched:** 2026-04-12
**Domain:** Flutter reader UI, sentence splitting, scroll restoration, responsive layout
**Confidence:** HIGH

## Summary

Phase 3 builds the reading experience on top of Phase 2's Block IR and Drift persistence. The core architecture is a horizontal `PageView` of chapters where each chapter is a vertical `ListView.builder` of per-paragraph `RichText` widgets, with each paragraph composed of one `TextSpan` per `Sentence`. This is locked by CONTEXT.md D-01 through D-17 and is the permanent reader architecture (not a retrofit).

No new packages are needed -- everything required is already in `pubspec.yaml`. The research focus is on Flutter-specific implementation patterns and pitfalls: nested scroll physics, fractional scroll position save/restore, immersive mode system chrome, accessibility semantics for `RichText`, and the basic sentence splitter regex.

**Primary recommendation:** Build the sentence splitter and block-to-widget renderer first (pure logic, fully unit-testable), then layer the PageView/ListView composition, then add chrome controls (immersive mode, chapter nav, typography settings). The scroll position save/restore is the trickiest integration point and should be wired last within the reader shell.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Sentence splitting happens at render time, not at import time. Block IR unchanged from Phase 2.
- **D-02:** Phase 3 builds a basic `SentenceSplitter` splitting on `.`, `!`, `?` with abbreviation/decimal/ellipsis handling. Lives in `lib/core/text/sentence_splitter.dart`.
- **D-03:** `Sentence` data model is `class Sentence { final String text; }` in `lib/core/text/sentence.dart`.
- **D-04:** Headings render as single TextSpan (no splitting). Blockquotes and list items are sentence-split. ImageBlocks are `Image.file()` widgets.
- **D-05:** Horizontal PageView of chapters; each page is a vertical ListView.builder of paragraph RichText widgets inside RepaintBoundary.
- **D-06:** Lazy chapter loading -- only current chapter deserialized. Adjacent chapters pre-loaded.
- **D-07:** Font size changes reflow immediately (no page recomputation).
- **D-08:** Tablets (shortest side >= 600dp) show persistent chapter sidebar (~300px). Always visible.
- **D-09:** Phones (shortest side < 600dp) show slide-over chapter drawer from app bar icon.
- **D-10:** Immersive mode: tapping center ~1/3 toggles app bar. Tablet sidebar stays visible. Phone drawer only accessible when app bar visible.
- **D-11:** Reading position = chapter index (int) + scroll offset fraction (0.0-1.0).
- **D-12:** Progress saved on scroll-stop after 2s debounce. Flushed on AppLifecycleState.paused.
- **D-13:** On book open, resume at saved position. First open starts at chapter 0, offset 0.0.
- **D-14:** Font size slider 12-28pt, continuous, persisted to shared_preferences.
- **D-15:** Font family picker: Literata and Merriweather only (per Phase 1 D-21).
- **D-16:** Theme uses existing Phase 1 infrastructure. No separate reader theme.
- **D-17:** Typography controls via bottom sheet from app bar icon.

### Claude's Discretion
- Exact tap-zone geometry for immersive mode toggle
- SentenceSplitter abbreviation list completeness
- Chapter sidebar width on large tablets
- ScrollController debounce implementation (Timer-based vs stream-based)
- Animation for chapter drawer open/close
- Whether font size slider shows numeric label
- ImageBlock rendering strategy (extract and cache vs read from EPUB on demand)

### Deferred Ideas (OUT OF SCOPE)
None deferred in Phase 3 discussion. Previously deferred items remain deferred:
- Bookmarks (RDR-13, RDR-14) -- Phase 6
- Continuous-scroll reader mode (RDR-15) -- v2
- Dictionary lookup (RDR-16) -- v2
- Additional reader fonts -- v2
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RDR-01 | Opening a book loads chapter list and resumes last position | Scroll position restore pattern (Pitfall 2), Drift query additions |
| RDR-02 | PageView of paginated content, one chapter per page run | PageView + ListView nesting pattern (Architecture Pattern 1) |
| RDR-03 | Per-paragraph RichText inside ListView.builder with RepaintBoundary | Block-to-widget renderer pattern (Architecture Pattern 2) |
| RDR-04 | Every paragraph composed of one TextSpan per Sentence | SentenceSplitter + Sentence model (Architecture Pattern 3) |
| RDR-05 | Semantics at paragraph level for VoiceOver/TalkBack | Accessibility pattern (Architecture Pattern 4) |
| RDR-06 | Font size slider 12-28pt with immediate apply | Font/theme provider pattern (Architecture Pattern 5) |
| RDR-07 | Font family picker from bundled options | Same provider pattern, 2 families per D-15 |
| RDR-08 | Theme switching (light/sepia/dark/OLED) persists | Existing Phase 1 ThemeModeController -- no new work |
| RDR-09 | Tablet persistent sidebar, phone slide-over drawer | Responsive layout pattern (Architecture Pattern 6) |
| RDR-10 | Tap chapter to jump, current chapter highlighted | PageController.jumpToPage + sidebar state |
| RDR-11 | Reading progress saved on page turn, debounced 2s | Debounced scroll save pattern (Architecture Pattern 7) |
| RDR-12 | Tapping center toggles immersive mode | Immersive mode pattern (Architecture Pattern 8) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **No HTML-opaque renderers**: `flutter_html`, `flutter_widget_from_html`, `epub_view`, webview are all forbidden. Reader MUST use `RichText` with `TextSpan` per sentence.
- **Sentence-first architecture**: Sentences are a first-class data structure from Phase 3 onward.
- **60fps scroll**: Reader must scroll at 60fps on mid-range phones/tablets.
- **Two font families only**: Literata and Merriweather (Phase 1 D-21).
- **Four themes**: Light, sepia, dark, OLED -- existing infrastructure.
- **Riverpod + code-gen**: All providers use `@riverpod` annotation.
- **Drift for persistence**: Reading progress stored in existing `books` table columns.
- **shared_preferences for simple settings**: Font size, font family.

## Standard Stack

### No New Dependencies Required

All packages needed for Phase 3 are already in `pubspec.yaml`. Phase 3 is pure Flutter widget + Dart logic work building on the existing dependency set. [VERIFIED: pubspec.yaml inspection]

| Existing Package | Phase 3 Use |
|-----------------|-------------|
| `flutter_riverpod` / `riverpod_annotation` | Font size, font family, chapter state, reader state providers |
| `drift` / `drift_flutter` | Reading progress queries (update chapter/offset, update lastReadDate, get chapters for book) |
| `shared_preferences` | Font size and font family persistence |
| `go_router` | `/reader/:bookId` route already wired |

### New Drift Queries (Not Schema Changes)

Phase 3 needs to add query methods to `AppDatabase` or companion DAOs. These are **code additions only** -- no schema version bump required because the `readingProgressChapter`, `readingProgressOffset`, and `lastReadDate` columns already exist in the `books` table. [VERIFIED: `books_table.dart` inspection]

Required queries:
1. `getChaptersForBook(int bookId)` -- returns `List<Chapter>` ordered by `orderIndex`
2. `updateReadingProgress(int bookId, int chapter, double offset)` -- updates the two progress columns
3. `updateLastReadDate(int bookId)` -- sets `lastReadDate` to `DateTime.now()`
4. `getBook(int bookId)` -- returns single `Book` for loading saved position on open

## Architecture Patterns

### Recommended Project Structure

```
lib/
  core/
    text/
      sentence.dart              # Sentence data model (D-03)
      sentence_splitter.dart     # SentenceSplitter class (D-02)
    db/
      app_database.dart          # Add query methods (no schema change)
  features/
    reader/
      reader_screen.dart         # Replace Phase 2 stub -- orchestrates PageView
      widgets/
        chapter_page.dart        # Single chapter ListView.builder
        block_renderer.dart      # Block -> Widget exhaustive switch
        paragraph_widget.dart    # RichText with per-sentence TextSpans
        chapter_sidebar.dart     # Tablet persistent sidebar (D-08)
        chapter_drawer.dart      # Phone slide-over drawer (D-09)
        typography_sheet.dart    # Bottom sheet with font size + family (D-17)
      providers/
        reader_provider.dart     # Book + chapters loading, current chapter state
        reading_progress_provider.dart  # Debounced save logic
        font_settings_provider.dart     # Font size + font family from shared_preferences
```

### Pattern 1: PageView + ListView Nesting (D-05)

**What:** Horizontal PageView where each page contains a vertical ListView.builder.
**When to use:** Chapter-based reading with per-chapter vertical scroll.

The key insight: when the scroll axes are perpendicular (horizontal PageView, vertical ListView), Flutter's gesture arena handles disambiguation correctly by default. No custom scroll physics or `NeverScrollableScrollPhysics` needed. [CITED: https://api.flutter.dev/flutter/widgets/PageView-class.html]

```dart
// Source: Flutter PageView docs + D-05/D-06
PageView.builder(
  controller: _pageController,
  itemCount: chapters.length,
  onPageChanged: (index) => ref.read(readerProvider.notifier).setChapter(index),
  itemBuilder: (context, index) {
    // D-06: lazy loading -- only current and adjacent chapters
    return ChapterPage(
      chapter: chapters[index],
      fontSettings: fontSettings,
    );
  },
)
```

**Adjacent chapter preloading (D-06):** `PageView` with default `viewportFraction: 1.0` already keeps `cacheExtent` pages in memory. Set `PageController(keepPage: true)` so swiped-away chapters retain their scroll position within the session. The `PageView.builder` constructor ensures only built chapters consume memory. [ASSUMED]

### Pattern 2: Block-to-Widget Renderer (D-04, RDR-03)

**What:** Exhaustive switch on the sealed `Block` hierarchy producing Flutter widgets.
**When to use:** Converting Block IR to reader display.

```dart
// Source: Existing block.dart sealed class pattern
Widget renderBlock(Block block, FontSettings fontSettings) {
  return switch (block) {
    Paragraph(text: final text) => RepaintBoundary(
      child: _buildParagraphWidget(text, fontSettings),
    ),
    Heading(level: final level, text: final text) => RepaintBoundary(
      child: _buildHeadingWidget(level, text, fontSettings),
    ),
    Blockquote(text: final text) => RepaintBoundary(
      child: _buildBlockquoteWidget(text, fontSettings),
    ),
    ListItem(text: final text, ordered: final ordered) => RepaintBoundary(
      child: _buildListItemWidget(text, ordered, fontSettings),
    ),
    ImageBlock(href: final href, alt: final alt) => RepaintBoundary(
      child: _buildImageWidget(href, alt),
    ),
  };
}
```

**RepaintBoundary placement:** Wrap each block widget (not the inner RichText) so paragraph-level repaints during scroll don't trigger siblings. This is standard for long-list performance. [ASSUMED]

### Pattern 3: Sentence-Span RichText (D-02, D-03, RDR-04)

**What:** Each paragraph rendered as `RichText` with one `TextSpan` per `Sentence`.
**When to use:** Every text block type except Heading.

```dart
// Per-paragraph RichText with sentence TextSpans
Widget _buildParagraphWidget(String text, FontSettings settings) {
  final sentences = sentenceSplitter.split(text);
  return Semantics(
    // RDR-05: paragraph-level semantics for screen readers
    label: text,
    child: ExcludeSemantics(
      child: RichText(
        text: TextSpan(
          children: sentences.map((s) => TextSpan(
            text: s.text,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: settings.fontSize,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          )).toList(),
        ),
      ),
    ),
  );
}
```

**Why each sentence is a separate TextSpan now:** Phase 5 will add per-sentence highlight state by modifying the `TextSpan.style.backgroundColor` of the active sentence. Building this structure in Phase 3 means Phase 5 is a style change, not an architecture change. [VERIFIED: CONTEXT.md D-03, D-04]

### Pattern 4: Accessibility Semantics (RDR-05)

**What:** Wrap each paragraph-level widget in `Semantics(label: fullText)` and `ExcludeSemantics` around the inner `RichText`.
**Why:** `RichText` with multiple `TextSpan` children does NOT automatically merge them into a single accessibility label. Without explicit `Semantics`, screen readers may read each `TextSpan` as a separate element, producing sentence-by-sentence narration instead of paragraph-level reading. [CITED: https://github.com/flutter/flutter/issues/129033]

The pattern is:
1. Outer `Semantics(label: fullParagraphText)` -- screen reader reads the whole paragraph
2. `ExcludeSemantics` wrapping the `RichText` -- prevents individual TextSpan semantics from leaking
3. The `RichText` itself handles visual rendering with per-sentence spans

### Pattern 5: Font Settings Provider (D-14, D-15)

**What:** Riverpod providers for font size (double) and font family (String), persisted to shared_preferences.
**When to use:** Reader body text styling.

```dart
// Font size provider -- follows ThemeModeController pattern
@Riverpod(keepAlive: true)
class FontSizeController extends _$FontSizeController {
  static const String prefsKey = 'settings.fontSize';
  static const double defaultSize = 18.0;
  static const double minSize = 12.0;
  static const double maxSize = 28.0;

  @override
  Future<double> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(prefsKey) ?? defaultSize;
  }

  Future<void> set(double size) async {
    final clamped = size.clamp(minSize, maxSize);
    state = AsyncData(clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(prefsKey, clamped);
  }
}
```

Font family follows the same pattern with `getString` / `setString`, defaulting to `'Literata'`.

### Pattern 6: Responsive Layout (D-08, D-09, RDR-09)

**What:** `MediaQuery` shortest-side breakpoint at 600dp determines tablet vs phone layout.

```dart
// In reader_screen.dart build()
final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

if (isTablet) {
  return Row(
    children: [
      SizedBox(
        width: 300, // D-08: ~300px sidebar
        child: ChapterSidebar(
          chapters: chapters,
          currentIndex: currentChapter,
          onChapterTap: (i) => pageController.jumpToPage(i),
        ),
      ),
      const VerticalDivider(width: 1),
      Expanded(child: readerPageView),
    ],
  );
} else {
  return Scaffold(
    drawer: ChapterDrawer(...), // D-09: slide-over on phone
    body: readerPageView,
  );
}
```

### Pattern 7: Debounced Progress Save (D-11, D-12, RDR-11)

**What:** Save reading position on scroll-stop after 2s debounce, flush on app pause.

```dart
// Timer-based debounce on ScrollController
class _ChapterPageState extends State<ChapterPage>
    with WidgetsBindingObserver {
  Timer? _saveTimer;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _saveProgress);
  }

  void _saveProgress() {
    final pos = _scrollController.position;
    if (!pos.hasContentDimensions || pos.maxScrollExtent == 0) return;
    final fraction = pos.pixels / pos.maxScrollExtent;
    ref.read(readingProgressProvider.notifier)
        .save(widget.bookId, currentChapter, fraction.clamp(0.0, 1.0));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveTimer?.cancel();
      _saveProgress(); // D-12: immediate flush on background
    }
  }
}
```

### Pattern 8: Immersive Mode (D-10, RDR-12)

**What:** Tapping center third of reader toggles app bar visibility. System chrome hidden.

**Android target SDK is 34** [VERIFIED: `build.gradle.kts`], which means `SystemUiMode.immersiveSticky` still works. If target SDK rises to 35+, immersive mode requires migration -- flag for Phase 7. [CITED: https://api.flutter.dev/flutter/services/SystemUiMode.html]

```dart
// Immersive mode toggle
void _toggleImmersive() {
  setState(() => _immersive = !_immersive);
  if (_immersive) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } else {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge, // restore system bars
    );
  }
}

// Tap zone detection in GestureDetector
GestureDetector(
  onTap: () {
    final box = context.findRenderObject() as RenderBox;
    final height = box.size.height;
    final tapY = /* from TapDownDetails */ details.localPosition.dy;
    final third = height / 3;
    if (tapY > third && tapY < third * 2) {
      _toggleImmersive();
    }
  },
  child: readerContent,
)
```

**Important:** Reset system UI mode when leaving the reader screen (`dispose` or `deactivate`), otherwise the system bars stay hidden app-wide. [ASSUMED]

### Anti-Patterns to Avoid

- **Wrapping each sentence in a separate Widget (WidgetSpan):** This breaks both accessibility (screen readers see separate elements) and performance (Widget overhead per sentence vs lightweight TextSpan). Use `TextSpan` children, not `WidgetSpan`.
- **Using `NeverScrollableScrollPhysics` on the inner ListView:** Not needed when axes are perpendicular. Would break the vertical scroll entirely.
- **Storing scroll position as absolute pixels:** Meaningless after font size change. D-11's fraction-based model is correct.
- **Calling `jumpTo` before layout completes:** `maxScrollExtent` is 0 until after the first frame. Must use `addPostFrameCallback` or check `hasContentDimensions`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Theme system | Custom color management | Existing `ClayColors` + `ThemeModeController` + `themeFor()` | Phase 1 already built this; reader inherits |
| Font loading | Manual font file management | Flutter's `pubspec.yaml` font declarations | Already declared for Literata + Merriweather |
| Chapter drawer | Custom drawer from scratch | Flutter's `Drawer` widget or `showModalBottomSheet` | Standard Material component, well-tested |
| Settings persistence | File-based settings | `shared_preferences` | Already used for theme mode |
| Database queries | Raw SQL strings | Drift's type-safe query builder | Already the locked ORM |

## Common Pitfalls

### Pitfall 1: Scroll Position Restore After Font Size Change
**What goes wrong:** User saves position at fraction 0.5 with 18pt font. Changes to 24pt. `maxScrollExtent` grows. The fraction 0.5 now points to a different paragraph.
**Why it happens:** Fraction-based position is font-size-dependent because content height changes.
**How to avoid:** Accept this as a known limitation for Phase 3. The position will be approximately correct (same general area of the chapter). True paragraph-anchored position requires tracking which block index is at the top of the viewport, which is Phase 5+ territory (needed for TTS sync anyway). For Phase 3, the fraction is good enough -- it restores within a few paragraphs of where the user was.
**Warning signs:** QA reports of "lost my place after changing font size."

### Pitfall 2: Restoring Scroll Position on Book Open
**What goes wrong:** `ScrollController.jumpTo(fraction * maxScrollExtent)` called before layout produces `jumpTo(0)` because `maxScrollExtent` is still 0.
**Why it happens:** `maxScrollExtent` is not available until after the first frame layout. [CITED: https://api.flutter.dev/flutter/widgets/ScrollPosition-class.html]
**How to avoid:** Use `WidgetsBinding.instance.addPostFrameCallback` after the chapter ListView is built, then check `scrollController.position.hasContentDimensions` before computing the offset. If content dimensions are not yet available, attach a listener to `ScrollPosition.isScrollingNotifier` or use `ScrollMetricsNotification`.
**Warning signs:** Books always opening at the top despite having saved progress.

### Pitfall 3: Timer Leak in Debounced Save
**What goes wrong:** `_saveTimer` fires after the reader widget is disposed, causing a `setState` on an unmounted State or a stale `ref.read`.
**Why it happens:** 2-second debounce timer outlives the widget if the user leaves the reader quickly.
**How to avoid:** Cancel the timer in `dispose()`. Also guard the callback: check `mounted` before accessing `ref` or calling `setState`.
**Warning signs:** "setState() called after dispose()" errors in debug console.

### Pitfall 4: PageView Losing Inner Scroll Position
**What goes wrong:** Swiping away from a chapter and back resets the chapter's ListView to the top.
**Why it happens:** `PageView` disposes off-screen pages by default.
**How to avoid:** Use `AutomaticKeepAliveClientMixin` on the ChapterPage widget, or keep the ScrollController position in a Riverpod provider keyed by chapter index. `PageController(keepPage: true)` helps but is not sufficient alone for the inner ListView state.
**Warning signs:** Swiping forward then back always showing chapter top.

### Pitfall 5: ImageBlock Rendering from EPUB Archive
**What goes wrong:** ImageBlocks reference EPUB-internal hrefs (e.g., `../images/cover.jpg`). These are paths within the EPUB zip, not file system paths.
**Why it happens:** Phase 2's Block IR stores the EPUB-internal `href` as-is.
**How to avoid:** At render time, the image must be extracted from the EPUB archive. Two approaches: (a) extract all images at import time and cache to disk (simpler at render time, more disk usage), or (b) extract on demand using `epubx` to read the EPUB zip and find the image by href (lazy, less disk). Approach (a) is recommended -- extract images during import and store paths in a known location. The `ImageBlock.href` then maps to `${appDocumentsDir}/books/${bookId}/images/${filename}`.
**Warning signs:** Broken image icons in the reader.

### Pitfall 6: SystemChrome Not Reset on Reader Exit
**What goes wrong:** Immersive mode persists after leaving the reader. Library screen has no status bar.
**Why it happens:** `SystemChrome.setEnabledSystemUIMode` is global, not scoped to a route.
**How to avoid:** Reset to `SystemUiMode.edgeToEdge` in the reader widget's `dispose()`. Also reset on `WillPopScope` / `PopScope` for back navigation.
**Warning signs:** Status bar missing on library screen after reading.

### Pitfall 7: Sentence Splitter Edge Cases
**What goes wrong:** "Mr. Smith went to Washington. He liked it." splits into ["Mr.", " Smith went to Washington.", " He liked it."] -- three sentences instead of two.
**Why it happens:** Naive split on `.` doesn't know about abbreviations.
**How to avoid:** The basic splitter uses a negative lookbehind pattern to skip known abbreviations. See the SentenceSplitter code example below. Accept that edge cases will exist -- Phase 4 TTS-06 hardens with 500+ fixtures.
**Warning signs:** Short fragments appearing as standalone sentences in the reader (visual inspection with debug borders on TextSpans).

## Code Examples

### SentenceSplitter Implementation (D-02)

```dart
// lib/core/text/sentence_splitter.dart
// Basic sentence splitter for Phase 3. Phase 4 TTS-06 hardens with 500+ fixtures.

class SentenceSplitter {
  // Common English abbreviations that should NOT trigger a sentence break.
  // This list is intentionally conservative for Phase 3.
  static const _abbreviations = {
    'Mr', 'Mrs', 'Ms', 'Dr', 'Prof', 'Rev', 'Sr', 'Jr',
    'St', 'Ave', 'Blvd',
    'Gen', 'Gov', 'Sgt', 'Cpl', 'Pvt', 'Capt', 'Lt', 'Col', 'Maj',
    'vs', 'etc', 'approx',
    'dept', 'est', 'vol',
    'Jan', 'Feb', 'Mar', 'Apr', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  };

  // Also protect: U.S., U.K., A.M., P.M., e.g., i.e.
  static final _abbreviationDotPattern = RegExp(
    r'(?:^|[\s(])([A-Z]\.){2,}', // Matches A.M., U.S.A., etc.
  );

  List<Sentence> split(String text) {
    if (text.trim().isEmpty) return const [];

    final sentences = <Sentence>[];
    final buffer = StringBuffer();
    final chars = text.runes.toList();

    for (var i = 0; i < chars.length; i++) {
      final char = String.fromCharCode(chars[i]);
      buffer.write(char);

      if (char == '.' || char == '!' || char == '?') {
        // Check for ellipsis (... or more dots)
        if (char == '.' && _isEllipsis(chars, i)) continue;

        // Check for decimal number (e.g., 3.14)
        if (char == '.' && _isDecimal(chars, i)) continue;

        // Check for known abbreviation
        if (char == '.' && _isAbbreviation(buffer.toString())) continue;

        // Check for initials pattern (A.B.C.)
        if (char == '.' && _isInitialPattern(buffer.toString())) continue;

        // Include any trailing quote or paren
        while (i + 1 < chars.length) {
          final next = String.fromCharCode(chars[i + 1]);
          if (next == '"' || next == '\u201D' || next == '\'' ||
              next == '\u2019' || next == ')') {
            buffer.write(next);
            i++;
          } else {
            break;
          }
        }

        // We have a sentence boundary
        final sentenceText = buffer.toString().trim();
        if (sentenceText.isNotEmpty) {
          sentences.add(Sentence(sentenceText));
        }
        buffer.clear();

        // Skip whitespace after sentence end
        while (i + 1 < chars.length &&
            String.fromCharCode(chars[i + 1]).trim().isEmpty) {
          i++;
        }
      }
    }

    // Remaining text is a sentence (may not end with punctuation)
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      sentences.add(Sentence(remaining));
    }

    return sentences;
  }

  bool _isEllipsis(List<int> chars, int i) {
    // Look ahead for more dots
    if (i + 1 < chars.length && chars[i + 1] == 0x2E) return true; // .
    // Also check Unicode ellipsis character
    if (chars[i] == 0x2026) return false; // treat as sentence end
    return false;
  }

  bool _isDecimal(List<int> chars, int i) {
    if (i == 0) return false;
    final prev = chars[i - 1];
    final hasNext = i + 1 < chars.length;
    final nextIsDigit = hasNext && chars[i + 1] >= 0x30 && chars[i + 1] <= 0x39;
    final prevIsDigit = prev >= 0x30 && prev <= 0x39;
    return prevIsDigit && nextIsDigit;
  }

  bool _isAbbreviation(String bufferSoFar) {
    // Extract last word before the dot
    final trimmed = bufferSoFar.trimRight();
    if (trimmed.isEmpty) return false;
    // Remove trailing dot
    final withoutDot = trimmed.substring(0, trimmed.length - 1);
    // Get last word
    final lastSpace = withoutDot.lastIndexOf(RegExp(r'\s'));
    final lastWord = lastSpace == -1 ? withoutDot : withoutDot.substring(lastSpace + 1);
    return _abbreviations.contains(lastWord);
  }

  bool _isInitialPattern(String bufferSoFar) {
    // Match patterns like "J. K. Rowling" -- single letter before dot
    final trimmed = bufferSoFar.trimRight();
    if (trimmed.length < 2) return false;
    final beforeDot = trimmed[trimmed.length - 2];
    if (trimmed.length >= 3) {
      final beforeLetter = trimmed[trimmed.length - 3];
      if (beforeLetter == ' ' || beforeLetter == '.') {
        return beforeDot.contains(RegExp(r'[A-Z]'));
      }
    }
    // Start of string
    if (trimmed.length == 2 && beforeDot.contains(RegExp(r'[A-Z]'))) {
      return true;
    }
    return false;
  }
}
```

**Note:** This is illustrative pseudocode. The actual implementation should be test-driven against basic fixtures first, then refined. Phase 4 TTS-06 will add 500+ regression fixtures. [ASSUMED]

### Sentence Data Model (D-03)

```dart
// lib/core/text/sentence.dart
class Sentence {
  final String text;

  const Sentence(this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Sentence && other.text == text);

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'Sentence($text)';
}
```

### Scroll Position Restore on Book Open (D-13)

```dart
// In ChapterPage, after build
@override
void initState() {
  super.initState();
  if (widget.initialOffsetFraction != null && widget.initialOffsetFraction! > 0) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pos = _scrollController.position;
      if (pos.hasContentDimensions && pos.maxScrollExtent > 0) {
        _scrollController.jumpTo(
          widget.initialOffsetFraction! * pos.maxScrollExtent,
        );
      }
    });
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `SystemUiMode.manual` for immersive | `SystemUiMode.immersiveSticky` | Flutter 2.5+ | Cleaner API, sticky behavior on swipe |
| Navigator 1.0 push/pop | go_router declarative routing | 2023+ | Already adopted in Phase 1 |
| Provider for state management | Riverpod 3 with code-gen | 2025 | Already adopted in Phase 1 |

**Android SDK 35+ deprecation of immersive modes:** Android SDK 35 (API 35) makes `edgeToEdge` the only supported system UI mode. Current `targetSdk = 34` is safe. When Phase 7 bumps target SDK for store compliance, immersive mode implementation will need revisiting. [CITED: https://api.flutter.dev/flutter/services/SystemUiMode.html]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | PageView default cacheExtent is sufficient for adjacent chapter preloading (D-06) | Pattern 1 | May need explicit `cacheExtent` or manual preload |
| A2 | RepaintBoundary per block widget provides meaningful scroll performance gain | Pattern 2 | Unnecessary wrapping adds minor overhead; easy to remove |
| A3 | AutomaticKeepAliveClientMixin preserves inner ListView scroll state in PageView | Pitfall 4 | May need per-chapter ScrollController + Riverpod state |
| A4 | SystemChrome immersive mode reset in dispose() is reliable on both platforms | Pitfall 6 | May need RouteObserver or go_router redirect hook |
| A5 | SentenceSplitter pseudocode handles the common 80% of English text correctly | Code Examples | Edge cases exposed by Phase 4 fixture suite |
| A6 | Extract-at-import for ImageBlock images is more practical than on-demand extraction | Pitfall 5 | Phase 2 import may need retroactive image extraction step |

## Open Questions

1. **ImageBlock image extraction timing**
   - What we know: Phase 2 Block IR stores EPUB-internal href. Images live inside the EPUB zip.
   - What's unclear: Did Phase 2 import extract images to disk, or does the reader need to extract on demand?
   - Recommendation: Check Phase 2 import code. If images were NOT extracted, add an image extraction step as part of Phase 3 reader initialization (extract on first open, cache to `${appDocumentsDir}/books/${bookId}/images/`). This is a one-time cost per book.

2. **PageView keepAlive behavior with many chapters**
   - What we know: Some books have 50+ chapters. Keeping all visited chapters alive wastes memory.
   - What's unclear: What's the right eviction strategy?
   - Recommendation: Only keep current + adjacent chapters alive. Let PageView dispose others. The scroll position for non-adjacent chapters is lost within the session but the Drift-persisted chapter+offset restores on re-navigation.

3. **Font size slider UX: numeric label or not?**
   - What we know: D-14 says continuous slider 12-28pt. Claude's discretion on label.
   - Recommendation: Show a numeric label (e.g., "18pt") next to the slider. It's a one-line `Text` widget and helps users communicate preferences ("I use 22pt").

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter SDK) |
| Config file | None needed (uses default `flutter_test` runner) |
| Quick run command | `flutter test test/core/text/` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RDR-04 | SentenceSplitter produces correct sentence boundaries | unit | `flutter test test/core/text/sentence_splitter_test.dart -x` | Wave 0 |
| RDR-04 | Sentence model equality and hashCode | unit | `flutter test test/core/text/sentence_test.dart -x` | Wave 0 |
| RDR-03 | Block renderer produces correct widget types per block variant | widget | `flutter test test/widget/reader/block_renderer_test.dart -x` | Wave 0 |
| RDR-05 | Paragraph widgets have Semantics with full paragraph text | widget | `flutter test test/widget/reader/paragraph_semantics_test.dart -x` | Wave 0 |
| RDR-01 | Reader loads chapters from DB and displays first chapter | widget | `flutter test test/widget/reader/reader_screen_test.dart -x` | Wave 0 |
| RDR-11 | Reading progress saved to DB after debounce | unit | `flutter test test/core/db/reading_progress_test.dart -x` | Wave 0 |
| RDR-06 | Font size change applies immediately to RichText widgets | widget | `flutter test test/widget/reader/font_settings_test.dart -x` | Wave 0 |
| RDR-09 | Tablet shows sidebar, phone shows drawer | widget | `flutter test test/widget/reader/responsive_layout_test.dart -x` | Wave 0 |
| RDR-02 | PageView renders chapters, swipe navigates | widget | Part of reader_screen_test.dart | Wave 0 |
| RDR-10 | Chapter tap jumps to correct page | widget | Part of reader_screen_test.dart | Wave 0 |
| RDR-12 | Immersive mode toggles on center tap | widget | Part of reader_screen_test.dart | Wave 0 |
| RDR-07 | Font family change applies | widget | Part of font_settings_test.dart | Wave 0 |
| RDR-08 | Theme change applies | manual-only | Existing theme tests + visual | N/A |

### Sampling Rate
- **Per task commit:** `flutter test test/core/text/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/core/text/sentence_splitter_test.dart` -- covers RDR-04 sentence splitting
- [ ] `test/core/text/sentence_test.dart` -- covers RDR-04 Sentence model
- [ ] `test/widget/reader/block_renderer_test.dart` -- covers RDR-03
- [ ] `test/widget/reader/paragraph_semantics_test.dart` -- covers RDR-05
- [ ] `test/widget/reader/reader_screen_test.dart` -- covers RDR-01, RDR-02, RDR-10, RDR-12
- [ ] `test/widget/reader/font_settings_test.dart` -- covers RDR-06, RDR-07
- [ ] `test/widget/reader/responsive_layout_test.dart` -- covers RDR-09
- [ ] `test/core/db/reading_progress_test.dart` -- covers RDR-11

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A -- no accounts |
| V3 Session Management | No | N/A -- no sessions |
| V4 Access Control | No | N/A -- local-only app |
| V5 Input Validation | Yes | Block IR validated at decode time (existing FormatException gates in block_json.dart) |
| V6 Cryptography | No | N/A for this phase |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malformed blocks_json crashes reader | Tampering | Existing FormatException gates in `blockFromJson()` -- reader wraps in try/catch |
| Oversized chapter exhausts memory | Denial of Service | Phase 2 enforces per-chapter size ceiling upstream |
| EPUB image path traversal | Tampering | Validate extracted image paths are within expected directory before rendering |

## Sources

### Primary (HIGH confidence)
- `lib/core/epub/block.dart` -- Sealed Block hierarchy, 5 variants
- `lib/core/epub/block_json.dart` -- JSON codec with FormatException gates
- `lib/core/db/tables/books_table.dart` -- readingProgressChapter/Offset columns confirmed nullable
- `lib/core/db/tables/chapters_table.dart` -- blocksJson column, bookId FK with CASCADE
- `lib/core/db/app_database.dart` -- Schema v2, no reading progress queries yet
- `lib/features/reader/reader_screen.dart` -- Phase 2 stub to be replaced
- `lib/app/router.dart` -- `/reader/:bookId` route already wired as top-level (hides bottom nav)
- `lib/core/theme/clay_colors.dart` -- LOCKED 4-theme palette
- `lib/core/theme/app_theme.dart` -- `themeFor()` builder, system font for chrome
- `lib/core/theme/theme_mode_provider.dart` -- shared_preferences persistence pattern
- `android/app/build.gradle.kts` -- targetSdk 34 confirmed

### Secondary (MEDIUM confidence)
- [Flutter PageView docs](https://api.flutter.dev/flutter/widgets/PageView-class.html) -- PageView behavior
- [Flutter ScrollPosition docs](https://api.flutter.dev/flutter/widgets/ScrollPosition-class.html) -- hasContentDimensions, maxScrollExtent timing
- [Flutter SystemUiMode docs](https://api.flutter.dev/flutter/services/SystemUiMode.html) -- immersiveSticky behavior, SDK 35+ deprecation
- [Flutter RichText semantics issue](https://github.com/flutter/flutter/issues/129033) -- TextSpan children not merged for accessibility
- [Nested ListView in PageView](https://mak95.medium.com/nested-scrolling-listview-inside-pageview-in-flutter-a57b7a6241b1) -- perpendicular scroll axes work by default

### Tertiary (LOW confidence)
- SentenceSplitter implementation details -- based on general NLP knowledge, not a verified Dart library [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, all packages verified in pubspec.yaml
- Architecture: HIGH -- patterns locked by CONTEXT.md D-01 through D-17, verified against Flutter docs
- Pitfalls: HIGH -- scroll restore, immersive mode, and semantics issues verified via Flutter docs and GitHub issues
- SentenceSplitter: MEDIUM -- basic algorithm is well-understood but implementation details are pseudocode, will be refined by TDD

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable Flutter patterns, no fast-moving dependencies)
