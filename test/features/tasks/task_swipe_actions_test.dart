// 移动端任务行滑动操作测试（50-ui-ux.md §5.8）。
//
// 覆盖：右滑阈值触发完成/取消完成（completedAt 由仓库维护）、未过阈值不触发、
// 父任务（派生状态）右滑禁用、左滑露出优先级/标签按钮即点即改、桌面平台无手势层。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/features/tasks/widgets/task_swipe_wrapper.dart';
import '../../helpers/db_test_setup.dart';

const _rowKey = Key('row');

Task _task(
  String id, {
  String parentId = '',
  TaskStatus status = TaskStatus.todo,
  TaskPriority priority = TaskPriority.none,
  int? completedAt,
}) => Task(
  id: id,
  projectId: 'p1',
  parentId: parentId.isEmpty ? null : parentId,
  title: '任务 $id',
  description: '',
  notes: '',
  status: status,
  completedAt: completedAt,
  priority: priority,
  sortOrder: 0,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

/// 泵入一个包着占位行的 [TaskSwipeWrapper]（真实内存 DB），返回 db/repo。
///
/// [tags] 注入 `tagsStreamProvider` 覆盖：真实 drift watch 流在 fake_async 下
/// 会残留 Timer 导致 pumpAndSettle 无法收敛（与 task_tree_test 同因）。
Future<(AppDatabase, TodoRepository)> _pumpWrapper(
  WidgetTester tester, {
  required Task task,
  required bool hasChildren,
  TargetPlatform platform = TargetPlatform.android,
  List<Tag> tags = const [],
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final db = openTestDatabase();
  addTearDown(db.close);
  final repo = TodoRepository(database: db);

  await db
      .into(db.projects)
      .insertOnConflictUpdate(
        ProjectsCompanion.insert(
          id: 'p1',
          name: 'P1',
          color: 0,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  await db.into(db.tasks).insertOnConflictUpdate(task);
  for (final tag in tags) {
    await db.into(db.tags).insertOnConflictUpdate(tag);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todoRepositoryProvider.overrideWithValue(repo),
        tagsStreamProvider.overrideWith((ref) => Stream.value(tags)),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: TaskSwipeWrapper(
            task: task,
            hasChildren: hasChildren,
            isDone: task.status == TaskStatus.done,
            child: SizedBox(key: _rowKey, height: 56, width: double.infinity),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (db, repo);
}

Future<Task> _readTask(AppDatabase db, String id) =>
    (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('右滑超过阈值直接切换为完成，completedAt 由仓库写入', (tester) async {
    final (db, _) = await _pumpWrapper(
      tester,
      task: _task('t1'),
      hasChildren: false,
    );

    await tester.drag(
      find.byKey(_rowKey),
      const Offset(100, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    final row = await _readTask(db, 't1');
    expect(row.status, TaskStatus.done);
    expect(row.completedAt, isNotNull);
  });

  testWidgets('右滑未过阈值不触发完成', (tester) async {
    final (db, _) = await _pumpWrapper(
      tester,
      task: _task('t1'),
      hasChildren: false,
    );

    await tester.drag(
      find.byKey(_rowKey),
      const Offset(40, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    final row = await _readTask(db, 't1');
    expect(row.status, TaskStatus.todo);
    expect(row.completedAt, isNull);
  });

  testWidgets('已完成任务右滑切回未完成并清除 completedAt', (tester) async {
    final (db, _) = await _pumpWrapper(
      tester,
      task: _task('t1', status: TaskStatus.done, completedAt: 12345),
      hasChildren: false,
    );

    await tester.drag(
      find.byKey(_rowKey),
      const Offset(100, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    final row = await _readTask(db, 't1');
    expect(row.status, TaskStatus.todo);
    expect(row.completedAt, isNull);
  });

  testWidgets('有子任务的任务右滑被禁用（状态由子任务派生）', (tester) async {
    final (db, _) = await _pumpWrapper(
      tester,
      task: _task('t1'),
      hasChildren: true,
    );

    await tester.drag(
      find.byKey(_rowKey),
      const Offset(100, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    final row = await _readTask(db, 't1');
    expect(row.status, TaskStatus.todo);
    expect(row.completedAt, isNull);
  });

  testWidgets('左滑露出快捷按钮，优先级即点即改', (tester) async {
    final (db, _) = await _pumpWrapper(
      tester,
      task: _task('t1'),
      hasChildren: false,
    );

    // 左滑展开（露出 2 个按钮，reveal 宽 2×64=128）。
    await tester.drag(
      find.byKey(_rowKey),
      const Offset(-140, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('优先级'), findsOneWidget);
    expect(find.byTooltip('标签'), findsOneWidget);

    // 点优先级按钮 → 底部弹层 → 选「高」。
    await tester.tap(find.byTooltip('优先级'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('高'));
    await tester.pumpAndSettle();

    final row = await _readTask(db, 't1');
    expect(row.priority, TaskPriority.high);
  });

  testWidgets('左滑标签按钮弹出快捷弹层，勾选即写回 DB', (tester) async {
    const tag = Tag(
      id: 'tg1',
      name: '工作',
      color: 0xFF22C55E,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    final (db, repo) = await _pumpWrapper(
      tester,
      task: _task('t1'),
      hasChildren: false,
      tags: const [tag],
    );

    await tester.drag(
      find.byKey(_rowKey),
      const Offset(-140, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('标签'), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('工作'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await repo.tags.tagIdsForTask('t1'), ['tg1']);

    // 再点取消 → 关联清除（即点即改双向生效）。
    await tester.tap(find.text('工作'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await repo.tags.tagIdsForTask('t1'), isEmpty);

    // 关闭弹层，释放流监听。
    await tester.tap(find.text('完成'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await _readTask(db, 't1').then((r) => r.id), 't1');
  });

  testWidgets('桌面平台不注册滑动手势层', (tester) async {
    final (db, repo) = await _pumpWrapper(
      tester,
      task: _task('t1'),
      hasChildren: false,
      platform: TargetPlatform.windows,
    );

    await tester.drag(
      find.byKey(_rowKey),
      const Offset(-140, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    // SwipeActions 组件仍在树中但桌面分支直接返回 child，无手势层、无按钮露出。
    expect(find.byTooltip('优先级'), findsNothing);
    expect(find.byTooltip('标签'), findsNothing);
    expect(await repo.tags.tagIdsForTask('t1'), isEmpty);

    await tester.drag(
      find.byKey(_rowKey),
      const Offset(100, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    final row = await _readTask(db, 't1');
    expect(row.status, TaskStatus.todo);
  });
}
