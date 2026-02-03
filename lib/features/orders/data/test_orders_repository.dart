import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';
import 'test_order_models.dart';

class TestOrdersRepository extends BaseRepository {
  TestOrdersRepository(Ref ref) : super(ref);

  Future<String> _generateOrderNumber() async {
    final d = await db;
    final year = DateTime.now().year;
    final like = 'LAB-$year-%';
    final rows = d.select(
      'SELECT order_number FROM test_orders WHERE order_number LIKE ? ORDER BY order_number DESC LIMIT 1',
      [like],
    );
    int next = 1;
    if (rows.isNotEmpty) {
      final last = (rows.first['order_number'] as String);
      final parts = last.split('-');
      if (parts.length == 3) {
        final seq = int.tryParse(parts[2]) ?? 0;
        next = seq + 1;
      }
    }
    final seqStr = next.toString().padLeft(5, '0');
    return 'LAB-$year-$seqStr';
  }

  Future<int> _priceForTest(String testId) async {
    final d = await db;
    final r = d.select(
      'SELECT price_cents FROM tests_master WHERE id = ? LIMIT 1',
      [testId],
    );
    if (r.isEmpty) return 0;
    final v = r.first['price_cents'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<String> createOrder({
    required String patientId,
    required List<String> testIds,
  }) async {
    if (testIds.isEmpty) {
      throw ArgumentError('At least one test must be selected');
    }
    final d = await db;
    final ts = nowSec();
    final orderId = newId();
    final orderNo = await _generateOrderNumber();

    d.execute('BEGIN');
    try {
      final insertOrder = d.prepare(
        'INSERT INTO test_orders(id, order_number, patient_id, ordered_at, status, created_at, updated_at) VALUES (?,?,?,?,?,?,?)',
      );
      try {
        insertOrder.execute([
          orderId,
          orderNo,
          patientId,
          ts,
          'ordered',
          ts,
          ts,
        ]);
      } finally {
        insertOrder.dispose();
      }

      final insertItem = d.prepare(
        'INSERT INTO test_order_items(id, order_id, test_id, price_cents, created_at) VALUES (?,?,?,?,?)',
      );
      try {
        for (final tid in testIds) {
          final price = await _priceForTest(tid);
          insertItem.execute([newId(), orderId, tid, price, ts]);
        }
      } finally {
        insertItem.dispose();
      }

      d.execute('COMMIT');
      return orderId;
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  TestOrder _fromRow(Map<String, Object?> r) {
    return TestOrder(
      id: r['id'] as String,
      orderNumber: (r['order_number'] as String?) ?? '',
      patientId: (r['patient_id'] as String?) ?? '',
      orderedAt: (r['ordered_at'] as int?) ?? 0,
      status: (r['status'] as String?) ?? 'ordered',
      createdAt: (r['created_at'] as int?) ?? 0,
      updatedAt: (r['updated_at'] as int?) ?? 0,
      patientName: r['patient_name'] as String?,
      testsCount: (r['tests_count'] is int)
          ? r['tests_count'] as int
          : (r['tests_count'] is num)
          ? (r['tests_count'] as num).toInt()
          : null,
      totalCents: (r['total_cents'] is int)
          ? r['total_cents'] as int
          : (r['total_cents'] is num)
          ? (r['total_cents'] as num).toInt()
          : null,
      collectedCount: (r['collected_count'] is int)
          ? r['collected_count'] as int
          : (r['collected_count'] is num)
          ? (r['collected_count'] as num).toInt()
          : null,
    );
  }

  Future<List<TestOrder>> listOrders({required int page}) async {
    final d = await db;
    final limit = 20;
    final offset = page <= 1 ? 0 : (page - 1) * limit;
    final rows = d.select(
      '''
      SELECT o.*, p.full_name AS patient_name,
             (SELECT COUNT(*) FROM test_order_items i WHERE i.order_id = o.id) AS tests_count,
             (SELECT COALESCE(SUM(price_cents),0) FROM test_order_items i2 WHERE i2.order_id = o.id) AS total_cents,
             (SELECT COALESCE(SUM(CASE WHEN s.status IN ('collected','received','processed') THEN 1 ELSE 0 END),0)
                FROM test_order_items i3
                LEFT JOIN samples s ON s.test_order_item_id = i3.id AND s.deleted_at IS NULL
               WHERE i3.order_id = o.id) AS collected_count
      FROM test_orders o
      JOIN patients p ON p.id = o.patient_id
      WHERE o.deleted_at IS NULL
      ORDER BY o.ordered_at DESC
      LIMIT ? OFFSET ?
    ''',
      [limit, offset],
    );
    return rows.map(_fromRow).toList();
  }

  Future<TestOrder?> getOrderById(String id) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT o.*, p.full_name AS patient_name,
             (SELECT COUNT(*) FROM test_order_items i WHERE i.order_id = o.id) AS tests_count,
             (SELECT COALESCE(SUM(price_cents),0) FROM test_order_items i2 WHERE i2.order_id = o.id) AS total_cents,
             (SELECT COALESCE(SUM(CASE WHEN s.status IN ('collected','received','processed') THEN 1 ELSE 0 END),0)
                FROM test_order_items i3
                LEFT JOIN samples s ON s.test_order_item_id = i3.id AND s.deleted_at IS NULL
               WHERE i3.order_id = o.id) AS collected_count
      FROM test_orders o
      JOIN patients p ON p.id = o.patient_id
      WHERE o.id = ?
      LIMIT 1
    ''',
      [id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<List<TestOrder>> searchOrders(String query) async {
    final d = await db;
    final q = '%${query.trim()}%';
    final rows = d.select(
      '''
      SELECT o.*, p.full_name AS patient_name,
             (SELECT COUNT(*) FROM test_order_items i WHERE i.order_id = o.id) AS tests_count,
             (SELECT COALESCE(SUM(price_cents),0) FROM test_order_items i2 WHERE i2.order_id = o.id) AS total_cents,
             (SELECT COALESCE(SUM(CASE WHEN s.status IN ('collected','received','processed') THEN 1 ELSE 0 END),0)
                FROM test_order_items i3
                LEFT JOIN samples s ON s.test_order_item_id = i3.id AND s.deleted_at IS NULL
               WHERE i3.order_id = o.id) AS collected_count
      FROM test_orders o
      JOIN patients p ON p.id = o.patient_id
      WHERE o.deleted_at IS NULL
        AND (o.order_number LIKE ? OR p.full_name LIKE ?)
      ORDER BY o.ordered_at DESC
      LIMIT 50
    ''',
      [q, q],
    );
    return rows.map(_fromRow).toList();
  }
}
