class TestOrderItem {
  final String id;
  final String orderId;
  final String testId;
  final int priceCents;
  final int createdAt;

  TestOrderItem({
    required this.id,
    required this.orderId,
    required this.testId,
    required this.priceCents,
    required this.createdAt,
  });
}

class TestOrder {
  final String id;
  final String orderNumber;
  final String patientId;
  final int orderedAt;
  final String status;
  final int createdAt;
  final int updatedAt;

  // Derived (for listing)
  final String? patientName;
  final int? testsCount;
  final int? totalCents;

  TestOrder({
    required this.id,
    required this.orderNumber,
    required this.patientId,
    required this.orderedAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.patientName,
    this.testsCount,
    this.totalCents,
  });
}
