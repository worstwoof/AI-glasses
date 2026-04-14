import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'demo_data.dart';
import 'helpers.dart';
import 'ingredient_label_page_fast.dart';
import 'models.dart';
import 'profile_edit_page_v2.dart';
import 'recognition_page_fast.dart';
import 'services/local_storage_service.dart';
import 'services/vivo_food_vision_service_v3.dart';
import 'ui_kit.dart';

const AnalysisResult kEmptyAnalysisResult = AnalysisResult(
  foodName: '等待识别',
  suggestedMealType: '加餐',
  calories: 0,
  carbs: 0,
  protein: 0,
  fat: 0,
  fiber: 0,
  confidence: 0,
  recommendations: [
    '拍照识别后，这里会展示营养分析结果和建议。',
    '也可以使用配料表 OCR 查看过敏原和需留意成分。',
  ],
  accent: Color(0xFF22B892),
  icon: Icons.hourglass_top_rounded,
);

class AppShellPro extends StatefulWidget {
  const AppShellPro({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AppShellPro> createState() => _AppShellProState();
}

class _AppShellProState extends State<AppShellPro> {
  int _currentIndex = 0;
  bool _isConnected = true;
  bool _isSyncing = false;
  bool _isBootstrapping = true;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  AppUserProfile _profile = DemoData.profile;
  final List<MealRecord> _meals = <MealRecord>[];
  AnalysisResult _lastAnalysis = kEmptyAnalysisResult;

  List<MealRecord> get _todayMeals {
    final today = DateTime.now();
    return _meals.where((meal) => sameDay(meal.eatenAt, today)).toList()
      ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
  }

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  int get _eatenCalories =>
      _todayMeals.fold<int>(0, (sum, meal) => sum + meal.calories);

  int get _remainingCalories =>
      math.max(_profile.dailyTargetCalories - _eatenCalories, 0);

  MacroSummary get _macroSummary {
    double carbs = 0;
    double protein = 0;
    double fat = 0;
    for (final meal in _todayMeals) {
      carbs += meal.carbs;
      protein += meal.protein;
      fat += meal.fat;
    }
    return MacroSummary(carbs: carbs, protein: protein, fat: fat);
  }

  String get _syncText {
    if (_isSyncing) {
      return '正在同步 AI 眼镜和饮食数据...';
    }
    return '最近一次同步 ${formatTime(DateTime.now())}';
  }

  Future<void> _loadLocalState() async {
    try {
      final localState = await LocalStorageService.loadState();
      if (!mounted) {
        return;
      }

      setState(() {
        _profile = localState.profile;
        _meals
          ..clear()
          ..addAll(localState.meals);
        _isConnected = localState.isConnected;
        _lastAnalysis = localState.lastAnalysis ?? kEmptyAnalysisResult;
        _isBootstrapping = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBootstrapping = false;
      });
    }
  }

  Future<void> _saveProfile() {
    return LocalStorageService.saveProfile(_profile);
  }

  Future<void> _saveMeals() {
    return LocalStorageService.saveMeals(_meals);
  }

  Future<void> _openRecognitionPage() async {
    final result = await Navigator.of(context).push<AnalysisResult>(
      MaterialPageRoute(
        builder: (_) => RecognitionPageFast(
          isConnected: _isConnected,
          profile: _profile,
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
      _selectedDate = DateTime.now();
      _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    });

    await _saveMeals();
    await LocalStorageService.saveLastAnalysis(result);
  }

  Future<void> _openIngredientLabelPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => IngredientLabelPageFast(
          profile: _profile,
        ),
      ),
    );
  }

  Future<void> _toggleConnection() async {
    setState(() {
      _isConnected = !_isConnected;
    });

    await LocalStorageService.saveConnection(_isConnected);
  }

  Future<void> _openProfileEditor() async {
    final updatedProfile = await Navigator.of(context).push<AppUserProfile>(
      MaterialPageRoute(
        builder: (_) => ProfileEditPageV2(initialProfile: _profile),
      ),
    );

    if (updatedProfile == null) {
      return;
    }

    setState(() {
      _profile = updatedProfile;
    });

    await _saveProfile();
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('同步完成，最新饮食状态已刷新')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isBootstrapping) {
      return Scaffold(
        body: MeshBackground(
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final pages = <Widget>[
      HomePagePro(
        isConnected: _isConnected,
        profile: _profile,
        meals: _meals,
        remainingCalories: _remainingCalories,
        eatenCalories: _eatenCalories,
        macroSummary: _macroSummary,
        lastAnalysis: _lastAnalysis,
        syncText: _syncText,
        onOpenScanner: _openRecognitionPage,
        onOpenIngredientOcr: _openIngredientLabelPage,
        onSyncNow: _syncNow,
      ),
      CalendarPagePro(
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
      InsightPagePro(
        profile: _profile,
        isConnected: _isConnected,
        meals: _meals,
        macroSummary: _macroSummary,
        eatenCalories: _eatenCalories,
        remainingCalories: _remainingCalories,
        lastAnalysis: _lastAnalysis,
        aiConfigured: VivoFoodVisionServiceV3.isConfigured,
      ),
      ProfilePagePro(
        profile: _profile,
        isConnected: _isConnected,
        syncText: _syncText,
        aiConfigured: VivoFoodVisionServiceV3.isConfigured,
        isLightMode: widget.themeMode != ThemeMode.dark,
        onEditProfile: _openProfileEditor,
        onToggleConnection: _toggleConnection,
        onSyncNow: _syncNow,
        onThemeChanged: (isLight) {
          widget.onThemeModeChanged(isLight ? ThemeMode.light : ThemeMode.dark);
        },
      ),
    ];

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      body: MeshBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingPulse(
        color: scheme.primary,
        child: FloatingActionButton.large(
          onPressed: _openRecognitionPage,
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.center_focus_strong_rounded, size: 28),
              SizedBox(height: 2),
              Text(
                '识别',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _DockedNavigationBar(
        currentIndex: _currentIndex,
        onChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class HomePagePro extends StatelessWidget {
  const HomePagePro({
    super.key,
    required this.isConnected,
    required this.profile,
    required this.meals,
    required this.remainingCalories,
    required this.eatenCalories,
    required this.macroSummary,
    required this.lastAnalysis,
    required this.syncText,
    required this.onOpenScanner,
    required this.onOpenIngredientOcr,
    required this.onSyncNow,
  });

  final bool isConnected;
  final AppUserProfile profile;
  final List<MealRecord> meals;
  final int remainingCalories;
  final int eatenCalories;
  final MacroSummary macroSummary;
  final AnalysisResult lastAnalysis;
  final String syncText;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenIngredientOcr;
  final Future<void> Function() onSyncNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime.now();
    final latestMeals = meals
        .where((meal) => sameDay(meal.eatenAt, today))
        .take(3)
        .toList();
    final hasRealAnalysis = lastAnalysis.confidence > 0 && lastAnalysis.calories > 0;
    final homeSuggestions = _buildHomeSuggestions(
      profile: profile,
      meals: meals,
      remainingCalories: remainingCalories,
      eatenCalories: eatenCalories,
      macroSummary: macroSummary,
      lastAnalysis: lastAnalysis,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 132),
      children: [
        PageHeader(
          title: '今日营养舱',
          subtitle: '${now.month}月${now.day}日 · 闭环饮食管理',
          trailing: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(isLightTheme(context) ? 0.66 : 0.06),
              border: Border.all(color: appSoftBorder(context)),
            ),
            child: Icon(Icons.notifications_none_rounded, color: scheme.onSurface),
          ),
        ),
        const SizedBox(height: 18),
        PremiumCard(
          accent: scheme.primary,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PillBadge(
                    label: isConnected ? 'AI 眼镜在线' : '设备待连接',
                    icon: isConnected
                        ? Icons.wifi_tethering_rounded
                        : Icons.link_off_rounded,
                    color: isConnected ? scheme.primary : const Color(0xFFE57E67),
                  ),
                  const Spacer(),
                  Text(
                    syncText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: appMutedText(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '今天还能吃',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: appMutedText(context),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$remainingCalories',
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      'kcal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: appMutedText(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '目标预算 ${profile.dailyTargetCalories} kcal，已摄入 $eatenCalories kcal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: appMutedText(context),
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 420;
                  final tagGroup = Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      PillBadge(
                        label: profile.goal,
                        icon: Icons.flag_rounded,
                        color: const Color(0xFF19826B),
                        soft: true,
                      ),
                      PillBadge(
                        label: profile.preference,
                        icon: Icons.favorite_rounded,
                        color: const Color(0xFF4A97FF),
                        soft: true,
                      ),
                      PillBadge(
                        label: '目标 ${profile.dailyTargetCalories} kcal',
                        icon: Icons.local_fire_department_rounded,
                        color: const Color(0xFF26B893),
                        soft: true,
                      ),
                    ],
                  );

                  final chart = SizedBox(
                    width: 138,
                    height: 138,
                    child: MacroDonutChart(
                      carbs: macroSummary.carbs,
                      protein: macroSummary.protein,
                      fat: macroSummary.fat,
                      centerLabel: '$eatenCalories\n已摄入',
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        tagGroup,
                        const SizedBox(height: 16),
                        Center(child: chart),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tagGroup),
                      const SizedBox(width: 18),
                      chart,
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MetricChip(
                      label: '碳水比例',
                      value: '${(macroSummary.carbs / math.max(macroSummary.total, 1) * 100).round()}%',
                      color: const Color(0xFF2AB792),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricChip(
                      label: '蛋白质',
                      value: '${macroSummary.protein.round()}g',
                      color: const Color(0xFF4A97FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricChip(
                      label: '脂肪',
                      value: '${macroSummary.fat.round()}g',
                      color: const Color(0xFFF1A35B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                icon: Icons.center_focus_strong_rounded,
                title: '拍照识别',
                subtitle: '从相机或相册快速进入识别流',
                color: scheme.primary,
                onTap: onOpenScanner,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionCard(
                icon: Icons.receipt_long_rounded,
                title: '配料表 OCR',
                subtitle: '识别配料、过敏原和需留意成分',
                color: const Color(0xFF4A97FF),
                onTap: onOpenIngredientOcr,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        QuickActionCard(
          icon: Icons.sync_rounded,
          title: '同步闭环',
          subtitle: '拉取眼镜、识别记录和档案状态，让建议保持最新',
          color: const Color(0xFF26B893),
          onTap: () {
            onSyncNow();
          },
        ),
        const SizedBox(height: 16),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: '今日饮食记录',
                subtitle: '识别结果会自动回写到这里',
                trailing: Text(
                  '${latestMeals.length} 条记录',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              if (latestMeals.isEmpty)
                Text(
                  '还没有饮食记录。点击上方拍照识别，第一条结果会自动写回这里。',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: appMutedText(context),
                  ),
                )
              else
                for (final meal in latestMeals) ...[
                  FoodRecordCard(meal: meal),
                  if (meal != latestMeals.last) const SizedBox(height: 12),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (meals.isNotEmpty && homeSuggestions.isNotEmpty)
          PremiumCard(
            accent: hasRealAnalysis ? lastAnalysis.accent : scheme.primary,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        (hasRealAnalysis ? lastAnalysis.accent : scheme.primary),
                        (hasRealAnalysis ? lastAnalysis.accent : scheme.primary)
                            .withOpacity(0.25),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('今日智能建议', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...homeSuggestions.take(2).map(
                        (tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            tip,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: appMutedText(context),
                            ),
                          ),
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

class CalendarPagePro extends StatelessWidget {
  const CalendarPagePro({
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
    final scheme = Theme.of(context).colorScheme;
    final days = buildCalendarDays(focusedMonth);
    final mealsOfDay = meals.where((meal) => sameDay(meal.eatenAt, selectedDate)).toList()
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    final totalCalories = mealsOfDay.fold<int>(0, (sum, meal) => sum + meal.calories);
    final totalCarbs = mealsOfDay.fold<double>(0, (sum, meal) => sum + meal.carbs).round();
    final totalProtein =
        mealsOfDay.fold<double>(0, (sum, meal) => sum + meal.protein).round();
    final totalFat = mealsOfDay.fold<double>(0, (sum, meal) => sum + meal.fat).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 132),
      children: [
        PageHeader(
          title: '营养日历',
          subtitle: '按日期回看每一顿的识别与摄入',
          trailing: PillBadge(
            label: '${focusedMonth.month} 月',
            icon: Icons.calendar_today_rounded,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 18),
        PremiumCard(
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
                      '${focusedMonth.year} 年 ${focusedMonth.month} 月',
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
              const SizedBox(height: 14),
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
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onSelectDate(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: isSelected
                              ? scheme.primary.withOpacity(0.16)
                              : hasMeal
                                  ? scheme.primary.withOpacity(0.08)
                                  : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? scheme.primary
                                : hasMeal
                                    ? scheme.primary.withOpacity(0.12)
                                    : appSoftBorder(context),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isCurrentMonth
                                    ? Theme.of(context).colorScheme.onSurface
                                    : appMutedText(context),
                              ),
                            ),
                            if (hasMeal)
                              Positioned(
                                bottom: 7,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
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
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: '${selectedDate.month}月${selectedDate.day}日总结',
                subtitle: '按实际识别记录聚合展示',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: MetricChip(label: '总摄入', value: '$totalCalories kcal')),
                  const SizedBox(width: 10),
                  Expanded(child: MetricChip(label: '碳水', value: '$totalCarbs g')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: MetricChip(label: '蛋白质', value: '$totalProtein g')),
                  const SizedBox(width: 10),
                  Expanded(child: MetricChip(label: '脂肪', value: '$totalFat g')),
                ],
              ),
              const SizedBox(height: 18),
              if (mealsOfDay.isEmpty)
                Text(
                  '这一天还没有饮食记录，可以点击底部中心按钮开始拍照识别。',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: appMutedText(context),
                  ),
                )
              else
                for (var i = 0; i < mealsOfDay.length; i++) ...[
                  MealTimelineRow(
                    meal: mealsOfDay[i],
                    last: i == mealsOfDay.length - 1,
                  ),
                  if (i != mealsOfDay.length - 1) const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class InsightPagePro extends StatelessWidget {
  const InsightPagePro({
    super.key,
    required this.profile,
    required this.isConnected,
    required this.meals,
    required this.macroSummary,
    required this.eatenCalories,
    required this.remainingCalories,
    required this.lastAnalysis,
    required this.aiConfigured,
  });

  final AppUserProfile profile;
  final bool isConnected;
  final List<MealRecord> meals;
  final MacroSummary macroSummary;
  final int eatenCalories;
  final int remainingCalories;
  final AnalysisResult lastAnalysis;
  final bool aiConfigured;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final hasTodayMeals = meals.any((meal) => sameDay(meal.eatenAt, today));
    final hasRealAnalysis =
        hasTodayMeals && lastAnalysis.confidence > 0 && lastAnalysis.calories > 0;
    final weeklyCalories = _buildWeeklyCalories(meals);
    final peak = weeklyCalories.fold<double>(0, math.max).clamp(1, double.infinity);
    const weekLabels = ['一', '二', '三', '四', '五', '六', '今'];
    final scheme = Theme.of(context).colorScheme;
    final insightSuggestions = _buildInsightSuggestions(
      profile: profile,
      meals: meals,
      remainingCalories: remainingCalories,
      eatenCalories: eatenCalories,
      macroSummary: macroSummary,
      lastAnalysis: lastAnalysis,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 132),
      children: [
        PageHeader(
          title: '健康分析',
          subtitle: '把识别结果转成可以执行的饮食策略',
          trailing: PillBadge(
            label: aiConfigured ? 'AI 已配置' : '演示模式',
            icon: aiConfigured ? Icons.cloud_done_rounded : Icons.science_rounded,
            color: aiConfigured ? scheme.primary : const Color(0xFFE39B64),
          ),
        ),
        const SizedBox(height: 18),
        PremiumCard(
          accent: scheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('闭环状态', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MetricChip(
                      label: '眼镜连接',
                      value: isConnected ? '在线' : '离线',
                      color: isConnected ? scheme.primary : const Color(0xFFE57E67),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricChip(
                      label: '今日摄入',
                      value: '$eatenCalories kcal',
                      color: const Color(0xFF4A97FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricChip(
                      label: '剩余预算',
                      value: '$remainingCalories kcal',
                      color: const Color(0xFF22B892),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: '近 7 日热量趋势',
                subtitle: '完全基于本地饮食记录聚合',
              ),
              const SizedBox(height: 18),
              if (meals.isEmpty)
                Text(
                  '还没有足够的饮食记录，开始拍照识别后这里会形成你的近 7 日趋势。',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: appMutedText(context),
                  ),
                )
              else
                SizedBox(
                  height: 178,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(weeklyCalories.length, (index) {
                      final value = weeklyCalories[index];
                      final ratio = (value / peak).clamp(0.08, 1.0);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                value.round().toString(),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: appMutedText(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                height: value <= 0 ? 10 : 118 * ratio,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Color(0xFF26B893),
                                      Color(0x9957D5BC),
                                    ],
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x3326B893),
                                      blurRadius: 18,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(weekLabels[index]),
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
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('宏量营养结构', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: MacroLegend(summary: macroSummary)),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: MacroDonutChart(
                      carbs: macroSummary.carbs,
                      protein: macroSummary.protein,
                      fat: macroSummary.fat,
                      centerLabel: '今日\n结构',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (hasRealAnalysis) ...[
          AnalysisSnapshotCard(result: lastAnalysis),
          const SizedBox(height: 16),
        ],
        if (insightSuggestions.isNotEmpty)
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('个性化建议', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    PillBadge(
                      label: profile.goal,
                      icon: Icons.flag_rounded,
                      color: scheme.primary,
                      soft: true,
                    ),
                    PillBadge(
                      label: profile.preference,
                      icon: Icons.tune_rounded,
                      color: const Color(0xFF4A97FF),
                      soft: true,
                    ),
                    if (profile.allergies.isNotEmpty)
                      PillBadge(
                        label: '过敏：${profile.allergies.join('、')}',
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFF0A85C),
                        soft: true,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ...insightSuggestions.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary.withOpacity(0.12),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tip,
                            style: Theme.of(context).textTheme.bodyLarge,
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

class ProfilePagePro extends StatelessWidget {
  const ProfilePagePro({
    super.key,
    required this.profile,
    required this.isConnected,
    required this.syncText,
    required this.aiConfigured,
    required this.isLightMode,
    required this.onEditProfile,
    required this.onToggleConnection,
    required this.onSyncNow,
    required this.onThemeChanged,
  });

  final AppUserProfile profile;
  final bool isConnected;
  final String syncText;
  final bool aiConfigured;
  final bool isLightMode;
  final Future<void> Function() onEditProfile;
  final Future<void> Function() onToggleConnection;
  final Future<void> Function() onSyncNow;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 132),
      children: [
        PageHeader(
          title: '个人档案',
          subtitle: '健康偏好、设备和 AI 策略都在这里',
          trailing: OutlinedButton.icon(
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('编辑'),
          ),
        ),
        const SizedBox(height: 18),
        PremiumCard(
          accent: scheme.primary,
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      scheme.primary.withOpacity(0.35),
                    ],
                  ),
                ),
                child: const Icon(Icons.person_rounded, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      '连接设备：${profile.deviceName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: appMutedText(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PillBadge(
                      label: isConnected ? '设备在线' : '设备离线',
                      icon: isConnected
                          ? Icons.bluetooth_connected_rounded
                          : Icons.bluetooth_disabled_rounded,
                      color: isConnected ? scheme.primary : const Color(0xFFE57E67),
                      soft: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('身体信息', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 14),
                    Text('性别：${profile.gender}'),
                    const SizedBox(height: 8),
                    Text('年龄：${profile.age} 岁'),
                    const SizedBox(height: 8),
                    Text('身高：${profile.heightCm} cm'),
                    const SizedBox(height: 8),
                    Text('体重：${profile.weightKg} kg'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('饮食策略', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 14),
                    Text('目标：${profile.goal}'),
                    const SizedBox(height: 8),
                    Text('偏好：${profile.preference}'),
                    const SizedBox(height: 8),
                    Text('每日目标：${profile.dailyTargetCalories} kcal'),
                    const SizedBox(height: 8),
                    Text('过敏：${profile.allergies.join('、')}'),
                    const SizedBox(height: 8),
                    Text('状态：${profile.conditions.join('、')}'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI 系统', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: MetricChip(
                      label: '识图接口',
                      value: aiConfigured ? '已配置' : '演示模式',
                      color: aiConfigured ? scheme.primary : const Color(0xFFE39B64),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricChip(
                      label: '建议闭环',
                      value: '已启用',
                      color: const Color(0xFF4A97FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: MetricChip(
                      label: '本地存储',
                      value: '已启用',
                      color: const Color(0xFF26B893),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricChip(
                      label: '每日目标',
                      value: '${profile.dailyTargetCalories} kcal',
                      color: const Color(0xFFF0A85C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                syncText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: appMutedText(context),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isLightMode,
                title: const Text('浅色模式'),
                subtitle: const Text('默认使用浅色主题，也可以随时切换深色主题'),
                onChanged: onThemeChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onSyncNow,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('同步数据'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onToggleConnection,
                icon: Icon(
                  isConnected
                      ? Icons.bluetooth_disabled_rounded
                      : Icons.bluetooth_searching_rounded,
                ),
                label: Text(isConnected ? '断开眼镜' : '重新连接'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

List<double> _buildWeeklyCalories(List<MealRecord> meals) {
  final today = DateTime.now();
  return List<double>.generate(7, (index) {
    final day = DateTime(today.year, today.month, today.day - (6 - index));
    return meals
        .where((meal) => sameDay(meal.eatenAt, day))
        .fold<double>(0, (sum, meal) => sum + meal.calories);
  });
}

List<String> _buildHomeSuggestions({
  required AppUserProfile profile,
  required List<MealRecord> meals,
  required int remainingCalories,
  required int eatenCalories,
  required MacroSummary macroSummary,
  required AnalysisResult lastAnalysis,
}) {
  final today = DateTime.now();
  final todayMeals = meals.where((meal) => sameDay(meal.eatenAt, today)).toList();
  if (todayMeals.isEmpty) {
    return const [];
  }

  final suggestions = <String>[];
  final totalMacro = math.max(macroSummary.total, 1);
  final carbsRatio = macroSummary.carbs / totalMacro;
  final proteinRatio = macroSummary.protein / totalMacro;
  final fatRatio = macroSummary.fat / totalMacro;

  if (remainingCalories <= 0) {
    suggestions.add('今天已达到或超过目标热量，后续餐次建议以蔬菜、清汤和低油蛋白为主。');
  } else if (remainingCalories < 300) {
    suggestions.add('今天剩余热量不多，下一餐建议尽量清淡，避免高油和高糖加餐。');
  } else {
    suggestions.add('今天还剩 $remainingCalories kcal，可以继续围绕 ${profile.goal} 做更稳的餐次安排。');
  }

  if (fatRatio > 0.42) {
    suggestions.add('今天脂肪占比偏高，后续优先补蔬菜、豆制品或瘦肉，少喝浓汤和重口调味。');
  } else if (proteinRatio < 0.22) {
    suggestions.add('今天蛋白质占比偏低，下一餐建议补鸡胸肉、鱼虾、鸡蛋或豆腐。');
  } else if (carbsRatio < 0.25) {
    suggestions.add('今天碳水摄入偏少，如果还有运动或工作强度，建议补一点米饭、玉米或全麦主食。');
  }

  if (lastAnalysis.confidence > 0 && lastAnalysis.recommendations.isNotEmpty) {
    suggestions.add(lastAnalysis.recommendations.first);
  } else {
    final latestMeal = todayMeals.first;
    suggestions.add('你最近一餐是“${latestMeal.name}”，建议继续结合 ${profile.preference} 控制总量和烹调方式。');
  }

  return suggestions.take(3).toList();
}

List<String> _buildInsightSuggestions({
  required AppUserProfile profile,
  required List<MealRecord> meals,
  required int remainingCalories,
  required int eatenCalories,
  required MacroSummary macroSummary,
  required AnalysisResult lastAnalysis,
}) {
  final today = DateTime.now();
  final todayMeals = meals.where((meal) => sameDay(meal.eatenAt, today)).toList();
  if (todayMeals.isEmpty) {
    return const [];
  }

  final suggestions = <String>[];
  final weeklyCalories = _buildWeeklyCalories(meals);
  final todayWeeklyAverage =
      weeklyCalories.fold<double>(0, (sum, item) => sum + item) / weeklyCalories.length;

  if (eatenCalories > profile.dailyTargetCalories) {
    suggestions.add('今天摄入 ${eatenCalories - profile.dailyTargetCalories} kcal 超过目标，建议明天把高油高糖餐次压缩到 1 次以内。');
  } else if (eatenCalories < (profile.dailyTargetCalories * 0.55).round()) {
    suggestions.add('今天总摄入明显低于目标，如果不是刻意控卡，建议补足主食和优质蛋白，避免后续暴食。');
  }

  if (weeklyCalories.last > todayWeeklyAverage * 1.15 && todayWeeklyAverage > 0) {
    suggestions.add('今天热量高于近 7 日平均值，接下来 1 到 2 餐可适当回到更清淡、更低油的结构。');
  }

  if (macroSummary.fat > macroSummary.protein && macroSummary.fat > macroSummary.carbs) {
    suggestions.add('今天脂肪是主要来源，之后尽量减少火锅蘸料、炸物和浓汤，提升蔬菜和蛋白占比。');
  } else if (macroSummary.protein >= macroSummary.fat &&
      macroSummary.protein >= macroSummary.carbs) {
    suggestions.add('今天蛋白结构相对不错，继续保持瘦肉、蛋类和豆制品的组合会比较稳。');
  }

  if (profile.allergies.isNotEmpty) {
    suggestions.add('你的档案里有过敏原：${profile.allergies.join('、')}，继续拍照和扫配料表时要重点规避相关成分。');
  }

  if (lastAnalysis.confidence > 0) {
    suggestions.addAll(lastAnalysis.recommendations);
  }

  return suggestions.toSet().take(4).toList();
}

class _DockedNavigationBar extends StatelessWidget {
  const _DockedNavigationBar({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: appElevatedSurface(context),
            border: Border.all(color: appSoftBorder(context)),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withOpacity(0.08),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_rounded,
                  label: '首页',
                  selected: currentIndex == 0,
                  onTap: () => onChanged(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.calendar_month_rounded,
                  label: '日历',
                  selected: currentIndex == 1,
                  onTap: () => onChanged(1),
                ),
              ),
              const SizedBox(width: 86),
              Expanded(
                child: _NavItem(
                  icon: Icons.monitor_heart_outlined,
                  label: '分析',
                  selected: currentIndex == 2,
                  onTap: () => onChanged(2),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.person_outline_rounded,
                  label: '档案',
                  selected: currentIndex == 3,
                  onTap: () => onChanged(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: selected ? scheme.primary.withOpacity(0.10) : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? scheme.primary : appMutedText(context),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? scheme.primary : appMutedText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
