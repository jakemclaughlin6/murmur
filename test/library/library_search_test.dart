/// LibrarySearchBar widget tests (Plan 02-07 Task 1).
///
/// Covers LIB-08 debounced search over title + author. D-15 search chrome;
/// Claude's Discretion note in 02-CONTEXT sets the debounce window at 300ms.
///
/// Strategy:
/// - Override `libraryProvider` with a spy notifier that records every
///   `setSearchQuery` call — avoids touching Drift entirely so the test
///   is purely about the debounce + clear-button wiring.
/// - Debounce assertions: pump 100ms (no call yet) vs 350ms (call made).
///   `pumpAndSettle` would race the debounce window so we use discrete
///   `pump(duration)` calls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/library/library_provider.dart';
import 'package:murmur/features/library/library_search_bar.dart';

/// A LibraryNotifier subclass that records every setSearchQuery /
/// setSortMode call and never touches a real database — the search-bar
/// tests only care about whether the widget invokes the notifier with
/// the right argument, not about what the notifier then does with it.
class _SpyLibraryNotifier extends LibraryNotifier {
  final List<String> searchCalls = [];

  @override
  Stream<LibraryState> build() {
    // Immediately emit an empty state; no DB subscription, no streams
    // hanging across tests (which caused flutter_tester SEGV crashes
    // when the real Stream<LibraryState> leaked across test boundaries).
    return Stream.value(
      const LibraryState(
        books: [],
        sortMode: SortMode.recentlyRead,
        searchQuery: '',
      ),
    );
  }

  @override
  void setSearchQuery(String query) {
    searchCalls.add(query);
  }
}

Widget _wrap(_SpyLibraryNotifier spy) => ProviderScope(
      overrides: [libraryProvider.overrideWith(() => spy)],
      child: const MaterialApp(
        home: Scaffold(body: LibrarySearchBar()),
      ),
    );

void main() {
  group('LibrarySearchBar — debounce (300ms)', () {
    testWidgets('typing does NOT apply the query within 100ms', (tester) async {
      final spy = _SpyLibraryNotifier();
      await tester.pumpWidget(_wrap(spy));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'dune');
      await tester.pump(const Duration(milliseconds: 100));

      expect(spy.searchCalls, isEmpty,
          reason: 'query must not apply before 300ms debounce elapses');
    });

    testWidgets('typing applies the query after 300ms', (tester) async {
      final spy = _SpyLibraryNotifier();
      await tester.pumpWidget(_wrap(spy));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'dune');
      await tester.pump(const Duration(milliseconds: 350));

      expect(spy.searchCalls, ['dune'],
          reason: 'query must be applied to LibraryNotifier after debounce');
    });

    testWidgets('rapid typing coalesces into a single final apply',
        (tester) async {
      final spy = _SpyLibraryNotifier();
      await tester.pumpWidget(_wrap(spy));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'd');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'du');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'dune');
      await tester.pump(const Duration(milliseconds: 350));

      // Only the last value should reach the notifier.
      expect(spy.searchCalls, ['dune']);
    });
  });

  group('LibrarySearchBar — clear button', () {
    testWidgets('clear button appears when text is non-empty', (tester) async {
      final spy = _SpyLibraryNotifier();
      await tester.pumpWidget(_wrap(spy));
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
      final spy = _SpyLibraryNotifier();
      await tester.pumpWidget(_wrap(spy));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'dune');
      await tester.pump(const Duration(milliseconds: 350));
      expect(spy.searchCalls, ['dune']);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump(const Duration(milliseconds: 350));

      // The clear path issues one more setSearchQuery('') call.
      expect(spy.searchCalls, ['dune', '']);
      expect(find.byIcon(Icons.clear), findsNothing);
    });
  });
}
