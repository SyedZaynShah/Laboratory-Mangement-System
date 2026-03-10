import 'package:riverpod/riverpod.dart';
import 'dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref);
});

final patientsTodayProvider = StreamProvider<int>((ref) async* {
  final repo = ref.read(dashboardRepositoryProvider);
  while (true) {
    yield await repo.patientsToday();
    await Future.delayed(const Duration(seconds: 3));
  }
});

final ordersTodayProvider = StreamProvider<int>((ref) async* {
  final repo = ref.read(dashboardRepositoryProvider);
  while (true) {
    yield await repo.ordersToday();
    await Future.delayed(const Duration(seconds: 3));
  }
});

final pendingOrdersProvider = StreamProvider<int>((ref) async* {
  final repo = ref.read(dashboardRepositoryProvider);
  while (true) {
    yield await repo.pendingOrders();
    await Future.delayed(const Duration(seconds: 3));
  }
});

final completedOrdersProvider = StreamProvider<int>((ref) async* {
  final repo = ref.read(dashboardRepositoryProvider);
  while (true) {
    yield await repo.completedOrders();
    await Future.delayed(const Duration(seconds: 3));
  }
});

final samplesCollectedTodayProvider = StreamProvider<int>((ref) async* {
  final repo = ref.read(dashboardRepositoryProvider);
  while (true) {
    yield await repo.samplesCollectedToday();
    await Future.delayed(const Duration(seconds: 3));
  }
});

final revenueTodayProvider = StreamProvider<int>((ref) async* {
  final repo = ref.read(dashboardRepositoryProvider);
  while (true) {
    yield await repo.revenueTodayCents();
    await Future.delayed(const Duration(seconds: 3));
  }
});
