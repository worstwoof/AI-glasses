import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_widgets.dart';
import 'demo_data.dart';
import 'helpers.dart';
import 'models.dart';
import 'recognition_page_clean.dart';
import 'services/vivo_food_vision_service_v3.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  bool _isConnected = true;
  bool _isSyncing = false;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  final AppUserProfile _profile = DemoData.profile;
  final List<MealRecord> _meals = List<MealRecord>.from(DemoData.initialMeals);
  AnalysisResult _lastAnalysis = DemoData.analysisCandidates.first;

  int get _eatenCalories => _meals.fold<int>(0, (sum, meal) => sum + meal.calories);

  int get _remainingCalories =>
      math.max(_profile.dailyTargetCalories - _eatenCalories, 0);

  MacroSummary get _macroSummary {
    double carbs = 0;
    double protein = 0;
    double fat = 0;
    for (final meal in _meals) {
      carbs += meal.carbs;
      protein += meal.protein;
      fat += meal.fat;
    }
    return MacroSummary(carbs: carbs, protein: protein, fat: fat);
  }

  String get _syncText {
    if (_isSyncing) {
      return '正在同步 AI 数据...';
    }
    return '已同步至今天 ${formatTime(DateTime.now())}';
  }

  Future<void> _openRecognitionPage() async {
    final result = await Navigator.of(context).push<AnalysisResult>(
      MaterialPageRoute(
        builder: (_) => RecognitionPageClean(
          isConnected: _isConnected,
          profile: _profile,
          initialResult: _lastAnalysis,
          aiConfigured: VivoFoodVisionServiceV3.isConfigured,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _lastAnalysis = result;
      _meals.insert(
        0,
        MealRecord(
          mealType: result.suggestedMealType,
          name: result.foodName,
          calories: result.calories,
          carbs: result.carbs,
          protein: result.protein,
          fat: result.fat,
          confidence: result.confidence,
          eatenAt: DateTime.now(),
          accent: result.accent,
          icon: result.icon,
        ),
      );
      _currentIndex = 0;
    });
  }

  Future<void> _toggleConnection() async {
    setState(() {
      _isConnected = !_isConnected;
    });
  }

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    setState(() {
      _isSyncing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pages = <Widget>[
      HomePage(
        isConnected: _isConnected,
        profile: _profile,
        meals: _meals,
        remainingCalories: _remainingCalories,
        eatenCalories: _eatenCalories,
        macroSummary: _macroSummary,
        syncText: _syncText,
      ),
      CalendarPage(
        focusedMonth: _focusedMonth,
        selectedDate: _selectedDate,
        meals: _meals,
        onPreviousMonth: () {
          setState(() {
            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
          });
        },
        onNextMonth: () {
          setState(() {
            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
          });
        },
        onSelectDate: (date) {
          setState(() {
            _selectedDate = date;
          });
        },
      ),
      InsightPage(
        profile: _profile,
        isConnected: _isConnected,
        macroSummary: _macroSummary,
        eatenCalories: _eatenCalories,
        remainingCalories: _remainingCalories,
        lastAnalysis: _lastAnalysis,
        aiConfigured: VivoFoodVisionServiceV3.isConfigured,
      ),
      ProfilePage(
        profile: _profile,
        isConnected: _isConnected,
        syncText: _syncText,
        aiConfigured: VivoFoodVisionServiceV3.isConfigured,
        isLightMode: widget.themeMode != ThemeMode.dark,
        onToggleConnection: _toggleConnection,
        onSyncNow: _syncNow,
        onThemeChanged: (isLight) {
          widget.onThemeModeChanged(isLight ? ThemeMode.light : ThemeMode.dark);
        },
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: AppBackdrop(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(0.32),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _openRecognitionPage,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: const Icon(Icons.camera_alt_rounded),
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: elevatedSurface(context),
          indicatorColor: scheme.primary.withOpacity(0.16),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          height: 76,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_rounded), label: '首页'),
            NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: '日历'),
            NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), label: '分析'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: '档案'),
          ],
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.isConnected,
    required this.profile,
    required this.meals,
    required this.remainingCalories,
    required this.eatenCalories,
    required this.macroSummary,
    required this.syncText,
  });

  final bool isConnected;
  final AppUserProfile profile;
  final List<MealRecord> meals;
  final int remainingCalories;
  final int eatenCalories;
  final MacroSummary macroSummary;
  final String syncText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final latestMeals = meals.take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: StatusChip(
                icon: isConnected ? Icons.wifi_tethering_rounded : Icons.link_off,
                label: isConnected ? '已连接 AI 眼镜' : 'AI 眼镜未连接',
                color: isConnected ? scheme.primary : const Color(0xFFFF9E7D),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 22,
              backgroundColor: scheme.primary.withOpacity(0.12),
              child: Icon(
                Icons.notifications_none_rounded,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今日饮食',
                style: theme.textTheme.titleMedium?.copyWith(color: mutedText(context)),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.headlineLarge?.copyWith(color: scheme.onSurface),
                  children: [
                    TextSpan(text: '$remainingCalories'),
                    TextSpan(
                      text: ' kcal',
                      style: theme.textTheme.titleLarge?.copyWith(color: mutedText(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '建议目标 ${profile.dailyTargetCalories} kcal',
                style: theme.textTheme.bodyMedium?.copyWith(color: mutedText(context)),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: MacroLegend(summary: macroSummary)),
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: MacroDonutChart(
                      carbs: macroSummary.carbs,
                      protein: macroSummary.protein,
                      fat: macroSummary.fat,
                      centerLabel: '$eatenCalories\n已摄入',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: '饮食记录',
                trailing: Text(
                  syncText,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary),
                ),
              ),
              const SizedBox(height: 14),
              for (final meal in latestMeals) ...[
                MealTile(meal: meal),
                if (meal != latestMeals.last) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(18),
          accent: scheme.primary,
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.restaurant_menu_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI 智能推荐', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '中午已经摄入较多脂肪，晚餐建议清蒸鱼、时蔬和糙米饭，补足蛋白质并保持热量余量。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CalendarPage extends StatelessWidget {
  const CalendarPage({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.meals,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final List<MealRecord> meals;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final mealsOfDay = meals.where((meal) => sameDay(meal.eatenAt, selectedDate)).toList()
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    final totalCalories = mealsOfDay.fold<int>(0, (sum, meal) => sum + meal.calories);
    final totalCarbs = mealsOfDay.fold<double>(0, (sum, meal) => sum + meal.carbs).round();
    final totalProtein =
        mealsOfDay.fold<double>(0, (sum, meal) => sum + meal.protein).round();
    final totalFat = mealsOfDay.fold<double>(0, (sum, meal) => sum + meal.fat).round();
    final days = buildCalendarDays(focusedMonth);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
      children: [
        Center(child: Text('日历', style: Theme.of(context).textTheme.headlineMedium)),
        const SizedBox(height: 18),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onPreviousMonth,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${focusedMonth.year}年${focusedMonth.month}月',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: onNextMonth,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Expanded(child: Center(child: Text('日'))),
                  Expanded(child: Center(child: Text('一'))),
                  Expanded(child: Center(child: Text('二'))),
                  Expanded(child: Center(child: Text('三'))),
                  Expanded(child: Center(child: Text('四'))),
                  Expanded(child: Center(child: Text('五'))),
                  Expanded(child: Center(child: Text('六'))),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final day = days[index];
                  final isCurrentMonth = day.month == focusedMonth.month;
                  final isSelected = sameDay(day, selectedDate);
                  final hasMeal = meals.any((meal) => sameDay(meal.eatenAt, day));
                  final scheme = Theme.of(context).colorScheme;
                  return GestureDetector(
                    onTap: () => onSelectDate(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? scheme.primary.withOpacity(0.18)
                            : hasMeal
                                ? scheme.primary.withOpacity(0.08)
                                : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? scheme.primary : softBorder(context),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isCurrentMonth
                                ? Theme.of(context).colorScheme.onSurface
                                : mutedText(context),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${selectedDate.month}月${selectedDate.day}日总结',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: MetricBlock(label: '总摄入', value: '$totalCalories kcal')),
                  Expanded(child: MetricBlock(label: '碳水', value: '${totalCarbs}g')),
                  Expanded(child: MetricBlock(label: '蛋白质', value: '${totalProtein}g')),
                  Expanded(child: MetricBlock(label: '脂肪', value: '${totalFat}g')),
                ],
              ),
              const SizedBox(height: 16),
              for (final meal in mealsOfDay) ...[
                TimelineMealTile(meal: meal),
                if (meal != mealsOfDay.last) const SizedBox(height: 10),
              ],
              if (mealsOfDay.isEmpty)
                Text(
                  '这一天还没有饮食记录，可以点击中间相机按钮进行拍照识别。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: mutedText(context),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class InsightPage extends StatelessWidget {
  const InsightPage({
    super.key,
    required this.profile,
    required this.isConnected,
    required this.macroSummary,
    required this.eatenCalories,
    required this.remainingCalories,
    required this.lastAnalysis,
    required this.aiConfigured,
  });

  final AppUserProfile profile;
  final bool isConnected;
  final MacroSummary macroSummary;
  final int eatenCalories;
  final int remainingCalories;
  final AnalysisResult lastAnalysis;
  final bool aiConfigured;

  @override
  Widget build(BuildContext context) {
    final weeklyCalories = <double>[
      1320,
      1480,
      1540,
      1610,
      1390,
      1720,
      eatenCalories.toDouble(),
    ];
    final peak = weeklyCalories.reduce(math.max);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
      children: [
        Center(child: Text('健康分析', style: Theme.of(context).textTheme.headlineMedium)),
        const SizedBox(height: 18),
        GlassCard(
          padding: const EdgeInsets.all(18),
          accent: Theme.of(context).colorScheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '闭环状态'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: MetricBlock(
                      label: '眼镜连接',
                      value: isConnected ? '在线' : '离线',
                      highlight: isConnected,
                    ),
                  ),
                  Expanded(
                    child: MetricBlock(
                      label: '今日热量',
                      value: '$eatenCalories kcal',
                      highlight: true,
                    ),
                  ),
                  Expanded(
                    child: MetricBlock(
                      label: '识图接口',
                      value: aiConfigured ? '已配置' : '未配置',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '近 7 日热量趋势'),
              const SizedBox(height: 18),
              SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(weeklyCalories.length, (index) {
                    final value = weeklyCalories[index];
                    final ratio = value / peak;
                    final label = ['一', '二', '三', '四', '五', '六', '今'][index];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              value.round().toString(),
                              style: TextStyle(fontSize: 11, color: mutedText(context)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 110 * ratio.clamp(0.2, 1.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xFF5FF4C8),
                                    Color(0x665FF4C8),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(label),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '最近识别结果'),
              const SizedBox(height: 14),
              MealInsightCard(result: lastAnalysis),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SuggestionChip(label: '目标：${profile.goal}'),
                  SuggestionChip(label: '偏好：${profile.preference}'),
                  SuggestionChip(label: '剩余：$remainingCalories kcal'),
                  SuggestionChip(label: '过敏原：${profile.allergies.join('、')}'),
                ],
              ),
              const SizedBox(height: 16),
              ...lastAnalysis.recommendations.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.isConnected,
    required this.syncText,
    required this.aiConfigured,
    required this.isLightMode,
    required this.onToggleConnection,
    required this.onSyncNow,
    required this.onThemeChanged,
  });

  final AppUserProfile profile;
  final bool isConnected;
  final String syncText;
  final bool aiConfigured;
  final bool isLightMode;
  final Future<void> Function() onToggleConnection;
  final Future<void> Function() onSyncNow;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
      children: [
        Center(child: Text('档案', style: Theme.of(context).textTheme.headlineMedium)),
        const SizedBox(height: 18),
        GlassCard(
          padding: const EdgeInsets.all(18),
          accent: scheme.primary,
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF9CF7DA), Color(0xFF3B7E68)],
                  ),
                ),
                child: Icon(Icons.person, size: 34, color: scheme.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '连接设备：${profile.deviceName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isConnected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_disabled_rounded,
                color: isConnected ? scheme.primary : const Color(0xFFFFA384),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: '个人信息',
          lines: [
            '性别：${profile.gender}',
            '年龄：${profile.age} 岁',
            '身高：${profile.heightCm} cm',
            '体重：${profile.weightKg} kg',
          ],
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: '健康状态',
          lines: [
            '疾病史：${profile.conditions.join('、')}',
            '过敏原：${profile.allergies.join('、')}',
            '目标：${profile.goal}',
          ],
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: '饮食偏好',
          lines: [
            '饮食偏好：${profile.preference}',
            '提醒策略：高盐高糖主动预警',
            '建议模式：识别后给出替代方案',
          ],
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: 'AI 系统',
          lines: [
            'AI 健康检测：已启用',
            'AI 识图接口：${aiConfigured ? "已配置" : "未配置"}',
            '闭环建议：已启用',
            syncText,
          ],
          child: SwitchListTile(
            value: isLightMode,
            contentPadding: EdgeInsets.zero,
            title: const Text('浅色模式'),
            subtitle: const Text('默认已启用，也可以随时切换深色模式'),
            onChanged: onThemeChanged,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onSyncNow,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('同步数据'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onToggleConnection,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF8B74),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Color(0x66FF9B86)),
                ),
                child: Text(isConnected ? '断开眼镜' : '重新连接'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class RecognitionPage extends StatefulWidget {
  const RecognitionPage({
    super.key,
    required this.isConnected,
    required this.profile,
    required this.initialResult,
    required this.aiConfigured,
  });

  final bool isConnected;
  final AppUserProfile profile;
  final AnalysisResult initialResult;
  final bool aiConfigured;

  @override
  State<RecognitionPage> createState() => _RecognitionPageState();
}

class _RecognitionPageState extends State<RecognitionPage> {
  final ImagePicker _picker = ImagePicker();
  ScanStage _stage = ScanStage.idle;
  late AnalysisResult _result;
  XFile? _selectedImage;
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null) {
        return;
      }
      setState(() {
        _selectedImage = image;
        _error = null;
        _stage = ScanStage.capturing;
      });
    } catch (e) {
      setState(() {
        _error = '获取图片失败：$e';
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先拍照或从相册选择一张图片')),
      );
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _stage = ScanStage.recognizing;
    });

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) {
      return;
    }

    setState(() {
      _stage = ScanStage.analyzing;
    });

    try {
      final result = await VivoFoodVisionServiceV3.analyzeImage(
        image: _selectedImage!,
        profile: widget.profile,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _stage = ScanStage.completed;
        _running = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _running = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stageLabels = <ScanStage, String>{
      ScanStage.idle: '准备开始识别',
      ScanStage.capturing: '图片已就绪，等待识别',
      ScanStage.recognizing: '正在识别菜品与份量...',
      ScanStage.analyzing: '正在估算营养值并生成建议...',
      ScanStage.completed: '识别完成，可以写入今日记录',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('AI 拍照识别')),
      body: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              accent: widget.isConnected ? scheme.primary : const Color(0xFFFFA384),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: widget.isConnected
                          ? scheme.primary.withOpacity(0.12)
                          : const Color(0x22FF9A82),
                    ),
                    child: Icon(
                      widget.isConnected
                          ? Icons.wifi_tethering_rounded
                          : Icons.link_off_rounded,
                      color: widget.isConnected ? scheme.primary : const Color(0xFFFFA384),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isConnected ? '已连接 AI 眼镜' : '当前未连接 AI 眼镜',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stageLabels[_stage]!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: '识别流程',
                    trailing: StatusChip(
                      icon: widget.aiConfigured
                          ? Icons.cloud_done_rounded
                          : Icons.science_rounded,
                      label: widget.aiConfigured ? '已配置 AI API' : '当前为演示识别',
                      color: scheme.primary,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FlowBadge(label: '1. 拍照/选图', active: true),
                      FlowBadge(label: '2. 菜品识别', active: true),
                      FlowBadge(label: '3. 营养分析', active: true),
                      FlowBadge(label: '4. 建议输出', active: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 230,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: softBorder(context)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: lightMode(context)
                            ? const [
                                Color(0xFFF6FFFC),
                                Color(0xFFDFF7F0),
                              ]
                            : const [
                                Color(0xFF0A1E22),
                                Color(0xFF14343B),
                              ],
                      ),
                    ),
                    child: _selectedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                size: 52,
                                color: scheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '拍一张餐食照片，或从相册选择一张图',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('拍照'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('相册'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _running ? null : _analyzeImage,
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_running ? '识别中...' : '开始 AI 识图'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            MealInsightCard(result: _result),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '针对 ${widget.profile.name} 的建议',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ..._result.recommendations.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: scheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              line,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _stage == ScanStage.completed
                  ? () => Navigator.of(context).pop(_result)
                  : null,
              child: const Text('写入今日饮食记录'),
            ),
          ],
        ),
      ),
    );
  }
}
