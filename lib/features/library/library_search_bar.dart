/// Plan 02-07: debounced library search field.
///
/// Owns the 300ms debounce window per 02-CONTEXT's Claude's Discretion
/// note. The underlying `LibraryNotifier` is eager (per D-02-06-B) — the
/// debounce belongs in the UI layer because it is a typing-cadence
/// concern, not a data concern.
///
/// Rebuilds only on the clear-button toggle (text empty ↔ non-empty) —
/// the heavy re-emit work happens at the notifier level when the timer
/// fires, not on every keystroke.
///
/// Visual spec:
/// - TextField with search + clear icons
/// - ClayColors-only palette (quiet library directive)
/// - 24px border radius, filled background, ClayColors.borderSubtle line
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/clay_colors.dart';
import 'library_provider.dart';

class LibrarySearchBar extends ConsumerStatefulWidget {
  const LibrarySearchBar({super.key});

  @override
  ConsumerState<LibrarySearchBar> createState() => _LibrarySearchBarState();
}

class _LibrarySearchBarState extends ConsumerState<LibrarySearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // setState to drive the clear-button visibility toggle — the suffix
    // icon depends on `_controller.text.isEmpty`, which the build method
    // reads on every rebuild.
    setState(() {});

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(libraryProvider.notifier).setSearchQuery(value);
    });
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: 'Search title or author',
          hintStyle: const TextStyle(color: ClayColors.textTertiary),
          prefixIcon: const Icon(
            Icons.search,
            color: ClayColors.textTertiary,
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  color: ClayColors.textTertiary,
                  onPressed: _clear,
                )
              : null,
          filled: true,
          fillColor: ClayColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: ClayColors.borderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: ClayColors.borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: ClayColors.accent),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
