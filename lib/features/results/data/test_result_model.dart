class TestResultModel {
  final String id;
  final String testOrderItemId;
  final String? valueText;
  final double? valueNum;
  final double? referenceLow;
  final double? referenceHigh;
  final String? referenceText;
  final bool isAbnormal;
  final String? validatedBy;
  final int? validatedAt;
  final String? remarks;
  final int createdAt;
  final int updatedAt;

  TestResultModel({
    required this.id,
    required this.testOrderItemId,
    this.valueText,
    this.valueNum,
    this.referenceLow,
    this.referenceHigh,
    this.referenceText,
    required this.isAbnormal,
    this.validatedBy,
    this.validatedAt,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });
}
