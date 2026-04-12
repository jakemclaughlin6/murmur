import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:murmur/core/epub/block.dart';
import 'package:murmur/features/reader/widgets/block_renderer.dart';

void main() {
  const fontFamily = 'Literata';
  const fontSize = 16.0;
  const textColor = Colors.black;
  const mutedColor = Colors.grey;

  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('BlockRenderer', () {
    testWidgets('Paragraph produces RepaintBoundary and RichText',
        (tester) async {
      final widget = renderBlock(
        const Paragraph('Hello world. Goodbye world.'),
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        mutedColor: mutedColor,
      );

      await tester.pumpWidget(wrap(widget));

      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(find.byType(RichText), findsOneWidget);
    });

    testWidgets('Heading produces RepaintBoundary and renders text',
        (tester) async {
      final widget = renderBlock(
        Heading(level: 2, text: 'Chapter One'),
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        mutedColor: mutedColor,
      );

      await tester.pumpWidget(wrap(widget));

      expect(find.byType(RepaintBoundary), findsWidgets);
      // Heading text rendered via RichText (single TextSpan, no sentence split)
      final richText = tester.widget<RichText>(find.byType(RichText));
      final span = richText.text as TextSpan;
      expect(span.text, 'Chapter One');
      expect(span.children, isNull);
    });

    testWidgets('Blockquote produces RepaintBoundary and left border',
        (tester) async {
      final widget = renderBlock(
        const Blockquote('To be or not to be.'),
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        mutedColor: mutedColor,
      );

      await tester.pumpWidget(wrap(widget));

      expect(find.byType(RepaintBoundary), findsWidgets);
      // Verify left border decoration exists
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('ListItem produces RepaintBoundary and bullet character',
        (tester) async {
      final widget = renderBlock(
        const ListItem(text: 'First item in list.', ordered: false),
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        mutedColor: mutedColor,
      );

      await tester.pumpWidget(wrap(widget));

      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(find.text('\u2022 '), findsOneWidget);
    });

    testWidgets('ImageBlock with no imagePathMap shows placeholder text',
        (tester) async {
      final widget = renderBlock(
        const ImageBlock(href: 'images/cover.jpg', alt: 'Book cover'),
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        mutedColor: mutedColor,
      );

      await tester.pumpWidget(wrap(widget));

      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(find.text('Book cover'), findsOneWidget);
    });

    testWidgets('ImageBlock with null alt shows "Image" placeholder',
        (tester) async {
      final widget = renderBlock(
        const ImageBlock(href: 'images/photo.png'),
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        mutedColor: mutedColor,
      );

      await tester.pumpWidget(wrap(widget));

      expect(find.text('Image'), findsOneWidget);
    });

    testWidgets('Heading has Semantics wrapper with label', (tester) async {
      final widget = renderBlock(
        Heading(level: 1, text: 'Title'),
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        mutedColor: mutedColor,
      );

      await tester.pumpWidget(wrap(widget));

      // Find the Semantics widget that has the heading label.
      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Title',
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
