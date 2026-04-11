import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/crash/crash_logger.dart';

void main() {
  late Directory tempDocs;

  setUp(() async {
    tempDocs = await Directory.systemTemp.createTemp('murmur_crash_test_');
    CrashLogger.resetForTest();
    await CrashLogger.initializeForTest(docs: tempDocs);
  });

  tearDown(() async {
    CrashLogger.resetForTest();
    if (tempDocs.existsSync()) {
      await tempDocs.delete(recursive: true);
    }
  });

  group('CrashLogger — init + JSONL write (D-07, FND-10)', () {
    test('crashes/ directory and crashes.log file are created on init', () {
      final dir = Directory('${tempDocs.path}/crashes');
      expect(dir.existsSync(), isTrue);
      expect(File('${dir.path}/crashes.log').existsSync(), isTrue);
    });

    test('logError writes exactly one JSONL line with all 7 D-07 fields', () async {
      await CrashLogger.instance.logError(
        Exception('boom'),
        StackTrace.fromString('#0 main (file://test.dart:1:1)'),
        level: 'test',
      );

      final content = await File('${tempDocs.path}/crashes/crashes.log').readAsString();
      final lines = content.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines, hasLength(1));

      final entry = jsonDecode(lines.first) as Map<String, dynamic>;
      expect(entry.keys.toSet(), CrashLogger.jsonlFields);
      expect(entry['level'], 'test');
      expect(entry['error'], contains('boom'));
      expect(entry['stack'], contains('main'));
      expect(entry['device'], isNotEmpty);
      expect(entry['os'], isNotEmpty);
      expect(entry['appVersion'], isNotEmpty);
      expect(DateTime.tryParse(entry['ts'] as String), isNotNull);
    });

    test('logFlutterError writes a line with level "flutter"', () async {
      final details = FlutterErrorDetails(
        exception: Exception('flutter-boom'),
        stack: StackTrace.fromString('#0 build (file://widget.dart:1:1)'),
      );
      await CrashLogger.instance.logFlutterError(details);

      final content = await File('${tempDocs.path}/crashes/crashes.log').readAsString();
      final entry = jsonDecode(content.trim()) as Map<String, dynamic>;
      expect(entry['level'], 'flutter');
      expect(entry['error'], contains('flutter-boom'));
    });

    test('filePath and currentSize expose the log file', () async {
      final logger = CrashLogger.instance;
      expect(logger.filePath, endsWith('/crashes/crashes.log'));
      final sizeBefore = await logger.currentSize();
      expect(sizeBefore, 0);
      await logger.logError('boom', StackTrace.empty);
      final sizeAfter = await logger.currentSize();
      expect(sizeAfter, greaterThan(0));
    });
  });

  group('CrashLogger — 1 MB rotation (D-08)', () {
    test('rotation at 1 MB: crashes.log renamed to crashes.1.log, fresh file started',
        () async {
      final logger = CrashLogger.instance;
      final logFile = File('${tempDocs.path}/crashes/crashes.log');
      final backup = File('${tempDocs.path}/crashes/crashes.1.log');

      // Each stack trace is ~400 bytes, each JSON line ~700 bytes.
      // 3000+ lines will comfortably exceed 1 MB.
      final bigStack = List.filled(20, '#0 at deep.stack.level').join('\n');
      for (var i = 0; i < 4000; i++) {
        await logger.logError('error $i', StackTrace.fromString(bigStack));
      }

      expect(backup.existsSync(), isTrue,
          reason: 'crashes.1.log should exist after 1 MB overflow');
      expect(await logFile.length(), lessThan(CrashLogger.maxBytes),
          reason: 'Fresh crashes.log should be under 1 MB after rotation');
    });

    test('double rotation overwrites .1.log — max 2 MB on disk', () async {
      final logger = CrashLogger.instance;
      final logFile = File('${tempDocs.path}/crashes/crashes.log');
      final backup = File('${tempDocs.path}/crashes/crashes.1.log');
      final extraBackup = File('${tempDocs.path}/crashes/crashes.2.log');

      final bigStack = List.filled(20, '#0 at deep.stack.level').join('\n');
      for (var i = 0; i < 4000; i++) {
        await logger.logError('a$i', StackTrace.fromString(bigStack));
      }
      for (var i = 0; i < 4000; i++) {
        await logger.logError('b$i', StackTrace.fromString(bigStack));
      }

      expect(backup.existsSync(), isTrue);
      expect(extraBackup.existsSync(), isFalse,
          reason: 'D-08: exactly ONE backup file — no .2.log');
      expect(
        await logFile.length() + await backup.length(),
        lessThanOrEqualTo(2 * CrashLogger.maxBytes),
        reason: 'Max on-disk footprint is 2 MB (current + one backup)',
      );
    });
  });

  group('CrashLogger — triple-catch simulation (D-10)', () {
    // Plan 08's main.dart wires FlutterError.onError, PlatformDispatcher.onError,
    // and runZonedGuarded to call into CrashLogger with levels flutter/platform/zone.
    // This group proves the logger correctly tags entries by level.

    test('FlutterError path writes level "flutter"', () async {
      await CrashLogger.instance.logFlutterError(FlutterErrorDetails(
        exception: Exception('from-flutter'),
        stack: StackTrace.current,
      ));
      final content =
          await File('${tempDocs.path}/crashes/crashes.log').readAsString();
      final entry = jsonDecode(content.trim().split('\n').first) as Map;
      expect(entry['level'], 'flutter');
    });

    test('PlatformDispatcher path writes level "platform"', () async {
      await CrashLogger.instance
          .logError(Exception('from-platform'), StackTrace.current, level: 'platform');
      final content =
          await File('${tempDocs.path}/crashes/crashes.log').readAsString();
      final lines = content.trim().split('\n');
      final entry = jsonDecode(lines.last) as Map;
      expect(entry['level'], 'platform');
    });

    test('zone path writes level "zone"', () async {
      await CrashLogger.instance
          .logError(Exception('from-zone'), StackTrace.current, level: 'zone');
      final content =
          await File('${tempDocs.path}/crashes/crashes.log').readAsString();
      final lines = content.trim().split('\n');
      final entry = jsonDecode(lines.last) as Map;
      expect(entry['level'], 'zone');
    });
  });
}
