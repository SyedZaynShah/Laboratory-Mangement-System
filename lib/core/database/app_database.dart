import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sq3;
import 'migration_service.dart';

class AppDatabase {
  sq3.Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationSupportDirectory();
    final dbFile = File('${dir.path}${Platform.pathSeparator}lms.db');
    if (!await dbFile.exists()) {
      await dbFile.create(recursive: true);
    }
    _db = sq3.sqlite3.open(dbFile.path);
    DatabaseMigrationService(_db!).migrate();
    if (kDebugMode) {
      debugPrint('[DB] Opened at ${dbFile.path}');
    }
  }

  sq3.Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('Database not initialized');
    }
    return d;
  }

  void close() {
    _db?.dispose();
    _db = null;
  }
}

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = AppDatabase();
  await db.init();
  ref.onDispose(db.close);
  return db;
});
