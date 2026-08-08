import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../demo_data.dart';
import '../models.dart';

class VivoFoodVisionServiceV2 {
  VivoFoodVisionServiceV2._();

  static const String apiKey = String.fromEnvironment('AI_API_KEY');
  static const String apiUrl = String.fromEnvironment(
    'AI_API_URL',
    defaultValue: 'https://api-ai.vivo.com.cn/v1/chat/completions',
  );
  static const String model = String.fromEnvironment(
    'AI_VISION_MODEL',
    defaultValue: 'Doubao-Seed-2.0-mini',
  );

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
    final uri = Uri.parse(apiUrl).replace(
      queryParameters: <String, String>{'request_id': requestId},
    );

    final payload = <String, dynamic>{
      'model': model,
      'temperature': 0.2,
      'max_tokens': 1400,
      'stream': false,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a food nutrition analyzer. Return JSON only. '
              'This app is for Chinese meals, shared dishes, and hotpot. '
              'If the image contains a boiling pot, soup base, many plates of meat or vegetables, identify it as hotpot rather than a single ingredient. '
              'Return exactly one JSON object with keys: food_name, meal_type, calories, carbs, protein, fat, fiber, confidence, recommendations. '
              'meal_type must be 早餐, 午餐, 晚餐, or 加餐. recommendations must be a Chinese array with 2 to 3 items.',
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  'Analyze the full visible meal, not only one ingredient. '
                  'If it looks like hotpot, estimate the whole meal as hotpot and include soup base or sauce impact if visible. '
                  'User goal: ${profile.goal}; preference: ${profile.preference}; allergies: ${profile.allergies.join(", ")}; conditions: ${profile.conditions.join(", ")}. '
                  'Return JSON only.',
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${image.mimeType ?? "image/jpeg"};base64,$base64Image',
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
        throw VivoFoodVisionException(
          'vivo AI 调用失败（$requestId）：HTTP ${response.statusCode}，${_clip(responseBody)}',
        );
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final apiError = decoded['error'];
      if (apiError is Map<String, dynamic>) {
        final code = apiError['code']?.toString() ?? '';
        final message = apiError['message']?.toString() ?? '未知错误';
        if (code == '1010') {
          throw VivoFoodVisionException(
            '当前 vivo 模型不支持图片输入。请检查运行配置里的 AI_VISION_MODEL；'
            '如果你填的是文本模型，请切换到支持图片理解的模型。'
            '原始信息：$message',
          );
        }
        throw VivoFoodVisionException(
          'vivo AI 返回错误（$code）：$message',
        );
      }
      final content = _extractContent(decoded, responseBody);
      return _parseResult(content, responseBody);
    } catch (e) {
      if (e is VivoFoodVisionException) rethrow;
      throw VivoFoodVisionException('识图请求失败：$e');
    } finally {
      client.close(force: true);
    }
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
            return content;
          }
          if (content is List) {
            final buffer = StringBuffer();
            for (final item in content) {
              if (item is Map<String, dynamic>) {
                final text = item['text'];
                if (text is String && text.trim().isNotEmpty) {
                  buffer.write(text);
                }
              }
            }
            if (buffer.isNotEmpty) {
              return buffer.toString();
            }
          }
          final reasoning = message['reasoning_content'];
          if (reasoning is String && reasoning.trim().isNotEmpty) {
            return reasoning;
          }
        }
      }
    }

    final msg = decoded['msg'];
    if (msg is String && msg.trim().isNotEmpty) {
      return msg;
    }

    throw VivoFoodVisionException(
      'AI 返回内容为空。原始响应：${_clip(rawBody)}',
    );
  }

  static AnalysisResult _parseResult(String content, String rawBody) {
    try {
      final parsed = _extractJsonObject(content);
      return _fromMap(parsed);
    } catch (_) {
      return _fallbackFromText(content.isNotEmpty ? content : rawBody);
    }
  }

  static Map<String, dynamic> _extractJsonObject(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const VivoFoodVisionException('响应中没有可解析的 JSON。');
    }
    return jsonDecode(content.substring(start, end + 1)) as Map<String, dynamic>;
  }

  static AnalysisResult _fromMap(Map<String, dynamic> map) {
    final recommendations = (map['recommendations'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();

    final foodName = map['food_name']?.toString().trim();
    final normalizedFood = (foodName == null || foodName.isEmpty) ? '未知餐食' : foodName;

    return AnalysisResult(
      foodName: normalizedFood,
      suggestedMealType: _normalizeMealType(map['meal_type']?.toString()),
      calories: _toInt(map['calories'], 420),
      carbs: _toDouble(map['carbs'], 28),
      protein: _toDouble(map['protein'], 22),
      fat: _toDouble(map['fat'], 18),
      fiber: _toDouble(map['fiber'], 5),
      confidence: (_toDouble(map['confidence'], 0.78).clamp(0.0, 0.99) as num)
          .toDouble(),
      recommendations: recommendations.isEmpty
          ? const ['识别已完成，建议结合份量和蘸料进一步校正营养值。']
          : recommendations.take(3).toList(),
      accent: _pickAccent(normalizedFood),
      icon: _pickIcon(normalizedFood),
    );
  }

  static AnalysisResult _fallbackFromText(String content) {
    final lower = content.toLowerCase();
    final looksLikeHotpot =
        lower.contains('hotpot') || content.contains('火锅') || content.contains('锅底');
    if (looksLikeHotpot) {
      return const AnalysisResult(
        foodName: '火锅',
        suggestedMealType: '晚餐',
        calories: 680,
        carbs: 36,
        protein: 34,
        fat: 40,
        fiber: 8,
        confidence: 0.68,
        recommendations: [
          '火锅整体油脂和钠通常偏高，建议控制蘸料和汤底摄入。',
          '优先多选蔬菜、菌菇、豆制品和瘦肉，少选肥牛和丸类。',
          '如果今天吃火锅，后续一餐建议清淡并多补水。',
        ],
        accent: Color(0xFFF07A62),
        icon: Icons.soup_kitchen_rounded,
      );
    }

    return AnalysisResult(
      foodName: '识别结果待确认',
      suggestedMealType: '加餐',
      calories: 320,
      carbs: 22,
      protein: 18,
      fat: 14,
      fiber: 4,
      confidence: 0.45,
      recommendations: [
        '模型没有稳定返回结构化结果，建议换一个更清晰角度再拍一次。',
        '尽量让整份餐食都进入画面，不只拍到单个食材。',
        '如果是火锅或多人共享菜，建议把锅底和主要食材一起拍进去。',
      ],
      accent: DemoData.analysisCandidates.first.accent,
      icon: DemoData.analysisCandidates.first.icon,
    );
  }

  static String _normalizeMealType(String? value) {
    switch (value) {
      case '早餐':
      case '午餐':
      case '晚餐':
      case '加餐':
        return value!;
      default:
        return '加餐';
    }
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Color _pickAccent(String foodName) {
    if (foodName.contains('火锅')) return const Color(0xFFF07A62);
    if (foodName.contains('鱼')) return const Color(0xFF7AF1A8);
    if (foodName.contains('牛')) return const Color(0xFF6CB8FF);
    return DemoData.analysisCandidates.first.accent;
  }

  static IconData _pickIcon(String foodName) {
    if (foodName.contains('火锅')) return Icons.soup_kitchen_rounded;
    if (foodName.contains('鱼')) return Icons.dinner_dining_rounded;
    if (foodName.contains('饭') || foodName.contains('碗')) {
      return Icons.rice_bowl_rounded;
    }
    return DemoData.analysisCandidates.first.icon;
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
    if (normalized.length <= 240) return normalized;
    return '${normalized.substring(0, 240)}...';
  }

  static AnalysisResult _mockFromImage(XFile image) {
    final seed = image.path.codeUnits.fold<int>(0, (sum, item) => sum + item);
    return DemoData.analysisCandidates[seed % DemoData.analysisCandidates.length];
  }
}

class VivoFoodVisionException implements Exception {
  const VivoFoodVisionException(this.message);

  final String message;

  @override
  String toString() => message;
}
