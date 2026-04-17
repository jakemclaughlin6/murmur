import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'schema_versions.dart';
import 'tables/books_table.dart';
import 'tables/chapters_table.dart';

part 'app_database.g.dart';

/// Phase 2 schema v2: `books` + `chapters` tables per D-03, D-04, D-05.
///
/// Migration strategy (per D-04 — drift_dev `stepByStep` workflow is LOCKED):
/// - Fresh installs start at schemaVersion=2 via [MigrationStrategy.onCreate]
///   calling `m.createAll()`, which picks up both tables.
/// - v1→v2 upgrades (users who opened Phase 1 builds at schemaVersion=1
///   with zero user tables) run the generated `stepByStep` handler wired
///   below. The `from1To2` closure receives the generated [Schema2]
///   versioned view of the tables so `createTable` sees the schema as it
///   existed at v2 — not as the current Dart table classes describe it.
///   This is what protects the migration from schema drift when Phase 3+
///   bumps to v3, v4, ….
///
/// Database file location: `${appDocumentsDir}/murmur.db`
/// (handled automatically by `drift_flutter`'s `driftDatabase` helper).
@DriftDatabase(tables: [Books, Chapters])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

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
          from2To3: (Migrator m, Schema3 schema) async {
            await m.addColumn(schema.books, schema.books.voiceId);
            await m.addColumn(schema.books, schema.books.playbackSpeed);
          },
        ),
        // SQLite ships with foreign-key enforcement disabled by default.
        // Drift's idiomatic place to turn it on is `beforeOpen` — the
        // pragma must be re-issued on every connection because it is a
        // per-connection setting. Without this, the `ON DELETE CASCADE`
        // declared on `chapters.book_id` is ignored: deleting a book
        // leaves orphan chapter rows behind, which breaks the Plan 08
        // persistence guarantee and silently corrupts downstream phases.
        // Enforcing FKs here is a correctness requirement, not a feature.
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ---------------------------------------------------------------------------
  // Reading progress queries (Phase 3, Plan 02)
  // ---------------------------------------------------------------------------

  /// Returns all chapters for a book, ordered by spine position.
  Future<List<Chapter>> getChaptersForBook(int bookId) {
    return (select(chapters)
          ..where((c) => c.bookId.equals(bookId))
          ..orderBy([(c) => OrderingTerm.asc(c.orderIndex)]))
        .get();
  }

  /// Persists reading position as chapter index + scroll offset fraction.
  ///
  /// [chapter] is the zero-based chapter index in spine order.
  /// [offset] is the 0.0–1.0 scroll fraction within that chapter.
  Future<void> updateReadingProgress(
      int bookId, int chapter, double offset) {
    return (update(books)..where((b) => b.id.equals(bookId))).write(
      BooksCompanion(
        readingProgressChapter: Value(chapter),
        readingProgressOffset: Value(offset),
      ),
    );
  }

  /// Stamps [lastReadDate] to `DateTime.now()` — called on every book open.
  Future<void> updateLastReadDate(int bookId) {
    return (update(books)..where((b) => b.id.equals(bookId))).write(
      BooksCompanion(lastReadDate: Value(DateTime.now())),
    );
  }

  /// Returns a single book by ID, or null if not found.
  Future<Book?> getBook(int bookId) {
    return (select(books)..where((b) => b.id.equals(bookId)))
        .getSingleOrNull();
  }

  static QueryExecutor _openConnection() => driftDatabase(name: 'murmur');
}
