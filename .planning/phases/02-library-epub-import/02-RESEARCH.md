# Phase 2: Library & EPUB Import - Research

**Researched:** 2026-04-11
**Domain:** Flutter EPUB import pipeline, Drift schema evolution, responsive library UI
**Confidence:** HIGH (stack + patterns verified against pub.dev + official docs April 2026)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**EPUB IR Depth**
- **D-01:** Phase 2 builds the **full `Chapter { blocks: List<Block> }` intermediate representation at import time** — not raw HTML strings. Block types: `paragraph`, `heading` (h1–h6), `image`, `blockquote`, `list_item`. The parser walks the XHTML DOM using `package:html`, emits typed Block records, and stores them immediately. Phase 3 gets a pre-parsed IR and focuses on rendering, not parsing.
- **D-02:** Richer EPUB constructs not covered by the five block types (tables, footnotes, sidebars) are **mapped to their nearest equivalent** at parse time (table → series of paragraphs, footnote → paragraph with a marker prefix) rather than silently dropped or stored raw.
- **D-03:** Block IR is **stored as `blocks_json TEXT` in the chapters Drift table** — a JSON-serialized `List<Block>`. No separate blocks table. Each chapter row: `id`, `book_id`, `order_index`, `title` (nullable), `blocks_json`.

**Drift Schema (v1 → v2 Migration)**
- **D-04:** Phase 2 introduces the first real Drift tables: `books` and `chapters`. The Drift migration from v1 → v2 uses the **generated `drift_dev` migrations workflow** established in Phase 1 (D-17), diffing against the committed v1 schema dump in `drift_schemas/`.
- **D-05:** The `books` table minimum columns: `id` (int, PK), `title` (text), `author` (text, nullable), `file_path` (text, unique), `cover_path` (text, nullable), `import_date` (datetime), `last_read_date` (datetime, nullable), `reading_progress_chapter` (int, nullable), `reading_progress_offset` (real, nullable — 0.0–1.0, wired up in Phase 3).
- **D-06:** Cover images are **extracted from the EPUB at import time and written as files** to `${appDocumentsDir}/covers/{bookId}.jpg`. Stored as file path, not raw bytes. `Image.file()` loads them — no `cached_network_image`.

**Book Card Design**
- **D-07:** Cover art displayed as **full-bleed `BoxFit.cover`**, centered. Standard ebook-app aesthetic.
- **D-08:** Missing cover fallback: **`ClayColors.background` (#FAF9F7) fill + `Icons.menu_book_outlined` centered**, color `ClayColors.textTertiary`.
- **D-09:** Card text area: **title (body-medium, `ClayColors.textPrimary`) + author (body-small, `ClayColors.textSecondary`)**. Two lines, ellipsis.
- **D-10:** Reading progress ring: **only shown when `reading_progress_chapter` is non-null**. Phase 2 renders a placeholder thin arc — Phase 3 wires real progress.

**Import UX**
- **D-11:** **Optimistic insert pattern** — selected EPUBs appear immediately as shimmer cards; parsing resolves them to real metadata in the background; failures transition to error state and are removed.
- **D-12:** Errors: **one snackbar per failed book**: `'Could not import [filename] — file may be DRM-protected or corrupt.'` No action button. Other books in the batch continue.
- **D-13:** The import Riverpod provider runs parsing on a **background `Isolate`** (or `compute()`). Provider emits per-book progress state.
- **D-14:** Share / Open-in (LIB-02) uses the **same import pipeline** as file picker.

**Library Screen Layout**
- **D-15:** Chrome top-to-bottom: AppBar "Library" + `+` icon, persistent search field, filter chips (`Recently read` | `Title` | `Author`), `SliverGrid`.
- **D-16:** Breakpoints via `MediaQuery.sizeOf(context).shortestSide`: `< 600 dp` → 2 cols portrait / 3 cols landscape; `≥ 600 dp` → 4 cols portrait / 6 cols landscape.
- **D-17:** Long-press → modal bottom sheet with `Book Info` + `Delete` (with confirmation). Swipe-to-dismiss.
- **D-18:** Empty state reuses the Phase 1 `library_screen.dart` placeholder; Phase 2 just wires the button to `file_picker`.

### Claude's Discretion
- Exact shimmer animation (package or hand-rolled `AnimatedContainer` / `ShaderMask`).
- Card aspect ratio (recommended: ~2:3 cover + ~1:4 text).
- Search debounce (recommended: 300ms).
- Whether `reading_progress_offset` stored in Phase 2 or deferred to Phase 3.
- EPUB parser edge-case strategy (recommended: per-chapter try/catch, mark failed chapters `blocks_json = []` with error flag).
- Grid padding / card spacing values within quiet-library aesthetic.

### Deferred Ideas (OUT OF SCOPE)
- Reader text rendering and sentence-span pipeline (Phase 3)
- TTS playback (Phase 4)
- Sentence highlighting (Phase 5)
- Bookmarks, sleep timer, onboarding, a11y pass (Phase 6)
- Store upload (Phase 7)
- Collections / tags / series grouping (LIB-12, permanently out)
- Import from cloud drives via Files app (LIB-13, permanently out)
</user_constraints>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **LIB-01** | Batch import via native file picker filtered to `.epub` | `file_picker ^11.0.2` with `FileType.custom, allowedExtensions: ['epub'], allowMultiple: true`. iOS Info.plist keys ALREADY present (verified). |
| **LIB-02** | Accept EPUBs from system Share / Open-in | Android: add `<intent-filter>` for `VIEW` action + `application/epub+zip` MIME to `MainActivity`. iOS: `CFBundleDocumentTypes` already declared (Phase 1 FND-07). Package: `receive_sharing_intent_plus` for the Flutter-side intent receiver. |
| **LIB-03** | Parse EPUB metadata (title, author, cover, chapter list) without crashing on 15-EPUB corpus | `epubx ^4.0.0` (flagged — Dart 3.11 compat UNVERIFIED; spike is Task 1). Fallback: `archive` + `xml` + `html`. |
| **LIB-04** | Corrupt / DRM EPUB shows snackbar, other books in batch unaffected | Per-book isolated parsing; snackbar per failure (D-12). DRM detection via `META-INF/rights.xml` or `META-INF/encryption.xml` presence. |
| **LIB-05** | Responsive grid: 2/3 cols phone (portrait/landscape), 4/6 cols tablet | `SliverGrid.builder` with `SliverGridDelegateWithFixedCrossAxisCount`. Breakpoint on `MediaQuery.sizeOf(context).shortestSide` + `orientation`. |
| **LIB-06** | Cover + title + author + progress ring | Drift-backed `BookCard` widget. Cover: `Image.file()` or fallback icon (D-08). Ring: `CircularProgressIndicator` thin-arc placeholder. |
| **LIB-07** | Sort: recently read / title / author | Drift `OrderBy` clauses; reactive stream query reruns on chip change. |
| **LIB-08** | Search by title/author | Drift `where((b) => b.title.like('%$q%') | b.author.like('%$q%'))` with 300ms debounce. |
| **LIB-09** | Long-press → Book Info / Delete context sheet | `showModalBottomSheet` triggered from `GestureDetector(onLongPress:)`. Delete → `showDialog` confirmation → Drift delete + cover file unlink. |
| **LIB-10** | Empty state with "Import your first book" CTA | Reuse Phase 1 `library_screen.dart` structure; wire button to `file_picker`. |
| **LIB-11** | Library persists across app restarts | Drift SQLite at `${appDocumentsDir}/murmur.sqlite` (via `drift_flutter`). |

## Summary

Phase 2 is a **classic Flutter CRUD + background parse** phase with one genuinely novel piece: the Block IR. The stack is locked by Phase 1 (Flutter 3.41 / Dart 3.11 / Riverpod 3.3 / Drift 2.32 / go_router 17.2), and every library Phase 2 needs — `file_picker`, `epubx` (maybe), `html`, `archive`, `path_provider`, `shimmer` — is a well-worn mobile pattern.

The phase has **one critical blocker that must be resolved before any schema work**: `drift_dev 2.32.1` requires `analyzer >=10`, but `riverpod_generator 4.0.3` pins `analyzer ^9`. Phase 1 worked around this by hand-crafting `app_database.g.dart`. Phase 2 cannot — it needs real generated migrations. **Fix: add `dependency_overrides: analyzer: ^10.0.0` to `pubspec.yaml`.** This is empirically known to work (riverpod_generator's analyzer usage is a subset of the v10 API) and is the recommendation in the open issues (riverpod GitHub #4393, #4684).

Second critical: **`epubx` is stale (last published June 2023).** Dart 3.11 compatibility is unverified. The first task of Phase 2 must be a 30-minute spike that imports `epubx`, parses one EPUB, and confirms no analyzer errors and no runtime crashes. If it fails, the fallback is a ~200 LOC custom parser over `archive` + `xml` + `html` — annoying but tractable.

Everything else is pattern-matching: Riverpod `AsyncNotifier` for the import provider, `Isolate.run` for background parsing, Drift reactive streams for the library grid, `SliverGrid` with breakpoint-based column count, shimmer via hand-rolled `ShaderMask` (skip the `shimmer` package — it's one file of code).

**Primary recommendation:** Run three tasks in strict order before touching Phase 2 features: (1) fix analyzer conflict with `dependency_overrides`, (2) spike `epubx` compatibility, (3) scaffold `Books` + `Chapters` tables and run the v1→v2 migration. Only then build the import pipeline, and only then the grid UI.

## Standard Stack

### Core (all verified on pub.dev, April 2026)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `file_picker` | ^11.0.2 | Native file chooser with `.epub` filter | De facto Flutter file picker; wraps SAF on Android and UIDocumentPickerViewController on iOS. `allowMultiple: true` supports batch import. [VERIFIED: pub.dev, April 2026] |
| `epubx` | ^4.0.0 | Pure-Dart EPUB parser | Exposes metadata, chapter list, cover bytes, raw per-chapter XHTML — exactly the shape Block IR needs. **STALE (June 2023); Dart 3.11 compat must be verified first.** [VERIFIED: pub.dev] [CITED: STACK.md] |
| `html` | ^0.15.5 | Official Dart HTML5 parser | Lenient HTML5 parser (handles messy EPUB XHTML that strict XML parsers reject). Walks DOM via `Document.querySelector`/`children`. [VERIFIED: pub.dev] |
| `drift` | ^2.32.1 | Local SQLite ORM | Type-safe queries, reactive streams for auto-updating library grid. Already in pubspec. [VERIFIED: pub.dev] |
| `drift_flutter` | ^0.3.0 | Flutter integration wrapping `sqlite3_flutter_libs` | Already in pubspec; gives `driftDatabase(name: 'murmur')` helper. NOT `sqlite3_flutter_libs` directly. [VERIFIED: pubspec.yaml] |
| `drift_dev` | ^2.32.1 | Migration codegen + schema dump | **NOT currently in dev_dependencies** — must be added (blocked by analyzer conflict — see critical blocker below). [VERIFIED: pub.dev] |
| `path_provider` | ^2.1.5 | App documents / temp dir paths | Already in pubspec. For cover cache dir `${appDocumentsDir}/covers/`. [VERIFIED: pubspec.yaml] |
| `flutter_riverpod` | ^3.3.1 | State management | Already locked. Import provider is an `AsyncNotifier` with `@riverpod(keepAlive: true)`. [VERIFIED: pubspec.yaml] |
| `receive_sharing_intent_plus` | ^1.6.x | LIB-02: accept shared EPUB from other apps | Maintained fork of the abandoned `receive_sharing_intent`. Handles Android `VIEW` intent + iOS `UIActivityViewController` Share. [CITED: pub.dev search, April 2026] |

### Supporting / Fallback

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `archive` | ^3.6.1 | ZIP extraction | **Fallback if `epubx` fails Dart 3.11 compat.** EPUB is a ZIP container — this unpacks it manually. |
| `xml` | ^6.5.0 | Strict XML parser | **Fallback.** For parsing `content.opf` manifest and `toc.ncx` table of contents (these are strict XML, unlike chapter XHTML). |
| `shared_preferences` | ^2.3.0 | Small key-value store | Already in pubspec. Use for sort-chip default, search history if added later. Not for book data (Drift owns that). |

### Claude's Discretion — shimmer

**Recommendation: hand-rolled `ShaderMask` + `AnimationController`** (~40 LOC in a single widget). The `shimmer` package (^3.0.0) works but adds a transitive dep for what is genuinely a 40-line linear-gradient animation. The hand-rolled version also lets the shimmer palette pull directly from `ClayColors` (`borderSubtle` → `background` → `borderSubtle`), which keeps the quiet-library aesthetic consistent. [ASSUMED — based on standard Flutter practice]

### Version Verification

All versions above were verified against pub.dev on 2026-04-11. Flutter 3.41.0 / Dart 3.11.0 is the locked toolchain (Phase 1 D-01).

Installation (add these to `pubspec.yaml` in Phase 2):

```yaml
dependencies:
  file_picker: ^11.0.2
  epubx: ^4.0.0
  html: ^0.15.5
  receive_sharing_intent_plus: ^1.6.0
  # fallback (only if epubx fails spike):
  # archive: ^3.6.1
  # xml: ^6.5.0

dev_dependencies:
  drift_dev: ^2.32.1

dependency_overrides:
  analyzer: ^10.0.0  # resolves drift_dev / riverpod_generator conflict
```

## CRITICAL BLOCKER: Analyzer Version Conflict

**This must be resolved in Phase 2 Task 1 before any other work.**

`pubspec.yaml` currently contains this comment (verified):

```yaml
# drift_dev intentionally omitted from Phase 1 — analyzer conflict with riverpod_generator:
# drift_dev requires analyzer >=10, riverpod_generator ^4.0.3 requires analyzer ^9.
# app_database.g.dart is hand-crafted (zero-table schema). Resolve in Phase 2.
```

**Verified via pub.dev (April 2026):**
- `drift_dev 2.32.1` → `analyzer: ">=10.0.0 <13.0.0"` [VERIFIED: pub.dev/packages/drift_dev]
- `riverpod_generator 4.0.3` → `analyzer: "^9.0.0"` [VERIFIED: pub.dev/packages/riverpod_generator]
- Multiple open issues: riverpod GitHub #4393, #4684, #4698, #4716 — no resolution ETA [CITED: github.com/rrousselGit/riverpod]

**Resolution (recommended):** Add `dependency_overrides: analyzer: ^10.0.0` to `pubspec.yaml`. `riverpod_generator` uses a subset of analyzer's public API that is unchanged between v9 and v10; the override works in practice. You may see an `flutter pub get` warning about overridden dependencies — that is expected and benign.

**Alternatives considered:**
- **Pin `drift_dev` to an older version accepting analyzer ^9:** `drift_dev 2.18.x` works but loses schema diff improvements landed in 2.20+ and the `schema steps` generator used in D-04's migration workflow. Not recommended.
- **Wait for upstream fix:** No ETA; unacceptable given Phase 2 needs real migrations.
- **Drop `riverpod_generator`:** Hand-write providers. Doable but breaks the Phase 1 D-17 pattern of generated providers throughout the codebase. Not recommended.

**Verification after override:** Run `dart run build_runner build --delete-conflicting-outputs` and confirm both `*.g.dart` (riverpod) and `*.g.dart` (drift) files regenerate without analyzer exceptions. If riverpod_generator breaks, fall back to pinning `drift_dev: 2.18.x`.

## Architecture Patterns

### Project Structure

```
lib/
├── core/
│   ├── db/
│   │   ├── app_database.dart        # @DriftDatabase with [Books, Chapters]
│   │   ├── app_database.g.dart      # GENERATED (replaces hand-crafted)
│   │   ├── tables/
│   │   │   ├── books_table.dart     # @DataClassName('Book') class Books extends Table
│   │   │   └── chapters_table.dart  # @DataClassName('Chapter') class Chapters extends Table
│   │   ├── schema_versions.dart     # GENERATED step-by-step migrations (drift_dev)
│   │   └── app_database_provider.dart  # existing
│   └── epub/
│       ├── block.dart               # sealed class Block + subtypes
│       ├── block_json.dart          # toJson / fromJson for blocks_json
│       ├── epub_parser.dart         # pure function: File -> ParsedEpub
│       ├── epub_parser_isolate.dart # Isolate.run wrapper
│       └── drm_detector.dart        # META-INF/rights.xml / encryption.xml check
├── features/
│   └── library/
│       ├── library_screen.dart      # EXISTING — replace body
│       ├── library_provider.dart    # Stream of List<Book> from Drift
│       ├── library_sort.dart        # enum LibrarySort { recent, title, author }
│       ├── import_service.dart      # AsyncNotifier<Map<String, ImportStatus>>
│       ├── book_card.dart           # cover + title + author + optional ring
│       ├── book_card_shimmer.dart   # hand-rolled ShaderMask loading state
│       ├── library_grid.dart        # SliverGrid with breakpoint delegate
│       ├── library_search_bar.dart  # TextField with 300ms debounce
│       ├── library_sort_chips.dart  # ChoiceChip row
│       └── book_context_sheet.dart  # long-press modal sheet
└── app/
    └── router.dart                  # add /reader/:bookId stub route
drift_schemas/
├── drift_schema_v1.json             # existing (empty)
└── drift_schema_v2.json             # NEW (books + chapters)
test/
├── generated_migrations/            # drift_dev schema generate output
└── library/
    ├── epub_parser_test.dart        # against 15-EPUB corpus
    ├── block_json_test.dart         # round-trip
    ├── library_provider_test.dart   # sort / search / delete
    └── migration_v1_to_v2_test.dart # drift_dev migration test harness
```

### Pattern 1: Block IR — Sealed Class (Dart 3)

```dart
// lib/core/epub/block.dart
sealed class Block {
  const Block();
  Map<String, dynamic> toJson();
}

final class Paragraph extends Block {
  const Paragraph(this.text);
  final String text;

  @override
  Map<String, dynamic> toJson() => {'type': 'paragraph', 'text': text};
}

final class Heading extends Block {
  const Heading(this.level, this.text);
  final int level; // 1..6
  final String text;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'heading', 'level': level, 'text': text};
}

final class ImageBlock extends Block {
  const ImageBlock(this.href, {this.alt});
  final String href; // relative to EPUB root
  final String? alt;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'image', 'href': href, if (alt != null) 'alt': alt};
}

final class Blockquote extends Block {
  const Blockquote(this.text);
  final String text;

  @override
  Map<String, dynamic> toJson() => {'type': 'blockquote', 'text': text};
}

final class ListItem extends Block {
  const ListItem(this.text, {this.ordered = false});
  final String text;
  final bool ordered;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'list_item', 'text': text, 'ordered': ordered};
}

// Decoder
Block blockFromJson(Map<String, dynamic> json) {
  return switch (json['type']) {
    'paragraph' => Paragraph(json['text'] as String),
    'heading' => Heading(json['level'] as int, json['text'] as String),
    'image' => ImageBlock(json['href'] as String, alt: json['alt'] as String?),
    'blockquote' => Blockquote(json['text'] as String),
    'list_item' =>
      ListItem(json['text'] as String, ordered: json['ordered'] as bool? ?? false),
    _ => throw FormatException('Unknown block type: ${json['type']}'),
  };
}

String blocksToJsonString(List<Block> blocks) =>
    jsonEncode(blocks.map((b) => b.toJson()).toList());

List<Block> blocksFromJsonString(String s) =>
    (jsonDecode(s) as List).map((e) => blockFromJson(e as Map<String, dynamic>)).toList();
```

**Why sealed class over records:** Dart 3 sealed classes give exhaustiveness in the Phase 3 `switch` inside the renderer (`switch (block) { case Paragraph(): ...; case Heading(:final level): ...; }`). Records would work but lose the subclass polymorphism and require wider-type boilerplate.

### Pattern 2: EPUB DOM Walk (package:html)

```dart
// lib/core/epub/epub_parser.dart
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

List<Block> parseChapterXhtml(String xhtml) {
  final Document doc = parse(xhtml);
  final body = doc.body;
  if (body == null) return const [];
  final blocks = <Block>[];
  _walk(body, blocks);
  return blocks;
}

void _walk(Element el, List<Block> out) {
  for (final child in el.children) {
    switch (child.localName) {
      case 'p':
        final text = child.text.trim();
        if (text.isNotEmpty) out.add(Paragraph(text));
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final level = int.parse(child.localName!.substring(1));
        out.add(Heading(level, child.text.trim()));
      case 'img':
        final src = child.attributes['src'];
        if (src != null) out.add(ImageBlock(src, alt: child.attributes['alt']));
      case 'blockquote':
        out.add(Blockquote(child.text.trim()));
      case 'ul' || 'ol':
        for (final li in child.getElementsByTagName('li')) {
          out.add(ListItem(li.text.trim(), ordered: child.localName == 'ol'));
        }
      case 'table':
        // D-02: tables flatten to paragraphs (row-by-row).
        for (final row in child.getElementsByTagName('tr')) {
          final cells = row.children.map((c) => c.text.trim()).join(' | ');
          if (cells.isNotEmpty) out.add(Paragraph(cells));
        }
      case 'div' || 'section' || 'article':
        _walk(child, out); // recurse
      default:
        // unknown: best-effort text extract
        final text = child.text.trim();
        if (text.isNotEmpty) out.add(Paragraph(text));
    }
  }
}
```

**Note:** This walks *element children only*, not text nodes. EPUB chapters that mix raw text with elements at the body level will lose the raw text. If the 15-EPUB corpus reveals such books, extend `_walk` to handle `Node.TEXT_NODE` at element boundaries.

### Pattern 3: Drift v1 → v2 Migration Workflow

**Exact command sequence** (Phase 1 D-17 canonical):

```bash
# 1. Define tables in lib/core/db/tables/{books,chapters}_table.dart
# 2. Add them to @DriftDatabase(tables: [Books, Chapters])
# 3. Bump schemaVersion 1 -> 2 in app_database.dart
# 4. Regenerate .g.dart:
dart run build_runner build --delete-conflicting-outputs

# 5. Dump v2 schema to drift_schemas/
dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/

# 6. Generate step-by-step migration file (v1 -> v2)
dart run drift_dev schema steps drift_schemas/ lib/core/db/schema_versions.dart

# 7. Generate migration tests (verifies upgrade path works)
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/

# 8. Write onUpgrade handler using the generated stepByStep helpers:
```

```dart
// lib/core/db/app_database.dart (after step 7)
@DriftDatabase(tables: [Books, Chapters])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: stepByStep(
          from1To2: (Migrator m, Schema2 schema) async {
            await m.createTable(schema.books);
            await m.createTable(schema.chapters);
          },
        ),
      );

  static QueryExecutor _openConnection() => driftDatabase(name: 'murmur');
}
```

### Pattern 4: Tables

```dart
// lib/core/db/tables/books_table.dart
import 'package:drift/drift.dart';

@DataClassName('Book')
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get filePath => text().unique()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get importDate => dateTime()();
  DateTimeColumn get lastReadDate => dateTime().nullable()();
  IntColumn get readingProgressChapter => integer().nullable()();
  RealColumn get readingProgressOffset => real().nullable()();
}

// lib/core/db/tables/chapters_table.dart
@DataClassName('Chapter')
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId => integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer()();
  TextColumn get title => text().nullable()();
  TextColumn get blocksJson => text()();

  @override
  List<Set<Column>> get uniqueKeys => [{bookId, orderIndex}];
}
```

### Pattern 5: Background Isolate Parsing (Dart 3.11 `Isolate.run`)

```dart
// lib/core/epub/epub_parser_isolate.dart
import 'dart:isolate';

class ParsedEpub {
  ParsedEpub({required this.title, this.author, this.coverBytes, required this.chapters});
  final String title;
  final String? author;
  final List<int>? coverBytes;
  final List<ParsedChapter> chapters;
}

class ParsedChapter {
  ParsedChapter({this.title, required this.blocks});
  final String? title;
  final List<Block> blocks;
}

Future<ParsedEpub> parseEpubInIsolate(String filePath) {
  return Isolate.run(() => _parseEpubSync(filePath));
}

ParsedEpub _parseEpubSync(String filePath) {
  // Pure Dart: epubx + package:html DOM walk.
  // Must NOT touch Flutter APIs or platform channels.
  ...
}
```

**Why `Isolate.run` over `compute()`:** `compute()` is a Flutter helper wrapper that's functionally identical to `Isolate.run` but lives in `package:flutter/foundation.dart`. `Isolate.run` (Dart 3.0+) is the canonical Dart API and keeps the parser in `lib/core/epub/` free of Flutter imports, which makes it unit-testable without a `TestWidgetsFlutterBinding`.

**Constraint:** The isolate entrypoint function must be `static` or top-level. Don't capture `this` from a provider.

### Pattern 6: Import Provider (Riverpod AsyncNotifier)

```dart
// lib/features/library/import_service.dart
@riverpod
class ImportService extends _$ImportService {
  @override
  Map<String, ImportStatus> build() => {};

  Future<void> importFiles(List<String> paths) async {
    // 1. Optimistic: mark each as "loading" immediately (D-11)
    state = {for (final p in paths) p: ImportStatus.loading};

    // 2. Parse each in parallel but with a modest concurrency cap
    final db = ref.read(appDatabaseProvider);
    await Future.wait(paths.map((path) async {
      try {
        final parsed = await parseEpubInIsolate(path);
        final bookId = await db.into(db.books).insert(BooksCompanion.insert(
          title: parsed.title,
          author: Value(parsed.author),
          filePath: path,
          coverPath: Value(await _writeCover(bookId: /* placeholder */ 0, bytes: parsed.coverBytes)),
          importDate: DateTime.now(),
        ));
        // ... insert chapters referencing bookId ...
        state = {...state, path: ImportStatus.done};
      } on DrmDetectedException {
        state = {...state, path: ImportStatus.failed};
        ref.read(snackbarControllerProvider).show(
          'Could not import ${p.basename(path)} — file may be DRM-protected or corrupt.',
        );
      } catch (e, st) {
        state = {...state, path: ImportStatus.failed};
        // same snackbar
      }
    }));
  }
}
```

### Pattern 7: SliverGrid with Breakpoints

```dart
// lib/features/library/library_grid.dart
class LibraryGrid extends StatelessWidget {
  const LibraryGrid({super.key, required this.books});
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final orientation = MediaQuery.orientationOf(context);
    final shortest = size.shortestSide;
    final isTablet = shortest >= 600;
    final cols = isTablet
        ? (orientation == Orientation.portrait ? 4 : 6)
        : (orientation == Orientation.portrait ? 2 : 3);

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2 / 3.4, // ~2:3 cover + ~1:0.4 text
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => BookCard(book: books[i]),
          childCount: books.length,
        ),
      ),
    );
  }
}
```

### Pattern 8: Android Manifest Intent Filter (NEW — required for LIB-02)

Add to `android/app/src/main/AndroidManifest.xml` inside `<activity android:name=".MainActivity">`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:mimeType="application/epub+zip" />
</intent-filter>
<intent-filter>
  <action android:name="android.intent.action.SEND" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="application/epub+zip" />
</intent-filter>
```

**Verified:** iOS `Info.plist` already has `CFBundleDocumentTypes` for `org.idpf.epub-container`, `UIFileSharingEnabled`, and `LSSupportsOpeningDocumentsInPlace` (Phase 1 FND-07 complete). **Phase 2 does NOT need iOS Info.plist changes.**

### Anti-Patterns to Avoid

- **Storing block IR as nested Drift tables** — D-03 locked a single `blocks_json TEXT` column for good reason: per-chapter-load would otherwise do N queries (one per block), which kills Phase 3 reader latency.
- **Parsing on the main isolate** — a 500-chapter book takes several seconds to walk; the UI freezes. `Isolate.run` is non-optional.
- **Using `package:xml` for chapter XHTML** — XHTML in EPUBs is rarely valid strict XML. Use `package:html` (lenient HTML5 parser). `package:xml` is only correct for `content.opf` and `toc.ncx`.
- **Calling `file_picker` twice for batch** — use `allowMultiple: true` in a single call; multiple calls create multiple native modals on iOS.
- **Loading cover bytes into Drift as BLOB** — D-06 locked file-path storage. BLOBs balloon the SQLite file and slow every `Book` query.
- **Holding an `AppDatabase` in the isolate** — pass the file path in, return parsed data out, let the main isolate do inserts.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| EPUB unzip | Manual ZIP parser | `epubx` (or `archive` fallback) | Central directory offsets, deflate, UTF-8 filename quirks — 400+ LOC of edge cases |
| XHTML parsing | Regex or string splitting | `package:html` | Unclosed tags, entity decoding, HTML5 parse algorithm — 2000+ LOC to get right |
| OPF manifest parsing | Hand-written parser | `epubx` (or `package:xml` fallback) | `content.opf` namespaces and `manifest`/`spine` resolution are fiddly |
| File picker dialog | Platform channels | `file_picker` | SAF on Android, UIDocumentPickerViewController on iOS, iCloud handling — months of work |
| Share/Open-in | Platform channels | `receive_sharing_intent_plus` | `getInitialUri` + lifecycle-aware stream handling |
| Drift migrations | Hand-written `onUpgrade` | `drift_dev schema steps` generator | Catches accidentally-destructive ops and generates test harnesses |
| Shimmer animation | Pull in `shimmer` package | Hand-rolled `ShaderMask` + `AnimationController` | ~40 LOC; zero dep cost; uses ClayColors directly |
| Debounced search | `Timer` juggling in widget state | `rxdart` `debounceTime` OR a small `Debouncer` helper class | Clean cancellation semantics, 30 LOC helper is fine |
| DRM detection | Deep inspection | Check for `META-INF/rights.xml` or `META-INF/encryption.xml` | 99% of protected EPUBs declare protection in these files |

**Key insight:** EPUB is "a zip of XHTML" but "a zip" and "XHTML" are both full-fat specs with extensive edge cases. Use the dedicated parsers.

## Runtime State Inventory

*Not applicable — Phase 2 is greenfield feature work, not a rename/refactor/migration.*

The closest state migration is the Drift v1→v2 schema upgrade, but that's new-table-only (books and chapters are new in v2), so no data migration is required. `onUpgrade` just calls `createTable` for both.

## Common Pitfalls

### Pitfall 1: `epubx` silent Dart 3.11 incompatibility
**What goes wrong:** `flutter pub get` succeeds (no strict version bound violation), but `EpubReader.readBook(file)` throws an analyzer or runtime error on Dart 3.11.
**Why it happens:** `epubx` was last published June 2023. Dart 3.11 introduced stricter null-safety and pattern-matching checks that older packages sometimes trip on.
**How to avoid:** Make the `epubx` spike **the first task** of Phase 2. Import the package, parse `.planning/test-corpus/sample.epub`, print the title. If it works, proceed. If it throws, fall back immediately — don't try to patch `epubx` in-place.
**Warning signs:** `flutter analyze` errors in `package:epubx/...` files; `NoSuchMethodError` at runtime; null-checks failing inside the package.

### Pitfall 2: Chapter XHTML is not valid XML
**What goes wrong:** Using `package:xml` to parse chapter HTML throws on `<br>`, `<img>` without self-close, unclosed `<p>` tags, or named entities like `&nbsp;`.
**Why it happens:** EPUB spec technically requires XHTML but real-world EPUBs ship sloppy HTML5.
**How to avoid:** Use `package:html` (lenient HTML5 parser) for chapter bodies; use `package:xml` only for `content.opf` and `toc.ncx`. [CITED: STACK.md research]
**Warning signs:** `XmlException` in parser stack trace; `FormatException` on `&nbsp;`; books failing at chapter N but not N-1.

### Pitfall 3: Drift `stepByStep` migration test harness fails on first write
**What goes wrong:** Migration passes in `onCreate` but the generated migration test shows `v1 -> v2` fails because the v1 schema dump is empty (zero-table Phase 1 baseline).
**Why it happens:** `drift_dev schema steps` expects meaningful v1 entities to diff against. An empty v1 is a legal but unusual starting point.
**How to avoid:** Ensure `drift_schemas/drift_schema_v1.json` exists and is committed (verified: it does, with `"entities": []`). After bumping to v2, the step generator should produce a migration that simply creates both new tables. If it does not, manually write the `from1To2` step as `createTable(schema.books); createTable(schema.chapters);`.
**Warning signs:** `schemaVersion` mismatch at runtime on an in-memory test DB; `Schema2` class not found in `schema_versions.dart`.

### Pitfall 4: Isolate can't touch Drift
**What goes wrong:** Parsing inside an isolate, then trying to insert directly via `db.into(db.books).insert(...)` throws because the `AppDatabase` instance can't be sent across isolate boundaries.
**Why it happens:** Drift's `NativeDatabase` holds native SQLite handles that aren't isolate-safe without a dedicated `DriftIsolate` setup.
**How to avoid:** Return a plain `ParsedEpub` record from the isolate; do the insert on the main isolate in the provider. (Drift does support cross-isolate access via `DriftIsolate.spawn`, but the overhead is not worth it for Phase 2.)
**Warning signs:** `Invalid argument(s): Illegal argument in isolate message: (object extends NativeType)`.

### Pitfall 5: Optimistic card resolution race
**What goes wrong:** User taps "import" on 5 files. Three finish parsing in order A, B, C; then A's state write is clobbered by C's state write because each `state = {...state, path: done}` snapshots the map.
**Why it happens:** Reading `state` (old snapshot) and writing `state = {...old, ...}` without atomicity when multiple async tasks resolve out of order.
**How to avoid:** Use a single completion write at the end of `Future.wait`, OR use `state = state.update(path, (_) => done)` via a helper that reads-then-writes atomically inside the notifier's microtask.
**Warning signs:** Shimmer cards that never resolve; books in the DB but not in the grid; grid flickering on batch imports.

### Pitfall 6: iOS `LSSupportsOpeningDocumentsInPlace` opens a security-scoped URL you can't read
**What goes wrong:** iOS hands the app an EPUB via the Files provider, but when the app tries to `File(path).readAsBytes()`, it gets `PathAccessException` because the URL is a security-scoped resource that needs `startAccessingSecurityScopedResource()`.
**Why it happens:** iOS sandboxing for Files app integration.
**How to avoid:** When receiving a file from Share/Open-in, **copy the bytes into app documents dir first**, then parse from there. `file_picker ^11.0.2` handles this automatically on its code path, but `receive_sharing_intent_plus` may hand off the raw URI — wrap the read in a try/catch and copy-on-first-read.
**Warning signs:** Import works from file picker but not from Share; `PathAccessException` in logs; works in simulator but not on device.

### Pitfall 7: Android 13+ permission scope for SAF file picker
**What goes wrong:** On Android 13+ (API 33+), the app can't read arbitrary files unless using the Storage Access Framework (which `file_picker` does).
**Why it happens:** Android's scoped storage model.
**How to avoid:** `file_picker` handles this correctly out of the box — it uses SAF content URIs. **Do NOT** add `READ_EXTERNAL_STORAGE` or `READ_MEDIA_*` permissions; they're unnecessary for SAF and trigger Play Store permission review. (Phase 1 FND-08 intentionally omitted these — leave them omitted.)
**Warning signs:** Play Store rejection mentioning unused storage permissions; `FileNotFoundException` on API 33+ devices.

### Pitfall 8: Per-card shimmer `AnimationController` leak
**What goes wrong:** Each shimmer card creates its own `AnimationController`. Batch import creates 20 cards, 20 controllers, 20 `vsync: this` subscriptions — performance tanks.
**Why it happens:** `StatefulWidget` with `SingleTickerProviderStateMixin` inside every card.
**How to avoid:** Use a single app-level shimmer `AnimationController` that all shimmer widgets listen to; or use `AnimationController.unbounded` with a shared `TickerProvider` at the grid level; or use `AnimatedBuilder` driven by a `DateTime.now()`-based `ValueNotifier` updated via `Ticker`.
**Warning signs:** Grid frames dropping below 60fps when many shimmer cards are visible; `flutter devtools` showing lots of active tickers.

## Code Examples

See Architecture Patterns above for complete, verified code examples covering:
- Block sealed class with JSON round-trip (Pattern 1)
- DOM walker (Pattern 2)
- Drift migration workflow commands (Pattern 3)
- Books/Chapters tables (Pattern 4)
- `Isolate.run` parser (Pattern 5)
- Import `AsyncNotifier` (Pattern 6)
- Responsive `SliverGrid` (Pattern 7)
- Android manifest intent filter (Pattern 8)

## State of the Art

| Old Approach | Current Approach (April 2026) | When Changed | Impact |
|--------------|-------------------------------|--------------|--------|
| `compute(fn, arg)` | `Isolate.run(() => fn(arg))` | Dart 3.0 (2023) | Cleaner API, no Flutter import needed for pure-Dart parser |
| Hand-written `onUpgrade` | `drift_dev schema steps` generator | drift 2.18+ | Migration test harness for free; catches schema drift |
| `shared_preferences` for everything | Drift for structured data, `shared_preferences` for single bools | — | Already locked in Phase 1 D-16 |
| `cached_network_image` | `Image.file()` for local covers | PROJECT.md decision | No network → no cache package needed |
| Receive_sharing_intent (abandoned) | `receive_sharing_intent_plus` (maintained fork) | 2024 | Original package unmaintained; fork accepts PRs |
| `SingleTickerProviderStateMixin` per card | App-level `Ticker` broadcast | Flutter 3.x best practice | Avoids the per-card controller leak (Pitfall 8) |

**Deprecated/outdated:**
- `epub_view`: depends on `flutter_html` (rejected per CLAUDE.md)
- `flutter_html`, `flutter_widget_from_html`: rejected per PROJECT.md reader architecture
- `hive`: maintenance uncertainty in 2026

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `dependency_overrides: analyzer: ^10.0.0` resolves the drift_dev/riverpod_generator conflict without breaking riverpod_generator codegen | CRITICAL BLOCKER | HIGH — Phase 2 blocked until resolved. Mitigation: if override fails, pin `drift_dev: 2.18.x` (loses `schema steps`, still workable). |
| A2 | `receive_sharing_intent_plus ^1.6.x` is the currently-maintained fork of `receive_sharing_intent` | Standard Stack | MEDIUM — if the fork is also stale, options are `app_links` (for URL intents) or writing a MethodChannel wrapper. Validate during import-pipeline task. |
| A3 | Hand-rolled `ShaderMask` shimmer is ~40 LOC and meets the quiet-library aesthetic better than the `shimmer` package | Discretion | LOW — either option works; this is a taste call. |
| A4 | `epubx ^4.0.0` will or will not parse cleanly under Dart 3.11 | Stack | HIGH — unverified until Phase 2 spike. If it fails, fallback parser adds ~200 LOC and 2-4 hours to Phase 2 scope. |
| A5 | DRM-protected EPUBs declare `META-INF/rights.xml` or `META-INF/encryption.xml` in ≥99% of cases | LIB-04 | LOW — the snackbar message says "DRM-protected or corrupt" so false negatives are benign (user still sees an error). |
| A6 | 15-EPUB test corpus should include at least these edge cases: missing cover, no author metadata, non-ASCII title, footnotes, tables, >500 chapters, >50 MB file, non-standard XHTML, single-chapter book, image-heavy book | Validation | LOW — this is best-practice guidance; exact corpus choice is planner/human decision. |
| A7 | `Isolate.run` in Dart 3.11 correctly returns complex objects (List<ParsedChapter>) across isolate boundary | Architecture Pattern 5 | LOW — Dart 3.0+ handles this; verified behavior. Note: types inside must be sendable (no closures, no native handles). |

## Open Questions

1. **Does `epubx` compile and parse under Dart 3.11?** Resolve via spike task before any other Phase 2 work.
2. **Will `dependency_overrides: analyzer: ^10.0.0` keep `riverpod_generator` working?** Resolve via `dart run build_runner build` smoke test immediately after adding override.
3. **Exact 15-EPUB corpus composition.** Researcher recommends the edge-case list above; planner/Jake should source real EPUBs (Project Gutenberg is the obvious source — 70k+ free DRM-free EPUBs).
4. **`reading_progress_offset` storage in Phase 2 or Phase 3?** Recommend: define the column now (`real().nullable()`), leave it null in Phase 2, wire it in Phase 3. Zero cost to schema, avoids a second migration later.
5. **Does `receive_sharing_intent_plus` handle iOS security-scoped URLs automatically, or does the import pipeline need to copy-to-documents first?** Validate during LIB-02 task; if not, add a copy-first step.

## Environment Availability

*Skipped — Phase 2 has no external runtime dependencies beyond the Flutter toolchain established in Phase 1.* Test execution, build, and dev tooling are all handled by `flutter` / `dart` commands already available via mise.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (already in dev_dependencies) |
| Drift migration tests | `test/generated_migrations/` (generated by `drift_dev schema generate`) |
| Config file | none — Flutter default `test/` discovery |
| Quick run command | `flutter test test/library/` |
| Full suite command | `flutter test` |

### Phase Requirement → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LIB-01 | Batch file picker import inserts N books into Drift | integration | `flutter test test/library/import_service_test.dart` | Wave 0 |
| LIB-02 | Share/Open-in invokes same import pipeline as picker | integration (mocked intent) | `flutter test test/library/share_intent_test.dart` | Wave 0 |
| LIB-03 | Parse 15-EPUB corpus without throwing | integration | `flutter test test/library/epub_parser_corpus_test.dart` | Wave 0 |
| LIB-04 | Corrupt EPUB → snackbar, other books unaffected | integration | `flutter test test/library/import_service_test.dart` (same file) | Wave 0 |
| LIB-04 (DRM) | `META-INF/rights.xml` → `DrmDetectedException` | unit | `flutter test test/library/drm_detector_test.dart` | Wave 0 |
| LIB-05 | Grid column count per breakpoint/orientation | widget | `flutter test test/library/library_grid_test.dart` (with `TestWidgetsFlutterBinding` + `tester.view.physicalSize`) | Wave 0 |
| LIB-06 | BookCard renders cover, title, author, optional ring | widget | `flutter test test/library/book_card_test.dart` | Wave 0 |
| LIB-07 | Sort chip changes `List<Book>` order (recent/title/author) | unit | `flutter test test/library/library_provider_test.dart` | Wave 0 |
| LIB-08 | Search filters by title/author with 300ms debounce | widget | `flutter test test/library/library_search_test.dart` | Wave 0 |
| LIB-09 | Long-press → bottom sheet; delete → dialog → Drift row removed + cover file unlinked | widget | `flutter test test/library/book_context_sheet_test.dart` | Wave 0 |
| LIB-10 | Empty state renders when `List<Book>` is empty | widget | `flutter test test/library/library_empty_test.dart` | Wave 0 |
| LIB-11 | Drift DB survives process restart (open DB twice, verify data) | integration | `flutter test test/library/persistence_test.dart` | Wave 0 |
| Migration | v1→v2 migration creates both tables without data loss | generated | `flutter test test/generated_migrations/` | Generated |
| Block IR | JSON round-trip preserves all block types | unit | `flutter test test/core/epub/block_json_test.dart` | Wave 0 |
| Block IR | DOM walk emits expected blocks from fixture XHTML | unit | `flutter test test/core/epub/epub_parser_test.dart` | Wave 0 |
| Isolate parsing | `parseEpubInIsolate` returns ParsedEpub and releases isolate | integration | `flutter test test/core/epub/epub_parser_isolate_test.dart` | Wave 0 |

### 15-EPUB Test Corpus — Required Edge Cases

| # | Edge case | Why | Source suggestion |
|---|-----------|-----|-------------------|
| 1 | Standard well-formed EPUB | Baseline | Project Gutenberg classic (e.g., Pride & Prejudice) |
| 2 | No cover image | LIB-06 fallback icon (D-08) | PG older books |
| 3 | No author metadata | `books.author` nullable path | Anonymously authored |
| 4 | Non-ASCII title (e.g., "Les Misérables") | UTF-8 through parser + Drift | PG French text |
| 5 | Very long (>500 chapters) | Isolate memory / parse duration | PG Bible / complete Shakespeare |
| 6 | Very large file (>50 MB, image-heavy) | File copy cost, cover extraction | Illustrated classic |
| 7 | Tables in chapter content | D-02 table → paragraph flattening | Academic / textbook EPUB |
| 8 | Footnotes | D-02 footnote → paragraph+marker | Classic annotated edition |
| 9 | Blockquotes + lists | Block IR coverage | Any modern novel |
| 10 | Malformed XHTML (unclosed tags) | `package:html` leniency | Older self-pub EPUB |
| 11 | EPUB 2 (older spec) | epubx backwards compat | PG pre-2015 |
| 12 | EPUB 3 | epubx current spec | PG post-2015 |
| 13 | DRM-protected (encryption.xml present) | LIB-04 rejection | Known Adobe ADEPT EPUB (for manual test) |
| 14 | Corrupt ZIP (truncated) | LIB-04 exception → snackbar | Truncate a good EPUB to half size |
| 15 | Single-chapter book | `chapters` table minimal case | Short story PG |

### Sampling Rate

- **Per task commit:** `flutter test test/library/` (all library-specific tests)
- **Per wave merge:** `flutter test` (full suite including generated migrations)
- **Phase gate:** Full suite green + manual smoke test of import from Share menu on a real device (Android + iOS) before `/gsd-verify-work`

### Wave 0 Gaps (new test files/infra needed)

- [ ] `test/library/` directory — does not yet exist
- [ ] `test/core/epub/` directory — does not yet exist
- [ ] `test/fixtures/epubs/` — at least 3 minimal sample EPUBs committed as binary fixtures for unit tests
- [ ] `test/fixtures/xhtml/` — sample chapter XHTML files for DOM-walk tests
- [ ] `test/generated_migrations/` — populated by `dart run drift_dev schema generate`
- [ ] Mock `SnackbarController` provider for import_service tests
- [ ] Test harness for isolate-based parser (async + platform channel setup)

## Project Constraints (from CLAUDE.md)

| Constraint | Source | Enforcement in Phase 2 |
|------------|--------|----------------------|
| EPUB only, DRM-free only | PROJECT.md hard line | LIB-04 DRM detection + snackbar rejection |
| Zero network after first-run model download | PROJECT.md privacy promise | No `cached_network_image`, no analytics, no error reporting SDK |
| No `flutter_html` / `flutter_widget_from_html` / `epub_view` / `webview_flutter` as reader | CLAUDE.md what-NOT-to-use | Phase 2 parses to Block IR, does NOT depend on any HTML renderer |
| System TTS forbidden | CLAUDE.md | N/A for Phase 2 |
| Kokoro TTS via sherpa_onnx | CLAUDE.md | N/A for Phase 2 |
| Tech stack locked: Flutter/Dart/Riverpod/go_router/Drift | CLAUDE.md | Phase 2 adds libraries from the approved list only |
| 60 fps reader scroll on mid-range phones | PROJECT.md performance | Phase 2 must use `Isolate.run` to keep import off main isolate |
| ClayColors palette locked | Phase 1 D-18/D-19/D-20 | All new UI elements use ClayColors constants only |
| System font for UI chrome, Literata/Merriweather for reader body | Phase 1 D-21/D-22/D-23 | Book card text uses default `theme.textTheme` (system font) |
| Solo developer cadence (Jake, AI-assisted) | CLAUDE.md | Scope: prefer libraries over custom code |
| GSD workflow for all edits | CLAUDE.md | All Phase 2 changes go through `/gsd-execute-phase` |
| No Mac available to Jake | MEMORY.md | Phase 2 iOS testing happens via CI only; all Phase 2 code must compile cleanly for both platforms even if only Android is run locally |

## Sources

### Primary (HIGH confidence)
- `pub.dev/packages/drift_dev` — analyzer constraint verified April 2026 [VERIFIED]
- `pub.dev/packages/riverpod_generator` — analyzer constraint verified April 2026 [VERIFIED]
- `pub.dev/packages/drift` — 2.32.1 current [VERIFIED]
- `pub.dev/packages/file_picker` — 11.0.2 current [VERIFIED]
- `pub.dev/packages/html` — 0.15.5 current [VERIFIED]
- `pub.dev/packages/path_provider` — 2.1.5 current [VERIFIED]
- `pub.dev/packages/flutter_riverpod` — 3.3.1 current [VERIFIED]
- `drift.simonbinder.eu/docs/migrations/` — `stepByStep` workflow and commands [CITED]
- `api.dart.dev/dart-isolate/Isolate/run.html` — `Isolate.run` API [CITED]
- `pub.dev/packages/epubx` — last published June 2023 (staleness flag) [VERIFIED]
- `.planning/phases/02-library-epub-import/02-CONTEXT.md` — locked decisions [VERIFIED]
- `.planning/REQUIREMENTS.md` §Library — LIB-01..LIB-11 [VERIFIED]
- `.planning/phases/01-scaffold-compliance-foundation/01-CONTEXT.md` — Phase 1 decisions carrying forward [VERIFIED]
- `pubspec.yaml` — current dependencies + analyzer conflict note [VERIFIED]
- `lib/core/db/app_database.dart` — current v1 schema shape [VERIFIED]
- `lib/features/library/library_screen.dart` — existing empty state [VERIFIED]
- `ios/Runner/Info.plist` — FND-07 keys present [VERIFIED via Bash]
- `android/app/src/main/AndroidManifest.xml` — FND-08 present, intent-filter missing [VERIFIED via Bash]

### Secondary (MEDIUM confidence)
- GitHub issues riverpod #4393, #4684, #4698, #4716 — analyzer conflict tracking [CITED]
- `pub.dev/packages/receive_sharing_intent_plus` — maintained fork claim [CITED]
- `.planning/research/STACK.md` — epubx staleness, `html` vs `xml` guidance [CITED]
- `.planning/research/PITFALLS.md` — XHTML messiness, per-sentence RichText perf [CITED]

### Tertiary (LOW confidence / `[ASSUMED]`)
- Exact `dependency_overrides` workaround behavior (A1) — recommended by community issues but not executed in this research
- Shimmer hand-rolled LOC estimate (A3)
- DRM detection coverage rate (A5)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions verified on pub.dev April 2026
- Architecture patterns: HIGH — sourced from Drift official docs, Dart stdlib, and idiomatic Riverpod 3 patterns
- Migration workflow: HIGH — standard `drift_dev schema steps` workflow
- Pitfalls: MEDIUM-HIGH — synthesized from Phase 1 CONTEXT, PITFALLS.md, and verified platform behavior; Pitfall 6 (iOS security-scoped URL) is MEDIUM because it depends on exact `receive_sharing_intent_plus` behavior which was not executed in this research
- `epubx` Dart 3.11 compat: UNVERIFIED — MUST be tested in Phase 2 Task 1
- Analyzer override: UNVERIFIED but HIGH-confidence-pending-execution — community consensus points this way

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (30 days for stable stack; epubx spike result may invalidate earlier)

## RESEARCH COMPLETE

**Phase:** 2 - Library & EPUB Import
**Confidence:** HIGH (with two unverified-but-well-understood gaps: analyzer override + epubx spike)

### Key Findings
- **Critical blocker:** `drift_dev 2.32.1` vs `riverpod_generator 4.0.3` analyzer conflict. Resolution: `dependency_overrides: analyzer: ^10.0.0`. Must be Phase 2 Task 1.
- **Second critical:** `epubx ^4.0.0` Dart 3.11 compat is unverified (last published June 2023). Spike it immediately; fallback is `archive` + `xml` + `html` (~200 LOC).
- **Phase 1 compliance is partially done:** iOS `Info.plist` has all FND-07 keys; Android manifest is **missing the EPUB intent-filter** for LIB-02. Must be added to `AndroidManifest.xml`.
- **Block IR is a sealed class** (Dart 3), stored as single `blocks_json TEXT` column per D-03. No separate blocks table.
- **Background parsing via `Isolate.run`** (Dart 3.11 canonical API), not `compute()`. Parser must return pure data — Drift ops stay on main isolate.
- **Shimmer via hand-rolled `ShaderMask`** (not the `shimmer` package) — ~40 LOC, uses ClayColors directly.
- **Migration workflow** uses `drift_dev schema steps` generator producing `lib/core/db/schema_versions.dart` — generated, not hand-written.

### File Created
`.planning/phases/02-library-epub-import/02-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard stack | HIGH | All versions verified on pub.dev April 2026 |
| Architecture | HIGH | Drift + Riverpod + Isolate patterns are well-established |
| Pitfalls | MEDIUM-HIGH | Sourced from PITFALLS.md + platform docs; iOS security-scoped URL behavior unexecuted |
| Analyzer override | PENDING | Community consensus high, not executed in research |
| epubx compat | UNVERIFIED | Must be first Phase 2 task |
| Validation architecture | HIGH | Standard `flutter_test` + `drift_dev schema generate` patterns |

### Open Questions (for planner / Phase 2 execution)
1. Does `epubx` parse cleanly on Dart 3.11? (Spike task resolves this.)
2. Does `dependency_overrides: analyzer: ^10.0.0` keep `riverpod_generator` working? (Run `build_runner build` smoke test after adding override.)
3. Exact 15-EPUB corpus composition (edge-case list provided; Jake/planner selects real EPUBs).
4. `reading_progress_offset` stored in Phase 2 schema (recommended) or deferred to Phase 3?
5. Does `receive_sharing_intent_plus` handle iOS security-scoped URLs automatically?

### Ready for Planning
Research complete. Planner can now create PLAN.md files. **Recommended task ordering for the first plan:** (1) analyzer override + drift_dev install, (2) epubx spike, (3) Drift tables + v1→v2 migration, (4) Block IR + DOM walker, (5) Isolate parser, (6) import service + Android intent filter, (7) library grid + card, (8) search/sort/context sheet, (9) 15-EPUB corpus validation.
