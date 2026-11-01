import 'package:flutter/material.dart';

import 'health_chat_models.dart';
import 'models.dart';
import 'services/health_chat_service.dart';
import 'services/local_storage_service.dart';
import 'ui_kit.dart';

class HealthChatPage extends StatefulWidget {
  const HealthChatPage({
    super.key,
    required this.profile,
    required this.isConnected,
    required this.meals,
    required this.macroSummary,
    required this.eatenCalories,
    required this.remainingCalories,
    required this.lastAnalysis,
    required this.aiConfigured,
    this.service,
  });

  final AppUserProfile profile;
  final bool isConnected;
  final List<MealRecord> meals;
  final MacroSummary macroSummary;
  final int eatenCalories;
  final int remainingCalories;
  final AnalysisResult lastAnalysis;
  final bool aiConfigured;
  final HealthChatService? service;

  @override
  State<HealthChatPage> createState() => _HealthChatPageState();
}

class _HealthChatPageState extends State<HealthChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late final HealthChatService _service;
  List<HealthChatMessage> _messages = <HealthChatMessage>[];
  bool _loadingHistory = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? HealthChatService();
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant HealthChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final saved = await LocalStorageService.loadHealthChatMessages();
    if (!mounted) return;
    setState(() {
      _messages = saved.isEmpty ? [_welcomeMessage] : saved;
      _loadingHistory = false;
    });
    _scrollToBottom();
  }

  HealthChatMessage get _welcomeMessage => HealthChatMessage(
    role: HealthChatRole.assistant,
    text: '我会结合你的个人档案、今天的饮食和近 14 天记录，帮你看清饮食变化，并给出下一步建议。你可以直接问我。',
    createdAt: DateTime.now(),
    metrics: const [
      HealthChatMetric(label: '数据范围', value: '今日 · 14天', status: 'neutral'),
    ],
  );

  HealthChatContext get _context => HealthChatContext.fromState(
    profile: widget.profile,
    meals: widget.meals,
    lastAnalysis: widget.lastAnalysis,
  );

  List<String> get _quickPrompts {
    if (widget.meals.isEmpty) {
      return const [
        '我应该怎样开始记录饮食？',
        '我的每日热量目标合理吗？',
        '如何拍出更适合分析的食物照片？',
        '我应该重点关注哪些营养素？',
      ];
    }
    return const [
      '我今天吃得健康吗？',
      '我最近蛋白质是否摄入不足？',
      '按照我的目标，晚餐怎么调整？',
      '我最近哪几天热量超标了？',
    ];
  }

  Future<void> _send([String? preset]) async {
    if (_isSending) return;
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty) return;
    _inputController.clear();
    final userMessage = HealthChatMessage(
      role: HealthChatRole.user,
      text: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages = [..._messages, userMessage];
      _isSending = true;
    });
    await LocalStorageService.saveHealthChatMessages(_messages);
    _scrollToBottom();

    try {
      final answer = await _service.sendMessage(
        userText: text,
        context: _context,
        history: _messages,
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, answer];
        _isSending = false;
      });
    } catch (error) {
      if (!mounted) return;
      final errorMessage = HealthChatMessage(
        role: HealthChatRole.assistant,
        text: error.toString().replaceFirst('HealthChatException: ', ''),
        createdAt: DateTime.now(),
      );
      setState(() {
        _messages = [..._messages, errorMessage];
        _isSending = false;
      });
    }
    await LocalStorageService.saveHealthChatMessages(_messages);
    _scrollToBottom();
  }

  Future<void> _clearChat() async {
    await LocalStorageService.clearHealthChatMessages();
    if (!mounted) return;
    setState(() {
      _messages = [_welcomeMessage];
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '饮食顾问',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '把饮食记录变成下一步行动',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: appMutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '清空对话',
                onPressed: _isSending ? null : _clearChat,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
              _StatusPill(
                label: widget.aiConfigured ? 'AI 在线' : '未配置',
                color: widget.aiConfigured
                    ? scheme.primary
                    : const Color(0xFFE39B64),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: _ContextStrip(
            profile: widget.profile,
            mealCount: widget.meals.length,
            isConnected: widget.isConnected,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingHistory
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                  itemCount: _messages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length)
                      return const _TypingIndicator();
                    return _ChatBubble(message: _messages[index]);
                  },
                ),
        ),
        if (!_isSending)
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ActionChip(
                label: Text(_quickPrompts[index]),
                onPressed: () => _send(_quickPrompts[index]),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: !_isSending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: '输入你的饮食问题……',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isSending ? null : _send,
                icon: const Icon(Icons.arrow_upward_rounded),
                tooltip: '发送',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.18)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _ContextStrip extends StatelessWidget {
  const _ContextStrip({
    required this.profile,
    required this.mealCount,
    required this.isConnected,
  });

  final AppUserProfile profile;
  final int mealCount;
  final bool isConnected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.07),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
      ),
    ),
    child: Row(
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          size: 17,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '已读取：${profile.goal} · 今日 $mealCount 条记录 · 近14天饮食',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Icon(
          isConnected
              ? Icons.check_circle_outline_rounded
              : Icons.cloud_off_rounded,
          size: 17,
          color: isConnected
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFFE57E67),
        ),
      ],
    ),
  );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final HealthChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == HealthChatRole.user;
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = isUser
        ? scheme.primary
        : (isLightTheme(context)
              ? Colors.white.withOpacity(0.88)
              : Colors.white.withOpacity(0.06));
    final textColor = isUser
        ? scheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
          border: Border.all(
            color: isUser ? Colors.transparent : appSoftBorder(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: textColor),
            ),
            if (message.metrics.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.metrics
                    .map((metric) => _MetricTag(metric: metric))
                    .toList(),
              ),
            ],
            if (message.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...message.actions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(color: textColor),
                            children: [
                              TextSpan(
                                text: '${action.title}：',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(text: action.detail),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricTag extends StatelessWidget {
  const _MetricTag({required this.metric});

  final HealthChatMetric metric;

  @override
  Widget build(BuildContext context) {
    final color = switch (metric.status) {
      'good' => const Color(0xFF22B892),
      'attention' => const Color(0xFFE39B64),
      _ => Theme.of(context).colorScheme.secondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        '${metric.label}  ${metric.value}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        '正在查看你的饮食记录……',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: appMutedText(context)),
      ),
    ),
  );
}
