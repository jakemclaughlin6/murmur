import 'package:flutter/material.dart';

import '../../../core/db/app_database.dart';

/// Slide-over chapter drawer for phone layout (D-09).
/// Same chapter list styling as tablet sidebar.
/// Opened from app bar icon, dismissed by swipe or tap-outside.
class ChapterDrawer extends StatelessWidget {
  const ChapterDrawer({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.onChapterTap,
    required this.bookTitle,
  });

  final List<Chapter> chapters;
  final int currentIndex;
  final ValueChanged<int> onChapterTap;
  final String bookTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                bookTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '${chapters.length} chapters',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
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
                    key: ValueKey('drawer-chapter-$index'),
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
                    onTap: () {
                      onChapterTap(index);
                      Navigator.of(context).pop(); // close drawer after selection
                    },
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
