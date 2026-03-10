import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';

class DashboardRepository extends BaseRepository {
  DashboardRepository(Ref ref) : super(ref);

  Map<String, int> _todayBounds() {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000;
    final end =
        DateTime(
              now.year,
              now.month,
              now.day,
              23,
              59,
              59,
              999,
            ).millisecondsSinceEpoch ~/
            1000 +
        1;
    return {'start': start, 'end': end};
  }

  Future<int> patientsToday() async {
    final d = await db;
    final b = _todayBounds();
    final rs = d.select(
      'SELECT COUNT(1) AS c FROM patients WHERE deleted_at IS NULL AND created_at >= ? AND created_at < ?;',
      [b['start'], b['end']],
    );
    return (rs.first['c'] as int?) ?? 0;
  }

  Future<int> ordersToday() async {
    final d = await db;
    final b = _todayBounds();
    final rs = d.select(
      'SELECT COUNT(1) AS c FROM test_orders WHERE deleted_at IS NULL AND ordered_at >= ? AND ordered_at < ?;',
      [b['start'], b['end']],
    );
    return (rs.first['c'] as int?) ?? 0;
  }

  Future<int> pendingOrders() async {
    final d = await db;
    final rs = d.select(
      "SELECT COUNT(1) AS c FROM test_orders WHERE deleted_at IS NULL AND status IN ('ordered','sample_collected','in_process');",
    );
    return (rs.first['c'] as int?) ?? 0;
  }

  Future<int> completedOrders() async {
    final d = await db;
    final rs = d.select(
      "SELECT COUNT(1) AS c FROM test_orders WHERE deleted_at IS NULL AND status = 'completed';",
    );
    return (rs.first['c'] as int?) ?? 0;
  }

  Future<int> samplesCollectedToday() async {
    final d = await db;
    final b = _todayBounds();
    final rs = d.select(
      'SELECT COUNT(1) AS c FROM samples WHERE deleted_at IS NULL AND collected_at IS NOT NULL AND collected_at >= ? AND collected_at < ?;',
      [b['start'], b['end']],
    );
    return (rs.first['c'] as int?) ?? 0;
  }

  Future<int> revenueTodayCents() async {
    final d = await db;
    final b = _todayBounds();
    final rs = d.select(
      'SELECT COALESCE(SUM(amount_cents),0) AS c FROM payments WHERE deleted_at IS NULL AND received_at >= ? AND received_at < ?;',
      [b['start'], b['end']],
    );
    return (rs.first['c'] as int?) ?? 0;
  }
}
