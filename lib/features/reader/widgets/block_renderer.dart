import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/epub/block.dart';
import '../../../core/text/sentence_splitter.dart';
import 'paragraph_widget.dart';

/// Converts a [Block] IR node into a Flutter widget for the reader.
///
/// Uses Dart 3 exhaustive switch on the sealed Block hierarchy.
/// Every widget is wrapped in [RepaintBoundary] per RDR-03 to prevent
/// cross-paragraph repaints during scroll.
Widget renderBlock(
  Block block, {
  required String fontFamily,
  required double fontSize,
  required Color textColor,
  required Color mutedColor,
  Map<String, String>? imagePathMap,
  SentenceSplitter? splitter,
}) {
  final effectiveSplitter = splitter ?? const SentenceSplitter();

  return switch (block) {
    Paragraph(text: final text) => RepaintBoundary(
      child: ParagraphWidget(
        text: text,
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        splitter: effectiveSplitter,
      ),
    ),
    Heading(level: final level, text: final text) => RepaintBoundary(
      child: _HeadingWidget(
        level: level,
        text: text,
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
      ),
    ),
    Blockquote(text: final text) => RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: mutedColor, width: 3)),
        ),
        child: ParagraphWidget(
          text: text,
          fontFamily: fontFamily,
          fontSize: fontSize,
          textColor: mutedColor,
          splitter: effectiveSplitter,
        ),
      ),
    ),
    ListItem(text: final text, ordered: final ordered) => RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ordered ? '\u2022 ' : '\u2022 ', // bullet for both; ordered numbering is a future enhancement
              style: TextStyle(fontSize: fontSize, color: textColor),
            ),
            Expanded(
              child: ParagraphWidget(
                text: text,
                fontFamily: fontFamily,
                fontSize: fontSize,
                textColor: textColor,
                splitter: effectiveSplitter,
              ),
            ),
          ],
        ),
      ),
    ),
    ImageBlock(href: final href, alt: final alt) => RepaintBoundary(
      child: _ImageBlockWidget(
        href: href,
        alt: alt,
        imagePathMap: imagePathMap,
      ),
    ),
  };
}

/// Renders a heading as a single [TextSpan] (no sentence splitting per D-04).
///
/// Font size scales by heading level. [Semantics] wraps the heading for
/// accessibility (RDR-05).
class _HeadingWidget extends StatelessWidget {
  const _HeadingWidget({
    required this.level,
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.textColor,
  });

  final int level;
  final String text;
  final String fontFamily;
  final double fontSize;
  final Color textColor;

  double get _scaledFontSize => switch (level) {
    1 => fontSize * 1.8,
    2 => fontSize * 1.5,
    3 => fontSize * 1.3,
    4 => fontSize * 1.15,
    _ => fontSize * 1.05, // h5, h6
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Semantics(
        header: true,
        label: text,
        child: ExcludeSemantics(
          child: RichText(
            text: TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: _scaledFontSize,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders an image block from the EPUB.
///
/// Looks up [href] in [imagePathMap] to get a local file path. If the path
/// is found and the file exists, renders [Image.file]. Otherwise shows a
/// placeholder with the alt text.
class _ImageBlockWidget extends StatelessWidget {
  const _ImageBlockWidget({
    required this.href,
    this.alt,
    this.imagePathMap,
  });

  final String href;
  final String? alt;
  final Map<String, String>? imagePathMap;

  @override
  Widget build(BuildContext context) {
    final localPath = imagePathMap?[href]
        ?? imagePathMap?[p.normalize(href)]
        ?? imagePathMap?[p.basename(href)];

    if (localPath != null && File(localPath).existsSync()) {
      return Semantics(
        image: true,
        label: alt ?? 'Image',
        child: ExcludeSemantics(
          child: Image.file(
            File(localPath),
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
      );
    }

    // Placeholder when image is not available.
    return Semantics(
      image: true,
      label: alt ?? 'Image',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: Center(
            child: Text(
              alt ?? 'Image',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
