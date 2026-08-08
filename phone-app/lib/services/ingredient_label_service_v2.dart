import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';

import '../models.dart';

class LabelRiskItem {
  const LabelRiskItem({
    required this.name,
    required this.reason,
  });

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

class IngredientLabelServiceV2 {
  IngredientLabelServiceV2._();

  static const String appId = String.fromEnvironment(
    'AI_APP_ID',
    defaultValue: '2026209917',
  );
  static const String apiKey = String.fromEnvironment('AI_API_KEY');
  static const String embeddedApiKey = 'sk-xuanji-2026209917-VVB5SXd0TGxlYUZiZ2Rocw==';
  static const String textModel = String.fromEnvironment(
    'AI_TEXT_MODEL',
    defaultValue: 'Doubao-Seed-2.0-mini',
  );
  static const String chatApiUrl = String.fromEnvironment(
    'AI_API_URL',
    defaultValue: 'https://api-ai.vivo.com.cn/v1/chat/completions',
  );
  static const String ocrApiUrl = String.fromEnvironment(
    'AI_OCR_URL',
    defaultValue: 'http://api-ai.vivo.com.cn/ocr/general_recognition',
  );

  static String get effectiveApiKey =>
      apiKey.trim().isNotEmpty ? apiKey.trim() : embeddedApiKey;

  static bool get aiConfigured => effectiveApiKey.isNotEmpty;
  static String get businessId => 'aigc$appId';

  static Future<IngredientLabelAnalysisResult> analyzeLabel({
    required XFile image,
    required AppUserProfile profile,
  }) async {
    if (!aiConfigured) {
      throw const IngredientLabelException('未检测到 AI_API_KEY，暂时无法使用配料表 OCR。');
    }

    final rawText = await _recognizeText(image);
    final normalizedText = _normalizeText(rawText);
    if (normalizedText.isEmpty) {
      throw const IngredientLabelException('没有识别到清晰文字，请尽量正对配料表重新拍摄。');
    }

    try {
      return await _analyzeWithAi(normalizedText, profile);
    } catch (_) {
      return _fallbackAnalyze(normalizedText, profile);
    }
  }

  static Future<String> _recognizeText(XFile image) async {
    final bytes = await image.readAsBytes();
    final requestId = _requestId();
    final uri = Uri.parse(ocrApiUrl).replace(
      queryParameters: <String, String>{'requestId': requestId},
    );
    final body = Uri(
      queryParameters: <String, String>{
        'image': base64Encode(bytes),
        'pos': '0',
        'businessid': businessId,
        'sessid': requestId,
      },
    ).query;

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded',
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $effectiveApiKey');
      request.write(body);

      final response = await request.close();
      final payload = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw IngredientLabelException(
          'OCR 调用失败，HTTP ${response.statusCode}。响应片段：${_clip(payload)}',
        );
      }

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final errorCode = decoded['error_code'];
      if (errorCode is num && errorCode != 0) {
        final message = decoded['error_msg']?.toString() ?? '未知错误';
        throw IngredientLabelException('OCR 识别失败：$message');
      }

      final result = decoded['result'];
      if (result is! Map<String, dynamic>) {
        throw const IngredientLabelException('OCR 返回结果缺少 result 字段。');
      }

      final words = <String>[];
      final wordsList = result['words'];
      if (wordsList is List) {
        for (final item in wordsList) {
          if (item is Map<String, dynamic>) {
            final word = item['words']?.toString().trim() ?? '';
            if (word.isNotEmpty) {
              words.add(word);
            }
          }
        }
      }

      final ocrBlocks = result['OCR'];
      if (ocrBlocks is List) {
        for (final item in ocrBlocks) {
          if (item is Map<String, dynamic>) {
            final word = item['words']?.toString().trim() ?? '';
            if (word.isNotEmpty) {
              words.add(word);
            }
          }
        }
      }

      return words.join('\n').trim();
    } on SocketException catch (error) {
      throw IngredientLabelException('OCR 网络连接失败：$error');
    } on FormatException catch (error) {
      throw IngredientLabelException('OCR 返回格式异常：$error');
    } finally {
      client.close(force: true);
    }
  }

  static Future<IngredientLabelAnalysisResult> _analyzeWithAi(
    String text,
    AppUserProfile profile,
  ) async {
    final requestId = _requestId();
    final uri = Uri.parse(chatApiUrl).replace(
      queryParameters: <String, String>{'request_id': requestId},
    );

    final payload = <String, dynamic>{
      'model': textModel,
      'temperature': 0.1,
      'max_tokens': 900,
      'reasoning_effort': 'minimal',
      'stream': false,
      'messages': [
        {
          'role': 'system',
          'content':
              'You analyze Chinese ingredient labels. Return JSON only. '
              'Do not claim definite carcinogenicity unless the OCR text clearly includes a known carcinogenic contaminant or explicit high-risk term. '
              'If uncertain, use wording like 需要留意, 争议较高, 或 可能存在风险. '
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
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $effectiveApiKey');
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
      throw IngredientLabelException('AI 文本分析网络连接失败：$error');
    } on FormatException catch (error) {
      throw IngredientLabelException('AI 文本分析返回格式异常：$error');
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
      '花生': '配料中含花生相关成分，花生过敏人群建议直接避免。',
      '乳粉': '属于奶制品来源成分，对奶制品敏感人群需谨慎。',
      '奶油': '属于奶制品来源成分，对奶制品敏感人群需谨慎。',
      '乳清': '属于奶制品来源成分，对奶制品敏感人群需谨慎。',
      '牛奶': '配料中含牛奶相关成分，奶制品过敏或乳糖不耐人群需留意。',
      '鸡蛋': '配料中含蛋类相关成分，对蛋类过敏者需留意。',
      '蛋白': '配料中含蛋类相关成分，对蛋类过敏者需留意。',
      '大豆': '配料中含大豆相关成分，对豆类敏感人群需留意。',
      '黄豆': '配料中含黄豆相关成分，对豆类敏感人群需留意。',
      '芝麻': '配料中含芝麻相关成分，过敏体质需留意。',
      '小麦': '配料中含小麦相关成分，对麸质敏感人群需留意。',
      '麸质': '配料提示含麸质，对麸质敏感人群需留意。',
      '虾': '配料中含甲壳类相关成分，海鲜过敏者需谨慎。',
      '蟹': '配料中含甲壳类相关成分，海鲜过敏者需谨慎。',
      '鱼': '配料中含鱼类相关成分，对鱼类过敏者需谨慎。',
      '坚果': '配料中含坚果相关成分，过敏体质需重点留意。',
    };

    const cautionMap = <String, String>{
      '亚硝酸钠': '属于需要控制摄入频率的添加剂，加工肉制品中应重点留意。',
      '亚硝酸盐': '提示存在腌制类添加剂风险，建议减少高频摄入。',
      '苯并芘': '属于需要高度警惕的污染风险词，如果出现在标签或检测信息中建议尽量避免。',
      '氢化植物油': '可能关联反式脂肪风险，建议减少长期高频摄入。',
      '植脂末': '常见于高糖高脂加工食品，建议控制食用频率和份量。',
      '阿斯巴甜': '甜味剂类成分，特殊代谢人群需重点留意。',
      '安赛蜜': '甜味剂类成分，建议避免长期高频大量摄入。',
      '脱氢乙酸钠': '属于需要留意的防腐剂成分，高频食用人群可谨慎选择。',
      '合成着色剂': '如属于高频食用食品，建议优先选择添加剂更少的版本。',
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
        '识别到 ${caution.first.name} 等需要留意的成分，建议控制食用频率和份量。',
      if (ingredients.length > 12)
        '配料项较多，通常代表加工度较高，可优先选择配料更短、更简单的替代品。',
      '建议继续结合营养成分表里的钠、糖和反式脂肪信息一起判断。',
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
      ingredients: ingredients.isEmpty ? _extractIngredients(rawText) : ingredients,
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

    return value.map<LabelRiskItem?>((item) {
      if (item is Map<String, dynamic>) {
        final name = item['name']?.toString().trim() ?? '';
        final reason = item['reason']?.toString().trim() ?? '';
        if (name.isEmpty && reason.isEmpty) {
          return null;
        }
        return LabelRiskItem(
          name: name.isEmpty ? '需留意成分' : name,
          reason: reason.isEmpty ? '建议结合食用频率和个人情况综合判断。' : reason,
        );
      }

      final text = item.toString().trim();
      if (text.isEmpty) {
        return null;
      }
      return LabelRiskItem(
        name: text,
        reason: '建议结合食用频率和个人情况进一步判断。',
      );
    }).whereType<LabelRiskItem>().toList();
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

    return jsonDecode(content.substring(start, end + 1)) as Map<String, dynamic>;
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
    return text
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
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
