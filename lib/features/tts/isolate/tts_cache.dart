// lib/features/tts/isolate/tts_cache.dart
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Synthesized-sentence WAV cache (CD-02).
///
/// Layout: `{cacheRoot}/{bookId}/{chapterIdx}/{sentenceIdx}.wav`.
///
/// - LRU ring per (bookId, chapterIdx): keep last 3 played + up to 2
///   pre-synth = 5 live entries; evict the rest.
/// - Soft cap: 20MB per book. Transient overage during pre-synth is
///   fine; enforcement runs after each SentenceReady.
/// - `wipeBook` is called from the Phase 2 delete flow.
class TtsCache {
  TtsCache({required this.cacheRoot});

  final Directory cacheRoot;
  static const int softCapBytes = 20 * 1024 * 1024;
  static const int liveEntriesPerChapter = 5;

  final Map<String, LinkedHashMap<int, DateTime>> _lru = {};

  static void _requireSafeBookId(String bookId) {
    if (bookId.isEmpty ||
        bookId == '.' ||
        bookId == '..' ||
        bookId.contains('/') ||
        bookId.contains(r'\') ||
        bookId.contains('\x00')) {
      throw ArgumentError.value(
        bookId,
        'bookId',
        'must not contain path separators or traversal segments',
      );
    }
  }

  String pathFor(String bookId, int chapterIdx, int sentenceIdx) {
    _requireSafeBookId(bookId);
    if (chapterIdx < 0 || sentenceIdx < 0) {
      throw ArgumentError('chapterIdx and sentenceIdx must be >= 0');
    }
    final dir = Directory(p.join(cacheRoot.path, bookId, '$chapterIdx'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return p.join(dir.path, '$sentenceIdx.wav');
  }

  void markRecentlyUsed(String bookId, int chapterIdx, int sentenceIdx) {
    _requireSafeBookId(bookId);
    final key = '$bookId:$chapterIdx';
    final map = _lru.putIfAbsent(key, () => LinkedHashMap<int, DateTime>());
    map.remove(sentenceIdx);
    map[sentenceIdx] = DateTime.now();
  }

  void evictLru(String bookId, int chapterIdx) {
    _requireSafeBookId(bookId);
    final key = '$bookId:$chapterIdx';
    final map = _lru[key];
    if (map == null) return;
    while (map.length > liveEntriesPerChapter) {
      final oldestIdx = map.keys.first;
      map.remove(oldestIdx);
      final f = File(p.join(
        cacheRoot.path,
        bookId,
        '$chapterIdx',
        '$oldestIdx.wav',
      ));
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {/* benign */}
      }
    }
  }

  Future<int> totalBytesFor(String bookId) async {
    _requireSafeBookId(bookId);
    final bookDir = Directory(p.join(cacheRoot.path, bookId));
    if (!bookDir.existsSync()) return 0;
    var total = 0;
    await for (final e in bookDir.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<void> enforceSoftCap(String bookId) async {
    _requireSafeBookId(bookId);
    final bookDir = Directory(p.join(cacheRoot.path, bookId));
    if (!bookDir.existsSync()) return;
    final files = <File>[];
    await for (final e in bookDir.list(recursive: true, followLinks: false)) {
      if (e is File) files.add(e);
    }
    files.sort((a, b) =>
        a.statSync().modified.compareTo(b.statSync().modified));

    var total = 0;
    for (final f in files) {
      total += await f.length();
    }
    var i = 0;
    while (total > softCapBytes && i < files.length) {
      final len = await files[i].length();
      try {
        await files[i].delete();
        total -= len;
      } catch (_) {/* benign */}
      i++;
    }
  }

  Future<void> wipeBook(String bookId) async {
    _requireSafeBookId(bookId);
    final bookDir = Directory(p.join(cacheRoot.path, bookId));
    if (bookDir.existsSync()) {
      await bookDir.delete(recursive: true);
    }
    _lru.removeWhere((k, _) => k.startsWith('$bookId:'));
  }
}
