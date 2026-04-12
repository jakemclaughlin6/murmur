/// Font size and font family Riverpod providers (Phase 3, Plan 02).
///
/// Follows the exact pattern of [ThemeModeController] in
/// `lib/core/theme/theme_mode_provider.dart`: `@Riverpod(keepAlive: true)`
/// async notifier backed by `shared_preferences`.
///
/// D-14: Font size is a continuous slider from 12pt to 28pt, persisted.
/// D-15: Font family picker offers Literata and Merriweather per Phase 1 D-21.
/// T-03-05: Font size clamped to min/max; font family rejects unknown values.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'font_settings_provider.g.dart';

/// Controls the reader font size (D-14).
///
/// Persists to `shared_preferences` under `settings.fontSize`.
/// Values are clamped to [minSize]–[maxSize] inclusive on set (T-03-05).
@Riverpod(keepAlive: true)
class FontSizeController extends _$FontSizeController {
  static const String prefsKey = 'settings.fontSize';
  static const double defaultSize = 18.0;
  static const double minSize = 12.0;
  static const double maxSize = 28.0;

  @override
  Future<double> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(prefsKey) ?? defaultSize;
  }

  /// Updates the font size, clamping to [minSize]–[maxSize].
  Future<void> set(double size) async {
    final clamped = size.clamp(minSize, maxSize);
    state = AsyncData(clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(prefsKey, clamped);
  }
}

/// Controls the reader font family (D-15).
///
/// Persists to `shared_preferences` under `settings.fontFamily`.
/// Rejects values not in [availableFamilies] (T-03-05).
@Riverpod(keepAlive: true)
class FontFamilyController extends _$FontFamilyController {
  static const String prefsKey = 'settings.fontFamily';
  static const String defaultFamily = 'Literata';
  static const List<String> availableFamilies = ['Literata', 'Merriweather'];

  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefsKey);
    if (stored != null && availableFamilies.contains(stored)) return stored;
    return defaultFamily;
  }

  /// Updates the font family if [family] is in [availableFamilies].
  /// Unknown families are silently rejected (state unchanged).
  Future<void> set(String family) async {
    if (!availableFamilies.contains(family)) return;
    state = AsyncData(family);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, family);
  }
}
