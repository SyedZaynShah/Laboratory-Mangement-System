import 'package:flutter/foundation.dart';
import 'app_database.dart';

Future<void> seedInitialData(AppDatabase db) async {
  final countRs = db.db.select('SELECT COUNT(1) AS c FROM tests_master');
  final count = (countRs.first['c'] as int?) ?? 0;
  if (count > 0) return;

  final ts = DateTime.now().millisecondsSinceEpoch;
  final batch = db.db.prepare('''
    INSERT INTO tests_master (id, category_id, name, price, sample_type, unit, normal_range, is_panel, panel_items, is_enabled, lab_id, updated_at, sync_status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NULL, ?, 0)
  ''');

  try {
    // Hematology
    batch.execute(['CBC', 'HEM', 'Complete Blood Count (CBC)', 800.0, 'Whole Blood', '', '', 1, '["HB","WBC","Platelets"]', ts]);
    batch.execute(['HB', 'HEM', 'Hemoglobin', 200.0, 'Whole Blood', 'g/dL', '13-17', 0, null, ts]);
    batch.execute(['WBC', 'HEM', 'Total WBC', 200.0, 'Whole Blood', 'x10^3/uL', '4.0-11.0', 0, null, ts]);
    batch.execute(['PLT', 'HEM', 'Platelets', 200.0, 'Whole Blood', 'x10^3/uL', '150-400', 0, null, ts]);

    // Biochemistry
    batch.execute(['LFT', 'BIO', 'Liver Function Test Panel', 1200.0, 'Serum', '', '', 1, '["ALT","AST","ALP"]', ts]);
    batch.execute(['ALT', 'BIO', 'ALT', 250.0, 'Serum', 'U/L', '7-56', 0, null, ts]);
    batch.execute(['AST', 'BIO', 'AST', 250.0, 'Serum', 'U/L', '10-40', 0, null, ts]);
    batch.execute(['ALP', 'BIO', 'ALP', 250.0, 'Serum', 'U/L', '44-147', 0, null, ts]);

    // Serology
    batch.execute(['CRP', 'SER', 'CRP', 500.0, 'Serum', 'mg/L', '<5', 0, null, ts]);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Seed] error: $e');
    }
  } finally {
    batch.dispose();
  }
}
