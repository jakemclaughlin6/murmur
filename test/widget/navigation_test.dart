import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/app/app.dart';
import 'package:murmur/core/crash/crash_logger.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/db/app_database_provider.dart';
import 'package:murmur/features/library/library_provider.dart';
import 'package:murmur/features/library/share_intent_listener.dart';
import 'package:murmur/features/tts/providers/model_status_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

late Directory _tempDocs;
late AppDatabase _testDb;

/// No-op share-intent source. The real
/// `ReceiveSharingIntent.instance.getInitialMedia()` call would hit a
/// MethodChannel without a test binding, leaving a dangling Future and
/// tripping the "Timer still pending" invariant at test teardown.
class _NoopShareIntentSource implements ShareIntentSource {
  const _NoopShareIntentSource();
  @override
  Future<List<String>> getInitialPaths() async => const <String>[];
  @override
  Stream<List<String>> getPathStream() => const Stream<List<String>>.empty();
  @override
  Future<void> reset() async {}
}

/// Library notifier stub that emits an empty state once and never
/// opens a Drift stream subscription — keeps the test tree free of
/// async scheduling that would trip the "Timer still pending"
/// invariant at teardown.
class _StubLibraryNotifier extends LibraryNotifier {
  @override
  Stream<LibraryState> build() => Stream.value(
        const LibraryState(
          books: [],
          sortMode: SortMode.recentlyRead,
          searchQuery: '',
        ),
      );
}

/// Model-status stub that reports the model as already installed so the
/// _LaunchGate passes through to the app shell. Without this override the
/// gate renders ModelDownloadModal, which has an indeterminate
/// LinearProgressIndicator that animates forever and causes pumpAndSettle
/// to time out.
class _InstalledModelStatusNotifier extends ModelStatusNotifier {
  @override
  Future<ModelStatus> build() async =>
      const ModelStatus(installed: true);
}

/// Builds a ProviderScope configured for widget tests that load
/// [MurmurApp]. LibraryScreen watches `libraryProvider`, which walks
/// `db.select(db.books).watch()` — so without overriding
/// `appDatabaseProvider` the navigation test would try to open the
/// real `driftDatabase(name: 'murmur')` file and hang pumpAndSettle.
Widget _app() => ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(_testDb),
        libraryProvider.overrideWith(_StubLibraryNotifier.new),
        shareIntentSourceProvider.overrideWithValue(
          const _NoopShareIntentSource(),
        ),
        modelStatusProvider.overrideWith(_InstalledModelStatusNotifier.new),
      ],
      child: const MurmurApp(),
    );

void main() {
  setUpAll(() async {
    // CrashLogger is initialized by main.dart in production; widget tests
    // don't run main.dart, so we do the equivalent here via the test helper.
    _tempDocs = await Directory.systemTemp.createTemp('murmur_nav_test_');
    CrashLogger.resetForTest();
    await CrashLogger.initializeForTest(docs: _tempDocs);
    SharedPreferences.setMockInitialValues({});
    _testDb = AppDatabase(NativeDatabase.memory());
  });

  tearDownAll(() async {
    await _testDb.close();
    CrashLogger.resetForTest();
    if (_tempDocs.existsSync()) {
      await _tempDocs.delete(recursive: true);
    }
  });

  group('Navigation — FND-02 3-tab bottom nav', () {
    testWidgets('app starts on Library with 3 destinations',
        (WidgetTester tester) async {
      await tester.pumpWidget(_app());
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
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reader'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reader-screen')), findsOneWidget);
    });

    testWidgets('tap Settings destination navigates to SettingsScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-screen')), findsOneWidget);
    });
  });
}
