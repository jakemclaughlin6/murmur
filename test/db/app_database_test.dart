import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';

void main() {
  group('AppDatabase — v1 schema (FND-04)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('schemaVersion is 1', () {
      expect(db.schemaVersion, 1);
    });

    test('has zero user tables (D-15)', () async {
      // Query sqlite_master for user tables, ignoring internal drift-managed tables.
      // Drift stores metadata in `sqlite_master` under SQLite-reserved names starting
      // with `sqlite_` — we filter them out.
      final result = await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
          )
          .get();
      final tableNames = result.map((row) => row.data['name'] as String).toList();
      expect(tableNames, isEmpty,
          reason: 'Phase 1 must have zero user tables — Phase 2 will add them');
    });

    test('close() succeeds on an empty database', () async {
      // Already covered by tearDown, but make it explicit.
      final freshDb = AppDatabase(NativeDatabase.memory());
      await freshDb.close();
    });
  });
}
