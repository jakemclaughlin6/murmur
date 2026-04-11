// One-off fixture builder for Phase 02 Plan 04 parser tests.
//
// Run with:
//   dart run test/fixtures/epub/_build_fixtures.dart
//
// Produces three synthetic EPUB 3 files next to this script:
//
//   minimal.epub         — valid EPUB 3, 1 chapter, 1 paragraph, no cover
//   drm_encrypted.epub   — same as minimal + empty META-INF/encryption.xml
//   malformed_xhtml.epub — same as minimal but chapter XHTML has an
//                          unclosed <em> tag (package:html should recover)
//
// These are checked in so tests are hermetic — the script exists only so
// anyone can regenerate or extend the corpus without guessing the EPUB
// layout. Do not invoke it as part of the normal test run.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

const String _containerXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

const String _contentOpf = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="pub-id">urn:uuid:00000000-0000-0000-0000-000000000001</dc:identifier>
    <dc:title>Minimal Test</dc:title>
    <dc:creator>Test Author</dc:creator>
    <dc:language>en</dc:language>
    <meta property="dcterms:modified">2026-04-11T00:00:00Z</meta>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chapter1"/>
  </spine>
</package>
''';

const String _navXhtml = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Nav</title></head>
<body>
<nav epub:type="toc"><ol><li><a href="chapter1.xhtml">Chapter 1</a></li></ol></nav>
</body>
</html>
''';

const String _cleanChapterXhtml = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 1</title></head>
<body>
<h1>Chapter 1</h1>
<p>Hello world.</p>
</body>
</html>
''';

const String _malformedChapterXhtml = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 1</title></head>
<body>
<h1>Chapter 1</h1>
<p>Unclosed <em>tag</p>
</body>
</html>
''';

ArchiveFile _stored(String name, String content) {
  final bytes = content.codeUnits;
  return ArchiveFile(name, bytes.length, bytes)
    ..compress = false; // "mimetype" + metadata entries are stored, not deflated.
}

ArchiveFile _deflated(String name, String content) {
  final bytes = content.codeUnits;
  return ArchiveFile(name, bytes.length, bytes)..compress = true;
}

Archive _baseArchive({required String chapterXhtml}) {
  final a = Archive();
  // EPUB spec: "mimetype" MUST be the first entry and MUST be stored uncompressed.
  a.addFile(_stored('mimetype', 'application/epub+zip'));
  a.addFile(_deflated('META-INF/container.xml', _containerXml));
  a.addFile(_deflated('OEBPS/content.opf', _contentOpf));
  a.addFile(_deflated('OEBPS/nav.xhtml', _navXhtml));
  a.addFile(_deflated('OEBPS/chapter1.xhtml', chapterXhtml));
  return a;
}

void _writeEpub(String path, Archive archive) {
  final encoder = ZipEncoder();
  final bytes = encoder.encode(archive);
  if (bytes == null) {
    throw StateError('ZipEncoder produced no bytes for $path');
  }
  File(path).writeAsBytesSync(bytes);
  // ignore: avoid_print
  print('wrote $path (${bytes.length} bytes)');
}

void main() {
  const dir = 'test/fixtures/epub';
  Directory(dir).createSync(recursive: true);

  // 1) minimal.epub — the happy path
  _writeEpub('$dir/minimal.epub', _baseArchive(chapterXhtml: _cleanChapterXhtml));

  // 2) drm_encrypted.epub — adds an empty META-INF/encryption.xml marker
  final drm = _baseArchive(chapterXhtml: _cleanChapterXhtml);
  drm.addFile(_deflated('META-INF/encryption.xml', ''));
  _writeEpub('$dir/drm_encrypted.epub', drm);

  // 3) malformed_xhtml.epub — unclosed <em> tag; package:html should recover.
  _writeEpub(
    '$dir/malformed_xhtml.epub',
    _baseArchive(chapterXhtml: _malformedChapterXhtml),
  );
}
