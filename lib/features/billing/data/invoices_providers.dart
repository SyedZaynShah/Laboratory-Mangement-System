import 'package:riverpod/riverpod.dart';
import 'invoices_repository.dart';

final invoicesRepositoryProvider = Provider<InvoicesRepository>((ref) {
  return InvoicesRepository(ref);
});

final invoicesPageProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, int>((ref, page) async {
  final repo = ref.read(invoicesRepositoryProvider);
  return repo.listInvoices(page: page);
});

final invoiceByIdProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>?, String>((ref, id) async {
  final repo = ref.read(invoicesRepositoryProvider);
  return repo.getInvoiceById(id);
});

final invoiceItemsProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>((ref, invoiceId) async {
  final repo = ref.read(invoicesRepositoryProvider);
  return repo.listInvoiceItems(invoiceId);
});
