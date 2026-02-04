import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';
import '../../../core/auth/auth_controller.dart';

class PaymentsRepository extends BaseRepository {
  PaymentsRepository(Ref ref) : super(ref);

  void _recomputeInvoiceTotals(dynamic d, String invoiceId, int ts) {
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

  Future<String> createPayment({
    required String invoiceId,
    required int amountCents,
    required String method,
    String? reference,
    int? receivedAt,
    String? notes,
  }) async {
    if (amountCents <= 0) {
      throw ArgumentError('Payment amount must be > 0');
    }
    final d = await db;
    final ts = nowSec();
    final uid = ref.read(currentUserIdProvider);
    final pid = newId();
    d.execute('BEGIN');
    try {
      final ins = d.prepare('''
        INSERT INTO payments(id, invoice_id, amount_cents, method, reference, received_at, received_by, notes, created_at, updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?)
      ''');
      try {
        ins.execute([
          pid,
          invoiceId,
          amountCents,
          method,
          reference,
          receivedAt ?? ts,
          uid,
          notes,
          ts,
          ts,
        ]);
      } finally {
        ins.dispose();
      }
      _recomputeInvoiceTotals(d, invoiceId, ts);
      d.execute('COMMIT');
      return pid;
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> listPayments(String invoiceId) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT * FROM payments
      WHERE invoice_id = ? AND deleted_at IS NULL
      ORDER BY received_at DESC
    ''',
      [invoiceId],
    );
    return rows
        .map((e) => Map<String, Object?>.from(e))
        .toList(growable: false);
  }

  Future<Map<String, Object?>?> getPaymentById(String id) async {
    final d = await db;
    final rows = d.select(
      'SELECT * FROM payments WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    return Map<String, Object?>.from(rows.first);
  }
}
