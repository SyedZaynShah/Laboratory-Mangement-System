import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sq3;
import 'migration_service.dart';

class AppDatabase {
  sq3.Database? _db;
  String? _dbPath;

  Future<void> init() async {
    if (_db != null) return;
    Directory dir;
    try {
      dir = await getApplicationSupportDirectory().timeout(
        const Duration(seconds: 8),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[DB] getApplicationSupportDirectory failed: $e. Falling back to APPDATA.',
        );
      }
      final appData =
          Platform.environment['APPDATA'] ??
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['USERPROFILE'];
      final base = appData ?? Directory.current.path;
      dir = Directory('$base${Platform.pathSeparator}LMS');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
    final dbFile = File('${dir.path}${Platform.pathSeparator}lms.db');
    try {
      if (!await dbFile.exists()) {
        await dbFile.create(recursive: true);
      }
      _db = sq3.sqlite3.open(dbFile.path);
      _dbPath = dbFile.path;
      DatabaseMigrationService(_db!).migrate();
      if (kDebugMode) {
        debugPrint('[DB] Opened at ${dbFile.path}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DB] Failed to open/migrate DB: $e');
      }
      rethrow;
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

  String get dbPath {
    final p = _dbPath;
    if (p == null) {
      throw StateError('Database path not initialized');
    }
    return p;
  }
}

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = AppDatabase();
  await db.init();
  ref.onDispose(db.close);
  return db;
});
