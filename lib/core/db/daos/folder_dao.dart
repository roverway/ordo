import 'package:drift/drift.dart';

import '../database.dart';

/// 文件夹 DAO（仅表级访问；解收纳/重排/校验逻辑在 Repository 层）。
class FolderDao {
  FolderDao(this._db);

  final AppDatabase _db;

  /// 全部未删除文件夹，按 sortOrder 升序。
  Stream<List<Folder>> watchAll() {
    return (_db.select(_db.folders)
          ..where((f) => f.deleted.equals(0))
          ..orderBy([(f) => OrderingTerm.asc(f.sortOrder)]))
        .watch();
  }

  /// 全部未删除文件夹（Future 版本），按 sortOrder 升序。
  Future<List<Folder>> getAll() async {
    return (_db.select(_db.folders)
          ..where((f) => f.deleted.equals(0))
          ..orderBy([(f) => OrderingTerm.asc(f.sortOrder)]))
        .get();
  }

  /// 按 id 查询（含已删除墓碑行，供同步/级联使用）。
  Future<Folder?> getById(String id) {
    return (_db.select(
      _db.folders,
    )..where((f) => f.id.equals(id))).getSingleOrNull();
  }

  /// 插入，返回行 id。
  Future<int> insert(FoldersCompanion entry) {
    return _db.into(_db.folders).insert(entry);
  }

  /// 按 id 更新（只写传入字段）。
  Future<void> updateById(String id, FoldersCompanion entry) async {
    await (_db.update(_db.folders)..where((f) => f.id.equals(id))).write(entry);
  }

  /// 物理删除单行（项目解收纳由 Repository 负责）。
  Future<void> deleteById(String id) async {
    await (_db.delete(_db.folders)..where((f) => f.id.equals(id))).go();
  }
}
