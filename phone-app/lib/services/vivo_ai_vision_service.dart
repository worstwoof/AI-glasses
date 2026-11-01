import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';

import '../demo_data.dart';
import '../models.dart';
import 'ai_provider_config.dart';

class VivoAiVisionService {
  VivoAiVisionService._();

  static const String apiKey = AiProviderConfig.apiKey;
  static String get apiUrl => AiProviderConfig.chatCompletionsUrl;
  static const String model = AiProviderConfig.visionModel;

  static bool get isConfigured => apiKey.trim().isNotEmpty;

  static Future<AnalysisResult> analyzeImage({
    required XFile image,
    required AppUserProfile profile,
  }) async {
    if (!isConfigured) {
      return _mockFromImage(image);
    }

    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final requestId = _requestId();
    final uri = Uri.parse(apiUrl);

    final payload = <String, dynamic>{
      'model': model,
      'temperature': 0.2,
      'max_tokens': 1200,
      'stream': false,
      'messages': [
        {
          'role': 'system',
          'content':
              '你是一名食品营养分析助手。请根据图片判断最可能的食物，并且只返回 JSON。'
              'JSON 必须包含这些字段：food_name, meal_type, calories, carbs, protein, fat, fiber, confidence, recommendations。'
              'recommendations 必须是中文字符串数组，最多 3 条。'
              'meal_type 只能是 早餐、午餐、晚餐、加餐 之一。'
              '如果无法完全确认，请给出最可能结果和较低 confidence。',
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  '请识别这张餐食图片。用户目标：${profile.goal}；'
                  '饮食偏好：${profile.preference}；'
                  '过敏原：${profile.allergies.join("、")}；'
                  '疾病史：${profile.conditions.join("、")}。'
                  '请估算热量、碳水、蛋白质、脂肪、纤维，并给出 2 到 3 条饮食建议。',
            },
            {
              'type': 'image_url',
              'image_url': {
                'url':
                    'data:${image.mimeType ?? "image/jpeg"};base64,$base64Image',
              },
            },
          ],
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
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VivoAiVisionException(
          '千问视觉调用失败（$requestId）：HTTP ${response.statusCode}，$responseBody',
        );
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final content = _extractContent(decoded);
      final parsed = _extractJsonObject(content);
      return _fromMap(parsed);
    } finally {
      client.close(force: true);
    }
  }

  static String _extractContent(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = message['content'];
          if (content is String) {
            return content;
          }
        }
      }
    }
    throw const VivoAiVisionException('AI 返回内容为空，无法解析识图结果。');
  }

  static Map<String, dynamic> _extractJsonObject(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw VivoAiVisionException('AI 返回的内容不是合法 JSON：$content');
    }
    return jsonDecode(content.substring(start, end + 1))
        as Map<String, dynamic>;
  }

  static AnalysisResult _fromMap(Map<String, dynamic> map) {
    final recommendations =
        (map['recommendations'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();

    return AnalysisResult(
      foodName: map['food_name']?.toString() ?? '未知餐食',
      suggestedMealType: map['meal_type']?.toString() ?? '加餐',
      calories: _toInt(map['calories'], 260),
      carbs: _toDouble(map['carbs'], 18),
      protein: _toDouble(map['protein'], 16),
      fat: _toDouble(map['fat'], 9),
      fiber: _toDouble(map['fiber'], 4),
      confidence: (_toDouble(map['confidence'], 0.82).clamp(0.0, 0.99) as num)
          .toDouble(),
      recommendations: recommendations.isEmpty
          ? const ['识别已完成，建议结合份量和烹饪方式进一步校正营养值。']
          : recommendations.take(3).toList(),
      accent: DemoData.analysisCandidates.first.accent,
      icon: DemoData.analysisCandidates.first.icon,
    );
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? fallback;
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

  static AnalysisResult _mockFromImage(XFile image) {
    final seed = image.path.codeUnits.fold<int>(0, (sum, item) => sum + item);
    return DemoData.analysisCandidates[seed %
        DemoData.analysisCandidates.length];
  }
}

class VivoAiVisionException implements Exception {
  const VivoAiVisionException(this.message);

  final String message;

  @override
  String toString() => message;
}
