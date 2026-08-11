import '../db/database.dart';

/// 层级校验纯函数（docs/40-data-model.md §5）。
///
/// **纯函数**：不访问数据库，仅基于传入的 [Task] 列表/索引计算，
/// 必须单测（70-milestones.md M1 任务 3）。
///
/// 约定：
/// - 根任务（parentId == null）深度 = 1；子任务深度 = 父深度 + 1；**最大深度 = 3**（§5.1）。
/// - 节点自身最大后代深度 = 节点深度 + 其子树最大高度 - 1（subtreeDepthOf 含自身）。

/// 由任务列表构建 `id → Task` 索引。
///
/// [all] 应包含目标节点到根的**整条祖先链**，否则 depth 计算会因链条断裂提前终止。
Map<String, Task> indexTasksById(List<Task> all) {
  return {for (final t in all) t.id: t};
}

/// 由任务列表构建 `parentId → 直接子任务列表` 索引（键为 null 表示根级任务）。
Map<String?, List<Task>> indexChildrenByParent(List<Task> all) {
  final result = <String?, List<Task>>{};
  for (final t in all) {
    result.putIfAbsent(t.parentId, () => []).add(t);
  }
  return result;
}

/// 节点深度：根（parentId == null）= 1，子任务 = 父深度 + 1。
///
/// [byId] 提供祖先查找（可由 [indexTasksById] 构建）。链条断裂时提前终止并返回
/// 已统计深度，避免死循环。
int depthOf(Task task, Map<String, Task> byId) {
  var depth = 1;
  var parentId = task.parentId;
  while (parentId != null) {
    depth++;
    final parent = byId[parentId];
    if (parent == null) break; // 数据不一致兜底。
    parentId = parent.parentId;
  }
  return depth;
}

/// 节点自身最大后代深度（**含自身**）。
///
/// 叶子节点 = 1；有子任务 = 1 + max(各直接子任务的 subtreeDepth)。
/// [childrenIndex] 可由 [indexChildrenByParent] 构建。
int subtreeDepthOf(Task root, Map<String?, List<Task>> childrenIndex) {
  final children = childrenIndex[root.id] ?? const <Task>[];
  if (children.isEmpty) return 1;
  var maxChild = 0;
  for (final child in children) {
    final d = subtreeDepthOf(child, childrenIndex);
    if (d > maxChild) maxChild = d;
  }
  return 1 + maxChild;
}

/// 沿 parentId 链上溯判断 [candidate] 是否为 [ancestor] 的后代。
///
/// - candidate 自身 ≠ 其后代（自身返回 false）。
/// - candidate.parentId 链中出现 ancestor.id 即为后代。
/// [byId] 提供祖先查找。
bool isDescendantOf(Task candidate, Task ancestor, Map<String, Task> byId) {
  var parentId = candidate.parentId;
  while (parentId != null) {
    if (parentId == ancestor.id) return true;
    final parent = byId[parentId];
    if (parent == null) return false; // 链条断裂。
    parentId = parent.parentId;
  }
  return false;
}
