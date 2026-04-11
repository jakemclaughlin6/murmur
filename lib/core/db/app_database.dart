import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// D-15: Phase 1 ships Drift at schemaVersion=1 with ZERO user tables.
///
/// Phase 2 will add @DataClassName tables for Book, Chapter, ReadingProgress, etc.
/// This empty shell exists ONLY to prove the Drift toolchain is wired correctly
/// and to commit a v1 schema dump to drift_schemas/ so Phase 2's v1→v2 migration
/// has a baseline to diff against.
///
/// Database file location: ${appDocumentsDir}/murmur.db
/// (handled automatically by drift_flutter's driftDatabase helper)
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // Nothing to create in v1 — zero user tables.
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Phase 2 populates this with v1 → v2 migration steps.
        },
      );

  static QueryExecutor _openConnection() => driftDatabase(name: 'murmur');
}
