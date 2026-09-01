// M3 标签视图测试（FR-TAG-01 / FR-VIEW-04）。
//
// 覆盖：
// 1. sortTagsByName 纯函数：大小写不敏感排序；
// 2. 标签列表按名称（不区分大小写）排序；
// 3. 新建标签（FAB 对话框输入名称 + 保存 → 出现在列表）；
// 4. 空名称被拒；
// 5. 重名标签被拒（SnackBar 提示出现，列表不变）；
// 6. 删除标签 → 列表移除，关联任务仍在（FR-TAG-03 级联解除）；
// 7. 行菜单编辑对话框预填名称；
// 8. 详情页任务列表正确 + 状态筛选只显示选中状态；
// 9. 详情页任务点击跳转任务页。
//
// 说明：widget 测试用 StreamController 覆盖 tagsStreamProvider（避免 drift
// 流在 fake_async 下的残留 Timer，与 task_tree_test 的 override 约定一致）；
// 真实排序函数 sortTagsByName 在 provider 与纯函数测试中都得到覆盖。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/features/tags/tags_detail_page.dart';
import 'package:todo/features/tags/tags_page.dart';
import 'package:todo/shared/widgets/modern_checkbox.dart';
import 'package:todo/shared/widgets/simple_task_tile.dart';
import '../../helpers/db_test_setup.dart';

/// 构造测试用 Tag。
Tag _tag(String id, String name, {int color = 0xFF4A6CF7}) => Tag(
  id: id,
  name: name,
  color: color,
  sortOrder: 0,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

/// 打开内存测试 DB + Repository。
Future<TodoRepository> _openRepo() async {
  final db = openTestDatabase();
  return TodoRepository(database: db);
}

/// 统一 pump：ProviderScope（Repository + 流覆盖）+ GoRouter + 本地化。
///
/// [tags] 为标签列表初始值（须已按名称排序）；[tagTasks] 为详情页某标签下的任务；
/// [allActiveTasks] 为全量未删除任务（详情页用它构建父子索引，含未打标签的任务）。
/// 返回 [tagsStreamProvider] 的控制器，供测试在增删后推送更新。
Future<StreamController<List<Tag>>> _pump(
  WidgetTester tester, {
  required String initialLocation,
  required TodoRepository repo,
  List<Tag> tags = const [],
  List<Project> projects = const [],
  Map<String, List<Task>> tagTasks = const {},
  List<Task> allActiveTasks = const [],
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cache = AppSettingsCache();
  final tagsController = StreamController<List<Tag>>();
  addTearDown(tagsController.close);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/tags', builder: (_, _) => const TagsPage()),
      GoRoute(
        path: '/tags/:id',
        builder: (_, state) =>
            TagsDetailPage(tagId: state.pathParameters['id']!),
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
        tagsStreamProvider.overrideWith((ref) => tagsController.stream),
        projectsStreamProvider.overrideWith((ref) => Stream.value(projects)),
        tagTasksProvider.overrideWith(
          (ref, tagId) => Stream.value(tagTasks[tagId] ?? const <Task>[]),
        ),
        allActiveTasksProvider.overrideWith(
          (ref) => Stream.value(allActiveTasks),
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
  tagsController.add(tags);
  await tester.pumpAndSettle();
  return tagsController;
}

/// 从 DB 读取标签并排序（生产排序函数）。
Future<List<Tag>> _sortedTags(TodoRepository repo) async =>
    sortTagsByName(await repo.tags.getAll());

void main() {
  setUp(() {
    // No locale set → defaults to zh (Chinese).
  });

  group('sortTagsByName', () {
    test('大小写不敏感排序', () {
      final sorted = sortTagsByName([
        _tag('w', 'Work'),
        _tag('a', 'apple'),
        _tag('z', 'Zebra'),
      ]);
      expect(sorted.map((t) => t.name).toList(), ['apple', 'Work', 'Zebra']);
    });

    test('同键（大小写差异）按原始名称二次排序', () {
      final sorted = sortTagsByName([_tag('a', 'work'), _tag('b', 'Work')]);
      expect(sorted.first.name, 'Work'); // 'W'(87) < 'w'(119)。
      expect(sorted.last.name, 'work');
    });
  });

  // ────────────────────────────────────────
  // 标签列表页（TagsPage）
  // ────────────────────────────────────────
  group('TagsPage', () {
    testWidgets('空列表显示空态 + 新建按钮', (tester) async {
      final repo = await _openRepo();
      await _pump(tester, initialLocation: '/tags', repo: repo);

      expect(find.text('还没有标签'), findsOneWidget);
      expect(find.text('新建标签'), findsOneWidget);
    });

    testWidgets('列表按名称不区分大小写排序', (tester) async {
      final repo = await _openRepo();
      await repo.createTag(name: 'Work', color: 0xFF4A6CF7);
      await repo.createTag(name: 'apple', color: 0xFF5CAB7D);
      await repo.createTag(name: 'Zebra', color: 0xFFEF6B6B);

      await _pump(
        tester,
        initialLocation: '/tags',
        repo: repo,
        tags: await _sortedTags(repo),
      );

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('Zebra'), findsOneWidget);
      // apple < Work < Zebra（大小写不敏感）。
      final appleY = tester.getTopLeft(find.text('apple')).dy;
      final workY = tester.getTopLeft(find.text('Work')).dy;
      final zebraY = tester.getTopLeft(find.text('Zebra')).dy;
      expect(appleY, lessThan(workY));
      expect(workY, lessThan(zebraY));
    });

    testWidgets('FAB 新建标签：输入名称保存后出现在列表', (tester) async {
      final repo = await _openRepo();
      await repo.createTag(name: '已有', color: 0xFF4A6CF7);

      final controller = await _pump(
        tester,
        initialLocation: '/tags',
        repo: repo,
        tags: await _sortedTags(repo),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '重要');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);

      // 推送更新后的列表。
      controller.add(await _sortedTags(repo));
      await tester.pumpAndSettle();

      expect(find.text('重要'), findsOneWidget);
      expect(find.text('已有'), findsOneWidget);
      final tags = await repo.tags.getAll();
      expect(tags.map((t) => t.name), contains('重要'));
    });

    testWidgets('新建对话框：空名称被拒', (tester) async {
      final repo = await _openRepo();
      await repo.createTag(name: '已有', color: 0xFF4A6CF7);

      await _pump(
        tester,
        initialLocation: '/tags',
        repo: repo,
        tags: await _sortedTags(repo),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('标题不能为空'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('重名标签被拒并提示', (tester) async {
      final repo = await _openRepo();
      await repo.createTag(name: 'Work', color: 0xFF4A6CF7);

      await _pump(
        tester,
        initialLocation: '/tags',
        repo: repo,
        tags: await _sortedTags(repo),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'work');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // SnackBar 提示「已存在」（Repository 撞名异常文案）。
      expect(find.textContaining('已存在'), findsOneWidget);
      // 列表仍只有原来的 Work，未新增。
      expect(find.text('Work'), findsOneWidget);
      final tags = await repo.tags.getAll();
      expect(tags.length, 1);

      // 等 SnackBar 自动消失，避免残留 Timer。
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('删除标签：列表移除，关联任务保留（FR-TAG-03）', (tester) async {
      final repo = await _openRepo();
      final project = await repo.createProject(name: '项目A', color: 0xFF4A6CF7);
      final task = await repo.createTask(projectId: project.id, title: '关联任务');
      final tag = await repo.createTag(name: 'Work', color: 0xFF4A6CF7);
      await repo.tags.setTaskTags(task.id, [tag.id]);

      final controller = await _pump(
        tester,
        initialLocation: '/tags',
        repo: repo,
        tags: await _sortedTags(repo),
      );

      // 行尾菜单 → 删除。
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 确认对话框：删除标签确认 + 警告。
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('确定要删除标签'), findsOneWidget);
      expect(find.textContaining('任务本身不会被删除'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 推送更新后的列表 → 空态。
      controller.add(await _sortedTags(repo));
      await tester.pumpAndSettle();
      expect(find.text('还没有标签'), findsOneWidget);

      // 标签已删除，任务仍在，关联已解除。
      expect(await repo.tags.getAll(), isEmpty);
      final remaining = await repo.tasks.getActiveById(task.id);
      expect(remaining, isNotNull);
      expect(await repo.tags.tagIdsForTask(task.id), isEmpty);
    });

    testWidgets('行菜单编辑：对话框预填名称', (tester) async {
      final repo = await _openRepo();
      await repo.createTag(name: 'Work', color: 0xFF4A6CF7);

      await _pump(
        tester,
        initialLocation: '/tags',
        repo: repo,
        tags: await _sortedTags(repo),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('编辑标签'), findsOneWidget);
      // 名称预填。
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller
            ?.text,
        'Work',
      );
    });
  });

  // ────────────────────────────────────────
  // 标签详情页（TagsDetailPage）
  // ────────────────────────────────────────
  group('TagsDetailPage', () {
    testWidgets('标签不存在时显示空态', (tester) async {
      final repo = await _openRepo();
      await _pump(tester, initialLocation: '/tags/nonexistent', repo: repo);

      expect(find.text('还没有标签'), findsOneWidget);
    });

    testWidgets('列出该标签下任务，未关联任务不显示', (tester) async {
      final repo = await _openRepo();
      final project = await repo.createProject(name: '项目A', color: 0xFF4A6CF7);
      final tag = await repo.createTag(name: 'Work', color: 0xFF4A6CF7);
      final tagged1 = await repo.createTask(
        projectId: project.id,
        title: '待办任务',
        status: TaskStatus.todo,
      );
      final tagged2 = await repo.createTask(
        projectId: project.id,
        title: '已完成任务',
        status: TaskStatus.done,
      );
      final untagged = await repo.createTask(
        projectId: project.id,
        title: '无标签任务',
      );
      await repo.tags.setTaskTags(tagged1.id, [tag.id]);
      await repo.tags.setTaskTags(tagged2.id, [tag.id]);

      await _pump(
        tester,
        initialLocation: '/tags/${tag.id}',
        repo: repo,
        tags: await _sortedTags(repo),
        tagTasks: {tag.id: await repo.tags.tasksForTag(tag.id)},
      );

      expect(find.text('待办任务'), findsOneWidget);
      expect(find.text('已完成任务'), findsOneWidget);
      expect(find.text('无标签任务'), findsNothing);
      // 引用 untagged 避免 unused 警告。
      expect(untagged.id, isNotEmpty);
    });

    testWidgets('状态筛选只显示选中状态', (tester) async {
      final repo = await _openRepo();
      final project = await repo.createProject(name: '项目A', color: 0xFF4A6CF7);
      final tag = await repo.createTag(name: 'Work', color: 0xFF4A6CF7);
      final todoTask = await repo.createTask(
        projectId: project.id,
        title: '待办任务',
        status: TaskStatus.todo,
      );
      final doneTask = await repo.createTask(
        projectId: project.id,
        title: '已完成任务',
        status: TaskStatus.done,
      );
      await repo.tags.setTaskTags(todoTask.id, [tag.id]);
      await repo.tags.setTaskTags(doneTask.id, [tag.id]);

      await _pump(
        tester,
        initialLocation: '/tags/${tag.id}',
        repo: repo,
        tags: await _sortedTags(repo),
        tagTasks: {tag.id: await repo.tags.tasksForTag(tag.id)},
      );

      // 默认「全部」：两条都在。
      expect(find.text('待办任务'), findsOneWidget);
      expect(find.text('已完成任务'), findsOneWidget);

      // 筛选「待办」。
      await tester.tap(find.text('全部'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('待办').last);
      await tester.pumpAndSettle();

      expect(find.text('待办任务'), findsOneWidget);
      expect(find.text('已完成任务'), findsNothing);
    });

    testWidgets('点击任务行跳转任务页', (tester) async {
      final repo = await _openRepo();
      final project = await repo.createProject(name: '项目A', color: 0xFF4A6CF7);
      final tag = await repo.createTag(name: 'Work', color: 0xFF4A6CF7);
      final task = await repo.createTask(projectId: project.id, title: '待办任务');
      await repo.tags.setTaskTags(task.id, [tag.id]);

      await _pump(
        tester,
        initialLocation: '/tags/${tag.id}',
        repo: repo,
        tags: await _sortedTags(repo),
        tagTasks: {tag.id: await repo.tags.tasksForTag(tag.id)},
      );

      await tester.tap(find.text('待办任务'));
      await tester.pumpAndSettle();

      expect(find.text('task:${task.id}'), findsOneWidget);
    });

    testWidgets('被标记父任务（子任务未标记）：勾选禁用且按派生状态显示', (tester) async {
      final repo = await _openRepo();
      final project = await repo.createProject(name: '项目A', color: 0xFF4A6CF7);
      final tag = await repo.createTag(name: 'Work', color: 0xFF4A6CF7);
      // 父任务打标签，直接子任务不打（标签按任务关联，不传播到子树）。
      final parent = await repo.createTask(
        projectId: project.id,
        title: '父任务',
        status: TaskStatus.todo,
      );
      final child = await repo.createTask(
        projectId: project.id,
        parentId: parent.id,
        title: '子任务',
        status: TaskStatus.done,
      );
      await repo.tags.setTaskTags(parent.id, [tag.id]);

      await _pump(
        tester,
        initialLocation: '/tags/${tag.id}',
        repo: repo,
        tags: await _sortedTags(repo),
        // tagTasks 仅含父任务（子任务未打标签）；allActiveTasks 含父子，
        // 供详情页用全量流构建 children 索引。
        tagTasks: {
          tag.id: [parent],
        },
        allActiveTasks: [parent, child],
      );

      // 父任务显示；未打标签的子任务不显示。
      expect(find.text('父任务'), findsOneWidget);
      expect(find.text('子任务'), findsNothing);

      // 父任务有子任务 → 勾选禁用（ModernCheckbox onChanged == null）。
      final checkbox = tester.widget<ModernCheckbox>(
        find.descendant(
          of: find.byType(SimpleTaskTile),
          matching: find.byType(ModernCheckbox),
        ),
      );
      expect(checkbox.onChanged, isNull);
      // 子任务全 done → 父任务按派生状态显示为已完成（checked=true）。
      expect(checkbox.checked, isTrue);
    });
  });
}
