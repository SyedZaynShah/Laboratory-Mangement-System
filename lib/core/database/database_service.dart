import 'package:riverpod/riverpod.dart';
import 'package:sqlite3/sqlite3.dart' as sq3;
import 'app_database.dart';

class DatabaseService {
  final Ref ref;
  sq3.Database? _db;

  DatabaseService(this.ref);

  Future<sq3.Database> get database async {
    if (_db != null) return _db!;
    final appDb = await ref.read(appDatabaseProvider.future);
    final db = appDb.db;
    db.execute('PRAGMA foreign_keys = ON;');
    _db = db;
    return _db!;
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final svc = DatabaseService(ref);
  ref.onDispose(() {});
  return svc;
});

final sqliteDbProvider = FutureProvider<sq3.Database>((ref) async {
  final svc = ref.read(databaseServiceProvider);
  return svc.database;
});
