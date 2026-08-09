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
enum PackagingAnalysisSource { vivoOcrDeterministic, deterministicText }

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
  });

  final String rawOcrText;
  final List<String> ingredients;
  final NutritionFacts nutrition;
  final List<PackagingFinding> allergens;
  final List<PackagingFinding> cautionIngredients;
  final List<PackagingRisk> risks;
  final List<String> suggestions;
  final PackagingAnalysisSource analysisSource;
}
