import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';
import '../../../core/auth/auth_controller.dart';

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
      final idx = last.lastIndexOf('-');
      if (idx != -1 && idx + 1 < last.length) {
        final tail = last.substring(idx + 1);
        final seq = int.tryParse(tail) ?? 0;
        next = seq + 1;
      }
    }
    return '$prefix${next.toString().padLeft(5, '0')}';
  }

  Future<String> createSample(String testOrderItemId) async {
    final d = await db;
    final ts = nowSec();

    // If exists (even if soft-deleted), revive or return
    final existingAny = d.select(
      'SELECT id, deleted_at FROM samples WHERE test_order_item_id = ? LIMIT 1',
      [testOrderItemId],
    );
    if (existingAny.isNotEmpty) {
      final id = existingAny.first['id'] as String;
      final deletedAt = existingAny.first['deleted_at'];
      if (deletedAt != null) {
        final upd = d.prepare('''
          UPDATE samples
          SET status = 'awaiting', collected_at = NULL, collected_by = NULL,
              container = NULL, notes = NULL, deleted_at = NULL, updated_at = ?
          WHERE id = ?
        ''');
        try {
          upd.execute([ts, id]);
        } finally {
          upd.dispose();
        }
      }
      return id;
    }

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
    final uid = ref.read(currentUserIdProvider);
    d.execute('BEGIN');
    try {
      final upd = d.prepare('''
        UPDATE samples
        SET status = ?,
            collected_at = CASE WHEN ? = 'collected' THEN ? ELSE collected_at END,
            collected_by = CASE WHEN ? = 'collected' THEN ? ELSE collected_by END,
            updated_at = ?
        WHERE id = ? AND deleted_at IS NULL
      ''');
      try {
        upd.execute([status, status, ts, status, uid, ts, sampleId]);
      } finally {
        upd.dispose();
      }

      // Recompute order status by resolving parent order id
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
        _recomputeOrderStatus(d, orderId, ts);
      }

      d.execute('COMMIT');
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  void _recomputeOrderStatus(dynamic d, String orderId, int ts) {
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

  Future<void> bulkUpdateSamplesForOrder({
    required String orderId,
    required List<String> fromStatuses,
    required String toStatus,
  }) async {
    if (fromStatuses.isEmpty) return;
    final d = await db;
    final ts = nowSec();
    d.execute('BEGIN');
    try {
      final placeholders = List.filled(fromStatuses.length, '?').join(',');
      final sql =
          '''
        UPDATE samples
        SET status = ?, collected_at = CASE WHEN ? = 'collected' THEN ? ELSE collected_at END,
            updated_at = ?
        WHERE deleted_at IS NULL
          AND test_order_item_id IN (
            SELECT i.id FROM test_order_items i WHERE i.order_id = ?
          )
          AND status IN ($placeholders)
      ''';
      final params = <Object?>[
        toStatus,
        toStatus,
        ts,
        ts,
        orderId,
        ...fromStatuses,
      ];
      d.execute(sql, params);

      _recomputeOrderStatus(d, orderId, ts);
      d.execute('COMMIT');
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> nudgeOrderForward(String orderId) async {
    final d = await db;
    final counts = d
        .select(
          '''
      SELECT
        SUM(CASE WHEN s.status = 'awaiting' THEN 1 ELSE 0 END) AS awaiting,
        SUM(CASE WHEN s.status = 'collected' THEN 1 ELSE 0 END) AS collected,
        SUM(CASE WHEN s.status = 'received' THEN 1 ELSE 0 END) AS received
      FROM test_order_items i
      JOIN samples s ON s.test_order_item_id = i.id
      WHERE i.order_id = ? AND s.deleted_at IS NULL
    ''',
          [orderId],
        )
        .first;
    final awaiting = (counts['awaiting'] as int?) ?? 0;
    final collected = (counts['collected'] as int?) ?? 0;
    final received = (counts['received'] as int?) ?? 0;
    if (awaiting > 0) {
      await bulkUpdateSamplesForOrder(
        orderId: orderId,
        fromStatuses: const ['awaiting'],
        toStatus: 'collected',
      );
    } else if (collected > 0) {
      await bulkUpdateSamplesForOrder(
        orderId: orderId,
        fromStatuses: const ['collected'],
        toStatus: 'received',
      );
    } else if (received > 0) {
      await bulkUpdateSamplesForOrder(
        orderId: orderId,
        fromStatuses: const ['received'],
        toStatus: 'processed',
      );
    }
  }

  Future<void> nudgeOrderBackward(String orderId) async {
    final d = await db;
    final counts = d
        .select(
          '''
      SELECT
        SUM(CASE WHEN s.status = 'processed' THEN 1 ELSE 0 END) AS processed,
        SUM(CASE WHEN s.status = 'received' THEN 1 ELSE 0 END) AS received,
        SUM(CASE WHEN s.status = 'collected' THEN 1 ELSE 0 END) AS collected
      FROM test_order_items i
      JOIN samples s ON s.test_order_item_id = i.id
      WHERE i.order_id = ? AND s.deleted_at IS NULL
    ''',
          [orderId],
        )
        .first;
    final processed = (counts['processed'] as int?) ?? 0;
    final received = (counts['received'] as int?) ?? 0;
    final collected = (counts['collected'] as int?) ?? 0;
    if (processed > 0) {
      await bulkUpdateSamplesForOrder(
        orderId: orderId,
        fromStatuses: const ['processed'],
        toStatus: 'received',
      );
    } else if (received > 0) {
      await bulkUpdateSamplesForOrder(
        orderId: orderId,
        fromStatuses: const ['received'],
        toStatus: 'collected',
      );
    } else if (collected > 0) {
      await bulkUpdateSamplesForOrder(
        orderId: orderId,
        fromStatuses: const ['collected'],
        toStatus: 'awaiting',
      );
    }
  }

  Future<List<Map<String, Object?>>> listSamplesByStatus(String status) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT s.id AS sample_id,
             s.sample_code,
             s.status,
             s.collected_at,
             i.id AS item_id,
             t.id AS test_id,
             t.name AS test_name,
             o.id AS order_id,
             o.order_number,
             p.full_name AS patient_name
      FROM samples s
      JOIN test_order_items i ON i.id = s.test_order_item_id
      JOIN tests_master t ON t.id = i.test_id
      JOIN test_orders o ON o.id = i.order_id
      JOIN patients p ON p.id = o.patient_id
      WHERE s.deleted_at IS NULL AND s.status = ?
      ORDER BY o.ordered_at DESC, t.name
      LIMIT 200
      ''',
      [status],
    );
    return rows
        .map((r) => Map<String, Object?>.from(r))
        .toList(growable: false);
  }

  Future<void> softDeleteSample(String sampleId) async {
    await softDelete('samples', sampleId);
  }
}
