// Synthesizes 15 corpus EPUBs exercising every edge case from
// 02-VALIDATION.md §15-EPUB Test Corpus.
//
// Run with:
//   dart run test/fixtures/epub/corpus/_build_corpus.dart
//
// Produces 15 .epub files in this directory. Checked in so tests are
// hermetic. The script exists so anyone can regenerate or extend.
//
// Cases 5 and 6 are scaled down (20 chapters / ~50 KB of images) to keep
// the repo reasonable. The parser code paths they exercise (multi-chapter
// iteration, image-in-chapter handling) are identical regardless of scale.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

const _dir = 'test/fixtures/epub/corpus';

// ---------------------------------------------------------------------------
// Shared EPUB scaffolding
// ---------------------------------------------------------------------------

const String _containerXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

String _contentOpf({
  required String title,
  String? author,
  String version = '3.0',
  List<String> manifestItems = const [],
  List<String> spineItems = const [],
  String? coverMeta,
}) {
  final dcCreator =
      author != null ? '    <dc:creator>$author</dc:creator>\n' : '';
  final coverMetaTag = coverMeta ?? '';
  final manifest = StringBuffer();
  manifest.writeln(
      '    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>');
  for (final item in manifestItems) {
    manifest.writeln('    $item');
  }
  final spine = StringBuffer();
  for (final item in spineItems) {
    spine.writeln('    $item');
  }
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="$version" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="pub-id">urn:uuid:00000000-0000-0000-0000-000000000001</dc:identifier>
    <dc:title>$title</dc:title>
$dcCreator    <dc:language>en</dc:language>
    <meta property="dcterms:modified">2026-04-12T00:00:00Z</meta>
$coverMetaTag  </metadata>
  <manifest>
${manifest.toString()}  </manifest>
  <spine>
${spine.toString()}  </spine>
</package>
''';
}

String _navXhtml(List<String> chapters) {
  final lis = StringBuffer();
  for (var i = 0; i < chapters.length; i++) {
    lis.writeln(
        '    <li><a href="${chapters[i]}">Chapter ${i + 1}</a></li>');
  }
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Nav</title></head>
<body>
<nav epub:type="toc"><ol>
$lis</ol></nav>
</body>
</html>
''';
}

String _chapterXhtml(String title, String body) => '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>$title</title></head>
<body>
<h1>$title</h1>
$body
</body>
</html>
''';

ArchiveFile _stored(String name, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes)..compress = false;
}

ArchiveFile _deflated(String name, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes)..compress = true;
}

ArchiveFile _deflatedBytes(String name, List<int> bytes) {
  return ArchiveFile(name, bytes.length, bytes)..compress = true;
}

void _writeEpub(String path, Archive archive) {
  final encoder = ZipEncoder();
  final bytes = encoder.encode(archive);
  if (bytes == null) throw StateError('ZipEncoder produced no bytes for $path');
  File(path).writeAsBytesSync(bytes);
  // ignore: avoid_print
  print('wrote $path (${bytes.length} bytes)');
}

// ---------------------------------------------------------------------------
// Helpers for building common EPUB variants
// ---------------------------------------------------------------------------

Archive _singleChapterEpub({
  required String title,
  String? author,
  required String chapterBody,
  String version = '3.0',
  List<int>? coverImageBytes,
  String? coverMeta,
}) {
  final a = Archive();
  a.addFile(_stored('mimetype', 'application/epub+zip'));
  a.addFile(_deflated('META-INF/container.xml', _containerXml));

  final manifestItems = <String>[
    '<item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>',
  ];
  final spineItems = <String>[
    '<itemref idref="chapter1"/>',
  ];

  if (coverImageBytes != null) {
    manifestItems.add(
        '<item id="cover-img" href="cover.jpg" media-type="image/jpeg" properties="cover-image"/>');
  }

  a.addFile(_deflated(
    'OEBPS/content.opf',
    _contentOpf(
      title: title,
      author: author,
      version: version,
      manifestItems: manifestItems,
      spineItems: spineItems,
      coverMeta: coverMeta,
    ),
  ));
  a.addFile(_deflated('OEBPS/nav.xhtml', _navXhtml(['chapter1.xhtml'])));
  a.addFile(_deflated(
      'OEBPS/chapter1.xhtml', _chapterXhtml('Chapter 1', chapterBody)));

  if (coverImageBytes != null) {
    a.addFile(_deflatedBytes('OEBPS/cover.jpg', coverImageBytes));
  }

  return a;
}

/// Generates a tiny valid JPEG (smallest possible — ~107 bytes).
/// This is a 1x1 red pixel JPEG for fixture purposes.
List<int> _tinyJpeg() => [
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, //
      0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
      0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06,
      0x05, 0x08, 0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C,
      0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12, 0x13, 0x0F,
      0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
      0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28,
      0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27,
      0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF,
      0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01,
      0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05,
      0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
      0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10,
      0x00, 0x02, 0x01, 0x03, 0x03, 0x02, 0x04, 0x03, 0x05, 0x05,
      0x04, 0x04, 0x00, 0x00, 0x01, 0x7D, 0x01, 0x02, 0x03, 0x00,
      0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51,
      0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
      0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33,
      0x62, 0x72, 0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A,
      0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x34, 0x35, 0x36, 0x37,
      0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
      0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63,
      0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75,
      0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87,
      0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98,
      0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9,
      0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA,
      0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2,
      0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
      0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2,
      0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA,
      0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0x7B, 0x94,
      0x11, 0x00, 0x00, 0x00, 0xFF, 0xD9,
    ];

// ---------------------------------------------------------------------------
// Corpus builders — one function per edge case
// ---------------------------------------------------------------------------

void _buildStandardEpub3() {
  _writeEpub(
    '$_dir/01-standard-epub3.epub',
    _singleChapterEpub(
      title: 'Standard EPUB 3',
      author: 'Test Author',
      chapterBody: '<p>This is a well-formed EPUB 3 test document.</p>\n'
          '<p>It exercises the baseline happy path of the parser.</p>',
    ),
  );
}

void _buildNoCover() {
  // Identical to standard but explicitly no cover image in manifest
  _writeEpub(
    '$_dir/02-no-cover.epub',
    _singleChapterEpub(
      title: 'No Cover Image',
      author: 'Test Author',
      chapterBody: '<p>This EPUB has no cover image in its manifest.</p>',
    ),
  );
}

void _buildNoAuthor() {
  _writeEpub(
    '$_dir/03-no-author.epub',
    _singleChapterEpub(
      title: 'No Author Metadata',
      author: null,
      chapterBody: '<p>This EPUB has no dc:creator element.</p>',
    ),
  );
}

void _buildNonAsciiTitle() {
  _writeEpub(
    '$_dir/04-non-ascii-title.epub',
    _singleChapterEpub(
      title: 'Les Misérables — Àéîöü',
      author: 'Victor Hugo',
      chapterBody:
          '<p>This EPUB tests UTF-8 handling through the parser and Drift.</p>\n'
          '<p>Ñoño café résumé naïve Ωmega.</p>',
    ),
  );
}

void _buildVeryLong() {
  // 20 chapters (scaled down from 500 — same iteration code path)
  final a = Archive();
  a.addFile(_stored('mimetype', 'application/epub+zip'));
  a.addFile(_deflated('META-INF/container.xml', _containerXml));

  const chapterCount = 20;
  final manifestItems = <String>[];
  final spineItems = <String>[];
  final chapterFiles = <String>[];

  for (var i = 1; i <= chapterCount; i++) {
    final id = 'ch$i';
    final file = 'chapter$i.xhtml';
    manifestItems.add(
        '<item id="$id" href="$file" media-type="application/xhtml+xml"/>');
    spineItems.add('<itemref idref="$id"/>');
    chapterFiles.add(file);
    a.addFile(_deflated(
      'OEBPS/$file',
      _chapterXhtml('Chapter $i', '<p>Content of chapter $i.</p>'),
    ));
  }

  a.addFile(_deflated(
    'OEBPS/content.opf',
    _contentOpf(
      title: 'Very Long Book (20 Chapters)',
      author: 'Prolific Writer',
      manifestItems: manifestItems,
      spineItems: spineItems,
    ),
  ));
  a.addFile(_deflated('OEBPS/nav.xhtml', _navXhtml(chapterFiles)));
  _writeEpub('$_dir/05-very-long.epub', a);
}

void _buildImageHeavy() {
  // Several chapters with image references (small synthetic JPEGs)
  final a = Archive();
  a.addFile(_stored('mimetype', 'application/epub+zip'));
  a.addFile(_deflated('META-INF/container.xml', _containerXml));

  final jpeg = _tinyJpeg();
  final manifestItems = <String>[];
  final spineItems = <String>[];
  final chapterFiles = <String>[];

  // 5 chapters, each referencing 3 images
  for (var ch = 1; ch <= 5; ch++) {
    final chId = 'ch$ch';
    final chFile = 'chapter$ch.xhtml';
    manifestItems.add(
        '<item id="$chId" href="$chFile" media-type="application/xhtml+xml"/>');
    spineItems.add('<itemref idref="$chId"/>');
    chapterFiles.add(chFile);

    final bodyParts = StringBuffer();
    for (var img = 1; img <= 3; img++) {
      final imgName = 'img_${ch}_$img.jpg';
      manifestItems.add(
          '<item id="img${ch}_$img" href="$imgName" media-type="image/jpeg"/>');
      a.addFile(_deflatedBytes('OEBPS/$imgName', jpeg));
      bodyParts.writeln('<p>Text before image $img.</p>');
      bodyParts.writeln('<img src="$imgName" alt="Image $img"/>');
    }
    bodyParts.writeln('<p>End of chapter $ch.</p>');

    a.addFile(_deflated(
      'OEBPS/$chFile',
      _chapterXhtml('Chapter $ch', bodyParts.toString()),
    ));
  }

  a.addFile(_deflated(
    'OEBPS/content.opf',
    _contentOpf(
      title: 'Image Heavy Book',
      author: 'Illustrator',
      manifestItems: manifestItems,
      spineItems: spineItems,
    ),
  ));
  a.addFile(_deflated('OEBPS/nav.xhtml', _navXhtml(chapterFiles)));
  _writeEpub('$_dir/06-image-heavy.epub', a);
}

void _buildTables() {
  _writeEpub(
    '$_dir/07-tables.epub',
    _singleChapterEpub(
      title: 'Tables in Content',
      author: 'Data Author',
      chapterBody: '''
<p>A chapter with table markup.</p>
<table>
  <tr><th>Name</th><th>Value</th></tr>
  <tr><td>Alpha</td><td>100</td></tr>
  <tr><td>Beta</td><td>200</td></tr>
  <tr><td>Gamma</td><td>300</td></tr>
</table>
<p>Text after the table.</p>
''',
    ),
  );
}

void _buildFootnotes() {
  _writeEpub(
    '$_dir/08-footnotes.epub',
    _singleChapterEpub(
      title: 'Footnoted Edition',
      author: 'Scholar',
      chapterBody: '''
<p>Main text with a footnote reference.</p>
<aside epub:type="footnote">This is a footnote explaining the reference.</aside>
<p>More main text continues here.</p>
<aside epub:type="note">This is an editorial note.</aside>
''',
    ),
  );
}

void _buildBlockquotesLists() {
  _writeEpub(
    '$_dir/09-blockquotes-lists.epub',
    _singleChapterEpub(
      title: 'Quotes and Lists',
      author: 'Philosopher',
      chapterBody: '''
<p>Introduction paragraph.</p>
<blockquote>To be or not to be, that is the question.</blockquote>
<p>A numbered list follows:</p>
<ol>
  <li>First ordered item</li>
  <li>Second ordered item</li>
  <li>Third ordered item</li>
</ol>
<p>And an unordered list:</p>
<ul>
  <li>Bullet point alpha</li>
  <li>Bullet point beta</li>
</ul>
<blockquote>Another famous quote for good measure.</blockquote>
''',
    ),
  );
}

void _buildMalformedXhtml() {
  _writeEpub(
    '$_dir/10-malformed-xhtml.epub',
    _singleChapterEpub(
      title: 'Malformed XHTML',
      author: 'Sloppy Publisher',
      chapterBody: '''
<p>Paragraph with unclosed <em>emphasis tag</p>
<p>Another paragraph with <strong>unclosed bold</p>
<p>Nested <div>block inside paragraph</div> which is invalid.</p>
<p class=>Attribute with no value.</p>
<p>Final valid paragraph.</p>
''',
    ),
  );
}

void _buildEpub2() {
  // EPUB 2 uses version="2.0" and NCX for TOC instead of nav
  final a = Archive();
  a.addFile(_stored('mimetype', 'application/epub+zip'));
  a.addFile(_deflated('META-INF/container.xml', _containerXml));

  a.addFile(_deflated('OEBPS/content.opf', '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="pub-id">urn:uuid:00000000-0000-0000-0000-000000000011</dc:identifier>
    <dc:title>EPUB 2 Format</dc:title>
    <dc:creator>Old Publisher</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="chapter1"/>
  </spine>
</package>
'''));

  a.addFile(_deflated('OEBPS/toc.ncx', '''
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="urn:uuid:00000000-0000-0000-0000-000000000011"/></head>
  <docTitle><text>EPUB 2 Format</text></docTitle>
  <navMap>
    <navPoint id="ch1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="chapter1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>
'''));

  a.addFile(_deflated(
    'OEBPS/chapter1.xhtml',
    _chapterXhtml(
        'Chapter 1', '<p>Content from an EPUB 2 format book.</p>'),
  ));

  _writeEpub('$_dir/11-epub2.epub', a);
}

void _buildSpineReordering() {
  // Chapters in manifest order 1,2,3 but spine order is 3,1,2
  final a = Archive();
  a.addFile(_stored('mimetype', 'application/epub+zip'));
  a.addFile(_deflated('META-INF/container.xml', _containerXml));

  a.addFile(_deflated('OEBPS/content.opf', _contentOpf(
    title: 'Spine Reordered',
    author: 'Shuffler',
    manifestItems: [
      '<item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>',
      '<item id="ch2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>',
      '<item id="ch3" href="chapter3.xhtml" media-type="application/xhtml+xml"/>',
    ],
    spineItems: [
      '<itemref idref="ch3"/>',
      '<itemref idref="ch1"/>',
      '<itemref idref="ch2"/>',
    ],
  )));

  a.addFile(_deflated('OEBPS/nav.xhtml',
      _navXhtml(['chapter3.xhtml', 'chapter1.xhtml', 'chapter2.xhtml'])));
  a.addFile(_deflated('OEBPS/chapter1.xhtml',
      _chapterXhtml('Chapter 1', '<p>First in manifest, second in spine.</p>')));
  a.addFile(_deflated('OEBPS/chapter2.xhtml',
      _chapterXhtml('Chapter 2', '<p>Second in manifest, third in spine.</p>')));
  a.addFile(_deflated('OEBPS/chapter3.xhtml',
      _chapterXhtml('Chapter 3', '<p>Third in manifest, first in spine.</p>')));

  _writeEpub('$_dir/12-spine-reordering.epub', a);
}

void _buildDrmProtected() {
  // Standard EPUB with META-INF/encryption.xml added → DRM marker
  final a = _singleChapterEpub(
    title: 'DRM Protected',
    author: 'Locked Publisher',
    chapterBody: '<p>This content is encrypted.</p>',
  );
  a.addFile(_deflated('META-INF/encryption.xml', '''
<?xml version="1.0" encoding="UTF-8"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
</encryption>
'''));
  _writeEpub('$_dir/13-drm-protected.epub', a);
}

void _buildCorruptZip() {
  // Take a valid EPUB and truncate to 50% → invalid zip
  final validBytes = ZipEncoder().encode(_singleChapterEpub(
    title: 'Will Be Corrupted',
    author: 'Nobody',
    chapterBody: '<p>This will be truncated.</p>',
  ))!;
  final truncated = validBytes.sublist(0, validBytes.length ~/ 2);
  File('$_dir/14-corrupt-zip.epub').writeAsBytesSync(truncated);
  // ignore: avoid_print
  print('wrote $_dir/14-corrupt-zip.epub (${truncated.length} bytes, truncated)');
}

void _buildMultiCover() {
  // EPUB with two images that both look like cover candidates
  final a = Archive();
  a.addFile(_stored('mimetype', 'application/epub+zip'));
  a.addFile(_deflated('META-INF/container.xml', _containerXml));

  final jpeg = _tinyJpeg();
  a.addFile(_deflatedBytes('OEBPS/cover.jpg', jpeg));
  a.addFile(_deflatedBytes('OEBPS/cover-alt.jpg', jpeg));

  a.addFile(_deflated('OEBPS/content.opf', _contentOpf(
    title: 'Multiple Cover Candidates',
    author: 'Designer',
    manifestItems: [
      '<item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>',
      '<item id="cover-img" href="cover.jpg" media-type="image/jpeg" properties="cover-image"/>',
      '<item id="cover-alt" href="cover-alt.jpg" media-type="image/jpeg"/>',
    ],
    spineItems: [
      '<itemref idref="chapter1"/>',
    ],
    coverMeta: '    <meta name="cover" content="cover-alt"/>\n',
  )));

  a.addFile(_deflated('OEBPS/nav.xhtml', _navXhtml(['chapter1.xhtml'])));
  a.addFile(_deflated(
    'OEBPS/chapter1.xhtml',
    _chapterXhtml('Chapter 1',
        '<p>This book has two images that could be the cover.</p>'),
  ));

  _writeEpub('$_dir/15-multi-cover.epub', a);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  Directory(_dir).createSync(recursive: true);

  _buildStandardEpub3();
  _buildNoCover();
  _buildNoAuthor();
  _buildNonAsciiTitle();
  _buildVeryLong();
  _buildImageHeavy();
  _buildTables();
  _buildFootnotes();
  _buildBlockquotesLists();
  _buildMalformedXhtml();
  _buildEpub2();
  _buildSpineReordering();
  _buildDrmProtected();
  _buildCorruptZip();
  _buildMultiCover();

  // Verify count
  final count = Directory(_dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.epub'))
      .length;
  // ignore: avoid_print
  print('\nCorpus complete: $count EPUBs');
  if (count != 15) {
    // ignore: avoid_print
    print('WARNING: expected 15 EPUBs, got $count');
    exit(1);
  }
}
