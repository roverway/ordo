import 'package:drift/drift.dart';

import '../database.dart';

/// 标签 DAO（含 task_tags 联表读写，docs/40-data-model.md §2.4）。
class TagDao {
  TagDao(this._db);

  final AppDatabase _db;

  /// 全部未删除标签，按 sortOrder 升序。
  Stream<List<Tag>> watchAll() {
    return (_db.select(_db.tags)
          ..where((t) => t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// 全部未删除标签（Future 版本）。
  Future<List<Tag>> getAll() async {
    return (_db.select(_db.tags)
          ..where((t) => t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// 按 id 查询（含墓碑行）。
  Future<Tag?> getById(String id) {
    return (_db.select(
      _db.tags,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 按名称查询（不区分大小写，仅未删除）。
  Future<Tag?> getByName(String name) {
    return (_db.select(_db.tags)..where(
          (t) =>
              t.deleted.equals(0) & t.name.lower().equals(name.toLowerCase()),
        ))
        .getSingleOrNull();
  }

  /// 插入，返回行 id。
  Future<int> insert(TagsCompanion entry) {
    return _db.into(_db.tags).insert(entry);
  }

  /// 按 id 更新（只写传入字段）。
  Future<void> updateById(String id, TagsCompanion entry) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(entry);
  }

  /// 物理删除单行（task_tags 解引用由 Repository 负责）。
  Future<void> deleteById(String id) async {
    await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
  }

  // ── task_tags 联表 ──────────────────────────────────────────────

  /// 某任务关联的全部标签（按标签 sortOrder 升序）。
  Future<List<Tag>> tagsForTask(String taskId) async {
    final query =
        _db.select(_db.tags).join([
            innerJoin(_db.taskTags, _db.taskTags.tagId.equalsExp(_db.tags.id)),
          ])
          ..where(
            _db.taskTags.taskId.equals(taskId) & _db.tags.deleted.equals(0),
          )
          ..orderBy([OrderingTerm.asc(_db.tags.sortOrder)]);
    final rows = await query.get();
    return rows.map((r) => r.readTable(_db.tags)).toList();
  }

  /// 某标签关联的全部未删除任务。
  Future<List<Task>> tasksForTag(String tagId) async {
    final query =
        _db.select(_db.tasks).join([
            innerJoin(
              _db.taskTags,
              _db.taskTags.taskId.equalsExp(_db.tasks.id),
            ),
          ])
          ..where(
            _db.taskTags.tagId.equals(tagId) & _db.tasks.deleted.equals(0),
          )
          ..orderBy([OrderingTerm.asc(_db.tasks.sortOrder)]);
    final rows = await query.get();
    return rows.map((r) => r.readTable(_db.tasks)).toList();
  }

  /// 某任务当前关联的 tagId 列表。
  Future<List<String>> tagIdsForTask(String taskId) async {
    final rows = await (_db.select(
      _db.taskTags,
    )..where((tt) => tt.taskId.equals(taskId))).get();
    return rows.map((r) => r.tagId).toList();
  }

  /// 全量替换某任务的标签关联（事务内调用）。
  Future<void> setTaskTags(String taskId, List<String> tagIds) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.taskTags,
      )..where((tt) => tt.taskId.equals(taskId))).go();
      await _db.batch((b) {
        b.insertAll(
          _db.taskTags,
          tagIds.map(
            (tagId) => TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
          ),
        );
      });
    });
  }

  /// 删除某任务的全部标签关联。
  Future<void> deleteTaskTagsForTask(String taskId) async {
    await (_db.delete(
      _db.taskTags,
    )..where((tt) => tt.taskId.equals(taskId))).go();
  }

  /// 删除某标签的全部引用行（删除标签时调用）。
  Future<void> deleteTaskTagsForTag(String tagId) async {
    await (_db.delete(
      _db.taskTags,
    )..where((tt) => tt.tagId.equals(tagId))).go();
  }

  /// 批量删除一批任务的标签关联（级联删除任务时调用）。
  Future<void> deleteTaskTagsForTasks(Iterable<String> taskIds) async {
    final list = taskIds.toList();
    if (list.isEmpty) return;
    await (_db.delete(_db.taskTags)..where((tt) => tt.taskId.isIn(list))).go();
  }
}
