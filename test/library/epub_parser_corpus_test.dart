/// 15-EPUB corpus validation (Plan 02-08 Task 2).
///
/// Covers LIB-03 per 02-VALIDATION.md. Iterates every .epub in
/// test/fixtures/epub/corpus/ and verifies:
/// - Valid EPUBs parse to a ParseResult with non-empty title and chapters
/// - DRM-protected (#13) throws DrmDetectedException
/// - Corrupt zip (#14) throws EpubParseException
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/epub/drm_detector.dart';
import 'package:murmur/core/epub/epub_parser.dart';

void main() {
  final corpusDir = Directory('test/fixtures/epub/corpus');
  if (!corpusDir.existsSync()) {
    throw StateError(
        'Corpus directory missing — run: dart run test/fixtures/epub/corpus/_build_corpus.dart');
  }

  final files = corpusDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.epub'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('corpus contains exactly 15 EPUBs', () {
    expect(files.length, 15, reason: 'Expected 15 corpus EPUBs per 02-VALIDATION.md');
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;

    if (name.contains('drm-protected')) {
      test('rejects $name (DRM)', () async {
        final bytes = file.readAsBytesSync();
        await expectLater(
          parseEpub(bytes),
          throwsA(isA<DrmDetectedException>()),
        );
      });
    } else if (name.contains('corrupt-zip')) {
      test('rejects $name (corrupt)', () async {
        final bytes = file.readAsBytesSync();
        await expectLater(
          parseEpub(bytes),
          throwsA(isA<EpubParseException>()),
        );
      });
    } else {
      test('parses $name', () async {
        final bytes = file.readAsBytesSync();
        final result = await parseEpub(bytes);
        expect(result.title, isNotEmpty, reason: 'Valid EPUBs must have a title');
        expect(result.chapters, isNotEmpty,
            reason: 'Valid EPUBs must have at least 1 chapter');

        // Edge-case-specific assertions
        if (name.contains('no-cover')) {
          expect(result.coverBytes, isNull,
              reason: 'No-cover EPUB should have null coverBytes');
        }
        if (name.contains('no-author')) {
          expect(result.author, isNull,
              reason: 'No-author EPUB should have null author');
        }
        if (name.contains('non-ascii')) {
          expect(result.title, contains('Misérables'),
              reason: 'Non-ASCII title must survive UTF-8 round-trip');
        }
        if (name.contains('very-long')) {
          expect(result.chapters.length, greaterThanOrEqualTo(20),
              reason: 'Very-long EPUB should have 20+ chapters');
        }
        if (name.contains('malformed')) {
          // Should parse without errors — package:html is lenient
          expect(result.chapters.first.blocks, isNotEmpty,
              reason: 'Malformed XHTML should still yield blocks via lenient parser');
        }
      });
    }
  }
}
