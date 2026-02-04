class InvoiceModel {
  final String id;
  final String invoiceNo;
  final String patientId;
  final int issuedAt;
  final String status;
  final int subtotalCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;
  final int paidCents;
  final int balanceCents;
  final String? patientName;

  InvoiceModel({
    required this.id,
    required this.invoiceNo,
    required this.patientId,
    required this.issuedAt,
    required this.status,
    required this.subtotalCents,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
    required this.paidCents,
    required this.balanceCents,
    this.patientName,
  });
}
