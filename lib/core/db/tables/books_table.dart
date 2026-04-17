import 'package:drift/drift.dart';

/// `books` table — per D-05 (Phase 02 CONTEXT).
///
/// Columns (in order):
/// - [id] — autoincrementing primary key.
/// - [title] — required, from EPUB `<dc:title>` or fallback filename.
/// - [author] — nullable, from EPUB `<dc:creator>` (may be missing).
/// - [filePath] — absolute path to the imported EPUB inside
///   `${appDocumentsDir}/books/`. **UNIQUE** so the same file cannot be
///   re-imported (mitigates T-02-03-01 tampering). Plan 05 adds a
///   defense-in-depth check that the path is inside the app documents
///   directory.
/// - [coverPath] — nullable, path to extracted cover at
///   `${appDocumentsDir}/covers/{bookId}.jpg` per D-06. Null when the EPUB
///   has no cover image (the UI shows the D-08 fallback).
/// - [importDate] — set to `DateTime.now()` at the insert call site.
/// - [lastReadDate] — null until Phase 3 opens the book at least once.
/// - [readingProgressChapter] — null until Phase 3 records chapter index.
/// - [readingProgressOffset] — null until Phase 3 records a 0.0–1.0 offset
///   within the current chapter. The exact reading position model is a
///   Phase 3 concern; this column is reserved space only.
@DataClassName('Book')
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get filePath => text().unique()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get importDate => dateTime()();
  DateTimeColumn get lastReadDate => dateTime().nullable()();
  IntColumn get readingProgressChapter => integer().nullable()();
  RealColumn get readingProgressOffset => real().nullable()();

  /// Per-book voice override (D-09 / CD-01). NULL = fall back to the
  /// shared_preferences global default. Value is a [ModelManifest] voiceId
  /// string (e.g. 'af_bella'), NOT the positional sherpa sid.
  TextColumn get voiceId => text().named('voice_id').nullable()();

  /// Per-book playback-speed override (PBK-04). NULL = use global default.
  /// Range clamping is a UI concern — migration stays additive and schema-only.
  RealColumn get playbackSpeed => real().named('playback_speed').nullable()();
}
