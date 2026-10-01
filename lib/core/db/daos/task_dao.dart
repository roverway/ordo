import 'package:drift/drift.dart';

import '../database.dart';

/// 任务 DAO（仅表级访问；级联/校验/派生逻辑在 Repository 层）。
class TaskDao {
  TaskDao(this._db);

  final AppDatabase _db;

  /// 某项目下全部未删除任务（含子树），按 parentId 分组后的 sortOrder 升序。
  ///
  /// 注意：这是扁平列表，层级由 parentId 推导。
  Stream<List<Task>> watchByProject(String projectId) {
    return (_db.select(_db.tasks)
          ..where((t) => t.projectId.equals(projectId) & t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// 某项目下全部未删除任务（Future 版本）。
  Future<List<Task>> getByProject(String projectId) async {
    return (_db.select(_db.tasks)
          ..where((t) => t.projectId.equals(projectId) & t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// 某项目下全部任务（**含 deleted 墓碑行**，供级联删除/同步使用）。
  Future<List<Task>> getAllByProject(String projectId) async {
    return (_db.select(
      _db.tasks,
    )..where((t) => t.projectId.equals(projectId))).get();
  }

  /// 某任务 id 所在项目的全部任务（含 deleted），供子树计算。
  Future<List<Task>> getAllInProjectOf(String taskId) async {
    final task = await getById(taskId);
    if (task == null) return const [];
    return getAllByProject(task.projectId);
  }

  /// 按 id 查询（含墓碑行）。
  Future<Task?> getById(String id) {
    return (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 按 id 查询（仅未删除）。
  Future<Task?> getActiveById(String id) {
    return (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(id) & t.deleted.equals(0))).getSingleOrNull();
  }

  /// 指定父级的直接未删除子任务（parentId 为空则查 1 级任务），按 sortOrder 升序。
  Future<List<Task>> getDirectChildren(
    String projectId,
    String? parentId,
  ) async {
    final query = _db.select(_db.tasks)
      ..where((t) => t.projectId.equals(projectId) & t.deleted.equals(0));
    if (parentId == null) {
      query.where((t) => t.parentId.isNull());
    } else {
      query.where((t) => t.parentId.equals(parentId));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.get();
  }

  /// 全部未删除任务，按 `updatedAt` 降序（今日/日历/搜索/筛选用）。
  ///
  /// 返回扁平列表，视图层再各自排序/过滤（view_rules.dart）。
  Stream<List<Task>> watchAllActive() {
    return (_db.select(_db.tasks)
          ..where((t) => t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// 全部未删除任务（Future 版本），按 `updatedAt` 降序。
  Future<List<Task>> getAllActive() async {
    return (_db.select(_db.tasks)
          ..where((t) => t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// 插入，返回行 id。
  Future<int> insert(TasksCompanion entry) {
    return _db.into(_db.tasks).insert(entry);
  }

  /// 按 id 更新（只写传入字段）。
  Future<void> updateById(String id, TasksCompanion entry) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(entry);
  }

  /// 批量物理删除（级联顺序由 Repository 在事务内保证）。
  Future<void> deleteManyByIds(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (_db.delete(_db.tasks)..where((t) => t.id.isIn(list))).go();
  }
}
