import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';

part 'app_database_provider.g.dart';

/// Lazily-initialized AppDatabase with disposal wired to the container lifecycle.
///
/// @Riverpod(keepAlive: true) keeps the instance alive across navigation rebuilds
/// — a per-build new database would leak connections. The ref.onDispose ensures
/// the database is closed when the container itself is disposed (e.g., at app
/// shutdown or during test teardown).
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
