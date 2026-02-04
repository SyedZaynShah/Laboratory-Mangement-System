import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';

class ResultsRepository extends BaseRepository {
  ResultsRepository(Ref ref) : super(ref);

  Future<Map<String, Object?>?> _defaultRefsForItem(
    String testOrderItemId,
  ) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT r.value_min AS ref_low,
             r.value_max AS ref_high,
             r.text_range AS ref_text
      FROM test_order_items i
      JOIN tests_master t ON t.id = i.test_id
      LEFT JOIN test_reference_ranges r
             ON r.test_id = t.id
            AND r.gender IS NULL AND r.age_min_years IS NULL AND r.age_max_years IS NULL
      WHERE i.id = ?
      LIMIT 1
    ''',
      [testOrderItemId],
    );
    if (rows.isEmpty) return null;
    return Map<String, Object?>.from(rows.first);
  }

  bool _computeAbnormal(num? value, num? low, num? high) {
    if (value == null) return false;
    if (low != null && value < low) return true;
    if (high != null && value > high) return true;
    return false;
  }

  Future<void> _recomputeOrderStatusForItem(
    dynamic d,
    String testOrderItemId,
    int ts,
  ) async {
    final orderRow = d.select(
      'SELECT order_id FROM test_order_items WHERE id = ? LIMIT 1',
      [testOrderItemId],
    );
    if (orderRow.isEmpty) return;
    final orderId = orderRow.first['order_id'] as String;
    final statusCounts = d
        .select(
          '''
      SELECT
        SUM(CASE WHEN s.status = 'processed' THEN 1 ELSE 0 END) AS processed,
        SUM(CASE WHEN s.status IN ('received','processed') THEN 1 ELSE 0 END) AS inproc,
        SUM(CASE WHEN s.status IN ('collected','received','processed') THEN 1 ELSE 0 END) AS collected,
        COUNT(1) AS total
      FROM test_order_items i
      JOIN samples s ON s.test_order_item_id = i.id
      WHERE i.order_id = ? AND s.deleted_at IS NULL
    ''',
          [orderId],
        )
        .first;
    final processed = (statusCounts['processed'] as int?) ?? 0;
    final inproc = (statusCounts['inproc'] as int?) ?? 0;
    final collected = (statusCounts['collected'] as int?) ?? 0;
    final total = (statusCounts['total'] as int?) ?? 0;
    String newStatus = 'ordered';
    if (total > 0 && processed == total) {
      newStatus = 'completed';
    } else if (inproc > 0) {
      newStatus = 'in_process';
    } else if (total > 0 && collected == total) {
      newStatus = 'sample_collected';
    }
    final updOrder = d.prepare(
      'UPDATE test_orders SET status = ?, updated_at = ? WHERE id = ?',
    );
    try {
      updOrder.execute([newStatus, ts, orderId]);
    } finally {
      updOrder.dispose();
    }
  }

  Future<void> createResult({
    required String testOrderItemId,
    double? valueNum,
    String? valueText,
    String? remarks,
  }) async {
    final d = await db;
    final ts = nowSec();
    d.execute('BEGIN');
    try {
      // Find or derive refs
      final defaults = await _defaultRefsForItem(testOrderItemId) ?? {};
      final refLow = defaults['ref_low'] as num?;
      final refHigh = defaults['ref_high'] as num?;
      final refText = defaults['ref_text'] as String?;

      // If existing result, update instead
      final existing = d.select(
        'SELECT id, reference_low, reference_high FROM test_results WHERE test_order_item_id = ? AND deleted_at IS NULL LIMIT 1',
        [testOrderItemId],
      );
      if (existing.isNotEmpty) {
        final rid = existing.first['id'] as String;
        final low = (existing.first['reference_low'] as num?) ?? refLow;
        final high = (existing.first['reference_high'] as num?) ?? refHigh;
        final abnormal = _computeAbnormal(valueNum, low, high) ? 1 : 0;
        final upd = d.prepare('''
          UPDATE test_results
          SET value_text = ?, value_num = ?, is_abnormal = ?, remarks = ?, updated_at = ?
          WHERE id = ?
        ''');
        try {
          upd.execute([valueText, valueNum, abnormal, remarks, ts, rid]);
        } finally {
          upd.dispose();
        }
      } else {
        final rid = newId();
        final abnormal = _computeAbnormal(valueNum, refLow, refHigh) ? 1 : 0;
        final ins = d.prepare('''
          INSERT INTO test_results(
            id, test_order_item_id, value_text, value_num, reference_low, reference_high, reference_text,
            is_abnormal, validated_by, validated_at, remarks, created_at, updated_at
          ) VALUES (?,?,?,?,?,?,?,?,NULL,NULL,?,?,?)
        ''');
        try {
          ins.execute([
            rid,
            testOrderItemId,
            valueText,
            valueNum,
            refLow,
            refHigh,
            refText,
            abnormal,
            ts,
            ts,
          ]);
        } finally {
          ins.dispose();
        }
      }

      // Mark sample processed if exists
      final updSample = d.prepare(
        'UPDATE samples SET status = ?, updated_at = ? WHERE test_order_item_id = ? AND deleted_at IS NULL',
      );
      try {
        updSample.execute(['processed', ts, testOrderItemId]);
      } finally {
        updSample.dispose();
      }

      await _recomputeOrderStatusForItem(d, testOrderItemId, ts);
      d.execute('COMMIT');
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> updateResult({
    required String testResultId,
    double? valueNum,
    String? valueText,
    String? remarks,
  }) async {
    final d = await db;
    final ts = nowSec();
    d.execute('BEGIN');
    try {
      final row = d.select(
        'SELECT test_order_item_id, reference_low, reference_high FROM test_results WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [testResultId],
      );
      if (row.isEmpty) {
        d.execute('COMMIT');
        return;
      }
      final itemId = row.first['test_order_item_id'] as String;
      final low = row.first['reference_low'] as num?;
      final high = row.first['reference_high'] as num?;
      final abnormal = _computeAbnormal(valueNum, low, high) ? 1 : 0;
      final upd = d.prepare('''
        UPDATE test_results
        SET value_text = ?, value_num = ?, is_abnormal = ?, remarks = ?, updated_at = ?
        WHERE id = ?
      ''');
      try {
        upd.execute([valueText, valueNum, abnormal, remarks, ts, testResultId]);
      } finally {
        upd.dispose();
      }

      // Keep sample processed
      final updSample = d.prepare(
        'UPDATE samples SET status = ?, updated_at = ? WHERE test_order_item_id = ? AND deleted_at IS NULL',
      );
      try {
        updSample.execute(['processed', ts, itemId]);
      } finally {
        updSample.dispose();
      }

      await _recomputeOrderStatusForItem(d, itemId, ts);
      d.execute('COMMIT');
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> validateResult({
    required String testResultId,
    required String validatorUserId,
  }) async {
    final d = await db;
    final ts = nowSec();
    d.execute('BEGIN');
    try {
      final row = d.select(
        'SELECT test_order_item_id FROM test_results WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [testResultId],
      );
      if (row.isEmpty) {
        d.execute('COMMIT');
        return;
      }
      final itemId = row.first['test_order_item_id'] as String;
      final upd = d.prepare(
        'UPDATE test_results SET validated_by = ?, validated_at = ?, updated_at = ? WHERE id = ?',
      );
      try {
        upd.execute([validatorUserId, ts, ts, testResultId]);
      } finally {
        upd.dispose();
      }

      // Keep sample processed
      final updSample = d.prepare(
        'UPDATE samples SET status = ?, updated_at = ? WHERE test_order_item_id = ? AND deleted_at IS NULL',
      );
      try {
        updSample.execute(['processed', ts, itemId]);
      } finally {
        updSample.dispose();
      }

      await _recomputeOrderStatusForItem(d, itemId, ts);
      d.execute('COMMIT');
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> listResultsForOrder(String orderId) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT i.id AS item_id,
             t.name AS test_name,
             t.unit AS unit,
             s.sample_code,
             s.status AS sample_status,
             r.id AS result_id,
             r.value_text,
             r.value_num,
             r.reference_low,
             r.reference_high,
             r.reference_text,
             r.is_abnormal,
             r.validated_by,
             r.validated_at,
             r.remarks
      FROM test_order_items i
      JOIN tests_master t ON t.id = i.test_id
      LEFT JOIN samples s ON s.test_order_item_id = i.id AND s.deleted_at IS NULL
      LEFT JOIN test_results r ON r.test_order_item_id = i.id AND r.deleted_at IS NULL
      WHERE i.order_id = ?
      ORDER BY t.name
    ''',
      [orderId],
    );
    return rows
        .map((e) => Map<String, Object?>.from(e))
        .toList(growable: false);
  }

  Future<Map<String, Object?>?> getResultById(String id) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT r.*
      FROM test_results r
      WHERE r.id = ? AND r.deleted_at IS NULL
      LIMIT 1
    ''',
      [id],
    );
    if (rows.isEmpty) return null;
    return Map<String, Object?>.from(rows.first);
  }
}
