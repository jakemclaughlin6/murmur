/// LibraryGrid widget tests (Plan 02-07 Task 1).
///
/// Covers LIB-05 responsive grid with D-16 breakpoints (2/3 cols on phone,
/// 4/6 on tablet via MediaQuery.shortestSide + orientation) and D-11
/// shimmer overlay for in-flight imports.
///
/// Strategy:
/// - ProviderScope wrapping with an in-memory Drift DB override (so the
///   library provider is real, but isolated per test).
/// - `tester.view.physicalSize` / `devicePixelRatio` to simulate phone
///   and tablet viewports; reset with `addTearDown(tester.view.reset)`.
/// - Feed books directly through `LibraryGrid`'s constructor (bypasses
///   the provider — Grid is a pure widget taking a List<Book>).
/// - `coverImageOverride` is wired for every test BookCard indirectly by
///   constructing BookCards with `coverPath: null` so they take the
///   fallback branch (no Image.file calls, no async decoder hangs).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/db/app_database_provider.dart';
import 'package:murmur/features/library/book_card.dart';
import 'package:murmur/features/library/book_card_shimmer.dart';
import 'package:murmur/features/library/import_service.dart';
import 'package:murmur/features/library/library_grid.dart';

Book _makeBook(int id, String title) => Book(
      id: id,
      title: title,
      author: 'Author $id',
      filePath: '/tmp/book_$id.epub',
      coverPath: null, // forces fallback — no Image.file decode
      importDate: DateTime(2026, 4, 11),
    );

/// Wraps a sliver in a CustomScrollView + ProviderScope and gives the
/// viewport a definite size controlled by [tester.view].
Widget _wrap({
  required WidgetTester tester,
  required List<Book> books,
  required ValueChanged<int> onLongPress,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            LibraryGrid(books: books, onLongPress: onLongPress),
          ],
        ),
      ),
    ),
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  List<Override> dbOverride() => [appDatabaseProvider.overrideWithValue(db)];

  group('LibraryGrid — responsive column count (D-16 / LIB-05)', () {
    testWidgets('phone portrait (shortestSide < 600, taller than wide) '
        '→ 2 columns', (tester) async {
      _setViewport(tester, const Size(400, 800)); // 400dp wide, portrait

      // Seed 4 books so we can observe the actual column count in the
      // first row.
      final books = [for (var i = 0; i < 4; i++) _makeBook(i, 'Book $i')];

      await tester.pumpWidget(
        _wrap(
          tester: tester,
          books: books,
          onLongPress: (_) {},
          overrides: dbOverride(),
        ),
      );
      await tester.pump();

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2,
          reason: 'phone portrait: 2 cols per D-16');
    });

    testWidgets('phone landscape (shortestSide < 600, wider than tall) '
        '→ 3 columns', (tester) async {
      _setViewport(tester, const Size(800, 400)); // phone landscape

      final books = [for (var i = 0; i < 6; i++) _makeBook(i, 'Book $i')];

      await tester.pumpWidget(
        _wrap(
          tester: tester,
          books: books,
          onLongPress: (_) {},
          overrides: dbOverride(),
        ),
      );
      await tester.pump();

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3,
          reason: 'phone landscape: 3 cols per D-16');
    });

    testWidgets('tablet portrait (shortestSide >= 600, taller than wide) '
        '→ 4 columns', (tester) async {
      _setViewport(tester, const Size(800, 1200)); // tablet portrait

      final books = [for (var i = 0; i < 8; i++) _makeBook(i, 'Book $i')];

      await tester.pumpWidget(
        _wrap(
          tester: tester,
          books: books,
          onLongPress: (_) {},
          overrides: dbOverride(),
        ),
      );
      await tester.pump();

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 4,
          reason: 'tablet portrait: 4 cols per D-16');
    });

    testWidgets('tablet landscape (shortestSide >= 600, wider than tall) '
        '→ 6 columns', (tester) async {
      _setViewport(tester, const Size(1200, 800)); // tablet landscape

      final books = [for (var i = 0; i < 12; i++) _makeBook(i, 'Book $i')];

      await tester.pumpWidget(
        _wrap(
          tester: tester,
          books: books,
          onLongPress: (_) {},
          overrides: dbOverride(),
        ),
      );
      await tester.pump();

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 6,
          reason: 'tablet landscape: 6 cols per D-16');
    });
  });

  group('LibraryGrid — shimmer overlay (D-11)', () {
    testWidgets('prepends BookCardShimmer for every ImportParsing state',
        (tester) async {
      _setViewport(tester, const Size(400, 800));

      // Seed importProvider with 2 ImportParsing states (overriding the
      // notifier's initial state directly).
      final overrides = [
        ...dbOverride(),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  // Push two parsing states into the import notifier
                  // before the first frame so LibraryGrid reads them.
                  final notifier = ref.read(importProvider.notifier);
                  notifier.state = const [
                    ImportParsing('pending1.epub'),
                    ImportParsing('pending2.epub'),
                  ];
                  return CustomScrollView(
                    slivers: [
                      LibraryGrid(
                        books: [_makeBook(1, 'Real Book')],
                        onLongPress: (_) {},
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 2 shimmer cards for the parsing states + 1 real BookCard.
      expect(find.byType(BookCardShimmer), findsNWidgets(2));
      expect(find.byType(BookCard), findsOneWidget);
    });
  });

  group('LibraryGrid — long-press callback', () {
    testWidgets('long-press on a BookCard invokes onLongPress with book id',
        (tester) async {
      _setViewport(tester, const Size(400, 800));

      final captured = <int>[];
      final book = _makeBook(42, 'Target');

      await tester.pumpWidget(
        _wrap(
          tester: tester,
          books: [book],
          onLongPress: captured.add,
          overrides: dbOverride(),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(BookCard));
      await tester.pump();

      expect(captured, [42]);
    });
  });
}
