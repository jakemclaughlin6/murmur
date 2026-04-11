/// Library provider tests (Plan 02-06 Task 1).
///
/// Covers LIB-06 (list), LIB-07 (sort chips: Recently read / Title / Author),
/// and LIB-08 (search by title or author substring).
///
/// Strategy:
/// - Real in-memory Drift DB (`NativeDatabase.memory()`).
/// - Direct `db.into(db.books).insert(...)` to seed rows — the import
///   pipeline is covered by Plan 02-05 tests; this plan tests the
///   provider's sort + search + delete logic in isolation.
/// - `container.listen(libraryProvider, ...)` to capture emissions across
///   setSortMode / setSearchQuery mutations. Reading `.future` alone only
///   resolves the first emission, which cannot assert re-emission order.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/db/app_database_provider.dart';
import 'package:murmur/features/library/library_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late Directory sandbox;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    sandbox = Directory.systemTemp.createTempSync('murmur_library_test_');
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  /// Inserts a Book row directly, bypassing the import pipeline.
  ///
  /// [filePath] is auto-generated from [title] and scoped to [sandbox] so
  /// UNIQUE(file_path) never collides across tests within a setUp.
  Future<int> insertBook({
    required String title,
    String? author,
    DateTime? lastReadDate,
    String? coverPath,
    String? filePath,
  }) async {
    return db.into(db.books).insert(
          BooksCompanion.insert(
            title: title,
            author: drift.Value<String?>(author),
            filePath: filePath ??
                p.join(sandbox.path, '${title.toLowerCase()}.epub'),
            coverPath: drift.Value<String?>(coverPath),
            importDate: DateTime(2026, 4, 11, 12),
            lastReadDate: drift.Value<DateTime?>(lastReadDate),
          ),
        );
  }

  /// Waits for the next `AsyncData<LibraryState>` emission where
  /// [predicate] returns true, with a short timeout. This is the
  /// re-emission-aware alternative to `container.read(...future)`.
  Future<LibraryState> waitForState(
    bool Function(LibraryState s) predicate, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final completer = Completer<LibraryState>();
    final sub = container.listen<AsyncValue<LibraryState>>(
      libraryProvider,
      (prev, next) {
        final value = next.valueOrNull;
        if (value != null && !completer.isCompleted && predicate(value)) {
          completer.complete(value);
        }
      },
      fireImmediately: true,
    );
    try {
      return await completer.future.timeout(timeout);
    } finally {
      sub.close();
    }
  }

  group('LibraryNotifier — initial build', () {
    test('empty DB emits LibraryState(books:[], recentlyRead, "")', () async {
      final state = await waitForState((_) => true);
      expect(state.books, isEmpty);
      expect(state.sortMode, SortMode.recentlyRead);
      expect(state.searchQuery, '');
    });

    test('three inserted books all appear in the next emission', () async {
      await insertBook(title: 'Alpha', author: 'Zed');
      await insertBook(title: 'Beta');
      await insertBook(title: 'Charlie', author: 'Author');

      final state = await waitForState((s) => s.books.length == 3);
      expect(state.books.map((b) => b.title),
          containsAll(['Alpha', 'Beta', 'Charlie']));
    });
  });

  group('LibraryNotifier — sort modes (LIB-07)', () {
    setUp(() async {
      await insertBook(
        title: 'Charlie',
        author: 'Author',
        lastReadDate: DateTime(2026, 4, 10),
      );
      await insertBook(
        title: 'Alpha',
        author: 'Zed',
        lastReadDate: DateTime(2026, 4, 11),
      );
      // Beta has null author AND null lastReadDate — exercises nulls-last.
      await insertBook(title: 'Beta');
    });

    test('setSortMode(title) re-emits with books sorted A-Z by title',
        () async {
      // Prime the provider so it has data.
      await waitForState((s) => s.books.length == 3);

      container.read(libraryProvider.notifier).setSortMode(SortMode.title);

      final state = await waitForState(
        (s) =>
            s.sortMode == SortMode.title &&
            s.books.isNotEmpty &&
            s.books.first.title == 'Alpha',
      );
      expect(state.books.map((b) => b.title), ['Alpha', 'Beta', 'Charlie']);
    });

    test(
        'setSortMode(author) re-emits with books sorted A-Z by author '
        '(nulls last)', () async {
      await waitForState((s) => s.books.length == 3);

      container.read(libraryProvider.notifier).setSortMode(SortMode.author);

      final state = await waitForState(
        (s) => s.sortMode == SortMode.author && s.books.length == 3,
      );
      // 'Author' < 'Zed' < null — Beta (null author) last.
      expect(state.books.map((b) => b.title), ['Charlie', 'Alpha', 'Beta']);
    });

    test(
        'setSortMode(recentlyRead) re-emits with lastReadDate DESC '
        '(nulls last)', () async {
      await waitForState((s) => s.books.length == 3);

      container
          .read(libraryProvider.notifier)
          .setSortMode(SortMode.recentlyRead);

      final state = await waitForState(
        (s) => s.sortMode == SortMode.recentlyRead && s.books.length == 3,
      );
      // Alpha (Apr 11) > Charlie (Apr 10) > Beta (null) last.
      expect(state.books.map((b) => b.title), ['Alpha', 'Charlie', 'Beta']);
    });
  });

  group('LibraryNotifier — search (LIB-08)', () {
    setUp(() async {
      await insertBook(title: 'Flatland', author: 'Edwin Abbott');
      await insertBook(title: 'Dune', author: 'Frank Herbert');
      await insertBook(title: 'Middlemarch', author: 'George Eliot');
    });

    test('setSearchQuery("flat") matches title substring case-insensitive',
        () async {
      await waitForState((s) => s.books.length == 3);

      container.read(libraryProvider.notifier).setSearchQuery('flat');

      final state = await waitForState(
        (s) => s.searchQuery == 'flat' && s.books.length == 1,
      );
      expect(state.books.single.title, 'Flatland');
    });

    test('setSearchQuery("HERBERT") matches author substring case-insensitive',
        () async {
      await waitForState((s) => s.books.length == 3);

      container.read(libraryProvider.notifier).setSearchQuery('HERBERT');

      final state = await waitForState(
        (s) => s.searchQuery == 'HERBERT' && s.books.length == 1,
      );
      expect(state.books.single.title, 'Dune');
    });

    test('setSearchQuery("") clears filter and re-emits all books', () async {
      await waitForState((s) => s.books.length == 3);
      container.read(libraryProvider.notifier).setSearchQuery('flat');
      await waitForState((s) => s.books.length == 1);

      container.read(libraryProvider.notifier).setSearchQuery('');

      final state = await waitForState(
        (s) => s.searchQuery == '' && s.books.length == 3,
      );
      expect(state.books.length, 3);
    });
  });

  group('LibraryNotifier — deleteBook', () {
    test('deleteBook removes the row and re-emits without it', () async {
      final aId = await insertBook(title: 'Alpha');
      await insertBook(title: 'Beta');
      await waitForState((s) => s.books.length == 2);

      await container.read(libraryProvider.notifier).deleteBook(aId);

      final state = await waitForState((s) => s.books.length == 1);
      expect(state.books.single.title, 'Beta');
    });

    test('deleteBook cascades to chapters', () async {
      final bookId = await insertBook(title: 'WithChapters');
      await db.into(db.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              orderIndex: 0,
              title: const drift.Value('Ch 1'),
              blocksJson: '[]',
            ),
          );
      expect((await db.select(db.chapters).get()), hasLength(1));

      await container.read(libraryProvider.notifier).deleteBook(bookId);

      expect((await db.select(db.chapters).get()), isEmpty,
          reason: 'ON DELETE CASCADE must fire (Plan 02-03 pragma)');
    });

    test('deleteBook best-effort deletes the coverPath file on disk',
        () async {
      final coverFile = File(p.join(sandbox.path, 'cover.jpg'));
      await coverFile.writeAsBytes([0, 1, 2, 3]);
      expect(coverFile.existsSync(), isTrue);

      final bookId =
          await insertBook(title: 'HasCover', coverPath: coverFile.path);

      await container.read(libraryProvider.notifier).deleteBook(bookId);

      expect(coverFile.existsSync(), isFalse,
          reason: 'orphan cover file must not accumulate on disk');
    });

    test('deleteBook on a missing id is a no-op', () async {
      await insertBook(title: 'Alpha');
      await waitForState((s) => s.books.length == 1);

      // Should not throw.
      await container.read(libraryProvider.notifier).deleteBook(9999);

      final state = await waitForState((s) => s.books.length == 1);
      expect(state.books.single.title, 'Alpha');
    });
  });
}
