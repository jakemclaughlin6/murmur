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
import 'package:murmur/features/reader/widgets/chapter_drawer.dart';
import 'package:murmur/features/reader/widgets/chapter_sidebar.dart';
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
Future<int> _insertBook(
  AppDatabase db, {
  required String title,
  int numChapters = 3,
}) async {
  final bookId = await db.into(db.books).insert(
    BooksCompanion.insert(
      title: title,
      filePath: '/fake/path/book.epub',
      importDate: DateTime(2026, 1, 1),
    ),
  );

  for (int i = 0; i < numChapters; i++) {
    await db.into(db.chapters).insert(
      ChaptersCompanion.insert(
        bookId: bookId,
        orderIndex: i,
        title: Value('Chapter ${i + 1}'),
        blocksJson: _blocksJson([
          'This is paragraph one of chapter ${i + 1}.',
          'This is paragraph two of chapter ${i + 1}.',
        ]),
      ),
    );
  }

  return bookId;
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

/// Wraps a widget with providers at a specific screen size.
Widget _testApp(
  AppDatabase db,
  Widget child, {
  Size size = const Size(390, 844), // phone by default
}) {
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
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    ),
  );
}

/// Pumps the widget and waits for async Riverpod providers to resolve.
Future<void> _pumpAndLoad(
  WidgetTester tester,
  Widget app,
) async {
  await tester.pumpWidget(app);
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
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

  group('Responsive layout', () {
    testWidgets('tablet shows sidebar, no drawer', (tester) async {
      final bookId = await _insertBook(db, title: 'Tablet Book');

      await _pumpAndLoad(
        tester,
        _testApp(
          db,
          ReaderScreen(bookId: bookId),
          size: const Size(1024, 768), // tablet: shortestSide = 768
        ),
      );

      // Tablet should show ChapterSidebar
      expect(find.byType(ChapterSidebar), findsOneWidget);

      // Tablet should NOT have a Drawer
      expect(find.byType(ChapterDrawer), findsNothing);
    });

    testWidgets('phone shows no sidebar, has drawer available', (tester) async {
      final bookId = await _insertBook(db, title: 'Phone Book');

      await _pumpAndLoad(
        tester,
        _testApp(
          db,
          ReaderScreen(bookId: bookId),
          size: const Size(390, 844), // phone: shortestSide = 390
        ),
      );

      // Phone should NOT show ChapterSidebar
      expect(find.byType(ChapterSidebar), findsNothing);

      // Drawer is set on Scaffold but not open yet -- verify via Scaffold
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(scaffold.drawer, isNotNull);
    });

    testWidgets('chapter tap in sidebar jumps to that chapter', (tester) async {
      final bookId = await _insertBook(db, title: 'Nav Book', numChapters: 3);

      await _pumpAndLoad(
        tester,
        _testApp(
          db,
          ReaderScreen(bookId: bookId),
          size: const Size(1024, 768), // tablet
        ),
      );

      // Initially on chapter 1
      expect(
        find.bySemanticsLabel('This is paragraph one of chapter 1.'),
        findsOneWidget,
      );

      // Tap chapter 2 in the sidebar
      await tester.tap(find.text('Chapter 2'));
      await tester.pumpAndSettle();

      // Should now show chapter 2 content
      expect(
        find.bySemanticsLabel('This is paragraph one of chapter 2.'),
        findsOneWidget,
      );
    });

    testWidgets('current chapter is highlighted in sidebar', (tester) async {
      final bookId = await _insertBook(db, title: 'Highlight Book');

      await _pumpAndLoad(
        tester,
        _testApp(
          db,
          ReaderScreen(bookId: bookId),
          size: const Size(1024, 768), // tablet
        ),
      );

      // Find the ListTile for chapter 1 (current) and verify it is selected
      final chapterTile = tester.widget<ListTile>(
        find.byKey(const ValueKey('chapter-tile-0')),
      );
      expect(chapterTile.selected, isTrue);

      // Chapter 2 should not be selected
      final chapter2Tile = tester.widget<ListTile>(
        find.byKey(const ValueKey('chapter-tile-1')),
      );
      expect(chapter2Tile.selected, isFalse);
    });
  });
}
