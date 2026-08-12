import 'package:drift/drift.dart';

import '../daos/project_dao.dart';
import '../daos/settings_dao.dart';
import '../daos/tag_dao.dart';
import '../daos/task_dao.dart';
import '../database.dart';
import '../tables.dart';
import '../../utils/tree.dart';
import '../../utils/uuid.dart';

/// 内置收件箱项目固定 id（产品决策 #3：未选项目的任务落入收件箱）。
const String inboxProjectId = 'inbox';

/// 内置收件箱项目颜色（设计常量，颜色不入 ARB，AGENTS.md §3-8）。
const int inboxProjectColor = 0xFF6C5CE7;

/// Repository 领域异常。
class RepositoryException implements Exception {
  RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 当前 UTC 毫秒（docs/40-data-model.md §4）。
int _nowMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

/// 数据层唯一写入口（docs/30-architecture.md §3）。
///
/// - 所有写操作统一更新 `updatedAt`（UTC 毫秒）。
/// - 级联删除/移动均在同一事务内完成。
/// - 校验（深度/防环/排序一致性）在写前强制，失败抛 [RepositoryException]。
class TodoRepository {
  TodoRepository({AppDatabase? database})
    : database = database ?? AppDatabase.open();

  final AppDatabase database;

  late final ProjectDao projects = ProjectDao(database);
  late final TaskDao tasks = TaskDao(database);
  late final TagDao tags = TagDao(database);
  late final SettingsDao settings = SettingsDao(database);

  // ─────────────────────────── Projects ───────────────────────────

  /// 新建项目（name 1–100 字符；description 最多 500 字符；sortOrder 自动追加到末尾）。
  Future<Project> createProject({
    required String name,
    required int color,
    String description = '',
  }) async {
    _checkTextLength(name, 1, 100, '项目名');
    _checkTextLength(description, 0, 500, '项目描述');
    final now = _nowMs();
    final project = ProjectsCompanion.insert(
      id: newUuid(),
      name: name,
      color: color,
      description: Value(description),
      sortOrder: await _nextProjectSortOrder(),
      createdAt: now,
      updatedAt: now,
    );
    await projects.insert(project);
    return (await projects.getById(project.id.value))!;
  }

  /// 更新项目（name/color/description），统一刷新 updatedAt。
  Future<void> updateProject(
    String id, {
    String? name,
    int? color,
    String? description,
  }) async {
    final existing = await projects.getById(id);
    if (existing == null) throw RepositoryException('项目不存在：$id');
    final entry = ProjectsCompanion(
      name: name != null
          ? Value(_checkTextLength(name, 1, 100, '项目名'))
          : const Value.absent(),
      color: color != null ? Value(color) : const Value.absent(),
      description: description != null
          ? Value(_checkTextLength(description, 0, 500, '项目描述'))
          : const Value.absent(),
      updatedAt: Value(_nowMs()),
    );
    await projects.updateById(id, entry);
  }

  /// 项目排序移动：[newIndex] 为最终列表中的位置（0-based）。
  Future<void> moveProject(String id, int newIndex) async {
    await database.transaction(() async {
      final all = await projects.getAll();
      final index = all.indexWhere((p) => p.id == id);
      if (index < 0) throw RepositoryException('项目不存在：$id');
      final list = [...all]..removeAt(index);
      final clamped = newIndex.clamp(0, list.length);
      list.insert(clamped, all[index]);
      final now = _nowMs();
      for (var i = 0; i < list.length; i++) {
        final p = list[i];
        if (p.sortOrder == i) continue;
        await projects.updateById(
          p.id,
          ProjectsCompanion(sortOrder: Value(i), updatedAt: Value(now)),
        );
      }
    });
  }

  /// 确保内置收件箱项目存在（幂等，产品决策 #3）。
  ///
  /// - 行不存在 → 新建（id 固定为 [inboxProjectId]，sortOrder 置 0 置顶）；
  /// - 行存在且未删除（deleted=0）→ 直接跳过，**不强制改名**（用户手动改名尊重保留）；
  /// - 行存在但已删除（deleted=1，同步墓碑）→ 恢复：deleted=0 并刷新名称/颜色，
  ///   保留原有 sortOrder（避免与其他项目撞序）。
  ///
  /// [displayName] 为收件箱展示名（ARB 文案），由 UI/Provider 层传入；
  /// Repository 不依赖 BuildContext/l10n。
  Future<Project> ensureInboxProject(String displayName) async {
    _checkTextLength(displayName, 1, 100, '收件箱名称');
    final existing = await projects.getById(inboxProjectId);
    final now = _nowMs();
    if (existing == null) {
      await projects.insert(
        ProjectsCompanion.insert(
          id: inboxProjectId,
          name: displayName,
          color: inboxProjectColor,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else if (existing.deleted != 0) {
      // 同步墓碑恢复：仅当行被标记删除时重建展示内容，保留 sortOrder。
      await projects.updateById(
        inboxProjectId,
        ProjectsCompanion(
          name: Value(displayName),
          color: Value(inboxProjectColor),
          deleted: const Value(0),
          updatedAt: Value(now),
        ),
      );
    }
    return (await projects.getById(inboxProjectId))!;
  }

  /// 删除项目：级联硬删其下全部任务（含子树）与关联 task_tags，同一事务。
  Future<void> deleteProject(String id) async {
    await database.transaction(() async {
      final existing = await projects.getById(id);
      if (existing == null) throw RepositoryException('项目不存在：$id');

      final allTasks = await tasks.getAllByProject(id);
      final ids = allTasks.map((t) => t.id).toList();
      await tags.deleteTaskTagsForTasks(ids);
      await tasks.deleteManyByIds(ids);
      await projects.deleteById(id);
    });
  }

  // ───────────────────────────── Tasks ─────────────────────────────

  /// 新建任务。
  ///
  /// - [projectId] 缺省时默认落入内置收件箱（产品决策 #3）。若收件箱行缺失/为
  ///   墓碑且未传 [inboxDisplayName]，将抛出 [RepositoryException]（展示名须由
  ///   调用方从 ARB 提供，Repository 不做 i18n）。
  /// - [parentId] 非空时校验父任务存在且 `depth(parent) < 3`（§5.1）。
  /// - [endAt] 设置时要求 `endAt >= startAt`（§5.4）。
  /// - [priority] 缺省为无优先级（滴答式 4 档，§3.2）。
  Future<Task> createTask({
    String? projectId,
    String? inboxDisplayName,
    String? parentId,
    required String title,
    String description = '',
    String notes = '',
    int? startAt,
    int? endAt,
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.none,
  }) async {
    _checkTextLength(title, 1, 200, '任务标题');
    _checkTimeRange(startAt, endAt);

    // 未指定项目 → 收件箱（自动 ensure，幂等）。
    final effectiveProjectId = await _resolveTaskProjectId(
      projectId,
      inboxDisplayName,
    );

    final project = await projects.getById(effectiveProjectId);
    if (project == null) {
      throw RepositoryException('项目不存在：$effectiveProjectId');
    }

    final now = _nowMs();
    if (parentId != null) {
      final parent = await tasks.getActiveById(parentId);
      if (parent == null) throw RepositoryException('父任务不存在：$parentId');
      if (parent.projectId != effectiveProjectId) {
        throw RepositoryException('父任务不属于该项目');
      }
      final siblings = await tasks.getDirectChildren(
        effectiveProjectId,
        parentId,
      );
      final parentDepth = depthOf(
        parent,
        indexTasksById(await tasks.getAllByProject(effectiveProjectId)),
      );
      if (parentDepth >= 3) {
        throw RepositoryException('超过 3 级层级上限，无法创建子任务');
      }
      final task = TasksCompanion.insert(
        id: newUuid(),
        projectId: effectiveProjectId,
        parentId: Value(parentId),
        title: title,
        description: Value(description),
        notes: Value(notes),
        startAt: Value(startAt),
        endAt: Value(endAt),
        status: status,
        priority: Value(priority),
        sortOrder: siblings.length,
        createdAt: now,
        updatedAt: now,
      );
      await tasks.insert(task);
      return (await tasks.getById(task.id.value))!;
    }

    // 1 级任务。
    final roots = await tasks.getDirectChildren(effectiveProjectId, null);
    final task = TasksCompanion.insert(
      id: newUuid(),
      projectId: effectiveProjectId,
      title: title,
      description: Value(description),
      notes: Value(notes),
      startAt: Value(startAt),
      endAt: Value(endAt),
      status: status,
      priority: Value(priority),
      sortOrder: roots.length,
      createdAt: now,
      updatedAt: now,
    );
    await tasks.insert(task);
    return (await tasks.getById(task.id.value))!;
  }

  /// 更新任务字段（只更新传入项），统一刷新 updatedAt。
  ///
  /// 状态仅在任务**无子任务**时允许修改（有子任务状态由子任务派生，
  /// AGENTS.md §3-2）。
  Future<void> updateTask(
    String id, {
    String? title,
    String? description,
    String? notes,
    int? startAt,
    int? endAt,
    TaskStatus? status,
    TaskPriority? priority,
  }) async {
    final existing = await tasks.getActiveById(id);
    if (existing == null) throw RepositoryException('任务不存在：$id');

    if (title != null) _checkTextLength(title, 1, 200, '任务标题');
    if (status != null) {
      final children = await tasks.getDirectChildren(existing.projectId, id);
      if (children.isNotEmpty) {
        throw RepositoryException('有子任务的任务状态由子任务派生，不可手动修改');
      }
    }
    final effectiveStart = startAt ?? existing.startAt;
    final effectiveEnd = endAt ?? existing.endAt;
    _checkTimeRange(effectiveStart, effectiveEnd);

    final entry = TasksCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      description: description != null
          ? Value(description)
          : const Value.absent(),
      notes: notes != null ? Value(notes) : const Value.absent(),
      startAt: Value(startAt),
      endAt: Value(endAt),
      status: status != null ? Value(status) : const Value.absent(),
      priority: priority != null ? Value(priority) : const Value.absent(),
      updatedAt: Value(_nowMs()),
    );
    await tasks.updateById(id, entry);
  }

  /// 移动任务：[newParentId] 为 null 表示提升为 1 级任务。
  ///
  /// 校验（§5）：
  /// - 防环：目标不得是节点自身或其后代（§5.2）；
  /// - 深度：`depthOf(target) + subtreeDepthOf(node) <= 3`（§5.1）；
  /// - 同一事务内更新 parentId + 重排新旧两组 sortOrder（§5.3）。
  Future<void> moveTask(
    String taskId, {
    String? newParentId,
    required int newIndex,
  }) async {
    await database.transaction(() async {
      final task = await tasks.getActiveById(taskId);
      if (task == null) throw RepositoryException('任务不存在：$taskId');

      final all = await tasks.getAllByProject(task.projectId);
      final byId = indexTasksById(all);
      final childrenIndex = indexChildrenByParent(all);

      if (newParentId == taskId) {
        throw RepositoryException('不能移动到自身');
      }
      if (newParentId != null) {
        final parent = byId[newParentId];
        if (parent == null) throw RepositoryException('父任务不存在：$newParentId');
        if (parent.projectId != task.projectId) {
          throw RepositoryException('不能移动到其他项目的任务下');
        }
        if (isDescendantOf(parent, task, byId)) {
          throw RepositoryException('不能移动到自身的子任务下（防环）');
        }
        final targetDepth = depthOf(parent, byId);
        final nodeSubtree = subtreeDepthOf(task, childrenIndex);
        if (targetDepth + nodeSubtree > 3) {
          throw RepositoryException('移动后层级超过 3 级上限');
        }
      } else {
        // 提升为 1 级：depth(target)=0，subtreeDepth 必然 ≤3，无需额外校验。
      }

      // 新旧两组（newParentId 等于当前父级时为纯重排）。
      final oldGroup =
          childrenIndex[task.parentId]?.where((t) => t.id != taskId).toList() ??
          <Task>[];
      final newGroup =
          childrenIndex[newParentId]?.where((t) => t.id != taskId).toList() ??
          <Task>[];
      oldGroup.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      newGroup.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      // 无父任务 → 新父级列表用 1 级任务（排序同源，重排即可）。
      final targetGroup = List<Task>.of(newGroup);
      final index = newIndex.clamp(0, targetGroup.length);
      targetGroup.insert(index, task);

      final now = _nowMs();

      // 写节点本身（parentId + 新 sortOrder + updatedAt）。
      await tasks.updateById(
        taskId,
        TasksCompanion(
          parentId: Value(newParentId),
          sortOrder: Value(index),
          updatedAt: Value(now),
        ),
      );

      // 重排新组（节点自身已更新，跳过）。
      for (var i = 0; i < targetGroup.length; i++) {
        final t = targetGroup[i];
        if (t.id == taskId || t.sortOrder == i) continue;
        await tasks.updateById(
          t.id,
          TasksCompanion(sortOrder: Value(i), updatedAt: Value(now)),
        );
      }

      // 重排旧组（新组与旧组为同一组时跳过）。
      if (task.parentId != newParentId) {
        for (var i = 0; i < oldGroup.length; i++) {
          final t = oldGroup[i];
          if (t.sortOrder == i) continue;
          await tasks.updateById(
            t.id,
            TasksCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          );
        }
      }
    });
  }

  /// 收件箱项目下全部未删除任务（扁平列表，含 1 级与子树），按 sortOrder 升序。
  ///
  /// 首页目前展示 1 级任务列表 + 完成勾选；子树任务一并返回，UI 层按需过滤。
  /// 收件箱行需先经 [ensureInboxProject] 确保存在（Provider 层负责）。
  Stream<List<Task>> watchInboxTasks() => tasks.watchByProject(inboxProjectId);

  /// 删除任务：级联硬删所有后代（含自身）+ 关联 task_tags，同一事务。
  Future<void> deleteTask(String taskId) async {
    await database.transaction(() async {
      final task = await tasks.getActiveById(taskId);
      if (task == null) throw RepositoryException('任务不存在：$taskId');

      final all = await tasks.getAllByProject(task.projectId);
      final childrenIndex = indexChildrenByParent(all);
      final subtreeIds = <String>[];
      void collect(String id) {
        subtreeIds.add(id);
        for (final child in childrenIndex[id] ?? const <Task>[]) {
          collect(child.id);
        }
      }

      collect(taskId);
      await tags.deleteTaskTagsForTasks(subtreeIds);
      await tasks.deleteManyByIds(subtreeIds);
    });
  }

  // ────────────────────────────── Tags ──────────────────────────────

  /// 新建标签（name 不区分大小写唯一，§5.4）。
  Future<Tag> createTag({required String name, required int color}) async {
    _checkTextLength(name, 1, 50, '标签名');
    final existing = await tags.getByName(name);
    if (existing != null) throw RepositoryException('标签名已存在（不区分大小写）：$name');
    final now = _nowMs();
    final all = await tags.getAll();
    final tag = TagsCompanion.insert(
      id: newUuid(),
      name: name,
      color: color,
      sortOrder: all.length,
      createdAt: now,
      updatedAt: now,
    );
    await tags.insert(tag);
    return (await tags.getById(tag.id.value))!;
  }

  /// 更新标签（name/color）。
  Future<void> updateTag(String id, {String? name, int? color}) async {
    final existing = await tags.getById(id);
    if (existing == null) throw RepositoryException('标签不存在：$id');
    if (name != null) {
      _checkTextLength(name, 1, 50, '标签名');
      final dup = await tags.getByName(name);
      if (dup != null && dup.id != id) {
        throw RepositoryException('标签名已存在（不区分大小写）：$name');
      }
    }
    await tags.updateById(
      id,
      TagsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
        updatedAt: Value(_nowMs()),
      ),
    );
  }

  /// 删除标签：硬删标签 + 删除 task_tags 引用行（任务保留，§7）。
  Future<void> deleteTag(String id) async {
    await database.transaction(() async {
      final existing = await tags.getById(id);
      if (existing == null) throw RepositoryException('标签不存在：$id');
      await tags.deleteTaskTagsForTag(id);
      await tags.deleteById(id);
    });
  }

  // ───────────────────────────── 校验辅助 ─────────────────────────────

  String _checkTextLength(String value, int min, int max, String label) {
    final len = value.runes.length;
    if (len < min || len > max) {
      throw RepositoryException('$label长度需在 $min–$max 字符之间');
    }
    return value;
  }

  void _checkTimeRange(int? startAt, int? endAt) {
    if (startAt != null && endAt != null && endAt < startAt) {
      throw RepositoryException('截止时间不能早于开始时间');
    }
  }

  Future<int> _nextProjectSortOrder() async {
    final all = await projects.getAll();
    return all.isEmpty ? 0 : (all.last.sortOrder + 1);
  }

  /// 解析任务所属项目 id：未传 [projectId] 时默认内置收件箱（产品决策 #3）。
  ///
  /// - 收件箱行存在且未删除 → 直接复用其固定 id；
  /// - 收件箱行缺失或为墓碑 → 需经 [ensureInboxProject] 重建，但创建需要展示名，
  ///   Repository 不感知 l10n（AGENTS.md §3-8），故展示名由调用方传入
  ///   [inboxDisplayName]；未提供时抛出 [RepositoryException]（UI 流程应保证
  ///   通过 [inboxProjectProvider] 先行 ensure）。
  Future<String> _resolveTaskProjectId(
    String? projectId,
    String? inboxDisplayName,
  ) async {
    if (projectId != null) return projectId;
    final existing = await projects.getById(inboxProjectId);
    if (existing != null && existing.deleted == 0) return inboxProjectId;
    if (inboxDisplayName == null) {
      throw RepositoryException('收件箱项目不存在，请先调用 ensureInboxProject 创建');
    }
    return (await ensureInboxProject(inboxDisplayName)).id;
  }
}
