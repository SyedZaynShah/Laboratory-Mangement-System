import 'package:riverpod/riverpod.dart';
import 'test_orders_repository.dart';
import 'test_order_models.dart';

final testOrdersRepositoryProvider = Provider<TestOrdersRepository>((ref) {
  return TestOrdersRepository(ref);
});

final testOrdersPageProvider = FutureProvider.autoDispose
    .family<List<TestOrder>, int>((ref, page) async {
  final repo = ref.read(testOrdersRepositoryProvider);
  return repo.listOrders(page: page);
});

final testOrderByIdProvider = FutureProvider.autoDispose
    .family<TestOrder?, String>((ref, id) async {
  final repo = ref.read(testOrdersRepositoryProvider);
  return repo.getOrderById(id);
});
