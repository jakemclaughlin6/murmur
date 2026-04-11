/// Round-trip tests for the [Block] sealed hierarchy JSON codec.
///
/// Covers LIB-03 per 02-VALIDATION.md Wave 0 Requirements.
///
/// D-01: Five block variants (Paragraph, Heading, ImageBlock, Blockquote,
/// ListItem) round-trip losslessly through JSON. D-03: this codec powers the
/// `chapters.blocks_json` storage column introduced in Plan 02-03.
library;

import 'package:murmur/core/epub/block.dart';
import 'package:murmur/core/epub/block_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Block JSON round-trip', () {
    test('Paragraph round-trips with discriminator "paragraph"', () {
      const block = Paragraph('hello');
      final json = block.toJson();
      expect(json, equals({'type': 'paragraph', 'text': 'hello'}));
      expect(blockFromJson(json), equals(block));
    });

    test('Heading round-trips with discriminator "heading"', () {
      final block = Heading(level: 2, text: 'Chapter 1');
      final json = block.toJson();
      expect(
        json,
        equals({'type': 'heading', 'level': 2, 'text': 'Chapter 1'}),
      );
      expect(blockFromJson(json), equals(block));
    });

    test('Heading rejects level < 1 with ArgumentError', () {
      expect(
        () => Heading(level: 0, text: 'bad'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Heading rejects level > 6 with ArgumentError', () {
      expect(
        () => Heading(level: 7, text: 'bad'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Heading accepts levels 1..6 inclusive', () {
      for (var i = 1; i <= 6; i++) {
        expect(Heading(level: i, text: 't').level, equals(i));
      }
    });

    test('ImageBlock round-trips with null alt preserved', () {
      const block = ImageBlock(href: 'cover.jpg', alt: null);
      final json = block.toJson();
      expect(
        json,
        equals({'type': 'image', 'href': 'cover.jpg', 'alt': null}),
      );
      expect(blockFromJson(json), equals(block));
    });

    test('ImageBlock round-trips with non-null alt', () {
      const block = ImageBlock(href: 'fig1.png', alt: 'Figure 1');
      final json = block.toJson();
      expect(
        json,
        equals({'type': 'image', 'href': 'fig1.png', 'alt': 'Figure 1'}),
      );
      expect(blockFromJson(json), equals(block));
    });

    test('Blockquote round-trips with discriminator "blockquote"', () {
      const block = Blockquote('quoted');
      final json = block.toJson();
      expect(json, equals({'type': 'blockquote', 'text': 'quoted'}));
      expect(blockFromJson(json), equals(block));
    });

    test('ListItem (ordered) round-trips with discriminator "list_item"', () {
      const block = ListItem(text: 'item', ordered: true);
      final json = block.toJson();
      expect(
        json,
        equals({'type': 'list_item', 'text': 'item', 'ordered': true}),
      );
      expect(blockFromJson(json), equals(block));
    });

    test('ListItem (unordered) round-trips', () {
      const block = ListItem(text: 'bullet', ordered: false);
      final json = block.toJson();
      expect(
        json,
        equals({'type': 'list_item', 'text': 'bullet', 'ordered': false}),
      );
      expect(blockFromJson(json), equals(block));
    });

    test('blocksToJsonString/blocksFromJsonString round-trip a mixed list', () {
      final blocks = <Block>[
        Heading(level: 1, text: 'Title'),
        const Paragraph('First paragraph.'),
        const Blockquote('A quote.'),
        const ListItem(text: 'one', ordered: true),
        const ListItem(text: 'two', ordered: true),
        const ImageBlock(href: 'img.jpg', alt: 'caption'),
        const Paragraph('Closing.'),
      ];
      final jsonString = blocksToJsonString(blocks);
      final decoded = blocksFromJsonString(jsonString);
      expect(decoded, equals(blocks));
    });

    test('blockFromJson throws FormatException on unknown discriminator', () {
      expect(
        () => blockFromJson({'type': 'table', 'text': 'x'}),
        throwsFormatException,
      );
    });

    test('blockFromJson throws FormatException on missing "type" field', () {
      expect(
        () => blockFromJson({'text': 'x'}),
        throwsFormatException,
      );
    });
  });

  group('Block value equality', () {
    test('Two Paragraphs with the same text are equal', () {
      expect(const Paragraph('a'), equals(const Paragraph('a')));
      expect(const Paragraph('a'), isNot(equals(const Paragraph('b'))));
    });

    test('Two Headings with the same fields are equal', () {
      expect(
        Heading(level: 3, text: 'x'),
        equals(Heading(level: 3, text: 'x')),
      );
      expect(
        Heading(level: 3, text: 'x'),
        isNot(equals(Heading(level: 4, text: 'x'))),
      );
    });

    test('Two ImageBlocks with identical href/alt are equal', () {
      expect(
        const ImageBlock(href: 'h', alt: 'a'),
        equals(const ImageBlock(href: 'h', alt: 'a')),
      );
      expect(
        const ImageBlock(href: 'h', alt: null),
        isNot(equals(const ImageBlock(href: 'h', alt: 'a'))),
      );
    });

    test('Two Blockquotes with identical text are equal', () {
      expect(const Blockquote('q'), equals(const Blockquote('q')));
    });

    test('Two ListItems with identical fields are equal', () {
      expect(
        const ListItem(text: 't', ordered: true),
        equals(const ListItem(text: 't', ordered: true)),
      );
      expect(
        const ListItem(text: 't', ordered: true),
        isNot(equals(const ListItem(text: 't', ordered: false))),
      );
    });
  });
}
