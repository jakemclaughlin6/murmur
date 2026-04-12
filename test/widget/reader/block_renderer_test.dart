import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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

    testWidgets('ImageBlock with relative href resolves via basename fallback',
        (tester) async {
      // Create a real temp image file so File.existsSync() passes.
      final tmpDir = Directory.systemTemp.createTempSync('img_render_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      final imgFile = File(p.join(tmpDir.path, 'test.png'));
      // Write minimal valid PNG bytes (1x1 transparent pixel).
      imgFile.writeAsBytesSync([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, // RGBA
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT
        0x54, 0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02,
        0x00, 0x01, 0xE5, 0x27, 0xDE, 0xFC, 0x00, 0x00,
        0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
        0x60, 0x82, // IEND
      ]);

      // href has '../' prefix but the map only has the basename.
      final widget = renderBlock(
        const ImageBlock(href: '../images/test.png', alt: 'Test image'),
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        mutedColor: mutedColor,
        imagePathMap: {'test.png': imgFile.path},
      );

      await tester.pumpWidget(wrap(widget));

      // Should render an Image.file, NOT the placeholder text.
      expect(find.text('Test image'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('ImageBlock with internal ../ resolves via normalize fallback',
        (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('img_render_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      final imgFile = File(p.join(tmpDir.path, 'fig.png'));
      imgFile.writeAsBytesSync([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02,
        0x00, 0x01, 0xE5, 0x27, 0xDE, 0xFC, 0x00, 0x00,
        0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
        0x60, 0x82,
      ]);

      // href 'text/../images/fig.png' normalizes to 'images/fig.png'
      // which IS in the map. This tests internal ../ collapsing.
      final widget = renderBlock(
        const ImageBlock(href: 'text/../images/fig.png', alt: 'Figure'),
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        mutedColor: mutedColor,
        imagePathMap: {'images/fig.png': imgFile.path},
      );

      await tester.pumpWidget(wrap(widget));

      expect(find.text('Figure'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
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
