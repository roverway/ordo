import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/quadrant/models/quadrant_models.dart';
import 'package:todo/features/quadrant/presentation/quadrant_page.dart';
import 'package:todo/features/quadrant/providers/quadrant_providers.dart';
import 'package:todo/features/quadrant/widgets/quadrant_card.dart';
import 'package:todo/features/quadrant/widgets/quadrant_focus_sheet.dart';
import 'package:todo/features/quadrant/widgets/quadrant_grid.dart';
import 'package:todo/features/quadrant/widgets/quadrant_list_view.dart';
import 'package:todo/features/quadrant/widgets/quadrant_scope_filter_sheet.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/shared/widgets/hero_progress_ring.dart';

import '../../helpers/db_test_setup.dart';

class _ListViewModeNotifier extends QuadrantViewModeNotifier {
  @override
  QuadrantViewMode build() => QuadrantViewMode.list;
}

Widget _buildTestApp({
  required Widget child,
  List<dynamic> overrides = const [],
}) {
  final cache = AppSettingsCache();
  return ProviderScope(
    overrides: [
      appSettingsCacheProvider.overrideWithValue(cache),
      ...overrides,
    ].cast(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: child,
    ),
  );
}

Task _createMockTask({
  required String id,
  required String title,
  String projectId = inboxProjectId,
  String? parentId,
  TaskPriority priority = TaskPriority.none,
  int? endAt,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Task(
    id: id,
    projectId: projectId,
    parentId: parentId,
    title: title,
    description: '',
    notes: '',
    status: TaskStatus.todo,
    sortOrder: 0,
    priority: priority,
    endAt: endAt,
    createdAt: now,
    updatedAt: now,
    deleted: 0,
  );
}

void main() {
  late AppDatabase db;
  late TodoRepository repo;

  setUp(() async {
    db = openTestDatabase();
    repo = TodoRepository(database: db);

    // 预插入默认收集箱项目（满足外键约束）
    await db
        .into(db.projects)
        .insertOnConflictUpdate(
          ProjectsCompanion.insert(
            id: inboxProjectId,
            name: '收集箱',
            color: inboxProjectColor,
            sortOrder: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('QuadrantPage 渲染 2x2 四象限网格与所有象限卡片', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final todayEnd = DateTime(
      now.year,
      now.month,
      now.day,
      18,
      0,
    ).millisecondsSinceEpoch;

    final tasks = [
      _createMockTask(
        id: 't1',
        title: '紧急重要任务',
        priority: TaskPriority.high,
        endAt: todayEnd,
      ),
      _createMockTask(id: 't2', title: '重要不紧急任务', priority: TaskPriority.high),
      _createMockTask(
        id: 't3',
        title: '紧急不重要任务',
        priority: TaskPriority.low,
        endAt: todayEnd,
      ),
      _createMockTask(id: 't4', title: '不重要不紧急任务', priority: TaskPriority.none),
    ];

    final defaultQuadrantData = buildQuadrantData(
      tasks: tasks,
      now: now,
      filter: const QuadrantFilterState(),
      taskTagsMap: const {},
      projects: const [],
    );

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          todoRepositoryProvider.overrideWithValue(repo),
          quadrantDataProvider.overrideWith(
            (ref) => Stream.value(defaultQuadrantData),
          ),
          projectsStreamProvider.overrideWithValue(const AsyncData([])),
          foldersStreamProvider.overrideWithValue(const AsyncData([])),
        ],
        child: const QuadrantPage(),
      ),
    );

    await tester.pumpAndSettle();

    // 页面结构完整性断言
    expect(find.byType(QuadrantGrid), findsOneWidget);
    expect(find.byType(QuadrantCard), findsNWidgets(4));

    // 验证各象限卡片内包含对应任务
    expect(find.text('紧急重要任务'), findsOneWidget);
    expect(find.text('重要不紧急任务'), findsOneWidget);
    expect(find.text('紧急不重要任务'), findsOneWidget);
    expect(find.text('不重要不紧急任务'), findsOneWidget);
  });

  testWidgets('点击右上角筛选按钮可弹出 QuadrantScopeFilterSheet 并筛选指定清单', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final projA = Project(
      id: 'proj-a',
      name: '清单A',
      color: 0xFF2563EB,
      description: '',
      sortOrder: 1,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    final projB = Project(
      id: 'proj-b',
      name: '清单B',
      color: 0xFF10B981,
      description: '',
      sortOrder: 2,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );

    final tasks = [
      _createMockTask(
        id: 't-a',
        title: '清单A的任务',
        projectId: 'proj-a',
        priority: TaskPriority.high,
      ),
      _createMockTask(
        id: 't-b',
        title: '清单B的任务',
        projectId: 'proj-b',
        priority: TaskPriority.high,
      ),
    ];

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          todoRepositoryProvider.overrideWithValue(repo),
          projectsStreamProvider.overrideWithValue(AsyncData([projA, projB])),
          foldersStreamProvider.overrideWithValue(const AsyncData([])),
          quadrantDataProvider.overrideWith((ref) {
            final filter = ref.watch(quadrantFilterProvider);
            return Stream.value(
              buildQuadrantData(
                tasks: tasks,
                now: DateTime.now(),
                filter: filter,
                taskTagsMap: const {},
                projects: [projA, projB],
              ),
            );
          }),
        ],
        child: const QuadrantPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('清单A的任务'), findsOneWidget);
    expect(find.text('清单B的任务'), findsOneWidget);

    // 点击右上角筛选按钮
    final filterBtn = find.byIcon(Icons.tune_rounded);
    expect(filterBtn, findsOneWidget);
    await tester.tap(filterBtn);
    await tester.pumpAndSettle();

    // 弹层展开
    expect(find.byType(QuadrantScopeFilterSheet), findsOneWidget);
    expect(find.text('范围筛选'), findsOneWidget);

    // 反选弹层中的「清单B」，使得仅剩下「清单A」生效
    final sheetProjB = find.descendant(
      of: find.byType(QuadrantScopeFilterSheet),
      matching: find.text('清单B'),
    );
    expect(sheetProjB, findsOneWidget);
    await tester.tap(sheetProjB);
    await tester.pumpAndSettle();

    // 点击完成关闭弹层
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    // 筛选后仅清单A的任务可见
    expect(find.text('清单A的任务'), findsOneWidget);
    expect(find.text('清单B的任务'), findsNothing);
  });

  testWidgets('点击象限聚焦按钮可打开 QuadrantFocusSheet 沉浸视图', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final tasks = [
      _createMockTask(
        id: 't-deep',
        title: '深度规划长远目标',
        priority: TaskPriority.high,
      ),
    ];

    final defaultQuadrantData = buildQuadrantData(
      tasks: tasks,
      now: now,
      filter: const QuadrantFilterState(),
      taskTagsMap: const {},
      projects: const [],
    );

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          todoRepositoryProvider.overrideWithValue(repo),
          quadrantDataProvider.overrideWith(
            (ref) => Stream.value(defaultQuadrantData),
          ),
          projectsStreamProvider.overrideWithValue(const AsyncData([])),
          foldersStreamProvider.overrideWithValue(const AsyncData([])),
        ],
        child: const QuadrantPage(),
      ),
    );

    await tester.pumpAndSettle();

    // 点击象限右上角的聚焦按钮
    final focusButtons = find.byIcon(Icons.fullscreen_outlined);
    expect(focusButtons, findsWidgets);

    await tester.tap(focusButtons.at(1)); // 第二个卡片 Q2
    await tester.pumpAndSettle();

    // 聚焦弹层出现，且包含该任务
    expect(find.byType(QuadrantFocusSheet), findsOneWidget);
    final focusTask = find.descendant(
      of: find.byType(QuadrantFocusSheet),
      matching: find.text('深度规划长远目标'),
    );
    expect(focusTask, findsOneWidget);
  });

  testWidgets('QuadrantPage 在 2x2 矩阵与聚焦列表之间切换', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final tasks = [
      _createMockTask(id: 't1', title: '重要紧急任务', priority: TaskPriority.high),
    ];
    final defaultQuadrantData = buildQuadrantData(
      tasks: tasks,
      now: now,
      filter: const QuadrantFilterState(),
      taskTagsMap: const {},
      projects: const [],
    );

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          todoRepositoryProvider.overrideWithValue(repo),
          quadrantDataProvider.overrideWith(
            (ref) => Stream.value(defaultQuadrantData),
          ),
          projectsStreamProvider.overrideWithValue(const AsyncData([])),
          foldersStreamProvider.overrideWithValue(const AsyncData([])),
        ],
        child: const QuadrantPage(),
      ),
    );

    await tester.pumpAndSettle();

    // 默认展示 2x2 矩阵
    expect(find.byType(QuadrantGrid), findsOneWidget);
    expect(find.byType(QuadrantListView), findsNothing);

    // 点击切换为聚焦列表
    await tester.tap(find.text('聚焦列表'));
    await tester.pumpAndSettle();

    expect(find.byType(QuadrantListView), findsOneWidget);
    expect(find.byType(QuadrantGrid), findsNothing);

    // 再次点击切换回 2x2 矩阵
    await tester.tap(find.text('2x2 矩阵'));
    await tester.pumpAndSettle();

    expect(find.byType(QuadrantGrid), findsOneWidget);
  });

  testWidgets('QuadrantListView 支持展示任务与头部进度环', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final tasks = [
      _createMockTask(id: 't1', title: '计划做长远事项', priority: TaskPriority.high),
    ];
    final defaultQuadrantData = buildQuadrantData(
      tasks: tasks,
      now: now,
      filter: const QuadrantFilterState(),
      taskTagsMap: const {},
      projects: const [],
    );

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          todoRepositoryProvider.overrideWithValue(repo),
          quadrantViewModeProvider.overrideWith(_ListViewModeNotifier.new),
          quadrantDataProvider.overrideWith(
            (ref) => Stream.value(defaultQuadrantData),
          ),
          projectsStreamProvider.overrideWithValue(const AsyncData([])),
          foldersStreamProvider.overrideWithValue(const AsyncData([])),
        ],
        child: const QuadrantPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(QuadrantListView), findsOneWidget);
    expect(find.text('计划做长远事项'), findsOneWidget);
    expect(find.byType(HeroProgressRing), findsOneWidget);
  });

  test('QuadrantActionController.moveTaskToQuadrant 严格保证只修改优先级和到期日', () async {
    // 插入测试清单
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-agile',
            name: '敏捷项目',
            color: 0xFF2563EB,
            sortOrder: 1,
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    final parent = await repo.createTask(title: '父任务', projectId: 'proj-agile');
    final subtask = await repo.createTask(
      title: '子任务',
      projectId: 'proj-agile',
      parentId: parent.id,
      priority: TaskPriority.none,
      endAt: null,
    );

    final controller = QuadrantActionController(repo);

    // 移入 Q1 (重要且紧急)
    await controller.moveTaskToQuadrant(subtask, QuadrantType.urgentImportant);

    final updated = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(subtask.id))).getSingleOrNull();

    expect(updated, isNotNull);
    // 优先级应变为 High
    expect(updated!.priority, equals(TaskPriority.high));
    // 截止日期应变为今天
    expect(updated.endAt, isNotNull);
    // 核心约束验证：projectId 与 parentId 绝对不能被篡改！
    expect(updated.projectId, equals('proj-agile'));
    expect(updated.parentId, equals(parent.id));
  });
}
