// M3 日历视图测试（FR-VIEW-02 / docs/10-requirements.md §9.2）。
//
// 覆盖：
// 1. 月视图：跨天任务在区间内每天显示；仅 endAt 任务只显示在截止日；
//    无时间任务不出现；月外任务不出现；
// 2. 点含任务日期格 → 底部弹层列出该任务；
// 3. 底部 FAB → 打开新建任务底部弹窗（TaskCreateSheet）且预填该日 09:00 的 startAt；
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

import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/features/calendar/calendar_page.dart';
import 'package:todo/features/calendar/calendar_providers.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import 'package:todo/features/tasks/widgets/task_create_sheet.dart';
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
  priority: TaskPriority.none,
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

  final cache = AppSettingsCache();
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
        appSettingsCacheProvider.overrideWithValue(cache),
        todoRepositoryProvider.overrideWithValue(repo),
        calendarStateProvider.overrideWith(() => _FixedCalendarNotifier(state)),
        calendarBucketsProvider.overrideWith((ref) => bucketsController.stream),
        // 页面直接 watch 的 drift 流/查询也须覆盖，否则 fake_async 下残留
        // Timer（allActiveTasksProvider 是真实 drift watch 流）。
        allActiveTasksProvider.overrideWith(
          (ref) => Stream.value(const <Task>[]),
        ),
        taskTagsProvider.overrideWith(
          (ref, taskId) => Stream.value(const <Tag>[]),
        ),
        // 新建弹窗 watch 的 drift 流也须覆盖（fake_async 下避免残留 Timer）。
        projectsStreamProvider.overrideWithValue(
          AsyncData([
            Project(
              id: 'inbox',
              name: '收件箱',
              color: 0xFF6C5CE7,
              description: '',
              sortOrder: 0,
              createdAt: 0,
              updatedAt: 0,
              deleted: 0,
            ),
          ]),
        ),
        tagsStreamProvider.overrideWithValue(const AsyncData(<Tag>[])),
        // 收件箱身份固定（新建任务的 projectId 来源；真实 drift 查询走事件循环，
        // 会让 pumpAndSettle 在 push 前提前返回，造成时序竞争）。
        inboxProjectProvider.overrideWithValue(
          AsyncData(
            Project(
              id: 'inbox',
              name: '收件箱',
              color: 0xFF6C5CE7,
              description: '',
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
    // No locale set → defaults to zh (Chinese).
  });

  testWidgets('月视图：跨天/仅截止日/无时间/月外任务的显示规则与分桶（§9.2）', (tester) async {
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
    final buckets = buildCalendarBuckets(
      tasks,
      _fixedState(CalendarMode.month),
    );
    expect(buckets[DateTime(2026, 8, 5)]?.map((t) => t.id), ['A']);
    expect(buckets[DateTime(2026, 8, 6)]?.map((t) => t.id), ['A', 'B']);
    expect(buckets[DateTime(2026, 8, 7)]?.map((t) => t.id), ['A']);
    expect(buckets[DateTime(2026, 8, 8)], isNull);
    expect(buckets[DateTime(2026, 9, 1)], isNull);

    final controller = await _pump(
      tester,
      repo: repo,
      state: _fixedState(CalendarMode.month),
    );
    controller.add(buckets);
    await tester.pumpAndSettle();

    // 点击 8/5：议程列表联动显示任务 A
    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);

    // 点击 8/6：议程列表联动显示任务 A 和 B
    await tester.tap(find.text('6').first);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    // 点击 8/7：议程列表联动显示任务 A
    await tester.tap(find.text('7').first);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsNothing);

    // 无时间任务 C 和月外任务 G 不在任何日历桶中出现
    expect(find.text('C'), findsNothing);
    expect(find.text('G'), findsNothing);
  });

  testWidgets('点选含任务日期格 → 联动议程列表列出该任务', (tester) async {
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

    // 点击 8/6 日期格
    await tester.tap(find.text('6').first);
    await tester.pumpAndSettle();

    // 议程联动区出现：任务行 A、B（新建入口统一走底部 FAB，头部无按钮）。
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('点击底部 FAB → 打开新建任务底部弹窗并预填选中日 09:00 的 startAt', (tester) async {
    final db = openTestDatabase();
    final repo = TodoRepository(database: db);
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

    // 点选空日期格（8/15，周六）
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();

    // 新建入口 = 底部 FAB（与选中日联动）
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // 打开的是底部弹窗
    expect(find.byType(TaskCreateSheet), findsOneWidget);
    expect(find.textContaining('new:'), findsNothing);

    // 预填该日 09:00 的 startAt（UTC 毫秒）到表单
    final ctx = tester.element(find.byType(TaskCreateSheet));
    final formState = ProviderScope.containerOf(ctx).read(taskFormProvider);
    expect(formState.projectId, 'inbox');
    expect(formState.startAt, _ms(2026, 8, 15, 9));
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
    final buckets = buildCalendarBuckets(tasks, state);
    expect(buckets[DateTime(2026, 8, 11)]?.map((t) => t.id), ['E']);
    expect(buckets[DateTime(2026, 8, 12)]?.map((t) => t.id), ['E', 'D']);
    expect(buckets[DateTime(2026, 8, 13)]?.map((t) => t.id), ['E']);
    expect(buckets[DateTime(2026, 8, 5)], isNull);

    final controller = await _pump(tester, repo: repo, state: state);
    controller.add(buckets);
    await tester.pumpAndSettle();

    // 默认选中 8/11：议程区显示 E
    expect(find.text('E'), findsOneWidget);
    expect(find.text('D'), findsNothing);
    expect(find.text('A'), findsNothing);

    // 点击 8/12：议程区显示 E 和 D
    await tester.tap(find.text('12').first);
    await tester.pumpAndSettle();
    expect(find.text('E'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('上下滑动日历视口切换月视图与周视图', (tester) async {
    final db = openTestDatabase();
    final repo = TodoRepository(database: db);
    final state = _fixedState(CalendarMode.month);

    final controller = await _pump(tester, repo: repo, state: state);
    controller.add(buildCalendarBuckets([], state));
    await tester.pumpAndSettle();

    // 初始为月视图：顶栏融合显示单处「2026年8月」
    expect(find.text('2026年8月'), findsOneWidget);

    // 星期表头纯正中文
    for (final label in ['一', '二', '三', '四', '五', '六', '日']) {
      expect(find.text(label), findsOneWidget);
    }

    // 向上滑动手势 -> 收起为周视图
    await tester.drag(find.text('11').first, const Offset(0, -100));
    await tester.pumpAndSettle();

    // 切换为周视图：顶栏显示周期区间「8月10日 – 8月16日」
    expect(find.text('8月10日 – 8月16日'), findsOneWidget);

    // 向下滑动手势 -> 展开为月视图
    await tester.drag(find.text('11').first, const Offset(0, 100));
    await tester.pumpAndSettle();

    // 恢复为月视图
    expect(find.text('2026年8月'), findsOneWidget);
  });

  testWidgets('三点更多菜单：展开显示「回到今天」、「切换为周视图」、「搜索」并可交互', (tester) async {
    final db = openTestDatabase();
    final repo = TodoRepository(database: db);
    final state = _fixedState(CalendarMode.month);

    final controller = await _pump(tester, repo: repo, state: state);
    controller.add(buildCalendarBuckets([], state));
    await tester.pumpAndSettle();

    // 点击右上角三点菜单
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('回到今天'), findsOneWidget);
    expect(find.text('切换为周视图'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);

    // 点击切换为周视图
    await tester.tap(find.text('切换为周视图'));
    await tester.pumpAndSettle();

    expect(find.text('8月10日 – 8月16日'), findsOneWidget);
  });

  testWidgets('日历打开新建任务弹窗 → 未输入标题点击遮罩可正常关闭', (tester) async {
    final db = openTestDatabase();
    final repo = TodoRepository(database: db);
    final state = _fixedState(CalendarMode.month);

    final controller = await _pump(tester, repo: repo, state: state);
    controller.add(buildCalendarBuckets([], state));
    await tester.pumpAndSettle();

    // 点选 8/15
    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();

    // 打开新建任务（底部 FAB）
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCreateSheet), findsOneWidget);

    // 点击遮罩空白部分
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 弹窗正常关闭，未被阻拦，且无任务落库
    expect(find.byType(TaskCreateSheet), findsNothing);
    expect(await repo.tasks.getAllByProject('inbox'), isEmpty);
  });
}
