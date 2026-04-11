/// Isolate wrapper tests (Plan 02-04 Task 3).
///
/// Verifies that:
///   1. Happy path — parseEpubInIsolate(minimal) returns the same
///      ParseResult shape as the in-process parser.
///   2. DrmDetectedException crosses the isolate boundary intact.
///   3. EpubParseException crosses the isolate boundary intact.
///
/// Threat T-02-04-06 (exception type loss across isolate boundary) is
/// what drives tests 2 and 3. Dart 3's `Isolate.run` machinery should
/// preserve the thrown Exception subclass, but this is the kind of
/// thing that silently regresses across SDK bumps — pinning it in a
/// test makes the regression loud.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/epub/block.dart';
import 'package:murmur/core/epub/drm_detector.dart';
import 'package:murmur/core/epub/epub_parser.dart';
import 'package:murmur/core/epub/epub_parser_isolate.dart';

Future<List<int>> _loadFixture(String name) async {
  final file = File('test/fixtures/epub/$name');
  expect(file.existsSync(), isTrue, reason: 'fixture missing: ${file.path}');
  return file.readAsBytesSync();
}

void main() {
  group('parseEpubInIsolate', () {
    test('happy path — returns a ParseResult matching in-process parseEpub', () async {
      final bytes = await _loadFixture('minimal.epub');

      final inIsolate = await parseEpubInIsolate(bytes);
      final inProcess = await parseEpub(bytes);

      // Compare the user-visible shape — blocks use value equality per
      // block.dart's == overrides, and ParseResult itself doesn't (it's
      // a one-shot container), so we spot-check the important fields.
      expect(inIsolate.title, inProcess.title);
      expect(inIsolate.author, inProcess.author);
      expect(inIsolate.chapters.length, inProcess.chapters.length);
      expect(inIsolate.errors.length, inProcess.errors.length);

      // Per-chapter comparison: Block subclasses implement value equality,
      // so the lists should compare deep-equal across the isolate boundary.
      for (var i = 0; i < inIsolate.chapters.length; i++) {
        final a = inIsolate.chapters[i];
        final b = inProcess.chapters[i];
        expect(a.orderIndex, b.orderIndex);
        expect(a.title, b.title);
        expect(a.blocks.length, b.blocks.length);
        for (var j = 0; j < a.blocks.length; j++) {
          expect(a.blocks[j], b.blocks[j]);
        }
      }

      // Sanity — make sure the minimal fixture actually round-tripped the
      // expected content, not two empty ParseResults that happen to match.
      expect(inIsolate.title, 'Minimal Test');
      expect(
        inIsolate.chapters.single.blocks,
        containsAllInOrder(<Block>[
          Heading(level: 1, text: 'Chapter 1'),
          const Paragraph('Hello world.'),
        ]),
      );
    });

    test('DrmDetectedException propagates across the isolate boundary', () async {
      final bytes = await _loadFixture('drm_encrypted.epub');

      // Primary assertion: the specific exception subclass survives the
      // isolate boundary. If a future Dart SDK regression breaks subclass
      // marshaling, this assertion is the canary.
      await expectLater(
        () => parseEpubInIsolate(bytes),
        throwsA(isA<DrmDetectedException>()),
      );

      // Secondary assertion: the reason string also survives, so the
      // import service can still produce a useful snackbar even if some
      // future version of Dart returns a re-wrapped exception.
      try {
        await parseEpubInIsolate(bytes);
        fail('expected DrmDetectedException');
      } catch (e) {
        expect(e.toString(), contains('DRM-protected'));
      }
    });

    test('EpubParseException propagates across the isolate boundary', () async {
      // Construct a truncated zip by lopping off all but the first 100
      // bytes of a good fixture — ZipDecoder will throw on the partial
      // archive, which we remap to EpubParseException in parseEpub.
      final fullBytes = await _loadFixture('minimal.epub');
      final truncated = fullBytes.sublist(0, 100);

      await expectLater(
        () => parseEpubInIsolate(truncated),
        throwsA(isA<EpubParseException>()),
      );

      try {
        await parseEpubInIsolate(truncated);
        fail('expected EpubParseException');
      } catch (e) {
        expect(e.toString(), contains('Invalid zip'));
      }
    });
  });
}
