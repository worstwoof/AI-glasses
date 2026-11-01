import 'package:flutter_test/flutter_test.dart';

import '../lib/packaging_models.dart';
import '../lib/services/packaging_display_summary.dart';

void main() {
  test('builds a short product, allergen, and risk summary for glasses', () {
    const result = PackagingAnalysisResult(
      rawOcrText: '品名：坚果饼干\n配料表：小麦粉，花生，白砂糖',
      productName: '坚果饼干',
      ingredients: ['小麦粉', '花生', '白砂糖'],
      nutrition: NutritionFacts(basis: NutritionBasis.per100g),
      allergens: [
        PackagingFinding(name: '花生', reason: '匹配用户档案过敏原'),
      ],
      cautionIngredients: [],
      risks: [
        PackagingRisk(
          type: PackagingRiskType.allergen,
          level: PackagingRiskLevel.high,
          title: '花生过敏风险',
          reason: '配料表包含花生',
          personalized: true,
        ),
      ],
      suggestions: [],
      analysisSource: PackagingAnalysisSource.qwenVisionOcrDeterministic,
    );

    final summary = buildPackagingDisplaySummary(result);

    expect(summary.displayLines, hasLength(3));
    expect(summary.displayLines[0], '商品：坚果饼干');
    expect(summary.displayLines[1], contains('花生'));
    expect(summary.displayLines[2], contains('花生过敏风险'));
    expect(summary.toMap(captureTaskId: 'task_1')['displayDurationMs'], 6000);
  });
}
