import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_theme.dart';
import 'package:ordo/core/theme/app_tokens.dart';
import 'package:ordo/features/ai_copilot/widgets/ai_task_proposal_card.dart';

void main() {
  final sampleResult = AiTaskParseResult(
    title: '准备季度总结 PPT',
    description: '整理 Q3 业绩与下一季度计划',
    priority: 3, // P1 high priority
    dueAt: DateTime(2026, 10, 15, 18, 0).millisecondsSinceEpoch,
    tags: const ['工作', '汇报'],
    substeps: const [
      AiSubstep(title: '收集核心数据指标', sortOrder: 0),
      AiSubstep(title: '撰写内容大纲', sortOrder: 1),
      AiSubstep(title: '美化幻灯片版式', sortOrder: 2),
    ],
  );

  Widget buildTestWidget({
    required AiTaskParseResult proposal,
    Set<int>? selectedIndices,
    bool isPersisted = false,
    bool isPersisting = false,
    bool isDiscarded = false,
    ValueChanged<Set<int>>? onSubstepsChanged,
    ValueChanged<AiTaskParseResult>? onProposalChanged,
    VoidCallback? onConfirm,
    VoidCallback? onDiscard,
    ThemeMode themeMode = ThemeMode.dark,
  }) {
    return MaterialApp(
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            child: AiTaskProposalCard(
              proposal: proposal,
              selectedSubstepIndices: selectedIndices ?? const {0, 1, 2},
              isPersisted: isPersisted,
              isPersisting: isPersisting,
              isDiscarded: isDiscarded,
              onSubstepsChanged: onSubstepsChanged,
              onProposalChanged: onProposalChanged,
              onConfirm: onConfirm,
              onDiscard: onDiscard,
            ),
          ),
        ),
      ),
    );
  }

  group('AiTaskProposalCard 渲染与属性展示', () {
    testWidgets('渲染任务标题、高优先级徽标、截止时间、标签及子步骤列表', (tester) async {
      await tester.pumpWidget(buildTestWidget(proposal: sampleResult));
      await tester.pumpAndSettle();

      // 验证标题与描述渲染
      expect(find.text('准备季度总结 PPT'), findsOneWidget);
      expect(find.text('整理 Q3 业绩与下一季度计划'), findsOneWidget);

      // 验证高优先级标签显示
      expect(find.text('P1 · 重要紧急'), findsOneWidget);

      // 验证截止时间芯片显示
      expect(find.textContaining('10-15'), findsOneWidget);

      // 验证标签展示
      expect(find.text('#工作'), findsOneWidget);
      expect(find.text('#汇报'), findsOneWidget);

      // 验证 3 个子步骤文本与复选框
      expect(find.text('收集核心数据指标'), findsOneWidget);
      expect(find.text('撰写内容大纲'), findsOneWidget);
      expect(find.text('美化幻灯片版式'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(3));

      // 验证操作按钮 "添加到待办"
      expect(find.text('添加到待办'), findsOneWidget);
    });

    testWidgets('暗色模式下应用 Linear 极简质感深灰底色与微光边框', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(proposal: sampleResult, themeMode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();

      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppTokens.radiusCard),
      );
      expect(decoration.color, AppTokens.surfaceCardDark);
      expect(decoration.border?.top.color, AppTokens.borderSubtleDark);
    });
  });

  group('AiTaskProposalCard 交互行为', () {
    testWidgets('点击子步骤复选框触发 onSubstepsChanged 回调', (tester) async {
      Set<int> updatedIndices = {};
      await tester.pumpWidget(
        buildTestWidget(
          proposal: sampleResult,
          selectedIndices: const {0, 1, 2},
          onSubstepsChanged: (indices) => updatedIndices = indices,
        ),
      );
      await tester.pumpAndSettle();

      // 取消勾选第 2 个子步骤（index 1）
      final secondCheckbox = find.byType(Checkbox).at(1);
      await tester.tap(secondCheckbox);
      await tester.pumpAndSettle();

      expect(updatedIndices, const {0, 2});
    });

    testWidgets('未落库时点击"添加到待办"触发 onConfirm 回调', (tester) async {
      var confirmCalled = false;
      await tester.pumpWidget(
        buildTestWidget(
          proposal: sampleResult,
          onConfirm: () => confirmCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      final confirmBtn = find.text('添加到待办');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(confirmCalled, isTrue);
    });

    testWidgets('已落库时（isPersisted=true）按钮显示为"已添加"并置灰禁用，复选框也禁用', (tester) async {
      var confirmCalled = false;
      await tester.pumpWidget(
        buildTestWidget(
          proposal: sampleResult,
          isPersisted: true,
          onConfirm: () => confirmCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      // 验证按钮显示"已添加"
      expect(find.text('已添加'), findsOneWidget);
      expect(find.text('添加到待办'), findsNothing);

      // 验证按钮不可点击
      await tester.tap(find.text('已添加'));
      await tester.pumpAndSettle();
      expect(confirmCalled, isFalse);

      // 验证 Checkbox 处于只读/禁用状态（onChanged == null）
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      for (final cb in checkboxes) {
        expect(cb.onChanged, isNull);
      }
    });

    testWidgets('放弃卡片时显示"已放弃"状态', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(proposal: sampleResult, isDiscarded: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('已放弃'), findsOneWidget);
    });

    testWidgets('点击优先级徽标可循环切换优先级并触发 onProposalChanged 回调', (tester) async {
      AiTaskParseResult? updated;
      await tester.pumpWidget(
        buildTestWidget(
          proposal: sampleResult,
          onProposalChanged: (p) => updated = p,
        ),
      );
      await tester.pumpAndSettle();

      // 点击 P1 徽标 -> 切换到 P2 (priority 2)
      await tester.tap(find.text('P1 · 重要紧急'));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.priority, equals(2));
    });

    testWidgets('点击标题进入行内编辑并提交修改', (tester) async {
      AiTaskParseResult? updated;
      await tester.pumpWidget(
        buildTestWidget(
          proposal: sampleResult,
          onProposalChanged: (p) => updated = p,
        ),
      );
      await tester.pumpAndSettle();

      // 点击标题进入编辑
      await tester.tap(find.text('准备季度总结 PPT'));
      await tester.pumpAndSettle();

      // 应当出现 TextField
      expect(find.byType(TextField), findsOneWidget);

      // 输入新标题
      await tester.enterText(find.byType(TextField), '修改后的全新任务标题');
      await tester.pumpAndSettle();

      // 点击确认保存勾选按钮
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.title, equals('修改后的全新任务标题'));
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('点击优先级徽标循环切换优先级 (P1 -> P2)', (tester) async {
      AiTaskParseResult? updated;
      await tester.pumpWidget(
        buildTestWidget(
          proposal: sampleResult,
          onProposalChanged: (p) => updated = p,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('P1 · 重要紧急'));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.priority, equals(2));
    });

    testWidgets('点击截止时间唤出底部快捷表单并支持清除截止时间', (tester) async {
      AiTaskParseResult? updated;
      await tester.pumpWidget(
        buildTestWidget(
          proposal: sampleResult,
          onProposalChanged: (p) => updated = p,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('10-15'));
      await tester.pumpAndSettle();

      expect(find.text('设置截止时间'), findsOneWidget);
      expect(find.text('清除截止时间'), findsOneWidget);

      await tester.tap(find.text('清除截止时间'));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.dueAt, isNull);
    });

    testWidgets('删除已有标签触发 onProposalChanged', (tester) async {
      AiTaskParseResult? updated;
      await tester.pumpWidget(
        buildTestWidget(
          proposal: sampleResult,
          onProposalChanged: (p) => updated = p,
        ),
      );
      await tester.pumpAndSettle();

      // 点击标签上的删除按钮
      final closeIcons = find.byIcon(Icons.close);
      expect(closeIcons, findsWidgets);
      await tester.tap(closeIcons.first);
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.tags, isNot(contains('工作')));
    });

    testWidgets('点击任务备注进入行内编辑并提交修改', (tester) async {
      AiTaskParseResult? updated;
      await tester.pumpWidget(
        buildTestWidget(
          proposal: sampleResult,
          onProposalChanged: (p) => updated = p,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('整理 Q3 业绩与下一季度计划'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '更新后的详细备注内容');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.description, equals('更新后的详细备注内容'));
    });

    testWidgets('点击子步骤文字进入编辑状态并保存', (tester) async {
      AiTaskParseResult? updated;
      await tester.pumpWidget(
        buildTestWidget(
          proposal: sampleResult,
          onProposalChanged: (p) => updated = p,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('撰写内容大纲'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '撰写详细内容大纲 (V2)');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(updated, isNotNull);
      expect(updated!.substeps.map((s) => s.title), contains('撰写详细内容大纲 (V2)'));
    });
  });
}
