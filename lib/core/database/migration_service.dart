import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart' as sq3;

class DatabaseMigrationService {
  static const int latestVersion = 11;

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
    if (currentVersion < 2) {
      _migrateToV2();
      _setUserVersion(2);
      _recordSchemaMigration(2);
      if (kDebugMode) {
        debugPrint('[DB] Migrated to schema version 2');
      }
    }
    if (currentVersion < 3) {
      _migrateToV3();
      _setUserVersion(3);
      _recordSchemaMigration(3);
      if (kDebugMode) {
        debugPrint('[DB] Migrated to schema version 3');
      }
    }
    if (currentVersion < 4) {
      _migrateToV4();
      _setUserVersion(4);
      _recordSchemaMigration(4);
      if (kDebugMode) {
        debugPrint('[DB] Migrated to schema version 4');
      }
    }
    if (currentVersion < 5) {
      _migrateToV5();
      _setUserVersion(5);
      _recordSchemaMigration(5);
      if (kDebugMode) {
        debugPrint('[DB] Migrated to schema version 5');
      }
    }
    if (currentVersion < 6) {
      _migrateToV6();
      _setUserVersion(6);
      _recordSchemaMigration(6);
      if (kDebugMode) {
        debugPrint('[DB] Migrated to schema version 6');
      }
    }
    if (currentVersion < 7) {
      _migrateToV7();
      _setUserVersion(7);
      _recordSchemaMigration(7);
      if (kDebugMode) {
        debugPrint('[DB] Migrated to schema version 7');
      }
    }
    if (currentVersion < 8) {
      _migrateToV8();
      _setUserVersion(8);
      _recordSchemaMigration(8);
      if (kDebugMode) {
        debugPrint('[DB] Migrated to schema version 8');
      }
    }
    if (currentVersion < 9) {
      _migrateToV9();
      _setUserVersion(9);
      _recordSchemaMigration(9);
      if (kDebugMode) {
        debugPrint('[DB] Migrated to schema version 9');
      }
    }
    if (currentVersion < 10) {
      _migrateToV10();
      _setUserVersion(10);
      _recordSchemaMigration(10);
      if (kDebugMode) {
        debugPrint('[DB] Migrated to schema version 10');
      }
    }
    if (currentVersion < 11) {
      _migrateToV11();
      _setUserVersion(11);
      _recordSchemaMigration(11);
      if (kDebugMode) {
        debugPrint('[DB] Migrated to schema version 11');
      }
    }
  }

  void _migrateToV10() {
    // Widen invoices.status CHECK to allow 'unpaid' and 'partially_paid'
    db.execute('PRAGMA foreign_keys = OFF;');
    db.execute('BEGIN;');
    try {
      final invTable = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='invoices' LIMIT 1;",
      );
      final invOldTable = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='invoices_old_v9' LIMIT 1;",
      );

      if (invTable.isEmpty && invOldTable.isEmpty) {
        db.execute('COMMIT;');
        db.execute('PRAGMA foreign_keys = ON;');
        return;
      }

      // If a previous migration attempt renamed invoices but failed mid-way,
      // we may already have invoices_old_v9 present.
      final sourceTable = invOldTable.isNotEmpty
          ? 'invoices_old_v9'
          : 'invoices';

      // Drop indexes that might already exist with these names (they may belong
      // to the old invoices table and would block recreation).
      db.execute('DROP INDEX IF EXISTS idx_invoices_patient;');
      db.execute('DROP INDEX IF EXISTS idx_invoices_issued;');
      db.execute('DROP INDEX IF EXISTS idx_invoices_status;');

      // If we are migrating from the live invoices table, rename it. Otherwise
      // keep using the already-renamed source.
      if (sourceTable == 'invoices') {
        db.execute('ALTER TABLE invoices RENAME TO invoices_old_v9;');
      }

      // In case a failed attempt already created the new invoices table, drop
      // it so we can recreate cleanly.
      db.execute('DROP TABLE IF EXISTS invoices;');
      db.execute('''
        CREATE TABLE invoices (
          id TEXT PRIMARY KEY,
          invoice_no TEXT NOT NULL UNIQUE,
          patient_id TEXT NOT NULL REFERENCES patients(id) ON UPDATE CASCADE ON DELETE RESTRICT,
          issued_at INTEGER NOT NULL,
          status TEXT NOT NULL CHECK(status IN ('draft','unpaid','partially_paid','paid','void')),
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
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_patient ON invoices(patient_id);',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_issued ON invoices(issued_at);',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);',
      );

      // Copy rows and map legacy 'open' to 'unpaid'/'partially_paid'
      db.execute('''
        INSERT INTO invoices(
          id, invoice_no, patient_id, issued_at, status,
          subtotal_cents, discount_cents, tax_cents, total_cents,
          paid_cents, balance_cents, created_by, created_at, updated_at, deleted_at
        )
        SELECT
          id, invoice_no, patient_id, issued_at,
          CASE
            WHEN status = 'paid' THEN 'paid'
            WHEN status = 'void' THEN 'void'
            WHEN status = 'draft' THEN 'draft'
            ELSE
              CASE
                WHEN COALESCE(paid_cents,0) <= 0 THEN 'unpaid'
                WHEN COALESCE(balance_cents,0) <= 0 THEN 'paid'
                ELSE 'partially_paid'
              END
          END AS status,
          subtotal_cents, discount_cents, tax_cents, total_cents,
          paid_cents, balance_cents, created_by, created_at, updated_at, deleted_at
        FROM $sourceTable;
      ''');

      db.execute('DROP TABLE IF EXISTS invoices_old_v9;');

      db.execute('COMMIT;');
      db.execute('PRAGMA foreign_keys = ON;');
    } catch (e) {
      db.execute('ROLLBACK;');
      db.execute('PRAGMA foreign_keys = ON;');
      rethrow;
    }
  }

  void _migrateToV11() {
    db.execute('PRAGMA foreign_keys = OFF;');
    db.execute('BEGIN;');
    try {
      final invRows = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='invoices' LIMIT 1;",
      );
      if (invRows.isEmpty) {
        db.execute('COMMIT;');
        db.execute('PRAGMA foreign_keys = ON;');
        return;
      }

      final invoiceItemsSqlRows = db.select(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='invoice_items' LIMIT 1;",
      );
      final invoiceItemsSql = invoiceItemsSqlRows.isEmpty
          ? ''
          : (invoiceItemsSqlRows.first['sql'] as String? ?? '');
      final invoiceItemsNeedsRepair = invoiceItemsSql.contains(
        'invoices_old_v9',
      );

      if (invoiceItemsNeedsRepair) {
        db.execute(
          'ALTER TABLE invoice_items RENAME TO invoice_items_old_v11;',
        );
        db.execute('''
          CREATE TABLE invoice_items (
            id TEXT PRIMARY KEY,
            invoice_id TEXT NOT NULL REFERENCES invoices(id) ON UPDATE CASCADE ON DELETE CASCADE,
            test_order_item_id TEXT NOT NULL REFERENCES test_order_items(id) ON UPDATE CASCADE ON DELETE RESTRICT,
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
        db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_invoice_item ON invoice_items(invoice_id, test_order_item_id);',
        );
        db.execute(
          'CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id);',
        );
        db.execute('''
          INSERT INTO invoice_items(
            id, invoice_id, test_order_item_id, test_id, description,
            qty, unit_price_cents, discount_cents, line_total_cents,
            created_at, updated_at, deleted_at
          )
          SELECT
            id, invoice_id, test_order_item_id, test_id, description,
            qty, unit_price_cents, discount_cents, line_total_cents,
            created_at, updated_at, deleted_at
          FROM invoice_items_old_v11;
        ''');
        db.execute('DROP TABLE invoice_items_old_v11;');
      }

      final paymentsSqlRows = db.select(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='payments' LIMIT 1;",
      );
      final paymentsSql = paymentsSqlRows.isEmpty
          ? ''
          : (paymentsSqlRows.first['sql'] as String? ?? '');
      final paymentsNeedsRepair = paymentsSql.contains('invoices_old_v9');

      if (paymentsNeedsRepair) {
        db.execute('ALTER TABLE payments RENAME TO payments_old_v11;');
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
        db.execute(
          'CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id);',
        );
        db.execute(
          'CREATE INDEX IF NOT EXISTS idx_payments_received_at ON payments(received_at);',
        );
        db.execute('''
          INSERT INTO payments(
            id, invoice_id, amount_cents, method, reference,
            received_at, received_by, notes, created_at, updated_at, deleted_at
          )
          SELECT
            id, invoice_id, amount_cents, method, reference,
            received_at, received_by, notes, created_at, updated_at, deleted_at
          FROM payments_old_v11;
        ''');
        db.execute('DROP TABLE payments_old_v11;');
      }

      db.execute('COMMIT;');
      db.execute('PRAGMA foreign_keys = ON;');
    } catch (e) {
      db.execute('ROLLBACK;');
      db.execute('PRAGMA foreign_keys = ON;');
      rethrow;
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
    // Ensure table exists even for databases created before v1 introduced it
    db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        applied_at INTEGER NOT NULL
      );
    ''');
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    db.execute(
      'INSERT OR REPLACE INTO schema_migrations(version, applied_at) VALUES (?, ?);',
      [version, ts],
    );
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
      db.execute(
        'CREATE UNIQUE INDEX idx_unique_test_categories ON test_categories(name, parent_id);',
      );

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
      db.execute(
        'CREATE INDEX idx_tests_category ON tests_master(category_id);',
      );
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
      db.execute(
        'CREATE INDEX idx_ref_ranges_test ON test_reference_ranges(test_id);',
      );

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
      db.execute(
        'CREATE INDEX idx_pt_ordered_at ON patient_tests(ordered_at);',
      );

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
      db.execute(
        'CREATE INDEX idx_samples_collected_at ON samples(collected_at);',
      );

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
      db.execute(
        'CREATE UNIQUE INDEX idx_unique_invoice_item ON invoice_items(invoice_id, patient_test_id);',
      );
      db.execute(
        'CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);',
      );

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
      db.execute(
        'CREATE INDEX idx_payments_received_at ON payments(received_at);',
      );

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
      db.execute(
        'CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);',
      );
      db.execute(
        'CREATE INDEX idx_audit_changed_at ON audit_logs(changed_at);',
      );

      db.execute('COMMIT;');
      db.execute('PRAGMA foreign_keys = ON;');
    } catch (e) {
      db.execute('ROLLBACK;');
      db.execute('PRAGMA foreign_keys = ON;');
      rethrow;
    }
  }

  void _migrateToV2() {
    db.execute('BEGIN;');
    try {
      db.execute('''
        CREATE TABLE IF NOT EXISTS test_orders (
          id TEXT PRIMARY KEY,
          order_number TEXT NOT NULL UNIQUE,
          patient_id TEXT NOT NULL REFERENCES patients(id) ON UPDATE CASCADE ON DELETE RESTRICT,
          ordered_at INTEGER NOT NULL,
          status TEXT NOT NULL CHECK(status IN ('ordered','sample_collected','in_process','completed')),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_test_orders_patient ON test_orders(patient_id);',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_test_orders_ordered_at ON test_orders(ordered_at);',
      );

      db.execute('''
        CREATE TABLE IF NOT EXISTS test_order_items (
          id TEXT PRIMARY KEY,
          order_id TEXT NOT NULL REFERENCES test_orders(id) ON UPDATE CASCADE ON DELETE CASCADE,
          test_id TEXT NOT NULL REFERENCES tests_master(id) ON UPDATE CASCADE ON DELETE RESTRICT,
          price_cents INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_items_order ON test_order_items(order_id);',
      );

      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _migrateToV3() {
    db.execute('BEGIN;');
    try {
      // Replace legacy samples table (patient_tests-based) with order_items-based samples
      db.execute('DROP TABLE IF EXISTS samples;');
      db.execute('''
        CREATE TABLE samples (
          id TEXT PRIMARY KEY,
          test_order_item_id TEXT NOT NULL UNIQUE REFERENCES test_order_items(id) ON UPDATE CASCADE ON DELETE CASCADE,
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
      db.execute(
        'CREATE INDEX idx_samples_order_item ON samples(test_order_item_id);',
      );
      db.execute('CREATE INDEX idx_samples_status ON samples(status);');
      db.execute(
        'CREATE INDEX idx_samples_collected_at ON samples(collected_at);',
      );

      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _migrateToV4() {
    db.execute('BEGIN;');
    try {
      // Drop legacy test_results that used patient_test_id to prevent index errors
      final tables = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='test_results';",
      );
      if (tables.isNotEmpty) {
        final cols = db.select("PRAGMA table_info('test_results');");
        final hasNew = cols.any((r) {
          final n = r['name'];
          return n == 'test_order_item_id';
        });
        if (!hasNew) {
          db.execute('DROP TABLE IF EXISTS test_results;');
        }
      }
      db.execute('''
        CREATE TABLE IF NOT EXISTS test_results (
          id TEXT PRIMARY KEY,
          test_order_item_id TEXT NOT NULL UNIQUE REFERENCES test_order_items(id) ON UPDATE CASCADE ON DELETE CASCADE,
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
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_results_item ON test_results(test_order_item_id);',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_results_validated_at ON test_results(validated_at);',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_results_abnormal ON test_results(is_abnormal);',
      );

      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _migrateToV5() {
    db.execute('BEGIN;');
    try {
      // Recreate invoice_items to reference test_order_items rather than patient_tests
      db.execute('DROP TABLE IF EXISTS invoice_items;');
      db.execute('''
        CREATE TABLE invoice_items (
          id TEXT PRIMARY KEY,
          invoice_id TEXT NOT NULL REFERENCES invoices(id) ON UPDATE CASCADE ON DELETE CASCADE,
          test_order_item_id TEXT NOT NULL REFERENCES test_order_items(id) ON UPDATE CASCADE ON DELETE RESTRICT,
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
      db.execute(
        'CREATE UNIQUE INDEX idx_unique_invoice_item ON invoice_items(invoice_id, test_order_item_id);',
      );
      db.execute(
        'CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);',
      );

      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _migrateToV6() {
    db.execute('PRAGMA foreign_keys = OFF;');
    db.execute('BEGIN;');
    try {
      // Ensure audit_logs index on changed_by exists
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_changed_by ON audit_logs(changed_by);',
      );

      // Widen users.role CHECK to include new roles. SQLite can't alter CHECK directly,
      // so recreate table if current schema lacks the roles.
      final cols = db.select("PRAGMA table_info('users');");
      final hasUsers = cols.isNotEmpty;
      if (hasUsers) {
        final usersSqlRow = db.select(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='users' LIMIT 1;",
        );
        final usersSql = usersSqlRow.isEmpty
            ? ''
            : (usersSqlRow.first['sql'] as String? ?? '');
        final needsRecreate =
            !usersSql.contains("'pathologist'") ||
            !usersSql.contains("'accountant'");
        if (needsRecreate) {
          final backupRow = db.select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='users_old_v5' LIMIT 1;",
          );
          final backupExists = backupRow.isNotEmpty;
          if (backupExists) {
            // If backup exists from a previous attempt, ensure a clean users table
            final existsUsersRow = db.select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='users' LIMIT 1;",
            );
            final existsUsers = existsUsersRow.isNotEmpty;
            if (existsUsers) {
              db.execute('DROP TABLE users;');
            }
            db.execute('''
              CREATE TABLE users (
                id TEXT PRIMARY KEY,
                email TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                name TEXT NOT NULL,
                role TEXT NOT NULL CHECK(role IN ('admin','receptionist','technician','pathologist','accountant')),
                phone TEXT,
                is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted_at INTEGER
              );
            ''');
            db.execute('''
              INSERT INTO users (
                id, email, password_hash, name, role, phone, is_active, created_at, updated_at, deleted_at
              )
              SELECT id, email, password_hash, name, role, phone, is_active, created_at, updated_at, deleted_at
              FROM users_old_v5;
            ''');
            db.execute(
              'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);',
            );
          } else {
            // Normal path: rename, create, copy
            db.execute('ALTER TABLE users RENAME TO users_old_v5;');
            db.execute('''
              CREATE TABLE users (
                id TEXT PRIMARY KEY,
                email TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                name TEXT NOT NULL,
                role TEXT NOT NULL CHECK(role IN ('admin','receptionist','technician','pathologist','accountant')),
                phone TEXT,
                is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted_at INTEGER
              );
            ''');
            db.execute('''
              INSERT INTO users (
                id, email, password_hash, name, role, phone, is_active, created_at, updated_at, deleted_at
              )
              SELECT id, email, password_hash, name, role, phone, is_active, created_at, updated_at, deleted_at
              FROM users_old_v5;
            ''');
            db.execute(
              'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);',
            );
          }
        }
      }

      db.execute('COMMIT;');
      db.execute('PRAGMA foreign_keys = ON;');
    } catch (e) {
      db.execute('ROLLBACK;');
      db.execute('PRAGMA foreign_keys = ON;');
      rethrow;
    }
  }

  void _migrateToV7() {
    db.execute('BEGIN;');
    try {
      db.execute('''
        CREATE TABLE IF NOT EXISTS lab_profile (
          id TEXT PRIMARY KEY,
          lab_name TEXT NOT NULL,
          address TEXT,
          phone TEXT,
          email TEXT,
          logo_path TEXT,
          created_at INTEGER NOT NULL
        );
      ''');
      final rows = db.select("SELECT COUNT(1) AS c FROM lab_profile;");
      final c = (rows.isEmpty ? 0 : (rows.first['c'] as int? ?? 0));
      if (c == 0) {
        final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        db.execute(
          'INSERT INTO lab_profile (id, lab_name, address, phone, email, logo_path, created_at) VALUES (?,?,?,?,?,?,?)',
          ['lab', 'Your Lab Name', '', '', '', null, ts],
        );
      }
      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _migrateToV8() {
    db.execute('BEGIN;');
    try {
      db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id TEXT PRIMARY KEY,
          category TEXT NOT NULL,
          amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
          occurred_at INTEGER NOT NULL,
          notes TEXT,
          created_by TEXT REFERENCES users(id),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_occurred_at ON expenses(occurred_at);',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);',
      );
      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _migrateToV9() {
    db.execute('BEGIN;');
    try {
      // Finance: expenses table for installations that already reached v8
      db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id TEXT PRIMARY KEY,
          category TEXT NOT NULL,
          amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
          occurred_at INTEGER NOT NULL,
          notes TEXT,
          created_by TEXT REFERENCES users(id),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        );
      ''');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_occurred_at ON expenses(occurred_at);',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);',
      );
      db.execute('COMMIT;');
    } catch (e) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }
}
