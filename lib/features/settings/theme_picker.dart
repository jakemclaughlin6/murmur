import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/murmur_theme_mode.dart';
import '../../core/theme/theme_mode_provider.dart';

class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeAsync = ref.watch(themeModeControllerProvider);
    final controller = ref.watch(themeModeControllerProvider.notifier);
    final current = modeAsync.value ?? MurmurThemeMode.system;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Theme',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        RadioGroup<MurmurThemeMode>(
          groupValue: current,
          onChanged: (selected) {
            if (selected != null) {
              controller.set(selected);
            }
          },
          child: Column(
            children: [
              for (final mode in MurmurThemeMode.values)
                RadioListTile<MurmurThemeMode>(
                  key: Key('theme-option-${mode.name}'),
                  title: Text(mode.displayLabel),
                  value: mode,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
