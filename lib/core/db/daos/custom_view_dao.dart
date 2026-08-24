import 'package:drift/drift.dart';

import '../database.dart';

/// 自定义视图 DAO（表级 CRUD 访问；排序与校验逻辑在 Repository 层）。
class CustomViewDao {
  CustomViewDao(this._db);

  final AppDatabase _db;

  /// 全部未删除自定义视图，按 sortOrder 升序。
  Stream<List<CustomView>> watchAll() {
    return (_db.select(_db.customViews)
          ..where((v) => v.deleted.equals(0))
          ..orderBy([(v) => OrderingTerm.asc(v.sortOrder)]))
        .watch();
  }

  /// 全部未删除自定义视图（Future 版本），按 sortOrder 升序。
  Future<List<CustomView>> getAll() async {
    return (_db.select(_db.customViews)
          ..where((v) => v.deleted.equals(0))
          ..orderBy([(v) => OrderingTerm.asc(v.sortOrder)]))
        .get();
  }

  /// 按 id 查询（含墓碑行，供同步/校验使用）。
  Future<CustomView?> getById(String id) {
    return (_db.select(
      _db.customViews,
    )..where((v) => v.id.equals(id))).getSingleOrNull();
  }

  /// 按 id 流式监听单个未删除视图。
  Stream<CustomView?> watchById(String id) {
    return (_db.select(
      _db.customViews,
    )..where((v) => v.id.equals(id) & v.deleted.equals(0))).watchSingleOrNull();
  }

  /// 插入新记录。
  Future<int> insert(CustomViewsCompanion entry) {
    return _db.into(_db.customViews).insert(entry);
  }

  /// 按 id 更新指定字段。
  Future<void> updateById(String id, CustomViewsCompanion entry) async {
    await (_db.update(
      _db.customViews,
    )..where((v) => v.id.equals(id))).write(entry);
  }

  /// 物理删除单行。
  Future<void> deleteById(String id) async {
    await (_db.delete(_db.customViews)..where((v) => v.id.equals(id))).go();
  }
}
