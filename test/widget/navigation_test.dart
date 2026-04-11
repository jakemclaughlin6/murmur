import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/app/app.dart';
import 'package:murmur/core/crash/crash_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    // CrashLogger is initialized by main.dart in production; widget tests
    // don't run main.dart, so we do the equivalent here via the test helper.
    final tempDocs = await Directory.systemTemp.createTemp('murmur_nav_test_');
    CrashLogger.resetForTest();
    await CrashLogger.initializeForTest(docs: tempDocs);
    SharedPreferences.setMockInitialValues({});
  });

  group('Navigation — FND-02 3-tab bottom nav', () {
    testWidgets('app starts on Library with 3 destinations',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: MurmurApp()));
      await tester.pumpAndSettle();

      // Verify 3 destinations with the expected labels.
      // 'Library' appears twice: AppBar title + NavigationBar destination.
      expect(find.text('Library'), findsAtLeastNWidgets(1));
      expect(find.text('Reader'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Library tab should show the placeholder content.
      expect(find.byKey(const Key('library-screen')), findsOneWidget);
    });

    testWidgets('tap Reader destination navigates to ReaderScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: MurmurApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reader'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reader-screen')), findsOneWidget);
    });

    testWidgets('tap Settings destination navigates to SettingsScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: MurmurApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-screen')), findsOneWidget);
    });
  });
}
