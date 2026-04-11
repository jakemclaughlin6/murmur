/// Block Intermediate Representation per D-01 (Phase 2 CONTEXT).
///
/// Stored as JSON in `chapters.blocks_json` per D-03. Richer EPUB constructs
/// (tables, footnotes, sidebars) are flattened to the nearest equivalent at
/// parse time per D-02 — no sixth Block variant.
///
/// TDD RED stub: types exist with minimal signatures so tests compile, but
/// equality is intentionally unimplemented. Filled in during GREEN step.
library;

sealed class Block {
  const Block();
}

class Paragraph extends Block {
  final String text;
  const Paragraph(this.text);
}

class Heading extends Block {
  final int level;
  final String text;
  const Heading({required this.level, required this.text});
}

class ImageBlock extends Block {
  final String href;
  final String? alt;
  const ImageBlock({required this.href, this.alt});
}

class Blockquote extends Block {
  final String text;
  const Blockquote(this.text);
}

class ListItem extends Block {
  final String text;
  final bool ordered;
  const ListItem({required this.text, required this.ordered});
}
