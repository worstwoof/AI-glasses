import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:ai_glasses_nutrition_app/models.dart';
import 'package:ai_glasses_nutrition_app/packaging_models.dart';
import 'package:ai_glasses_nutrition_app/services/local_storage_service.dart';
import 'package:ai_glasses_nutrition_app/services/packaging_analysis_service.dart';

const _profile = AppUserProfile(
  name: '测试用户',
  deviceName: 'RV101',
  gender: '未设置',
  age: 20,
  heightCm: 170,
  weightKg: 60,
  goal: '',
  preference: '低盐饮食',
  dailyTargetCalories: 2000,
  allergies: ['花生'],
  conditions: ['高血压'],
);

void main() {
  const service = PackagingAnalysisService();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'recalculates packaging risks from user-corrected nutrition and ingredients',
    () {
      final original = service.analyzeText(
        rawText: '配料表：花生、食盐\n营养成分表 每100克\n钠 900毫克',
        profile: _profile,
      );
      expect(
        original.risks.map((risk) => risk.type),
        contains(PackagingRiskType.allergen),
      );
      expect(
        original.risks.map((risk) => risk.type),
        contains(PackagingRiskType.highSodium),
      );

      final corrected = service.recalculate(
        previous: original,
        confirmedIngredients: const ['水'],
        confirmedNutrition: const NutritionFacts(
          basis: NutritionBasis.per100g,
          sodium: NutritionValue(value: 10, unit: 'mg', rawText: '10毫克'),
        ),
        profile: _profile,
      );

      expect(
        corrected.risks.map((risk) => risk.type),
        isNot(contains(PackagingRiskType.allergen)),
      );
      expect(
        corrected.risks.map((risk) => risk.type),
        isNot(contains(PackagingRiskType.highSodium)),
      );
      expect(corrected.ingredients, const ['水']);
    },
  );

  test('confirmed packaging scan round-trips separately from meal records', () {
    const result = PackagingAnalysisResult(
      rawOcrText: '营养成分表 每100克 钠 10毫克',
      ingredients: ['水'],
      nutrition: NutritionFacts(
        basis: NutritionBasis.per100g,
        sodium: NutritionValue(value: 10, unit: 'mg', rawText: '10毫克'),
      ),
      allergens: [],
      cautionIngredients: [],
      risks: [],
      suggestions: [],
      analysisSource: PackagingAnalysisSource.deterministicText,
    );
    final record = PackagingScanRecord.fromAnalysis(
      id: 'scan_1',
      imagePath: 'capture.jpg',
      createdAt: DateTime.utc(2026, 8, 11),
      analysis: result,
    );

    final restored = PackagingScanRecord.fromMap(record.toMap());
    expect(restored.id, 'scan_1');
    expect(restored.imagePath, 'capture.jpg');
    expect(restored.confirmedIngredients, const ['水']);
    expect(restored.confirmedNutrition.sodium?.value, 10);
    expect(restored.mealSessionId, isNull);
  });

  test('confirmed packaging scan persists and reloads through local storage', () async {
    const result = PackagingAnalysisResult(
      rawOcrText: '营养成分表 每100克 钠 10毫克',
      ingredients: ['水'],
      nutrition: NutritionFacts(
        basis: NutritionBasis.per100g,
        sodium: NutritionValue(value: 10, unit: 'mg', rawText: '10毫克'),
      ),
      allergens: [],
      cautionIngredients: [],
      risks: [],
      suggestions: [],
      analysisSource: PackagingAnalysisSource.deterministicText,
    );
    final record = PackagingScanRecord.fromAnalysis(
      id: 'scan_persisted',
      imagePath: 'capture.jpg',
      createdAt: DateTime.utc(2026, 8, 13),
      analysis: result,
    );

    await LocalStorageService.savePackagingScan(record);
    final restored = await LocalStorageService.loadPackagingScans();

    expect(restored, hasLength(1));
    expect(restored.single.id, 'scan_persisted');
    expect(restored.single.confirmedNutrition.sodium?.value, 10);
    expect(restored.single.mealSessionId, isNull);
  });
}
