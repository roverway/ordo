import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/models/efficiency_stats.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_theme.dart';
import 'package:ordo/features/ai_copilot/widgets/ai_efficiency_report_view.dart';

void main() {
  Widget buildTestWidget({
    required EfficiencyStats stats,
    String? analysisMarkdown,
    bool isLoading = false,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      theme: AppTheme.build(brightness),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      locale: const Locale('zh'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AiEfficiencyReportView(
            stats: stats,
            analysisMarkdown: analysisMarkdown,
            isLoading: isLoading,
          ),
        ),
      ),
    );
  }

  final testStats = EfficiencyStats(
    startDate: DateTime.utc(2026, 9, 21),
    endDate: DateTime.utc(2026, 9, 28),
    totalCount: 7,
    completedCount: 5,
    cancelledCount: 1,
    inProgressCount: 1,
    overdueCount: 1,
    completionRate: 5 / 7,
    q1Count: 2,
    q2Count: 2,
    q3Count: 2,
    q4Count: 1,
    q1Ratio: 2 / 7,
    q2Ratio: 2 / 7,
    q3Ratio: 2 / 7,
    q4Ratio: 1 / 7,
  );

  group('AiEfficiencyReportView Widget Tests', () {
    testWidgets(
      'renders KPI cards with completion rate %, completed and cancelled counts',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(stats: testStats));
        await tester.pumpAndSettle();

        // Check title
        expect(find.text('周度效能诊断'), findsOneWidget);

        // Check KPI values
        expect(find.text('71%'), findsOneWidget); // 5/7 ~ 71%
        expect(find.text('5'), findsOneWidget);
        expect(find.text('1'), findsAtLeastNWidgets(1));

        // Check KPI labels
        expect(find.text('完成率'), findsOneWidget);
        expect(find.text('已完成'), findsOneWidget);
        expect(find.text('已放弃'), findsOneWidget);
      },
    );

    testWidgets('renders 4 quadrant proportion bar and legends', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(stats: testStats));
      await tester.pumpAndSettle();

      expect(find.byKey(AiEfficiencyReportView.quadrantBarKey), findsOneWidget);
      expect(find.textContaining('Q1'), findsOneWidget);
      expect(find.textContaining('Q2'), findsOneWidget);
      expect(find.textContaining('Q3'), findsOneWidget);
      expect(find.textContaining('Q4'), findsOneWidget);
    });

    testWidgets('renders analysis markdown text when provided', (tester) async {
      const mockMarkdown = '### 本周成果\n超额完成核心目标。\n\n### 优化建议\n聚焦重要不紧急任务。';

      await tester.pumpWidget(
        buildTestWidget(stats: testStats, analysisMarkdown: mockMarkdown),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('本周成果'), findsOneWidget);
      expect(find.textContaining('超额完成核心目标'), findsOneWidget);
      expect(find.textContaining('聚焦重要不紧急任务'), findsOneWidget);
    });

    testWidgets('renders loading indicator when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(stats: testStats, isLoading: true),
      );

      expect(
        find.byKey(AiEfficiencyReportView.loadingIndicatorKey),
        findsOneWidget,
      );
    });

    testWidgets('renders without overflow in dark mode', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          stats: testStats,
          analysisMarkdown: '### 深度分析\n测试暗色模式渲染效果良好。',
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('周度效能诊断'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
