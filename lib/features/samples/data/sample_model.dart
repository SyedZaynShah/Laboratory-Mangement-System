class SampleModel {
  final String id;
  final String testOrderItemId;
  final String sampleCode;
  final String status; // awaiting, collected, received, rejected, processed
  final int? collectedAt;
  final String? collectedBy;
  final String? container;
  final String? notes;
  final int createdAt;
  final int updatedAt;

  SampleModel({
    required this.id,
    required this.testOrderItemId,
    required this.sampleCode,
    required this.status,
    required this.collectedAt,
    required this.collectedBy,
    required this.container,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
}
