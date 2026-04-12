import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// Inserts a test book and returns its ID.
  Future<int> insertTestBook({String title = 'Test Book'}) async {
    return db.into(db.books).insert(
          BooksCompanion.insert(
            title: title,
            filePath: '/books/$title.epub',
            importDate: DateTime(2026, 1, 1),
          ),
        );
  }

  /// Inserts a chapter for the given book.
  Future<void> insertChapter(int bookId, int orderIndex, String? title) async {
    await db.into(db.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            orderIndex: orderIndex,
            title: Value<String?>(title),
            blocksJson: '[]',
          ),
        );
  }

  group('getChaptersForBook', () {
    test('returns chapters ordered by orderIndex', () async {
      final bookId = await insertTestBook();
      // Insert out of order to verify sorting.
      await insertChapter(bookId, 2, 'Chapter 3');
      await insertChapter(bookId, 0, 'Chapter 1');
      await insertChapter(bookId, 1, 'Chapter 2');

      final chapters = await db.getChaptersForBook(bookId);

      expect(chapters, hasLength(3));
      expect(chapters[0].orderIndex, 0);
      expect(chapters[0].title, 'Chapter 1');
      expect(chapters[1].orderIndex, 1);
      expect(chapters[2].orderIndex, 2);
    });

    test('returns empty list for book with no chapters', () async {
      final bookId = await insertTestBook();
      final chapters = await db.getChaptersForBook(bookId);
      expect(chapters, isEmpty);
    });

    test('does not return chapters from other books', () async {
      final book1 = await insertTestBook(title: 'Book 1');
      final book2 = await insertTestBook(title: 'Book 2');
      await insertChapter(book1, 0, 'B1 Ch1');
      await insertChapter(book2, 0, 'B2 Ch1');
      await insertChapter(book2, 1, 'B2 Ch2');

      final chapters = await db.getChaptersForBook(book1);
      expect(chapters, hasLength(1));
      expect(chapters[0].title, 'B1 Ch1');
    });
  });

  group('updateReadingProgress', () {
    test('persists chapter and offset', () async {
      final bookId = await insertTestBook();

      await db.updateReadingProgress(bookId, 3, 0.75);

      final book = await db.getBook(bookId);
      expect(book, isNotNull);
      expect(book!.readingProgressChapter, 3);
      expect(book.readingProgressOffset, closeTo(0.75, 0.001));
    });

    test('overwrites previous progress', () async {
      final bookId = await insertTestBook();

      await db.updateReadingProgress(bookId, 1, 0.5);
      await db.updateReadingProgress(bookId, 5, 0.9);

      final book = await db.getBook(bookId);
      expect(book!.readingProgressChapter, 5);
      expect(book.readingProgressOffset, closeTo(0.9, 0.001));
    });
  });

  group('updateLastReadDate', () {
    test('sets a non-null date', () async {
      final bookId = await insertTestBook();

      // Initially null.
      var book = await db.getBook(bookId);
      expect(book!.lastReadDate, isNull);

      await db.updateLastReadDate(bookId);

      book = await db.getBook(bookId);
      expect(book!.lastReadDate, isNotNull);
    });
  });

  group('getBook', () {
    test('returns book by ID', () async {
      final bookId = await insertTestBook(title: 'My EPUB');
      final book = await db.getBook(bookId);

      expect(book, isNotNull);
      expect(book!.id, bookId);
      expect(book.title, 'My EPUB');
    });

    test('returns null for nonexistent ID', () async {
      final book = await db.getBook(99999);
      expect(book, isNull);
    });
  });
}
