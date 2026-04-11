import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('library-screen'),
      appBar: AppBar(
        title: const Text('Library'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 96,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 24),
              Text(
                'Your library is empty',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Import an EPUB to start listening.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  // Phase 2 wires this to the file_picker import flow.
                  debugPrint('Library: Import CTA tapped (no-op in Phase 1)');
                },
                icon: const Icon(Icons.add),
                label: const Text('Import your first book'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
