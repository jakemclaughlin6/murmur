import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/app_database_provider.dart';

part 'reading_progress_provider.g.dart';

/// Debounced reading progress saver (D-12, RDR-11).
///
/// Accepts scroll offset updates and saves to Drift after a 2-second
/// debounce. Also provides [flushNow] for AppLifecycleState.paused.
@riverpod
class ReadingProgressNotifier extends _$ReadingProgressNotifier {
  Timer? _debounceTimer;
  int? _pendingBookId;
  int? _pendingChapter;
  double? _pendingOffset;
  late final AppDatabase _db;

  @override
  void build() {
    // Eagerly capture DB reference so _flushPending doesn't need ref.read.
    // ref.read is forbidden inside onDispose callbacks in Riverpod 3.
    _db = ref.read(appDatabaseProvider);

    // Cleanup timer on dispose (T-03-12)
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
  }

  /// Called on every scroll offset change. Debounces for 2 seconds.
  void onScrollChanged(int bookId, int chapterIndex, double offsetFraction) {
    _pendingBookId = bookId;
    _pendingChapter = chapterIndex;
    _pendingOffset = offsetFraction;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _flushPending();
    });
  }

  /// Called on AppLifecycleState.paused -- immediate flush.
  void flushNow() {
    _debounceTimer?.cancel();
    _flushPending();
  }

  void _flushPending() {
    if (_pendingBookId == null ||
        _pendingChapter == null ||
        _pendingOffset == null) {
      return;
    }
    _db.updateReadingProgress(_pendingBookId!, _pendingChapter!, _pendingOffset!);
    _pendingBookId = null;
    _pendingChapter = null;
    _pendingOffset = null;
  }
}
