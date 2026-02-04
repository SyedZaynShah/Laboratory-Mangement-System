import 'dart:io';
import 'dart:typed_data';

import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';

class LabProfileRepository extends BaseRepository {
  LabProfileRepository(Ref ref) : super(ref);

  Future<Map<String, Object?>?> getProfile() async {
    final d = await db;
    final rows = d.select('SELECT * FROM lab_profile LIMIT 1');
    if (rows.isEmpty) return null;
    return Map<String, Object?>.from(rows.first);
  }

  Future<void> upsertProfile({
    required String labName,
    String? address,
    String? phone,
    String? email,
    String? logoPath,
  }) async {
    final d = await db;
    final ts = nowSec();
    final rows = d.select("SELECT id FROM lab_profile LIMIT 1");
    if (rows.isEmpty) {
      final ins = d.prepare(
        'INSERT INTO lab_profile(id, lab_name, address, phone, email, logo_path, created_at) VALUES (?,?,?,?,?,?,?)',
      );
      try {
        ins.execute([
          'lab',
          labName.trim(),
          address,
          phone,
          email,
          logoPath,
          ts,
        ]);
      } finally {
        ins.dispose();
      }
    } else {
      final upd = d.prepare(
        'UPDATE lab_profile SET lab_name = ?, address = ?, phone = ?, email = ?, logo_path = ? WHERE id = ?',
      );
      try {
        upd.execute([
          labName.trim(),
          address,
          phone,
          email,
          logoPath,
          rows.first['id'],
        ]);
      } finally {
        upd.dispose();
      }
    }
  }

  Future<Uint8List?> loadLogoBytes() async {
    final p = (await getProfile())?['logo_path'] as String?;
    if (p == null || p.isEmpty) return null;
    final f = File(p);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }
}

final labProfileRepositoryProvider = Provider<LabProfileRepository>((ref) {
  return LabProfileRepository(ref);
});
