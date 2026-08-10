import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../packaging_models.dart';
import 'ingredient_label_service_v2.dart';
import 'nutrition_facts_parser.dart';
import 'packaging_risk_engine.dart';

class PackagingAnalysisException implements Exception {
  const PackagingAnalysisException(this.message, {this.code = 'OCR_ERROR'});

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// Orchestrates the packaging pipeline while keeping parsing and risk rules
/// deterministic and independently testable.
class PackagingAnalysisService {
  const PackagingAnalysisService({
    this.ocr = const IngredientLabelServiceV2Adapter(),
    this.parser = const NutritionFactsParser(),
    this.riskEngine = const PackagingRiskEngine(),
  });

  final IngredientLabelServiceV2Adapter ocr;
  final NutritionFactsParser parser;
  final PackagingRiskEngine riskEngine;

  Future<PackagingAnalysisResult> analyzeImage({
    required XFile image,
    required AppUserProfile profile,
  }) async {
    final rawText = await ocr.recognize(image);
    if (rawText.trim().isEmpty) {
      throw const PackagingAnalysisException('OCR 没有识别到清晰文字，请正对包装并减少反光后重试。');
    }
    return analyzeText(
      rawText: rawText,
      profile: profile,
      analysisSource: PackagingAnalysisSource.vivoOcrDeterministic,
    );
  }

  PackagingAnalysisResult analyzeText({
    required String rawText,
    required AppUserProfile profile,
    PackagingAnalysisSource analysisSource =
        PackagingAnalysisSource.deterministicText,
  }) {
    final normalized = rawText.trim();
    if (normalized.isEmpty) {
      throw const PackagingAnalysisException('OCR 原文为空。');
    }
    final ingredients = _extractIngredients(normalized);
    final nutrition = parser.parse(normalized);
    final evaluation = riskEngine.evaluate(
      nutrition: nutrition,
      ingredients: ingredients,
      profile: profile,
    );
    return PackagingAnalysisResult(
      rawOcrText: normalized,
      ingredients: ingredients,
      nutrition: nutrition,
      allergens: evaluation.allergens,
      cautionIngredients: evaluation.cautionIngredients,
      risks: evaluation.risks,
      suggestions: evaluation.suggestions,
      analysisSource: analysisSource,
    );
  }

  PackagingAnalysisResult recalculate({
    required PackagingAnalysisResult previous,
    required List<String> confirmedIngredients,
    required NutritionFacts confirmedNutrition,
    required AppUserProfile profile,
  }) {
    final ingredients = confirmedIngredients
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final evaluation = riskEngine.evaluate(
      nutrition: confirmedNutrition,
      ingredients: ingredients,
      profile: profile,
    );
    return PackagingAnalysisResult(
      rawOcrText: previous.rawOcrText,
      ingredients: ingredients,
      nutrition: confirmedNutrition,
      allergens: evaluation.allergens,
      cautionIngredients: evaluation.cautionIngredients,
      risks: evaluation.risks,
      suggestions: evaluation.suggestions,
      analysisSource: previous.analysisSource,
    );
  }

  List<String> _extractIngredients(String text) {
    final marker = RegExp(r'(配料表|配料|成分表|原料表)\s*[:：]?').firstMatch(text);
    if (marker == null) return const [];
    var source = text.substring(marker.end);
    final end = RegExp(r'(营养成分表|营养标签|产品标准号|净含量|规格)').firstMatch(source);
    if (end != null) source = source.substring(0, end.start);
    source = source
        .replaceAll('\r', '，')
        .replaceAll('\n', '，')
        .replaceAll('、', '，')
        .replaceAll(';', '，')
        .replaceAll('；', '，')
        .replaceAll('。', '，');
    return source
        .split('，')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty && item.length <= 32)
        .take(40)
        .toList(growable: false);
  }
}

/// Small adapter keeps the existing static OCR implementation behind an
/// injectable boundary for parser/service tests.
class IngredientLabelServiceV2Adapter {
  const IngredientLabelServiceV2Adapter();

  Future<String> recognize(XFile image) {
    if (!IngredientLabelServiceV2.aiConfigured) {
      throw const IngredientLabelException('未检测到 AI_API_KEY，暂时无法使用包装 OCR。');
    }
    return IngredientLabelServiceV2.recognizeText(image);
  }
}
