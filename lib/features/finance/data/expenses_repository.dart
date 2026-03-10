import 'package:riverpod/riverpod.dart';
import '../../../core/database/base_repository.dart';
import '../../../core/auth/auth_controller.dart';

typedef ExpenseRow = Map<String, Object?>;

class ExpensesRepository extends BaseRepository {
  ExpensesRepository(Ref ref) : super(ref);

  Future<String> createExpense({
    required String category,
    required int amountCents,
    required int occurredAt,
    String? notes,
  }) async {
    if (amountCents <= 0) {
      throw ArgumentError('Expense amount must be > 0');
    }
    final d = await db;
    final ts = nowSec();
    final id = newId();
    final uid = ref.read(currentUserIdProvider);

    final stmt = d.prepare('''
      INSERT INTO expenses(
        id, category, amount_cents, occurred_at, notes,
        created_by, created_at, updated_at
      ) VALUES (?,?,?,?,?,?,?,?)
    ''');
    try {
      stmt.execute([
        id,
        category.trim(),
        amountCents,
        occurredAt,
        notes,
        uid,
        ts,
        ts,
      ]);
    } finally {
      stmt.dispose();
    }
    return id;
  }

  Future<List<ExpenseRow>> listExpenses({
    required int? fromSec,
    required int? toSec,
    int limit = 200,
  }) async {
    final d = await db;
    final rows = d.select(
      '''
      SELECT e.*,
             u.name AS created_by_name
      FROM expenses e
      LEFT JOIN users u ON u.id = e.created_by
      WHERE e.deleted_at IS NULL
        AND (? IS NULL OR e.occurred_at >= ?)
        AND (? IS NULL OR e.occurred_at <= ?)
      ORDER BY e.occurred_at DESC
      LIMIT ?
    ''',
      [fromSec, fromSec, toSec, toSec, limit],
    );
    return rows.map((r) => Map<String, Object?>.from(r)).toList(growable: false);
  }

  Future<void> deleteExpense(String id) async {
    await softDelete('expenses', id);
  }
}
