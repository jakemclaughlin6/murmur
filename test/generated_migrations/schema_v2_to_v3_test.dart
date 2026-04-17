/// v2 → v3 Drift migration test per CD-01.
///
/// Same `SchemaVerifier` pattern as `schema_v1_to_v2_test.dart`.
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/db/app_database.dart';

import 'schema.dart';

void main() {
  group('v2 -> v3 migration (CD-01)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('adds voice_id + playback_speed; existing rows carry NULL defaults',
        () async {
      // Start at v2 and open AppDatabase, which runs from2To3.
      final connection = await verifier.startAt(2);
      final db = AppDatabase(connection);
      try {
        await verifier.migrateAndValidate(db, 3);

        // Insert three rows through the live v3 tables; voice_id +
        // playback_speed default to NULL because no Value() is passed.
        for (var i = 0; i < 3; i++) {
          await db.into(db.books).insert(
                BooksCompanion.insert(
                  title: 'Fixture $i',
                  filePath: '/tmp/fx-$i.epub',
                  importDate: DateTime.utc(2026, 4, 17, 10 + i),
                ),
              );
        }
        final rows = await db.select(db.books).get();
        expect(rows.length, 3);
        for (final r in rows) {
          expect(r.voiceId, isNull);
          expect(r.playbackSpeed, isNull);
        }

        // Round-trip a write of both new columns.
        final id = await db.into(db.books).insert(
              BooksCompanion.insert(
                title: 'With overrides',
                filePath: '/tmp/ov.epub',
                importDate: DateTime.utc(2026, 4, 17, 13),
                voiceId: const Value('af_bella'),
                playbackSpeed: const Value(1.25),
              ),
            );
        final ov = await (db.select(db.books)..where((b) => b.id.equals(id)))
            .getSingle();
        expect(ov.voiceId, 'af_bella');
        expect(ov.playbackSpeed, 1.25);

        // PRAGMA foreign_keys survives the migration (regression guard).
        final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
        expect(fk.data.values.first, 1);
      } finally {
        await db.close();
      }
    });
  });
}
