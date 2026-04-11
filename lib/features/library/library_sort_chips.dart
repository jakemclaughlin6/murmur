/// Plan 02-07: sort chip row for the library grid.
///
/// Three FilterChips — Recently read / Title / Author — wired to
/// [LibraryNotifier.setSortMode] per D-15 and LIB-07. The active chip
/// highlights with `ClayColors.accent` (no new palette).
///
/// Horizontally scrollable on narrow phones so a fourth chip (if added
/// in a future decision) never wraps under the grid.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/clay_colors.dart';
import 'library_provider.dart';

class LibrarySortChips extends ConsumerWidget {
  const LibrarySortChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryProvider).value;
    final active = state?.sortMode ?? SortMode.recentlyRead;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(ref, 'Recently read', SortMode.recentlyRead, active),
            const SizedBox(width: 8),
            _chip(ref, 'Title', SortMode.title, active),
            const SizedBox(width: 8),
            _chip(ref, 'Author', SortMode.author, active),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    WidgetRef ref,
    String label,
    SortMode mode,
    SortMode active,
  ) {
    final selected = mode == active;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) =>
          ref.read(libraryProvider.notifier).setSortMode(mode),
      selectedColor: ClayColors.accent.withValues(alpha: 0.15),
      checkmarkColor: ClayColors.accent,
      labelStyle: TextStyle(
        color: selected ? ClayColors.accent : ClayColors.textSecondary,
      ),
      side: BorderSide(
        color: selected ? ClayColors.accent : ClayColors.borderSubtle,
      ),
      backgroundColor: ClayColors.surface,
    );
  }
}
