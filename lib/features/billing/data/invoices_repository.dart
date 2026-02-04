import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';
import '../../../core/auth/auth_controller.dart';

class InvoicesRepository extends BaseRepository {
  InvoicesRepository(Ref ref) : super(ref);

  Future<String> _generateInvoiceNo() async {
    final d = await db;
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
    return 'INV-$year-${next.toString().padLeft(5, '0')}';
  }

  Future<String> createInvoice(String orderId) async {
    final d = await db;
    final ts = nowSec();
    final uid = ref.read(currentUserIdProvider);

    // If invoice already exists for this order (by items join), return it
    final existing = d.select(
      '''
      SELECT ii.invoice_id
      FROM invoice_items ii
      JOIN test_order_items i ON i.id = ii.test_order_item_id
      WHERE i.order_id = ?
      LIMIT 1
    ''',
      [orderId],
    );
    if (existing.isNotEmpty) {
      return existing.first['invoice_id'] as String;
    }

    // Load order + patient
    final ordRows = d.select(
      'SELECT patient_id FROM test_orders WHERE id = ? LIMIT 1',
      [orderId],
    );
    if (ordRows.isEmpty) {
      throw StateError('Order not found');
    }
    final patientId = ordRows.first['patient_id'] as String;

    // Snapshot items
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
    final invoiceNo = await _generateInvoiceNo();

    d.execute('BEGIN');
    try {
      // Insert invoice
      final insInv = d.prepare('''
        INSERT INTO invoices(
          id, invoice_no, patient_id, issued_at, status,
          subtotal_cents, discount_cents, tax_cents, total_cents,
          paid_cents, balance_cents, created_by, created_at, updated_at
        ) VALUES (?,?,?,?, 'open', 0,0,0,0, 0,0, ?, ?, ?)
      ''');
      try {
        insInv.execute([invoiceId, invoiceNo, patientId, ts, uid, ts, ts]);
      } finally {
        insInv.dispose();
      }

      // Insert items
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

      _recomputeTotals(d, invoiceId, ts);
      d.execute('COMMIT');
      return invoiceId;
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  void _recomputeTotals(dynamic d, String invoiceId, int ts) {
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
    final hdrDiscount = (totals['hdr_discount'] as int?) ?? 0;
    final hdrTax = (totals['hdr_tax'] as int?) ?? 0;
    final total = subtotal - hdrDiscount + hdrTax;
    final paid = (totals['paid'] as int?) ?? 0;
    var balance = total - paid;
    if (balance < 0) balance = 0;
    String status = 'open';
    if (total == 0) {
      status = 'draft';
    } else if (balance == 0) {
      status = 'paid';
    }
    final upd = d.prepare('''
      UPDATE invoices
      SET subtotal_cents = ?, total_cents = ?, paid_cents = ?, balance_cents = ?, status = ?, updated_at = ?
      WHERE id = ?
    ''');
    try {
      upd.execute([subtotal, total, paid, balance, status, ts, invoiceId]);
    } finally {
      upd.dispose();
    }
  }

  Future<void> updateInvoice({
    required String invoiceId,
    int? discountCents,
    int? taxCents,
  }) async {
    final d = await db;
    final ts = nowSec();
    d.execute('BEGIN');
    try {
      if (discountCents != null || taxCents != null) {
        final upd = d.prepare('''
          UPDATE invoices
          SET discount_cents = COALESCE(?, discount_cents),
              tax_cents = COALESCE(?, tax_cents),
              updated_at = ?
          WHERE id = ? AND deleted_at IS NULL
        ''');
        try {
          upd.execute([discountCents, taxCents, ts, invoiceId]);
        } finally {
          upd.dispose();
        }
      }
      _recomputeTotals(d, invoiceId, ts);
      d.execute('COMMIT');
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> addInvoiceItem({
    required String invoiceId,
    required String testOrderItemId,
  }) async {
    final d = await db;
    final ts = nowSec();
    final r = d.select(
      '''
      SELECT i.id AS item_id, i.test_id, i.price_cents, t.name AS test_name
      FROM test_order_items i
      JOIN tests_master t ON t.id = i.test_id
      WHERE i.id = ?
      LIMIT 1
    ''',
      [testOrderItemId],
    );
    if (r.isEmpty) return;
    final unit = (r.first['price_cents'] as int?) ?? 0;
    final lineTotal = unit;
    d.execute('BEGIN');
    try {
      final ins = d.prepare('''
        INSERT INTO invoice_items(
          id, invoice_id, test_order_item_id, test_id, description, qty, unit_price_cents, discount_cents, line_total_cents, created_at, updated_at
        ) VALUES (?,?,?,?,?,1,?,0,?,?,?)
      ''');
      try {
        ins.execute([
          newId(),
          invoiceId,
          testOrderItemId,
          r.first['test_id'] as String,
          r.first['test_name'] as String?,
          unit,
          lineTotal,
          ts,
          ts,
        ]);
      } finally {
        ins.dispose();
      }
      _recomputeTotals(d, invoiceId, ts);
      d.execute('COMMIT');
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> updateInvoiceItem({
    required String invoiceItemId,
    int? qty,
    int? unitPriceCents,
    int? discountCents,
  }) async {
    final d = await db;
    final ts = nowSec();
    d.execute('BEGIN');
    try {
      // Load current
      final row = d.select(
        'SELECT invoice_id, qty, unit_price_cents, discount_cents FROM invoice_items WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [invoiceItemId],
      );
      if (row.isEmpty) {
        d.execute('COMMIT');
        return;
      }
      final invoiceId = row.first['invoice_id'] as String;
      final curQty = (row.first['qty'] as int?) ?? 1;
      final curUnit = (row.first['unit_price_cents'] as int?) ?? 0;
      final curDisc = (row.first['discount_cents'] as int?) ?? 0;
      final newQty = qty ?? curQty;
      final newUnit = unitPriceCents ?? curUnit;
      final newDisc = discountCents ?? curDisc;
      final lineTotal = (newQty * newUnit) - newDisc;

      final upd = d.prepare('''
        UPDATE invoice_items
        SET qty = ?, unit_price_cents = ?, discount_cents = ?, line_total_cents = ?, updated_at = ?
        WHERE id = ? AND deleted_at IS NULL
      ''');
      try {
        upd.execute([newQty, newUnit, newDisc, lineTotal, ts, invoiceItemId]);
      } finally {
        upd.dispose();
      }

      _recomputeTotals(d, invoiceId, ts);
      d.execute('COMMIT');
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> removeInvoiceItem(String invoiceItemId) async {
    final d = await db;
    final ts = nowSec();
    d.execute('BEGIN');
    try {
      final row = d.select(
        'SELECT invoice_id FROM invoice_items WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [invoiceItemId],
      );
      if (row.isEmpty) {
        d.execute('COMMIT');
        return;
      }
      final invoiceId = row.first['invoice_id'] as String;
      final del = d.prepare(
        'UPDATE invoice_items SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL',
      );
      try {
        del.execute([ts, ts, invoiceItemId]);
      } finally {
        del.dispose();
      }
      _recomputeTotals(d, invoiceId, ts);
      d.execute('COMMIT');
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> listInvoices({required int page}) async {
    final d = await db;
    final limit = 20;
    final offset = page <= 1 ? 0 : (page - 1) * limit;
    final rows = d.select(
      '''
      SELECT i.*, p.full_name AS patient_name
      FROM invoices i
      JOIN patients p ON p.id = i.patient_id
      WHERE i.deleted_at IS NULL
      ORDER BY i.issued_at DESC
      LIMIT ? OFFSET ?
    ''',
      [limit, offset],
    );
    return rows
        .map((e) => Map<String, Object?>.from(e))
        .toList(growable: false);
  }

  Future<Map<String, Object?>?> getInvoiceById(String id) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT i.*, p.full_name AS patient_name
      FROM invoices i
      JOIN patients p ON p.id = i.patient_id
      WHERE i.id = ?
      LIMIT 1
    ''',
      [id],
    );
    if (rows.isEmpty) return null;
    return Map<String, Object?>.from(rows.first);
  }

  Future<List<Map<String, Object?>>> listInvoiceItems(String invoiceId) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT ii.*, t.name AS test_name
      FROM invoice_items ii
      JOIN tests_master t ON t.id = ii.test_id
      WHERE ii.invoice_id = ? AND ii.deleted_at IS NULL
      ORDER BY t.name
    ''',
      [invoiceId],
    );
    return rows
        .map((e) => Map<String, Object?>.from(e))
        .toList(growable: false);
  }
}
