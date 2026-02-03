import 'package:riverpod/riverpod.dart';
import 'samples_repository.dart';

final samplesRepositoryProvider = Provider<SamplesRepository>((ref) {
  return SamplesRepository(ref);
});

final samplesPageProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>((ref, orderId) async {
  final repo = ref.read(samplesRepositoryProvider);
  return repo.listSamples(orderId);
});

final sampleByIdProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>?, String>((ref, id) async {
  final repo = ref.read(samplesRepositoryProvider);
  return repo.getSampleById(id);
});
