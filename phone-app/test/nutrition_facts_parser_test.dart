import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/nutrition_facts_parser.dart';
import 'package:ai_glasses_nutrition_app/packaging_models.dart';

void main() {
  const parser = NutritionFactsParser();

  test(
    'parses Chinese per-100g nutrition facts without treating missing data as zero',
    () {
      const text = '''
营养成分表
项目 每100克 NRV%
能量 2090千焦 25%
蛋白质 6.8克 11%
脂肪 25.4克 42%
碳水化合物 58.3克 19%
钠 680毫克 34%
''';

      final facts = parser.parse(text);

      expect(facts.basis, NutritionBasis.per100g);
      expect(
        facts.energy,
        const NutritionValue(value: 2090, unit: 'kJ', rawText: '2090千焦'),
      );
      expect(
        facts.protein,
        const NutritionValue(value: 6.8, unit: 'g', rawText: '6.8克'),
      );
      expect(
        facts.fat,
        const NutritionValue(value: 25.4, unit: 'g', rawText: '25.4克'),
      );
      expect(
        facts.carbohydrate,
        const NutritionValue(value: 58.3, unit: 'g', rawText: '58.3克'),
      );
      expect(
        facts.sodium,
        const NutritionValue(value: 680, unit: 'mg', rawText: '680毫克'),
      );
      expect(facts.sugar, isNull);
    },
  );

  test('accepts English units and irregular spaces', () {
    const text = '''
每 100 g
能量 450 kcal
蛋白质 3.2 g
总脂肪 10g
碳水 50 g
Na 500mg
''';

    final facts = parser.parse(text);

    expect(facts.basis, NutritionBasis.per100g);
    expect(facts.energy?.unit, 'kcal');
    expect(facts.energy?.value, 450);
    expect(facts.protein?.value, 3.2);
    expect(facts.fat?.value, 10);
    expect(facts.carbohydrate?.value, 50);
    expect(facts.sodium?.value, 500);
  });

  test('recognizes per-100ml beverage labels', () {
    const text = '营养成分表 每100毫升 能量 180 kJ 蛋白质 0g 脂肪 0g 碳水化合物 10.6g 钠 45 mg';

    final facts = parser.parse(text);

    expect(facts.basis, NutritionBasis.per100ml);
    expect(facts.carbohydrate?.value, 10.6);
    expect(facts.sodium?.unit, 'mg');
  });

  test('recognizes per-serving and per-package bases', () {
    final serving = parser.parse('每份 能量 620千焦 蛋白质 4克');
    final package = parser.parse('每包装 能量 620千焦 蛋白质 4克');

    expect(serving.basis, NutritionBasis.perServing);
    expect(package.basis, NutritionBasis.perServing);
  });

  test('keeps unknown basis unknown when OCR has no basis', () {
    final facts = parser.parse('能量 500 kJ 蛋白质 4g 脂肪 2g');

    expect(facts.basis, NutritionBasis.unknown);
  });

  test('does not create zero values for missing fields', () {
    final facts = parser.parse('营养成分表 每100克 钠 600毫克');

    expect(facts.energy, isNull);
    expect(facts.protein, isNull);
    expect(facts.fat, isNull);
    expect(facts.carbohydrate, isNull);
    expect(
      facts.sodium,
      const NutritionValue(value: 600, unit: 'mg', rawText: '600毫克'),
    );
  });

  test('does not mistake carbohydrate for sugar', () {
    final facts = parser.parse('每100克 碳水化合物 20g 糖 8g');

    expect(facts.carbohydrate?.value, 20);
    expect(facts.sugar?.value, 8);
  });
}
