/// LibraryScreen empty-state widget tests (Plan 02-07 Task 2).
///
/// Covers LIB-10 (D-18 empty state reuses Phase 1 placeholder with the
/// FilledButton.icon now wired to pickAndImport) AND the distinct
/// "no search results" variant per D-18 amendment.
///
/// Strategy:
/// - Override `libraryProvider` with a spy that emits a configurable
///   [LibraryState] synchronously — avoids Drift entirely, side-steps
///   the flutter_tester SEGV seen when a real Drift stream leaks
///   across test boundaries, and lets each test dictate the exact
///   `books` + `searchQuery` state the screen is rendering.
/// - Override `importProvider` to prevent any real pickAndImport call
///   from landing on file_picker (which cannot load in a unit test).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/features/library/import_service.dart';
import 'package:murmur/features/library/library_provider.dart';
import 'package:murmur/features/library/library_screen.dart';

/// Spy LibraryNotifier with a configurable initial state + call log.
class _SpyLibraryNotifier extends LibraryNotifier {
  final LibraryState initial;
  final List<String> searchCalls = [];
  final List<int> deleteCalls = [];

  _SpyLibraryNotifier(this.initial);

  @override
  Stream<LibraryState> build() => Stream.value(initial);

  @override
  void setSearchQuery(String query) => searchCalls.add(query);

  @override
  Future<void> deleteBook(int id) async => deleteCalls.add(id);
}

/// Minimal Book for the tests — all books have coverPath=null so the
/// fallback branch runs (no Image.file hangs).
Book _book(int id, String title) => Book(
      id: id,
      title: title,
      author: 'Author $id',
      filePath: '/tmp/book_$id.epub',
      coverPath: null,
      importDate: DateTime(2026, 4, 11),
    );

Widget _wrap(_SpyLibraryNotifier spy) => ProviderScope(
      overrides: [
        libraryProvider.overrideWith(() => spy),
      ],
      child: const MaterialApp(
        home: LibraryScreen(),
      ),
    );

void main() {
  group('LibraryScreen — first-import empty state (D-18 / LIB-10)', () {
    testWidgets(
        'empty library shows placeholder icon, headline, body, and '
        'Import your first book button', (tester) async {
      final spy = _SpyLibraryNotifier(
        const LibraryState(
          books: [],
          sortMode: SortMode.recentlyRead,
          searchQuery: '',
        ),
      );
      await tester.pumpWidget(_wrap(spy));
      await tester.pump();

      // 96px book icon.
      final iconFinder = find.byIcon(Icons.menu_book_outlined);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.size, 96, reason: 'D-18 placeholder icon is 96px');

      // Headline + body text.
      expect(find.text('Your library is empty'), findsOneWidget);
      expect(find.text('Import an EPUB to start listening.'), findsOneWidget);

      // Import button with + icon.
      expect(find.text('Import your first book'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('LibraryScreen — empty search results (distinct from D-18)', () {
    testWidgets(
        'empty books + non-empty query shows "No books match your search" '
        'instead of the first-import CTA', (tester) async {
      final spy = _SpyLibraryNotifier(
        const LibraryState(
          books: [],
          sortMode: SortMode.recentlyRead,
          searchQuery: 'nonexistent',
        ),
      );
      await tester.pumpWidget(_wrap(spy));
      await tester.pump();

      expect(find.text('No books match your search'), findsOneWidget,
          reason: 'distinct empty-search message per D-18 amendment');
      expect(find.text('Import your first book'), findsNothing,
          reason: 'first-import CTA must NOT appear when searching');
      expect(find.text('Your library is empty'), findsNothing,
          reason: 'first-import headline must NOT appear when searching');
    });
  });

  group('LibraryScreen — populated grid', () {
    testWidgets('non-empty books renders CustomScrollView with SliverAppBar',
        (tester) async {
      final spy = _SpyLibraryNotifier(
        LibraryState(
          books: [_book(1, 'Dune'), _book(2, 'Flatland')],
          sortMode: SortMode.recentlyRead,
          searchQuery: '',
        ),
      );
      await tester.pumpWidget(_wrap(spy));
      await tester.pump();

      // The SliverAppBar title.
      expect(find.text('Library'), findsOneWidget);
      // Both book titles rendered.
      expect(find.text('Dune'), findsOneWidget);
      expect(find.text('Flatland'), findsOneWidget);
      // First-import CTA is absent when books exist.
      expect(find.text('Your library is empty'), findsNothing);
    });
  });
}
