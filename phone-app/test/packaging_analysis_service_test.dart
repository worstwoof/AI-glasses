import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ai_glasses_nutrition_app/models.dart';
import 'package:ai_glasses_nutrition_app/packaging_models.dart';
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

class _FakeOcr extends IngredientLabelServiceV2Adapter {
  const _FakeOcr(this.text) : super();

  final String text;

  @override
  Future<String> recognize(XFile image) async => text;
}

void main() {
  const service = PackagingAnalysisService();

  test('explicit product name wins over the first OCR line', () {
    final result = service.analyzeText(
      rawText: '广告文字\n产品名称：花生饼干\n配料表：花生',
      profile: _profile,
    );
    expect(result.productName, '花生饼干');
  });

  test('empty OCR is an error rather than a risk conclusion', () async {
    const service = PackagingAnalysisService(ocr: _FakeOcr('  '));
    await expectLater(
      service.analyzeImage(image: XFile('label.jpg'), profile: _profile),
      throwsA(isA<PackagingAnalysisException>()),
    );
  });

  test('combines OCR text, nutrition parsing, and profile risks', () {
    final result = service.analyzeText(
      rawText: '''
配料表：水、白砂糖、花生碎
营养成分表 每100克
能量 2090千焦
蛋白质 6.8克
脂肪 25.4克
碳水化合物 58.3克
钠 680毫克
''',
      profile: _profile,
    );

    expect(result.ingredients, contains('花生碎'));
    expect(result.nutrition.sodium?.value, 680);
    expect(
      result.risks.any(
        (risk) =>
            risk.type == PackagingRiskType.allergen &&
            risk.level == PackagingRiskLevel.high,
      ),
      isTrue,
    );
    expect(
      result.risks.map((risk) => risk.type),
      contains(PackagingRiskType.highSodium),
    );
    expect(result.rawOcrText, contains('营养成分表'));
  });

  test('records OCR provenance without claiming text AI was used', () async {
    const service = PackagingAnalysisService(
      ocr: _FakeOcr('营养成分表 每100克 能量 100千焦'),
    );

    final result = await service.analyzeImage(
      image: XFile('packaging.jpg'),
      profile: _profile,
    );

    expect(
      result.analysisSource,
      PackagingAnalysisSource.qwenVisionOcrDeterministic,
    );
  });
}
