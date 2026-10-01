import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';
import 'package:ordo/core/utils/dates.dart';
import 'package:ordo/features/tasks/task_providers.dart';
import 'package:ordo/features/tasks/widgets/task_editor/task_date_picker_dialogs.dart';

void main() {
  group('TaskDatePickerDialogs 辅助函数单元测试', () {
    test('statusIcon 映射各状态对应图标', () {
      expect(statusIcon(TaskStatus.todo), Icons.radio_button_unchecked);
      expect(statusIcon(TaskStatus.inProgress), Icons.circle);
      expect(statusIcon(TaskStatus.done), Icons.check_circle);
      expect(statusIcon(TaskStatus.cancelled), Icons.cancel_outlined);
    });

    test('statusColor 映射各状态对应颜色', () {
      expect(statusColor(TaskStatus.todo), AppTokens.colorCancelled);
      expect(statusColor(TaskStatus.inProgress), AppTokens.colorInProgress);
      expect(statusColor(TaskStatus.done), AppTokens.colorDone);
      expect(statusColor(TaskStatus.cancelled), AppTokens.colorCancelled);
    });

    testWidgets('statusLabel 本地化文案映射正确', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(statusLabel(l10n, TaskStatus.todo), l10n.statusTodo);
      expect(statusLabel(l10n, TaskStatus.inProgress), l10n.statusInProgress);
      expect(statusLabel(l10n, TaskStatus.done), l10n.statusDone);
      expect(statusLabel(l10n, TaskStatus.cancelled), l10n.statusCancelled);
    });
  });

  group('TaskDateRangePickerSheet 控件与交互测试', () {
    Widget buildTestHarness(ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TaskDateRangePickerSheet()),
        ),
      );
    }

    testWidgets('渲染基础布局元素（标题、完成按钮、预设胶囊、起止时间卡片）', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildTestHarness(container));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TaskDateRangePickerSheet)),
      );

      // 验证标题和完成按钮
      expect(find.text(l10n.dateAndReminder), findsOneWidget);
      expect(find.text(l10n.done), findsOneWidget);

      // 验证快捷预设选项
      expect(find.text(l10n.today), findsOneWidget);
      expect(find.text(l10n.tomorrow), findsOneWidget);
      expect(find.text(l10n.thisWeekend), findsOneWidget);
      expect(find.text(l10n.nextWeek), findsOneWidget);
      expect(find.text(l10n.custom), findsOneWidget);

      // 验证未设置时间时的卡片文本
      expect(find.text(l10n.taskStartTime), findsOneWidget);
      expect(find.text(l10n.noStartTime), findsOneWidget);
      expect(find.text(l10n.taskEndTime), findsOneWidget);
      expect(find.text(l10n.noDueDate), findsOneWidget);
    });

    testWidgets('点击“今天”快捷预设更新截止时间', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildTestHarness(container));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TaskDateRangePickerSheet)),
      );

      // 点击“今天”
      await tester.tap(find.text(l10n.today));
      await tester.pumpAndSettle();

      final state = container.read(taskFormProvider);
      final expected = dateOnlyMs(DateTime.now());
      expect(state.endAt, expected);
    });

    testWidgets('点击“明天”快捷预设更新截止时间', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildTestHarness(container));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TaskDateRangePickerSheet)),
      );

      await tester.tap(find.text(l10n.tomorrow));
      await tester.pumpAndSettle();

      final state = container.read(taskFormProvider);
      final expected = dateOnlyMs(DateTime.now().add(const Duration(days: 1)));
      expect(state.endAt, expected);
    });

    testWidgets('点击“本周末”快捷预设更新截止时间', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildTestHarness(container));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TaskDateRangePickerSheet)),
      );

      await tester.tap(find.text(l10n.thisWeekend));
      await tester.pumpAndSettle();

      final state = container.read(taskFormProvider);
      final expected = dateOnlyMs(thisWeekend(DateTime.now()));
      expect(state.endAt, expected);
    });

    testWidgets('点击“下周”快捷预设更新截止时间', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildTestHarness(container));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TaskDateRangePickerSheet)),
      );

      await tester.tap(find.text(l10n.nextWeek));
      await tester.pumpAndSettle();

      final state = container.read(taskFormProvider);
      final expected = dateOnlyMs(nextMonday(DateTime.now()));
      expect(state.endAt, expected);
    });

    testWidgets('当设置时间后显示“清除”预设，点击重置起止时间', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 先赋初始起止时间
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      container.read(taskFormProvider.notifier).updateStartAt(nowMs);
      container.read(taskFormProvider.notifier).updateEndAt(nowMs + 3600000);

      await tester.pumpWidget(buildTestHarness(container));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TaskDateRangePickerSheet)),
      );

      // 验证“清除”胶囊出现
      final clearFinder = find.widgetWithText(DatePresetChip, l10n.clear);
      expect(clearFinder, findsOneWidget);

      // 滚动至可见区域并点击清除
      await tester.ensureVisible(clearFinder);
      await tester.pumpAndSettle();
      await tester.tap(clearFinder);
      await tester.pumpAndSettle();

      final state = container.read(taskFormProvider);
      expect(state.startAt, isNull);
      expect(state.endAt, isNull);
    });

    testWidgets('单项时间卡片清除按钮可独立清空开始时间或截止时间', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      container.read(taskFormProvider.notifier).updateStartAt(nowMs);
      container.read(taskFormProvider.notifier).updateEndAt(nowMs + 7200000);

      await tester.pumpWidget(buildTestHarness(container));
      await tester.pumpAndSettle();

      // 开始时间和截止时间卡片各自都有一个 Icons.close 的 IconButton
      final closeButtons = find.widgetWithIcon(IconButton, Icons.close);
      expect(closeButtons, findsNWidgets(2));

      // 点击第一个（开始时间的清除）
      await tester.tap(closeButtons.first);
      await tester.pumpAndSettle();

      var state = container.read(taskFormProvider);
      expect(state.startAt, isNull);
      expect(state.endAt, isNotNull);

      // 此时只剩下一个清除按钮（截止时间的清除）
      final remainingClose = find.widgetWithIcon(IconButton, Icons.close);
      expect(remainingClose, findsOneWidget);

      await tester.tap(remainingClose);
      await tester.pumpAndSettle();

      state = container.read(taskFormProvider);
      expect(state.startAt, isNull);
      expect(state.endAt, isNull);
    });
  });

  group('showTaskDatePicker 弹窗集成测试', () {
    testWidgets('点击宿主按钮弹出 TaskDateRangePickerSheet 并在点击“完成”后正常关闭', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () => showTaskDatePicker(context, ref),
                    child: const Text('打开日期选择'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // 打开弹窗
      await tester.tap(find.text('打开日期选择'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDateRangePickerSheet), findsOneWidget);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(TaskDateRangePickerSheet)),
      );
      // 点击“完成”关闭
      await tester.tap(find.text(l10n.done));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDateRangePickerSheet), findsNothing);
    });
  });
}
