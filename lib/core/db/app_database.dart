import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/books_table.dart';
import 'tables/chapters_table.dart';

part 'app_database.g.dart';

/// Phase 2 schema v2: `books` + `chapters` tables per D-03, D-04, D-05.
///
/// Migration strategy:
/// - Fresh installs start at schemaVersion=2 via [MigrationStrategy.onCreate]
///   calling `m.createAll()`, which picks up both tables.
/// - v1→v2 upgrades (users who opened Phase 1 builds at schemaVersion=1
///   with zero user tables) run the generated `stepByStep` handler in
///   [onUpgrade]. That handler is wired in Task 2 after
///   `drift_dev schema steps` regenerates `schema_versions.dart`.
///
/// Database file location: `${appDocumentsDir}/murmur.db`
/// (handled automatically by `drift_flutter`'s `driftDatabase` helper).
@DriftDatabase(tables: [Books, Chapters])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Task 2 wires `stepByStep(from1To2: ...)` from the generated
          // `schema_versions.dart` helper. Until that file exists this
          // stub is a no-op — acceptable because fresh installs go through
          // `onCreate` and no real users are on schemaVersion=1 yet.
        },
      );

  static QueryExecutor _openConnection() => driftDatabase(name: 'murmur');
}
