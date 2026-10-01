import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';
import 'package:ordo/features/ai_copilot/widgets/proposal_date_picker_sheets.dart';

void main() {
  Widget buildApp({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('showProposalDueDatePicker 交互与状态回调测试', () {
    testWidgets('弹窗正确展示标题、预设选项及无清除按钮（initialDueAt 为空）', (tester) async {
      configureViewport(tester);
      int? selected;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showProposalDueDatePicker(
                    context: context,
                    initialDueAt: null,
                    onDateSelected: (val) => selected = val,
                  );
                },
                child: const Text('Open Due Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Due Picker'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ElevatedButton)),
      );

      expect(find.text(l10n.aiSetDueDate), findsOneWidget);
      expect(find.text(l10n.aiPresetToday18), findsOneWidget);
      expect(find.text(l10n.aiPresetTonight21), findsOneWidget);
      expect(find.text(l10n.aiPresetTomorrow09), findsOneWidget);
      expect(find.text(l10n.aiPresetThisFriday18), findsOneWidget);
      expect(find.text(l10n.aiPresetNextMonday09), findsOneWidget);
      expect(find.text(l10n.aiCustomDateTime), findsOneWidget);
      // initialDueAt 为 null 时不应出现清除按钮
      expect(find.text(l10n.aiClearDueDate), findsNothing);
      expect(selected, isNull);
    });

    testWidgets('点击预设「今天 18:00」正确计算并触发回调', (tester) async {
      configureViewport(tester);
      int? selected;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showProposalDueDatePicker(
                    context: context,
                    initialDueAt: null,
                    onDateSelected: (val) => selected = val,
                  );
                },
                child: const Text('Open Due Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Due Picker'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ElevatedButton)),
      );

      await tester.tap(find.text(l10n.aiPresetToday18));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(selected!);
      expect(dt.hour, 18);
      expect(dt.minute, 0);
      // 弹窗已 pop
      expect(find.text(l10n.aiSetDueDate), findsNothing);
    });

    testWidgets('点击预设「今晚 21:00」正确计算并触发回调', (tester) async {
      configureViewport(tester);
      int? selected;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showProposalDueDatePicker(
                    context: context,
                    initialDueAt: null,
                    onDateSelected: (val) => selected = val,
                  );
                },
                child: const Text('Open Due Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Due Picker'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ElevatedButton)),
      );

      await tester.tap(find.text(l10n.aiPresetTonight21));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(selected!);
      expect(dt.hour, 21);
      expect(dt.minute, 0);
    });

    testWidgets('initialDueAt 非空时展示清除按钮，点击触发 null 回调', (tester) async {
      configureViewport(tester);
      int? selected = 1727776800000;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showProposalDueDatePicker(
                    context: context,
                    initialDueAt: selected,
                    onDateSelected: (val) => selected = val,
                  );
                },
                child: const Text('Open Due Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Due Picker'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ElevatedButton)),
      );

      expect(find.text(l10n.aiClearDueDate), findsOneWidget);

      await tester.tap(find.text(l10n.aiClearDueDate));
      await tester.pumpAndSettle();

      expect(selected, isNull);
      expect(find.text(l10n.aiSetDueDate), findsNothing);
    });
  });

  group('showProposalStartDatePicker 交互与状态回调测试', () {
    testWidgets('弹窗正确展示标题、预设选项及无清除按钮（initialStartAt 为空）', (tester) async {
      configureViewport(tester);
      int? selected;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showProposalStartDatePicker(
                    context: context,
                    initialStartAt: null,
                    onDateSelected: (val) => selected = val,
                  );
                },
                child: const Text('Open Start Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Start Picker'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ElevatedButton)),
      );

      expect(find.text(l10n.aiSetStartDate), findsOneWidget);
      expect(find.text(l10n.aiPresetNow), findsOneWidget);
      expect(find.text(l10n.aiPresetToday14), findsOneWidget);
      expect(find.text(l10n.aiPresetTomorrow09), findsOneWidget);
      expect(find.text(l10n.aiCustomDateTime), findsOneWidget);
      expect(find.text(l10n.aiClearStartDate), findsNothing);
      expect(selected, isNull);
    });

    testWidgets('点击预设「现在」正确回调当前时间戳', (tester) async {
      configureViewport(tester);
      int? selected;
      final before = DateTime.now().millisecondsSinceEpoch;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showProposalStartDatePicker(
                    context: context,
                    initialStartAt: null,
                    onDateSelected: (val) => selected = val,
                  );
                },
                child: const Text('Open Start Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Start Picker'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ElevatedButton)),
      );

      await tester.tap(find.text(l10n.aiPresetNow));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!, greaterThanOrEqualTo(before));
      expect(
        selected!,
        lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch + 1000),
      );
    });

    testWidgets('点击预设「今天 14:00」正确计算并触发回调', (tester) async {
      configureViewport(tester);
      int? selected;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showProposalStartDatePicker(
                    context: context,
                    initialStartAt: null,
                    onDateSelected: (val) => selected = val,
                  );
                },
                child: const Text('Open Start Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Start Picker'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ElevatedButton)),
      );

      await tester.tap(find.text(l10n.aiPresetToday14));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(selected!);
      expect(dt.hour, 14);
      expect(dt.minute, 0);
    });

    testWidgets('initialStartAt 非空时展示清除按钮，点击触发 null 回调', (tester) async {
      configureViewport(tester);
      int? selected = 1727776800000;
      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showProposalStartDatePicker(
                    context: context,
                    initialStartAt: selected,
                    onDateSelected: (val) => selected = val,
                  );
                },
                child: const Text('Open Start Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Start Picker'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ElevatedButton)),
      );

      expect(find.text(l10n.aiClearStartDate), findsOneWidget);

      await tester.tap(find.text(l10n.aiClearStartDate));
      await tester.pumpAndSettle();

      expect(selected, isNull);
      expect(find.text(l10n.aiSetStartDate), findsNothing);
    });

    testWidgets('暗色模式下 Container 使用 surfaceCardDark 背景', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(
        buildApp(
          themeMode: ThemeMode.dark,
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showProposalStartDatePicker(
                    context: context,
                    initialStartAt: null,
                    onDateSelected: (_) {},
                  );
                },
                child: const Text('Open Dark Picker'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dark Picker'));
      await tester.pumpAndSettle();

      final containerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final box = w.decoration as BoxDecoration;
          return box.color == AppTokens.surfaceCardDark;
        }
        return false;
      });

      expect(containerFinder, findsOneWidget);
    });
  });
}
