import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/todo_repository.dart';

export '../../core/db/repositories/todo_repository.dart' show TodoRepository;

/// 全局 Repository Provider（M2 复用 M1 已实现的数据层）。
///
/// 编辑自动同步接线（FR-SYNC-02）：Repository.onDataChanged 在 **main.dart**
/// 中手工注入 `syncTriggers.onEdit`（容器创建后赋值）。这里不能在 Provider
/// 构造时 watch syncTriggersProvider——会形成 syncTriggers → syncEngine →
/// todoRepository 的循环依赖。测试直接 `overrideWithValue` 传入自建仓库时
/// 回调保持 null（无自动同步），符合预期。
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository();
});

/// 全部未删除项目（按 sortOrder 升序，StreamProvider 自动刷新）。
final projectsStreamProvider = StreamProvider<List<Project>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.projects.watchAll();
});

/// 全部未删除任务流（updatedAt 降序，FR-VIEW-05）。
///
/// 跨视图共享（日历/搜索/标签详情/今日均消费）：单独成 provider 让各视图
/// 共用同一份流订阅（Riverpod 按 provider 去重，避免同一查询被订阅多次）。
/// 返回扁平列表，视图层再各自过滤/排序（view_rules.dart）。
final allActiveTasksProvider = StreamProvider<List<Task>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.tasks.watchAllActive();
});
