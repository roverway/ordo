import 'database.dart';
import 'repositories/todo_repository.dart';
import 'tables.dart';

/// 演示种子数据（70-milestones.md M1 任务 7，可选，供 M2 联调）。
///
/// 幂等：重复调用会追加新数据（不清理已有数据）。
Future<void> seedDemoData(AppDatabase database) async {
  final repo = TodoRepository(database: database);

  // 项目 1：工作（含 3 级任务树）。
  final work = await repo.createProject(name: '工作', color: 0xFF2196F3);
  final wRoot = await repo.createTask(
    projectId: work.id,
    title: '发布 v1.0',
    description: '完成 M1–M5 里程碑',
  );
  final wChild1 = await repo.createTask(
    projectId: work.id,
    parentId: wRoot.id,
    title: '数据层（M1）',
    status: TaskStatus.done,
  );
  final wChild2 = await repo.createTask(
    projectId: work.id,
    parentId: wRoot.id,
    title: '任务树 UI（M2）',
    status: TaskStatus.inProgress,
  );
  await repo.createTask(
    projectId: work.id,
    parentId: wChild2.id,
    title: '拖拽排序',
  );
  await repo.createTask(
    projectId: work.id,
    parentId: wChild2.id,
    title: '深度校验提示',
  );
  final wLeaf = await repo.createTask(
    projectId: work.id,
    parentId: wRoot.id,
    title: '同步引擎（M4）',
  );
  await repo.createTask(
    projectId: work.id,
    parentId: wLeaf.id,
    title: 'WebDAV 实现',
  );

  // 项目 2：生活。
  final life = await repo.createProject(name: '生活', color: 0xFF4CAF50);
  final lRoot = await repo.createTask(
    projectId: life.id,
    title: '周末计划',
    startAt: DateTime.now().toUtc().millisecondsSinceEpoch,
  );
  await repo.createTask(
    projectId: life.id,
    parentId: lRoot.id,
    title: '买菜',
    status: TaskStatus.done,
  );
  await repo.createTask(projectId: life.id, parentId: lRoot.id, title: '健身');

  // 标签。
  final urgent = await repo.createTag(name: '紧急', color: 0xFFF44336);
  final home = await repo.createTag(name: '家庭', color: 0xFFFF9800);
  await repo.tags.setTaskTags(wChild1.id, [urgent.id]);
  await repo.tags.setTaskTags(lRoot.id, [home.id]);

  // 设置示例。
  await repo.settings.set('lastSyncedAt', '0');
}
