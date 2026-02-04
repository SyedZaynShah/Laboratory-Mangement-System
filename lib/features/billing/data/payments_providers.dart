import 'package:riverpod/riverpod.dart';
import 'payments_repository.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(ref);
});

final paymentsByInvoiceProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>((ref, invoiceId) async {
  final repo = ref.read(paymentsRepositoryProvider);
  return repo.listPayments(invoiceId);
});
