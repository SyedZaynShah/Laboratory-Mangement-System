import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';

class ReportsRepository extends BaseRepository {
  ReportsRepository(Ref ref) : super(ref);

  Future<List<Map<String, Object?>>> fetchPatientResultReport({
    String? patientId,
    String? orderId,
    int? fromSec,
    int? toSec,
    String? orderStatus,
  }) async {
    final d = await db;
    final where = <String>['o.deleted_at IS NULL', 'p.deleted_at IS NULL'];
    final args = <Object?>[];
    if (patientId != null && patientId.isNotEmpty) {
      where.add('p.id = ?');
      args.add(patientId);
    }
    if (orderId != null && orderId.isNotEmpty) {
      where.add('o.id = ?');
      args.add(orderId);
    }
    if (fromSec != null) {
      where.add('o.ordered_at >= ?');
      args.add(fromSec);
    }
    if (toSec != null) {
      where.add('o.ordered_at <= ?');
      args.add(toSec);
    }
    if (orderStatus != null && orderStatus.isNotEmpty) {
      where.add('o.status = ?');
      args.add(orderStatus);
    }
    final sql = '''
      SELECT
        p.id AS patient_id,
        p.full_name AS patient_name,
        p.cnic AS patient_cnic,
        o.id AS order_id,
        o.order_number,
        o.ordered_at,
        o.status AS order_status,
        t.name AS test_name,
        t.unit AS test_unit,
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
      JOIN test_orders o ON o.id = i.order_id
      JOIN patients p ON p.id = o.patient_id
      JOIN tests_master t ON t.id = i.test_id
      LEFT JOIN test_results r ON r.test_order_item_id = i.id
      WHERE ${where.join(' AND ')}
      ORDER BY p.full_name, o.ordered_at DESC, t.name
    ''';
    final rows = d.select(sql, args);
    return rows.map((e) => Map<String, Object?>.from(e)).toList(growable: false);
  }

  Future<List<Map<String, Object?>>> fetchInvoiceReport({
    String? invoiceId,
    int? fromSec,
    int? toSec,
    String? status,
  }) async {
    final d = await db;
    final where = <String>['i.deleted_at IS NULL'];
    final args = <Object?>[];
    if (invoiceId != null && invoiceId.isNotEmpty) {
      where.add('i.id = ?');
      args.add(invoiceId);
    }
    if (fromSec != null) {
      where.add('i.issued_at >= ?');
      args.add(fromSec);
    }
    if (toSec != null) {
      where.add('i.issued_at <= ?');
      args.add(toSec);
    }
    if (status != null && status.isNotEmpty) {
      where.add('i.status = ?');
      args.add(status);
    }
    final sql = '''
      SELECT
        i.id AS invoice_id,
        i.invoice_no,
        i.issued_at,
        i.status,
        i.subtotal_cents,
        i.discount_cents AS header_discount_cents,
        i.tax_cents AS header_tax_cents,
        i.total_cents,
        i.balance_cents,
        p.id AS patient_id,
        p.full_name AS patient_name,
        it.description,
        it.qty,
        it.unit_price_cents,
        it.discount_cents AS item_discount_cents,
        it.line_total_cents,
        (
          SELECT COALESCE(SUM(py.amount_cents),0)
          FROM payments py
          WHERE py.invoice_id = i.id AND py.deleted_at IS NULL
        ) AS paid_cents
      FROM invoices i
      JOIN patients p ON p.id = i.patient_id
      LEFT JOIN invoice_items it ON it.invoice_id = i.id AND it.deleted_at IS NULL
      WHERE ${where.join(' AND ')}
      ORDER BY i.issued_at DESC, i.invoice_no, it.created_at
    ''';
    final rows = d.select(sql, args);
    return rows.map((e) => Map<String, Object?>.from(e)).toList(growable: false);
  }

  Future<Map<String, Object?>> fetchDailyLabSummary({
    required int fromSec,
    required int toSec,
  }) async {
    final d = await db;
    final orders = d.select(
      'SELECT COUNT(1) AS c FROM test_orders o WHERE o.deleted_at IS NULL AND o.ordered_at BETWEEN ? AND ?',
      [fromSec, toSec],
    );
    final samples = d.select(
      'SELECT COUNT(1) AS c FROM samples s WHERE s.deleted_at IS NULL AND s.status = ? AND COALESCE(s.collected_at, s.created_at) BETWEEN ? AND ?',
      ['processed', fromSec, toSec],
    );
    final results = d.select(
      'SELECT COUNT(1) AS c FROM test_results r WHERE r.deleted_at IS NULL AND r.validated_at IS NOT NULL AND r.validated_at BETWEEN ? AND ?',
      [fromSec, toSec],
    );
    final pays = d.select(
      'SELECT COALESCE(SUM(p.amount_cents),0) AS s FROM payments p WHERE p.deleted_at IS NULL AND p.received_at BETWEEN ? AND ?',
      [fromSec, toSec],
    );
    return {
      'total_orders': (orders.first['c'] as int?) ?? 0,
      'processed_samples': (samples.first['c'] as int?) ?? 0,
      'validated_results': (results.first['c'] as int?) ?? 0,
      'payments_collected_cents': (pays.first['s'] as int?) ?? 0,
    };
  }
}
