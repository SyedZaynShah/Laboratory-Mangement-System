import 'package:riverpod/riverpod.dart';
import 'finance_repository.dart';
import 'expenses_repository.dart';

export 'finance_repository.dart' show FinanceGroupBy;

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref);
});

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref);
});

class FinanceQuery {
  final FinanceGroupBy groupBy;
  final int? fromSec;
  final int? toSec;
  const FinanceQuery({
    required this.groupBy,
    required this.fromSec,
    required this.toSec,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is FinanceQuery &&
            other.groupBy == groupBy &&
            other.fromSec == fromSec &&
            other.toSec == toSec);
  }

  @override
  int get hashCode => Object.hash(groupBy, fromSec, toSec);
}

final financeSummaryProvider = FutureProvider.autoDispose
    .family<FinanceSummary, FinanceQuery>((ref, q) async {
      final repo = ref.read(financeRepositoryProvider);
      return repo.getSummary(fromSec: q.fromSec, toSec: q.toSec);
    });

final financePeriodsProvider = FutureProvider.autoDispose
    .family<List<FinancePeriodRow>, FinanceQuery>((ref, q) async {
      final repo = ref.read(financeRepositoryProvider);
      return repo.listPeriods(
        groupBy: q.groupBy,
        fromSec: q.fromSec,
        toSec: q.toSec,
      );
    });

final expensesListProvider = FutureProvider.autoDispose
    .family<List<ExpenseRow>, FinanceQuery>((ref, q) async {
      final repo = ref.read(expensesRepositoryProvider);
      return repo.listExpenses(fromSec: q.fromSec, toSec: q.toSec);
    });
