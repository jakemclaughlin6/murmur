import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Font bundle — Literata + Merriweather (FND-06)', () {
    test('Literata-Regular.ttf loads from bundle and is > 10KB', () async {
      final data = await rootBundle.load('assets/fonts/literata/Literata-Regular.ttf');
      expect(data.lengthInBytes, greaterThan(10 * 1024));
    });

    test('Literata-Bold.ttf loads from bundle and is > 10KB', () async {
      final data = await rootBundle.load('assets/fonts/literata/Literata-Bold.ttf');
      expect(data.lengthInBytes, greaterThan(10 * 1024));
    });

    test('Merriweather-Regular.ttf loads from bundle and is > 10KB', () async {
      final data = await rootBundle.load('assets/fonts/merriweather/Merriweather-Regular.ttf');
      expect(data.lengthInBytes, greaterThan(10 * 1024));
    });

    test('Merriweather-Bold.ttf loads from bundle and is > 10KB', () async {
      final data = await rootBundle.load('assets/fonts/merriweather/Merriweather-Bold.ttf');
      expect(data.lengthInBytes, greaterThan(10 * 1024));
    });
  });
}
