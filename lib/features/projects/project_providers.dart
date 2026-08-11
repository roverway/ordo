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
