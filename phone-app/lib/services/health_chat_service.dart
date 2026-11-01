import 'dart:convert';
import 'dart:io';

import '../health_chat_models.dart';
import 'ai_provider_config.dart';

class HealthChatHttpResponse {
  const HealthChatHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

abstract interface class HealthChatTransport {
  Future<HealthChatHttpResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  });
}

class DefaultHealthChatTransport implements HealthChatTransport {
  const DefaultHealthChatTransport();

  @override
  Future<HealthChatHttpResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(uri);
      headers.forEach(request.headers.set);
      request.write(body);
      final response = await request.close();
      return HealthChatHttpResponse(
        statusCode: response.statusCode,
        body: await response.transform(utf8.decoder).join(),
      );
    } finally {
      client.close(force: true);
    }
  }
}

class HealthChatException implements Exception {
  const HealthChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HealthChatService {
  HealthChatService({
    HealthChatTransport? transport,
    String? apiKey,
    String? apiUrl,
    String? model,
  }) : _transport = transport ?? const DefaultHealthChatTransport(),
       _apiKey = apiKey ?? AiProviderConfig.apiKey,
       _apiUrl = apiUrl ?? AiProviderConfig.chatCompletionsUrl,
       _model = model ?? AiProviderConfig.textModel;

  final HealthChatTransport _transport;
  final String _apiKey;
  final String _apiUrl;
  final String _model;

  Future<HealthChatMessage> sendMessage({
    required String userText,
    required HealthChatContext context,
    required List<HealthChatMessage> history,
  }) async {
    final question = userText.trim();
    if (question.isEmpty) {
      throw const HealthChatException('请输入想咨询的饮食问题。');
    }
    if (_apiKey.trim().isEmpty) {
      throw const HealthChatException('尚未配置千问 API Key，暂时无法进行个性化分析。');
    }

    final recentHistory = history.length > 12
        ? history.sublist(history.length - 12)
        : history;
    final payload = <String, dynamic>{
      'model': _model,
      'temperature': 0.3,
      'max_tokens': 1200,
      'stream': false,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': '当前用户数据：${jsonEncode(context.toMap())}'},
        {
          'role': 'user',
          'content':
              '最近对话：${jsonEncode(recentHistory.map(_historyToMap).toList())}',
        },
        {'role': 'user', 'content': '用户问题：$question'},
      ],
    };

    final response = await _transport.post(
      uri: Uri.parse(_apiUrl),
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HealthChatException(
        '千问对话请求失败（HTTP ${response.statusCode}）。${_responseHint(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HealthChatException('千问返回的数据格式无法识别。');
    }
    final content = _extractContent(decoded);
    return _parseAssistantMessage(content);
  }

  static const _systemPrompt = '''你是用户的饮食健康顾问。
只根据用户提供的个人档案、饮食记录和最近对话回答，不要声称读取了未提供的数据。
明确区分记录事实、模型估计和建议；不要进行疾病诊断，不要擅自修改或新增饮食记录。
涉及过敏原时提醒用户核对包装信息；热量和营养值使用“估计”“建议”等表达。
请用简洁、温和、可执行的中文回答，只返回一个 JSON 对象，不要输出 Markdown 代码块。
JSON 必须包含 reply、metrics、actions 三个字段。
metrics 是数组，每项包含 label、value、status；status 只能是 good、attention、neutral。
actions 是数组，每项包含 title、detail、priority；priority 只能是 now、later。''';

  static Map<String, dynamic> _historyToMap(HealthChatMessage message) =>
      <String, dynamic>{'role': message.role.name, 'text': message.text};

  static String _extractContent(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = message['content'];
          if (content is String && content.trim().isNotEmpty)
            return content.trim();
          if (content is List) {
            final text = content
                .whereType<Map>()
                .map((item) => item['text']?.toString() ?? '')
                .where((item) => item.trim().isNotEmpty)
                .join('\n');
            if (text.isNotEmpty) return text.trim();
          }
        }
      }
    }
    throw const HealthChatException('千问没有返回有效的对话内容。');
  }

  static HealthChatMessage _parseAssistantMessage(String content) {
    final jsonText = _extractJson(content);
    if (jsonText == null) {
      return HealthChatMessage(
        role: HealthChatRole.assistant,
        text: content.trim(),
        createdAt: DateTime.now(),
      );
    }
    try {
      final map = jsonDecode(jsonText) as Map<String, dynamic>;
      final metrics = (map['metrics'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => HealthChatMetric.fromMap(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.label.isNotEmpty && item.value.isNotEmpty)
          .take(4)
          .toList(growable: false);
      final actions = (map['actions'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => HealthChatAction.fromMap(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.title.isNotEmpty && item.detail.isNotEmpty)
          .take(4)
          .toList(growable: false);
      return HealthChatMessage(
        role: HealthChatRole.assistant,
        text: map['reply']?.toString().trim().isNotEmpty == true
            ? map['reply'].toString().trim()
            : content.trim(),
        createdAt: DateTime.now(),
        metrics: metrics,
        actions: actions,
      );
    } catch (_) {
      return HealthChatMessage(
        role: HealthChatRole.assistant,
        text: content.trim(),
        createdAt: DateTime.now(),
      );
    }
  }

  static String? _extractJson(String content) {
    var normalized = content.trim();
    if (normalized.startsWith('```')) {
      normalized = normalized
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    final start = normalized.indexOf('{');
    final end = normalized.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return normalized.substring(start, end + 1);
  }

  static String _responseHint(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        return ' ${decoded['error']['message'] ?? ''}';
      }
    } catch (_) {
      // Keep the user-facing error short when the provider did not return JSON.
    }
    return '';
  }
}
