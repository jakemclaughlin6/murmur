/// Plan 02-07: book context bottom sheet (D-17 / LIB-09).
///
/// Shown on long-press of a [BookCard] from the library grid. Two
/// options — Book Info (dialog with metadata) and Delete (confirmation
/// dialog → [LibraryNotifier.deleteBook]). The two-step gesture
/// (long-press → tap Delete → confirm) is the T-02-07-01 mitigation
/// for accidental, non-undoable deletion.
///
/// Book Info reads chapter count directly from Drift via a tiny
/// `selectOnly(...).count()` query. This is a leaf widget → DB query
/// (a light code smell) but kept local because an info dialog is
/// out-of-band with the library grid state and doesn't belong in
/// [LibraryNotifier].
library;

import 'dart:io';

import 'package:drift/drift.dart' show countAll;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/app_database_provider.dart';
import '../../core/theme/clay_colors.dart';
import 'library_provider.dart';

/// Shows the long-press context sheet for [book].
///
/// Returns when the sheet closes (either via the user tapping outside,
/// choosing an option, or the delete flow completing).
Future<void> showBookContextSheet(BuildContext context, Book book) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ClayColors.surface,
    builder: (_) => _BookContextSheet(book: book),
  );
}

class _BookContextSheet extends ConsumerWidget {
  final Book book;
  const _BookContextSheet({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.info_outline,
              color: ClayColors.textSecondary,
            ),
            title: const Text('Book Info'),
            onTap: () async {
              Navigator.of(context).pop();
              await _showInfoDialog(context, ref, book);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              // Capture the notifier BEFORE popping the sheet — after
              // the pop, this widget's element is unmounted and `ref`
              // becomes unusable.
              final notifier = ref.read(libraryProvider.notifier);
              final rootContext = Navigator.of(context, rootNavigator: true)
                  .context;
              Navigator.of(context).pop();
              await _confirmAndDelete(rootContext, notifier, book);
            },
          ),
        ],
      ),
    );
  }
}

/// Two-step delete (T-02-07-01 mitigation).
///
/// Separated from the widget class so the sheet closes BEFORE the
/// dialog opens — otherwise the dialog would be a child of the modal
/// sheet's route and dismissing it would feel like a bug.
Future<void> _confirmAndDelete(
  BuildContext context,
  LibraryNotifier notifier,
  Book book,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete "${book.title}"?'),
      content: const Text(
        'This will remove the book and its reading progress.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await notifier.deleteBook(book.id);
  }
}

/// Book Info dialog — title, author, chapter count, file size, imported.
///
/// Runs a small Drift count query against the chapters table to show
/// how many chapters the parser produced; any error (e.g. table
/// deleted out from under us) falls back to `—`.
Future<void> _showInfoDialog(
  BuildContext context,
  WidgetRef ref,
  Book book,
) async {
  final db = ref.read(appDatabaseProvider);

  int chapterCount;
  try {
    final countExpr = countAll();
    final row = await (db.selectOnly(db.chapters)
          ..addColumns([countExpr])
          ..where(db.chapters.bookId.equals(book.id)))
        .getSingle();
    chapterCount = row.read(countExpr) ?? 0;
  } catch (_) {
    chapterCount = 0;
  }

  var fileSize = 0;
  try {
    final f = File(book.filePath);
    if (f.existsSync()) fileSize = f.lengthSync();
  } catch (_) {
    // Ignore — file may have been removed out of band.
  }

  if (!context.mounted) return;

  final sizeMb = (fileSize / 1024 / 1024).toStringAsFixed(1);
  final importedDate =
      '${book.importDate.toLocal().year}-'
      '${book.importDate.toLocal().month.toString().padLeft(2, '0')}-'
      '${book.importDate.toLocal().day.toString().padLeft(2, '0')}';

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(book.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Author: ${book.author ?? "Unknown"}'),
          Text('Chapters: $chapterCount'),
          Text('Size: $sizeMb MB'),
          Text('Imported: $importedDate'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
