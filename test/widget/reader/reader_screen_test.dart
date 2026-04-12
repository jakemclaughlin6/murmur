import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/db/app_database_provider.dart';
import 'package:murmur/features/reader/providers/font_settings_provider.dart';
import 'package:murmur/features/reader/reader_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to build blocksJson for a chapter with simple paragraphs.
String _blocksJson(List<String> paragraphs) {
  return jsonEncode(
    paragraphs
        .map((text) => {'type': 'paragraph', 'text': text})
        .toList(),
  );
}

/// Inserts a book with [numChapters] chapters into [db].
/// Returns the book id.
Future<int> _insertBook(
  AppDatabase db, {
  required String title,
  int numChapters = 3,
  int? readingProgressChapter,
  double? readingProgressOffset,
}) async {
  final bookId = await db.into(db.books).insert(
    BooksCompanion.insert(
      title: title,
      filePath: '/fake/path/book.epub',
      importDate: DateTime(2026, 1, 1),
      readingProgressChapter: readingProgressChapter != null
          ? Value(readingProgressChapter)
          : const Value.absent(),
      readingProgressOffset: readingProgressOffset != null
          ? Value(readingProgressOffset)
          : const Value.absent(),
    ),
  );

  for (int i = 0; i < numChapters; i++) {
    await db.into(db.chapters).insert(
      ChaptersCompanion.insert(
        bookId: bookId,
        orderIndex: i,
        title: Value('Chapter ${i + 1}'),
        blocksJson: _blocksJson([
          'This is the first paragraph of chapter ${i + 1}.',
          'This is the second paragraph of chapter ${i + 1}.',
        ]),
      ),
    );
  }

  return bookId;
}

/// Wraps a widget in the required providers for reader tests.
Widget _testApp(
  AppDatabase db,
  Widget child,
) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      fontSizeControllerProvider.overrideWith(
        () => _SyncFontSizeController(),
      ),
      fontFamilyControllerProvider.overrideWith(
        () => _SyncFontFamilyController(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

/// Font size controller that returns synchronously for tests.
class _SyncFontSizeController extends FontSizeController {
  @override
  Future<double> build() async => 18.0;
}

/// Font family controller that returns synchronously for tests.
class _SyncFontFamilyController extends FontFamilyController {
  @override
  Future<String> build() async => 'Literata';
}

/// Pumps the widget and waits for the async Riverpod providers to resolve.
///
/// Uses `tester.runAsync` to allow real async operations (Drift FFI queries)
/// to complete, then pumps frames for the widget tree to rebuild.
Future<void> _pumpAndLoad(
  WidgetTester tester,
  Widget app,
) async {
  await tester.pumpWidget(app);
  // runAsync lets real async (Drift NativeDatabase) resolve outside FakeAsync
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  // Pump frames for widget tree rebuild after provider resolves
  await tester.pump();
  await tester.pump();
}

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('ReaderScreen', () {
    testWidgets('book loads and shows title in AppBar', (tester) async {
      final bookId = await _insertBook(db, title: 'Pride and Prejudice');

      await _pumpAndLoad(
        tester,
        _testApp(db, ReaderScreen(bookId: bookId)),
      );

      expect(find.text('Pride and Prejudice'), findsOneWidget);
    });

    testWidgets('first chapter content is displayed', (tester) async {
      final bookId = await _insertBook(db, title: 'Test Book');

      await _pumpAndLoad(
        tester,
        _testApp(db, ReaderScreen(bookId: bookId)),
      );

      // Chapter 1 paragraph text rendered via RichText inside Semantics.
      // find.text won't find TextSpan text; check via Semantics label.
      expect(
        find.bySemanticsLabel(
          'This is the first paragraph of chapter 1.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('swipe to next chapter shows chapter 2 content',
        (tester) async {
      final bookId = await _insertBook(db, title: 'Swipe Book');

      await _pumpAndLoad(
        tester,
        _testApp(db, ReaderScreen(bookId: bookId)),
      );

      // Swipe left to go to chapter 2
      await tester.drag(
        find.byType(PageView),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      // Chapter 2 content should now be visible (RichText via Semantics)
      expect(
        find.bySemanticsLabel(
          'This is the first paragraph of chapter 2.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no bookId shows placeholder message', (tester) async {
      await tester.pumpWidget(
        _testApp(db, const ReaderScreen(bookId: null)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open a book from the Library'), findsOneWidget);
      expect(find.byKey(const Key('reader-screen')), findsOneWidget);
    });

    testWidgets('resume position starts at saved chapter index',
        (tester) async {
      final bookId = await _insertBook(
        db,
        title: 'Resume Book',
        numChapters: 3,
        readingProgressChapter: 1, // second chapter (zero-indexed)
      );

      await _pumpAndLoad(
        tester,
        _testApp(db, ReaderScreen(bookId: bookId)),
      );

      // Should show chapter 2 (index 1), not chapter 1 (RichText via Semantics)
      expect(
        find.bySemanticsLabel(
          'This is the first paragraph of chapter 2.',
        ),
        findsOneWidget,
      );
    });
  });
}
