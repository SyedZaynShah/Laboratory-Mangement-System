class TestModel {
  final String? id;
  final String testCode;
  final String testName;
  final String? category;
  final String sampleType;
  final String? unit;
  final double? normalRangeMin;
  final double? normalRangeMax;
  final int priceCents;
  final String? clinicalNotes;
  final bool isActive;
  final int? createdAt;
  final int? updatedAt;

  TestModel({
    this.id,
    required this.testCode,
    required this.testName,
    required this.category,
    required this.sampleType,
    required this.unit,
    required this.normalRangeMin,
    required this.normalRangeMax,
    required this.priceCents,
    required this.clinicalNotes,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  TestModel copyWith({
    String? id,
    String? testCode,
    String? testName,
    String? category,
    String? sampleType,
    String? unit,
    double? normalRangeMin,
    double? normalRangeMax,
    int? priceCents,
    String? clinicalNotes,
    bool? isActive,
    int? createdAt,
    int? updatedAt,
  }) {
    return TestModel(
      id: id ?? this.id,
      testCode: testCode ?? this.testCode,
      testName: testName ?? this.testName,
      category: category ?? this.category,
      sampleType: sampleType ?? this.sampleType,
      unit: unit ?? this.unit,
      normalRangeMin: normalRangeMin ?? this.normalRangeMin,
      normalRangeMax: normalRangeMax ?? this.normalRangeMax,
      priceCents: priceCents ?? this.priceCents,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
