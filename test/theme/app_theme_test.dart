import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/theme/clay_colors.dart';
import 'package:murmur/core/theme/murmur_theme_mode.dart';

void main() {
  group('app_theme — 4 ThemeData builders', () {
    test('buildLightTheme has brightness.light and Clay cream background', () {
      final theme = buildLightTheme();
      expect(theme, isNotNull);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFAF9F7));
    });

    test('buildSepiaTheme has brightness.light and warm paper background', () {
      final theme = buildSepiaTheme();
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF4ECD8));
    });

    test('buildDarkTheme has brightness.dark and near-black background', () {
      final theme = buildDarkTheme();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF121212));
    });

    test('buildOledTheme has brightness.dark and true-black background', () {
      final theme = buildOledTheme();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
    });

    test('themeFor(MurmurThemeMode.light) returns same bg as buildLightTheme', () {
      expect(
        themeFor(MurmurThemeMode.light).scaffoldBackgroundColor,
        buildLightTheme().scaffoldBackgroundColor,
      );
    });

    test('accent color is locked to matcha-800 #02492A (D-18)', () {
      expect(ClayColors.accent, const Color(0xFF02492A));
    });
  });

  group('MurmurThemeMode enum', () {
    test('has exactly 5 values in locked order', () {
      expect(MurmurThemeMode.values, hasLength(5));
      expect(MurmurThemeMode.values, [
        MurmurThemeMode.system,
        MurmurThemeMode.light,
        MurmurThemeMode.sepia,
        MurmurThemeMode.dark,
        MurmurThemeMode.oled,
      ]);
    });

    test('platformMode maps sepia->light and oled->dark', () {
      expect(MurmurThemeMode.system.platformMode, ThemeMode.system);
      expect(MurmurThemeMode.light.platformMode, ThemeMode.light);
      expect(MurmurThemeMode.sepia.platformMode, ThemeMode.light);
      expect(MurmurThemeMode.dark.platformMode, ThemeMode.dark);
      expect(MurmurThemeMode.oled.platformMode, ThemeMode.dark);
    });
  });
}
