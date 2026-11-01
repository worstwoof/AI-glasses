import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/health_chat_models.dart';
import 'package:ai_glasses_nutrition_app/models.dart';
import 'package:ai_glasses_nutrition_app/services/health_chat_service.dart';

void main() {
  test('chat messages round trip through JSON', () {
    final message = HealthChatMessage(
      role: HealthChatRole.assistant,
      text: '今天蛋白质偏低。',
      createdAt: DateTime(2026, 9, 29, 12),
      metrics: const [
        HealthChatMetric(label: '蛋白质', value: '52 g', status: 'attention'),
      ],
      actions: const [
        HealthChatAction(title: '补充蛋白质', detail: '晚餐选择鱼肉。', priority: 'now'),
      ],
    );

    final restored = HealthChatMessage.fromMap(message.toMap());
    expect(restored.role, HealthChatRole.assistant);
    expect(restored.text, message.text);
    expect(restored.metrics.single.value, '52 g');
    expect(restored.actions.single.title, '补充蛋白质');
  });

  test('context includes today and only the latest 14 days', () {
    final now = DateTime(2026, 9, 29, 12);
    final meals = <MealRecord>[
      _meal('今天的午餐', now),
      _meal('14天内的早餐', now.subtract(const Duration(days: 13))),
      _meal('过期记录', now.subtract(const Duration(days: 15))),
    ];
    final context = HealthChatContext.fromState(
      profile: _profile,
      meals: meals,
      lastAnalysis: _analysis,
      now: now,
    );

    final recent = context.data['recentMeals'] as List<dynamic>;
    final today = context.data['today'] as Map<String, dynamic>;
    expect(recent, hasLength(2));
    expect((today['meals'] as List<dynamic>), hasLength(1));
    expect(today['eatenCalories'], 300);
    expect(context.data['profile'], isA<Map<String, dynamic>>());
  });

  test('service parses structured Qwen response and limits history', () async {
    final responseBody = jsonEncode(<String, dynamic>{
      'choices': [
        {
          'message': {
            'content': jsonEncode(<String, dynamic>{
              'reply': '建议补充蛋白质。',
              'metrics': [
                {'label': '蛋白质', 'value': '52 g', 'status': 'attention'},
              ],
              'actions': <Map<String, String>>[],
            }),
          },
        },
      ],
    });
    final transport = _FakeTransport(
      response: HealthChatHttpResponse(statusCode: 200, body: responseBody),
    );
    final service = HealthChatService(
      transport: transport,
      apiKey: 'test-key',
      apiUrl: 'https://example.test/v1/chat/completions',
      model: 'qwen-test',
    );
    final history = List<HealthChatMessage>.generate(
      20,
      (index) => HealthChatMessage(
        role: HealthChatRole.user,
        text: '问题 $index',
        createdAt: DateTime(2026, 9, 1).add(Duration(minutes: index)),
      ),
    );

    final answer = await service.sendMessage(
      userText: '我今天吃得怎么样？',
      context: HealthChatContext(data: const {'contextVersion': 1}),
      history: history,
    );

    expect(answer.text, '建议补充蛋白质。');
    expect(answer.metrics.single.label, '蛋白质');
    final payload = jsonDecode(transport.body!) as Map<String, dynamic>;
    expect(payload['model'], 'qwen-test');
    final messages = payload['messages'] as List<dynamic>;
    expect(messages, hasLength(4));
    final historyContent = (messages[2] as Map)['content'] as String;
    expect(
      (jsonDecode(historyContent.substring(historyContent.indexOf('：') + 1))
          as List),
      hasLength(12),
    );
    expect(
      transport.headers[HttpHeaders.authorizationHeader],
      'Bearer test-key',
    );
  });

  test(
    'service falls back to plain text when Qwen response is not JSON',
    () async {
      final service = HealthChatService(
        transport: _FakeTransport(
          response: const HealthChatHttpResponse(
            statusCode: 200,
            body: '{"choices":[{"message":{"content":"请优先保证三餐规律。"}}]}',
          ),
        ),
        apiKey: 'test-key',
      );
      final answer = await service.sendMessage(
        userText: '我该怎么做？',
        context: HealthChatContext(data: const {}),
        history: const [],
      );
      expect(answer.text, '请优先保证三餐规律。');
      expect(answer.metrics, isEmpty);
    },
  );

  test('service reports provider errors and missing API key', () async {
    final errorService = HealthChatService(
      transport: _FakeTransport(
        response: const HealthChatHttpResponse(
          statusCode: 401,
          body: '{"error":{"message":"invalid key"}}',
        ),
      ),
      apiKey: 'bad-key',
    );
    expect(
      () => errorService.sendMessage(
        userText: '测试',
        context: HealthChatContext(data: const {}),
        history: const [],
      ),
      throwsA(isA<HealthChatException>()),
    );

    final missingKeyService = HealthChatService(
      transport: _FakeTransport(response: null),
    );
    expect(
      () => missingKeyService.sendMessage(
        userText: '测试',
        context: HealthChatContext(data: const {}),
        history: const [],
      ),
      throwsA(isA<HealthChatException>()),
    );
  });
}

class _FakeTransport implements HealthChatTransport {
  _FakeTransport({required this.response});

  final HealthChatHttpResponse? response;
  Map<String, String> headers = const {};
  String? body;

  @override
  Future<HealthChatHttpResponse> post({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    this.headers = headers;
    this.body = body;
    if (response == null) {
      throw const HealthChatException('transport should not be called');
    }
    return response!;
  }
}

AppUserProfile get _profile => const AppUserProfile(
  name: '测试用户',
  deviceName: 'RV101',
  gender: '女',
  age: 20,
  heightCm: 165,
  weightKg: 55,
  goal: '减脂',
  preference: '清淡',
  dailyTargetCalories: 1800,
  allergies: ['花生'],
  conditions: [],
);

MealRecord _meal(String name, DateTime eatenAt) => MealRecord(
  mealType: '午餐',
  name: name,
  calories: 300,
  carbs: 20,
  protein: 12,
  fat: 10,
  confidence: 0.9,
  eatenAt: eatenAt,
  accent: Colors.green,
  icon: Icons.rice_bowl,
);

const _analysis = AnalysisResult(
  foodName: '测试餐食',
  suggestedMealType: '午餐',
  calories: 300,
  carbs: 20,
  protein: 12,
  fat: 10,
  fiber: 3,
  confidence: 0.9,
  recommendations: ['建议均衡饮食'],
  accent: Colors.green,
  icon: Icons.rice_bowl,
);
