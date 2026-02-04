import 'package:riverpod/riverpod.dart';
import 'results_repository.dart';

final testResultsRepositoryProvider = Provider<ResultsRepository>((ref) {
  return ResultsRepository(ref);
});

final testResultsByOrderProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>((ref, orderId) async {
      final repo = ref.read(testResultsRepositoryProvider);
      return repo.listResultsForOrder(orderId);
    });

final testResultByIdProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>?, String>((ref, resultId) async {
      return ref.read(testResultsRepositoryProvider).getResultById(resultId);
    });
