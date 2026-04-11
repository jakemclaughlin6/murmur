/// EPUB parser tests (Plan 02-04 Task 2).
///
/// Covers the 7 behaviors listed in Plan 02-04's `<behavior>` block for
/// Task 2 plus a targeted DOM-walker suite that exercises every Block
/// variant and every D-02 flattening rule against synthetic XHTML.
///
/// Fixtures live under `test/fixtures/epub/` and are built by
/// `test/fixtures/epub/_build_fixtures.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/epub/block.dart';
import 'package:murmur/core/epub/drm_detector.dart';
import 'package:murmur/core/epub/epub_parser.dart';

Future<List<int>> _loadFixture(String name) async {
  final file = File('test/fixtures/epub/$name');
  expect(file.existsSync(), isTrue, reason: 'fixture missing: ${file.path}');
  return file.readAsBytesSync();
}

void main() {
  group('parseEpub end-to-end (fixture corpus)', () {
    test('minimal.epub returns title, author, 1 chapter, 1 paragraph', () async {
      final bytes = await _loadFixture('minimal.epub');
      final result = await parseEpub(bytes);

      expect(result.title, 'Minimal Test');
      expect(result.author, 'Test Author');
      expect(result.coverBytes, isNull);
      expect(result.coverMimeType, isNull);
      expect(result.chapters, hasLength(1));
      expect(result.errors, isEmpty);

      final chapter = result.chapters.single;
      expect(chapter.orderIndex, 0);
      // The chapter XHTML has <h1>Chapter 1</h1><p>Hello world.</p>, so
      // the DOM walker emits a Heading followed by a Paragraph.
      expect(chapter.blocks, hasLength(2));
      expect(chapter.blocks[0], Heading(level: 1, text: 'Chapter 1'));
      expect(chapter.blocks[1], const Paragraph('Hello world.'));
    });

    test('drm_encrypted.epub throws DrmDetectedException BEFORE parsing', () async {
      final bytes = await _loadFixture('drm_encrypted.epub');
      await expectLater(
        () => parseEpub(bytes),
        throwsA(isA<DrmDetectedException>()),
      );
    });

    test('malformed_xhtml.epub recovers — 1 chapter parsed, whole book OK', () async {
      final bytes = await _loadFixture('malformed_xhtml.epub');
      final result = await parseEpub(bytes);

      expect(result.title, 'Minimal Test');
      expect(result.chapters, hasLength(1));
      // package:html is lenient — the unclosed <em> is recovered and the
      // paragraph text still reads correctly. The whole-book contract
      // here is: it does NOT throw, and errors list is either empty or
      // carries at most one flag for the offending chapter.
      expect(result.errors.length, lessThanOrEqualTo(1));
      final chapter = result.chapters.single;
      // At minimum, the "Unclosed tag" text survives in some form.
      final joined = chapter.blocks
          .whereType<Paragraph>()
          .map((p) => p.text)
          .join(' ');
      expect(joined, contains('Unclosed'));
      expect(joined, contains('tag'));
    });

    test('truncated zip throws EpubParseException (not DRM, not Exception)', () async {
      final bytes = (await _loadFixture('minimal.epub')).sublist(0, 100);
      await expectLater(
        () => parseEpub(bytes),
        throwsA(isA<EpubParseException>()),
      );
    });
  });

  group('parseChapterXhtml DOM walker (D-01 / D-02)', () {
    test('emits Heading, Paragraph, Blockquote, ListItem for standard block mix', () {
      const xhtml = '''
<html><body>
<h2>Section Two</h2>
<p>Some paragraph text.</p>
<blockquote>A quoted line.</blockquote>
<ul><li>first</li><li>second</li></ul>
</body></html>
''';
      final blocks = parseChapterXhtml(xhtml);
      expect(blocks, <Block>[
        Heading(level: 2, text: 'Section Two'),
        const Paragraph('Some paragraph text.'),
        const Blockquote('A quoted line.'),
        const ListItem(text: 'first', ordered: false),
        const ListItem(text: 'second', ordered: false),
      ]);
    });

    test('<ol> emits ListItem with ordered:true', () {
      const xhtml = '<html><body><ol><li>one</li><li>two</li></ol></body></html>';
      final blocks = parseChapterXhtml(xhtml);
      expect(blocks, <Block>[
        const ListItem(text: 'one', ordered: true),
        const ListItem(text: 'two', ordered: true),
      ]);
    });

    test('<img> emits ImageBlock with src and alt', () {
      const xhtml = '''
<html><body>
<p>Before image.</p>
<img src="images/fig1.png" alt="A figure"/>
</body></html>
''';
      final blocks = parseChapterXhtml(xhtml);
      expect(blocks, contains(const Paragraph('Before image.')));
      expect(
        blocks.whereType<ImageBlock>(),
        contains(const ImageBlock(href: 'images/fig1.png', alt: 'A figure')),
      );
    });

    test('<table> is flattened to one Paragraph per row (D-02)', () {
      const xhtml = '''
<html><body>
<table>
  <tr><th>Name</th><th>Value</th></tr>
  <tr><td>Foo</td><td>1</td></tr>
  <tr><td>Bar</td><td>2</td></tr>
</table>
</body></html>
''';
      final blocks = parseChapterXhtml(xhtml);
      // Three rows → three paragraphs, NOT a throw.
      expect(blocks.whereType<Paragraph>().toList(), <Paragraph>[
        const Paragraph('Name | Value'),
        const Paragraph('Foo | 1'),
        const Paragraph('Bar | 2'),
      ]);
    });

    test('<aside epub:type="footnote"> becomes Paragraph with [fn] prefix (D-02)', () {
      const xhtml = '''
<html><body>
<p>Main body.</p>
<aside epub:type="footnote">See page 42.</aside>
</body></html>
''';
      final blocks = parseChapterXhtml(xhtml);
      expect(blocks, containsAllInOrder(<Block>[
        const Paragraph('Main body.'),
        const Paragraph('[fn] See page 42.'),
      ]));
    });

    test('whitespace-only and empty paragraphs are skipped', () {
      const xhtml = '<html><body><p>   </p><p></p><p>Real content.</p></body></html>';
      final blocks = parseChapterXhtml(xhtml);
      expect(blocks, <Block>[const Paragraph('Real content.')]);
    });

    test('<div> wrapper recurses into children', () {
      const xhtml = '''
<html><body>
<div class="chapter">
  <h1>Title</h1>
  <div><p>Nested paragraph.</p></div>
</div>
</body></html>
''';
      final blocks = parseChapterXhtml(xhtml);
      expect(blocks, <Block>[
        Heading(level: 1, text: 'Title'),
        const Paragraph('Nested paragraph.'),
      ]);
    });
  });

  group('EpubParseException shape', () {
    test('carries reason and toString contains it', () {
      const ex = EpubParseException('Invalid zip');
      expect(ex.reason, 'Invalid zip');
      expect(ex.toString(), contains('Invalid zip'));
    });
  });
}
