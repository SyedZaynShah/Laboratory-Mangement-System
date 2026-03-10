import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';

enum FinanceGroupBy { overall, daily, weekly }

typedef FinanceSummary = Map<String, Object?>;

typedef FinancePeriodRow = Map<String, Object?>;

class FinanceRepository extends BaseRepository {
  FinanceRepository(Ref ref) : super(ref);

  Future<FinanceSummary> getSummary({
    required int? fromSec,
    required int? toSec,
  }) async {
    final d = await db;

    final orders = d.select(
      '''
      SELECT
        COUNT(1) AS orders_count
      FROM test_orders o
      WHERE o.deleted_at IS NULL
        AND (? IS NULL OR o.ordered_at >= ?)
        AND (? IS NULL OR o.ordered_at <= ?)
    ''',
      [fromSec, fromSec, toSec, toSec],
    );

    final invoices = d.select(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN i.deleted_at IS NULL THEN i.total_cents ELSE 0 END), 0) AS invoices_total_cents,
        COALESCE(SUM(CASE WHEN i.deleted_at IS NULL THEN i.paid_cents ELSE 0 END), 0) AS invoices_paid_cents,
        COALESCE(SUM(CASE WHEN i.deleted_at IS NULL THEN i.balance_cents ELSE 0 END), 0) AS invoices_balance_cents,
        COUNT(1) AS invoices_count
      FROM invoices i
      WHERE i.deleted_at IS NULL
        AND (? IS NULL OR i.issued_at >= ?)
        AND (? IS NULL OR i.issued_at <= ?)
    ''',
      [fromSec, fromSec, toSec, toSec],
    );

    final payments = d.select(
      '''
      SELECT
        COALESCE(SUM(p.amount_cents),0) AS payments_received_cents,
        COUNT(1) AS payments_count
      FROM payments p
      WHERE p.deleted_at IS NULL
        AND (? IS NULL OR p.received_at >= ?)
        AND (? IS NULL OR p.received_at <= ?)
    ''',
      [fromSec, fromSec, toSec, toSec],
    );

    final expenses = d.select(
      '''
      SELECT
        COALESCE(SUM(e.amount_cents),0) AS expenses_cents,
        COUNT(1) AS expenses_count
      FROM expenses e
      WHERE e.deleted_at IS NULL
        AND (? IS NULL OR e.occurred_at >= ?)
        AND (? IS NULL OR e.occurred_at <= ?)
    ''',
      [fromSec, fromSec, toSec, toSec],
    );

    return {
      'orders_count': (orders.first['orders_count'] as int?) ?? 0,
      'invoices_total_cents':
          (invoices.first['invoices_total_cents'] as int?) ?? 0,
      'invoices_paid_cents':
          (invoices.first['invoices_paid_cents'] as int?) ?? 0,
      'invoices_balance_cents':
          (invoices.first['invoices_balance_cents'] as int?) ?? 0,
      'invoices_count': (invoices.first['invoices_count'] as int?) ?? 0,
      'payments_received_cents':
          (payments.first['payments_received_cents'] as int?) ?? 0,
      'payments_count': (payments.first['payments_count'] as int?) ?? 0,
      'expenses_cents': (expenses.first['expenses_cents'] as int?) ?? 0,
      'expenses_count': (expenses.first['expenses_count'] as int?) ?? 0,
    };
  }

  String _periodExpr(FinanceGroupBy groupBy, String tsColumn) {
    switch (groupBy) {
      case FinanceGroupBy.daily:
        return "strftime('%Y-%m-%d', datetime($tsColumn, 'unixepoch'))";
      case FinanceGroupBy.weekly:
        return "strftime('%Y-W%W', datetime($tsColumn, 'unixepoch'))";
      case FinanceGroupBy.overall:
        return "'Overall'";
    }
  }

  Future<List<FinancePeriodRow>> listPeriods({
    required FinanceGroupBy groupBy,
    required int? fromSec,
    required int? toSec,
  }) async {
    final d = await db;

    final invPeriod = _periodExpr(groupBy, 'i.issued_at');
    final payPeriod = _periodExpr(groupBy, 'p.received_at');
    final expPeriod = _periodExpr(groupBy, 'e.occurred_at');
    final ordPeriod = _periodExpr(groupBy, 'o.ordered_at');

    // Build a unified set of periods, then left join aggregates for each source.
    final rows = d.select(
      '''
      WITH periods AS (
        SELECT $invPeriod AS period
        FROM invoices i
        WHERE i.deleted_at IS NULL
          AND (? IS NULL OR i.issued_at >= ?)
          AND (? IS NULL OR i.issued_at <= ?)
        GROUP BY period
        UNION
        SELECT $payPeriod AS period
        FROM payments p
        WHERE p.deleted_at IS NULL
          AND (? IS NULL OR p.received_at >= ?)
          AND (? IS NULL OR p.received_at <= ?)
        GROUP BY period
        UNION
        SELECT $expPeriod AS period
        FROM expenses e
        WHERE e.deleted_at IS NULL
          AND (? IS NULL OR e.occurred_at >= ?)
          AND (? IS NULL OR e.occurred_at <= ?)
        GROUP BY period
        UNION
        SELECT $ordPeriod AS period
        FROM test_orders o
        WHERE o.deleted_at IS NULL
          AND (? IS NULL OR o.ordered_at >= ?)
          AND (? IS NULL OR o.ordered_at <= ?)
        GROUP BY period
      ),
      inv AS (
        SELECT $invPeriod AS period,
               COALESCE(SUM(i.total_cents),0) AS invoices_total_cents,
               COALESCE(SUM(i.paid_cents),0) AS invoices_paid_cents,
               COALESCE(SUM(i.balance_cents),0) AS invoices_balance_cents,
               COUNT(1) AS invoices_count
        FROM invoices i
        WHERE i.deleted_at IS NULL
          AND (? IS NULL OR i.issued_at >= ?)
          AND (? IS NULL OR i.issued_at <= ?)
        GROUP BY period
      ),
      pay AS (
        SELECT $payPeriod AS period,
               COALESCE(SUM(p.amount_cents),0) AS payments_received_cents,
               COUNT(1) AS payments_count
        FROM payments p
        WHERE p.deleted_at IS NULL
          AND (? IS NULL OR p.received_at >= ?)
          AND (? IS NULL OR p.received_at <= ?)
        GROUP BY period
      ),
      exp AS (
        SELECT $expPeriod AS period,
               COALESCE(SUM(e.amount_cents),0) AS expenses_cents,
               COUNT(1) AS expenses_count
        FROM expenses e
        WHERE e.deleted_at IS NULL
          AND (? IS NULL OR e.occurred_at >= ?)
          AND (? IS NULL OR e.occurred_at <= ?)
        GROUP BY period
      ),
      ord AS (
        SELECT $ordPeriod AS period,
               COUNT(1) AS orders_count
        FROM test_orders o
        WHERE o.deleted_at IS NULL
          AND (? IS NULL OR o.ordered_at >= ?)
          AND (? IS NULL OR o.ordered_at <= ?)
        GROUP BY period
      )
      SELECT
        p.period AS period,
        COALESCE(inv.invoices_total_cents, 0) AS invoices_total_cents,
        COALESCE(inv.invoices_paid_cents, 0) AS invoices_paid_cents,
        COALESCE(inv.invoices_balance_cents, 0) AS invoices_balance_cents,
        COALESCE(inv.invoices_count, 0) AS invoices_count,
        COALESCE(pay.payments_received_cents, 0) AS payments_received_cents,
        COALESCE(pay.payments_count, 0) AS payments_count,
        COALESCE(exp.expenses_cents, 0) AS expenses_cents,
        COALESCE(exp.expenses_count, 0) AS expenses_count,
        COALESCE(ord.orders_count, 0) AS orders_count
      FROM periods p
      LEFT JOIN inv ON inv.period = p.period
      LEFT JOIN pay ON pay.period = p.period
      LEFT JOIN exp ON exp.period = p.period
      LEFT JOIN ord ON ord.period = p.period
      ORDER BY p.period DESC;
    ''',
      () {
        final args = <Object?>[];
        void addRangeArgs() {
          args
            ..add(fromSec)
            ..add(fromSec)
            ..add(toSec)
            ..add(toSec);
        }

        // periods: invoices, payments, expenses, orders = 4 blocks
        addRangeArgs();
        addRangeArgs();
        addRangeArgs();
        addRangeArgs();

        // aggregates: inv, pay, exp, ord = 4 blocks
        addRangeArgs();
        addRangeArgs();
        addRangeArgs();
        addRangeArgs();

        assert(args.length == 32);
        return args;
      }(),
    );

    return rows
        .map((r) => Map<String, Object?>.from(r))
        .toList(growable: false);
  }
}
