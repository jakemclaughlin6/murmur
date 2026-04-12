import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/reader/providers/font_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FontSizeController', () {
    test('defaults to 18.0', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final size = await container.read(fontSizeControllerProvider.future);
      expect(size, 18.0);
    });

    test('set(24.0) updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Wait for initial build.
      await container.read(fontSizeControllerProvider.future);

      await container.read(fontSizeControllerProvider.notifier).set(24.0);

      final size = await container.read(fontSizeControllerProvider.future);
      expect(size, 24.0);

      // Verify persistence.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(FontSizeController.prefsKey), 24.0);
    });

    test('set(5.0) clamps to 12.0', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(fontSizeControllerProvider.future);
      await container.read(fontSizeControllerProvider.notifier).set(5.0);

      final size = await container.read(fontSizeControllerProvider.future);
      expect(size, 12.0);
    });

    test('set(50.0) clamps to 28.0', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(fontSizeControllerProvider.future);
      await container.read(fontSizeControllerProvider.notifier).set(50.0);

      final size = await container.read(fontSizeControllerProvider.future);
      expect(size, 28.0);
    });

    test('round-trip: persisted value loaded by new container', () async {
      SharedPreferences.setMockInitialValues({});
      final container1 = ProviderContainer();

      await container1.read(fontSizeControllerProvider.future);
      await container1.read(fontSizeControllerProvider.notifier).set(22.0);
      container1.dispose();

      // New container reads the persisted value.
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      final size = await container2.read(fontSizeControllerProvider.future);
      expect(size, 22.0);
    });
  });

  group('FontFamilyController', () {
    test('defaults to Literata', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final family =
          await container.read(fontFamilyControllerProvider.future);
      expect(family, 'Literata');
    });

    test('set Merriweather updates and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(fontFamilyControllerProvider.future);
      await container
          .read(fontFamilyControllerProvider.notifier)
          .set('Merriweather');

      final family =
          await container.read(fontFamilyControllerProvider.future);
      expect(family, 'Merriweather');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(FontFamilyController.prefsKey), 'Merriweather');
    });

    test('set unknown family is rejected (state unchanged)', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(fontFamilyControllerProvider.future);
      await container
          .read(fontFamilyControllerProvider.notifier)
          .set('ComicSans');

      final family =
          await container.read(fontFamilyControllerProvider.future);
      expect(family, 'Literata'); // unchanged from default
    });

    test('round-trip: persisted family loaded by new container', () async {
      SharedPreferences.setMockInitialValues({});
      final container1 = ProviderContainer();

      await container1.read(fontFamilyControllerProvider.future);
      await container1
          .read(fontFamilyControllerProvider.notifier)
          .set('Merriweather');
      container1.dispose();

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      final family =
          await container2.read(fontFamilyControllerProvider.future);
      expect(family, 'Merriweather');
    });

    test('stored unknown family falls back to default', () async {
      // Simulate a manually-edited prefs value.
      SharedPreferences.setMockInitialValues({
        FontFamilyController.prefsKey: 'NonExistentFont',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final family =
          await container.read(fontFamilyControllerProvider.future);
      expect(family, 'Literata');
    });
  });
}
