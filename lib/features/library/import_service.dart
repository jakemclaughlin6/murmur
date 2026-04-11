/// Plan 02-05: import pipeline.
///
/// Single entry point (per D-14) for BOTH LIB-01 (file picker) and
/// LIB-02 (Share / Open-in) EPUB imports:
///
///   pickAndImport()       -> file_picker -> importFromPaths()
///   importFromPaths(...)  -> parser isolate -> cover write -> Drift insert
///
/// Per D-13 the parse runs inside `Isolate.run` via
/// `parseEpubInIsolate`, so the UI thread stays 60fps responsive during
/// batch import. Per D-11 the notifier emits one `ImportParsing` state
/// per path up front, then resolves each to `ImportSuccess` or
/// `ImportFailed` as the parse completes.
///
/// Threat mitigations:
/// - T-02-05-02 (path traversal): destination paths are constructed from
///   `p.basename(sourcePath)` plus the app docs dir. The user-supplied
///   source path never becomes the stored `file_path`.
/// - T-02-05-03 (zip bomb / parser stall): 30-second timeout on the
///   isolate call. The isolate itself prevents a UI freeze even before
///   the timeout fires.
/// - T-02-05-04 (cover image bomb): 10 MB cap on coverBytes before
///   writing to `${appDocumentsDir}/covers/`. Oversized covers are
///   dropped — the book still imports with `coverPath = null`.
/// - T-02-05-05 (duplicate import race): `books.file_path` has a UNIQUE
///   constraint (Plan 02-03). The notifier catches the resulting
///   `SqliteException` and emits `ImportFailed(reason: 'Already in library')`.
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show SqliteException;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/app_database.dart';
import '../../core/db/app_database_provider.dart';
import '../../core/epub/block_json.dart';
import '../../core/epub/drm_detector.dart';
import '../../core/epub/epub_parser.dart' show EpubParseException;
import '../../core/epub/epub_parser_isolate.dart';
import '../../core/epub/parse_result.dart';

part 'import_service.g.dart';

/// Upper bound for cover art bytes (T-02-05-04). Anything larger than
/// this is dropped — the book still imports, it just has no cover.
const int _kCoverMaxBytes = 10 * 1024 * 1024;

/// Upper bound for a single parse operation in the isolate (T-02-05-03).
/// 30s is long enough for a 1000-page book on mid-range hardware and
/// short enough to catch a stall / zip-bomb.
const Duration _kParseTimeout = Duration(seconds: 30);

// ---------------------------------------------------------------------------
// Public Riverpod seam: app documents dir.
// ---------------------------------------------------------------------------

/// The directory the import service writes EPUBs and covers into.
///
/// In production this resolves to `getApplicationDocumentsDirectory()`
/// via `path_provider`. Tests override this provider to point at a
/// per-test `Directory.systemTemp.createTempSync(...)` sandbox so the
/// service does not need a `TestDefaultBinaryMessengerBinding` +
/// `PathProviderPlatform` mock to run.
///
/// `keepAlive: true` because the resolved directory never changes
/// during an app session.
@Riverpod(keepAlive: true)
Future<Directory> appDocumentsDir(Ref ref) async {
  return getApplicationDocumentsDirectory();
}

// ---------------------------------------------------------------------------
// Per-book import state (Plan 07 renders shimmer / real / error cards
// from this sealed hierarchy per D-11).
// ---------------------------------------------------------------------------

/// State of a single in-flight or just-finished import.
///
/// Kept as a sealed class so Plan 07 can exhaustive-switch on the three
/// variants when rendering per-card UI. `filename` carries the basename
/// of the source path at import start — the notifier never reveals the
/// full source path to the UI (privacy: we don't want "imported from
/// /Users/alice/secret/" to appear in a snackbar).
sealed class ImportState {
  final String filename;
  const ImportState(this.filename);
}

/// The EPUB is being parsed + persisted. Plan 07 renders this as a
/// shimmer placeholder card.
class ImportParsing extends ImportState {
  const ImportParsing(super.filename);
}

/// Import succeeded; [bookId] is the inserted `books.id`.
class ImportSuccess extends ImportState {
  final int bookId;
  const ImportSuccess(super.filename, this.bookId);
}

/// Import failed. [reason] is a short, user-displayable string — D-12
/// shows this verbatim in the snackbar, so it must not contain PII or
/// the source path.
class ImportFailed extends ImportState {
  final String reason;
  const ImportFailed(super.filename, this.reason);
}

// ---------------------------------------------------------------------------
// The notifier.
// ---------------------------------------------------------------------------

/// Single import pipeline for both file_picker (LIB-01) and Share /
/// Open-in (LIB-02) per D-14.
///
/// `keepAlive: true` because the notifier outlives widget rebuilds —
/// a freshly-mounted library screen should pick up an already-running
/// import without restarting it.
@Riverpod(keepAlive: true)
class ImportNotifier extends _$ImportNotifier {
  @override
  List<ImportState> build() => const <ImportState>[];

  /// LIB-02 / LIB-01 entry point:
  /// imports EPUBs from already-resolved file paths per D-14.
  ///
  /// Each path is processed sequentially — per-file parallelism is
  /// intentionally avoided because `Isolate.run` spawns a full
  /// isolate per call and a batch of 20 EPUBs launching in parallel
  /// would thrash memory on mid-range phones.
  Future<void> importFromPaths(List<String> paths) async {
    if (paths.isEmpty) return;

    // D-11: seed the state with one ImportParsing per path up front so
    // the library grid can render shimmer cards immediately.
    state = [for (final path in paths) ImportParsing(p.basename(path))];

    final db = ref.read(appDatabaseProvider);
    final appDocs = await ref.read(appDocumentsDirProvider.future);

    final booksDir = Directory(p.join(appDocs.path, 'books'));
    final coversDir = Directory(p.join(appDocs.path, 'covers'));
    if (!booksDir.existsSync()) booksDir.createSync(recursive: true);
    // Covers dir is created lazily — only if we actually write a cover.

    final newStates = <ImportState>[...state];

    for (var i = 0; i < paths.length; i++) {
      final sourcePath = paths[i];
      final filename = p.basename(sourcePath);
      try {
        newStates[i] = await _importOne(
          sourcePath: sourcePath,
          filename: filename,
          db: db,
          booksDir: booksDir,
          coversDir: coversDir,
        );
      } on DrmDetectedException {
        newStates[i] = ImportFailed(filename, 'DRM-protected');
      } on EpubParseException catch (e) {
        newStates[i] = ImportFailed(filename, 'Corrupt: ${e.reason}');
      } on SqliteException catch (e) {
        if (e.message.toUpperCase().contains('UNIQUE')) {
          newStates[i] = ImportFailed(filename, 'Already in library');
        } else {
          newStates[i] = ImportFailed(filename, 'Database error');
        }
      } on FileSystemException catch (e) {
        newStates[i] = ImportFailed(filename, 'File error: ${e.message}');
      } catch (_) {
        // Unknown error — catch-all so one bad book never blows up the
        // whole batch. D-12 snackbar is generic in this case.
        newStates[i] = ImportFailed(filename, 'Unknown error');
      }
      // Publish partial progress after every file so Plan 07's shimmer
      // cards resolve one-at-a-time as the batch works through.
      state = List<ImportState>.unmodifiable(newStates);
    }
  }

  /// Imports a single EPUB. Throws typed exceptions on failure so the
  /// caller can map them to [ImportFailed] reasons.
  ///
  /// Split out so the exception-to-state mapping lives in exactly one
  /// place ([importFromPaths]).
  Future<ImportSuccess> _importOne({
    required String sourcePath,
    required String filename,
    required AppDatabase db,
    required Directory booksDir,
    required Directory coversDir,
  }) async {
    // 1. Read source bytes.
    final bytes = await File(sourcePath).readAsBytes();

    // 2. Parse in a background isolate with a 30s timeout (T-02-05-03).
    //    parseEpubInIsolate re-throws DrmDetectedException and
    //    EpubParseException across the isolate boundary intact.
    final ParseResult parsed =
        await parseEpubInIsolate(bytes).timeout(_kParseTimeout);

    // 3. Compute the destination path INSIDE the app docs dir, using
    //    only the basename of the source path (T-02-05-02 defense).
    final destPath = p.join(booksDir.path, filename);

    // 4. Copy the source file to its new home. We do this BEFORE the
    //    DB insert so that if the copy fails we haven't written an
    //    unreachable books row. If the DB insert fails AFTER the copy
    //    (e.g. duplicate filename), clean up the copied file.
    await File(sourcePath).copy(destPath);

    late int bookId;
    try {
      // 5. Insert the Books row. coverPath is null at this point —
      //    we'll update it below once we know bookId.
      bookId = await db.into(db.books).insert(
            BooksCompanion.insert(
              title: parsed.title,
              author: Value<String?>(parsed.author),
              filePath: destPath,
              coverPath: const Value<String?>(null),
              importDate: DateTime.now(),
            ),
          );
    } catch (e) {
      // Roll back the copied file so UNIQUE-constraint failures don't
      // leave orphan EPUB bytes in the books/ dir. Swallow any cleanup
      // error because the primary error is more important.
      try {
        final copied = File(destPath);
        if (copied.existsSync()) copied.deleteSync();
      } catch (_) {}
      rethrow;
    }

    // 6. Write the cover image if present AND within size budget
    //    (T-02-05-04). Cover failures are non-fatal — the book stays.
    String? coverPath;
    final coverBytes = parsed.coverBytes;
    if (coverBytes != null && coverBytes.length <= _kCoverMaxBytes) {
      if (!coversDir.existsSync()) coversDir.createSync(recursive: true);
      coverPath = p.join(coversDir.path, '$bookId.jpg');
      try {
        await File(coverPath).writeAsBytes(coverBytes);
        await (db.update(db.books)..where((b) => b.id.equals(bookId)))
            .write(BooksCompanion(coverPath: Value<String?>(coverPath)));
      } catch (_) {
        // Cover write failed — leave coverPath null, the book still
        // imports and the D-08 fallback renders in place of the image.
        coverPath = null;
      }
    }

    // 7. Persist chapters with blocksJson (D-03).
    for (final ch in parsed.chapters) {
      await db.into(db.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              orderIndex: ch.orderIndex,
              title: Value<String?>(ch.title),
              blocksJson: blocksToJsonString(ch.blocks),
            ),
          );
    }

    return ImportSuccess(filename, bookId);
  }
}
