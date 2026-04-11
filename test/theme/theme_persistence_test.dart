import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/theme/murmur_theme_mode.dart';
import 'package:murmur/core/theme/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThemeModeController — shared_preferences persistence', () {
    test('default on empty prefs is MurmurThemeMode.system', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = await container.read(themeModeControllerProvider.future);
      expect(mode, MurmurThemeMode.system);
    });

    test('reads persisted value from prefs', () async {
      SharedPreferences.setMockInitialValues({'settings.themeMode': 'sepia'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = await container.read(themeModeControllerProvider.future);
      expect(mode, MurmurThemeMode.sepia);
    });

    test('set() writes the name to prefs and updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(themeModeControllerProvider.notifier);
      await container.read(themeModeControllerProvider.future); // ensure built
      await controller.set(MurmurThemeMode.dark);

      final state = container.read(themeModeControllerProvider);
      expect(state.value, MurmurThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.themeMode'), 'dark');
    });

    test('set() survives container dispose + rebuild', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      final controller = container.read(themeModeControllerProvider.notifier);
      await container.read(themeModeControllerProvider.future);
      await controller.set(MurmurThemeMode.oled);
      container.dispose();

      // New container reads the persisted value.
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      final mode = await container2.read(themeModeControllerProvider.future);
      expect(mode, MurmurThemeMode.oled);
    });

    test('invalid persisted value falls back to system', () async {
      SharedPreferences.setMockInitialValues({'settings.themeMode': 'notARealMode'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = await container.read(themeModeControllerProvider.future);
      expect(mode, MurmurThemeMode.system);
    });
  });
}
