import 'package:riverpod/riverpod.dart';
import 'tests_repository.dart';
import 'test_model.dart';

final testsRepositoryProvider = Provider<TestsRepository>((ref) {
  return TestsRepository(ref);
});

final testsPageProvider = FutureProvider.autoDispose
    .family<List<TestModel>, int>((ref, page) async {
  final repo = ref.read(testsRepositoryProvider);
  return repo.getTests(page: page);
});

final testsSearchProvider = FutureProvider.autoDispose
    .family<List<TestModel>, String>((ref, query) async {
  final repo = ref.read(testsRepositoryProvider);
  if (query.trim().isEmpty) return <TestModel>[];
  return repo.searchTests(query);
});

final testByIdProvider = FutureProvider.autoDispose
    .family<TestModel?, String>((ref, id) async {
  final repo = ref.read(testsRepositoryProvider);
  return repo.getTestById(id);
});
