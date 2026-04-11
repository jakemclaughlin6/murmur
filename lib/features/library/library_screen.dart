/// Plan 02-07: LibraryScreen composition.
///
/// Replaces the Phase 1 placeholder with the real library UX:
///   1. SliverAppBar (title + import + icon) per D-15 top-of-chrome
///   2. LibrarySearchBar persistent below the app bar per D-15
///   3. LibrarySortChips row per D-15 / LIB-07
///   4. Responsive LibraryGrid of BookCards per D-15 / D-16
///   + Long-press on a card opens the BookContextSheet per D-17
///   + Import failures surface as snackbars per D-12
///   + First-import empty state reuses the Phase 1 placeholder per D-18
///   + Distinct "No books match your search" variant per D-18 amendment
///
/// The `ref.watch(shareIntentListenerProvider)` call that boots the
/// share-intent pipeline already lives in `lib/app/app.dart`; this
/// screen does not re-subscribe.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/clay_colors.dart';
import 'book_context_sheet.dart';
import 'import_picker_provider.dart';
import 'import_service.dart';
import 'library_grid.dart';
import 'library_provider.dart';
import 'library_search_bar.dart';
import 'library_sort_chips.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // D-12: surface one snackbar per newly-failed import. Compare by
    // filename + reason so retrying the same file doesn't spam the
    // user with duplicates.
    ref.listen<List<ImportState>>(importProvider, (prev, next) {
      final prevFailed = (prev ?? const <ImportState>[])
          .whereType<ImportFailed>()
          .map((f) => '${f.filename}:${f.reason}')
          .toSet();
      final nextFailed = next.whereType<ImportFailed>();
      for (final f in nextFailed) {
        final key = '${f.filename}:${f.reason}';
        if (!prevFailed.contains(key)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not import ${f.filename} — ${f.reason}'),
            ),
          );
        }
      }
    });

    final libAsync = ref.watch(libraryProvider);
    final importStates = ref.watch(importProvider);
    final parsingInFlight = importStates.whereType<ImportParsing>().isNotEmpty;

    return Scaffold(
      key: const Key('library-screen'),
      backgroundColor: ClayColors.background,
      body: libAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (state) {
          final hasBooks = state.books.isNotEmpty;
          final hasQuery = state.searchQuery.isNotEmpty;

          // First-import empty state: no books, no search query, and no
          // imports currently in flight. The third clause keeps the
          // shimmer grid visible the moment the user picks a file.
          if (!hasBooks && !hasQuery && !parsingInFlight) {
            return _EmptyFirstImport(
              onImport: () => ref.read(importPickerCallbackProvider)(ref),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Library'),
                pinned: true,
                backgroundColor: ClayColors.background,
                foregroundColor: ClayColors.textPrimary,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Import EPUB',
                    onPressed: () => ref.read(importPickerCallbackProvider)(ref),
                  ),
                ],
              ),
              const SliverToBoxAdapter(child: LibrarySearchBar()),
              const SliverToBoxAdapter(child: LibrarySortChips()),
              if (!hasBooks && hasQuery)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No books match your search',
                        style: TextStyle(color: ClayColors.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                LibraryGrid(
                  books: state.books,
                  onLongPress: (bookId) async {
                    final book = state.books.firstWhere(
                      (b) => b.id == bookId,
                      orElse: () => throw StateError(
                        'Long-pressed book $bookId not in current state',
                      ),
                    );
                    await showBookContextSheet(context, book);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

/// D-18 empty-state — reuses the Phase 1 placeholder structure with the
/// button now wired to pickAndImport.
class _EmptyFirstImport extends StatelessWidget {
  final VoidCallback onImport;
  const _EmptyFirstImport({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 96,
              color: ClayColors.textTertiary,
            ),
            const SizedBox(height: 24),
            Text(
              'Your library is empty',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: ClayColors.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Import an EPUB to start listening.',
              style: TextStyle(color: ClayColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('Import your first book'),
            ),
          ],
        ),
      ),
    );
  }
}
