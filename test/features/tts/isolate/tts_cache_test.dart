// test/features/tts/isolate/tts_cache_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';

void main() {
  late Directory tempRoot;
  late TtsCache cache;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('tts_cache_test_');
    cache = TtsCache(cacheRoot: tempRoot);
  });

  tearDown(() async {
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  test('pathFor creates parent dirs and returns expected structure', () {
    final path = cache.pathFor('bookA', 3, 7);
    expect(path, endsWith('bookA/3/7.wav'));
    expect(Directory('${tempRoot.path}/bookA/3').existsSync(), isTrue);
  });

  test('pathFor rejects bookId with traversal or separators', () {
    expect(() => cache.pathFor('..', 0, 0), throwsArgumentError);
    expect(() => cache.pathFor('a/b', 0, 0), throwsArgumentError);
    expect(() => cache.pathFor('../evil', 0, 0), throwsArgumentError);
    expect(() => cache.pathFor(r'a\b', 0, 0), throwsArgumentError);
    expect(() => cache.pathFor('', 0, 0), throwsArgumentError);
    expect(() => cache.pathFor('.', 0, 0), throwsArgumentError);
  });

  test('LRU keeps 5 most-recent per chapter, deletes the rest', () async {
    for (var i = 0; i < 7; i++) {
      final p = cache.pathFor('bookA', 0, i);
      await File(p).writeAsBytes(List.filled(1024, i & 0xff));
      cache.markRecentlyUsed('bookA', 0, i);
    }
    cache.evictLru('bookA', 0);

    final surviving = Directory('${tempRoot.path}/bookA/0')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(surviving, {'2.wav', '3.wav', '4.wav', '5.wav', '6.wav'});
  });

  test('soft cap evicts oldest mtime until under 20MB', () async {
    const mb = 1024 * 1024;
    for (var i = 0; i < 25; i++) {
      final p = cache.pathFor('bookA', 0, i);
      await File(p).writeAsBytes(List.filled(mb, 0));
      await File(p).setLastModified(
        DateTime.fromMillisecondsSinceEpoch(1700000000000 + i * 1000),
      );
    }
    await cache.enforceSoftCap('bookA');
    final total = await cache.totalBytesFor('bookA');
    expect(total, lessThanOrEqualTo(20 * mb));
    expect(File(cache.pathFor('bookA', 0, 0)).existsSync(), isFalse);
    expect(File(cache.pathFor('bookA', 0, 24)).existsSync(), isTrue);
  });

  test('wipeBook deletes bookId subtree only', () async {
    await File(cache.pathFor('bookA', 0, 0))
        .writeAsBytes(List.filled(1024, 0));
    await File(cache.pathFor('bookB', 0, 0))
        .writeAsBytes(List.filled(1024, 0));

    await cache.wipeBook('bookA');

    expect(Directory('${tempRoot.path}/bookA').existsSync(), isFalse);
    expect(File(cache.pathFor('bookB', 0, 0)).existsSync(), isTrue);
  });

  test('wipeBook rejects traversal input', () async {
    expect(() => cache.wipeBook('..'), throwsArgumentError);
    expect(() => cache.wipeBook('a/b'), throwsArgumentError);
    expect(() => cache.wipeBook(''), throwsArgumentError);
  });
}
