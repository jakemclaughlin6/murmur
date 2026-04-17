import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/db/app_database_provider.dart';
import 'package:murmur/features/library/library_provider.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_cache_provider.dart';

void main() {
  late Directory tempRoot;
  late TtsCache cache;
  late AppDatabase db;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('wipe_test_');
    cache = TtsCache(cacheRoot: tempRoot);
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  test('deleteBook invokes TtsCache.wipeBook(bookId.toString())', () async {
    final id = await db.into(db.books).insert(
          BooksCompanion.insert(
            title: 'Moby-Dick',
            author: const Value('Herman Melville'),
            filePath: '/tmp/moby.epub',
            importDate: DateTime.now(),
          ),
        );

    final wavPath = cache.pathFor(id.toString(), 0, 0);
    await File(wavPath).writeAsBytes(List.filled(64, 0));
    expect(File(wavPath).existsSync(), isTrue);

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      ttsCacheProvider.overrideWithValue(cache),
    ]);
    addTearDown(container.dispose);

    await container.read(libraryProvider.notifier).deleteBook(id);

    expect(File(wavPath).existsSync(), isFalse);
    expect(
      Directory('${tempRoot.path}/$id').existsSync(),
      isFalse,
      reason: 'Book subtree should be removed',
    );
  });
}
