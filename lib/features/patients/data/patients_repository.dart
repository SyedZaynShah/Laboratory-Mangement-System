import 'package:riverpod/riverpod.dart';
import 'package:sqlite3/sqlite3.dart' as sq3;
import '../../../core/database/base_repository.dart';

class PatientsRepository extends BaseRepository {
  PatientsRepository(super.ref);

  Future<String> createPatient({
    required String fullName,
    String? cnic,
    int? dateOfBirthSec,
    required String gender,
    String? phone,
    String? address,
    String? referredBy,
  }) async {
    final d = await db;
    final cnicVal = cnic?.trim();
    if (cnicVal != null && cnicVal.isNotEmpty) {
      final dup = d.select(
        'SELECT id FROM patients WHERE cnic = ? AND deleted_at IS NULL LIMIT 1',
        [cnicVal],
      );
      if (dup.isNotEmpty) {
        throw StateError('A patient with this CNIC already exists.');
      }
    }
    final id = newId();
    final ts = nowSec();
    final stmt = d.prepare('''
      INSERT INTO patients (
        id, full_name, cnic, date_of_birth, gender, phone, address, referred_by, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute([
        id,
        fullName.trim(),
        cnicVal,
        dateOfBirthSec,
        gender,
        phone?.trim(),
        address?.trim(),
        referredBy?.trim(),
        ts,
        ts,
      ]);
      return id;
    } on sq3.SqliteException catch (e) {
      final msg = e.message.toLowerCase();
      if (e.extendedResultCode == 2067 ||
          msg.contains('unique') && msg.contains('patients.cnic')) {
        throw StateError('A patient with this CNIC already exists.');
      }
      rethrow;
    } finally {
      stmt.dispose();
    }
  }

  Future<Map<String, Object?>?> getPatientById(String id) async {
    final d = await db;
    final stmt = d.prepare('''
      SELECT id, full_name, cnic, date_of_birth, gender, phone, address, referred_by, created_at, updated_at, deleted_at
      FROM patients
      WHERE id = ? AND deleted_at IS NULL
      LIMIT 1
    ''');
    try {
      final rs = stmt.select([id]);
      if (rs.isEmpty) return null;
      final row = rs.first;
      return {
        'id': row['id'],
        'full_name': row['full_name'],
        'cnic': row['cnic'],
        'date_of_birth': row['date_of_birth'],
        'gender': row['gender'],
        'phone': row['phone'],
        'address': row['address'],
        'referred_by': row['referred_by'],
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
        'deleted_at': row['deleted_at'],
      };
    } finally {
      stmt.dispose();
    }
  }

  Future<List<Map<String, Object?>>> searchPatients(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final d = await db;
    final q = '%${query.trim()}%';
    final stmt = d.prepare('''
      SELECT id, full_name, cnic, date_of_birth, gender, phone, address, referred_by, created_at, updated_at
      FROM patients
      WHERE ${notDeleted()} AND (
        full_name LIKE ? OR phone LIKE ? OR cnic LIKE ?
      )
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    ''');
    try {
      final rs = stmt.select([q, q, q, limit, offset]);
      return rs
          .map(
            (row) => {
              'id': row['id'],
              'full_name': row['full_name'],
              'cnic': row['cnic'],
              'date_of_birth': row['date_of_birth'],
              'gender': row['gender'],
              'phone': row['phone'],
              'address': row['address'],
              'referred_by': row['referred_by'],
              'created_at': row['created_at'],
              'updated_at': row['updated_at'],
            },
          )
          .toList(growable: false);
    } finally {
      stmt.dispose();
    }
  }

  Future<List<Map<String, Object?>>> listPatients({
    int limit = 20,
    int offset = 0,
  }) async {
    final d = await db;
    final stmt = d.prepare('''
      SELECT id, full_name, cnic, date_of_birth, gender, phone, address, referred_by, created_at, updated_at
      FROM patients
      WHERE ${notDeleted()}
      ORDER BY created_at DESC
      LIMIT ? OFFSET ?
    ''');
    try {
      final rs = stmt.select([limit, offset]);
      return rs
          .map(
            (row) => {
              'id': row['id'],
              'full_name': row['full_name'],
              'cnic': row['cnic'],
              'date_of_birth': row['date_of_birth'],
              'gender': row['gender'],
              'phone': row['phone'],
              'address': row['address'],
              'referred_by': row['referred_by'],
              'created_at': row['created_at'],
              'updated_at': row['updated_at'],
            },
          )
          .toList(growable: false);
    } finally {
      stmt.dispose();
    }
  }

  Future<int> updatePatient(
    String id, {
    String? fullName,
    String? cnic,
    int? dateOfBirthSec,
    String? gender,
    String? phone,
    String? address,
    String? referredBy,
  }) async {
    final d = await db;
    if (cnic != null) {
      final newCnic = cnic.trim();
      if (newCnic.isNotEmpty) {
        final dup = d.select(
          'SELECT id FROM patients WHERE cnic = ? AND id <> ? AND deleted_at IS NULL LIMIT 1',
          [newCnic, id],
        );
        if (dup.isNotEmpty) {
          throw StateError('Another patient with this CNIC already exists.');
        }
      }
    }
    final fields = <String>[];
    final values = <Object?>[];
    if (fullName != null) {
      fields.add('full_name = ?');
      values.add(fullName.trim());
    }
    if (cnic != null) {
      fields.add('cnic = ?');
      values.add(cnic.trim());
    }
    if (dateOfBirthSec != null) {
      fields.add('date_of_birth = ?');
      values.add(dateOfBirthSec);
    }
    if (gender != null) {
      fields.add('gender = ?');
      values.add(gender);
    }
    if (phone != null) {
      fields.add('phone = ?');
      values.add(phone.trim());
    }
    if (address != null) {
      fields.add('address = ?');
      values.add(address.trim());
    }
    if (referredBy != null) {
      fields.add('referred_by = ?');
      values.add(referredBy.trim());
    }
    if (fields.isEmpty) return 0;
    fields.add('updated_at = ?');
    values.add(nowSec());
    values.add(id);
    final sql =
        'UPDATE patients SET ${fields.join(', ')} WHERE id = ? AND deleted_at IS NULL';
    final stmt = d.prepare(sql);
    try {
      stmt.execute(values);
      return d.getUpdatedRows();
    } on sq3.SqliteException catch (e) {
      final msg = e.message.toLowerCase();
      if (e.extendedResultCode == 2067 ||
          msg.contains('unique') && msg.contains('patients.cnic')) {
        throw StateError('Another patient with this CNIC already exists.');
      }
      rethrow;
    } finally {
      stmt.dispose();
    }
  }

  Future<int> softDeletePatient(String id) {
    return softDelete('patients', id);
  }

  Future<List<Map<String, Object?>>> listPatientInsightTimeline({
    required String patientId,
    required int? fromSec,
    required int? toSec,
    int limit = 200,
  }) async {
    final d = await db;
    final rows = d.select(
      '''
      WITH ord AS (
        SELECT o.id, o.order_number, o.patient_id, o.ordered_at, o.status
        FROM test_orders o
        WHERE o.deleted_at IS NULL
          AND o.patient_id = ?
          AND (? IS NULL OR o.ordered_at >= ?)
          AND (? IS NULL OR o.ordered_at <= ?)
      ),
      ord_tests AS (
        SELECT o.id AS order_id,
               COUNT(1) AS tests_count,
               COALESCE(SUM(toi.price_cents),0) AS tests_total_cents
        FROM ord o
        JOIN test_order_items toi ON toi.order_id = o.id
        GROUP BY o.id
      ),
      inv_for_order AS (
        SELECT o.id AS order_id,
               ii.invoice_id AS invoice_id
        FROM ord o
        JOIN test_order_items toi ON toi.order_id = o.id
        JOIN invoice_items ii ON ii.test_order_item_id = toi.id
        WHERE ii.deleted_at IS NULL
        GROUP BY o.id
      ),
      inv_sum AS (
        SELECT x.order_id AS order_id,
               COALESCE(SUM(i.total_cents),0) AS total_cents,
               COALESCE(SUM(i.balance_cents),0) AS balance_cents
        FROM inv_for_order x
        JOIN invoices i ON i.id = x.invoice_id
        WHERE i.deleted_at IS NULL
        GROUP BY x.order_id
      ),
      pay_sum AS (
        SELECT x.order_id AS order_id,
               COALESCE(SUM(p.amount_cents),0) AS cash_received_cents
        FROM inv_for_order x
        JOIN payments p ON p.invoice_id = x.invoice_id
        WHERE p.deleted_at IS NULL
        GROUP BY x.order_id
      )
      SELECT
        o.id AS order_id,
        o.order_number,
        o.ordered_at,
        COALESCE(ot.tests_count,0) AS tests_count,
        COALESCE(isum.total_cents, COALESCE(ot.tests_total_cents,0)) AS total_cents,
        COALESCE(psum.cash_received_cents,0) AS cash_received_cents,
        COALESCE(isum.balance_cents, (COALESCE(isum.total_cents, COALESCE(ot.tests_total_cents,0)) - COALESCE(psum.cash_received_cents,0))) AS balance_cents,
        CASE WHEN o.status = 'completed' THEN 'Completed' ELSE 'Not Completed' END AS status
      FROM ord o
      LEFT JOIN ord_tests ot ON ot.order_id = o.id
      LEFT JOIN inv_sum isum ON isum.order_id = o.id
      LEFT JOIN pay_sum psum ON psum.order_id = o.id
      ORDER BY o.ordered_at DESC
      LIMIT ?;
    ''',
      [patientId, fromSec, fromSec, toSec, toSec, limit],
    );

    return rows
        .map((r) => Map<String, Object?>.from(r))
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> listPatientInsights({
    required int? fromSec,
    required int? toSec,
    String query = '',
    int limit = 200,
  }) async {
    final d = await db;
    final q = query.trim();
    final like = '%$q%';

    final rows = d.select(
      '''
      WITH ord AS (
        SELECT o.id, o.patient_id, o.ordered_at, o.status
        FROM test_orders o
        WHERE o.deleted_at IS NULL
          AND (? IS NULL OR o.ordered_at >= ?)
          AND (? IS NULL OR o.ordered_at <= ?)
      ),
      ord_items AS (
        SELECT o.patient_id AS patient_id,
               COUNT(1) AS tests_count
        FROM ord o
        JOIN test_order_items toi ON toi.order_id = o.id
        GROUP BY o.patient_id
      ),
      inv_ids AS (
        SELECT DISTINCT o.patient_id AS patient_id,
                        ii.invoice_id AS invoice_id
        FROM ord o
        JOIN test_order_items toi ON toi.order_id = o.id
        JOIN invoice_items ii ON ii.test_order_item_id = toi.id
        WHERE ii.deleted_at IS NULL
      ),
      inv_sum AS (
        SELECT x.patient_id AS patient_id,
               COALESCE(SUM(i.total_cents),0) AS total_cents,
               COALESCE(SUM(i.balance_cents),0) AS balance_cents
        FROM inv_ids x
        JOIN invoices i ON i.id = x.invoice_id
        WHERE i.deleted_at IS NULL
        GROUP BY x.patient_id
      ),
      pay_sum AS (
        SELECT x.patient_id AS patient_id,
               COALESCE(SUM(p.amount_cents),0) AS cash_received_cents
        FROM inv_ids x
        JOIN payments p ON p.invoice_id = x.invoice_id
        WHERE p.deleted_at IS NULL
        GROUP BY x.patient_id
      )
      SELECT
        p.id AS patient_id,
        p.full_name,
        p.phone,
        p.cnic,
        COALESCE(COUNT(DISTINCT o.id),0) AS total_orders,
        COALESCE(oi.tests_count,0) AS total_tests,
        COALESCE(isum.total_cents,0) AS total_cents,
        COALESCE(psum.cash_received_cents,0) AS cash_received_cents,
        COALESCE(isum.balance_cents,0) AS balance_cents,
        COALESCE(MAX(o.ordered_at), 0) AS last_order_at,
        CASE WHEN COALESCE(MAX(CASE WHEN o.status = 'completed' THEN 1 ELSE 0 END),0) = 1 THEN 'Completed' ELSE 'Not Completed' END AS status
      FROM patients p
      LEFT JOIN ord o ON o.patient_id = p.id
      LEFT JOIN ord_items oi ON oi.patient_id = p.id
      LEFT JOIN inv_sum isum ON isum.patient_id = p.id
      LEFT JOIN pay_sum psum ON psum.patient_id = p.id
      WHERE p.deleted_at IS NULL
        AND (? = '' OR p.full_name LIKE ? OR p.phone LIKE ? OR p.cnic LIKE ?)
      GROUP BY p.id
      HAVING COUNT(DISTINCT o.id) > 0
      ORDER BY last_order_at DESC, p.full_name
      LIMIT ?;
    ''',
      [fromSec, fromSec, toSec, toSec, q, like, like, like, limit],
    );

    return rows
        .map((r) => Map<String, Object?>.from(r))
        .toList(growable: false);
  }
}

final patientsRepositoryProvider = Provider<PatientsRepository>((ref) {
  return PatientsRepository(ref);
});
