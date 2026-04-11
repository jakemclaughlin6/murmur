import 'package:flutter/material.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key});

  // D-12: "a single sample paragraph rendered via RichText in the currently
  // selected reader font and theme" — Claude's discretion on text choice.
  // Middlemarch opening (public domain) is under 150 words and shows off the
  // serif family's quotation marks, small caps, and hyphenation behavior.
  static const _samplePassage =
      'Miss Brooke had that kind of beauty which seems to be thrown into '
      'relief by poor dress. Her hand and wrist were so finely formed that '
      'she could wear sleeves not less bare of style than those in which '
      'the Blessed Virgin appeared to Italian painters; and her profile as '
      'well as her stature and bearing seemed to gain the more dignity from '
      'her plain garments, which by the side of provincial fashion gave her '
      'the impressiveness of a fine quotation from the Bible,—or from one '
      'of our elder poets,—in a paragraph of to-day\'s newspaper.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary =
        theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;

    return Scaffold(
      key: const Key('reader-screen'),
      appBar: AppBar(
        title: const Text('Reader'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: SingleChildScrollView(
            child: RichText(
              text: TextSpan(
                text: _samplePassage,
                style: TextStyle(
                  fontFamily: 'Literata',
                  fontSize: 18,
                  height: 1.6,
                  color: primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
