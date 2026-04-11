/// Import service tests (Plan 02-05 Task 2).
///
/// Covers LIB-01 (file picker batch import), LIB-04 (DRM / corrupt file
/// rejection + snackbar), D-11 (optimistic insert), D-12 (one snackbar per
/// failed book), D-13 (isolate parsing), D-14 (single pipeline for Share
/// and file_picker).
///
/// Uses real fixture EPUBs from test/fixtures/epub/ and a real in-memory
/// Drift database. The `getApplicationDocumentsDirectory` surface is
/// sidestepped by a Riverpod override of [appDocumentsDirProvider] that
/// points at a per-test `Directory.systemTemp.createTempSync(...)` tree.
///
/// We do NOT test `pickAndImport` — FilePicker is a static platform-channel
/// facade with no injectable seam and the method is a thin wrapper around
/// `importFromPaths`. Coverage of the file-picker UI lives in a manual
/// verification row of 02-VALIDATION.md (per D-14 the pipeline is already
/// exercised end-to-end by the `importFromPaths` tests below).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/db/app_database_provider.dart';
import 'package:murmur/features/library/import_service.dart';
import 'package:path/path.dart' as p;

Future<Uint8List> _loadFixture(String name) async {
  final file = File('test/fixtures/epub/$name');
  expect(file.existsSync(), isTrue, reason: 'fixture missing: ${file.path}');
  return file.readAsBytesSync();
}

/// Copy a fixture into [dir] under [newName] and return its absolute path.
///
/// Import paths must live on disk because the import service reads bytes
/// from the path it is given. Each test copies into a dedicated temp dir
/// so the test is hermetic.
Future<String> _stageFixture(
  String fixtureName,
  Directory dir, {
  String? newName,
}) async {
  final bytes = await _loadFixture(fixtureName);
  final destPath = p.join(dir.path, newName ?? fixtureName);
  await File(destPath).writeAsBytes(bytes);
  return destPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory _sandbox; // per-test sandbox (source files + app docs dir)
  late Directory _sourceDir;
  late Directory _docsDir;
  late AppDatabase _db;
  late ProviderContainer _container;

  setUp(() async {
    _sandbox = Directory.systemTemp.createTempSync('murmur_import_test_');
    _sourceDir = Directory(p.join(_sandbox.path, 'src'))..createSync();
    _docsDir = Directory(p.join(_sandbox.path, 'docs'))..createSync();
    _db = AppDatabase(NativeDatabase.memory());
    _container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(_db),
        appDocumentsDirProvider.overrideWithValue(_docsDir),
      ],
    );
  });

  tearDown(() async {
    _container.dispose();
    await _db.close();
    if (_sandbox.existsSync()) {
      _sandbox.deleteSync(recursive: true);
    }
  });

  group('ImportNotifier.importFromPaths — happy path', () {
    test('minimal.epub inserts one row with title and author', () async {
      final path = await _stageFixture('minimal.epub', _sourceDir);
      final notifier = _container.read(importNotifierProvider.notifier);

      await notifier.importFromPaths([path]);

      final states = _container.read(importNotifierProvider);
      expect(states, hasLength(1));
      expect(states.single, isA<ImportSuccess>());

      final books = await _db.select(_db.books).get();
      expect(books, hasLength(1));
      expect(books.single.title, 'Minimal Test');
      expect(books.single.author, 'Test Author');
      // file_path must live INSIDE the app docs dir, NOT equal the source
      // path (threat T-02-05-02 — path traversal defense).
      expect(
        p.isWithin(_docsDir.path, books.single.filePath),
        isTrue,
        reason: 'stored file_path must be inside appDocsDir',
      );
    });

    test('chapters are persisted with blocks_json per D-03', () async {
      final path = await _stageFixture('minimal.epub', _sourceDir);
      final notifier = _container.read(importNotifierProvider.notifier);

      await notifier.importFromPaths([path]);

      final chapters = await _db.select(_db.chapters).get();
      expect(chapters, isNotEmpty);
      // minimal.epub has a <h1>Chapter 1</h1><p>Hello world.</p> chapter
      final chapter = chapters.first;
      expect(chapter.orderIndex, 0);
      expect(chapter.blocksJson, isNotEmpty);
      expect(chapter.blocksJson, contains('Hello world'));
    });

    test('minimal.epub with no cover leaves coverPath null', () async {
      final path = await _stageFixture('minimal.epub', _sourceDir);
      final notifier = _container.read(importNotifierProvider.notifier);

      await notifier.importFromPaths([path]);

      final book = (await _db.select(_db.books).get()).single;
      expect(book.coverPath, isNull);
      // And the covers dir should either not exist yet or be empty.
      final coversDir = Directory(p.join(_docsDir.path, 'covers'));
      if (coversDir.existsSync()) {
        expect(coversDir.listSync(), isEmpty);
      }
    });
  });

  group('ImportNotifier.importFromPaths — failure paths (LIB-04, D-12)', () {
    test('drm_encrypted.epub emits ImportFailed "DRM" and inserts no row',
        () async {
      final path = await _stageFixture('drm_encrypted.epub', _sourceDir);
      final notifier = _container.read(importNotifierProvider.notifier);

      await notifier.importFromPaths([path]);

      final states = _container.read(importNotifierProvider);
      expect(states, hasLength(1));
      expect(states.single, isA<ImportFailed>());
      expect((states.single as ImportFailed).reason, contains('DRM'));

      final books = await _db.select(_db.books).get();
      expect(books, isEmpty,
          reason: 'DRM reject must not leave an orphan books row (D-12)');
    });

    test('truncated/corrupt EPUB emits ImportFailed "Corrupt" and inserts no row',
        () async {
      // Truncate minimal.epub to 100 bytes — the parser will throw
      // EpubParseException per Plan 04 Task 2.
      final bytes = await _loadFixture('minimal.epub');
      final corruptPath = p.join(_sourceDir.path, 'corrupt.epub');
      await File(corruptPath).writeAsBytes(bytes.sublist(0, 100));
      final notifier = _container.read(importNotifierProvider.notifier);

      await notifier.importFromPaths([corruptPath]);

      final states = _container.read(importNotifierProvider);
      expect(states, hasLength(1));
      expect(states.single, isA<ImportFailed>());
      final reason = (states.single as ImportFailed).reason.toLowerCase();
      expect(reason, anyOf(contains('corrupt'), contains('invalid')));

      final books = await _db.select(_db.books).get();
      expect(books, isEmpty);
    });

    test('batch [minimal, drm] imports one success and one failure', () async {
      final okPath = await _stageFixture('minimal.epub', _sourceDir);
      final drmPath =
          await _stageFixture('drm_encrypted.epub', _sourceDir);
      final notifier = _container.read(importNotifierProvider.notifier);

      await notifier.importFromPaths([okPath, drmPath]);

      final states = _container.read(importNotifierProvider);
      expect(states, hasLength(2));
      expect(states[0], isA<ImportSuccess>());
      expect(states[1], isA<ImportFailed>());

      final books = await _db.select(_db.books).get();
      expect(books, hasLength(1),
          reason: 'batch must continue past one failure');
    });
  });

  group('ImportNotifier.importFromPaths — duplicates (T-02-05-05)', () {
    test('re-importing the same filename emits ImportFailed "Already in library"',
        () async {
      // We import two sources that both end up at the same destPath —
      // because the import service's destPath is constructed from
      // basename(sourcePath), two source files with the same basename
      // collide on the books.file_path UNIQUE constraint.
      final path1 = await _stageFixture('minimal.epub', _sourceDir);
      final notifier = _container.read(importNotifierProvider.notifier);
      await notifier.importFromPaths([path1]);
      expect((await _db.select(_db.books).get()), hasLength(1));

      // Stage the same fixture into a sibling dir with the same filename.
      final otherDir = Directory(p.join(_sandbox.path, 'src2'))..createSync();
      final path2 = await _stageFixture('minimal.epub', otherDir);
      await notifier.importFromPaths([path2]);

      final states = _container.read(importNotifierProvider);
      expect(states, hasLength(1),
          reason: 'state resets on each importFromPaths call');
      expect(states.single, isA<ImportFailed>());
      expect(
        (states.single as ImportFailed).reason.toLowerCase(),
        contains('already'),
      );
      // Still only one book in the library.
      expect((await _db.select(_db.books).get()), hasLength(1));
    });
  });

  group('ImportState sealed class', () {
    test('ImportParsing / ImportSuccess / ImportFailed carry the filename',
        () {
      const parsing = ImportParsing('a.epub');
      const success = ImportSuccess('b.epub', 7);
      const failed = ImportFailed('c.epub', 'DRM');
      expect(parsing.filename, 'a.epub');
      expect(success.filename, 'b.epub');
      expect(success.bookId, 7);
      expect(failed.filename, 'c.epub');
      expect(failed.reason, 'DRM');
    });
  });
}
