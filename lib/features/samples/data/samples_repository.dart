import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';

class SamplesRepository extends BaseRepository {
  SamplesRepository(Ref ref) : super(ref);

  Future<String> _generateSampleCode() async {
    final d = await db;
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final prefix = 'S-$y$m$day-';
    final rows = d.select(
      'SELECT sample_code FROM samples WHERE sample_code LIKE ? ORDER BY sample_code DESC LIMIT 1',
      ['$prefix%'],
    );
    int next = 1;
    if (rows.isNotEmpty) {
      final last = (rows.first['sample_code'] as String);
      final parts = last.split('-');
      if (parts.length == 2) {
        final seq = int.tryParse(parts[1]) ?? 0;
        next = seq + 1;
      }
    }
    return '$prefix${next.toString().padLeft(5, '0')}';
  }

  Future<String> createSample(String testOrderItemId) async {
    final d = await db;
    final ts = nowSec();

    // If already exists and not deleted, return existing ID
    final existing = d.select(
      'SELECT id FROM samples WHERE test_order_item_id = ? AND deleted_at IS NULL LIMIT 1',
      [testOrderItemId],
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;

    final id = newId();
    final code = await _generateSampleCode();
    final stmt = d.prepare('''
      INSERT INTO samples(id, test_order_item_id, sample_code, status, collected_at, collected_by, container, notes, created_at, updated_at)
      VALUES (?,?,?,?,NULL,NULL,NULL,NULL,?,?)
    ''');
    try {
      stmt.execute([id, testOrderItemId, code, 'awaiting', ts, ts]);
      return id;
    } finally {
      stmt.dispose();
    }
  }

  Future<void> ensureSamplesForOrder(String orderId) async {
    final d = await db;
    final items = d.select(
      'SELECT id FROM test_order_items WHERE order_id = ? ORDER BY id',
      [orderId],
    );
    for (final row in items) {
      final itemId = row['id'] as String;
      await createSample(itemId);
    }
  }

  Future<Map<String, Object?>?> getSampleById(String sampleId) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT s.*, i.test_id, t.code AS test_code, t.name AS test_name
      FROM samples s
      JOIN test_order_items i ON i.id = s.test_order_item_id
      JOIN tests_master t ON t.id = i.test_id
      WHERE s.id = ? AND s.deleted_at IS NULL
      LIMIT 1
    ''',
      [sampleId],
    );
    if (rows.isEmpty) return null;
    return Map<String, Object?>.from(rows.first);
  }

  Future<List<Map<String, Object?>>> listSamples(String orderId) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT s.id AS sample_id,
             s.sample_code,
             s.status,
             s.collected_at,
             s.container,
             s.notes,
             s.created_at,
             s.updated_at,
             i.id AS item_id,
             t.id AS test_id,
             t.code AS test_code,
             t.name AS test_name
      FROM test_order_items i
      JOIN tests_master t ON t.id = i.test_id
      JOIN samples s ON s.test_order_item_id = i.id
      WHERE i.order_id = ? AND s.deleted_at IS NULL
      ORDER BY t.name
    ''',
      [orderId],
    );
    return rows
        .map((r) => Map<String, Object?>.from(r))
        .toList(growable: false);
  }

  Future<void> updateSampleStatus(String sampleId, String status) async {
    final d = await db;
    final ts = nowSec();
    d.execute('BEGIN');
    try {
      final upd = d.prepare('''
        UPDATE samples
        SET status = ?, collected_at = CASE WHEN ? = 'collected' THEN ? ELSE collected_at END,
            updated_at = ?
        WHERE id = ? AND deleted_at IS NULL
      ''');
      try {
        upd.execute([status, status, ts, ts, sampleId]);
      } finally {
        upd.dispose();
      }

      // Recompute order status
      final orderRow = d.select(
        '''
        SELECT o.id AS order_id
        FROM test_orders o
        JOIN test_order_items i ON i.order_id = o.id
        JOIN samples s ON s.test_order_item_id = i.id
        WHERE s.id = ?
        LIMIT 1
      ''',
        [sampleId],
      );
      if (orderRow.isNotEmpty) {
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

      d.execute('COMMIT');
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> softDeleteSample(String sampleId) async {
    await softDelete('samples', sampleId);
  }
}
