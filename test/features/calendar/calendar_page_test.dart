// M3 日历视图测试（FR-VIEW-02 / docs/10-requirements.md §9.2）。
//
// 覆盖：
// 1. 月视图：跨天任务在区间内每天显示；仅 endAt 任务只显示在截止日；
//    无时间任务不出现；月外任务不出现；
// 2. 点含任务日期格 → 底部弹层列出该任务 +「新建」入口；
// 3. 弹层「新建」→ 跳转 /task/new 且携带该日 09:00 的 startAt 参数；
// 4. 周视图：周区间内每天列出任务（跨天任务出现在多天）。
//
// 说明：widget 测试用 StreamController 覆盖 calendarBucketsProvider（避免 drift
// 流在 fake_async 下的残留 Timer，与 tags/task_tree 测试的 override 约定一致）；
// 真实分桶逻辑 buildCalendarBuckets / calendarDaysForTask 通过纯函数构造桶数据
// 得到覆盖。日历状态用固定日期（2026-08-11，周二）保证确定性：
// 2026 年 8 月 1 日为周六；8/10–8/16 为完整一周。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/features/calendar/calendar_page.dart';
import 'package:todo/features/calendar/calendar_providers.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import '../../helpers/db_test_setup.dart';

/// 固定日历状态（2026-08-11，周二；月/周视图由参数决定）。
CalendarState _fixedState(CalendarMode mode) =>
    CalendarState(selectedDate: DateTime(2026, 8, 11), mode: mode);

/// 固定日期状态的 Notifier（override calendarStateProvider 用）。
class _FixedCalendarNotifier extends CalendarNotifier {
  _FixedCalendarNotifier(this._fixed);

  final CalendarState _fixed;

  @override
  CalendarState build() => _fixed;
}

/// 构造测试用任务。
Task _task(
  String id, {
  int? startAt,
  int? endAt,
  TaskStatus status = TaskStatus.todo,
}) => Task(
  id: id,
  projectId: 'p1',
  title: id,
  description: '',
  notes: '',
  startAt: startAt,
  endAt: endAt,
  status: status,
  sortOrder: 0,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

int _ms(int y, int m, int d, [int hour = 0, int minute = 0]) =>
    DateTime(y, m, d, hour, minute).toUtc().millisecondsSinceEpoch;

/// 统一 pump：ProviderScope（Repository + 流覆盖）+ GoRouter + 本地化（zh）。
/// 返回 [calendarBucketsProvider] 的控制器，供测试推送分桶数据。
Future<StreamController<Map<DateTime, List<Task>>>> _pump(
  WidgetTester tester, {
  required TodoRepository repo,
  required CalendarState state,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prefs = await SharedPreferences.getInstance();
  final bucketsController = StreamController<Map<DateTime, List<Task>>>();
  addTearDown(bucketsController.close);

  final router = GoRouter(
    initialLocation: '/calendar',
    routes: [
      GoRoute(path: '/calendar', builder: (_, _) => const CalendarPage()),
      // 注意：/task/new 必须声明在 /task/:id 之前（与真实 router.dart 一致），
      // 否则会被 :id 参数路由影子匹配（id='new'）。
      GoRoute(
        path: '/task/new',
        builder: (_, state) =>
            Scaffold(body: Text('new:${state.uri.queryParameters['startAt']}')),
      ),
      GoRoute(
        path: '/task/:id',
        builder: (_, state) =>
            Scaffold(body: Text('task:${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        todoRepositoryProvider.overrideWithValue(repo),
        calendarStateProvider.overrideWith(() => _FixedCalendarNotifier(state)),
        calendarBucketsProvider.overrideWith((ref) => bucketsController.stream),
        // 页面直接 watch 的 drift 流/查询也须覆盖，否则 fake_async 下残留
        // Timer（allActiveTasksProvider 是真实 drift watch 流）。
        allActiveTasksProvider.overrideWith(
          (ref) => Stream.value(const <Task>[]),
        ),
        taskTagsProvider.overrideWith((ref, taskId) async => const <Tag>[]),
        // 收件箱身份固定（新建任务的 projectId 来源；真实 drift 查询走事件循环，
        // 会让 pumpAndSettle 在 push 前提前返回，造成时序竞争）。
        inboxProjectProvider.overrideWithValue(
          AsyncData(
            Project(
              id: 'inbox',
              name: '收件箱',
              color: 0xFF6C5CE7,
              sortOrder: 0,
              createdAt: 0,
              updatedAt: 0,
              deleted: 0,
            ),
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  return bucketsController;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('月视图：跨天/仅截止日/无时间/月外任务的显示规则（§9.2）', (tester) async {
    final db = openTestDatabase();
    final repo = TodoRepository(database: db);

    // A：8/5–8/7 跨天区间 → 3 天；B：仅 endAt 8/6 → 只 8/6；C：无时间 → 不出现；
    // G：9/1 截止（月外）→ 不出现。
    final tasks = [
      _task('A', startAt: _ms(2026, 8, 5, 9), endAt: _ms(2026, 8, 7, 18)),
      _task('B', endAt: _ms(2026, 8, 6, 18)),
      _task('C'),
      _task('G', endAt: _ms(2026, 9, 1, 18)),
    ];
    final controller = await _pump(
      tester,
      repo: repo,
      state: _fixedState(CalendarMode.month),
    );
    controller.add(
      buildCalendarBuckets(tasks, _fixedState(CalendarMode.month)),
    );
    await tester.pumpAndSettle();

    expect(find.text('A'), findsNWidgets(3)); // 8/5、8/6、8/7 三个日期格
    expect(find.text('B'), findsOneWidget); // 仅 8/6
    expect(find.text('C'), findsNothing); // 无时间任务
    expect(find.text('G'), findsNothing); // 月外任务
  });

  testWidgets('点含任务日期格 → 弹层列出该任务并可「新建」', (tester) async {
    final db = openTestDatabase();
    final repo = TodoRepository(database: db);

    final tasks = [
      _task('A', startAt: _ms(2026, 8, 5, 9), endAt: _ms(2026, 8, 6, 18)),
      _task('B', endAt: _ms(2026, 8, 6, 18)),
    ];
    final controller = await _pump(
      tester,
      repo: repo,
      state: _fixedState(CalendarMode.month),
    );
    controller.add(
      buildCalendarBuckets(tasks, _fixedState(CalendarMode.month)),
    );
    await tester.pumpAndSettle();

    // 点 8/6 的日期格（该格显示任务 B 标题）。
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    // 弹层出现：任务行 + 「新建」按钮。
    expect(find.text('新建任务'), findsOneWidget);
    expect(find.text('B'), findsNWidgets(2)); // 日期格 + 弹层行
  });

  testWidgets('弹层「新建」→ 跳转 /task/new 并携带该日 09:00 的 startAt', (tester) async {
    final db = openTestDatabase();
    final repo = TodoRepository(database: db);
    // 桶里至少有一个任务，月网格才会渲染（空桶 → EmptyState 而非网格）。
    final tasks = [_task('X', endAt: _ms(2026, 8, 6, 18))];
    final controller = await _pump(
      tester,
      repo: repo,
      state: _fixedState(CalendarMode.month),
    );
    controller.add(
      buildCalendarBuckets(tasks, _fixedState(CalendarMode.month)),
    );
    await tester.pumpAndSettle();

    // 点一个空日期格（8/15，周六）：弹层只有「新建」。
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(find.text('新建任务'), findsOneWidget);

    await tester.tap(find.text('新建任务'));
    await tester.pumpAndSettle();

    // 路由落到 /task/new，startAt = 2026-08-15 09:00 本地转 UTC 毫秒。
    final expected = _ms(2026, 8, 15, 9).toString();
    expect(find.text('new:$expected'), findsOneWidget);
  });

  testWidgets('周视图：周区间内每天列出任务，跨天任务出现在多天', (tester) async {
    final db = openTestDatabase();
    final repo = TodoRepository(database: db);

    // 周区间 8/10（周一）– 8/16（周日）。E：8/11–8/13 跨天 → 3 天；
    // D：仅 endAt 8/12 → 只 8/12；A（8/5–8/7）在周区间外 → 不出现。
    final tasks = [
      _task('E', startAt: _ms(2026, 8, 11, 9), endAt: _ms(2026, 8, 13, 18)),
      _task('D', endAt: _ms(2026, 8, 12, 18)),
      _task('A', startAt: _ms(2026, 8, 5, 9), endAt: _ms(2026, 8, 7, 18)),
    ];
    final state = _fixedState(CalendarMode.week);
    final controller = await _pump(tester, repo: repo, state: state);
    controller.add(buildCalendarBuckets(tasks, state));
    await tester.pumpAndSettle();

    expect(find.text('E'), findsNWidgets(3)); // 8/11、8/12、8/13
    expect(find.text('D'), findsOneWidget); // 仅 8/12
    expect(find.text('A'), findsNothing); // 周区间外
  });
}
