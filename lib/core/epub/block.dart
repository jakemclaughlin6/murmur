/// Block Intermediate Representation per D-01 (Phase 2 CONTEXT).
///
/// The EPUB parser (Plan 02-04) walks chapter XHTML with `package:html` and
/// emits `List<Block>` per chapter. Drift stores it as `chapters.blocks_json`
/// per D-03. The reader (Phase 3) reads this IR directly — no HTML at
/// render time.
///
/// Richer EPUB constructs that don't fit the five variants (tables,
/// footnotes, sidebars) are flattened to the nearest equivalent at parse
/// time per D-02 — tables become a series of [Paragraph]s, footnotes become
/// a [Paragraph] with a marker prefix. No sixth variant is ever added
/// without a new phase-level decision.
library;

/// Sealed root of the Block hierarchy. Exhaustive switching on [Block]
/// subtypes (Dart 3 sealed-class pattern) gives the codec and the renderer
/// compile-time safety — adding a variant without updating every switch is
/// a compile error.
sealed class Block {
  const Block();
}

/// A run of body text.
final class Paragraph extends Block {
  final String text;

  const Paragraph(this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Paragraph && other.text == text);

  @override
  int get hashCode => Object.hash(runtimeType, text);

  @override
  String toString() => 'Paragraph($text)';
}

/// An EPUB heading, `h1`..`h6`. [level] is validated 1..6 inclusive at
/// construction.
final class Heading extends Block {
  /// EPUB heading level, 1..6 inclusive.
  final int level;
  final String text;

  Heading({required this.level, required this.text}) {
    if (level < 1 || level > 6) {
      throw ArgumentError.value(
        level,
        'level',
        'Heading level must be between 1 and 6 inclusive',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Heading && other.level == level && other.text == text);

  @override
  int get hashCode => Object.hash(runtimeType, level, text);

  @override
  String toString() => 'Heading(level: $level, text: $text)';
}

/// An embedded image reference. [href] is the EPUB-internal href relative to
/// the chapter XHTML (i.e. exactly what `<img src="...">` carried).
final class ImageBlock extends Block {
  /// EPUB-internal href relative to the chapter XHTML.
  final String href;

  /// `alt` attribute if present, else null.
  final String? alt;

  const ImageBlock({required this.href, this.alt});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageBlock && other.href == href && other.alt == alt);

  @override
  int get hashCode => Object.hash(runtimeType, href, alt);

  @override
  String toString() => 'ImageBlock(href: $href, alt: $alt)';
}

/// A block quote. Multi-paragraph quotes are flattened into a single
/// concatenated [text] by the parser — downstream sentence splitting
/// operates on [text] directly.
final class Blockquote extends Block {
  final String text;

  const Blockquote(this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Blockquote && other.text == text);

  @override
  int get hashCode => Object.hash(runtimeType, text);

  @override
  String toString() => 'Blockquote($text)';
}

/// A single `<li>` from a `<ul>` or `<ol>`. [ordered] is true for `<ol>`,
/// false for `<ul>`. Nested lists are flattened to a single level by the
/// parser; the reader does not render indent levels.
final class ListItem extends Block {
  final String text;

  /// `true` for `<ol>`, `false` for `<ul>`.
  final bool ordered;

  const ListItem({required this.text, required this.ordered});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListItem &&
          other.text == text &&
          other.ordered == ordered);

  @override
  int get hashCode => Object.hash(runtimeType, text, ordered);

  @override
  String toString() => 'ListItem(text: $text, ordered: $ordered)';
}
