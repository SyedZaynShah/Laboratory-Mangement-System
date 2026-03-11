import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart' as sq3;

import '../../data/default_tests.dart';

Future<void> seedDefaultTests(sq3.Database db) async {
  final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final categories = <String>{
    'Hematology',
    'Biochemistry',
    'Microbiology',
    'Serology',
    'Endocrinology',
    'Immunology',
    'Pathology',
    'Molecular Diagnostics',
    'Urinalysis',
    'Cytology',
  };

  String _categoryId(String name) {
    final slug = name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'CAT_$slug';
  }

  double? _parseRange(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == '-' || s.toLowerCase() == 'n/a') return null;
    return double.tryParse(s);
  }

  try {
    final insCat = db.prepare(
      'INSERT OR IGNORE INTO test_categories(id, name, parent_id, sort_order, created_at, updated_at) VALUES (?,?,NULL,0,?,?)',
    );
    try {
      for (final c in categories) {
        final id = _categoryId(c);
        insCat.execute([id, c, ts, ts]);
      }
    } finally {
      insCat.dispose();
    }

    final catRows = db.select(
      'SELECT id, name FROM test_categories WHERE deleted_at IS NULL',
    );
    final catByName = <String, String>{};
    for (final r in catRows) {
      final n = r['name'] as String?;
      final id = r['id'] as String?;
      if (n != null && id != null) {
        catByName[n] = id;
      }
    }

    final insTest = db.prepare('''
      INSERT OR IGNORE INTO tests_master(
        id, code, category_id, name, sample_type, unit, method, price_cents, is_panel, created_at, updated_at
      ) VALUES (?,?,?,?,?,?,NULL,?,0,?,?)
    ''');
    final insRange = db.prepare('''
      INSERT OR IGNORE INTO test_reference_ranges(
        id, test_id, gender, age_min_years, age_max_years, value_min, value_max, text_range, unit, created_at, updated_at
      ) VALUES (?,?,NULL,NULL,NULL,?,?,NULL,?,?,?)
    ''');

    try {
      final seenCodes = <String>{};
      for (final t in defaultTests) {
        final codeRaw = (t['test_code'] as String?) ?? '';
        final code = codeRaw.trim();
        if (code.isEmpty) continue;
        if (!seenCodes.add(code)) continue;

        final name = ((t['test_name'] as String?) ?? '').trim();
        if (name.isEmpty) continue;

        final category = ((t['category'] as String?) ?? '').trim();
        final categoryId = catByName[category];

        var sample = ((t['sample_type'] as String?) ?? '').trim();
        if (sample.isEmpty) sample = 'Blood';

        var unit = ((t['unit'] as String?) ?? '').trim();
        if (unit.isEmpty) unit = 'N/A';

        final priceAny = t['price'];
        final price = (priceAny is num)
            ? priceAny.toInt()
            : int.tryParse('${priceAny ?? 0}') ?? 0;
        final priceCents = price <= 0 ? 0 : price * 100;

        final id = (t['id'] as String?)?.trim();
        final testId = (id == null || id.isEmpty) ? 'DEF_$code' : id;

        insTest.execute([
          testId,
          code,
          categoryId,
          name,
          sample,
          unit,
          priceCents,
          ts,
          ts,
        ]);

        final resolved = db.select(
          'SELECT id FROM tests_master WHERE code = ? LIMIT 1',
          [code],
        );
        if (resolved.isEmpty) continue;
        final actualTestId = resolved.first['id'] as String;

        final min = _parseRange(t['normal_range_min']);
        final max = _parseRange(t['normal_range_max']);
        if (min == null && max == null) continue;

        final rrId = 'RR_$code';
        insRange.execute([rrId, actualTestId, min, max, unit, ts, ts]);
      }
    } finally {
      insTest.dispose();
      insRange.dispose();
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Seed] error: $e');
    }
  }
}
