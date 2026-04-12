import 'package:flutter/material.dart';

import '../../../core/db/app_database.dart';

/// Persistent chapter sidebar for tablet layout (D-08).
/// Width: 300px (floor). Always visible, even in immersive mode (D-10).
/// Current chapter highlighted with accent background.
class ChapterSidebar extends StatelessWidget {
  const ChapterSidebar({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.onChapterTap,
  });

  final List<Chapter> chapters;
  final int currentIndex;
  final ValueChanged<int> onChapterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 300,
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Chapters',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final isActive = index == currentIndex;
                return ListTile(
                  key: ValueKey('chapter-tile-$index'),
                  title: Text(
                    chapter.title ?? 'Chapter ${index + 1}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  selected: isActive,
                  selectedTileColor:
                      colorScheme.primaryContainer.withValues(alpha: 0.3),
                  onTap: () => onChapterTap(index),
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
