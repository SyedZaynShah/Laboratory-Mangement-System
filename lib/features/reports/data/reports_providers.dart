import 'package:riverpod/riverpod.dart';
import 'reports_repository.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref);
});

class ReportQuery {
  final String type; // 'patient_results' | 'invoices' | 'daily_summary'
  final String? patientId;
  final String? orderId;
  final String? invoiceId;
  final String? status;
  final int? fromSec;
  final int? toSec;
  final int token;
  const ReportQuery({
    required this.type,
    this.patientId,
    this.orderId,
    this.invoiceId,
    this.status,
    this.fromSec,
    this.toSec,
    this.token = 0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // Only compare fields that control when to refetch: type and token.
    // This keeps the provider stable while the user edits filters.
    return other is ReportQuery && other.type == type && other.token == token;
  }

  @override
  int get hashCode => Object.hash(type, token);
}

final reportDataProvider = FutureProvider.autoDispose
    .family<Object, ReportQuery>((ref, q) async {
      final repo = ref.read(reportsRepositoryProvider);
      switch (q.type) {
        case 'patient_results':
          return repo.fetchPatientResultReport(
            patientId: q.patientId,
            orderId: q.orderId,
            fromSec: q.fromSec,
            toSec: q.toSec,
            orderStatus: q.status,
          );
        case 'invoices':
          return repo.fetchInvoiceReport(
            invoiceId: q.invoiceId,
            fromSec: q.fromSec,
            toSec: q.toSec,
            status: q.status,
          );
        case 'daily_summary':
          return repo.fetchDailyLabSummary(
            fromSec: q.fromSec ?? 0,
            toSec: q.toSec ?? 4102444800, // year 2100
          );
        default:
          return <Map<String, Object?>>[];
      }
    });
