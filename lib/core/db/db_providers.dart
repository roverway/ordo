import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data_change_observer.dart';
import 'repositories/todo_repository.dart';

export 'data_change_observer.dart' show DataChangeObserver;
export 'repositories/todo_repository.dart' show TodoRepository, inboxProjectId;

/// 全局 Repository Provider（位于 core 数据层，供全工程注入复用）。
///
/// 编辑自动同步接线（FR-SYNC-02）：
/// 通过 [DataChangeObserver] 接口依赖倒置，在上层 [syncTriggersProvider]
/// 创建时自动绑定到 Repository 的 dataChangeObserver，保证单向依赖且生命周期安全。
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository();
});
