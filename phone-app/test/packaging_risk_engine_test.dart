import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/models.dart';
import 'package:ai_glasses_nutrition_app/packaging_models.dart';
import 'package:ai_glasses_nutrition_app/services/packaging_risk_engine.dart';

const _blankProfile = AppUserProfile(
  name: '测试用户',
  deviceName: 'RV101',
  gender: '未设置',
  age: 20,
  heightCm: 170,
  weightKg: 60,
  goal: '',
  preference: '',
  dailyTargetCalories: 2000,
  allergies: [],
  conditions: [],
);

NutritionFacts _facts({
  NutritionValue? sodium,
  NutritionValue? fat,
  NutritionValue? sugar,
  NutritionBasis basis = NutritionBasis.per100g,
}) => NutritionFacts(basis: basis, sodium: sodium, fat: fat, sugar: sugar);

void main() {
  const engine = PackagingRiskEngine();

  test(
    'escalates peanut allergy found in ingredients for the matching profile',
    () {
      final profile = _blankProfile.copyWith(allergies: const ['花生']);

      final result = engine.evaluate(
        nutrition: _facts(),
        ingredients: const ['白砂糖', '花生碎'],
        profile: profile,
      );

      expect(result.allergens.map((item) => item.name), contains('花生'));
      expect(
        result.risks.any(
          (risk) =>
              risk.type == PackagingRiskType.allergen &&
              risk.level == PackagingRiskLevel.high &&
              risk.personalized,
        ),
        isTrue,
      );
    },
  );

  test(
    'does not create a personalized allergen warning without a matching profile allergy',
    () {
      final result = engine.evaluate(
        nutrition: _facts(),
        ingredients: const ['花生碎'],
        profile: _blankProfile,
      );

      expect(result.allergens, isNotEmpty);
      expect(result.risks.where((risk) => risk.personalized), isEmpty);
    },
  );

  test('flags sodium and fat only with a known per-100 basis', () {
    final result = engine.evaluate(
      nutrition: _facts(
        sodium: const NutritionValue(value: 680, unit: 'mg', rawText: '680mg'),
        fat: const NutritionValue(value: 25.4, unit: 'g', rawText: '25.4g'),
      ),
      ingredients: const [],
      profile: _blankProfile,
    );

    expect(
      result.risks.map((risk) => risk.type),
      contains(PackagingRiskType.highSodium),
    );
    expect(
      result.risks.map((risk) => risk.type),
      contains(PackagingRiskType.highFat),
    );
  });

  test(
    'does not treat unknown nutrition basis as a high-content measurement',
    () {
      final result = engine.evaluate(
        nutrition: _facts(
          basis: NutritionBasis.unknown,
          sodium: const NutritionValue(
            value: 680,
            unit: 'mg',
            rawText: '680mg',
          ),
          fat: const NutritionValue(value: 25.4, unit: 'g', rawText: '25.4g'),
        ),
        ingredients: const [],
        profile: _blankProfile,
      );

      expect(
        result.risks.where(
          (risk) =>
              risk.type == PackagingRiskType.highSodium ||
              risk.type == PackagingRiskType.highFat,
        ),
        isEmpty,
      );
    },
  );

  test(
    'does not treat per-serving nutrition as a per-100 high-content measurement',
    () {
      final result = engine.evaluate(
        nutrition: _facts(
          basis: NutritionBasis.perServing,
          sodium: const NutritionValue(
            value: 680,
            unit: 'mg',
            rawText: '680mg',
          ),
          fat: const NutritionValue(value: 25.4, unit: 'g', rawText: '25.4g'),
        ),
        ingredients: const [],
        profile: _blankProfile,
      );

      expect(
        result.risks.where(
          (risk) =>
              risk.type == PackagingRiskType.highSodium ||
              risk.type == PackagingRiskType.highFat,
        ),
        isEmpty,
      );
    },
  );

  test('flags added-sugar ingredients without inventing a sugar quantity', () {
    final result = engine.evaluate(
      nutrition: _facts(),
      ingredients: const ['水', '白砂糖', '果葡糖浆'],
      profile: _blankProfile,
    );

    expect(
      result.risks.map((risk) => risk.type),
      contains(PackagingRiskType.addedSugar),
    );
  });

  test(
    'uses conditions, preferences, and goals for non-diagnostic personalized prompts',
    () {
      final profile = _blankProfile.copyWith(
        conditions: const ['高血压'],
        preference: '低盐饮食',
        goal: '减脂控糖',
      );
      final result = engine.evaluate(
        nutrition: _facts(
          sodium: const NutritionValue(
            value: 680,
            unit: 'mg',
            rawText: '680mg',
          ),
          fat: const NutritionValue(value: 25, unit: 'g', rawText: '25g'),
        ),
        ingredients: const ['白砂糖'],
        profile: profile,
      );

      expect(result.risks.where((risk) => risk.personalized), isNotEmpty);
      expect(result.suggestions.join(' '), contains('档案'));
    },
  );

  test('preserves existing caution-ingredient coverage', () {
    final result = engine.evaluate(
      nutrition: _facts(),
      ingredients: const ['氢化植物油', '植脂末', '阿斯巴甜', '亚硝酸钠'],
      profile: _blankProfile,
    );

    expect(
      result.cautionIngredients.map((item) => item.name),
      containsAll(const ['氢化植物油', '植脂末', '阿斯巴甜', '亚硝酸钠']),
    );
  });

  test(
    'empty profile and missing nutrition values do not crash or create measurement risks',
    () {
      final result = engine.evaluate(
        nutrition: const NutritionFacts(basis: NutritionBasis.unknown),
        ingredients: const [],
        profile: _blankProfile,
      );

      expect(result.risks, isEmpty);
    },
  );

  test('generic protein is not treated as an egg allergen', () {
    final profile = _blankProfile.copyWith(allergies: const ['鸡蛋']);
    final result = engine.evaluate(
      nutrition: _facts(),
      ingredients: const ['大豆分离蛋白'],
      profile: profile,
    );

    expect(
      result.allergens.map((item) => item.canonicalKey),
      isNot(contains('egg')),
    );
    expect(
      result.risks.any(
        (risk) => risk.type == PackagingRiskType.allergen && risk.personalized,
      ),
      isFalse,
    );
  });
  test('egg protein matches egg allergy aliases', () {
    final profile = _blankProfile.copyWith(allergies: const ['鸡蛋']);
    final result = engine.evaluate(
      nutrition: _facts(),
      ingredients: const ['鸡蛋蛋白'],
      profile: profile,
    );

    expect(result.allergens.any((item) => item.canonicalKey == 'egg'), isTrue);
    expect(
      result.risks.any(
        (risk) =>
            risk.type == PackagingRiskType.allergen &&
            risk.level == PackagingRiskLevel.high,
      ),
      isTrue,
    );
  });

  test('dairy and soy profile aliases match related ingredients', () {
    final dairy = engine.evaluate(
      nutrition: _facts(),
      ingredients: const ['乳清蛋白'],
      profile: _blankProfile.copyWith(allergies: const ['乳制品']),
    );
    final soy = engine.evaluate(
      nutrition: _facts(),
      ingredients: const ['大豆蛋白'],
      profile: _blankProfile.copyWith(allergies: const ['大豆']),
    );

    expect(dairy.risks.any((risk) => risk.personalized), isTrue);
    expect(soy.risks.any((risk) => risk.personalized), isTrue);
  });

  test('uses separate food and drink threshold configuration', () {
    const thresholds = PackagingRiskThresholds(
      foodSugarGPer100g: 20,
      drinkSugarGPer100ml: 5,
      foodSodiumMgPer100g: 600,
      drinkSodiumMgPer100ml: 200,
      foodFatGPer100g: 17.5,
      drinkFatGPer100ml: 3,
    );
    const configuredEngine = PackagingRiskEngine(thresholds: thresholds);
    const sugar = NutritionValue(value: 10, unit: 'g', rawText: '10g');

    final food = configuredEngine.evaluate(
      nutrition: _facts(sugar: sugar, basis: NutritionBasis.per100g),
      ingredients: const [],
      profile: _blankProfile,
    );
    final drink = configuredEngine.evaluate(
      nutrition: _facts(sugar: sugar, basis: NutritionBasis.per100ml),
      ingredients: const [],
      profile: _blankProfile,
    );

    expect(
      food.risks.map((risk) => risk.type),
      isNot(contains(PackagingRiskType.highSugar)),
    );
    expect(
      drink.risks.map((risk) => risk.type),
      contains(PackagingRiskType.highSugar),
    );
  });

  test(
    'does not personalize sodium risk for a vague single-character condition',
    () {
      final result = engine.evaluate(
        nutrition: _facts(
          sodium: const NutritionValue(
            value: 680,
            unit: 'mg',
            rawText: '680mg',
          ),
        ),
        ingredients: const [],
        profile: _blankProfile.copyWith(conditions: const ['肾功能检查中']),
      );

      expect(
        result.risks.any(
          (risk) =>
              risk.type == PackagingRiskType.highSodium && risk.personalized,
        ),
        isFalse,
      );
    },
  );
}
