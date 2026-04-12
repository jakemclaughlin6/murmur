import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/reader/providers/font_settings_provider.dart';
import 'package:murmur/features/reader/widgets/typography_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks calls to FontSizeController.set().
class _SpyFontSizeController extends FontSizeController {
  double? lastSetValue;

  @override
  Future<double> build() async => 18.0;

  @override
  Future<void> set(double size) async {
    lastSetValue = size;
    state = AsyncData(size.clamp(
      FontSizeController.minSize,
      FontSizeController.maxSize,
    ));
  }
}

/// Tracks calls to FontFamilyController.set().
class _SpyFontFamilyController extends FontFamilyController {
  String? lastSetValue;

  @override
  Future<String> build() async => 'Literata';

  @override
  Future<void> set(String family) async {
    if (!FontFamilyController.availableFamilies.contains(family)) return;
    lastSetValue = family;
    state = AsyncData(family);
  }
}

/// Wraps TypographySheet with mocked providers.
Widget _testApp({
  _SpyFontSizeController? fontSizeSpy,
  _SpyFontFamilyController? fontFamilySpy,
}) {
  return ProviderScope(
    overrides: [
      fontSizeControllerProvider.overrideWith(
        () => fontSizeSpy ?? _SpyFontSizeController(),
      ),
      fontFamilyControllerProvider.overrideWith(
        () => fontFamilySpy ?? _SpyFontFamilyController(),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: TypographySheet(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TypographySheet', () {
    testWidgets('slider is present with correct range', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, FontSizeController.minSize);
      expect(slider.max, FontSizeController.maxSize);
    });

    testWidgets('dragging slider calls FontSizeController.set()',
        (tester) async {
      final spy = _SpyFontSizeController();
      await tester.pumpWidget(_testApp(fontSizeSpy: spy));
      await tester.pumpAndSettle();

      // Find slider and drag it right
      final sliderFinder = find.byType(Slider);
      final sliderWidget = tester.widget<Slider>(sliderFinder);
      expect(sliderWidget.value, 18.0);

      // Drag slider to the right to increase font size
      await tester.drag(sliderFinder, const Offset(100, 0));
      await tester.pumpAndSettle();

      // Spy should have been called with a value > 18
      expect(spy.lastSetValue, isNotNull);
      expect(spy.lastSetValue!, greaterThan(18.0));
    });

    testWidgets('tapping Merriweather calls FontFamilyController.set()',
        (tester) async {
      final spy = _SpyFontFamilyController();
      await tester.pumpWidget(_testApp(fontFamilySpy: spy));
      await tester.pumpAndSettle();

      // Tap 'Merriweather' in the family list
      await tester.tap(find.text('Merriweather'));
      await tester.pumpAndSettle();

      expect(spy.lastSetValue, 'Merriweather');
    });

    testWidgets('font preview text is displayed for each family',
        (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      // Each family should have a preview line
      for (final family in FontFamilyController.availableFamilies) {
        expect(find.text(family), findsOneWidget);
      }

      // Preview sentence should appear for each family
      expect(
        find.text('The quick brown fox jumps over the lazy dog.'),
        findsNWidgets(FontFamilyController.availableFamilies.length),
      );
    });

    testWidgets('selected family shows check icon', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      // Default family is 'Literata' -- should have check icon
      expect(find.byIcon(Icons.check), findsOneWidget);

      // The check icon should be in the Literata ListTile
      final literataListTile = tester.widget<ListTile>(
        find.byKey(const ValueKey('font-Literata')),
      );
      expect(literataListTile.trailing, isNotNull);
      expect(literataListTile.selected, isTrue);

      // Merriweather should not have trailing icon
      final merriweatherListTile = tester.widget<ListTile>(
        find.byKey(const ValueKey('font-Merriweather')),
      );
      expect(merriweatherListTile.trailing, isNull);
      expect(merriweatherListTile.selected, isFalse);
    });
  });
}
