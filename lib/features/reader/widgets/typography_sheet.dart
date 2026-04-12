import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/font_settings_provider.dart';

/// Bottom sheet for font size slider and font family picker (D-17).
/// Opened from an icon in the reader app bar.
class TypographySheet extends ConsumerWidget {
  const TypographySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSizeAsync = ref.watch(fontSizeControllerProvider);
    final fontFamilyAsync = ref.watch(fontFamilyControllerProvider);
    final theme = Theme.of(context);

    final fontSize = fontSizeAsync.value ?? FontSizeController.defaultSize;
    final fontFamily = fontFamilyAsync.value ?? FontFamilyController.defaultFamily;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Font size section (D-14)
          Text('Font Size', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${fontSize.round()}pt',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: Slider(
                  value: fontSize,
                  min: FontSizeController.minSize,
                  max: FontSizeController.maxSize,
                  onChanged: (value) {
                    ref.read(fontSizeControllerProvider.notifier).set(value);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Font family section (D-15)
          Text('Font', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ...FontFamilyController.availableFamilies.map((family) {
            final isSelected = family == fontFamily;
            return ListTile(
              key: ValueKey('font-$family'),
              title: Text(
                family,
                style: TextStyle(
                  fontFamily: family,
                  fontSize: 16,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                'The quick brown fox jumps over the lazy dog.',
                style: TextStyle(fontFamily: family, fontSize: 14),
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              selected: isSelected,
              selectedTileColor:
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () {
                ref.read(fontFamilyControllerProvider.notifier).set(family);
              },
            );
          }),
        ],
      ),
    );
  }
}

/// Shows the typography bottom sheet.
void showTypographySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (_) => const TypographySheet(),
    isScrollControlled: true,
  );
}
