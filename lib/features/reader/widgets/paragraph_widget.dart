import 'package:flutter/material.dart';

import '../../../core/text/sentence.dart';
import '../../../core/text/sentence_splitter.dart';

/// Renders a paragraph as a [RichText] with one [TextSpan] per [Sentence].
///
/// This is the permanent sentence-span architecture (RDR-04). Each sentence
/// is a separate TextSpan child so Phase 5 can apply per-sentence highlight
/// styles by changing individual TextSpan.style.backgroundColor.
///
/// Accessibility (RDR-05): Outer [Semantics] provides the full paragraph
/// text as a single label. [ExcludeSemantics] around the [RichText] prevents
/// screen readers from announcing individual TextSpans as separate elements.
class ParagraphWidget extends StatelessWidget {
  const ParagraphWidget({
    super.key,
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.textColor,
    required this.splitter,
  });

  final String text;
  final String fontFamily;
  final double fontSize;
  final Color textColor;
  final SentenceSplitter splitter;

  @override
  Widget build(BuildContext context) {
    final sentences = splitter.split(text);
    if (sentences.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        // RDR-05: paragraph-level semantics
        label: text,
        child: ExcludeSemantics(
          child: RichText(
            text: TextSpan(
              children: sentences.map((Sentence s) => TextSpan(
                text: s.text,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: fontSize,
                  height: 1.6,
                  color: textColor,
                ),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
