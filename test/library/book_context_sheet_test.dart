/// BookContextSheet widget tests (Plan 02-07 Task 2).
///
/// Covers LIB-09 (D-17 long-press → modal bottom sheet with Book Info +
/// Delete, plus a confirmation dialog before the deletion actually
/// fires). T-02-07-01 mitigation — the two-step gesture.
///
/// Strategy:
/// - `showBookContextSheet` is called from a plain Scaffold button so
///   we skip LibraryScreen composition and test the sheet surface
///   directly.
/// - A spy LibraryNotifier captures `deleteBook` calls without touching
///   Drift — consistent with the approach in library_search_test.dart
///   (avoids flutter_tester SEGV on leaked streams).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/features/library/book_context_sheet.dart';
import 'package:murmur/features/library/library_provider.dart';

class _SpyLibraryNotifier extends LibraryNotifier {
  final List<int> deleteCalls = [];

  @override
  Stream<LibraryState> build() => Stream.value(
        const LibraryState(
          books: [],
          sortMode: SortMode.recentlyRead,
          searchQuery: '',
        ),
      );

  @override
  Future<void> deleteBook(int id) async {
    deleteCalls.add(id);
  }
}

Book _book() => Book(
      id: 42,
      title: 'Flatland',
      author: 'Edwin Abbott',
      filePath: '/tmp/flatland.epub',
      coverPath: null,
      importDate: DateTime(2026, 4, 11),
    );

/// A trivial host that shows a button; tapping the button opens the
/// sheet against the same `BuildContext` the sheet needs.
Widget _host(_SpyLibraryNotifier spy, Book book) => ProviderScope(
      overrides: [libraryProvider.overrideWith(() => spy)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showBookContextSheet(context, book),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  group('BookContextSheet (D-17 / LIB-09)', () {
    testWidgets('shows Book Info and Delete ListTiles', (tester) async {
      final spy = _SpyLibraryNotifier();
      await tester.pumpWidget(_host(spy, _book()));
      await tester.pump();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Book Info'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('tapping Delete shows a confirmation dialog',
        (tester) async {
      final spy = _SpyLibraryNotifier();
      await tester.pumpWidget(_host(spy, _book()));
      await tester.pump();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirmation dialog with book title and both Cancel / Delete.
      expect(find.textContaining('Flatland'), findsAtLeastNWidgets(1));
      expect(find.text('Cancel'), findsOneWidget);
      // The second "Delete" is the dialog's confirm button.
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('confirming delete calls LibraryNotifier.deleteBook(id)',
        (tester) async {
      final spy = _SpyLibraryNotifier();
      await tester.pumpWidget(_host(spy, _book()));
      await tester.pump();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Tap the dialog's confirm button (the only remaining "Delete").
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(spy.deleteCalls, [42],
          reason: 'deleteBook called with the book id from the sheet');
    });

    testWidgets('tapping Cancel in the confirm dialog does NOT delete',
        (tester) async {
      final spy = _SpyLibraryNotifier();
      await tester.pumpWidget(_host(spy, _book()));
      await tester.pump();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(spy.deleteCalls, isEmpty,
          reason: 'canceling the dialog must abort the delete');
    });
  });
}
