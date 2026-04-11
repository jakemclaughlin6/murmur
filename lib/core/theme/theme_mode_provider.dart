import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'murmur_theme_mode.dart';

part 'theme_mode_provider.g.dart';

/// D-14: Theme mode persists across app restarts via `shared_preferences`
/// under the key `settings.themeMode`. @Riverpod(keepAlive: true) prevents
/// the provider from being disposed on navigation rebuilds — critical for
/// avoiding a re-read of SharedPreferences on every route change.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  static const String prefsKey = 'settings.themeMode';

  @override
  Future<MurmurThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null) return MurmurThemeMode.system;
    return MurmurThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => MurmurThemeMode.system,
    );
  }

  /// Updates the active mode and persists it to SharedPreferences.
  Future<void> set(MurmurThemeMode mode) async {
    state = AsyncData(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, mode.name);
  }
}
