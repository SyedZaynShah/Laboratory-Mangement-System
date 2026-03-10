import 'package:riverpod/riverpod.dart';
import '../../../core/filters/time_filter.dart';
import 'patients_repository.dart';

final patientByIdProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>?, String>((ref, id) async {
      final repo = ref.read(patientsRepositoryProvider);
      return repo.getPatientById(id);
    });

final patientsSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>((ref, query) async {
      final repo = ref.read(patientsRepositoryProvider);
      return repo.searchPatients(query, limit: 20, offset: 0);
    });

final patientsPageProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, int>((ref, page) async {
      final repo = ref.read(patientsRepositoryProvider);
      final limit = 20;
      final offset = (page <= 1 ? 0 : (page - 1) * limit);
      return repo.listPatients(limit: limit, offset: offset);
    });

final patientInsightsProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>((ref, query) async {
      final repo = ref.read(patientsRepositoryProvider);
      final f = ref.watch(globalTimeFilterProvider);
      return repo.listPatientInsights(
        fromSec: f.fromSec,
        toSec: f.toSec,
        query: query,
        limit: 500,
      );
    });

final patientInsightTimelineProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>((ref, patientId) async {
      final repo = ref.read(patientsRepositoryProvider);
      final f = ref.watch(globalTimeFilterProvider);
      return repo.listPatientInsightTimeline(
        patientId: patientId,
        fromSec: f.fromSec,
        toSec: f.toSec,
        limit: 200,
      );
    });
