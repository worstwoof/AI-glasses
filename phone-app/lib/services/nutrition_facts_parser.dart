import '../packaging_models.dart';

/// Deterministic first-pass parser for OCR text. Missing values stay null.
class NutritionFactsParser {
  const NutritionFactsParser();

  NutritionFacts parse(String rawOcrText) {
    final section = _extractNutritionSection(rawOcrText);
    final normalized = _normalize(section.text);
    return NutritionFacts(
      basis: _parseBasis(normalized),
      sectionDetected: section.detected,
      energy: _findValue(normalized, r'(?:能量|energy)', _energyUnits),
      protein: _findValue(normalized, r'(?:蛋白质|蛋白|protein)', _massUnits),
      fat: _findValue(normalized, r'(?:总?脂肪|fat)', _massUnits),
      carbohydrate: _findValue(
        normalized,
        r'(?:碳水化合物|碳水|carbohydrate)',
        _massUnits,
      ),
      sodium: _findValue(normalized, r'(?:钠|\bna\b|sodium)', _massUnits),
      sugar: _findValue(
        normalized,
        r'(?<!碳水化合物)(?<!碳水)(?:糖|sugars?)',
        _massUnits,
      ),
    );
  }

  static const _energyUnits = r'(?:kJ|kj|千焦|kcal|KCAL|千卡)';
  static const _massUnits = r'(?:mg|MG|毫克|g|G|克)';
  static final _nutritionTitle = RegExp(
    r'(?:营养成分表|营养标签|nutrition\s*facts?)',
    caseSensitive: false,
  );
  static final _sectionEnd = RegExp(
    r'(?:配料表|配料|成分表|原料表|食用方法|贮存方法|储存方法|产品标准|生产日期|保质期|净含量|制造商|生产商|地址)',
    caseSensitive: false,
  );

  _NutritionSection _extractNutritionSection(String rawText) {
    final title = _nutritionTitle.firstMatch(rawText);
    if (title == null) {
      return _NutritionSection(text: rawText, detected: false);
    }

    final afterTitle = rawText.substring(title.end);
    final end = _sectionEnd.firstMatch(afterTitle);
    final sectionEnd = end == null ? rawText.length : title.end + end.start;
    return _NutritionSection(
      text: rawText.substring(title.start, sectionEnd),
      detected: true,
    );
  }

  String _normalize(String value) => value
      .replaceAll('，', ',')
      .replaceAll('。', '.')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'(?<=\d),(?=\d)'), '.')
      .trim();

  NutritionBasis _parseBasis(String text) {
    if (RegExp(
      r'每\s*100\s*(?:毫升|ml|mL)',
      caseSensitive: false,
    ).hasMatch(text)) {
      return NutritionBasis.per100ml;
    }
    if (RegExp(r'每\s*100\s*(?:克|g)', caseSensitive: false).hasMatch(text)) {
      return NutritionBasis.per100g;
    }
    if (RegExp(r'每\s*(?:份|包装|包)').hasMatch(text)) {
      return NutritionBasis.perServing;
    }
    return NutritionBasis.unknown;
  }

  NutritionValue? _findValue(String text, String label, String units) {
    final expression = RegExp(
      '$label(?:\\s*[:：]?)\\s*(\\d+(?:\\.\\d+)?)\\s*($units)',
      caseSensitive: false,
    );
    final match = expression.firstMatch(text);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    final unit = _canonicalUnit(match.group(2)!);
    return NutritionValue(
      value: value,
      unit: unit,
      rawText: '${match.group(1)}${match.group(2)}',
    );
  }

  String _canonicalUnit(String value) {
    switch (value.toLowerCase()) {
      case '千焦':
      case 'kj':
        return 'kJ';
      case '千卡':
      case 'kcal':
        return 'kcal';
      case '克':
      case 'g':
        return 'g';
      case '毫克':
      case 'mg':
        return 'mg';
      default:
        return value;
    }
  }
}

class _NutritionSection {
  const _NutritionSection({required this.text, required this.detected});

  final String text;
  final bool detected;
}
