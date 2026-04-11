/// Plan 02-07: responsive SliverGrid of BookCards.
///
/// Pure presentation sliver — takes a `List<Book>` and a long-press
/// callback, and renders a `SliverGrid` with column count chosen from
/// MediaQuery breakpoints per D-16:
///
///   shortestSide < 600 (phone):
///     portrait  → 2 cols
///     landscape → 3 cols
///   shortestSide >= 600 (tablet):
///     portrait  → 4 cols
///     landscape → 6 cols
///
/// Shimmer overlay (D-11): for every `ImportParsing` entry in
/// `importProvider`, a [BookCardShimmer] is prepended to the grid so the
/// user sees an optimistic placeholder the moment they confirm a file
/// picker selection or a Share intent fires.
///
/// Tap/long-press:
/// - `onTap` navigates to `/reader/:bookId` via `context.push` so the
///   back button returns to the library (not `go`, which replaces the
///   stack).
/// - `onLongPress` fires the parent-provided callback with `book.id`.
///   Plan 02-07's LibraryScreen wires that to the context sheet per D-17.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import 'book_card.dart';
import 'book_card_shimmer.dart';
import 'import_service.dart';

class LibraryGrid extends ConsumerWidget {
  final List<Book> books;
  final ValueChanged<int> onLongPress;

  const LibraryGrid({
    super.key,
    required this.books,
    required this.onLongPress,
  });

  /// D-16 breakpoints.
  int _columnCount(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    final isLandscape = size.width > size.height;
    if (shortest < 600) {
      return isLandscape ? 3 : 2; // phone
    }
    return isLandscape ? 6 : 4; // tablet
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(importProvider);
    final parsing = importState.whereType<ImportParsing>().toList();
    final columnCount = _columnCount(context);

    // D-11: prepend one BookCardShimmer per in-flight parse so the grid
    // shows an immediate placeholder for each EPUB the user selected.
    final items = <Widget>[
      for (final p in parsing) BookCardShimmer(filename: p.filename),
      for (final book in books)
        BookCard(
          book: book,
          onTap: () => context.push('/reader/${book.id}'),
          onLongPress: () => onLongPress(book.id),
        ),
    ];

    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          // Cover-dominant aspect: 2:3 cover area + 8px gap + two
          // text rows below. 0.50 gives ~15-20px headroom for font
          // metrics so BookCard's Column never overflows on narrow
          // phone portrait cells.
          childAspectRatio: 0.50,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => items[index],
          childCount: items.length,
        ),
      ),
    );
  }
}
