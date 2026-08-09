import '../models.dart';
import '../packaging_models.dart';

/// Prototype screening thresholds only. Food and drink fields stay independent
/// so product/domain validation can replace each basis without changing rules.
/// They are not regulatory classifications or medical diagnostic thresholds.
class PackagingRiskThresholds {
  const PackagingRiskThresholds({
    this.foodSodiumMgPer100g = 600,
    this.foodFatGPer100g = 17.5,
    this.foodSugarGPer100g = 22.5,
    this.drinkSodiumMgPer100ml = 600,
    this.drinkFatGPer100ml = 17.5,
    this.drinkSugarGPer100ml = 22.5,
  });

  final double foodSodiumMgPer100g;
  final double foodFatGPer100g;
  final double foodSugarGPer100g;
  final double drinkSodiumMgPer100ml;
  final double drinkFatGPer100ml;
  final double drinkSugarGPer100ml;
}

class PackagingRiskEngine {
  const PackagingRiskEngine({
    this.thresholds = const PackagingRiskThresholds(),
  });

  final PackagingRiskThresholds thresholds;

  static const _allergenRules = <_AllergenRule>[
    _AllergenRule(
      'peanut',
      ['花生仁', '花生'],
      ['花生仁', '花生'],
      '配料中出现花生相关成分，过敏人群应重点核对标签。',
    ),
    _AllergenRule(
      'dairy',
      ['乳清蛋白', '乳清', '酪蛋白', '乳粉', '奶粉', '牛奶', '奶油'],
      ['乳制品', '奶制品', '乳清', '乳粉', '奶粉', '牛奶'],
      '配料中出现乳制品来源成分，乳制品敏感人群建议留意。',
    ),
    _AllergenRule(
      'egg',
      ['鸡蛋蛋白', '鸡蛋粉', '全蛋粉', '鸡蛋', '全蛋', '蛋黄', '蛋清'],
      ['鸡蛋', '蛋类', '蛋过敏'],
      '配料中出现蛋类相关成分，蛋类过敏人群建议留意。',
    ),
    _AllergenRule(
      'soy',
      ['大豆分离蛋白', '大豆蛋白', '黄豆', '大豆'],
      ['大豆', '黄豆', '豆类'],
      '配料中出现大豆相关成分，豆类敏感人群建议留意。',
    ),
    _AllergenRule('sesame', ['芝麻'], ['芝麻'], '配料中出现芝麻相关成分，过敏体质建议留意。'),
    _AllergenRule(
      'wheat',
      ['小麦粉', '小麦', '麸质'],
      ['小麦', '麸质'],
      '配料中出现小麦或麸质相关成分，敏感人群建议留意。',
    ),
    _AllergenRule('fish', ['鱼粉', '鱼'], ['鱼类', '鱼'], '配料中出现鱼类相关成分，鱼类过敏人群建议留意。'),
    _AllergenRule(
      'crustacean',
      ['甲壳类', '虾', '蟹'],
      ['甲壳类', '虾', '蟹', '海鲜'],
      '配料中出现甲壳类相关成分，海鲜过敏人群建议留意。',
    ),
    _AllergenRule(
      'tree_nut',
      ['开心果', '腰果', '杏仁', '核桃', '榛子', '坚果'],
      ['开心果', '腰果', '杏仁', '核桃', '榛子', '坚果'],
      '配料中出现坚果相关成分，坚果过敏人群建议留意。',
    ),
  ];

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
    final allergens = _findAllergens(source);
    final cautions = _find(source, _cautionRules);
    final risks = <PackagingRisk>[];

    for (final allergen in allergens) {
      final matchesProfile = profile.allergies.any(
        (allergy) =>
            _canonicalizeProfileAllergy(allergy) == allergen.canonicalKey,
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

    final sodiumThreshold = _sodiumThreshold(nutrition.basis);
    if (sodiumThreshold != null &&
        _massInMg(nutrition.sodium) >= sodiumThreshold) {
      risks.add(
        _nutritionRisk(
          PackagingRiskType.highSodium,
          '钠含量较高',
          '按${nutrition.basis.label}识别到 ${nutrition.sodium!.displayValue}${nutrition.sodium!.unit} 钠，建议关注同日其它高盐食物。',
          profile,
          const ['高血压', '需要控制钠摄入', '低钠饮食'],
          const ['低盐', '少盐', '低钠'],
        ),
      );
    }
    final fatThreshold = _fatThreshold(nutrition.basis);
    if (fatThreshold != null && _massInGrams(nutrition.fat) >= fatThreshold) {
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
    final sugarThreshold = _sugarThreshold(nutrition.basis);
    if (sugarThreshold != null &&
        _massInGrams(nutrition.sugar) >= sugarThreshold) {
      risks.add(
        _nutritionRisk(
          PackagingRiskType.highSugar,
          '糖含量较高',
          '按${nutrition.basis.label}识别到 ${nutrition.sugar!.displayValue}${nutrition.sugar!.unit} 糖，建议控制单次和高频摄入。',
          profile,
          const ['糖尿病', '血糖控制'],
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

  List<PackagingFinding> _findAllergens(String source) {
    final found = <PackagingFinding>[];
    for (final rule in _allergenRules) {
      final matchedAlias = rule.ingredientAliases.firstWhere(
        source.contains,
        orElse: () => '',
      );
      if (matchedAlias.isEmpty) continue;
      found.add(
        PackagingFinding(
          name: matchedAlias,
          reason: rule.reason,
          canonicalKey: rule.canonicalKey,
        ),
      );
    }
    return found;
  }

  String? _canonicalizeProfileAllergy(String allergy) {
    final value = allergy.trim();
    if (value.isEmpty) return null;
    for (final rule in _allergenRules) {
      if (rule.profileAliases.any(value.contains)) {
        return rule.canonicalKey;
      }
    }
    return null;
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

  double? _sodiumThreshold(NutritionBasis basis) => switch (basis) {
    NutritionBasis.per100g => thresholds.foodSodiumMgPer100g,
    NutritionBasis.per100ml => thresholds.drinkSodiumMgPer100ml,
    NutritionBasis.perServing || NutritionBasis.unknown => null,
  };

  double? _fatThreshold(NutritionBasis basis) => switch (basis) {
    NutritionBasis.per100g => thresholds.foodFatGPer100g,
    NutritionBasis.per100ml => thresholds.drinkFatGPer100ml,
    NutritionBasis.perServing || NutritionBasis.unknown => null,
  };

  double? _sugarThreshold(NutritionBasis basis) => switch (basis) {
    NutritionBasis.per100g => thresholds.foodSugarGPer100g,
    NutritionBasis.per100ml => thresholds.drinkSugarGPer100ml,
    NutritionBasis.perServing || NutritionBasis.unknown => null,
  };

  bool _containsAny(String text, List<String> values) =>
      values.any(text.contains);

  double _massInMg(NutritionValue? value) {
    if (value == null) return -1;
    return value.unit == 'g' ? value.value * 1000 : value.value;
  }

  double _massInGrams(NutritionValue? value) {
    if (value == null) return -1;
    return value.unit == 'mg' ? value.value / 1000 : value.value;
  }
}

class _AllergenRule {
  const _AllergenRule(
    this.canonicalKey,
    this.ingredientAliases,
    this.profileAliases,
    this.reason,
  );

  final String canonicalKey;
  final List<String> ingredientAliases;
  final List<String> profileAliases;
  final String reason;
}
