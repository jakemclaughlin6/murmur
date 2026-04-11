import 'package:flutter/material.dart';

/// D-13 locked 5-option theme enum. Persisted as string name under
/// `settings.themeMode` via shared_preferences (D-14).
enum MurmurThemeMode { system, light, sepia, dark, oled }

extension MurmurThemeModeX on MurmurThemeMode {
  /// Flutter's `ThemeMode` only has light/dark/system — sepia is a light variant
  /// and OLED is a dark variant. The actual color scheme differs inside the
  /// MaterialApp builder based on the full `MurmurThemeMode` value.
  ThemeMode get platformMode => switch (this) {
        MurmurThemeMode.system => ThemeMode.system,
        MurmurThemeMode.light => ThemeMode.light,
        MurmurThemeMode.sepia => ThemeMode.light,
        MurmurThemeMode.dark => ThemeMode.dark,
        MurmurThemeMode.oled => ThemeMode.dark,
      };

  String get displayLabel => switch (this) {
        MurmurThemeMode.system => 'System',
        MurmurThemeMode.light => 'Light',
        MurmurThemeMode.sepia => 'Sepia',
        MurmurThemeMode.dark => 'Dark',
        MurmurThemeMode.oled => 'OLED',
      };
}
