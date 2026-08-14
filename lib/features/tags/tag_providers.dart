import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../projects/project_providers.dart';

/// 按名称**不区分大小写**排序（FR-VIEW-04：标签列表按名称排序）。
///
/// 纯函数：`Work` 与 `work` 视为同一排序键；同键时按原始名称二次排序保证稳定。
List<Tag> sortTagsByName(List<Tag> tags) {
  final result = List<Tag>.from(tags)
    ..sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.name.compareTo(b.name);
    });
  return result;
}

/// 全部未删除标签（StreamProvider 自动刷新）。
final tagsStreamProvider = StreamProvider<List<Tag>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.tags.watchAll().map(sortTagsByName);
});

/// 某标签下的全部未删除任务（StreamProvider，DB 变更自动刷新）。
final tagTasksProvider = StreamProvider.family<List<Task>, String>((
  ref,
  tagId,
) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.tags.watchTasksForTag(tagId);
});
