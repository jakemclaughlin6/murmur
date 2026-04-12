/// Persistence round-trip test (Plan 02-08 Task 2).
///
/// Covers LIB-11 per 02-VALIDATION.md: imported books re-hydrate from
/// Drift after a simulated app restart (DB close + reopen from the same
/// file). Uses the same provider override pattern as import_service_test.dart.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/db/app_database_provider.dart';
import 'package:murmur/features/library/import_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('book survives DB reopen (LIB-11)', () async {
    // Use a persistent file so reopen actually tests persistence,
    // not just in-memory state.
    final tempDir = Directory.systemTemp.createTempSync('murmur_persist_');
    final dbFile = File(p.join(tempDir.path, 'test.sqlite'));
    final docsDir = Directory(p.join(tempDir.path, 'docs'))..createSync();
    final sourceDir = Directory(p.join(tempDir.path, 'src'))..createSync();
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    // Stage the fixture into sourceDir (import reads from path on disk).
    final fixtureBytes = File('test/fixtures/epub/minimal.epub').readAsBytesSync();
    final sourcePath = p.join(sourceDir.path, 'minimal.epub');
    File(sourcePath).writeAsBytesSync(fixtureBytes);

    // --- Session 1: open DB, import, verify ---
    final db1 = AppDatabase(NativeDatabase(dbFile));
    final container1 = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db1),
        appDocumentsDirProvider.overrideWith((ref) async => docsDir),
      ],
    );

    final notifier = container1.read(importProvider.notifier);
    await notifier.importFromPaths([sourcePath]);

    final states = container1.read(importProvider);
    expect(states.whereType<ImportSuccess>(), isNotEmpty,
        reason: 'Import must succeed in session 1');

    final booksBefore = await db1.select(db1.books).get();
    expect(booksBefore, hasLength(1));
    final titleBefore = booksBefore.first.title;
    final authorBefore = booksBefore.first.author;

    final chaptersBefore = await db1.select(db1.chapters).get();
    expect(chaptersBefore, isNotEmpty, reason: 'Chapters must persist with the book');
    final chapterCountBefore = chaptersBefore.length;

    // --- Close session 1 ---
    container1.dispose();
    await db1.close();

    // --- Session 2: reopen from same file, verify data survived ---
    final db2 = AppDatabase(NativeDatabase(dbFile));
    addTearDown(() async => db2.close());

    final booksAfter = await db2.select(db2.books).get();
    expect(booksAfter, hasLength(1), reason: 'Book must survive DB reopen');
    expect(booksAfter.first.title, titleBefore,
        reason: 'Title must be identical after reopen');
    expect(booksAfter.first.author, authorBefore,
        reason: 'Author must be identical after reopen');

    final chaptersAfter = await db2.select(db2.chapters).get();
    expect(chaptersAfter.length, chapterCountBefore,
        reason: 'Chapter count must be identical after reopen');
    expect(chaptersAfter.first.blocksJson, isNotEmpty,
        reason: 'blocksJson must persist');
  });
}
