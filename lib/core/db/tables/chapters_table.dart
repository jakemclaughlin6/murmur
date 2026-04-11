import 'package:drift/drift.dart';

import 'books_table.dart';

/// `chapters` table — per D-03 (Phase 02 CONTEXT).
///
/// Each row is one EPUB chapter in spine order, with its Block IR stored
/// inline as a JSON string in [blocksJson]. There is deliberately NO
/// separate `blocks` table — per D-03 the IR round-trips through a single
/// TEXT column so that loading a chapter is one row read, not a per-block
/// join.
///
/// Columns (in order):
/// - [id] — autoincrementing primary key.
/// - [bookId] — FK to `books.id` with `ON DELETE CASCADE` so removing a
///   book removes all of its chapters (Plan 08 persistence test exercises
///   this path).
/// - [orderIndex] — spine order per D-03. EPUB 3 allows a non-default
///   linear ordering; the parser (Plan 04) preserves the `<spine>` order.
/// - [title] — chapter title from `<nav>` / `toc.ncx` when available,
///   nullable because many EPUBs omit per-chapter titles for front-matter.
/// - [blocksJson] — `List<Block>` serialized via `blocksToJsonString()`
///   (see `lib/core/epub/block_json.dart`). Discriminator field values
///   are frozen persistence contract (D-02-02-B).
///
/// Note on bounds (threat T-02-03-02, disposition: accept):
/// SQLite TEXT columns are bounded by `SQLITE_MAX_LENGTH` (~1 GB default).
/// The parser enforces a practical per-chapter size ceiling in Plan 04;
/// this schema cannot express a byte-level CHECK constraint ergonomically
/// via drift_dev so the bound is enforced upstream.
@DataClassName('Chapter')
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer()();
  TextColumn get title => text().nullable()();
  TextColumn get blocksJson => text()();
}
