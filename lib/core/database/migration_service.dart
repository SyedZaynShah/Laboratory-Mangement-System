import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart' as sq3;

class DatabaseMigrationService {
  static const int latestVersion = 1;

  final sq3.Database db;
  DatabaseMigrationService(this.db);

  void migrate() {
    // Always enforce foreign keys
    db.execute('PRAGMA foreign_keys = ON;');

    final currentVersion = _getUserVersion();
    if (kDebugMode) {
      debugPrint('[DB] Current schema version: $currentVersion');
    }

    if (currentVersion < 1) {
      _migrateToV1();
      _setUserVersion(1);
      _recordSchemaMigration(1);
      if (kDebugMode) {
        debugPrint('[DB] Migrated to schema version 1');
      }
    }
  }

  int _getUserVersion() {
    final rows = db.select('PRAGMA user_version;');
    if (rows.isEmpty) return 0;
    final value = rows.first.values.first;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  void _setUserVersion(int version) {
    db.execute('PRAGMA user_version = $version;');
  }

  void _recordSchemaMigration(int version) {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    db.execute('INSERT OR REPLACE INTO schema_migrations(version, applied_at) VALUES (?, ?);', [version, ts]);
  }

  void _migrateToV1() {
    db.execute('BEGIN;');
    try {
      // Drop old/previous tables if they exist (Option A: replace)
      const dropOrder = <String>[
        // Newer tables first (children), then older ones
        'invoice_items',
        'payments',
        'test_results',
        'samples',
        'patient_tests',
        'panel_items',
        'test_reference_ranges',
        'invoices',
        'tests_master',
        'test_categories',
        'patients',
        'users',
        'audit_logs',
        'orders',
        'order_tests',
        'results',
        'reports',
        'settings',
        'schema_migrations',
      ];
      for (final t in dropOrder) {
        db.execute('DROP TABLE IF EXISTS $t;');
      }

      // schema_migrations
      db.execute('''
        CREATE TABLE schema_migrations (
          version INTEGER PRIMARY KEY,
          applied_at INTEGER NOT NULL
        );
      ''');

      // users
      db.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY,
          email TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          name TEXT NOT NULL,
          role TEXT NOT NULL CHECK(role IN ('admin','receptionist','technician')),
          phone TEXT,
          is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute('CREATE INDEX idx_users_role ON users(role);');

      // patients
      db.execute('''
        CREATE TABLE patients (
          id TEXT PRIMARY KEY,
          full_name TEXT NOT NULL,
          cnic TEXT UNIQUE,
          date_of_birth INTEGER,
          gender TEXT NOT NULL CHECK(gender IN ('male','female','other')),
          phone TEXT,
          address TEXT,
          referred_by TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute('CREATE INDEX idx_patients_name ON patients(full_name);');
      db.execute('CREATE INDEX idx_patients_phone ON patients(phone);');

      // test_categories
      db.execute('''
        CREATE TABLE test_categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          parent_id TEXT REFERENCES test_categories(id) ON UPDATE CASCADE ON DELETE SET NULL,
          sort_order INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute('CREATE UNIQUE INDEX idx_unique_test_categories ON test_categories(name, parent_id);');

      // tests_master
      db.execute('''
        CREATE TABLE tests_master (
          id TEXT PRIMARY KEY,
          code TEXT NOT NULL UNIQUE,
          category_id TEXT REFERENCES test_categories(id) ON UPDATE CASCADE ON DELETE SET NULL,
          name TEXT NOT NULL,
          sample_type TEXT NOT NULL,
          unit TEXT,
          method TEXT,
          price_cents INTEGER NOT NULL,
          is_panel INTEGER NOT NULL DEFAULT 0 CHECK(is_panel IN (0,1)),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute('CREATE INDEX idx_tests_category ON tests_master(category_id);');
      db.execute('CREATE INDEX idx_tests_name ON tests_master(name);');

      // test_reference_ranges
      db.execute('''
        CREATE TABLE test_reference_ranges (
          id TEXT PRIMARY KEY,
          test_id TEXT NOT NULL REFERENCES tests_master(id) ON UPDATE CASCADE ON DELETE CASCADE,
          gender TEXT CHECK(gender IN ('male','female','other')),
          age_min_years REAL,
          age_max_years REAL,
          value_min REAL,
          value_max REAL,
          text_range TEXT,
          unit TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      db.execute('CREATE INDEX idx_ref_ranges_test ON test_reference_ranges(test_id);');

      // panel_items
      db.execute('''
        CREATE TABLE panel_items (
          panel_id TEXT NOT NULL REFERENCES tests_master(id) ON UPDATE CASCADE ON DELETE CASCADE,
          test_id TEXT NOT NULL REFERENCES tests_master(id) ON UPDATE CASCADE ON DELETE RESTRICT,
          display_order INTEGER DEFAULT 0,
          PRIMARY KEY (panel_id, test_id)
        );
      ''');

      // patient_tests
      db.execute('''
        CREATE TABLE patient_tests (
          id TEXT PRIMARY KEY,
          patient_id TEXT NOT NULL REFERENCES patients(id) ON UPDATE CASCADE ON DELETE RESTRICT,
          test_id TEXT NOT NULL REFERENCES tests_master(id) ON UPDATE CASCADE ON DELETE RESTRICT,
          status TEXT NOT NULL CHECK(status IN ('ordered','sample_collected','processing','completed','cancelled')),
          priority TEXT CHECK(priority IN ('routine','urgent','stat')),
          request_id TEXT,
          ordered_at INTEGER NOT NULL,
          ordered_by TEXT REFERENCES users(id),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute('CREATE INDEX idx_pt_patient ON patient_tests(patient_id);');
      db.execute('CREATE INDEX idx_pt_test ON patient_tests(test_id);');
      db.execute('CREATE INDEX idx_pt_status ON patient_tests(status);');
      db.execute('CREATE INDEX idx_pt_ordered_at ON patient_tests(ordered_at);');

      // samples
      db.execute('''
        CREATE TABLE samples (
          id TEXT PRIMARY KEY,
          patient_test_id TEXT NOT NULL UNIQUE REFERENCES patient_tests(id) ON UPDATE CASCADE ON DELETE CASCADE,
          sample_code TEXT NOT NULL UNIQUE,
          status TEXT NOT NULL CHECK(status IN ('awaiting','collected','received','rejected','processed')),
          collected_at INTEGER,
          collected_by TEXT REFERENCES users(id),
          container TEXT,
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute('CREATE INDEX idx_samples_collected_at ON samples(collected_at);');

      // test_results
      db.execute('''
        CREATE TABLE test_results (
          id TEXT PRIMARY KEY,
          patient_test_id TEXT NOT NULL UNIQUE REFERENCES patient_tests(id) ON UPDATE CASCADE ON DELETE CASCADE,
          value_text TEXT,
          value_num REAL,
          reference_low REAL,
          reference_high REAL,
          reference_text TEXT,
          is_abnormal INTEGER NOT NULL DEFAULT 0 CHECK(is_abnormal IN (0,1)),
          validated_by TEXT REFERENCES users(id),
          validated_at INTEGER,
          remarks TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');

      // invoices
      db.execute('''
        CREATE TABLE invoices (
          id TEXT PRIMARY KEY,
          invoice_no TEXT NOT NULL UNIQUE,
          patient_id TEXT NOT NULL REFERENCES patients(id) ON UPDATE CASCADE ON DELETE RESTRICT,
          issued_at INTEGER NOT NULL,
          status TEXT NOT NULL CHECK(status IN ('draft','open','paid','void')),
          subtotal_cents INTEGER NOT NULL DEFAULT 0,
          discount_cents INTEGER NOT NULL DEFAULT 0,
          tax_cents INTEGER NOT NULL DEFAULT 0,
          total_cents INTEGER NOT NULL DEFAULT 0,
          paid_cents INTEGER NOT NULL DEFAULT 0,
          balance_cents INTEGER NOT NULL DEFAULT 0,
          created_by TEXT REFERENCES users(id),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute('CREATE INDEX idx_invoices_patient ON invoices(patient_id);');
      db.execute('CREATE INDEX idx_invoices_issued ON invoices(issued_at);');
      db.execute('CREATE INDEX idx_invoices_status ON invoices(status);');

      // invoice_items
      db.execute('''
        CREATE TABLE invoice_items (
          id TEXT PRIMARY KEY,
          invoice_id TEXT NOT NULL REFERENCES invoices(id) ON UPDATE CASCADE ON DELETE CASCADE,
          patient_test_id TEXT NOT NULL REFERENCES patient_tests(id) ON UPDATE CASCADE ON DELETE RESTRICT,
          test_id TEXT NOT NULL REFERENCES tests_master(id) ON UPDATE CASCADE ON DELETE RESTRICT,
          description TEXT,
          qty INTEGER NOT NULL DEFAULT 1 CHECK(qty > 0),
          unit_price_cents INTEGER NOT NULL,
          discount_cents INTEGER NOT NULL DEFAULT 0,
          line_total_cents INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute('CREATE UNIQUE INDEX idx_unique_invoice_item ON invoice_items(invoice_id, patient_test_id);');
      db.execute('CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);');

      // payments
      db.execute('''
        CREATE TABLE payments (
          id TEXT PRIMARY KEY,
          invoice_id TEXT NOT NULL REFERENCES invoices(id) ON UPDATE CASCADE ON DELETE CASCADE,
          amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
          method TEXT NOT NULL CHECK(method IN ('cash','card','bank','other')),
          reference TEXT,
          received_at INTEGER NOT NULL,
          received_by TEXT REFERENCES users(id),
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute('CREATE INDEX idx_payments_invoice ON payments(invoice_id);');
      db.execute('CREATE INDEX idx_payments_received_at ON payments(received_at);');

      // audit_logs
      db.execute('''
        CREATE TABLE audit_logs (
          id TEXT PRIMARY KEY,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          action TEXT NOT NULL CHECK(action IN ('insert','update','delete','login','logout','status_change','payment','print')),
          changed_by TEXT REFERENCES users(id),
          changed_at INTEGER NOT NULL,
          old_values TEXT,
          new_values TEXT
        );
      ''');
      db.execute('CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);');
      db.execute('CREATE INDEX idx_audit_changed_at ON audit_logs(changed_at);');

      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }
}
