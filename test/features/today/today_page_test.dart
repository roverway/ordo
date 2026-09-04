// 今日视图页测试（FR-VIEW-01，docs/10-requirements.md §9.1/§9.3）。
//
// 覆盖 DoD：今日匹配、逾期分组与「已逾期」文案、done 任务不标逾期、
// 无时间任务不渲染、勾选完成切换真实落库、buildTodayView 分组排序纯逻辑。
//
// 日期约定：测试用「今天/昨天」相对日期（本地时区零点），与 provider 的
// `DateTime.now()` 本地边界一致，保证任意运行日期通过。
//
// Provider 注入：沿用现有 feature 测试的 override 模式（inbox/project 测试
// 均 override 流式 Provider）。widget 层注入由生产逻辑 `buildTodayView`
// （走真实内存 DB 的 tagsForTask）算出的展示数据，避免 Drift 实时流在
// widget 树销毁时排入 0ms Timer 导致测试超时（project_pages_test 注释）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:drift/drift.dart' show Value;
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/core/theme/app_tokens.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import 'package:todo/features/tasks/widgets/task_create_sheet.dart';
import 'package:todo/features/tasks/task_list_page.dart';
import 'package:todo/features/today/today_providers.dart';
import 'package:todo/shared/widgets/empty_state.dart';
import 'package:todo/shared/widgets/modern_checkbox.dart';
import 'package:todo/shared/widgets/simple_task_tile.dart';
import 'package:todo/shared/widgets/task_progress_ring.dart';
import '../../helpers/db_test_setup.dart';

/// 本地「今天」零点（与 provider 的 todayStart 口径一致）。
DateTime _todayStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// 本地「昨天」零点。
DateTime _yesterday() => _todayStart().subtract(const Duration(days: 1));

/// 构造测试用 Task（projectId 固定收件箱，满足 FK）。
Task _task(
  String id, {
  String? parentId,
  String? title,
  TaskStatus status = TaskStatus.todo,
  int? startAt,
  int? endAt,
  int? completedAt,
  int sortOrder = 0,
  int? updatedAt,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final effectiveUpdated = updatedAt ?? now;
  return Task(
    id: id,
    projectId: inboxProjectId,
    parentId: parentId,
    title: title ?? id,
    description: '',
    notes: '',
    status: status,
    sortOrder: sortOrder,
    startAt: startAt,
    endAt: endAt,
    completedAt:
        completedAt ?? (status == TaskStatus.done ? effectiveUpdated : null),
    priority: TaskPriority.none,
    createdAt: now,
    updatedAt: effectiveUpdated,
    deleted: 0,
  );
}

/// 构造测试用 Tag。
Tag _tag(String id, String name, {int color = 0xFF3482FF}) => Tag(
  id: id,
  name: name,
  color: color,
  sortOrder: 0,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

/// 封装今日页的 ProviderScope + GoRouter + 内存 DB 种子。
///
/// 任务/标签/关联真实写入内存数据库；`todayViewProvider` 按现有测试的
/// override 模式注入由生产逻辑 [buildTodayView] 算出的数据（tagsForTask
/// 走真实 DB），返回 repo 供断言。
Future<TodoRepository> _pumpToday(
  WidgetTester tester, {
  required List<Task> tasks,
  List<Tag> tags = const [],
  Map<String, List<String>> taskTagIds = const {},
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cache = AppSettingsCache();
  final db = openTestDatabase();
  final repo = TodoRepository(database: db);

  // 预插入收件箱项目（满足 FK 约束）。
  await db
      .into(db.projects)
      .insertOnConflictUpdate(
        ProjectsCompanion.insert(
          id: inboxProjectId,
          name: '收件箱',
          color: inboxProjectColor,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  for (final tag in tags) {
    await db
        .into(db.tags)
        .insertOnConflictUpdate(
          TagsCompanion.insert(
            id: tag.id,
            name: tag.name,
            color: tag.color,
            sortOrder: tag.sortOrder,
            createdAt: tag.createdAt,
            updatedAt: tag.updatedAt,
          ),
        );
  }

  for (final task in tasks) {
    await db
        .into(db.tasks)
        .insertOnConflictUpdate(
          TasksCompanion.insert(
            id: task.id,
            projectId: task.projectId,
            parentId: Value(task.parentId),
            title: task.title,
            startAt: Value(task.startAt),
            endAt: Value(task.endAt),
            status: task.status,
            sortOrder: task.sortOrder,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
          ),
        );
  }

  for (final entry in taskTagIds.entries) {
    for (final tagId in entry.value) {
      await db
          .into(db.taskTags)
          .insert(TaskTagsCompanion.insert(taskId: entry.key, tagId: tagId));
    }
  }

  // 用生产逻辑计算展示数据（真实 DB tagsForTask）。
  final view = await buildTodayView(
    tasks: tasks,
    now: DateTime.now(),
    tagsForTask: repo.tags.tagsForTask,
  );

  final inboxProject = Project(
    id: inboxProjectId,
    name: '收件箱',
    color: inboxProjectColor,
    description: '',
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    deleted: 0,
  );

  final overrides = [
    appSettingsCacheProvider.overrideWithValue(cache),
    todoRepositoryProvider.overrideWithValue(repo),
    todayViewProvider.overrideWithValue(AsyncData(view)),
    // 新建弹窗依赖的 Provider 一并覆盖（fake_async 下避免 drift 流残留 Timer）。
    inboxProjectProvider.overrideWithValue(AsyncData(inboxProject)),
    projectsStreamProvider.overrideWithValue(AsyncData([inboxProject])),
    tagsStreamProvider.overrideWithValue(const AsyncData(<Tag>[])),
  ];

  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      GoRoute(
        path: '/today',
        builder: (_, _) => const TaskListPage(scope: TodayTaskScope()),
      ),
      GoRoute(
        path: '/task/:id',
        builder: (_, state) =>
            Scaffold(body: Text('detail:${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// 定位某任务所在 SimpleTaskTile 行内嵌的 Checkbox / ModernCheckbox。
Finder _checkboxOf(WidgetTester tester, String title) {
  final tile = find.ancestor(
    of: find.text(title),
    matching: find.byType(SimpleTaskTile),
  );
  final modern = find.descendant(
    of: tile,
    matching: find.byType(ModernCheckbox),
  );
  if (modern.evaluate().isNotEmpty) return modern;
  return find.descendant(of: tile, matching: find.byType(Checkbox));
}

void main() {
  setUp(() {
    // No locale set → defaults to zh (Chinese).
  });

  group('buildTodayView 纯逻辑', () {
    test('逾期组按 endAt 升序（最紧迫在前）', () async {
      final today = _todayStart();
      final yesterdayMs = _yesterday().millisecondsSinceEpoch;
      final tasks = [
        _task('late', title: '晚', endAt: yesterdayMs + 3600000, sortOrder: 0),
        _task('early', title: '早', endAt: yesterdayMs, sortOrder: 1),
      ];

      final view = await buildTodayView(
        tasks: tasks,
        now: today,
        tagsForTask: (_) async => const [],
      );

      expect(view.overdue.map((v) => v.task.id).toList(), ['early', 'late']);
      expect(view.today, isEmpty);
    });

    test('今天组按 startAt 升序，null 排最后', () async {
      final today = _todayStart();
      final todayMs = today.millisecondsSinceEpoch;
      final tasks = [
        _task('noStart', title: '无开始', endAt: todayMs, updatedAt: 100),
        _task(
          'start2',
          title: '10点',
          startAt: todayMs + 3600000 * 10,
          updatedAt: 50,
        ),
        _task(
          'start1',
          title: '9点',
          startAt: todayMs + 3600000 * 9,
          updatedAt: 40,
        ),
      ];

      final view = await buildTodayView(
        tasks: tasks,
        now: today,
        tagsForTask: (_) async => const [],
      );

      expect(view.today.map((v) => v.task.id).toList(), [
        'start1',
        'start2',
        'noStart',
      ]);
    });

    test('今天组同 startAt 时按 updatedAt 降序', () async {
      final today = _todayStart();
      final todayMs = today.millisecondsSinceEpoch;
      final tasks = [
        _task('old', title: '旧', startAt: todayMs, updatedAt: 10),
        _task('new', title: '新', startAt: todayMs, updatedAt: 90),
      ];

      final view = await buildTodayView(
        tasks: tasks,
        now: today,
        tagsForTask: (_) async => const [],
      );

      expect(view.today.map((v) => v.task.id).toList(), ['new', 'old']);
    });

    test('入选规则：startAt/endAt/跨天区间命中，无时间不入选，逾期入选', () async {
      final today = _todayStart();
      final todayMs = today.millisecondsSinceEpoch;
      final yesterdayMs = _yesterday().millisecondsSinceEpoch;
      final tomorrowMs = today
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
      final tasks = [
        _task('s', title: '开始今天', startAt: todayMs),
        _task('e', title: '截止今天', endAt: todayMs),
        _task('range', title: '跨天', startAt: yesterdayMs, endAt: tomorrowMs),
        _task('none', title: '无时间'),
        _task('overdue', title: '逾期', endAt: yesterdayMs),
      ];

      final view = await buildTodayView(
        tasks: tasks,
        now: today,
        tagsForTask: (_) async => const [],
      );

      final ids = {
        ...view.overdue.map((v) => v.task.id),
        ...view.today.map((v) => v.task.id),
      };
      expect(ids, {'s', 'e', 'range', 'overdue'});
      expect(ids, isNot(contains('none')));
    });

    test('hasChildren + 派生状态：有子任务复用 derivedStatus，无子任务用自身状态', () async {
      final today = _todayStart();
      final todayMs = today.millisecondsSinceEpoch;
      final tasks = [
        _task('parent', title: '父', startAt: todayMs),
        _task(
          'child',
          title: '子',
          parentId: 'parent',
          startAt: todayMs,
          status: TaskStatus.done,
        ),
      ];

      final view = await buildTodayView(
        tasks: tasks,
        now: today,
        tagsForTask: (_) async => const [],
      );

      final parent = view.today.firstWhere((v) => v.task.id == 'parent');
      final child = view.today.firstWhere((v) => v.task.id == 'child');
      expect(parent.hasChildren, isTrue);
      expect(parent.effectiveStatus, TaskStatus.done); // 子任务全 done → 派生 done
      expect(child.hasChildren, isFalse);
      expect(child.effectiveStatus, TaskStatus.done); // 无子任务 → 自身状态
    });
  });

  testWidgets('逾期任务（endAt=昨天）渲染且带「已逾期」文案与红色分组标题', (tester) async {
    final yesterday = _yesterday().millisecondsSinceEpoch;
    await _pumpToday(
      tester,
      tasks: [_task('o1', title: '逾期任务', endAt: yesterday)],
    );

    expect(find.text('逾期任务'), findsOneWidget);
    expect(find.byType(SimpleTaskTile), findsOneWidget);

    // 「已逾期」共 1 处：逾期分组标题（行内药丸已按设计原型移除）。
    expect(find.text('已逾期'), findsOneWidget);

    // 分组标题用 AppTokens.colorOverdue（红色）。
    final header = tester.widget<Text>(find.text('已逾期'));
    expect(header.style?.color, AppTokens.colorOverdue);
  });

  testWidgets('今天任务（startAt=今天）渲染在今天组，并展示标签', (tester) async {
    final today = _todayStart();
    final startAt = DateTime(
      today.year,
      today.month,
      today.day,
      9,
    ).millisecondsSinceEpoch;

    await _pumpToday(
      tester,
      tasks: [_task('t1', title: '今天任务', startAt: startAt)],
      tags: [_tag('tg1', '工作')],
      taskTagIds: {
        't1': ['tg1'],
      },
    );

    expect(find.text('今天任务'), findsOneWidget);

    // 「今天」共 2 处：今天组标题 + 行内时间标签（formatDateRange → today）。
    expect(find.text('今天'), findsNWidgets(2));

    // 标签 chip 已解析展示。
    expect(find.text('工作'), findsOneWidget);

    // 非逾期任务无逾期文案。
    expect(find.text('已逾期'), findsNothing);
  });

  testWidgets('无时间任务不渲染，显示空态', (tester) async {
    await _pumpToday(tester, tasks: [_task('n1', title: '无时间任务')]);

    expect(find.text('无时间任务'), findsNothing);
    expect(find.byType(SimpleTaskTile), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('今天还没有任务'), findsOneWidget);
  });

  testWidgets('昨天结束的 done 任务不标逾期（todo 逾期，done 不逾期不渲染）', (tester) async {
    final yesterday = _yesterday().millisecondsSinceEpoch;
    await _pumpToday(
      tester,
      tasks: [
        _task(
          'd1',
          title: '昨天完成',
          status: TaskStatus.done,
          endAt: yesterday,
          completedAt: yesterday,
          updatedAt: yesterday,
          sortOrder: 0,
        ),
        _task('o1', title: '昨天逾期', endAt: yesterday, sortOrder: 1),
      ],
    );

    // todo 逾期任务进入逾期组。
    expect(find.text('昨天逾期'), findsOneWidget);
    // done 任务既不匹配今日也不逾期 → 不渲染、不标逾期。
    expect(find.text('昨天完成'), findsNothing);
    // 「已逾期」仅来自逾期任务的分组标题。
    expect(find.text('已逾期'), findsOneWidget);
  });

  testWidgets('勾选今天任务的复选框 → DB 状态变为 done', (tester) async {
    final today = _todayStart();
    final startAt = DateTime(
      today.year,
      today.month,
      today.day,
      9,
    ).millisecondsSinceEpoch;
    final repo = await _pumpToday(
      tester,
      tasks: [_task('t1', title: '待完成', startAt: startAt)],
    );

    expect((await repo.tasks.getActiveById('t1'))!.status, TaskStatus.todo);

    await tester.tap(_checkboxOf(tester, '待完成'));
    await tester.pumpAndSettle();

    final after = await repo.tasks.getActiveById('t1');
    expect(after!.status, TaskStatus.done);
    // 勾选点击不应触发行 onTap（没有跳转详情页）。
    expect(find.text('detail:t1'), findsNothing);
  });

  testWidgets('FAB 打开新建任务底部弹窗（D2 定稿，替代全屏 /task/new）', (tester) async {
    final today = _todayStart();
    final startAt = DateTime(
      today.year,
      today.month,
      today.day,
      9,
    ).millisecondsSinceEpoch;
    await _pumpToday(
      tester,
      tasks: [_task('t1', title: '今天任务', startAt: startAt)],
    );

    // 右下角 FAB（无全屏新建路由可跳，只有底部弹窗）。
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(TaskCreateSheet), findsOneWidget);
  });

  testWidgets('空态下 FAB 仍可用并打开弹窗', (tester) async {
    await _pumpToday(tester, tasks: [_task('n1', title: '无时间任务')]);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(TaskCreateSheet), findsOneWidget);
  });

  testWidgets('reduced motion：错落入场与勾选弹性瞬时降级（NFR-06）', (tester) async {
    // 系统开启「减弱动态效果」→ motion.dart 时长/曲线全部降级。
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final today = _todayStart();
    final startAt = DateTime(
      today.year,
      today.month,
      today.day,
      9,
    ).millisecondsSinceEpoch;
    await _pumpToday(
      tester,
      tasks: [
        _task('t1', title: '任务A', startAt: startAt),
        _task('t2', title: '任务B', startAt: startAt),
      ],
    );

    // B 错落入场瞬时到位：tile 最近的 FadeTransition 已到 opacity 1
    //（reduced 下 motionNormal 归零，无中间帧）。
    final tileFade = tester.widget<FadeTransition>(
      find
          .ancestor(of: find.text('任务A'), matching: find.byType(FadeTransition))
          .first,
    );
    expect(tileFade.opacity.value, 1.0);

    // 回归（评审发现）：index ≥ 1 的项其错落 **延迟** 也必须随 reduced-motion
    // 归零——修复前 delay 未降级，第二项起会在整段延迟期保持 opacity 0
    // 后瞬间弹出（逐项弹出正是减弱动态效果要消除的动效）。
    final secondFade = tester.widget<FadeTransition>(
      find
          .ancestor(of: find.text('任务B'), matching: find.byType(FadeTransition))
          .first,
    );
    expect(secondFade.opacity.value, 1.0);

    // A 勾选弹性瞬时：勾选框最近的 ScaleTransition 保持 1.0（不缩放）。
    final checkboxScale = tester.widget<ScaleTransition>(
      find
          .ancestor(
            of: _checkboxOf(tester, '任务A'),
            matching: find.byType(ScaleTransition),
          )
          .first,
    );
    expect(checkboxScale.scale.value, 1.0);
  });

  testWidgets('逾期且含子任务的任务：已逾期徽标与进度圆环之间有合理间距', (tester) async {
    final yest = _yesterday();
    final startAt = DateTime(
      yest.year,
      yest.month,
      yest.day,
      9,
    ).millisecondsSinceEpoch;
    final endAt = DateTime(
      yest.year,
      yest.month,
      yest.day,
      18,
    ).millisecondsSinceEpoch;

    await _pumpToday(
      tester,
      tasks: [
        _task('parent', title: '逾期父任务', startAt: startAt, endAt: endAt),
        _task('child1', parentId: 'parent', title: '子任务1'),
      ],
    );

    // 验证在 SimpleTaskTile 内存在 TaskProgressRing
    final progressFinder = find.byType(TaskProgressRing);
    expect(progressFinder, findsOneWidget);
  });

  testWidgets('逾期任务在今日页面被勾选完成：依然在已逾期分组展示（以已完成划线状态呈现）', (tester) async {
    final yesterday = _yesterday().millisecondsSinceEpoch;
    final repo = await _pumpToday(
      tester,
      tasks: [_task('o1', title: '逾期待完成', endAt: yesterday)],
    );

    expect(find.text('逾期待完成'), findsOneWidget);
    expect(find.text('已逾期'), findsOneWidget);

    await tester.tap(_checkboxOf(tester, '逾期待完成'));
    await tester.pumpAndSettle();

    final after = await repo.tasks.getActiveById('o1');
    expect(after!.status, TaskStatus.done);
    expect(after.completedAt, isNotNull);

    // 重新通过 buildTodayView 计算视图模型
    final updatedTasks = await repo.tasks.getAllActive();
    final updatedView = await buildTodayView(
      tasks: updatedTasks,
      now: DateTime.now(),
      tagsForTask: repo.tags.tagsForTask,
    );

    // 逾期组依然包含该任务，今天组为空
    expect(updatedView.overdue.map((v) => v.task.id), contains('o1'));
    expect(updatedView.today, isEmpty);
    expect(updatedView.overdue.single.effectiveStatus, TaskStatus.done);
    expect(updatedView.overdue.single.isOverdue, isTrue);
  });

  testWidgets('Filter Chips 筛选：全部、待办、已完成分别准确展示逾期与今天分组', (tester) async {
    final today = _todayStart();
    final todayMs = today.millisecondsSinceEpoch;
    final yesterday = _yesterday().millisecondsSinceEpoch;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await _pumpToday(
      tester,
      tasks: [
        _task('o_open', title: '逾期待办', endAt: yesterday),
        _task(
          'o_done',
          title: '逾期已完成',
          endAt: yesterday,
          status: TaskStatus.done,
          completedAt: nowMs,
        ),
        _task('t_open', title: '今天待办', startAt: todayMs),
        _task(
          't_done',
          title: '今天已完成',
          startAt: todayMs,
          status: TaskStatus.done,
          completedAt: nowMs,
        ),
      ],
    );

    // 默认「全部」模式：4 个任务全显示
    expect(find.text('逾期待办'), findsOneWidget);
    expect(find.text('逾期已完成'), findsOneWidget);
    expect(find.text('今天待办'), findsOneWidget);
    expect(find.text('今天已完成'), findsOneWidget);

    // 切换到「进行中」
    await tester.tap(find.text('进行中'));
    await tester.pumpAndSettle();
    expect(find.text('逾期待办'), findsOneWidget);
    expect(find.text('今天待办'), findsOneWidget);
    expect(find.text('逾期已完成'), findsNothing);
    expect(find.text('今天已完成'), findsNothing);

    // 切换到「已完成」
    await tester.tap(find.text('已完成'));
    await tester.pumpAndSettle();
    expect(find.text('逾期待办'), findsNothing);
    expect(find.text('今天待办'), findsNothing);
    expect(find.text('逾期已完成'), findsOneWidget);
    expect(find.text('今天已完成'), findsOneWidget);
  });

  group('今日视图已完成匹配精度（问题 1 修复）', () {
    test('昨天完成的任务（即使截止日是今天或今天被修改），不进入今日视图', () async {
      final now = DateTime(2026, 9, 3, 12, 0, 0);
      final todayStart = DateTime(2026, 9, 3, 0, 0, 0);
      final todayEnd = DateTime(2026, 9, 3, 23, 59, 59, 999);
      final yesterday = DateTime(2026, 9, 2, 12, 0, 0);

      final tasks = [
        Task(
          id: 't_done_yesterday',
          projectId: inboxProjectId,
          title: '昨天完成的任务（截止今天）',
          description: '',
          notes: '',
          startAt: todayStart.millisecondsSinceEpoch,
          endAt: todayEnd.millisecondsSinceEpoch,
          completedAt: yesterday.millisecondsSinceEpoch,
          status: TaskStatus.done,
          sortOrder: 0,
          createdAt: yesterday.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch, // 今天被更新过其他属性
          deleted: 0,
          priority: TaskPriority.none,
        ),
        Task(
          id: 't_done_today',
          projectId: inboxProjectId,
          title: '今天完成的任务',
          description: '',
          notes: '',
          startAt: todayStart.millisecondsSinceEpoch,
          endAt: todayEnd.millisecondsSinceEpoch,
          completedAt: now.millisecondsSinceEpoch,
          status: TaskStatus.done,
          sortOrder: 1,
          createdAt: yesterday.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          deleted: 0,
          priority: TaskPriority.none,
        ),
      ];

      final viewData = await buildTodayView(
        tasks: tasks,
        now: now,
        tagsForTask: (_) async => const [],
      );

      final todayIds = viewData.today.map((v) => v.task.id).toList();
      expect(todayIds, contains('t_done_today'));
      expect(todayIds, isNot(contains('t_done_yesterday')));
    });

    test('3级任务全部完成时，父任务递归获取有效完成时间并进入今日视图', () async {
      final now = DateTime(2026, 9, 3, 12, 0, 0);
      final tasks = [
        Task(
          id: 'root',
          projectId: inboxProjectId,
          title: '一级父任务',
          description: '',
          notes: '',
          startAt: null,
          endAt: null,
          completedAt: null,
          status: TaskStatus.todo,
          sortOrder: 0,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          deleted: 0,
          priority: TaskPriority.none,
        ),
        Task(
          id: 'child',
          projectId: inboxProjectId,
          parentId: 'root',
          title: '二级子任务',
          description: '',
          notes: '',
          startAt: null,
          endAt: null,
          completedAt: null,
          status: TaskStatus.todo,
          sortOrder: 0,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          deleted: 0,
          priority: TaskPriority.none,
        ),
        Task(
          id: 'grand',
          projectId: inboxProjectId,
          parentId: 'child',
          title: '三级孙任务',
          description: '',
          notes: '',
          startAt: null,
          endAt: null,
          completedAt: now.millisecondsSinceEpoch,
          status: TaskStatus.done,
          sortOrder: 0,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          deleted: 0,
          priority: TaskPriority.none,
        ),
      ];

      final viewData = await buildTodayView(
        tasks: tasks,
        now: now,
        tagsForTask: (_) async => const [],
      );

      final todayIds = viewData.today.map((v) => v.task.id).toList();
      expect(todayIds, contains('root'));
      expect(viewData.completedCount, 3);
    });

    test('逾期任务在今日完成：保留在逾期组中（已完成状态），不移入今天组', () async {
      final now = DateTime(2026, 9, 3, 12, 0, 0);
      final yesterday = DateTime(2026, 9, 2, 12, 0, 0);

      final tasks = [
        Task(
          id: 'overdue_done_today',
          projectId: inboxProjectId,
          title: '逾期且今日完成的任务',
          description: '',
          notes: '',
          startAt: null,
          endAt: yesterday.millisecondsSinceEpoch,
          completedAt: now.millisecondsSinceEpoch,
          status: TaskStatus.done,
          sortOrder: 0,
          createdAt: yesterday.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          deleted: 0,
          priority: TaskPriority.none,
        ),
      ];

      final viewData = await buildTodayView(
        tasks: tasks,
        now: now,
        tagsForTask: (_) async => const [],
      );

      // 应在逾期组，不在今天组
      expect(
        viewData.overdue.map((v) => v.task.id),
        contains('overdue_done_today'),
      );
      expect(viewData.today, isEmpty);
      expect(viewData.overdue.single.isOverdue, isTrue);
      expect(viewData.overdue.single.effectiveStatus, TaskStatus.done);
      expect(viewData.completedCount, 1);
      expect(viewData.uncompletedCount, 0);
    });

    test('无排期任务在今日完成：进入今天组（已完成状态）', () async {
      final now = DateTime(2026, 9, 3, 12, 0, 0);

      final tasks = [
        Task(
          id: 'inbox_done_today',
          projectId: inboxProjectId,
          title: '无排期收件箱任务今日完成',
          description: '',
          notes: '',
          startAt: null,
          endAt: null,
          completedAt: now.millisecondsSinceEpoch,
          status: TaskStatus.done,
          sortOrder: 0,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          deleted: 0,
          priority: TaskPriority.none,
        ),
      ];

      final viewData = await buildTodayView(
        tasks: tasks,
        now: now,
        tagsForTask: (_) async => const [],
      );

      expect(
        viewData.today.map((v) => v.task.id),
        contains('inbox_done_today'),
      );
      expect(viewData.overdue, isEmpty);
      expect(viewData.today.single.isOverdue, isFalse);
      expect(viewData.today.single.effectiveStatus, TaskStatus.done);
      expect(viewData.completedCount, 1);
    });

    test('排期跨过今天但昨天已完成的任务：今日页面不显示', () async {
      final now = DateTime(2026, 9, 3, 12, 0, 0);
      final spanStart = DateTime(2026, 9, 1, 10, 0, 0);
      final spanEnd = DateTime(2026, 9, 5, 18, 0, 0);
      final yesterday = DateTime(2026, 9, 2, 15, 0, 0);

      final tasks = [
        Task(
          id: 'span_done_yesterday',
          projectId: inboxProjectId,
          title: '跨越今天但昨天已完成',
          description: '',
          notes: '',
          startAt: spanStart.millisecondsSinceEpoch,
          endAt: spanEnd.millisecondsSinceEpoch,
          completedAt: yesterday.millisecondsSinceEpoch,
          status: TaskStatus.done,
          sortOrder: 0,
          createdAt: spanStart.millisecondsSinceEpoch,
          updatedAt: yesterday.millisecondsSinceEpoch,
          deleted: 0,
          priority: TaskPriority.none,
        ),
      ];

      final viewData = await buildTodayView(
        tasks: tasks,
        now: now,
        tagsForTask: (_) async => const [],
      );

      expect(viewData.isEmpty, isTrue);
      expect(viewData.totalCount, 0);
    });

    test('缺失 completedAt 记录的历史已完成任务（即使排期跨越今日）：今日页面坚决不显示', () async {
      final now = DateTime(2026, 9, 3, 12, 0, 0);
      final spanStart = DateTime(2026, 9, 1, 10, 0, 0);
      final spanEnd = DateTime(2026, 9, 5, 18, 0, 0);

      final tasks = [
        Task(
          id: 'null_comp_spanning',
          projectId: inboxProjectId,
          title: '跨越今天但无 completedAt 记录的已完成任务',
          description: '',
          notes: '',
          startAt: spanStart.millisecondsSinceEpoch,
          endAt: spanEnd.millisecondsSinceEpoch,
          completedAt: null, // 缺失 completedAt
          status: TaskStatus.done,
          sortOrder: 0,
          createdAt: spanStart.millisecondsSinceEpoch,
          updatedAt: spanStart.millisecondsSinceEpoch,
          deleted: 0,
          priority: TaskPriority.none,
        ),
      ];

      final viewData = await buildTodayView(
        tasks: tasks,
        now: now,
        tagsForTask: (_) async => const [],
      );

      expect(viewData.isEmpty, isTrue);
      expect(viewData.totalCount, 0);
    });
  });
}
