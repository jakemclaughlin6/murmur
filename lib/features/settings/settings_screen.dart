import 'package:flutter/material.dart';

import 'crash_log_status_tile.dart';
import 'theme_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('settings-screen'),
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ThemePicker(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Reader fonts',
              style: theme.textTheme.titleLarge,
            ),
          ),
          const _FontPreviewRow(
            familyName: 'Literata',
            fontFamily: 'Literata',
          ),
          const _FontPreviewRow(
            familyName: 'Merriweather',
            fontFamily: 'Merriweather',
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Diagnostics',
              style: theme.textTheme.titleLarge,
            ),
          ),
          const CrashLogStatusTile(),
        ],
      ),
    );
  }
}

class _FontPreviewRow extends StatelessWidget {
  const _FontPreviewRow({required this.familyName, required this.fontFamily});
  final String familyName;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(familyName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        'The quick brown fox jumps over the lazy dog',
        style: TextStyle(fontFamily: fontFamily, fontSize: 16),
      ),
    );
  }
}
