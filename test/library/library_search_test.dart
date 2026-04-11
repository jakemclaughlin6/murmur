/// LibrarySearchBar widget tests (Plan 02-07 Task 1).
///
/// Covers LIB-08 debounced search over title + author. D-15 search chrome;
/// Claude's Discretion note in 02-CONTEXT sets the debounce window at 300ms.
///
/// Strategy:
/// - Real in-memory Drift DB + Riverpod `libraryProvider` so the test
///   asserts the end-to-end wire: typing in the TextField eventually
///   calls `LibraryNotifier.setSearchQuery`.
/// - Debounce assertions: pump 100ms (query NOT yet applied) then
///   pump 250ms more (query IS applied). `pumpAndSettle` would race the
///   debounce window, so we use discrete `pump(duration)` calls.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/db/app_database_provider.dart';
import 'package:murmur/features/library/library_provider.dart';
import 'package:murmur/features/library/library_search_bar.dart';

Widget _wrap({
  required AppDatabase db,
}) =>
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        home: Scaffold(
          body: LibrarySearchBar(),
        ),
      ),
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('LibrarySearchBar — debounce (300ms)', () {
    testWidgets('typing does NOT apply the query within 100ms', (tester) async {
      await tester.pumpWidget(_wrap(db: db));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'dune');
      await tester.pump(const Duration(milliseconds: 100));

      // Query must still be empty — debounce window has not elapsed.
      final scope = tester.element(find.byType(LibrarySearchBar));
      final container = ProviderScope.containerOf(scope);
      final state = container.read(libraryProvider).value;
      expect(state?.searchQuery, '',
          reason: 'query must not apply before 300ms debounce elapses');
    });

    testWidgets('typing applies the query after 300ms', (tester) async {
      await tester.pumpWidget(_wrap(db: db));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'dune');
      // Push past the 300ms debounce window.
      await tester.pump(const Duration(milliseconds: 350));

      final scope = tester.element(find.byType(LibrarySearchBar));
      final container = ProviderScope.containerOf(scope);
      final state = container.read(libraryProvider).value;
      expect(state?.searchQuery, 'dune',
          reason: 'query must be applied to LibraryNotifier after debounce');
    });

    testWidgets('rapid typing coalesces into a single final apply',
        (tester) async {
      await tester.pumpWidget(_wrap(db: db));
      await tester.pump();

      // Three rapid keystrokes well under the debounce window.
      await tester.enterText(find.byType(TextField), 'd');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'du');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'dune');
      await tester.pump(const Duration(milliseconds: 350));

      final scope = tester.element(find.byType(LibrarySearchBar));
      final container = ProviderScope.containerOf(scope);
      final state = container.read(libraryProvider).value;
      expect(state?.searchQuery, 'dune');
    });
  });

  group('LibrarySearchBar — clear button', () {
    testWidgets('clear button appears when text is non-empty', (tester) async {
      await tester.pumpWidget(_wrap(db: db));
      await tester.pump();

      // Initially empty — no clear icon.
      expect(find.byIcon(Icons.clear), findsNothing);

      await tester.enterText(find.byType(TextField), 'dune');
      await tester.pump();

      // Clear icon now visible.
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('tapping clear button wipes text and re-applies empty query',
        (tester) async {
      await tester.pumpWidget(_wrap(db: db));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'dune');
      await tester.pump(const Duration(milliseconds: 350));

      final scope = tester.element(find.byType(LibrarySearchBar));
      final container = ProviderScope.containerOf(scope);
      expect(container.read(libraryProvider).value?.searchQuery, 'dune');

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump(const Duration(milliseconds: 350));

      expect(container.read(libraryProvider).value?.searchQuery, '');
      expect(find.byIcon(Icons.clear), findsNothing);
    });
  });
}
