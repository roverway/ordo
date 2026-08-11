import 'package:drift/drift.dart';

import '../database.dart';

/// 设备本地设置 DAO（docs/40-data-model.md §2.5，不参与同步）。
class SettingsDao {
  SettingsDao(this._db);

  final AppDatabase _db;

  /// 读取单个设置；不存在时返回 [fallback]。
  Future<String?> get(String key, {String? fallback}) async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value ?? fallback;
  }

  /// 读取全部设置。
  Future<Map<String, String>> getAll() async {
    final rows = await _db.select(_db.settings).get();
    return {for (final r in rows) r.key: r.value};
  }

  /// 写入（upsert）。
  Future<void> set(String key, String value) async {
    await _db
        .into(_db.settings)
        .insert(
          SettingsCompanion.insert(key: key, value: value),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// 删除单个设置。
  Future<void> remove(String key) async {
    await (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();
  }
}
