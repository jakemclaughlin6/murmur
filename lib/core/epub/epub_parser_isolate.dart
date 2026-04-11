/// Background-isolate wrapper for [parseEpub] per D-13.
///
/// The parser in `epub_parser.dart` is pure Dart and synchronous from
/// the caller's perspective (well, a Future, but CPU-bound). Walking a
/// 500-chapter book's DOM takes several seconds on mid-range hardware
/// — running that on the UI thread would blow the 60fps budget during
/// batch import. This file moves it to a background isolate.
///
/// **Why `Isolate.run` over `compute()`:** `compute()` lives in
/// `package:flutter/foundation.dart` and is functionally a thin wrapper
/// around `Isolate.run`. Going direct keeps this file Flutter-free so
/// it can be unit-tested without a `TestWidgetsFlutterBinding`.
///
/// **Sendability:** the return type ([ParseResult] + [Block] + its
/// sealed subclasses) is all pure Dart objects with primitive fields,
/// which Dart 3's isolate message serializer handles natively. The
/// thrown exceptions ([DrmDetectedException], [EpubParseException])
/// also marshal cleanly — both implement `Exception` and carry only a
/// String field, which is tested explicitly in
/// `test/core/epub/epub_parser_isolate_test.dart`.
library;

import 'dart:isolate';

import 'epub_parser.dart';
import 'parse_result.dart';

/// Parses [bytes] in a background isolate.
///
/// Throws the same exceptions as [parseEpub] — [DrmDetectedException]
/// and [EpubParseException] — and Dart 3's isolate machinery propagates
/// them to the caller's Future via rethrow.
Future<ParseResult> parseEpubInIsolate(List<int> bytes) {
  return Isolate.run(() => parseEpub(bytes));
}
