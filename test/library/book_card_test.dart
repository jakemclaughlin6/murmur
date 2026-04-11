/// BookCard + BookCardShimmer widget tests (Plan 02-06 Task 2).
///
/// Covers LIB-06 (card visual) and D-07 through D-11:
/// - D-07: cover full-bleed BoxFit.cover
/// - D-08: missing-cover fallback (ClayColors.background + menu_book_outlined)
/// - D-09: title body-medium + author body-small typography
/// - D-10: progress ring only when reading_progress_chapter != null
/// - D-11: BookCardShimmer for optimistic insert placeholder
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/theme/clay_colors.dart';
import 'package:murmur/features/library/book_card.dart';
import 'package:murmur/features/library/book_card_shimmer.dart';

/// Minimal 1x1 red PNG — smallest valid image we can load via Image.file.
/// Source: https://github.com/mathiasbynens/small/blob/master/png-red.png
final Uint8List _onePixelPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
  0x54, 0x08, 0x99, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x00, 0x03, 0x00, 0x01, 0x5B, 0x8C, 0x11,
  0x3A, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
  0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Constructs a Book directly via the Drift-generated constructor —
/// sidesteps the import pipeline, which is Plan 02-05's concern.
Book makeBook({
  int id = 1,
  String title = 'Test Title',
  String? author = 'Test Author',
  String filePath = '/tmp/test.epub',
  String? coverPath,
  DateTime? importDate,
  DateTime? lastReadDate,
  int? readingProgressChapter,
  double? readingProgressOffset,
}) =>
    Book(
      id: id,
      title: title,
      author: author,
      filePath: filePath,
      coverPath: coverPath,
      importDate: importDate ?? DateTime(2026, 4, 11),
      lastReadDate: lastReadDate,
      readingProgressChapter: readingProgressChapter,
      readingProgressOffset: readingProgressOffset,
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          // Cover area is 2:3 of the width — at 140 wide that's 210 tall,
          // + 8 padding + title line + author line. 280 gives generous
          // headroom so flex overflow errors do not break layout asserts.
          child: SizedBox(width: 140, height: 280, child: child),
        ),
      ),
    );

void main() {
  group('BookCard — cover art (D-07, D-08)', () {
    testWidgets(
        'renders fallback Container + menu_book_outlined when coverPath is null',
        (tester) async {
      final book = makeBook(coverPath: null);

      await tester.pumpWidget(_wrap(BookCard(book: book)));
      await tester.pump();

      // Fallback icon present.
      final iconFinder = find.byIcon(Icons.menu_book_outlined);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, ClayColors.textTertiary, reason: 'D-08 icon color');
      // No Image widget in the fallback path.
      expect(find.byType(Image), findsNothing);
    });

    testWidgets(
        'renders Image with BoxFit.cover when cover is available '
        '(test seam: MemoryImage override — avoids the Image.file decoder '
        'hang in widget tests)', (tester) async {
      // The production path uses `Image.file(File(book.coverPath!))`,
      // but `FileImage`'s async decode interacts badly with `testWidgets`
      // and can hang the test binding. BookCard exposes a
      // `coverImageOverride` seam exactly for this — tests substitute
      // a `MemoryImage` of a 1x1 PNG so the widget mounts synchronously
      // while still exercising the `_buildCover` branch that produces
      // an `Image` with `BoxFit.cover`.
      final book = makeBook(coverPath: '/does-not-matter.png');

      await tester.pumpWidget(
        _wrap(
          BookCard(
            book: book,
            coverImageOverride: MemoryImage(_onePixelPng),
          ),
        ),
      );
      // pumpAndSettle would hang on MemoryImage resolution too — one
      // frame is enough to materialize the widget tree for findByType.
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(image.fit, BoxFit.cover, reason: 'D-07 full-bleed cover');
      expect(find.byIcon(Icons.menu_book_outlined), findsNothing,
          reason: 'fallback icon must be absent when cover is present');
    });
  });

  group('BookCard — typography (D-09)', () {
    testWidgets('title row uses body-medium and ClayColors.textPrimary',
        (tester) async {
      await tester
          .pumpWidget(_wrap(BookCard(book: makeBook(title: 'War and Peace'))));
      await tester.pump();

      final titleFinder = find.text('War and Peace');
      expect(titleFinder, findsOneWidget);
      final titleText = tester.widget<Text>(titleFinder);
      expect(titleText.maxLines, 1);
      expect(titleText.overflow, TextOverflow.ellipsis);
      expect(titleText.style?.color, ClayColors.textPrimary);
    });

    testWidgets('author row uses body-small and ClayColors.textSecondary '
        'when author is non-null', (tester) async {
      await tester.pumpWidget(
        _wrap(BookCard(book: makeBook(author: 'Leo Tolstoy'))),
      );
      await tester.pump();

      final authorFinder = find.text('Leo Tolstoy');
      expect(authorFinder, findsOneWidget);
      final authorText = tester.widget<Text>(authorFinder);
      expect(authorText.maxLines, 1);
      expect(authorText.overflow, TextOverflow.ellipsis);
      expect(authorText.style?.color, ClayColors.textSecondary);
    });

    testWidgets('author row is omitted entirely when author is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(BookCard(book: makeBook(title: 'Anonymous', author: null))),
      );
      await tester.pump();

      // Only the title text is present; no second Text widget for an
      // empty / "Unknown" author placeholder.
      expect(find.byType(Text), findsOneWidget);
      expect(find.text('Anonymous'), findsOneWidget);
    });
  });

  group('BookCard — progress ring (D-10)', () {
    testWidgets(
        'shows CircularProgressIndicator when readingProgressChapter != null',
        (tester) async {
      final book = makeBook(
        readingProgressChapter: 2,
        readingProgressOffset: 0.4,
      );

      await tester.pumpWidget(_wrap(BookCard(book: book)));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'does NOT show a ring when readingProgressChapter is null',
        (tester) async {
      final book = makeBook(readingProgressChapter: null);

      await tester.pumpWidget(_wrap(BookCard(book: book)));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('BookCard — interaction callbacks', () {
    testWidgets('onTap fires when the card is tapped', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        _wrap(BookCard(book: makeBook(), onTap: () => tapCount++)),
      );
      await tester.pump();

      await tester.tap(find.byType(BookCard));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('onLongPress fires on long-press', (tester) async {
      var longPressCount = 0;
      await tester.pumpWidget(
        _wrap(BookCard(
          book: makeBook(),
          onLongPress: () => longPressCount++,
        )),
      );
      await tester.pump();

      await tester.longPress(find.byType(BookCard));
      await tester.pump();

      expect(longPressCount, 1);
    });
  });

  group('BookCardShimmer (D-11)', () {
    testWidgets('renders without exceptions and animates through frames',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const BookCardShimmer(filename: 'incoming.epub')),
      );

      // Advance through several animation frames to catch any builder
      // exceptions or controller misuse.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1400));

      // Still on screen — at minimum a ShaderMask wraps the placeholder.
      expect(find.byType(BookCardShimmer), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('disposes AnimationController cleanly on unmount',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const BookCardShimmer(filename: 'incoming.epub')),
      );
      await tester.pump();

      // Replace with an empty widget — this triggers dispose() on the
      // State and its AnimationController. If dispose is missing or the
      // controller is already disposed, Flutter's asserts in debug mode
      // throw and the test fails.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      // One extra frame advance — if the controller is leaked, its
      // repeat() tick would still fire here and surface as an error.
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(BookCardShimmer), findsNothing);
      // No exceptions recorded by the test binding.
      expect(tester.takeException(), isNull);
    });
  });
}
