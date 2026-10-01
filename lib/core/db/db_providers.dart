import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/todo_repository.dart';

export 'repositories/todo_repository.dart' show TodoRepository, inboxProjectId;

/// 全局 Repository Provider（位于 core 数据层，供全工程注入复用）。
///
/// 编辑自动同步接线（FR-SYNC-02）：Repository.onDataChanged 在 **main.dart**
/// 中手工注入 `syncTriggers.onEdit`（容器创建后赋值）。这里不能在 Provider
/// 构造时 watch syncTriggersProvider——会形成 syncTriggers → syncEngine →
/// todoRepository 的循环依赖。测试直接 `overrideWithValue` 传入自建仓库时
/// 回调保持 null（无自动同步），符合预期。
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository();
});
