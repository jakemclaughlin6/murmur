/// Plan 02-06: single-book grid tile.
///
/// Atomic presentation widget — Plan 07 composes these into a SliverGrid.
/// Intentionally takes a [Book] and two callbacks and returns a Column;
/// no routing, no data fetching, no state. Laying this out as a leaf
/// widget keeps Plan 07's grid focused on the scroll chrome.
///
/// Visual spec (from 02-CONTEXT.md):
/// - D-07: cover art full-bleed, BoxFit.cover
/// - D-08: missing-cover fallback = ClayColors.background + menu_book_outlined
/// - D-09: title body-medium + textPrimary, author body-small + textSecondary
/// - D-10: CircularProgressIndicator only when reading_progress_chapter != null
/// - Aspect ratio 2:3 cover area (Claude's Discretion per CONTEXT)
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/clay_colors.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Test seam — injects an [ImageProvider] instead of [FileImage].
  ///
  /// `Image.file` triggers the `FileImage` async decode pipeline, which
  /// is unreliable inside `testWidgets` (the decoder's frame callbacks
  /// interact badly with the fake frame scheduler and can hang). Tests
  /// pass a `MemoryImage` of a tiny in-memory PNG so the widget mounts
  /// without touching the file system.
  ///
  /// Production code (Plan 07's SliverGrid) leaves this null; the
  /// widget falls back to `Image.file(File(book.coverPath!))`.
  final ImageProvider? coverImageOverride;

  const BookCard({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPress,
    this.coverImageOverride,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cover area: ~2:3 aspect ratio, full-bleed (D-07).
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCover(),
                // D-10: progress ring only when the user has opened this
                // book at least once (Phase 3 owns the correctness of
                // readingProgressChapter).
                if (book.readingProgressChapter != null)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: book.readingProgressOffset ?? 0.0,
                        strokeWidth: 2,
                        backgroundColor: ClayColors.borderSubtle,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          ClayColors.accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // D-09: title — body-medium, textPrimary, 1 line, ellipsis.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              book.title,
              style: textTheme.bodyMedium?.copyWith(
                color: ClayColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // D-09: author — body-small, textSecondary, 1 line, ellipsis.
          // Omitted entirely when null (no "Unknown" placeholder row).
          if (book.author != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                book.author!,
                style: textTheme.bodySmall?.copyWith(
                  color: ClayColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the cover widget — either an [Image] backed by the test
  /// override or a real [FileImage] for a cached cover (D-07), or the
  /// D-08 fallback container.
  ///
  /// Corrupt or missing cover files fall through to [_buildFallback]
  /// via Image.file's errorBuilder, which mitigates T-02-06-01 (DoS on
  /// corrupt/oversized cover file).
  Widget _buildCover() {
    if (coverImageOverride != null) {
      return Image(
        image: coverImageOverride!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _buildFallback(),
      );
    }
    if (book.coverPath != null) {
      return Image.file(
        File(book.coverPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  /// D-08: missing-cover fallback — oat-tone fill + muted book icon.
  /// Uses only `ClayColors` constants (quiet library directive).
  Widget _buildFallback() {
    return Container(
      color: ClayColors.background,
      child: const Center(
        child: Icon(
          Icons.menu_book_outlined,
          size: 48,
          color: ClayColors.textTertiary,
        ),
      ),
    );
  }
}
