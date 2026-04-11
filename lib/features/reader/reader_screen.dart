import 'package:flutter/material.dart';

import '../../core/theme/clay_colors.dart';

/// Reader screen — serves two jobs in Phase 2:
///
/// 1. As the `/reader` shell-tab placeholder (no [bookId]): renders a short
///    Middlemarch passage in Literata to exercise the reader font/theme
///    primitives landed in Phase 1. This is the pre-existing behavior and
///    the navigation_test widget test asserts against it via the
///    `reader-screen` key.
///
/// 2. As the `/reader/:bookId` top-level route (with [bookId]): renders a
///    Phase 2 stub that Plan 07's book cards can navigate into. The real
///    reader lands in Phase 3; this stub just proves the route wiring.
///
/// Splitting these into two widgets would be marginally cleaner but would
/// fork the test infrastructure for no gain — Phase 3 will replace both
/// render paths with the sentence-span RichText pipeline anyway.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key, this.bookId});

  /// When non-null, render the Phase 2 "Book #$bookId" stub instead of the
  /// Phase 1 sample passage. Plan 07 will pass this via
  /// `context.go('/reader/$bookId')`.
  final int? bookId;

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
    if (bookId != null) {
      return _buildBookStub(context, bookId!);
    }
    return _buildSamplePassage(context);
  }

  Widget _buildBookStub(BuildContext context, int id) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final Color bg = brightness == Brightness.dark
        ? ClayColors.darkBackground
        : ClayColors.background;
    final Color fg = brightness == Brightness.dark
        ? ClayColors.darkTextPrimary
        : ClayColors.textPrimary;

    return Scaffold(
      key: const Key('reader-screen-book'),
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Reader'),
        backgroundColor: bg,
        foregroundColor: fg,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Book #$id — Phase 3 will render this',
            style: theme.textTheme.bodyLarge?.copyWith(color: fg),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildSamplePassage(BuildContext context) {
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
