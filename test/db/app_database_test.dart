import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';

void main() {
  group('AppDatabase — v2 schema (D-04, D-05, D-03)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('schemaVersion is 2', () {
      expect(db.schemaVersion, 2);
    });

    test('has books and chapters user tables (D-04, D-05, D-03)', () async {
      // Query sqlite_master for user tables, ignoring internal drift-managed
      // tables. Drift stores metadata in `sqlite_master` under SQLite-reserved
      // names starting with `sqlite_` — we filter them out.
      final result = await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' "
            "ORDER BY name",
          )
          .get();
      final tableNames =
          result.map((row) => row.data['name'] as String).toList();
      expect(
        tableNames,
        containsAll(<String>['books', 'chapters']),
        reason: 'Phase 2 schema v2 must create both user tables via onCreate',
      );
    });

    test('close() succeeds on a freshly-created v2 database', () async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      await freshDb.close();
    });
  });
}
