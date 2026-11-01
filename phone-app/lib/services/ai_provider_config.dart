class AiProviderConfig {
  AiProviderConfig._();

  static const String apiKey = String.fromEnvironment('AI_API_KEY');
  static const String apiUrl = String.fromEnvironment(
    'AI_API_URL',
    defaultValue:
        'https://ws-xx2967i3d388t86v.cn-beijing.maas.aliyuncs.com/compatible-mode/v1/chat/completions',
  );
  static const String visionModel = String.fromEnvironment(
    'AI_VISION_MODEL',
    defaultValue: 'qwen3.8-flash',
  );
  static const String textModel = String.fromEnvironment(
    'AI_TEXT_MODEL',
    defaultValue: 'qwen3.8-flash',
  );
  static const String ocrModel = String.fromEnvironment(
    'AI_OCR_MODEL',
    defaultValue: 'qwen3.8-flash',
  );

  static bool get isConfigured => apiKey.trim().isNotEmpty;

  static String get chatCompletionsUrl {
    final value = apiUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (value.endsWith('/chat/completions')) {
      return value;
    }
    return '$value/chat/completions';
  }
}
