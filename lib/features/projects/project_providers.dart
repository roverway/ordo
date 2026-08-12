import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/todo_repository.dart';

export '../../core/db/repositories/todo_repository.dart' show TodoRepository;

/// 全局 Repository Provider（M2 复用 M1 已实现的数据层）。
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
