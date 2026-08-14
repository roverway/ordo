import 'package:drift/drift.dart';

import '../database.dart';

/// 项目 DAO（仅表级访问；级联/校验逻辑在 Repository 层）。
class ProjectDao {
  ProjectDao(this._db);

  final AppDatabase _db;

  /// 全部未删除项目，按 sortOrder 升序。
  Stream<List<Project>> watchAll() {
    return (_db.select(_db.projects)
          ..where((p) => p.deleted.equals(0))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .watch();
  }

  /// 全部未删除项目，按 sortOrder 升序。
  Future<List<Project>> getAll() async {
    return (_db.select(_db.projects)
          ..where((p) => p.deleted.equals(0))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .get();
  }

  /// 某文件夹组内的全部未删除项目，按 sortOrder 升序。
  ///
  /// [folderId] 为 null 时查未分组组（folderId IS NULL）；排序语义为
  /// **组内排序**（docs/62-folder-nav.md §4.3），跨组调用方自行分组。
  Future<List<Project>> getAllInFolder(String? folderId) async {
    final query = _db.select(_db.projects)
      ..where((p) => p.deleted.equals(0))
      ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]);
    if (folderId == null) {
      query.where((p) => p.folderId.isNull());
    } else {
      query.where((p) => p.folderId.equals(folderId));
    }
    return query.get();
  }

  /// 按 id 查询（含已删除墓碑行，供同步/级联使用）。
  Future<Project?> getById(String id) {
    return (_db.select(
      _db.projects,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  /// 插入，返回行 id。
  Future<int> insert(ProjectsCompanion entry) {
    return _db.into(_db.projects).insert(entry);
  }

  /// 按 id 更新（只写传入字段）。
  Future<void> updateById(String id, ProjectsCompanion entry) async {
    await (_db.update(
      _db.projects,
    )..where((p) => p.id.equals(id))).write(entry);
  }

  /// 物理删除单行（级联由 Repository 负责）。
  Future<void> deleteById(String id) async {
    await (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
  }
}
