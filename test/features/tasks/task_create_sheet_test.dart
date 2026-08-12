// 新建任务底部弹窗测试（55-ui-redesign-proposal.md §4.1 D2）。
//
// 覆盖：结构渲染（顶部清单名/标题输入/选项行）、自动保存（输入标题后关闭 →
// 复用 taskFormProvider.save 落库）、空内容关闭不落库、有内容但标题为空 →
// 提示并停留、优先级选择持久化、收件箱解析期间输入不被清空（评审问题 2 回归）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import 'package:todo/features/tasks/widgets/task_create_sheet.dart';
import '../../helpers/db_test_setup.dart';

/// 打开底部弹窗（项目固定 p1，满足 FK）。
///
/// [projectId] 传 null 时走「缺省收件箱」路径；[inboxOverride] 可控制
/// inboxProjectProvider 的解析时机（评审问题 2 的时序回归测试用）。
Future<void> _openSheet(
  WidgetTester tester, {
  required TodoRepository repo,
  String? projectId = 'p1',
  String? parentId,
  Future<Project> Function(Ref ref)? inboxOverride,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prefs = await SharedPreferences.getInstance();
  final project = projectId == null
      ? null
      : Project(
          id: projectId,
          name: '测试项目',
          color: 0xFF3482FF,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
          deleted: 0,
        );

  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    todoRepositoryProvider.overrideWithValue(repo),
    projectsStreamProvider.overrideWithValue(
      AsyncData(project == null ? const <Project>[] : [project]),
    ),
    tagsStreamProvider.overrideWithValue(const AsyncData(<Tag>[])),
    if (inboxOverride != null) inboxProjectProvider.overrideWith(inboxOverride),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => TaskCreateSheet.show(
                  context,
                  projectId: projectId,
                  parentId: parentId,
                ),
                child: const Text('打开弹窗'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开弹窗'));
  await tester.pumpAndSettle();
}

/// 准备内存 DB + Repository，并预插入项目（FK）。
Future<TodoRepository> _repo(String projectId) async {
  final db = openTestDatabase();
  await db
      .into(db.projects)
      .insertOnConflictUpdate(
        ProjectsCompanion.insert(
          id: projectId,
          name: '测试项目',
          color: 0xFF3482FF,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  return TodoRepository(database: db);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('结构渲染：顶部清单名 + 标题输入 + 三个选项行', (tester) async {
    final repo = await _repo('p1');
    await _openSheet(tester, repo: repo);

    // 顶部清单名。
    expect(find.text('测试项目'), findsOneWidget);
    // 标题输入（占位符「任务标题」）。
    expect(find.text('任务标题'), findsOneWidget);
    // 选项行。
    expect(find.text('日期与提醒'), findsOneWidget);
    expect(find.text('优先级'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    // 子任务区（1 级任务展示）。
    expect(find.text('子任务'), findsOneWidget);
    expect(find.text('添加子任务'), findsOneWidget);
  });

  testWidgets('自动保存：输入标题后点击遮罩关闭 → 任务落库', (tester) async {
    final repo = await _repo('p1');
    await _openSheet(tester, repo: repo);

    await tester.enterText(find.byType(TextField).first, '买牛奶');
    // 点击遮罩（弹窗上方空白处）→ PopScope 拦截 → 自动保存 → 关闭。
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 弹窗已关闭。
    expect(find.byType(TaskCreateSheet), findsNothing);
    // 任务已创建。
    final all = await repo.tasks.getAllByProject('p1');
    expect(all, hasLength(1));
    expect(all.single.title, '买牛奶');
    expect(all.single.priority, TaskPriority.none);
  });

  testWidgets('空内容关闭 → 不落库', (tester) async {
    final repo = await _repo('p1');
    await _openSheet(tester, repo: repo);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(TaskCreateSheet), findsNothing);
    expect(await repo.tasks.getAllByProject('p1'), isEmpty);
  });

  testWidgets('有内容但标题为空 → 提示「标题不能为空」并停留在弹窗', (tester) async {
    final repo = await _repo('p1');
    await _openSheet(tester, repo: repo);

    // 设置日期（产生内容但标题为空）。
    await tester.tap(find.text('日期与提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();

    // 关闭 → 校验失败 → SnackBar + 弹窗仍在。
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('标题不能为空'), findsOneWidget);
    expect(find.byType(TaskCreateSheet), findsOneWidget);
    // 未落库。
    expect(await repo.tasks.getAllByProject('p1'), isEmpty);
  });

  testWidgets('优先级选择持久化：选「高」并保存 → 任务 priority = high', (tester) async {
    final repo = await _repo('p1');
    await _openSheet(tester, repo: repo);

    await tester.tap(find.text('优先级'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('高'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '重要任务');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    final all = await repo.tasks.getAllByProject('p1');
    expect(all, hasLength(1));
    expect(all.single.priority, TaskPriority.high);
  });

  testWidgets('收件箱解析期间输入标题 → 不被清空（评审问题 2 回归）', (tester) async {
    final repo = await _repo('p1');
    // 模拟冷启动：收件箱 ensure 挂起（首次打开弹窗、行尚未创建）。
    // 先造好收件箱行（生产 ensureInboxProject 语义），供自动保存落库。
    await repo.ensureInboxProject('收件箱');
    final completer = Completer<Project>();
    final inboxProject = Project(
      id: inboxProjectId,
      name: '收件箱',
      color: inboxProjectColor,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    // 不传 projectId → 缺省收件箱路径。
    await _openSheet(
      tester,
      repo: repo,
      projectId: null,
      inboxOverride: (_) => completer.future,
    );

    // 在收件箱 ensure 解析完成前输入标题（旧实现会在 resetForNew 时静默清空）。
    await tester.enterText(find.byType(TextField).first, '等待期间输入');
    await tester.pump();

    // ensure 完成 → 仅校正项目字段，用户输入应保留。
    completer.complete(inboxProject);
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(TaskCreateSheet));
    final formState = ProviderScope.containerOf(ctx).read(taskFormProvider);
    expect(formState.title, '等待期间输入');
    expect(formState.projectId, inboxProjectId);

    // 关闭弹窗 → 自动保存落库（标题被正确持久化，无静默丢失）。
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    final all = await repo.tasks.getAllByProject(inboxProjectId);
    expect(all, hasLength(1));
    expect(all.single.title, '等待期间输入');
  });
}
