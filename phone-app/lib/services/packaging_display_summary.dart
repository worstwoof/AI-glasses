import '../packaging_models.dart';

class PackagingDisplaySummary {
  const PackagingDisplaySummary({
    required this.productName,
    required this.allergens,
    required this.riskSummary,
    required this.displayLines,
    required this.severity,
  });

  final String productName;
  final List<String> allergens;
  final String riskSummary;
  final List<String> displayLines;
  final String severity;

  Map<String, dynamic> toMap({String? captureTaskId}) => {
    'type': 'analysis_result',
    'analysisType': 'packaging_ocr',
    'status': 'completed',
    if (captureTaskId != null && captureTaskId.isNotEmpty)
      'captureTaskId': captureTaskId,
    'productName': productName,
    'allergens': allergens,
    'riskSummary': riskSummary,
    'displayLines': displayLines,
    'displayDurationMs': 6000,
    'severity': severity,
  };
}

PackagingDisplaySummary buildPackagingDisplaySummary(
  PackagingAnalysisResult result,
) {
  final allergens = result.allergens
      .where(
        (finding) => result.risks.any(
          (risk) =>
              risk.type == PackagingRiskType.allergen &&
              risk.personalized &&
              risk.title.contains(finding.name),
        ),
      )
      .map((finding) => finding.name.trim())
      .where((name) => name.isNotEmpty)
      .take(3)
      .toList(growable: false);
  final allergenText = allergens.isEmpty ? '未发现档案匹配项' : allergens.join('、');
  final riskCandidates = <String>[
    ...result.risks
        .where((risk) => risk.level != PackagingRiskLevel.info)
        .map((risk) => risk.title.trim())
        .where((text) => text.isNotEmpty),
    ...result.cautionIngredients
        .map((finding) => finding.name.trim())
        .where((text) => text.isNotEmpty),
    ...result.suggestions
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty),
  ];
  final riskSummary = riskCandidates.isEmpty
      ? '信息有限，请核对完整标签'
      : riskCandidates.take(2).join('；');
  final productName = _shorten(
    result.productName.trim().isEmpty ? '未识别商品' : result.productName,
  );
  final lines = <String>[
    _shorten('商品：$productName', 22),
    _shorten('过敏原：$allergenText', 22),
    _shorten('提示：$riskSummary', 22),
  ];
  return PackagingDisplaySummary(
    productName: productName,
    allergens: allergens,
    riskSummary: _shorten(riskSummary),
    displayLines: lines,
    severity: allergens.isNotEmpty
        ? 'error'
        : result.risks.isNotEmpty
        ? 'warning'
        : 'success',
  );
}

String _shorten(String value, [int maxLength = 28]) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxLength) return normalized;
  return '${normalized.substring(0, maxLength - 1)}…';
}
