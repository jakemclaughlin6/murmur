import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/font_settings_provider.dart';
import 'providers/reader_provider.dart';
import 'widgets/chapter_drawer.dart';
import 'widgets/chapter_page.dart';
import 'widgets/chapter_sidebar.dart';
import 'widgets/typography_sheet.dart';
import 'providers/reading_progress_provider.dart';

/// Full reader screen with responsive layout (D-05, D-08, D-09, D-10).
///
/// Tablet (shortestSide >= 600dp): persistent 300px chapter sidebar.
/// Phone (shortestSide < 600dp): slide-over chapter drawer from app bar.
/// Immersive mode toggles app bar on center-third tap.
/// Typography bottom sheet for font size / font family controls.
/// Debounced reading progress save with lifecycle flush.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, this.bookId});
  final int? bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  PageController? _pageController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _immersive = false;
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(readingProgressProvider.notifier).flushNow();
    }
  }

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    if (_immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
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

        // Responsive breakpoint: D-08 / D-09
        final isTablet =
            MediaQuery.of(context).size.shortestSide >= 600;

        // Initialize PageController at saved chapter (D-13)
        _pageController ??= PageController(
          initialPage: readerState.currentChapterIndex,
          keepPage: true,
        );

        // Build the PageView
        final pageView = PageView.builder(
          controller: _pageController,
          itemCount: readerState.chapters.length,
          onPageChanged: (index) {
            ref
                .read(readerProvider(widget.bookId!).notifier)
                .setChapter(index);
            // Record chapter change as progress so exiting after a swipe
            // (without scrolling) still persists the new chapter position.
            ref
                .read(readingProgressProvider.notifier)
                .onScrollChanged(widget.bookId!, index, 0.0);
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
              onScrollOffsetChanged: (fraction) {
                ref
                    .read(readingProgressProvider.notifier)
                    .onScrollChanged(
                      widget.bookId!,
                      readerState.currentChapterIndex,
                      fraction,
                    );
              },
            );
          },
        );

        // Wrap in GestureDetector for immersive mode toggle (D-10)
        final gesturePageView = GestureDetector(
          onTapUp: (details) {
            final box = context.findRenderObject() as RenderBox;
            final height = box.size.height;
            final tapY = details.localPosition.dy;
            final third = height / 3;
            if (tapY > third && tapY < third * 2) {
              _toggleImmersive();
            }
          },
          child: pageView,
        );

        // Build body: tablet has collapsible sidebar + page, phone has just page
        final Widget body;
        if (isTablet) {
          body = Row(
            children: [
              if (!_sidebarCollapsed) ...[
                ChapterSidebar(
                  chapters: readerState.chapters,
                  currentIndex: readerState.currentChapterIndex,
                  onChapterTap: (i) => _pageController?.jumpToPage(i),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(child: gesturePageView),
            ],
          );
        } else {
          body = gesturePageView;
        }

        // Build AppBar actions
        final actions = <Widget>[
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Typography',
            onPressed: () => showTypographySheet(context),
          ),
          if (isTablet)
            IconButton(
              icon: Icon(_sidebarCollapsed
                  ? Icons.menu_open
                  : Icons.menu),
              tooltip: _sidebarCollapsed
                  ? 'Show chapters'
                  : 'Hide chapters',
              onPressed: () =>
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),
          if (!isTablet)
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'Chapters',
              onPressed: () =>
                  _scaffoldKey.currentState?.openDrawer(),
            ),
        ];

        return Scaffold(
          key: !isTablet ? _scaffoldKey : const Key('reader-screen-book'),
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: _immersive
              ? null
              : AppBar(
                  title: Text(
                    readerState.book.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: actions,
                ),
          drawer: !isTablet
              ? ChapterDrawer(
                  chapters: readerState.chapters,
                  currentIndex: readerState.currentChapterIndex,
                  onChapterTap: (i) => _pageController?.jumpToPage(i),
                  bookTitle: readerState.book.title,
                )
              : null,
          body: body,
        );
      },
    );
  }
}
