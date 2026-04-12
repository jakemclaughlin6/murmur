import 'package:flutter/material.dart';

import '../../../core/epub/block.dart';
import '../../../core/text/sentence_splitter.dart';
import 'block_renderer.dart';

/// Renders a single chapter as a vertical [ListView.builder] of block widgets.
///
/// Per D-05, each chapter is one "page" in the outer PageView. The ListView
/// scrolls vertically within the chapter. Per D-06, only the current and
/// adjacent chapters are built by the PageView.
class ChapterPage extends StatefulWidget {
  const ChapterPage({
    super.key,
    required this.blocks,
    required this.fontFamily,
    required this.fontSize,
    required this.textColor,
    required this.mutedColor,
    this.initialOffsetFraction,
    this.imagePathMap,
    this.onScrollOffsetChanged,
  });

  final List<Block> blocks;
  final String fontFamily;
  final double fontSize;
  final Color textColor;
  final Color mutedColor;
  final double? initialOffsetFraction;
  final Map<String, String>? imagePathMap;

  /// Called with the current scroll offset fraction (0.0-1.0) for progress
  /// saving. Wired in Plan 05.
  final ValueChanged<double>? onScrollOffsetChanged;

  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final _splitter = const SentenceSplitter();
  bool _hasRestoredPosition = false;

  @override
  bool get wantKeepAlive => true; // Pitfall 4: preserve scroll on PageView swipe

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // D-13: restore scroll position after first frame layout (Pitfall 2)
    if (widget.initialOffsetFraction != null &&
        widget.initialOffsetFraction! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restorePosition();
      });
    }
  }

  void _restorePosition() {
    if (_hasRestoredPosition) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.hasContentDimensions && pos.maxScrollExtent > 0) {
      _scrollController
          .jumpTo(widget.initialOffsetFraction! * pos.maxScrollExtent);
      _hasRestoredPosition = true;
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (!pos.hasContentDimensions || pos.maxScrollExtent == 0) return;
    final fraction = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    widget.onScrollOffsetChanged?.call(fraction);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: widget.blocks.length,
      itemBuilder: (context, index) {
        return renderBlock(
          widget.blocks[index],
          fontFamily: widget.fontFamily,
          fontSize: widget.fontSize,
          textColor: widget.textColor,
          mutedColor: widget.mutedColor,
          imagePathMap: widget.imagePathMap,
          splitter: _splitter,
        );
      },
    );
  }
}
