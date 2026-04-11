// Phase 2 Plan 02-01 Task 3 spike test:
//   (A) Verify `epubx ^4.0.0` parses a minimal real EPUB under Dart 3.11
//       without analyzer errors or runtime exceptions.
//   (B) Verify `receive_sharing_intent ^1.8.1` imports cleanly under flutter_test.
//       (Assumption A2 in 02-RESEARCH.md was invalidated: `receive_sharing_intent_plus`
//        ^1.6.0 does not exist on pub.dev. Latest `_plus` is 1.0.1 and is discontinued,
//        pointing back at the maintained `receive_sharing_intent`. Switched in Plan
//        02-01 Task 1.)
//
// ignore: unused_import
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('epubx parses a minimal real EPUB under Dart 3.11', () async {
    final file = File('test/fixtures/spike.epub');
    expect(file.existsSync(), isTrue, reason: 'spike fixture missing');
    final bytes = await file.readAsBytes();
    final book = await EpubReader.readBook(bytes);

    // Assertions: book object is non-null, title is a String, chapters list exists.
    expect(book, isNotNull);
    expect(book.Title, isA<String>());
    expect(book.Chapters, isA<List>());

    // Print observations for spike-notes.md (captured in test output).
    // ignore: avoid_print
    print('SPIKE epubx: title=${book.Title}, author=${book.Author}, '
        'chapters=${book.Chapters?.length}, hasCover=${book.CoverImage != null}');
  });

  test('receive_sharing_intent imports cleanly', () {
    // Import at top of file; if the import line fails to resolve, flutter_test
    // will refuse to compile this file and the failure is visible. The runtime
    // body is a placeholder — import success IS the test.
    expect(true, isTrue);
  });
}
