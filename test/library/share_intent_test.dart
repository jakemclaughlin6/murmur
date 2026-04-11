/// Share intent listener tests (Plan 02-05 Task 3).
///
/// Covers LIB-02 Share/Open-in entry point per D-14 (single pipeline
/// with file_picker). The listener routes EPUB file paths from the
/// incoming intent stream to `ImportNotifier.importFromPaths`; non-EPUB
/// files are filtered out before reaching the notifier.
///
/// Test strategy:
///   The ShareIntentListener depends on a small abstract
///   [ShareIntentSource] seam (see lib/features/library/share_intent_listener.dart)
///   rather than calling `ReceiveSharingIntent.instance` directly. In
///   production the seam is the real package; in tests we override the
///   Riverpod provider with a fake source that emits controlled streams.
///   This keeps the tests hermetic — no platform channel mocking, no
///   TestDefaultBinaryMessengerBinding ceremony.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';
import 'package:murmur/core/db/app_database_provider.dart';
import 'package:murmur/features/library/import_service.dart';
import 'package:murmur/features/library/share_intent_listener.dart';
import 'package:path/path.dart' as p;

/// In-memory fake [ShareIntentSource] that lets tests push values into the
/// listener one-shot (initial media) and streamed.
class FakeShareIntentSource implements ShareIntentSource {
  FakeShareIntentSource({
    List<String> initial = const [],
    Stream<List<String>>? stream,
  })  : _initial = List.of(initial),
        _stream = stream ?? const Stream<List<String>>.empty();

  List<String> _initial;
  final Stream<List<String>> _stream;

  int resetCount = 0;

  @override
  Future<List<String>> getInitialPaths() async => _initial;

  @override
  Stream<List<String>> getPathStream() => _stream;

  @override
  Future<void> reset() async {
    resetCount++;
    _initial = <String>[];
  }
}

/// Stage a fixture file at [dir]/[name] and return its absolute path.
Future<String> _stage(String fixture, String name, Directory dir) async {
  final bytes = File('test/fixtures/epub/$fixture').readAsBytesSync();
  final dest = p.join(dir.path, name);
  await File(dest).writeAsBytes(bytes);
  return dest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late Directory sourceDir;
  late Directory docsDir;
  late AppDatabase db;
  late ProviderContainer container;

  ProviderContainer makeContainer(FakeShareIntentSource source) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appDocumentsDirProvider.overrideWith((ref) async => docsDir),
        shareIntentSourceProvider.overrideWithValue(source),
      ],
    );
  }

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('murmur_share_test_');
    sourceDir = Directory(p.join(sandbox.path, 'src'))..createSync();
    docsDir = Directory(p.join(sandbox.path, 'docs'))..createSync();
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  group('ShareIntentListener — initial media (cold-start Share)', () {
    test('an initial .epub path imports and reset() is called', () async {
      final path = await _stage('minimal.epub', 'cold.epub', sourceDir);
      final source = FakeShareIntentSource(initial: [path]);
      container = makeContainer(source);

      // Force the listener to build — Future returns after initial media
      // is drained. Any streamed events arrive later.
      await container.read(shareIntentListenerProvider.future);
      // Give the async import a beat to run.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Drain any remaining microtasks until the book appears.
      for (var i = 0; i < 20; i++) {
        final count = (await db.select(db.books).get()).length;
        if (count > 0) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      final books = await db.select(db.books).get();
      expect(books, hasLength(1));
      expect(books.single.title, 'Minimal Test');
      expect(source.resetCount, greaterThanOrEqualTo(1),
          reason: 'listener must call reset() after consuming initial media');
    });

    test('non-EPUB initial media is filtered out — no import runs', () async {
      final pdfPath = p.join(sourceDir.path, 'not.pdf');
      await File(pdfPath).writeAsString('fake pdf');
      final source = FakeShareIntentSource(initial: [pdfPath]);
      container = makeContainer(source);

      await container.read(shareIntentListenerProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final books = await db.select(db.books).get();
      expect(books, isEmpty);
    });
  });

  group('ShareIntentListener — streamed events (warm-start Share)', () {
    test('a streamed .epub event flows to ImportNotifier and inserts a row',
        () async {
      final path = await _stage('minimal.epub', 'warm.epub', sourceDir);
      final controller = StreamController<List<String>>.broadcast();
      final source = FakeShareIntentSource(stream: controller.stream);
      container = makeContainer(source);

      // Build the listener (no initial media).
      await container.read(shareIntentListenerProvider.future);
      // Emit a streamed share event AFTER build completes.
      controller.add([path]);
      // Wait for the import pipeline to drain.
      for (var i = 0; i < 20; i++) {
        final count = (await db.select(db.books).get()).length;
        if (count > 0) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      final books = await db.select(db.books).get();
      expect(books, hasLength(1));
      await controller.close();
    });

    test('streamed non-EPUB events are filtered out', () async {
      final pdfPath = p.join(sourceDir.path, 'junk.pdf');
      await File(pdfPath).writeAsString('not an epub');
      final controller = StreamController<List<String>>.broadcast();
      final source = FakeShareIntentSource(stream: controller.stream);
      container = makeContainer(source);

      await container.read(shareIntentListenerProvider.future);
      controller.add([pdfPath]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final books = await db.select(db.books).get();
      expect(books, isEmpty);
      await controller.close();
    });
  });
}
