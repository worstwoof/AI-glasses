import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'demo_data.dart';
import 'helpers.dart';
import 'models.dart';
import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insight_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recognition_flow_page.dart';
import 'widgets/common_widgets.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
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
        builder: (_) => RecognitionFlowPage(
          isConnected: _isConnected,
          profile: _profile,
          initialResult: _lastAnalysis,
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
    final pages = <Widget>[
      HomeScreen(
        isConnected: _isConnected,
        profile: _profile,
        meals: _meals,
        remainingCalories: _remainingCalories,
        eatenCalories: _eatenCalories,
        macroSummary: _macroSummary,
        syncText: _syncText,
      ),
      CalendarScreen(
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
      InsightScreen(
        profile: _profile,
        isConnected: _isConnected,
        macroSummary: _macroSummary,
        eatenCalories: _eatenCalories,
        remainingCalories: _remainingCalories,
        lastAnalysis: _lastAnalysis,
      ),
      ProfileScreen(
        profile: _profile,
        isConnected: _isConnected,
        syncText: _syncText,
        onToggleConnection: _toggleConnection,
        onSyncNow: _syncNow,
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
              color: const Color(0xFF73FFD0).withOpacity(0.35),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _openRecognitionPage,
          backgroundColor: const Color(0xFF6EF7C8),
          foregroundColor: const Color(0xFF0E191C),
          child: const Icon(Icons.camera_alt_rounded),
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF091619).withOpacity(0.92),
          indicatorColor: const Color(0x226EF7C8),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFFB9FFEA)
                  : const Color(0xFF94A5A7),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          height: 76,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: '首页',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_rounded),
              label: '日历',
            ),
            NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined),
              label: '分析',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              label: '档案',
            ),
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

