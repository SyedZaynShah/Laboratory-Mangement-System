import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';
import 'test_model.dart';

class TestsRepository extends BaseRepository {
  TestsRepository(Ref ref) : super(ref);

  Future<String?> _ensureCategory(String? name) async {
    if (name == null || name.trim().isEmpty) return null;
    final d = await db;
    final n = name.trim();
    final rows = d.select(
      'SELECT id FROM test_categories WHERE name = ? AND deleted_at IS NULL LIMIT 1',
      [n],
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;
    final id = newId();
    final ts = nowSec();
    final stmt = d.prepare(
      'INSERT INTO test_categories(id, name, created_at, updated_at) VALUES (?,?,?,?)',
    );
    try {
      stmt.execute([id, n, ts, ts]);
    } finally {
      stmt.dispose();
    }
    return id;
  }

  TestModel _fromRow(Map<String, Object?> r) {
    return TestModel(
      id: r['id'] as String?,
      testCode: (r['code'] as String?) ?? '',
      testName: (r['name'] as String?) ?? '',
      category: r['category_name'] as String?,
      sampleType: (r['sample_type'] as String?) ?? '',
      unit: r['unit'] as String?,
      normalRangeMin: (r['value_min'] is num)
          ? (r['value_min'] as num).toDouble()
          : null,
      normalRangeMax: (r['value_max'] is num)
          ? (r['value_max'] as num).toDouble()
          : null,
      priceCents: (r['price_cents'] is int)
          ? r['price_cents'] as int
          : (r['price_cents'] is num)
          ? (r['price_cents'] as num).toInt()
          : 0,
      clinicalNotes: null,
      isActive: r['deleted_at'] == null,
      createdAt: (r['created_at'] is int) ? r['created_at'] as int : null,
      updatedAt: (r['updated_at'] is int) ? r['updated_at'] as int : null,
    );
  }

  Future<List<TestModel>> getTests({required int page}) async {
    final d = await db;
    final limit = 20;
    final offset = page <= 1 ? 0 : (page - 1) * limit;
    final rows = d.select(
      '''
      SELECT t.*, c.name AS category_name,
             r.value_min, r.value_max
      FROM tests_master t
      LEFT JOIN test_categories c ON c.id = t.category_id
      LEFT JOIN (
        SELECT test_id, value_min, value_max
        FROM test_reference_ranges
        WHERE gender IS NULL AND age_min_years IS NULL AND age_max_years IS NULL
      ) r ON r.test_id = t.id
      WHERE t.deleted_at IS NULL
      ORDER BY t.name
      LIMIT ? OFFSET ?
    ''',
      [limit, offset],
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<TestModel>> searchTests(String query) async {
    final d = await db;
    final q = '%${query.trim()}%';
    final rows = d.select(
      '''
      SELECT t.*, c.name AS category_name,
             r.value_min, r.value_max
      FROM tests_master t
      LEFT JOIN test_categories c ON c.id = t.category_id
      LEFT JOIN (
        SELECT test_id, value_min, value_max
        FROM test_reference_ranges
        WHERE gender IS NULL AND age_min_years IS NULL AND age_max_years IS NULL
      ) r ON r.test_id = t.id
      WHERE t.deleted_at IS NULL
        AND (
          t.code LIKE ? OR t.name LIKE ? OR ifnull(c.name, '') LIKE ?
        )
      ORDER BY t.name
      LIMIT 50
    ''',
      [q, q, q],
    );
    return rows.map(_fromRow).toList();
  }

  Future<TestModel?> getTestById(String id) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT t.*, c.name AS category_name,
             r.value_min, r.value_max
      FROM tests_master t
      LEFT JOIN test_categories c ON c.id = t.category_id
      LEFT JOIN (
        SELECT test_id, value_min, value_max
        FROM test_reference_ranges
        WHERE gender IS NULL AND age_min_years IS NULL AND age_max_years IS NULL
      ) r ON r.test_id = t.id
      WHERE t.id = ?
      LIMIT 1
    ''',
      [id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<void> createTest(TestModel t) async {
    final d = await db;
    final id = newId();
    final ts = nowSec();
    final catId = await _ensureCategory(t.category);
    final insert = d.prepare('''
      INSERT INTO tests_master(id, code, category_id, name, sample_type, unit, method, price_cents, is_panel, created_at, updated_at)
      VALUES (?,?,?,?,?,?,?,?,0,?,?)
    ''');
    try {
      insert.execute([
        id,
        t.testCode.trim(),
        catId,
        t.testName.trim(),
        t.sampleType.trim(),
        t.unit?.trim(),
        null,
        t.priceCents,
        ts,
        ts,
      ]);
    } finally {
      insert.dispose();
    }
    if (t.normalRangeMin != null || t.normalRangeMax != null) {
      final rsId = newId();
      final stmt = d.prepare('''
        INSERT INTO test_reference_ranges(id, test_id, gender, age_min_years, age_max_years, value_min, value_max, text_range, unit, created_at, updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?)
      ''');
      try {
        stmt.execute([
          rsId,
          id,
          null,
          null,
          null,
          t.normalRangeMin,
          t.normalRangeMax,
          null,
          t.unit,
          ts,
          ts,
        ]);
      } finally {
        stmt.dispose();
      }
    }
  }

  Future<void> updateTest(TestModel t) async {
    if (t.id == null) return;
    final d = await db;
    final ts = nowSec();
    final catId = await _ensureCategory(t.category);
    final upd = d.prepare('''
      UPDATE tests_master
      SET code = ?, category_id = ?, name = ?, sample_type = ?, unit = ?, price_cents = ?, updated_at = ?
      WHERE id = ? AND deleted_at IS NULL
    ''');
    try {
      upd.execute([
        t.testCode.trim(),
        catId,
        t.testName.trim(),
        t.sampleType.trim(),
        t.unit?.trim(),
        t.priceCents,
        ts,
        t.id,
      ]);
    } finally {
      upd.dispose();
    }

    final existing = d.select(
      'SELECT id FROM test_reference_ranges WHERE test_id = ? AND gender IS NULL AND age_min_years IS NULL AND age_max_years IS NULL LIMIT 1',
      [t.id],
    );
    if (t.normalRangeMin != null || t.normalRangeMax != null) {
      if (existing.isEmpty) {
        final rsId = newId();
        final ins = d.prepare('''
          INSERT INTO test_reference_ranges(id, test_id, gender, age_min_years, age_max_years, value_min, value_max, text_range, unit, created_at, updated_at)
          VALUES (?,?,?,?,?,?,?,?,?,?,?)
        ''');
        try {
          ins.execute([
            rsId,
            t.id,
            null,
            null,
            null,
            t.normalRangeMin,
            t.normalRangeMax,
            null,
            t.unit,
            ts,
            ts,
          ]);
        } finally {
          ins.dispose();
        }
      } else {
        final rid = existing.first['id'] as String;
        final up = d.prepare('''
          UPDATE test_reference_ranges
          SET value_min = ?, value_max = ?, unit = ?, updated_at = ?
          WHERE id = ?
        ''');
        try {
          up.execute([t.normalRangeMin, t.normalRangeMax, t.unit, ts, rid]);
        } finally {
          up.dispose();
        }
      }
    }
  }

  Future<void> softDeleteTest(String id) async {
    await softDelete('tests_master', id);
  }
}
