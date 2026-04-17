/// Plan 02-06: library backing state.
///
/// Single source of truth for the library grid — wraps the Drift `books`
/// table in a reactive stream + in-memory sort/search state, and exposes
/// a deleteBook mutation that also cascades the on-disk cover file.
///
/// Plan 07's `SliverGrid` watches `libraryProvider` and renders cards.
/// Plan 07's search field + sort chips call `setSearchQuery` /
/// `setSortMode` on the notifier. This file deliberately contains no
/// layout code — it's the backing layer only.
///
/// Scope boundaries:
/// - No debouncing lives here. Plan 07's search text field owns the
///   300ms debounce (per 02-CONTEXT Claude's Discretion note); this
///   provider filters eagerly on whatever query it is given.
/// - deleteBook relies on the `ON DELETE CASCADE` FK declared on
///   `chapters.book_id` + `PRAGMA foreign_keys = ON` from Plan 02-03
///   to remove child chapter rows automatically.
library;

import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/app_database.dart';
import '../../core/db/app_database_provider.dart';
import '../tts/isolate/tts_cache_provider.dart';

part 'library_provider.g.dart';

/// Sort modes per LIB-07 and D-15 chip row.
///
/// - [recentlyRead]: `last_read_date DESC`, books never opened (null) last.
/// - [title]: title A-Z (case-sensitive — locale-aware sort is a v1.1
///   concern; English-only in v1 means ASCII `compareTo` is correct).
/// - [author]: author A-Z, books with null author last (nulls-last
///   sentinel `'\uFFFF'` sorts after any real author).
enum SortMode { recentlyRead, title, author }

/// Immutable snapshot of the library grid state.
///
/// Carries both the filtered/sorted [books] AND the active [sortMode] +
/// [searchQuery] so Plan 07 can render the correct chip / text-field
/// highlight from a single `watch(libraryProvider)`.
class LibraryState {
  final List<Book> books;
  final SortMode sortMode;
  final String searchQuery;

  const LibraryState({
    required this.books,
    required this.sortMode,
    required this.searchQuery,
  });

  LibraryState copyWith({
    List<Book>? books,
    SortMode? sortMode,
    String? searchQuery,
  }) =>
      LibraryState(
        books: books ?? this.books,
        sortMode: sortMode ?? this.sortMode,
        searchQuery: searchQuery ?? this.searchQuery,
      );

  @override
  String toString() =>
      'LibraryState(books: ${books.length}, sortMode: $sortMode, '
      'searchQuery: "$searchQuery")';
}

/// Reactive library state — watches the Drift `books` table and emits
/// a [LibraryState] every time either the underlying table changes OR
/// [setSortMode] / [setSearchQuery] is called.
///
/// `keepAlive: true` so the state survives library-screen rebuilds
/// (swiping away to Settings and back must not reset the user's active
/// sort chip or search text).
@Riverpod(keepAlive: true)
class LibraryNotifier extends _$LibraryNotifier {
  SortMode _sortMode = SortMode.recentlyRead;
  String _searchQuery = '';
  StreamSubscription<List<Book>>? _subscription;
  StreamController<LibraryState>? _controller;
  List<Book> _latestRaw = const <Book>[];

  @override
  Stream<LibraryState> build() {
    final db = ref.read(appDatabaseProvider);
    final controller = StreamController<LibraryState>();
    _controller = controller;

    _subscription = db.select(db.books).watch().listen((books) {
      _latestRaw = books;
      _emit();
    });

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
      _controller = null;
      controller.close();
    });

    return controller.stream;
  }

  /// Applies the active sort + search to [_latestRaw] and publishes
  /// the resulting [LibraryState]. Safe to call multiple times.
  void _emit() {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;

    final query = _searchQuery.toLowerCase().trim();
    final filtered = query.isEmpty
        ? List<Book>.of(_latestRaw)
        : _latestRaw.where((b) {
            final title = b.title.toLowerCase();
            final author = (b.author ?? '').toLowerCase();
            return title.contains(query) || author.contains(query);
          }).toList();

    switch (_sortMode) {
      case SortMode.title:
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case SortMode.author:
        filtered.sort((a, b) {
          // '\uFFFF' sentinel sorts AFTER any real author, producing
          // nulls-last behavior with a single comparator.
          final aa = a.author ?? '\uFFFF';
          final bb = b.author ?? '\uFFFF';
          return aa.compareTo(bb);
        });
      case SortMode.recentlyRead:
        filtered.sort((a, b) {
          final at = a.lastReadDate;
          final bt = b.lastReadDate;
          if (at == null && bt == null) return 0;
          if (at == null) return 1; // nulls last
          if (bt == null) return -1;
          return bt.compareTo(at); // DESC
        });
    }

    controller.add(
      LibraryState(
        books: List<Book>.unmodifiable(filtered),
        sortMode: _sortMode,
        searchQuery: _searchQuery,
      ),
    );
  }

  /// Changes the active sort mode and re-emits immediately.
  ///
  /// Uses the cached `_latestRaw` rather than re-querying Drift — the
  /// data did not change, only the view over it.
  void setSortMode(SortMode mode) {
    if (_sortMode == mode) return;
    _sortMode = mode;
    _emit();
  }

  /// Changes the active search query and re-emits immediately.
  ///
  /// No debounce — Plan 07's text field is the debounce boundary.
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _emit();
  }

  /// Deletes a book and (best-effort) its on-disk cover + EPUB file.
  ///
  /// Schema-level cascade removes child `chapters` rows automatically
  /// because Plan 02-03 enabled `PRAGMA foreign_keys = ON`.
  ///
  /// File-system cleanup is best-effort: we never throw on a missing
  /// or unreadable file because the user already deleted the row and
  /// the DB is the source of truth — a stale orphan file is a disk-
  /// bloat concern, not a correctness failure.
  Future<void> deleteBook(int bookId) async {
    final db = ref.read(appDatabaseProvider);

    // Fetch row first so we can clean up its files after the delete.
    final row = await (db.select(db.books)
          ..where((b) => b.id.equals(bookId)))
        .getSingleOrNull();
    if (row == null) return;

    // Best-effort TTS cache wipe (CD-02). Run before the DB delete so
    // a mid-op crash leaves an orphan cache (disk bloat only) rather
    // than a ghost cache for a recycled rowid.
    try {
      final cache = ref.read(ttsCacheProvider);
      await cache.wipeBook(bookId.toString());
    } catch (_) {
      // Provider not overridden (uncommon test path) or wipe failed —
      // non-fatal.
    }

    await (db.delete(db.books)..where((b) => b.id.equals(bookId))).go();

    // Best-effort cover file cleanup.
    final coverPath = row.coverPath;
    if (coverPath != null) {
      try {
        final f = File(coverPath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {
        // Swallow — orphan cover is a non-critical disk concern.
      }
    }

    // Best-effort EPUB file cleanup.
    try {
      final bookFile = File(row.filePath);
      if (bookFile.existsSync()) bookFile.deleteSync();
    } catch (_) {
      // Swallow — same reasoning as coverPath.
    }
  }
}
