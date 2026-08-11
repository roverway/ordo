import '../db/database.dart';
import '../db/tables.dart';
import 'tree.dart';

/// 派生状态纯函数（docs/40-data-model.md §6）。
///
/// **纯函数**：不访问数据库，禁止落库冗余状态（AGENTS.md §3-2），
/// 必须单测（70-milestones.md M1 任务 4）。
///
/// 注意：`derivedStatus` / `progress` 作用于**完整的数据列表**（含根任务自身），
/// 由调用方从 DAO 查询后传入。

/// 派生任务状态（§6.1，基于**直接子任务**，排除 deleted）。
///
/// 算法顺序（定稿，禁止调换）：
/// 1. 无子任务 → 返回 parent.status（手动状态）；
/// 2. 全部 done → done；
/// 3. 存在 inProgress → inProgress；
/// 4. 全部 cancelled → cancelled；
/// 5. 其余 → todo。
TaskStatus derivedStatus(Task parent, List<Task> directChildren) {
  final children = directChildren.where((c) => c.deleted == 0).toList();
  if (children.isEmpty) return parent.status;
  if (children.every((c) => c.status == TaskStatus.done)) {
    return TaskStatus.done;
  }
  if (children.any((c) => c.status == TaskStatus.inProgress)) {
    return TaskStatus.inProgress;
  }
  if (children.every((c) => c.status == TaskStatus.cancelled)) {
    return TaskStatus.cancelled;
  }
  return TaskStatus.todo;
}

/// 完成度（§6.2，基于**整棵子树**，排除 cancelled 与 deleted）。
///
/// [subtree] 应为根任务及其全部后代；total = 非 cancelled/deleted 数，
/// done = 其中 done 数；total == 0 时返回 0.0。
double progress(Task root, List<Task> subtree) {
  var total = 0;
  var done = 0;
  for (final t in subtree) {
    if (t.deleted != 0 || t.status == TaskStatus.cancelled) continue;
    total++;
    if (t.status == TaskStatus.done) done++;
  }
  return total == 0 ? 0.0 : done / total;
}

/// 未完成任务数（§6.1 派生口径，审查发现 Bug 4）。
///
/// 纯函数：父任务按**派生状态**计数——全部直接子任务均 done/cancelled 时
/// 父任务视为完成，不再计入；叶子任务按其存储 status 计数。
/// 必须单测。
int uncompletedCount(List<Task> tasks) {
  final childrenIndex = indexChildrenByParent(tasks);
  var count = 0;
  for (final t in tasks) {
    if (t.deleted != 0) continue;
    final children = childrenIndex[t.id] ?? const <Task>[];
    final effective = derivedStatus(t, children);
    if (effective != TaskStatus.done && effective != TaskStatus.cancelled) {
      count++;
    }
  }
  return count;
}
