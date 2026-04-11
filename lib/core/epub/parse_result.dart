/// Result record types for the EPUB parser (Plan 02-04).
///
/// These are one-shot data containers constructed by [parseEpub] and
/// consumed by the import service (Plan 02-05). No equality, no JSON
/// codec — they never get stored directly (the Block IR is what hits
/// Drift, via `chapters.blocks_json`).
///
/// This file is pure Dart: no Flutter imports. It must cross the
/// `Isolate.run` boundary in `epub_parser_isolate.dart` per D-13.
library;

import 'block.dart';

/// Output of [parseEpub]: metadata + a chapter list + per-chapter parse
/// warnings.
///
/// Field contract (matches Plan 02-04 interfaces block):
/// - [title]           — always non-null; `EpubParseException` thrown if
///                       the EPUB has no usable title.
/// - [author]          — nullable; EPUB metadata may omit the creator.
/// - [coverBytes]      — raw image bytes (JPEG/PNG/etc), null when the
///                       EPUB has no cover image in its manifest.
/// - [coverMimeType]   — MIME type matching [coverBytes], null whenever
///                       [coverBytes] is null.
/// - [chapters]        — spine-ordered list of parsed chapters.
/// - [errors]          — per-chapter parse warnings. Empty list == clean
///                       parse; a non-empty list is NOT a failure (the
///                       book still imports, just with flagged chapters).
class ParseResult {
  final String title;
  final String? author;
  final List<int>? coverBytes;
  final String? coverMimeType;
  final List<ParsedChapter> chapters;
  final List<ChapterError> errors;

  const ParseResult({
    required this.title,
    required this.author,
    required this.coverBytes,
    required this.coverMimeType,
    required this.chapters,
    required this.errors,
  });
}

/// One chapter of a [ParseResult], carrying its parsed [Block] IR.
class ParsedChapter {
  /// Zero-based spine order. The import service writes this to
  /// `chapters.order_index`.
  final int orderIndex;

  /// Chapter title from the OPF/NCX, or null if the source did not
  /// advertise one.
  final String? title;

  /// Block IR for this chapter per D-01. An empty list is legal — it
  /// means the chapter was empty or its XHTML failed to parse (in which
  /// case a matching [ChapterError] will be present in [ParseResult.errors]).
  final List<Block> blocks;

  const ParsedChapter({
    required this.orderIndex,
    required this.title,
    required this.blocks,
  });
}

/// A per-chapter parse warning. The parser emits one of these whenever a
/// chapter's XHTML fails to parse — the offending chapter is recorded
/// with an empty block list and parsing continues with the next spine
/// item. This is "graceful degradation, not whole-book failure" per the
/// 02-CONTEXT.md Claude's Discretion note.
class ChapterError {
  final int orderIndex;
  final String message;
  const ChapterError(this.orderIndex, this.message);
}
