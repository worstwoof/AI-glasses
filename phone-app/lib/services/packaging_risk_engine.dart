import '../models.dart';
import '../packaging_models.dart';

/// Demo screening thresholds, centralized so they are reviewable rather than
/// scattered through UI code. They apply only to a known per-100g/per-100ml
/// nutrition basis and are not medical diagnoses.
class PackagingRiskThresholds {
  const PackagingRiskThresholds({
    this.sodiumMgPer100 = 600,
    this.fatGPer100 = 17.5,
    this.sugarGPer100 = 22.5,
  });

  final double sodiumMgPer100;
  final double fatGPer100;
  final double sugarGPer100;
}

class PackagingRiskEngine {
  const PackagingRiskEngine({
    this.thresholds = const PackagingRiskThresholds(),
  });

  final PackagingRiskThresholds thresholds;

  static const _allergenRules = <String, String>{
    '花生': '配料中出现花生相关成分，过敏人群应重点核对标签。',
    '乳粉': '属于乳制品来源成分，乳制品敏感人群建议留意。',
    '乳清': '属于乳制品来源成分，乳制品敏感人群建议留意。',
    '牛奶': '配料中出现牛奶相关成分，乳制品敏感人群建议留意。',
    '奶油': '属于乳制品来源成分，乳制品敏感人群建议留意。',
    '鸡蛋': '配料中出现蛋类相关成分，蛋类过敏人群建议留意。',
    '蛋白': '配料中出现蛋类相关成分，蛋类过敏人群建议留意。',
    '大豆': '配料中出现大豆相关成分，豆类敏感人群建议留意。',
    '黄豆': '配料中出现黄豆相关成分，豆类敏感人群建议留意。',
    '芝麻': '配料中出现芝麻相关成分，过敏体质建议留意。',
    '小麦': '配料中出现小麦相关成分，麸质敏感人群建议留意。',
    '麸质': '标签提示含麸质，麸质敏感人群建议留意。',
    '虾': '配料中出现甲壳类相关成分，海鲜过敏人群建议留意。',
    '蟹': '配料中出现甲壳类相关成分，海鲜过敏人群建议留意。',
    '鱼': '配料中出现鱼类相关成分，鱼类过敏人群建议留意。',
    '坚果': '配料中出现坚果相关成分，坚果过敏人群建议留意。',
  };

  static const _cautionRules = <String, String>{
    '亚硝酸钠': '腌制类添加剂提示，建议控制高频摄入。',
    '亚硝酸盐': '腌制类添加剂提示，建议控制高频摄入。',
    '苯并芘': '标签出现污染风险词时建议避免选择，并核对产品信息。',
    '氢化植物油': '可能涉及反式脂肪相关关注点，建议减少长期高频食用。',
    '植脂末': '常见于加工食品，可结合总体脂肪和糖含量控制频率。',
    '阿斯巴甜': '甜味剂成分，特殊代谢情况请以专业建议为准。',
    '安赛蜜': '甜味剂成分，建议避免长期高频大量摄入。',
    '脱氢乙酸钠': '防腐剂成分，高频食用人群可谨慎选择。',
    '日落黄': '人工色素类成分，建议减少高频摄入。',
    '胭脂红': '人工色素类成分，建议减少高频摄入。',
  };

  PackagingRiskEvaluation evaluate({
    required NutritionFacts nutrition,
    required List<String> ingredients,
    required AppUserProfile profile,
  }) {
    final source = ingredients.join('、');
    final allergens = _find(source, _allergenRules);
    final cautions = _find(source, _cautionRules);
    final risks = <PackagingRisk>[];

    final normalizedAllergies = profile.allergies
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    for (final allergen in allergens) {
      final matchesProfile = normalizedAllergies.any(
        (allergy) =>
            allergen.name.contains(allergy) || allergy.contains(allergen.name),
      );
      risks.add(
        PackagingRisk(
          type: PackagingRiskType.allergen,
          level: matchesProfile
              ? PackagingRiskLevel.high
              : PackagingRiskLevel.warning,
          title: matchesProfile
              ? '与你的过敏档案相关：${allergen.name}'
              : '可能的常见过敏原：${allergen.name}',
          reason: matchesProfile
              ? '配料与档案中过敏项匹配，建议避免食用并以包装标示为准。'
              : allergen.reason,
          personalized: matchesProfile,
        ),
      );
    }

    final hasComparableBasis =
        nutrition.basis == NutritionBasis.per100g ||
        nutrition.basis == NutritionBasis.per100ml;
    if (hasComparableBasis &&
        _massInMg(nutrition.sodium) >= thresholds.sodiumMgPer100) {
      risks.add(
        _nutritionRisk(
          PackagingRiskType.highSodium,
          '钠含量较高',
          '按${nutrition.basis.label}识别到 ${nutrition.sodium!.displayValue}${nutrition.sodium!.unit} 钠，建议关注同日其它高盐食物。',
          profile,
          const ['高血压', '肾', '水肿'],
          const ['低盐', '少盐'],
        ),
      );
    }
    if (hasComparableBasis &&
        _massInGrams(nutrition.fat) >= thresholds.fatGPer100) {
      risks.add(
        _nutritionRisk(
          PackagingRiskType.highFat,
          '脂肪含量较高',
          '按${nutrition.basis.label}识别到 ${nutrition.fat!.displayValue}${nutrition.fat!.unit} 脂肪，建议结合当天总摄入控制份量。',
          profile,
          const ['高血脂', '脂肪肝'],
          const ['低脂'],
        ),
      );
    }
    if (hasComparableBasis &&
        _massInGrams(nutrition.sugar) >= thresholds.sugarGPer100) {
      risks.add(
        _nutritionRisk(
          PackagingRiskType.highSugar,
          '糖含量较高',
          '按${nutrition.basis.label}识别到 ${nutrition.sugar!.displayValue}${nutrition.sugar!.unit} 糖，建议控制单次和高频摄入。',
          profile,
          const ['糖尿病', '血糖'],
          const ['控糖', '低糖'],
        ),
      );
    }
    if (_containsAny(source, const ['白砂糖', '果葡糖浆', '葡萄糖浆', '麦芽糖', '蔗糖'])) {
      risks.add(
        const PackagingRisk(
          type: PackagingRiskType.addedSugar,
          level: PackagingRiskLevel.info,
          title: '含添加糖相关配料',
          reason: '配料中出现糖或糖浆；未把碳水化合物数值当作糖含量。',
          personalized: false,
        ),
      );
    }
    for (final caution in cautions) {
      risks.add(
        PackagingRisk(
          type: PackagingRiskType.cautionIngredient,
          level: PackagingRiskLevel.info,
          title: '需关注配料：${caution.name}',
          reason: caution.reason,
          personalized: false,
        ),
      );
    }

    _addGoalAndPreferencePrompts(profile, risks);
    return PackagingRiskEvaluation(
      allergens: allergens,
      cautionIngredients: cautions,
      risks: risks,
      suggestions: _suggestions(risks, nutrition),
    );
  }

  PackagingRisk _nutritionRisk(
    PackagingRiskType type,
    String title,
    String reason,
    AppUserProfile profile,
    List<String> conditionKeywords,
    List<String> preferenceKeywords,
  ) {
    final profileText =
        '${profile.conditions.join(' ')} ${profile.preference} ${profile.goal}';
    final personalized = _containsAny(profileText, [
      ...conditionKeywords,
      ...preferenceKeywords,
    ]);
    return PackagingRisk(
      type: type,
      level: personalized
          ? PackagingRiskLevel.warning
          : PackagingRiskLevel.info,
      title: personalized ? '$title（与你的档案相关）' : title,
      reason: personalized ? '$reason 已结合你的健康档案或饮食目标给出提示，不构成诊断。' : reason,
      personalized: personalized,
    );
  }

  void _addGoalAndPreferencePrompts(
    AppUserProfile profile,
    List<PackagingRisk> risks,
  ) {
    final text = '${profile.preference} ${profile.goal}';
    if (_containsAny(text, const ['减脂', '控卡'])) {
      risks.add(
        const PackagingRisk(
          type: PackagingRiskType.profilePreference,
          level: PackagingRiskLevel.info,
          title: '结合减脂/控卡目标',
          reason: '包装营养信息不等于实际食用量，建议先确认份量再纳入当天计划。',
          personalized: true,
        ),
      );
    }
  }

  List<PackagingFinding> _find(String source, Map<String, String> rules) {
    final found = <PackagingFinding>[];
    for (final entry in rules.entries) {
      if (source.contains(entry.key) &&
          found.every((item) => item.name != entry.key)) {
        found.add(PackagingFinding(name: entry.key, reason: entry.value));
      }
    }
    return found;
  }

  List<String> _suggestions(
    List<PackagingRisk> risks,
    NutritionFacts nutrition,
  ) {
    if (risks.isEmpty) {
      return const ['未发现明显的规则型风险；建议仍以完整包装标示和实际食用量为准。'];
    }
    final suggestions = <String>[];
    if (risks.any((risk) => risk.personalized)) {
      suggestions.add('已结合档案中的过敏、疾病史、偏好或目标生成提示；该提示不构成医疗诊断。');
    }
    if (nutrition.basis == NutritionBasis.unknown) {
      suggestions.add('未能确认营养表计量基准，数值仅供核对原始标签，不用于含量等级判断。');
    }
    suggestions.add('包装识别结果不会自动写入饮食记录；请在实际食用后再单独记录。');
    return suggestions.take(3).toList();
  }

  bool _containsAny(String text, List<String> values) =>
      values.any((value) => text.contains(value));

  double _massInMg(NutritionValue? value) {
    if (value == null) return -1;
    return value.unit == 'g' ? value.value * 1000 : value.value;
  }

  double _massInGrams(NutritionValue? value) {
    if (value == null) return -1;
    return value.unit == 'mg' ? value.value / 1000 : value.value;
  }
}
