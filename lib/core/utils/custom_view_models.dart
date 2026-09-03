import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../db/tables.dart';
import 'derived.dart';
import 'uuid.dart';

/// 日期筛选范围枚举。
enum DateScopeEnum {
  all,
  overdue,
  today,
  tomorrow,
  thisWeek,
  noDate,
  customRange,
  completedToday,
}

/// 层级筛选范围枚举。
enum HierarchyScopeEnum { all, rootOnly, subtasksOnly }

/// 筛选条件纯 Dart 模型（docs/65-custom-views-and-panels.md §2.2）。
class FilterCriteria {
  const FilterCriteria({
    this.folderIds = const [],
    this.projectIds = const [],
    this.tagIds = const [],
    this.tagMatchAll = false,
    this.priorities = const [],
    this.statuses = const [],
    this.dateScope = DateScopeEnum.all,
    this.customDateStart,
    this.customDateEnd,
    this.hierarchyScope = HierarchyScopeEnum.all,
    this.searchQuery,
  });

  /// 文件夹 ID 列表（包含 'unassigned' 表示未分组项目）。
  final List<String> folderIds;

  /// 项目 ID 列表。
  final List<String> projectIds;

  /// 标签 ID 列表。
  final List<String> tagIds;

  /// 标签匹配方式：true = 全部包含 (AND)，false = 任一包含 (OR)。
  final bool tagMatchAll;

  /// 优先级列表。
  final List<TaskPriority> priorities;

  /// 状态列表。
  final List<TaskStatus> statuses;

  /// 日期范围。
  final DateScopeEnum dateScope;

  /// 自定义起始时间（UTC 毫秒）。
  final int? customDateStart;

  /// 自定义截止时间（UTC 毫秒）。
  final int? customDateEnd;

  /// 层级范围。
  final HierarchyScopeEnum hierarchyScope;

  /// 文本搜索关键字。
  final String? searchQuery;

  /// 是否包含任意生效的筛选条件（非空）。
  bool get hasActiveFilter {
    return folderIds.isNotEmpty ||
        projectIds.isNotEmpty ||
        tagIds.isNotEmpty ||
        priorities.isNotEmpty ||
        statuses.isNotEmpty ||
        dateScope != DateScopeEnum.all ||
        hierarchyScope != HierarchyScopeEnum.all ||
        (searchQuery != null && searchQuery!.trim().isNotEmpty);
  }

  FilterCriteria copyWith({
    List<String>? folderIds,
    List<String>? projectIds,
    List<String>? tagIds,
    bool? tagMatchAll,
    List<TaskPriority>? priorities,
    List<TaskStatus>? statuses,
    DateScopeEnum? dateScope,
    int? customDateStart,
    int? customDateEnd,
    HierarchyScopeEnum? hierarchyScope,
    String? searchQuery,
  }) {
    return FilterCriteria(
      folderIds: folderIds ?? this.folderIds,
      projectIds: projectIds ?? this.projectIds,
      tagIds: tagIds ?? this.tagIds,
      tagMatchAll: tagMatchAll ?? this.tagMatchAll,
      priorities: priorities ?? this.priorities,
      statuses: statuses ?? this.statuses,
      dateScope: dateScope ?? this.dateScope,
      customDateStart: customDateStart ?? this.customDateStart,
      customDateEnd: customDateEnd ?? this.customDateEnd,
      hierarchyScope: hierarchyScope ?? this.hierarchyScope,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'folderIds': folderIds,
      'projectIds': projectIds,
      'tagIds': tagIds,
      'tagMatchAll': tagMatchAll,
      'priorities': priorities.map((p) => p.index).toList(),
      'statuses': statuses.map((s) => s.index).toList(),
      'dateScope': dateScope.name,
      if (customDateStart != null) 'customDateStart': customDateStart,
      if (customDateEnd != null) 'customDateEnd': customDateEnd,
      'hierarchyScope': hierarchyScope.name,
      if (searchQuery != null) 'searchQuery': searchQuery,
    };
  }

  factory FilterCriteria.fromJson(Map<String, dynamic> json) {
    return FilterCriteria(
      folderIds:
          (json['folderIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      projectIds:
          (json['projectIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      tagIds:
          (json['tagIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      tagMatchAll: json['tagMatchAll'] as bool? ?? false,
      priorities:
          (json['priorities'] as List<dynamic>?)?.map((e) {
            final idx = e is int ? e : int.tryParse(e.toString()) ?? 0;
            return idx >= 0 && idx < TaskPriority.values.length
                ? TaskPriority.values[idx]
                : TaskPriority.none;
          }).toList() ??
          const [],
      statuses:
          (json['statuses'] as List<dynamic>?)?.map((e) {
            final idx = e is int ? e : int.tryParse(e.toString()) ?? 0;
            return idx >= 0 && idx < TaskStatus.values.length
                ? TaskStatus.values[idx]
                : TaskStatus.todo;
          }).toList() ??
          const [],
      dateScope: DateScopeEnum.values.firstWhere(
        (e) => e.name == json['dateScope'],
        orElse: () => DateScopeEnum.all,
      ),
      customDateStart: json['customDateStart'] as int?,
      customDateEnd: json['customDateEnd'] as int?,
      hierarchyScope: HierarchyScopeEnum.values.firstWhere(
        (e) => e.name == json['hierarchyScope'],
        orElse: () => HierarchyScopeEnum.all,
      ),
      searchQuery: json['searchQuery'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterCriteria &&
        listEquals(other.folderIds, folderIds) &&
        listEquals(other.projectIds, projectIds) &&
        listEquals(other.tagIds, tagIds) &&
        other.tagMatchAll == tagMatchAll &&
        listEquals(other.priorities, priorities) &&
        listEquals(other.statuses, statuses) &&
        other.dateScope == dateScope &&
        other.customDateStart == customDateStart &&
        other.customDateEnd == customDateEnd &&
        other.hierarchyScope == hierarchyScope &&
        other.searchQuery == searchQuery;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(folderIds),
    Object.hashAll(projectIds),
    Object.hashAll(tagIds),
    tagMatchAll,
    Object.hashAll(priorities),
    Object.hashAll(statuses),
    dateScope,
    customDateStart,
    customDateEnd,
    hierarchyScope,
    searchQuery,
  );
}

/// 面板配置纯 Dart 模型。
class CustomViewPanelConfig {
  const CustomViewPanelConfig({
    required this.id,
    required this.title,
    required this.filter,
    this.displayMode = 'flat',
    this.sortBy = 'sortOrder',
    this.sortDirection = 'asc',
  });

  /// 面板 UUID。
  final String id;

  /// 面板标题。
  final String title;

  /// 筛选条件。
  final FilterCriteria filter;

  /// 任务展示模式：'flat'(扁平) / 'tree'(树状)。
  final String displayMode;

  /// 排序字段：'sortOrder' / 'priority' / 'endAt' / 'updatedAt' / 'title'。
  final String sortBy;

  /// 排序方向：'asc' / 'desc'。
  final String sortDirection;

  CustomViewPanelConfig copyWith({
    String? id,
    String? title,
    FilterCriteria? filter,
    String? displayMode,
    String? sortBy,
    String? sortDirection,
  }) {
    return CustomViewPanelConfig(
      id: id ?? this.id,
      title: title ?? this.title,
      filter: filter ?? this.filter,
      displayMode: displayMode ?? this.displayMode,
      sortBy: sortBy ?? this.sortBy,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filter': filter.toJson(),
      'displayMode': displayMode,
      'sortBy': sortBy,
      'sortDirection': sortDirection,
    };
  }

  factory CustomViewPanelConfig.fromJson(Map<String, dynamic> json) {
    return CustomViewPanelConfig(
      id: json['id'] as String? ?? newUuid(),
      title: json['title'] as String? ?? '',
      filter: json['filter'] is Map<String, dynamic>
          ? FilterCriteria.fromJson(json['filter'] as Map<String, dynamic>)
          : const FilterCriteria(),
      displayMode: json['displayMode'] as String? ?? 'flat',
      sortBy: json['sortBy'] as String? ?? 'sortOrder',
      sortDirection: json['sortDirection'] as String? ?? 'asc',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomViewPanelConfig &&
        other.id == id &&
        other.title == title &&
        other.filter == filter &&
        other.displayMode == displayMode &&
        other.sortBy == sortBy &&
        other.sortDirection == sortDirection;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, filter, displayMode, sortBy, sortDirection);
}

/// 解析 panelsJson 字符串。
List<CustomViewPanelConfig> decodePanelsJson(String jsonStr) {
  if (jsonStr.trim().isEmpty) return const [];
  try {
    final list = jsonDecode(jsonStr);
    if (list is List) {
      return list
          .whereType<Map<String, dynamic>>()
          .map(CustomViewPanelConfig.fromJson)
          .toList();
    }
  } catch (_) {}
  return const [];
}

/// 序列化 panels 配置列表为 JSON 字符串。
String encodePanelsJson(List<CustomViewPanelConfig> panels) {
  return jsonEncode(panels.map((p) => p.toJson()).toList());
}

/// 预设模板：状态三栏看板（待办 / 进行中 / 已完成）。
List<CustomViewPanelConfig> createStatusKanbanPanels({
  String titleTodo = 'To Do',
  String titleInProgress = 'In Progress',
  String titleDone = 'Done',
}) {
  return [
    CustomViewPanelConfig(
      id: newUuid(),
      title: titleTodo,
      filter: const FilterCriteria(statuses: [TaskStatus.todo]),
    ),
    CustomViewPanelConfig(
      id: newUuid(),
      title: titleInProgress,
      filter: const FilterCriteria(statuses: [TaskStatus.inProgress]),
    ),
    CustomViewPanelConfig(
      id: newUuid(),
      title: titleDone,
      filter: const FilterCriteria(statuses: [TaskStatus.done]),
    ),
  ];
}

/// 预设模板：优先级四栏看板（高优 / 中优 / 低优 / 无）。
List<CustomViewPanelConfig> createPriorityKanbanPanels({
  String titleHigh = 'High',
  String titleMedium = 'Medium',
  String titleLow = 'Low',
  String titleNone = 'None',
}) {
  return [
    CustomViewPanelConfig(
      id: newUuid(),
      title: titleHigh,
      filter: const FilterCriteria(
        priorities: [TaskPriority.high],
        statuses: [TaskStatus.todo, TaskStatus.inProgress],
      ),
    ),
    CustomViewPanelConfig(
      id: newUuid(),
      title: titleMedium,
      filter: const FilterCriteria(
        priorities: [TaskPriority.medium],
        statuses: [TaskStatus.todo, TaskStatus.inProgress],
      ),
    ),
    CustomViewPanelConfig(
      id: newUuid(),
      title: titleLow,
      filter: const FilterCriteria(
        priorities: [TaskPriority.low],
        statuses: [TaskStatus.todo, TaskStatus.inProgress],
      ),
    ),
    CustomViewPanelConfig(
      id: newUuid(),
      title: titleNone,
      filter: const FilterCriteria(
        priorities: [TaskPriority.none],
        statuses: [TaskStatus.todo, TaskStatus.inProgress],
      ),
    ),
  ];
}

/// 纯函数：判断单个任务是否满足 [FilterCriteria] 条件。
bool matchesFilter(
  Task task,
  FilterCriteria filter, {
  required Map<String, Task> byId,
  required List<Task> directChildren,
  required Map<String, Project> projectsById,
  required Set<String> taskTagIds,
  required int nowUtcMs,
}) {
  // 1. 文件夹筛选
  if (filter.folderIds.isNotEmpty) {
    final project = projectsById[task.projectId];
    if (project == null) return false;
    final folderId = project.folderId;
    if (folderId == null) {
      if (!filter.folderIds.contains('unassigned')) return false;
    } else {
      if (!filter.folderIds.contains(folderId)) return false;
    }
  }

  // 2. 项目筛选
  if (filter.projectIds.isNotEmpty) {
    if (!filter.projectIds.contains(task.projectId)) return false;
  }

  // 3. 标签筛选
  if (filter.tagIds.isNotEmpty) {
    if (filter.tagMatchAll) {
      for (final t in filter.tagIds) {
        if (!taskTagIds.contains(t)) return false;
      }
    } else {
      final matchesAny = filter.tagIds.any(taskTagIds.contains);
      if (!matchesAny) return false;
    }
  }

  // 4. 优先级筛选
  if (filter.priorities.isNotEmpty) {
    if (!filter.priorities.contains(task.priority)) return false;
  }

  // 5. 状态筛选（派生状态口径，递归子树）
  final effectiveStatus = _getRecursiveDerivedStatus(
    task,
    directChildren,
    byId,
  );
  if (filter.statuses.isNotEmpty) {
    if (!filter.statuses.contains(effectiveStatus)) return false;
  }

  // 6. 层级筛选
  if (filter.hierarchyScope == HierarchyScopeEnum.rootOnly) {
    if (task.parentId != null) return false;
  } else if (filter.hierarchyScope == HierarchyScopeEnum.subtasksOnly) {
    if (task.parentId == null) return false;
  }

  // 7. 搜索关键字匹配
  if (filter.searchQuery != null && filter.searchQuery!.trim().isNotEmpty) {
    final q = filter.searchQuery!.trim().toLowerCase();
    final inTitle = task.title.toLowerCase().contains(q);
    final inDesc = task.description.toLowerCase().contains(q);
    final inNotes = task.notes.toLowerCase().contains(q);
    if (!inTitle && !inDesc && !inNotes) return false;
  }

  // 8. 日期范围筛选
  if (filter.dateScope != DateScopeEnum.all) {
    final localNow = DateTime.fromMillisecondsSinceEpoch(
      nowUtcMs,
      isUtc: true,
    ).toLocal();
    final todayStart = DateTime(localNow.year, localNow.month, localNow.day);
    final todayStartUtcMs = todayStart.toUtc().millisecondsSinceEpoch;
    final todayEndUtcMs =
        todayStart.add(const Duration(days: 1)).toUtc().millisecondsSinceEpoch -
        1;

    switch (filter.dateScope) {
      case DateScopeEnum.noDate:
        if (task.startAt != null || task.endAt != null) return false;
        break;
      case DateScopeEnum.overdue:
        // 截止时间早于今天开始且未完成
        final effectiveStatus = derivedStatus(task, directChildren);
        if (effectiveStatus == TaskStatus.done ||
            effectiveStatus == TaskStatus.cancelled) {
          return false;
        }
        if (task.endAt == null || task.endAt! >= todayStartUtcMs) return false;
        break;
      case DateScopeEnum.today:
        // 今天截止或今天开始
        final hasStartToday =
            task.startAt != null &&
            task.startAt! >= todayStartUtcMs &&
            task.startAt! <= todayEndUtcMs;
        final hasEndToday =
            task.endAt != null &&
            task.endAt! >= todayStartUtcMs &&
            task.endAt! <= todayEndUtcMs;
        final spansToday =
            task.startAt != null &&
            task.endAt != null &&
            task.startAt! < todayStartUtcMs &&
            task.endAt! > todayEndUtcMs;
        if (!hasStartToday && !hasEndToday && !spansToday) return false;
        break;
      case DateScopeEnum.tomorrow:
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        final tomorrowStartUtcMs = tomorrowStart.toUtc().millisecondsSinceEpoch;
        final tomorrowEndUtcMs =
            tomorrowStart
                .add(const Duration(days: 1))
                .toUtc()
                .millisecondsSinceEpoch -
            1;
        final hasStartTomorrow =
            task.startAt != null &&
            task.startAt! >= tomorrowStartUtcMs &&
            task.startAt! <= tomorrowEndUtcMs;
        final hasEndTomorrow =
            task.endAt != null &&
            task.endAt! >= tomorrowStartUtcMs &&
            task.endAt! <= tomorrowEndUtcMs;
        if (!hasStartTomorrow && !hasEndTomorrow) return false;
        break;
      case DateScopeEnum.thisWeek:
        // 本周（周一至周日）
        final weekday = localNow.weekday; // 1=Mon .. 7=Sun
        final weekStart = todayStart.subtract(Duration(days: weekday - 1));
        final weekStartUtcMs = weekStart.toUtc().millisecondsSinceEpoch;
        final weekEndUtcMs =
            weekStart
                .add(const Duration(days: 7))
                .toUtc()
                .millisecondsSinceEpoch -
            1;
        final inRange =
            (task.endAt != null &&
                task.endAt! >= weekStartUtcMs &&
                task.endAt! <= weekEndUtcMs) ||
            (task.startAt != null &&
                task.startAt! >= weekStartUtcMs &&
                task.startAt! <= weekEndUtcMs);
        if (!inRange) return false;
        break;
      case DateScopeEnum.customRange:
        if (filter.customDateStart != null && task.endAt != null) {
          if (task.endAt! < filter.customDateStart!) return false;
        }
        if (filter.customDateEnd != null && task.startAt != null) {
          if (task.startAt! > filter.customDateEnd!) return false;
        }
        break;
      case DateScopeEnum.completedToday:
        final effectiveStatus = derivedStatus(task, directChildren);
        if (effectiveStatus != TaskStatus.done) return false;
        final compAt = _getEffectiveCompletedAt(task, directChildren, byId);
        if (compAt == null) return false;
        if (compAt < todayStartUtcMs || compAt > todayEndUtcMs) return false;
        break;
      case DateScopeEnum.all:
        break;
    }
  }

  return true;
}

/// 纯函数：对面板内的任务列表进行排序。
List<Task> sortPanelTasks(
  List<Task> tasks, {
  required String sortBy,
  required String sortDirection,
}) {
  final result = List<Task>.from(tasks);
  final isAsc = sortDirection == 'asc';

  result.sort((a, b) {
    int cmp;
    switch (sortBy) {
      case 'priority':
        cmp = a.priority.index.compareTo(b.priority.index);
        break;
      case 'endAt':
        if (a.endAt == null && b.endAt == null) {
          cmp = 0;
        } else if (a.endAt == null) {
          cmp = 1;
        } else if (b.endAt == null) {
          cmp = -1;
        } else {
          cmp = a.endAt!.compareTo(b.endAt!);
        }
        break;
      case 'updatedAt':
        cmp = a.updatedAt.compareTo(b.updatedAt);
        break;
      case 'title':
        cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        break;
      case 'sortOrder':
      default:
        cmp = a.sortOrder.compareTo(b.sortOrder);
        break;
    }
    return isAsc ? cmp : -cmp;
  });

  return result;
}

TaskStatus _getRecursiveDerivedStatus(
  Task task,
  List<Task> directChildren,
  Map<String, Task> byId,
) {
  final children = directChildren.where((c) => c.deleted == 0).toList();
  if (children.isEmpty) return task.status;

  TaskStatus effectiveChildStatus(Task c) {
    final subChildren = byId.values.where((t) => t.parentId == c.id).toList();
    if (subChildren.isNotEmpty) {
      return _getRecursiveDerivedStatus(c, subChildren, byId);
    }
    return c.status;
  }

  if (children.every((c) => effectiveChildStatus(c) == TaskStatus.done)) {
    return TaskStatus.done;
  }
  if (children.any((c) => effectiveChildStatus(c) == TaskStatus.inProgress)) {
    return TaskStatus.inProgress;
  }
  if (children.every((c) => effectiveChildStatus(c) == TaskStatus.cancelled)) {
    return TaskStatus.cancelled;
  }
  return TaskStatus.todo;
}

/// 计算任务的有效完成时间（UTC 毫秒）。
///
/// - 有直接子任务的任务：递归遍历整棵子树取有效完成时间的最大值；
/// - 无子任务任务：严格使用 [task.completedAt]（旧数据 NULL 不误作今日完成）。
int? _getEffectiveCompletedAt(
  Task task,
  List<Task> directChildren,
  Map<String, Task> byId,
) {
  if (directChildren.isEmpty) {
    return task.completedAt;
  }
  int? maxTime;
  for (final child in directChildren) {
    final subChildren = byId.values
        .where((t) => t.parentId == child.id)
        .toList();
    final t = _getEffectiveCompletedAt(child, subChildren, byId);
    if (t != null && (maxTime == null || t > maxTime)) {
      maxTime = t;
    }
  }
  return maxTime;
}
