/// Pure-Dart EPUB parser (Plan 02-04).
///
/// Converts raw EPUB bytes into a [ParseResult] carrying the Block IR
/// per D-01/D-02. Rejects DRM-protected EPUBs up front per LIB-04.
/// Degrades gracefully on malformed chapters per the 02-CONTEXT.md
/// "Claude's Discretion" note — a parse failure on chapter N records a
/// [ChapterError] and continues with chapter N+1 rather than failing
/// the whole book.
///
/// **Purity:** this file imports ZERO Flutter packages. It runs inside
/// `Isolate.run` via `epub_parser_isolate.dart` per D-13.
///
/// **Pipeline:**
///   1. `ZipDecoder().decodeBytes(bytes)`           (corrupt zip → throw)
///   2. `detectDrm(archive)`                        (DRM marker → throw)
///   3. `EpubReader.readBook(bytes)`                (metadata + chapters)
///   4. Flatten sub-chapters, walk each XHTML with `package:html`
///   5. Extract cover bytes (JPEG-encoded from the decoded Image)
///   6. Return [ParseResult]
///
/// The DOM walker rules live in [_walkBlocks]; they map 1:1 onto the
/// five [Block] variants plus the D-02 flattening rules for tables,
/// footnotes, and sidebars.
library;

import 'package:archive/archive.dart';
import 'package:epubx/epubx.dart' as epubx;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as images;

import 'block.dart';
import 'drm_detector.dart';
import 'parse_result.dart';

/// Thrown on any unrecoverable parse failure that is NOT DRM-related.
///
/// Distinct from [DrmDetectedException] so the import service can show a
/// different user-facing message if product later wants to, even though
/// Phase 2's D-12 snackbar currently treats both identically.
class EpubParseException implements Exception {
  final String reason;
  const EpubParseException(this.reason);

  @override
  String toString() => 'EpubParseException: $reason';
}

/// Parses [bytes] into a [ParseResult].
///
/// Throws:
/// - [DrmDetectedException] when the archive carries a DRM marker
///   (checked BEFORE any XHTML parsing runs).
/// - [EpubParseException] on a corrupt zip, missing OPF, or any other
///   unrecoverable metadata error.
///
/// Per-chapter XHTML errors are captured into [ParseResult.errors] and
/// do NOT throw — the book still imports with an empty-block chapter
/// where the parse failed.
///
/// Async because `epubx.EpubReader.readBook` is async; `Isolate.run`
/// accepts `FutureOr<R>` so this composes cleanly with
/// `epub_parser_isolate.dart`.
Future<ParseResult> parseEpub(List<int> bytes) async {
  // Step A — decode the zip. Anything that comes out of ZipDecoder that
  // isn't a well-formed archive is an EpubParseException (NOT DRM).
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    throw EpubParseException('Invalid zip: $e');
  }

  // Step B — DRM short-circuit. Per LIB-04 and T-02-04-02: we bail out
  // BEFORE any XHTML is walked. A DRM book must never have its content
  // touched, even transitively.
  if (detectDrm(archive)) {
    throw const DrmDetectedException('EPUB is DRM-protected');
  }

  // Step C/D — hand the bytes to epubx for OPF + chapter loading.
  // Spike verdict (see spike-notes.md): epubx ^4.0.0 works under Dart 3.11
  // for the happy path; edge-case handling is this parser's job.
  final epubx.EpubBook book;
  try {
    book = await epubx.EpubReader.readBook(bytes);
  } catch (e) {
    throw EpubParseException('Failed to read EPUB metadata: $e');
  }

  // Title is required. An EPUB with no title is treated as corrupt.
  final String? rawTitle = book.Title;
  if (rawTitle == null || rawTitle.trim().isEmpty) {
    throw const EpubParseException('EPUB has no title');
  }
  final String title = rawTitle.trim();

  // Author is optional. epubx joins multiple creators with ", " — we
  // keep that flat string because the Books table is a single author
  // column per D-05.
  String? author = book.Author?.trim();
  if (author != null && author.isEmpty) author = null;

  // Step E — walk chapters. epubx returns a tree of EpubChapter with
  // nested SubChapters; the spine order is the pre-order traversal of
  // that tree. We flatten it and assign sequential orderIndex values.
  final rawChapters = _flattenChapters(book.Chapters ?? const <epubx.EpubChapter>[]);
  final parsedChapters = <ParsedChapter>[];
  final chapterErrors = <ChapterError>[];

  for (var i = 0; i < rawChapters.length; i++) {
    final epubx.EpubChapter chapter = rawChapters[i];
    final String? chapterTitle = (chapter.Title != null && chapter.Title!.trim().isNotEmpty)
        ? chapter.Title!.trim()
        : null;
    final String? xhtml = chapter.HtmlContent;

    List<Block> blocks;
    try {
      blocks = (xhtml == null || xhtml.isEmpty)
          ? const <Block>[]
          : parseChapterXhtml(xhtml);
    } catch (e) {
      // Graceful degradation: record the error, continue with the next
      // chapter. Per the "Claude's Discretion" note in 02-CONTEXT.md —
      // one malformed chapter never kills a whole book import.
      chapterErrors.add(ChapterError(i, 'XHTML parse failed: $e'));
      blocks = const <Block>[];
    }

    parsedChapters.add(
      ParsedChapter(orderIndex: i, title: chapterTitle, blocks: blocks),
    );
  }

  // Step F — cover. epubx decodes the cover into an `images.Image`; we
  // re-encode to JPEG because Plan 05 (D-06) writes covers to disk as
  // `${bookId}.jpg`. The re-encode is lossy relative to an original PNG
  // but acceptable for the "quiet library" grid use case at phone/tablet
  // sizes. If a future phase wants original bytes, extract from the
  // archive manifest directly rather than going through epubx.
  List<int>? coverBytes;
  String? coverMimeType;
  final images.Image? decoded = book.CoverImage;
  if (decoded != null) {
    try {
      coverBytes = images.encodeJpg(decoded, quality: 85);
      coverMimeType = 'image/jpeg';
    } catch (_) {
      // Cover encoding failure is non-fatal — the book still imports,
      // just without a cover. D-08 fallback (oat-tone placeholder) kicks
      // in at the UI layer.
      coverBytes = null;
      coverMimeType = null;
    }
  }

  return ParseResult(
    title: title,
    author: author,
    coverBytes: coverBytes,
    coverMimeType: coverMimeType,
    chapters: parsedChapters,
    errors: chapterErrors,
  );
}

/// Depth-first flatten of the EpubChapter tree in spine order.
///
/// epubx returns chapters as a forest where each `EpubChapter` may carry
/// `SubChapters`. Pre-order traversal preserves the visual reading order
/// the OPF spine advertises.
List<epubx.EpubChapter> _flattenChapters(List<epubx.EpubChapter> tree) {
  final out = <epubx.EpubChapter>[];
  void visit(epubx.EpubChapter c) {
    out.add(c);
    final subs = c.SubChapters;
    if (subs != null) {
      for (final s in subs) {
        visit(s);
      }
    }
  }

  for (final c in tree) {
    visit(c);
  }
  return out;
}

/// Walks one chapter's XHTML and emits a `List<Block>` per D-01/D-02.
///
/// Uses `package:html` (the lenient HTML5 parser) — NOT `package:xml` —
/// because chapter XHTML in the wild is rarely strict XML. Entities,
/// unclosed tags, and stray whitespace are all tolerated.
///
/// Public for unit tests; callers in production should go through
/// [parseEpub].
List<Block> parseChapterXhtml(String xhtml) {
  final dom.Document doc = html_parser.parse(xhtml);
  final dom.Element? body = doc.body;
  if (body == null) return const <Block>[];

  final blocks = <Block>[];
  _walkBlocks(body, blocks);
  return blocks;
}

/// Recursive DOM walker. Appends [Block]s to [out] in document order.
///
/// Rules mirror the plan's &lt;action&gt; block:
/// - `<p>`                              → `Paragraph`
/// - `<h1>`..`<h6>`                     → `Heading(level: N)`
/// - `<img>`                            → `ImageBlock(href, alt)`
/// - `<blockquote>`                     → `Blockquote` (flat text)
/// - `<ul>/<ol>` + `<li>`               → one `ListItem` per `<li>`
/// - `<table>`                          → one `Paragraph` per `<tr>` with
///                                        cells joined by " | " (D-02)
/// - `<aside epub:type="footnote">` or
///   `<aside epub:type="note">`         → `Paragraph` prefixed with "[fn] "
/// - `<div>`, `<section>`, `<article>`  → recurse into children
/// - unknown element with text          → wrap in `Paragraph`
/// - text nodes at body level           → wrap in `Paragraph` if non-empty
void _walkBlocks(dom.Element parent, List<Block> out) {
  for (final node in parent.nodes) {
    if (node is dom.Text) {
      final t = _normalizeWhitespace(node.text);
      if (t.isNotEmpty) out.add(Paragraph(t));
      continue;
    }
    if (node is! dom.Element) continue;
    final dom.Element el = node;
    final String? tag = el.localName?.toLowerCase();

    switch (tag) {
      case 'p':
        final t = _normalizeWhitespace(el.text);
        if (t.isNotEmpty) out.add(Paragraph(t));
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        final level = int.parse(tag!.substring(1));
        final t = _normalizeWhitespace(el.text);
        if (t.isNotEmpty) {
          out.add(Heading(level: level, text: t));
        }
      case 'img':
        final src = el.attributes['src'];
        if (src != null && src.isNotEmpty) {
          out.add(ImageBlock(href: src, alt: el.attributes['alt']));
        }
      case 'blockquote':
        final t = _normalizeWhitespace(el.text);
        if (t.isNotEmpty) out.add(Blockquote(t));
      case 'ul':
      case 'ol':
        final ordered = tag == 'ol';
        for (final li in el.getElementsByTagName('li')) {
          final t = _normalizeWhitespace(li.text);
          if (t.isNotEmpty) out.add(ListItem(text: t, ordered: ordered));
        }
      case 'table':
        // D-02: flatten table rows into paragraphs. Cell text joined by
        // " | " preserves some semantic grouping without pretending the
        // reader can render a grid.
        for (final row in el.getElementsByTagName('tr')) {
          final cells = row.children
              .map((c) => _normalizeWhitespace(c.text))
              .where((t) => t.isNotEmpty)
              .join(' | ');
          if (cells.isNotEmpty) out.add(Paragraph(cells));
        }
      case 'aside':
        // D-02: footnotes and sidebars become paragraphs with a marker
        // prefix so the content isn't silently dropped. The marker lets
        // the sentence splitter in Phase 3 recognize and softly demote
        // them if it wants to.
        final epubType = el.attributes['epub:type']?.toLowerCase() ?? '';
        final t = _normalizeWhitespace(el.text);
        if (t.isNotEmpty) {
          if (epubType.contains('footnote') || epubType.contains('note')) {
            out.add(Paragraph('[fn] $t'));
          } else {
            out.add(Paragraph(t));
          }
        }
      case 'div':
      case 'section':
      case 'article':
      case 'main':
      case 'header':
      case 'footer':
      case 'nav':
      case 'figure':
        _walkBlocks(el, out);
      case 'script':
      case 'style':
      case 'link':
      case 'meta':
        // Drop non-content elements silently.
        break;
      default:
        // Unknown element — best-effort text extract. If it has
        // element children, recurse; otherwise take its text content.
        if (el.children.isNotEmpty) {
          _walkBlocks(el, out);
        } else {
          final t = _normalizeWhitespace(el.text);
          if (t.isNotEmpty) out.add(Paragraph(t));
        }
    }
  }
}

/// Collapse runs of whitespace to a single space and trim. Matches what
/// a browser's `textContent` would render for the reader at display time.
String _normalizeWhitespace(String s) {
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
