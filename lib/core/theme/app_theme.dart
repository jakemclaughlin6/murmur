import 'package:flutter/material.dart';

import 'clay_colors.dart';
import 'murmur_theme_mode.dart';

/// D-18: Clay-neutrals light theme. "Quiet library" aesthetic.
ThemeData buildLightTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: ClayColors.background,
      colorScheme: const ColorScheme.light(
        primary: ClayColors.accent,
        onPrimary: Colors.white,
        surface: ClayColors.surface,
        onSurface: ClayColors.textPrimary,
        secondary: ClayColors.textSecondary,
        onSecondary: Colors.white,
        surfaceContainerHighest: ClayColors.borderSubtle,
        outline: ClayColors.borderDefault,
      ),
      textTheme: _baseTextTheme(ClayColors.textPrimary, ClayColors.textSecondary),
      dividerTheme: const DividerThemeData(
        color: ClayColors.borderSubtle,
        thickness: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ClayColors.background,
        foregroundColor: ClayColors.textPrimary,
        elevation: 0,
      ),
    );

/// D-19: warm paper sepia variant.
ThemeData buildSepiaTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: ClayColors.sepiaBackground,
      colorScheme: const ColorScheme.light(
        primary: ClayColors.sepiaAccent,
        onPrimary: Colors.white,
        surface: ClayColors.sepiaSurface,
        onSurface: ClayColors.sepiaTextPrimary,
        secondary: ClayColors.sepiaTextSecondary,
        onSecondary: Colors.white,
        surfaceContainerHighest: ClayColors.sepiaBorder,
        outline: ClayColors.sepiaBorder,
      ),
      textTheme: _baseTextTheme(ClayColors.sepiaTextPrimary, ClayColors.sepiaTextSecondary),
      dividerTheme: const DividerThemeData(color: ClayColors.sepiaBorder, thickness: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: ClayColors.sepiaBackground,
        foregroundColor: ClayColors.sepiaTextPrimary,
        elevation: 0,
      ),
    );

/// D-19: near-black dark with warm off-white text.
ThemeData buildDarkTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ClayColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: ClayColors.darkAccent,
        onPrimary: Colors.black,
        surface: ClayColors.darkSurface,
        onSurface: ClayColors.darkTextPrimary,
        secondary: ClayColors.darkTextSecondary,
        onSecondary: Colors.black,
        surfaceContainerHighest: ClayColors.darkBorder,
        outline: ClayColors.darkBorder,
      ),
      textTheme: _baseTextTheme(ClayColors.darkTextPrimary, ClayColors.darkTextSecondary),
      dividerTheme: const DividerThemeData(color: ClayColors.darkBorder, thickness: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: ClayColors.darkBackground,
        foregroundColor: ClayColors.darkTextPrimary,
        elevation: 0,
      ),
    );

/// D-19: true #000000 for AMOLED pixel-off.
ThemeData buildOledTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ClayColors.oledBackground,
      colorScheme: const ColorScheme.dark(
        primary: ClayColors.oledAccent,
        onPrimary: Colors.black,
        surface: ClayColors.oledSurface,
        onSurface: ClayColors.oledTextPrimary,
        secondary: ClayColors.oledTextSecondary,
        onSecondary: Colors.black,
        surfaceContainerHighest: ClayColors.oledBorder,
        outline: ClayColors.oledBorder,
      ),
      textTheme: _baseTextTheme(ClayColors.oledTextPrimary, ClayColors.oledTextSecondary),
      dividerTheme: const DividerThemeData(color: ClayColors.oledBorder, thickness: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: ClayColors.oledBackground,
        foregroundColor: ClayColors.oledTextPrimary,
        elevation: 0,
      ),
    );

/// Maps the 5-value enum to the correct ThemeData. `system` resolves to
/// the light theme here — the MaterialApp builder handles the actual
/// system-brightness lookup via `themeMode: ThemeMode.system`.
ThemeData themeFor(MurmurThemeMode mode) => switch (mode) {
      MurmurThemeMode.system || MurmurThemeMode.light => buildLightTheme(),
      MurmurThemeMode.sepia => buildSepiaTheme(),
      MurmurThemeMode.dark => buildDarkTheme(),
      MurmurThemeMode.oled => buildOledTheme(),
    };

/// D-23: UI chrome uses system font (SF Pro on iOS, Roboto on Android).
/// fontFamily is NOT set — Flutter resolves to the platform default.
/// Reader body text sets fontFamily: 'Literata' or 'Merriweather' at the
/// RichText level, not on ThemeData.
TextTheme _baseTextTheme(Color primary, Color secondary) => TextTheme(
      headlineMedium: TextStyle(color: primary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: primary),
      bodyLarge: TextStyle(color: primary),
      bodyMedium: TextStyle(color: secondary),
    );
