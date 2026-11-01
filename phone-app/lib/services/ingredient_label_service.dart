import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import 'ai_provider_config.dart';

class LabelRiskItem {
  const LabelRiskItem({required this.name, required this.reason});

  final String name;
  final String reason;
}

class IngredientLabelAnalysisResult {
  const IngredientLabelAnalysisResult({
    required this.rawText,
    required this.summary,
    required this.ingredients,
    required this.allergens,
    required this.cautionIngredients,
    required this.suggestions,
    required this.usedAi,
  });

  final String rawText;
  final String summary;
  final List<String> ingredients;
  final List<LabelRiskItem> allergens;
  final List<LabelRiskItem> cautionIngredients;
  final List<String> suggestions;
  final bool usedAi;
}

class IngredientLabelService {
  IngredientLabelService._();

  static const String apiKey = AiProviderConfig.apiKey;
  static String get apiUrl => AiProviderConfig.chatCompletionsUrl;
  static const String textModel = AiProviderConfig.textModel;

  static bool get aiConfigured => apiKey.trim().isNotEmpty;

  static Future<IngredientLabelAnalysisResult> analyzeLabel({
    required XFile image,
    required AppUserProfile profile,
  }) async {
    final rawText = await _recognizeText(image);
    final normalizedText = _normalizeText(rawText);
    if (normalizedText.isEmpty) {
      throw const IngredientLabelException('未识别到清晰文字，请尽量正对配料表重新拍摄。');
    }

    if (!aiConfigured) {
      return _fallbackAnalyze(normalizedText, profile);
    }

    try {
      return await _analyzeWithAi(normalizedText, profile);
    } on IngredientLabelException {
      rethrow;
    } catch (_) {
      return _fallbackAnalyze(normalizedText, profile);
    }
  }

  static Future<String> _recognizeText(XFile image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  static Future<IngredientLabelAnalysisResult> _analyzeWithAi(
    String text,
    AppUserProfile profile,
  ) async {
    final requestId = _requestId();
    final uri = Uri.parse(apiUrl);

    final payload = <String, dynamic>{
      'model': textModel,
      'temperature': 0.2,
      'max_tokens': 1200,
      'stream': false,
      'messages': [
        {
          'role': 'system',
          'content':
              'You analyze Chinese ingredient labels. Return JSON only. '
              'Do not state something is carcinogenic unless the OCR text directly suggests a known carcinogenic contaminant or clearly high-risk term. '
              'Prefer wording like 需要留意, 高风险添加剂提示, 或 可能存在风险. '
              'Return exactly one JSON object with keys: '
              'summary, ingredients, allergens, caution_ingredients, suggestions. '
              'ingredients is a string array. '
              'allergens and caution_ingredients are arrays of objects with keys name and reason. '
              'suggestions is a Chinese array with 2 to 4 items.',
        },
        {
          'role': 'user',
          'content':
              'User allergies: ${profile.allergies.join("、")}; '
              'conditions: ${profile.conditions.join("、")}; '
              'goal: ${profile.goal}. '
              'OCR text: $text',
        },
      ],
    };

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.write(jsonEncode(payload));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw IngredientLabelException(
          'AI 配料分析失败，HTTP ${response.statusCode}。响应片段：${_clip(body)}',
        );
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final apiError = decoded['error'];
      if (apiError is Map<String, dynamic>) {
        final code = apiError['code']?.toString() ?? 'unknown';
        final message = apiError['message']?.toString() ?? '未知错误';
        throw IngredientLabelException('AI 配料分析失败 $code：$message');
      }

      final content = _extractContent(decoded, body);
      final parsed = _extractJsonObject(content);
      return _fromMap(
        map: parsed,
        rawText: text,
        fallbackProfile: profile,
        usedAi: true,
      );
    } on SocketException catch (error) {
      throw IngredientLabelException('网络连接失败：$error');
    } on FormatException catch (error) {
      throw IngredientLabelException('AI 返回格式异常：$error');
    } finally {
      client.close(force: true);
    }
  }

  static IngredientLabelAnalysisResult _fallbackAnalyze(
    String text,
    AppUserProfile profile,
  ) {
    final ingredients = _extractIngredients(text);
    final allergens = <LabelRiskItem>[];
    final caution = <LabelRiskItem>[];

    const allergenMap = <String, String>{
      '花生': '配料中包含花生相关成分，对花生过敏人群需避免。',
      '乳粉': '属于乳制品来源成分，对奶制品过敏人群需谨慎。',
      '奶油': '属于乳制品来源成分，对奶制品过敏人群需谨慎。',
      '乳清': '属于乳制品来源成分，对奶制品过敏人群需谨慎。',
      '牛奶': '配料含牛奶相关成分，乳糖不耐或奶制品过敏者需留意。',
      '鸡蛋': '配料含鸡蛋相关成分，对蛋类过敏者需留意。',
      '蛋白': '配料含蛋类相关成分，对蛋类过敏者需留意。',
      '大豆': '配料含大豆相关成分，对豆类敏感人群需留意。',
      '黄豆': '配料含黄豆相关成分，对豆类敏感人群需留意。',
      '芝麻': '配料含芝麻相关成分，对芝麻过敏者需留意。',
      '小麦': '配料含小麦相关成分，对麸质敏感人群需留意。',
      '麸质': '配料提示含麸质，对麸质敏感人群需留意。',
      '虾': '配料含甲壳类相关成分，对海鲜过敏者需谨慎。',
      '蟹': '配料含甲壳类相关成分，对海鲜过敏者需谨慎。',
      '鱼': '配料含鱼类相关成分，对鱼类过敏者需谨慎。',
      '坚果': '配料含坚果相关成分，过敏体质需重点留意。',
    };

    const cautionMap = <String, String>{
      '亚硝酸钠': '属于需要控制摄入频率的添加剂，腌制加工食品中要特别留意。',
      '亚硝酸盐': '提示存在腌制类添加剂风险，建议减少高频摄入。',
      '苯并芘': '属于需要高度警惕的污染风险词，如果是检测信息出现建议尽量避免。',
      '氢化植物油': '可能关联反式脂肪风险，建议减少长期高频摄入。',
      '植脂末': '常见于高糖高脂加工食品，建议控制频率和总量。',
      '阿斯巴甜': '甜味剂类成分，苯丙酮尿症等特殊人群需重点留意。',
      '安赛蜜': '甜味剂类成分，建议避免长期高频大量摄入。',
      '脱氢乙酸钠': '属于需要留意的防腐剂成分，儿童和高频食用人群可谨慎选择。',
      '合成着色剂': '如果为长期高频食用食品，建议优先选择添加剂更少的版本。',
      '日落黄': '属于人工色素类成分，儿童和高频食用人群可适当减少摄入。',
      '胭脂红': '属于人工色素类成分，建议减少高频摄入。',
    };

    for (final entry in allergenMap.entries) {
      if (text.contains(entry.key) &&
          allergens.every((item) => item.name != entry.key)) {
        allergens.add(LabelRiskItem(name: entry.key, reason: entry.value));
      }
    }

    for (final entry in cautionMap.entries) {
      if (text.contains(entry.key) &&
          caution.every((item) => item.name != entry.key)) {
        caution.add(LabelRiskItem(name: entry.key, reason: entry.value));
      }
    }

    final matchedUserAllergies = profile.allergies
        .where((allergy) => text.contains(allergy))
        .toList();

    final suggestions = <String>[
      if (matchedUserAllergies.isNotEmpty)
        '检测到与你档案中过敏项相关的成分：${matchedUserAllergies.join("、")}，建议直接避免食用。',
      if (caution.isNotEmpty)
        '这份配料表含有 ${caution.first.name} 等需留意成分，建议控制食用频率和份量。',
      if (ingredients.length > 12) '配料项较多，通常代表加工度较高，可优先选择配料更短、更简单的替代品。',
      '如果是经常购买的包装食品，建议同时查看营养成分表里的钠、糖和反式脂肪信息。',
    ];

    return IngredientLabelAnalysisResult(
      rawText: text,
      summary: _buildFallbackSummary(
        ingredients: ingredients,
        allergens: allergens,
        cautionIngredients: caution,
      ),
      ingredients: ingredients,
      allergens: allergens,
      cautionIngredients: caution,
      suggestions: suggestions.take(4).toList(),
      usedAi: false,
    );
  }

  static IngredientLabelAnalysisResult _fromMap({
    required Map<String, dynamic> map,
    required String rawText,
    required AppUserProfile fallbackProfile,
    required bool usedAi,
  }) {
    final ingredients = (map['ingredients'] as List<dynamic>? ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final allergens = _parseRiskList(map['allergens']);
    final caution = _parseRiskList(map['caution_ingredients']);
    final suggestions = (map['suggestions'] as List<dynamic>? ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return IngredientLabelAnalysisResult(
      rawText: rawText,
      summary: map['summary']?.toString().trim().isNotEmpty == true
          ? map['summary'].toString().trim()
          : _buildFallbackSummary(
              ingredients: ingredients,
              allergens: allergens,
              cautionIngredients: caution,
            ),
      ingredients: ingredients.isEmpty
          ? _extractIngredients(rawText)
          : ingredients,
      allergens: allergens,
      cautionIngredients: caution,
      suggestions: suggestions.isEmpty
          ? _fallbackAnalyze(rawText, fallbackProfile).suggestions
          : suggestions.take(4).toList(),
      usedAi: usedAi,
    );
  }

  static List<LabelRiskItem> _parseRiskList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map<LabelRiskItem?>((item) {
          if (item is Map<String, dynamic>) {
            final name = item['name']?.toString().trim() ?? '';
            final reason = item['reason']?.toString().trim() ?? '';
            if (name.isEmpty && reason.isEmpty) {
              return null;
            }
            return LabelRiskItem(
              name: name.isEmpty ? '需留意成分' : name,
              reason: reason.isEmpty ? '建议结合配料表和食用频率综合判断。' : reason,
            );
          }
          final text = item.toString().trim();
          if (text.isEmpty) {
            return null;
          }
          return LabelRiskItem(name: text, reason: '建议结合食用频率和个人情况进一步判断。');
        })
        .whereType<LabelRiskItem>()
        .toList();
  }

  static String _extractContent(Map<String, dynamic> decoded, String rawBody) {
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = message['content'];
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      }
    }

    throw IngredientLabelException('AI 返回内容为空：${_clip(rawBody)}');
  }

  static Map<String, dynamic> _extractJsonObject(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const IngredientLabelException('AI 返回内容中没有可解析的 JSON。');
    }
    return jsonDecode(content.substring(start, end + 1))
        as Map<String, dynamic>;
  }

  static List<String> _extractIngredients(String text) {
    final markerMatch = RegExp(
      r'(配料表|配料|成分表|原料表)[:：]?\s*',
      caseSensitive: false,
    ).firstMatch(text);
    var source = text;
    if (markerMatch != null) {
      source = text.substring(markerMatch.end);
    }

    source = source
        .replaceAll('\n', '，')
        .replaceAll('、', '，')
        .replaceAll(';', '，')
        .replaceAll('；', '，')
        .replaceAll('。', '，');

    return source
        .split('，')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .where((item) => item.length <= 20)
        .take(20)
        .toList();
  }

  static String _normalizeText(String text) {
    return text.replaceAll('\r', '').replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  static String _buildFallbackSummary({
    required List<String> ingredients,
    required List<LabelRiskItem> allergens,
    required List<LabelRiskItem> cautionIngredients,
  }) {
    if (allergens.isEmpty && cautionIngredients.isEmpty) {
      return '已识别到 ${ingredients.length} 项配料，暂未发现明显高风险提示词，建议继续结合营养成分表查看糖、钠和脂肪。';
    }

    return '配料表中识别到 ${allergens.length} 项过敏相关成分、${cautionIngredients.length} 项需留意成分，建议结合个人过敏史和食用频率谨慎判断。';
  }

  static String _requestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  static String _clip(String text) {
    final normalized = text.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
    if (normalized.length <= 220) {
      return normalized;
    }
    return '${normalized.substring(0, 220)}...';
  }
}

class IngredientLabelException implements Exception {
  const IngredientLabelException(this.message);

  final String message;

  @override
  String toString() => message;
}
