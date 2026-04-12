import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/font_settings_provider.dart';
import 'providers/reader_provider.dart';
import 'widgets/chapter_page.dart';

/// Full reader screen replacing the Phase 2 stub.
///
/// Structure (D-05): Horizontal PageView of chapters. Each page is a
/// ChapterPage with a vertical ListView of rendered blocks.
///
/// Plan 05 adds: chapter sidebar/drawer, typography sheet, immersive mode,
/// debounced progress save. This plan delivers the core reading surface.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, this.bookId});
  final int? bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  PageController? _pageController;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If no bookId, show placeholder (shell tab route).
    // Key('reader-screen') is asserted by navigation_test.dart.
    if (widget.bookId == null) {
      return Scaffold(
        key: const Key('reader-screen'),
        appBar: AppBar(title: const Text('Reader')),
        body: const Center(child: Text('Open a book from the Library')),
      );
    }

    final readerAsync = ref.watch(readerProvider(widget.bookId!));
    final fontSizeAsync = ref.watch(fontSizeControllerProvider);
    final fontFamilyAsync = ref.watch(fontFamilyControllerProvider);

    return readerAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Reader')),
        body: Center(child: Text('Error loading book: $error')),
      ),
      data: (readerState) {
        final fontSize = fontSizeAsync.value ?? 18.0;
        final fontFamily = fontFamilyAsync.value ?? 'Literata';
        final theme = Theme.of(context);
        final textColor = theme.colorScheme.onSurface;
        final mutedColor =
            theme.colorScheme.onSurface.withValues(alpha: 0.6);

        // Initialize PageController at saved chapter (D-13)
        _pageController ??= PageController(
          initialPage: readerState.currentChapterIndex,
          keepPage: true,
        );

        return Scaffold(
          key: const Key('reader-screen-book'),
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              readerState.book.title,
              overflow: TextOverflow.ellipsis,
            ),
            // Plan 05 adds: typography icon, chapter nav icon
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: readerState.chapters.length,
            onPageChanged: (index) {
              ref
                  .read(readerProvider(widget.bookId!).notifier)
                  .setChapter(index);
            },
            itemBuilder: (context, index) {
              final blocks = readerState.blocksForChapter(index);
              return ChapterPage(
                key: ValueKey('chapter-$index'),
                blocks: blocks,
                fontFamily: fontFamily,
                fontSize: fontSize,
                textColor: textColor,
                mutedColor: mutedColor,
                imagePathMap: readerState.imagePathMap,
                initialOffsetFraction:
                    index == readerState.currentChapterIndex
                        ? readerState.initialOffsetFraction
                        : null,
              );
            },
          ),
        );
      },
    );
  }
}
