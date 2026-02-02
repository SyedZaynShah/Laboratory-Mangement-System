import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sq3;

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
    _createTables(_db!);
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

  void _createTables(sq3.Database db) {
    // Users
    db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        name TEXT,
        role TEXT NOT NULL,
        lab_id TEXT,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER,
        updated_at INTEGER,
        sync_status INTEGER DEFAULT 0
      );
    ''');

    // Patients
    db.execute('''
      CREATE TABLE IF NOT EXISTS patients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        age INTEGER,
        gender TEXT,
        phone TEXT,
        doctor TEXT,
        address TEXT,
        date INTEGER,
        lab_id TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        sync_status INTEGER DEFAULT 0
      );
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_patients_name ON patients(name);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_patients_phone ON patients(phone);');

    // Test categories (hierarchical)
    db.execute('''
      CREATE TABLE IF NOT EXISTS test_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        lab_id TEXT,
        updated_at INTEGER,
        sync_status INTEGER DEFAULT 0
      );
    ''');

    // Tests master
    db.execute('''
      CREATE TABLE IF NOT EXISTS tests_master (
        id TEXT PRIMARY KEY,
        category_id TEXT,
        subcategory_id TEXT,
        name TEXT NOT NULL,
        price REAL,
        sample_type TEXT,
        unit TEXT,
        normal_range TEXT,
        is_panel INTEGER DEFAULT 0,
        panel_items TEXT,
        is_enabled INTEGER DEFAULT 1,
        lab_id TEXT,
        updated_at INTEGER,
        sync_status INTEGER DEFAULT 0
      );
    ''');

    // Orders
    db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        date INTEGER,
        total REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        net REAL DEFAULT 0,
        paid REAL DEFAULT 0,
        due REAL DEFAULT 0,
        status TEXT,
        lab_id TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        sync_status INTEGER DEFAULT 0
      );
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_orders_date ON orders(date);');

    // Order tests
    db.execute('''
      CREATE TABLE IF NOT EXISTS order_tests (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        test_id TEXT NOT NULL,
        price REAL,
        sample_status TEXT DEFAULT 'Pending',
        lab_id TEXT,
        updated_at INTEGER,
        sync_status INTEGER DEFAULT 0
      );
    ''');

    // Results
    db.execute('''
      CREATE TABLE IF NOT EXISTS results (
        id TEXT PRIMARY KEY,
        order_test_id TEXT NOT NULL,
        value TEXT,
        flag TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        lab_id TEXT,
        sync_status INTEGER DEFAULT 0
      );
    ''');

    // Reports
    db.execute('''
      CREATE TABLE IF NOT EXISTS reports (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        pdf_path TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        lab_id TEXT,
        sync_status INTEGER DEFAULT 0
      );
    ''');

    // Settings
    db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');
  }
}

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = AppDatabase();
  await db.init();
  ref.onDispose(db.close);
  return db;
});
