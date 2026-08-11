import 'package:drift/drift.dart';

/// 任务状态枚举（docs/40-data-model.md §3.1）。
///
/// 注意：**枚举顺序即存储值**（0=todo / 1=inProgress / 2=done / 3=cancelled），
/// 已有数据后禁止调整枚举顺序，只允许末尾追加。
enum TaskStatus { todo, inProgress, done, cancelled }

/// 将 [TaskStatus] 与数据库 INTEGER 互转的 TypeConverter。
///
/// 值域：0=todo / 1=inProgress / 2=done / 3=cancelled（§3.1）。
class TaskStatusConverter extends TypeConverter<TaskStatus, int> {
  const TaskStatusConverter();

  @override
  TaskStatus fromSql(int fromDb) => TaskStatus.values[fromDb];

  @override
  int toSql(TaskStatus value) => value.index;
}

/// 项目表（docs/40-data-model.md §2.1）。
///
/// 参与同步：必须带 id / updatedAt / deleted 三字段（AGENTS.md §3-3）。
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer()();

  /// UTC 毫秒。
  IntColumn get createdAt => integer()();

  /// UTC 毫秒（同步字段）。
  IntColumn get updatedAt => integer()();

  /// 墓碑标记（同步字段），0=正常 / 1=已删除。
  IntColumn get deleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 任务表（docs/40-data-model.md §2.2）。
///
/// 参与同步：必须带 id / updatedAt / deleted 三字段（AGENTS.md §3-3）。
/// 层级不落 level 字段，由 parentId 链推导（最大深度 3）。
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get parentId => text().nullable().references(Tasks, #id)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// 开始时间（UTC 毫秒，可选）。
  IntColumn get startAt => integer().nullable()();

  /// 截止时间（UTC 毫秒，可选；设置时要求 endAt >= startAt）。
  IntColumn get endAt => integer().nullable()();

  /// 状态枚举 0–3（§3.1）。有子任务的任务此字段被忽略（状态由子任务派生）。
  IntColumn get status => integer().map(const TaskStatusConverter())();

  /// 同级内排序（0..n-1 连续）。
  IntColumn get sortOrder => integer()();

  /// UTC 毫秒。
  IntColumn get createdAt => integer()();

  /// UTC 毫秒（同步字段）。
  IntColumn get updatedAt => integer()();

  /// 墓碑标记（同步字段）。
  IntColumn get deleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 标签表（docs/40-data-model.md §2.3）。
///
/// 参与同步：必须带 id / updatedAt / deleted 三字段（AGENTS.md §3-3）。
/// name 不区分大小写唯一。
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 任务-标签联表（docs/40-data-model.md §2.4）。
///
/// **不参与同步**：快照中 tagIds 内嵌于 task 记录，合并时整体重建。
class TaskTags extends Table {
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

/// 设备本地设置表（docs/40-data-model.md §2.5）。
///
/// **不参与同步**；仅存非敏感偏好（主题/语言/同步开关等），
/// 同步凭据禁止存这里（走 flutter_secure_storage）。
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
