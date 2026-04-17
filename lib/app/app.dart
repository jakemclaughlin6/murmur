import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/murmur_theme_mode.dart';
import '../core/theme/theme_mode_provider.dart';
import '../features/library/share_intent_listener.dart';
import '../features/tts/providers/model_status_provider.dart';
import '../features/tts/ui/model_download_modal.dart';
import 'router.dart';

class MurmurApp extends ConsumerWidget {
  const MurmurApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeAsync = ref.watch(themeModeControllerProvider);
    final mode = modeAsync.value ?? MurmurThemeMode.system;
    final router = ref.watch(routerProvider);

    // LIB-02 / D-14: kick off the share-intent listener at app startup.
    // The provider's `build()` drains any initial cold-start share
    // intent and subscribes to the hot stream; we only need to watch
    // it here so that the @Riverpod(keepAlive: true) lifecycle actually
    // instantiates. The result (a `Future<void>`) is intentionally
    // discarded — the listener publishes state via ImportNotifier.
    ref.watch(shareIntentListenerProvider);

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
      // Phase 6 onboarding absorbs this launch gate. Keep the modal factored
      // so it can be embedded inside the broader ONB-01 flow.
      builder: (context, child) =>
          _LaunchGate(child: child ?? const SizedBox()),
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

class _LaunchGate extends ConsumerWidget {
  const _LaunchGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(modelStatusProvider);
    return async.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Startup error: $e'))),
      data: (s) => s.installed ? child : const ModelDownloadModal(),
    );
  }
}
