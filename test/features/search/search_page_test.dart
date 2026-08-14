// M3 搜索页测试（FR-VIEW-05 / FR-VIEW-06）。
//
// 覆盖：
// 1. 输入即搜防抖 300ms（<300ms 不出结果，到点后出现）；
// 2. 标题/描述/备注命中 + 大小写不敏感；
// 3. 有查询无结果 → emptySearch 空态；
// 4. 状态筛选叠加 → 只显示该状态；
// 5. 时间段「今天」筛选 → 今天区间任务出现、昨天任务不出现（仅 endAt 也命中）；
// 6. 标签筛选 → 只显示带该标签的任务；
// 7. 清除筛选 → 恢复全量；
// 8. 结果按 updatedAt 降序。
//
// 说明：widget 测试用 `Stream.value` 覆盖 allActiveTasksProvider / tagsStreamProvider
// （避免 drift 流在 fake_async 下的残留 Timer，与 tags_page_test 的约定一致）；
// 真实的查询/筛选流水线（searchResultsProvider + 防抖 + 筛选状态）全程运行，
// 标签关联查询走真实内存 DB（repo.tags.tasksForTag）。

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/search/search_page.dart';
import 'package:todo/features/search/search_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/shared/widgets/empty_state.dart';
import 'package:todo/shared/widgets/simple_task_tile.dart';
import '../../helpers/db_test_setup.dart';

/// 构造测试用 Task。
Task _task(
  String id, {
  String title = '',
  String description = '',
  String notes = '',
  TaskStatus status = TaskStatus.todo,
  int? startAt,
  int? endAt,
  int updatedAt = 0,
}) => Task(
  id: id,
  projectId: 'p1',
  parentId: null,
  title: title,
  description: description,
  notes: notes,
  status: status,
  startAt: startAt,
  endAt: endAt,
  sortOrder: 0,
  priority: TaskPriority.none,
  createdAt: 0,
  updatedAt: updatedAt,
  deleted: 0,
);

/// 打开内存测试 DB + Repository。
Future<TodoRepository> _openRepo() async {
  final db = openTestDatabase();
  return TodoRepository(database: db);
}

/// 预插入项目（满足 FK 约束）。
Future<void> _seedProject(TodoRepository repo) async {
  await repo.database
      .into(repo.database.projects)
      .insertOnConflictUpdate(
        ProjectsCompanion.insert(
          id: 'p1',
          name: 'P1',
          color: 0xFF4A6CF7,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
      );
}

/// 预插入任务（显式控制 updatedAt 等字段）。
Future<void> _insertTask(TodoRepository repo, Task t) async {
  await repo.database
      .into(repo.database.tasks)
      .insertOnConflictUpdate(
        TasksCompanion.insert(
          id: t.id,
          projectId: t.projectId,
          title: t.title,
          description: Value(t.description),
          notes: Value(t.notes),
          status: t.status,
          sortOrder: t.sortOrder,
          createdAt: t.createdAt,
          updatedAt: t.updatedAt,
          startAt: Value(t.startAt),
          endAt: Value(t.endAt),
        ),
      );
}

/// 预插入标签。
Future<void> _insertTag(TodoRepository repo, Tag tag) async {
  await repo.database
      .into(repo.database.tags)
      .insertOnConflictUpdate(
        TagsCompanion.insert(
          id: tag.id,
          name: tag.name,
          color: tag.color,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
      );
}

/// 统一 pump：ProviderScope（Repository + 流覆盖）+ GoRouter + 本地化。
///
/// [tasks] 按 DAO 语义（updatedAt 降序）排序后作为 allActiveTasksProvider 的流值。
Future<void> _pumpSearch(
  WidgetTester tester, {
  required TodoRepository repo,
  List<Task> tasks = const [],
  List<Tag> tags = const [],
}) async {
  tester.view.physicalSize = const Size(900, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cache = AppSettingsCache();

  // 镜像 DAO 排序（watchAllActive 按 updatedAt 降序）。
  final sorted = List<Task>.from(tasks)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(path: '/search', builder: (_, _) => const SearchPage()),
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
        allActiveTasksProvider.overrideWith((ref) => Stream.value(sorted)),
        tagsStreamProvider.overrideWith((ref) => Stream.value(tags)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  // 初始流数据到达 + 首帧。
  await tester.pump();
  await tester.pump();
}

/// 输入查询并等待防抖触发（300ms）+ 结果流事件传播 + UI 重建。
Future<void> _typeQuery(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tester.pump();
}

/// 结果列表中的任务标题（按显示顺序）。
List<String> _displayedTitles(WidgetTester tester) => tester
    .widgetList<SimpleTaskTile>(find.byType(SimpleTaskTile))
    .map((w) => w.task.title)
    .toList();

void main() {
  setUp(() {
    // No locale set → defaults to zh (Chinese).
  });

  testWidgets('输入即搜：防抖 300ms 后结果出现', (tester) async {
    final repo = await _openRepo();
    await _seedProject(repo);
    final t1 = _task('t1', title: '买牛奶', updatedAt: 100);
    await _insertTask(repo, t1);

    await _pumpSearch(tester, repo: repo, tasks: [t1]);

    // 空查询：提示空态。
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byIcon(Icons.search), findsWidgets);
    expect(find.text('买牛奶'), findsNothing);

    // 输入后 <300ms：防抖未触发，结果不出现。
    await tester.enterText(find.byType(TextField), '牛奶');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('买牛奶'), findsNothing);

    // 累计 ≥300ms：防抖触发，结果出现。
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(find.text('买牛奶'), findsOneWidget);
  });

  testWidgets('标题/描述/备注命中 + 大小写不敏感', (tester) async {
    final repo = await _openRepo();
    await _seedProject(repo);
    final tTitle = _task('t1', title: 'Buy Milk', updatedAt: 100);
    final tDesc = _task(
      't2',
      title: '无关任务',
      description: 'Whole milk from the store',
      updatedAt: 200,
    );
    final tNotes = _task(
      't3',
      title: '任务三',
      notes: 'remember salt',
      updatedAt: 300,
    );
    final tMiss = _task('t4', title: '完全无关', updatedAt: 400);
    await _insertTask(repo, tTitle);
    await _insertTask(repo, tDesc);
    await _insertTask(repo, tNotes);
    await _insertTask(repo, tMiss);

    await _pumpSearch(
      tester,
      repo: repo,
      tasks: [tTitle, tDesc, tNotes, tMiss],
    );

    // 标题命中。
    await _typeQuery(tester, 'milk');
    expect(find.text('Buy Milk'), findsOneWidget);
    expect(find.text('任务三'), findsNothing);

    // 描述命中。
    await _typeQuery(tester, 'store');
    expect(find.text('无关任务'), findsOneWidget);

    // 备注命中。
    await _typeQuery(tester, 'salt');
    expect(find.text('任务三'), findsOneWidget);
    expect(find.text('Buy Milk'), findsNothing);

    // 大小写不敏感。
    await _typeQuery(tester, 'BUY');
    expect(find.text('Buy Milk'), findsOneWidget);
    expect(find.text('无关任务'), findsNothing);
  });

  testWidgets('有查询无结果 → emptySearch 空态', (tester) async {
    final repo = await _openRepo();
    await _seedProject(repo);
    final t1 = _task('t1', title: '买牛奶', updatedAt: 100);
    await _insertTask(repo, t1);

    await _pumpSearch(tester, repo: repo, tasks: [t1]);

    await _typeQuery(tester, '不存在的关键词');

    expect(find.text('未找到相关内容'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
  });

  testWidgets('状态筛选叠加 → 只显示该状态', (tester) async {
    final repo = await _openRepo();
    await _seedProject(repo);
    final todo = _task(
      'a',
      title: '开会-A',
      status: TaskStatus.todo,
      updatedAt: 300,
    );
    final done = _task(
      'b',
      title: '开会-B',
      status: TaskStatus.done,
      updatedAt: 200,
    );
    final prog = _task(
      'c',
      title: '开会-C',
      status: TaskStatus.inProgress,
      updatedAt: 100,
    );
    await _insertTask(repo, todo);
    await _insertTask(repo, done);
    await _insertTask(repo, prog);

    await _pumpSearch(tester, repo: repo, tasks: [todo, done, prog]);

    await _typeQuery(tester, '开会');
    expect(find.text('开会-A'), findsOneWidget);
    expect(find.text('开会-B'), findsOneWidget);
    expect(find.text('开会-C'), findsOneWidget);

    // 状态下拉 →「已完成」。
    await tester.tap(find.byType(DropdownButton<TaskStatus?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已完成').last);
    await tester.pumpAndSettle();

    expect(find.text('开会-B'), findsOneWidget);
    expect(find.text('开会-A'), findsNothing);
    expect(find.text('开会-C'), findsNothing);
  });

  testWidgets('时间段「今天」筛选：今天任务出现、昨天任务不出现（仅 endAt 命中）', (tester) async {
    final now = DateTime.now();
    final todayNoon = DateTime(now.year, now.month, now.day, 12);
    final yesterdayNoon = todayNoon.subtract(const Duration(days: 1));

    final repo = await _openRepo();
    await _seedProject(repo);
    // 仅 startAt 在今天。
    final startToday = _task(
      'a',
      title: '任务-今天开始',
      startAt: todayNoon.millisecondsSinceEpoch,
      updatedAt: 100,
    );
    // 仅 endAt 在今天（inTimeRange 修正：仅 endAt 也应命中）。
    final endToday = _task(
      'b',
      title: '任务-今天截止',
      endAt: todayNoon.millisecondsSinceEpoch,
      updatedAt: 200,
    );
    // 昨天截止 → 不应出现。
    final endYesterday = _task(
      'c',
      title: '任务-昨天截止',
      endAt: yesterdayNoon.millisecondsSinceEpoch,
      updatedAt: 300,
    );
    // 无时间任务 → 不参与时间段筛选。
    final noTime = _task('d', title: '任务-无时间', updatedAt: 400);
    await _insertTask(repo, startToday);
    await _insertTask(repo, endToday);
    await _insertTask(repo, endYesterday);
    await _insertTask(repo, noTime);

    await _pumpSearch(
      tester,
      repo: repo,
      tasks: [startToday, endToday, endYesterday, noTime],
    );

    await _typeQuery(tester, '任务');
    expect(find.text('任务-今天开始'), findsOneWidget);
    expect(find.text('任务-今天截止'), findsOneWidget);
    expect(find.text('任务-昨天截止'), findsOneWidget);
    expect(find.text('任务-无时间'), findsOneWidget);

    // 时间段下拉 →「今天」。
    await tester.tap(find.byType(DropdownButton<TimeRange>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今天').last);
    await tester.pumpAndSettle();

    expect(find.text('任务-今天开始'), findsOneWidget);
    expect(find.text('任务-今天截止'), findsOneWidget);
    expect(find.text('任务-昨天截止'), findsNothing);
    expect(find.text('任务-无时间'), findsNothing);
  });

  testWidgets('标签筛选 → 只显示带该标签的任务', (tester) async {
    final repo = await _openRepo();
    await _seedProject(repo);
    final tag = Tag(
      id: 'tag1',
      name: '工作',
      color: 0xFF4A6CF7,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    await _insertTag(repo, tag);
    final tagged = _task('a', title: '开会甲', updatedAt: 100);
    final untagged = _task('b', title: '开会乙', updatedAt: 200);
    await _insertTask(repo, tagged);
    await _insertTask(repo, untagged);
    await repo.tags.setTaskTags(tagged.id, [tag.id]);

    await _pumpSearch(
      tester,
      repo: repo,
      tasks: [tagged, untagged],
      tags: [tag],
    );

    await _typeQuery(tester, '开会');
    expect(find.text('开会甲'), findsOneWidget);
    expect(find.text('开会乙'), findsOneWidget);

    // 标签下拉 →「工作」。
    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作').last);
    await tester.pumpAndSettle();

    expect(find.text('开会甲'), findsOneWidget);
    expect(find.text('开会乙'), findsNothing);
  });

  testWidgets('清除筛选 → 恢复全量', (tester) async {
    final repo = await _openRepo();
    await _seedProject(repo);
    final todo = _task(
      'a',
      title: '开会-A',
      status: TaskStatus.todo,
      updatedAt: 300,
    );
    final done = _task(
      'b',
      title: '开会-B',
      status: TaskStatus.done,
      updatedAt: 200,
    );
    final prog = _task(
      'c',
      title: '开会-C',
      status: TaskStatus.inProgress,
      updatedAt: 100,
    );
    await _insertTask(repo, todo);
    await _insertTask(repo, done);
    await _insertTask(repo, prog);

    await _pumpSearch(tester, repo: repo, tasks: [todo, done, prog]);

    await _typeQuery(tester, '开会');
    expect(find.text('开会-A'), findsOneWidget);
    expect(find.text('开会-B'), findsOneWidget);
    expect(find.text('开会-C'), findsOneWidget);

    // 应用状态筛选 → 只剩已完成。
    await tester.tap(find.byType(DropdownButton<TaskStatus?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已完成').last);
    await tester.pumpAndSettle();
    expect(find.text('开会-B'), findsOneWidget);
    expect(find.text('开会-A'), findsNothing);
    expect(find.text('开会-C'), findsNothing);

    // 清除筛选 → 恢复全量。
    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();

    expect(find.text('开会-A'), findsOneWidget);
    expect(find.text('开会-B'), findsOneWidget);
    expect(find.text('开会-C'), findsOneWidget);
    expect(find.text('清除筛选'), findsNothing);
  });

  testWidgets('结果按 updatedAt 降序', (tester) async {
    final repo = await _openRepo();
    await _seedProject(repo);
    final old = _task('a', title: '任务-旧', updatedAt: 100);
    final newest = _task('b', title: '任务-新', updatedAt: 300);
    final mid = _task('c', title: '任务-中', updatedAt: 200);
    await _insertTask(repo, old);
    await _insertTask(repo, newest);
    await _insertTask(repo, mid);

    // 乱序传入，验证页面按 updatedAt 降序展示。
    await _pumpSearch(tester, repo: repo, tasks: [old, mid, newest]);

    await _typeQuery(tester, '任务');

    expect(_displayedTitles(tester), ['任务-新', '任务-中', '任务-旧']);
  });
}
