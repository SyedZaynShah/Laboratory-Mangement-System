import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';
import '../../../core/auth/auth_controller.dart';
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
    bool autoInvoice = false,
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

      // Auto-create invoice if requested
      String? invoiceId;
      if (autoInvoice) {
        invoiceId = await _createInvoiceForOrder(d, orderId, patientId, ts);
      }

      d.execute('COMMIT');
      return orderId;
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<String> _createInvoiceForOrder(
    dynamic d,
    String orderId,
    String patientId,
    int ts,
  ) async {
    // Generate invoice number
    final year = DateTime.now().year;
    final like = 'INV-$year-%';
    final rows = d.select(
      'SELECT invoice_no FROM invoices WHERE invoice_no LIKE ? ORDER BY invoice_no DESC LIMIT 1',
      [like],
    );
    int next = 1;
    if (rows.isNotEmpty) {
      final last = rows.first['invoice_no'] as String;
      final parts = last.split('-');
      if (parts.length == 3) {
        final seq = int.tryParse(parts[2]) ?? 0;
        next = seq + 1;
      }
    }
    final invoiceNo = 'INV-$year-${next.toString().padLeft(5, '0')}';

    // Snapshot order items
    final items = d.select(
      '''
      SELECT i.id AS item_id, i.test_id, i.price_cents, t.name AS test_name
      FROM test_order_items i
      JOIN tests_master t ON t.id = i.test_id
      WHERE i.order_id = ?
      ORDER BY t.name
    ''',
      [orderId],
    );
    if (items.isEmpty) {
      throw StateError('Order has no items');
    }

    final invoiceId = newId();
    final uid = ref.read(currentUserIdProvider);

    // Insert invoice
    final insInv = d.prepare('''
      INSERT INTO invoices(
        id, invoice_no, patient_id, issued_at, status,
        subtotal_cents, discount_cents, tax_cents, total_cents,
        paid_cents, balance_cents, created_by, created_at, updated_at
      ) VALUES (?,?,?,?, 'unpaid', 0,0,0,0, 0,0, ?, ?, ?)
    ''');
    try {
      insInv.execute([invoiceId, invoiceNo, patientId, ts, uid, ts, ts]);
    } finally {
      insInv.dispose();
    }

    // Insert invoice items
    final insItem = d.prepare('''
      INSERT INTO invoice_items(
        id, invoice_id, test_order_item_id, test_id, description,
        qty, unit_price_cents, discount_cents, line_total_cents, created_at, updated_at
      ) VALUES (?,?,?,?,?,?,?,0,?,?,?)
    ''');
    try {
      for (final r in items) {
        final iid = newId();
        final qty = 1;
        final unit = (r['price_cents'] as int?) ?? 0;
        final lineTotal = qty * unit;
        insItem.execute([
          iid,
          invoiceId,
          r['item_id'] as String,
          r['test_id'] as String,
          r['test_name'] as String?,
          qty,
          unit,
          lineTotal,
          ts,
          ts,
        ]);
      }
    } finally {
      insItem.dispose();
    }

    // Recompute totals
    final totals = d
        .select(
          '''
      SELECT
        COALESCE(SUM(CASE WHEN ii.deleted_at IS NULL THEN ii.line_total_cents ELSE 0 END),0) AS subtotal,
        (SELECT COALESCE(SUM(p.amount_cents),0) FROM payments p WHERE p.invoice_id = i.id AND p.deleted_at IS NULL) AS paid,
        i.discount_cents AS hdr_discount,
        i.tax_cents AS hdr_tax
      FROM invoices i
      LEFT JOIN invoice_items ii ON ii.invoice_id = i.id
      WHERE i.id = ?
      GROUP BY i.id
    ''',
          [invoiceId],
        )
        .first;

    final subtotal = (totals['subtotal'] as int?) ?? 0;
    var hdrDiscount = (totals['hdr_discount'] as int?) ?? 0;
    var hdrTax = (totals['hdr_tax'] as int?) ?? 0;
    if (hdrDiscount < 0) hdrDiscount = 0;
    if (hdrDiscount > subtotal) hdrDiscount = subtotal;
    if (hdrTax < 0) hdrTax = 0;
    final net = subtotal - hdrDiscount;
    final total = net + hdrTax;
    final paid = (totals['paid'] as int?) ?? 0;
    var balance = total - paid;
    if (balance < 0) balance = 0;

    String status = 'unpaid';
    if (total == 0) {
      status = 'draft';
    } else if (paid <= 0) {
      status = 'unpaid';
    } else if (balance == 0) {
      status = 'paid';
    } else {
      status = 'partially_paid';
    }

    final upd = d.prepare('''
      UPDATE invoices SET
        subtotal_cents = ?, discount_cents = ?, tax_cents = ?,
        total_cents = ?, paid_cents = ?, balance_cents = ?, status = ?, updated_at = ?
      WHERE id = ?
    ''');
    try {
      upd.execute([
        subtotal,
        hdrDiscount,
        hdrTax,
        total,
        paid,
        balance,
        status,
        ts,
        invoiceId,
      ]);
    } finally {
      upd.dispose();
    }

    return invoiceId;
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
