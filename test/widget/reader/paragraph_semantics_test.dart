import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:murmur/core/text/sentence_splitter.dart';
import 'package:murmur/features/reader/widgets/paragraph_widget.dart';

void main() {
  const splitter = SentenceSplitter();
  const fontFamily = 'Literata';
  const fontSize = 16.0;
  const textColor = Colors.black;

  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  Widget buildParagraph({
    required String text,
    String family = fontFamily,
    double size = fontSize,
    Color color = textColor,
  }) {
    return wrap(
      ParagraphWidget(
        text: text,
        fontFamily: family,
        fontSize: size,
        textColor: color,
        splitter: splitter,
      ),
    );
  }

  group('ParagraphWidget', () {
    testWidgets('two sentences produce TextSpan with 2 children',
        (tester) async {
      await tester.pumpWidget(buildParagraph(text: 'Hello world. Goodbye world.'));

      final richText = tester.widget<RichText>(find.byType(RichText));
      final parentSpan = richText.text as TextSpan;
      expect(parentSpan.children, hasLength(2));
    });

    testWidgets('Semantics label is the full paragraph text', (tester) async {
      const fullText = 'First sentence. Second sentence.';
      await tester.pumpWidget(buildParagraph(text: fullText));

      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == fullText,
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('ExcludeSemantics wraps RichText', (tester) async {
      await tester.pumpWidget(buildParagraph(text: 'Some text here.'));

      // ExcludeSemantics should be an ancestor of RichText within ParagraphWidget
      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsOneWidget);
      expect(
        find.ancestor(
          of: richTextFinder,
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets, // at least one ExcludeSemantics ancestor
      );
    });

    testWidgets('font family is applied to TextSpan style', (tester) async {
      await tester.pumpWidget(buildParagraph(
        text: 'Test sentence.',
        family: 'Merriweather',
      ));

      final richText = tester.widget<RichText>(find.byType(RichText));
      final parentSpan = richText.text as TextSpan;
      final childSpan = parentSpan.children!.first as TextSpan;
      expect(childSpan.style!.fontFamily, 'Merriweather');
    });

    testWidgets('font size is applied to TextSpan style', (tester) async {
      await tester.pumpWidget(buildParagraph(text: 'Test sentence.', size: 24.0));

      final richText = tester.widget<RichText>(find.byType(RichText));
      final parentSpan = richText.text as TextSpan;
      final childSpan = parentSpan.children!.first as TextSpan;
      expect(childSpan.style!.fontSize, 24.0);
    });

    testWidgets('empty text renders SizedBox.shrink', (tester) async {
      await tester.pumpWidget(buildParagraph(text: ''));

      expect(find.byType(RichText), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('single sentence produces TextSpan with 1 child',
        (tester) async {
      await tester.pumpWidget(buildParagraph(text: 'Just one sentence.'));

      final richText = tester.widget<RichText>(find.byType(RichText));
      final parentSpan = richText.text as TextSpan;
      expect(parentSpan.children, hasLength(1));
    });
  });
}
