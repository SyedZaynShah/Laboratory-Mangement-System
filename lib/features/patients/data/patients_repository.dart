import 'package:riverpod/riverpod.dart';
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
        cnic?.trim(),
        dateOfBirthSec,
        gender,
        phone?.trim(),
        address?.trim(),
        referredBy?.trim(),
        ts,
        ts,
      ]);
      return id;
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
    } finally {
      stmt.dispose();
    }
  }

  Future<int> softDeletePatient(String id) {
    return softDelete('patients', id);
  }
}

final patientsRepositoryProvider = Provider<PatientsRepository>((ref) {
  return PatientsRepository(ref);
});
