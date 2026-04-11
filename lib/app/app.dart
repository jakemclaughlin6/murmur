import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/murmur_theme_mode.dart';
import '../core/theme/theme_mode_provider.dart';
import 'router.dart';

class MurmurApp extends ConsumerWidget {
  const MurmurApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeAsync = ref.watch(themeModeControllerProvider);
    final mode = modeAsync.value ?? MurmurThemeMode.system;
    final router = ref.watch(routerProvider);

    // For System, Light: light themes follow ThemeMode.system / light.
    // For Dark, OLED: dark themes follow ThemeMode.dark.
    // For Sepia: we override via the builder because Flutter's ThemeMode
    // doesn't know about sepia as a distinct variant.
    return MaterialApp.router(
      title: 'Murmur',
      debugShowCheckedModeBanner: false,
      theme: _lightVariantFor(mode),
      darkTheme: _darkVariantFor(mode),
      themeMode: mode.platformMode,
      routerConfig: router,
    );
  }

  /// Pick the light-variant ThemeData to feed to MaterialApp.theme.
  /// For sepia, this returns the sepia theme so it wins when platformMode==light.
  ThemeData _lightVariantFor(MurmurThemeMode mode) => switch (mode) {
        MurmurThemeMode.sepia => buildSepiaTheme(),
        _ => buildLightTheme(),
      };

  /// Pick the dark-variant ThemeData to feed to MaterialApp.darkTheme.
  /// For OLED, this returns the OLED theme so it wins when platformMode==dark.
  ThemeData _darkVariantFor(MurmurThemeMode mode) => switch (mode) {
        MurmurThemeMode.oled => buildOledTheme(),
        _ => buildDarkTheme(),
      };
}
