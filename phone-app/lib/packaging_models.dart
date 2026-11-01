enum CaptureType {
  food,
  packaging,
  unknown;

  String get wireValue => switch (this) {
    CaptureType.food => 'food',
    CaptureType.packaging => 'packaging',
    CaptureType.unknown => 'unknown',
  };

  static CaptureType fromWireValue(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case null:
      case '':
      case 'food':
        // Requests sent before the metadata field existed were food captures.
        return CaptureType.food;
      case 'packaging':
        return CaptureType.packaging;
      default:
        return CaptureType.unknown;
    }
  }
}

extension CaptureTypeAnalysisPolicy on CaptureType {
  /// Missing/unknown legacy values keep the historic food-compatible route.
  /// Packaging must use the separate OCR analysis flow.
  bool get canUseFoodAnalysis => this != CaptureType.packaging;
}

enum NutritionBasis { per100g, per100ml, perServing, unknown }

extension NutritionBasisLabel on NutritionBasis {
  String get label => switch (this) {
    NutritionBasis.per100g => '每 100 g',
    NutritionBasis.per100ml => '每 100 mL',
    NutritionBasis.perServing => '每份/每包装',
    NutritionBasis.unknown => '计量基准未识别',
  };
}

class NutritionValue {
  const NutritionValue({
    required this.value,
    required this.unit,
    required this.rawText,
  });

  final double value;
  final String unit;
  final String rawText;

  String get displayValue => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  Map<String, dynamic> toMap() => {
    'value': value,
    'unit': unit,
    'rawText': rawText,
  };

  factory NutritionValue.fromMap(Map<String, dynamic> map) => NutritionValue(
    value: _asDouble(map['value']),
    unit: map['unit']?.toString() ?? '',
    rawText: map['rawText']?.toString() ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is NutritionValue &&
      other.value == value &&
      other.unit == unit &&
      other.rawText == rawText;

  @override
  int get hashCode => Object.hash(value, unit, rawText);
}

class NutritionFacts {
  const NutritionFacts({
    required this.basis,
    this.sectionDetected = false,
    this.energy,
    this.protein,
    this.fat,
    this.carbohydrate,
    this.sodium,
    this.sugar,
  });

  final NutritionBasis basis;
  final bool sectionDetected;
  final NutritionValue? energy;
  final NutritionValue? protein;
  final NutritionValue? fat;
  final NutritionValue? carbohydrate;
  final NutritionValue? sodium;
  final NutritionValue? sugar;

  int get parsedFieldCount => [
    energy,
    protein,
    fat,
    carbohydrate,
    sodium,
    sugar,
  ].whereType<NutritionValue>().length;

  Map<String, dynamic> toMap() => {
    'basis': basis.name,
    'sectionDetected': sectionDetected,
    'energy': energy?.toMap(),
    'protein': protein?.toMap(),
    'fat': fat?.toMap(),
    'carbohydrate': carbohydrate?.toMap(),
    'sodium': sodium?.toMap(),
    'sugar': sugar?.toMap(),
  };

  factory NutritionFacts.fromMap(Map<String, dynamic> map) => NutritionFacts(
    basis: NutritionBasis.values.firstWhere(
      (candidate) => candidate.name == map['basis']?.toString(),
      orElse: () => NutritionBasis.unknown,
    ),
    sectionDetected: map['sectionDetected'] == true,
    energy: _nutritionValueFromMap(map['energy']),
    protein: _nutritionValueFromMap(map['protein']),
    fat: _nutritionValueFromMap(map['fat']),
    carbohydrate: _nutritionValueFromMap(map['carbohydrate']),
    sodium: _nutritionValueFromMap(map['sodium']),
    sugar: _nutritionValueFromMap(map['sugar']),
  );
}

class PackagingFinding {
  const PackagingFinding({
    required this.name,
    required this.reason,
    this.canonicalKey,
  });

  final String name;
  final String reason;
  final String? canonicalKey;
}

enum PackagingRiskType {
  allergen,
  highSugar,
  addedSugar,
  highSodium,
  highFat,
  cautionIngredient,
  profilePreference,
}

enum PackagingRiskLevel { info, warning, high }

class PackagingRisk {
  const PackagingRisk({
    required this.type,
    required this.level,
    required this.title,
    required this.reason,
    required this.personalized,
  });

  final PackagingRiskType type;
  final PackagingRiskLevel level;
  final String title;
  final String reason;
  final bool personalized;

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'level': level.name,
    'title': title,
    'reason': reason,
    'personalized': personalized,
  };

  factory PackagingRisk.fromMap(Map<String, dynamic> map) => PackagingRisk(
    type: PackagingRiskType.values.firstWhere(
      (candidate) => candidate.name == map['type']?.toString(),
      orElse: () => PackagingRiskType.cautionIngredient,
    ),
    level: PackagingRiskLevel.values.firstWhere(
      (candidate) => candidate.name == map['level']?.toString(),
      orElse: () => PackagingRiskLevel.info,
    ),
    title: map['title']?.toString() ?? '',
    reason: map['reason']?.toString() ?? '',
    personalized: map['personalized'] == true,
  );
}

class PackagingRiskEvaluation {
  const PackagingRiskEvaluation({
    required this.allergens,
    required this.cautionIngredients,
    required this.risks,
    required this.suggestions,
  });

  final List<PackagingFinding> allergens;
  final List<PackagingFinding> cautionIngredients;
  final List<PackagingRisk> risks;
  final List<String> suggestions;
}

/// Packaging currently uses cloud OCR followed by deterministic local parsing
/// and risk rules. It does not invoke a text-generation model.
enum PackagingAnalysisSource { qwenVisionOcrDeterministic, deterministicText }

class PackagingAnalysisResult {
  const PackagingAnalysisResult({
    required this.rawOcrText,
    required this.ingredients,
    required this.nutrition,
    required this.allergens,
    required this.cautionIngredients,
    required this.risks,
    required this.suggestions,
    required this.analysisSource,
    this.productName = '',
  });

  final String rawOcrText;
  final List<String> ingredients;
  final NutritionFacts nutrition;
  final List<PackagingFinding> allergens;
  final List<PackagingFinding> cautionIngredients;
  final List<PackagingRisk> risks;
  final List<String> suggestions;
  final PackagingAnalysisSource analysisSource;
  final String productName;
}

/// A user-confirmed packaging scan. It is intentionally independent from
/// [MealRecord], because reading a label does not mean the product was eaten.
class PackagingScanRecord {
  const PackagingScanRecord({
    required this.id,
    required this.imagePath,
    required this.createdAt,
    required this.rawOcrText,
    required this.confirmedIngredients,
    required this.confirmedNutrition,
    required this.risks,
    this.mealSessionId,
  });

  final String id;
  final String imagePath;
  final DateTime createdAt;
  final String rawOcrText;
  final List<String> confirmedIngredients;
  final NutritionFacts confirmedNutrition;
  final List<PackagingRisk> risks;
  final String? mealSessionId;

  factory PackagingScanRecord.fromAnalysis({
    required String id,
    required String imagePath,
    required DateTime createdAt,
    required PackagingAnalysisResult analysis,
    String? mealSessionId,
  }) => PackagingScanRecord(
    id: id,
    imagePath: imagePath,
    createdAt: createdAt,
    rawOcrText: analysis.rawOcrText,
    confirmedIngredients: List<String>.unmodifiable(analysis.ingredients),
    confirmedNutrition: analysis.nutrition,
    risks: List<PackagingRisk>.unmodifiable(analysis.risks),
    mealSessionId: mealSessionId,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
    'rawOcrText': rawOcrText,
    'confirmedIngredients': confirmedIngredients,
    'confirmedNutrition': confirmedNutrition.toMap(),
    'risks': risks.map((risk) => risk.toMap()).toList(growable: false),
    'mealSessionId': mealSessionId,
  };

  factory PackagingScanRecord.fromMap(Map<String, dynamic> map) =>
      PackagingScanRecord(
        id: map['id']?.toString() ?? '',
        imagePath: map['imagePath']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        rawOcrText: map['rawOcrText']?.toString() ?? '',
        confirmedIngredients: _stringList(map['confirmedIngredients']),
        confirmedNutrition: _factsFromMap(map['confirmedNutrition']),
        risks: _riskList(map['risks']),
        mealSessionId: _optionalString(map['mealSessionId']),
      );
}

NutritionValue? _nutritionValueFromMap(Object? value) {
  if (value is! Map) return null;
  return NutritionValue.fromMap(Map<String, dynamic>.from(value));
}

NutritionFacts _factsFromMap(Object? value) {
  if (value is! Map) return const NutritionFacts(basis: NutritionBasis.unknown);
  return NutritionFacts.fromMap(Map<String, dynamic>.from(value));
}

List<PackagingRisk> _riskList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => PackagingRisk.fromMap(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
