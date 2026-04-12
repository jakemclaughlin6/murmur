/// Reader state management provider (Phase 3, Plan 04).
///
/// Loads book + chapters from Drift, resumes at saved position (D-13),
/// extracts images if needed, and exposes chapter navigation.
///
/// Auto-disposes when the reader screen is torn down — Riverpod default.
/// Family provider keyed by bookId so multiple books don't share state.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/app_database_provider.dart';
import '../../../core/epub/block.dart';
import '../../../core/epub/block_json.dart';
import '../../../core/epub/image_extractor.dart';

part 'reader_provider.g.dart';

/// Immutable state for the reader screen.
class ReaderState {
  final Book book;
  final List<Chapter> chapters;
  final int currentChapterIndex;

  /// Non-null only on first load to restore scroll position (D-13).
  final double? initialOffsetFraction;
  final Map<String, String> imagePathMap;

  const ReaderState({
    required this.book,
    required this.chapters,
    required this.currentChapterIndex,
    this.initialOffsetFraction,
    this.imagePathMap = const {},
  });

  ReaderState copyWith({
    int? currentChapterIndex,
    double? initialOffsetFraction,
    Map<String, String>? imagePathMap,
  }) {
    return ReaderState(
      book: book,
      chapters: chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      initialOffsetFraction: initialOffsetFraction,
      imagePathMap: imagePathMap ?? this.imagePathMap,
    );
  }

  /// Deserializes blocks for the given chapter index.
  ///
  /// Returns empty list if blocksJson is malformed (T-03-06: FormatException
  /// caught) or if the index is out of bounds.
  List<Block> blocksForChapter(int index) {
    if (index < 0 || index >= chapters.length) return [];
    try {
      return blocksFromJsonString(chapters[index].blocksJson);
    } on FormatException {
      return [];
    }
  }
}

@riverpod
class ReaderNotifier extends _$ReaderNotifier {
  @override
  Future<ReaderState> build(int bookId) async {
    final db = ref.read(appDatabaseProvider);

    // Load book and chapters (T-03-09: null book -> error state)
    final book = await db.getBook(bookId);
    if (book == null) throw StateError('Book $bookId not found');

    final chapters = await db.getChaptersForBook(bookId);
    if (chapters.isEmpty) throw StateError('Book $bookId has no chapters');

    // D-13: resume at saved position or start of book
    final savedChapter = book.readingProgressChapter ?? 0;
    final savedOffset = book.readingProgressOffset;
    final chapterIndex = savedChapter.clamp(0, chapters.length - 1);

    // Update lastReadDate (D-13)
    await db.updateLastReadDate(bookId);

    // Extract images — always call extractImages which is idempotent
    // (overwrites existing files). Wrapped in try-catch so test environments
    // and missing EPUB files degrade gracefully to no images.
    Map<String, String> imagePathMap = {};
    if (book.filePath.isNotEmpty) {
      try {
        final lastSlash = book.filePath.lastIndexOf('/');
        if (lastSlash > 0) {
          final bookDir = book.filePath.substring(0, lastSlash);
          imagePathMap = await ImageExtractor.extractImages(
            epubFilePath: book.filePath,
            outputDir: bookDir,
          );
        }
      } on Exception {
        // File missing or unreadable — degrade to no images
      }
    }

    return ReaderState(
      book: book,
      chapters: chapters,
      currentChapterIndex: chapterIndex,
      initialOffsetFraction: savedOffset,
      imagePathMap: imagePathMap,
    );
  }

  /// Called by PageView.onPageChanged when the user swipes to a new chapter.
  void setChapter(int index) {
    final current = state.value;
    if (current == null) return;
    if (index < 0 || index >= current.chapters.length) return;
    state = AsyncData(current.copyWith(
      currentChapterIndex: index,
      initialOffsetFraction: null, // no offset restoration on swipe
    ));
  }
}
