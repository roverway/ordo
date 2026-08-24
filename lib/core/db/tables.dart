import 'package:drift/drift.dart';

/// 任务状态枚举（docs/40-data-model.md §3.1）。
///
/// 注意：**枚举顺序即存储值**（0=todo / 1=inProgress / 2=done / 3=cancelled），
/// 已有数据后禁止调整枚举顺序，只允许末尾追加。
enum TaskStatus { todo, inProgress, done, cancelled }

/// 将 [TaskStatus] 与数据库 INTEGER 互转的 TypeConverter。
///
/// 值域：0=todo / 1=inProgress / 2=done / 3=cancelled（§3.1）。
/// 读取路径**崩溃安全**（评审问题 3，与 TaskPriorityConverter 同款）：status
/// 已进入同步快照，未来同步引擎或新版本客户端可能带来越界值；越界一律回退
/// [TaskStatus.todo]（status 的语义默认值）。写入路径由枚举驱动，`toSql` 恒合法。
class TaskStatusConverter extends TypeConverter<TaskStatus, int> {
  const TaskStatusConverter();

  @override
  TaskStatus fromSql(int fromDb) {
    if (fromDb < 0 || fromDb >= TaskStatus.values.length) {
      return TaskStatus.todo;
    }
    return TaskStatus.values[fromDb];
  }

  @override
  int toSql(TaskStatus value) => value.index;
}

/// 任务优先级枚举（docs/40-data-model.md §3.2）。
///
/// 滴答式 4 档：无 / 低（蓝）/ 中（橙）/ 高（红）。
/// 注意：**枚举顺序即存储值**（0=none / 1=low / 2=medium / 3=high），
/// 已有数据后禁止调整枚举顺序，只允许末尾追加。
enum TaskPriority { none, low, medium, high }

/// 将 [TaskPriority] 与数据库 INTEGER 互转的 TypeConverter。
///
/// 值域：0=none / 1=low / 2=medium / 3=high（§3.2）。
/// 读取路径**崩溃安全**（评审问题 3）：priority 已进入同步快照，未来同步引擎
/// 或新版本客户端可能带来越界值；越界一律回退 [TaskPriority.none]（未知值
/// 不应被静默解释为某个具体优先级）。写入路径由枚举驱动，`toSql` 恒合法。
class TaskPriorityConverter extends TypeConverter<TaskPriority, int> {
  const TaskPriorityConverter();

  @override
  TaskPriority fromSql(int fromDb) {
    if (fromDb < 0 || fromDb >= TaskPriority.values.length) {
      return TaskPriority.none;
    }
    return TaskPriority.values[fromDb];
  }

  @override
  int toSql(TaskPriority value) => value.index;
}

/// 项目表（docs/40-data-model.md §2.1）。
///
/// 参与同步：必须带 id / updatedAt / deleted 三字段（AGENTS.md §3-3）。
/// v4 起 [folderId] 归属文件夹，NULL = 未分组；**sortOrder 语义由全局改为
/// 文件夹内排序**（docs/62-folder-nav.md §4.3），分组在 UI/Provider 层做。
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get color => integer()();

  /// 描述（可选，纯文本，最多 500 字符）。
  TextColumn get description =>
      text().withLength(max: 500).withDefault(const Constant(''))();

  /// 所属文件夹（NULL = 未分组），FK → folders.id（docs/62-folder-nav.md §4.2）。
  TextColumn get folderId => text().nullable().references(Folders, #id)();
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

/// 文件夹表（docs/62-folder-nav.md §4.1）。
///
/// 参与同步：必须带 id / updatedAt / deleted 三字段（AGENTS.md §3-3）。
/// 单层结构（D2：文件夹直接装项目，不嵌套）；删除语义 = 仅解除收纳（D3）。
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();

  /// 文件夹间排序（0..n-1 连续，docs/62-folder-nav.md §4.3）。
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

  /// 优先级枚举 0–3（§3.2，滴答式 4 档：无/低/中/高）。
  IntColumn get priority => integer()
      .map(const TaskPriorityConverter())
      .withDefault(const Constant(0))();

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

/// 自定义筛选视图与多面板看板表（docs/65-custom-views-and-panels.md §4.1）。
///
/// 参与同步：必须带 id / updatedAt / deleted 三字段（AGENTS.md §3-3）。
class CustomViews extends Table {
  /// 主键 UUID v4。
  TextColumn get id => text()();

  /// 视图名称（1–50 字符）。
  TextColumn get name => text().withLength(min: 1, max: 50)();

  /// 视图图标（Material Icons identifier 字符串，如 'dashboard_outlined'）。
  TextColumn get icon =>
      text().withDefault(const Constant('dashboard_outlined'))();

  /// 视图强调颜色（ARGB 32位整数，如 0xFF3B82F6）。
  IntColumn get color => integer().withDefault(const Constant(0xFF3B82F6))();

  /// 排序权重（0..n-1，用于侧边栏展示排序）。
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 布局模式：'kanban'(看板多列) 或 'list'(单列聚合)。
  TextColumn get layoutMode => text().withDefault(const Constant('kanban'))();

  /// 面板配置列表序列化 JSON 字符串。
  TextColumn get panelsJson => text()();

  /// 创建时间（UTC 毫秒时间戳）。
  IntColumn get createdAt => integer()();

  /// 最后更新时间（UTC 毫秒时间戳，参与同步 LWW 合并）。
  IntColumn get updatedAt => integer()();

  /// 墓碑删除标记（0 = 正常，1 = 已删除）。
  IntColumn get deleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
