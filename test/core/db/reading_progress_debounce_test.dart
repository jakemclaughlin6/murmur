import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/db/app_database_provider.dart';
import 'package:murmur/features/reader/providers/reading_progress_provider.dart';

void main() {
  late AppDatabase db;
  late int bookId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    bookId = await db.into(db.books).insert(
      BooksCompanion.insert(
        title: 'Test Book',
        filePath: '/fake/path.epub',
        importDate: DateTime(2026, 1, 1),
      ),
    );
    await db.into(db.chapters).insert(
      ChaptersCompanion.insert(
        bookId: bookId,
        orderIndex: 0,
        title: const Value('Chapter 1'),
        blocksJson: '[]',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ReadingProgressNotifier debounce', () {
    // Container must be created OUTSIDE runAsync so Riverpod's internal
    // scheduler zone matches the test's main zone. Timers created by
    // the notifier then fire correctly when runAsync awaits a Future.delayed.

    testWidgets('does NOT save before debounce elapses', (tester) async {
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      container.read(readingProgressProvider);
      final notifier = container.read(readingProgressProvider.notifier);

      await tester.runAsync(() async {
        notifier.onScrollChanged(bookId, 0, 0.5);

        // Wait less than the 2s debounce
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final book = await db.getBook(bookId);
        expect(book!.readingProgressChapter, isNull,
            reason: 'Progress should not save before 2s debounce');
      });

      container.dispose();
    });

    testWidgets('saves after 2-second debounce elapses', (tester) async {
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      container.read(readingProgressProvider);
      final notifier = container.read(readingProgressProvider.notifier);

      await tester.runAsync(() async {
        notifier.onScrollChanged(bookId, 0, 0.42);

        // Wait for debounce timer to fire (2s) + buffer for Drift FFI write
        await Future<void>.delayed(const Duration(milliseconds: 2500));

        final book = await db.getBook(bookId);
        expect(book!.readingProgressChapter, 0);
        expect(book.readingProgressOffset, closeTo(0.42, 0.001));
      });

      container.dispose();
    });

    testWidgets('rapid calls debounce to only the latest value',
        (tester) async {
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      container.read(readingProgressProvider);
      final notifier = container.read(readingProgressProvider.notifier);

      await tester.runAsync(() async {
        notifier.onScrollChanged(bookId, 0, 0.1);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        notifier.onScrollChanged(bookId, 0, 0.3);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        notifier.onScrollChanged(bookId, 0, 0.7);

        // Wait for debounce from the last call
        await Future<void>.delayed(const Duration(milliseconds: 2500));

        final book = await db.getBook(bookId);
        expect(book!.readingProgressChapter, 0);
        expect(book.readingProgressOffset, closeTo(0.7, 0.001));
      });

      container.dispose();
    });

    testWidgets('flushNow saves immediately without waiting for timer',
        (tester) async {
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      container.read(readingProgressProvider);
      final notifier = container.read(readingProgressProvider.notifier);

      await tester.runAsync(() async {
        notifier.onScrollChanged(bookId, 1, 0.55);

        // No delay -- call flushNow immediately
        notifier.flushNow();

        // Small delay for Drift FFI write to complete
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final book = await db.getBook(bookId);
        expect(book!.readingProgressChapter, 1);
        expect(book.readingProgressOffset, closeTo(0.55, 0.001));
      });

      container.dispose();
    });
  });
}
