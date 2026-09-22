import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/theme/app_tokens.dart';

/// 四象限类型枚举（艾森豪威尔矩阵）。
enum QuadrantType {
  /// 第一象限：重要且紧急（Q1）
  urgentImportant,

  /// 第二象限：重要不紧急（Q2）
  notUrgentImportant,

  /// 第三象限：不重要但紧急（Q3）
  urgentUnimportant,

  /// 第四象限：不重要不紧急（Q4）
  notUrgentUnimportant,
}

/// 四象限类型元数据与展示扩展。
extension QuadrantTypeX on QuadrantType {
  /// 象限特征强调色（遵循 AppTokens 设计规范，零魔法值）。
  Color get accentColor {
    switch (this) {
      case QuadrantType.urgentImportant:
        return AppTokens.colorPriorityHigh;
      case QuadrantType.notUrgentImportant:
        return AppTokens.colorPriorityMedium;
      case QuadrantType.urgentUnimportant:
        return AppTokens.colorPriorityLow;
      case QuadrantType.notUrgentUnimportant:
        return AppTokens.colorQuadrantQ4;
    }
  }

  /// 语义图标。
  IconData get icon {
    switch (this) {
      case QuadrantType.urgentImportant:
        return Icons.local_fire_department_rounded;
      case QuadrantType.notUrgentImportant:
        return Icons.star_rounded;
      case QuadrantType.urgentUnimportant:
        return Icons.notifications_active_rounded;
      case QuadrantType.notUrgentUnimportant:
        return Icons.inventory_2_outlined;
    }
  }

  /// 默认新建任务优先级。
  TaskPriority get initialPriority {
    switch (this) {
      case QuadrantType.urgentImportant:
      case QuadrantType.notUrgentImportant:
        return TaskPriority.high;
      case QuadrantType.urgentUnimportant:
      case QuadrantType.notUrgentUnimportant:
        return TaskPriority.none;
    }
  }

  /// 默认新建任务截止时间戳（UTC 毫秒）。
  int? initialEndAt(DateTime now) {
    switch (this) {
      case QuadrantType.urgentImportant:
      case QuadrantType.urgentUnimportant:
        return DateTime(
          now.year,
          now.month,
          now.day,
          23,
          59,
          59,
          999,
        ).millisecondsSinceEpoch;
      case QuadrantType.notUrgentImportant:
      case QuadrantType.notUrgentUnimportant:
        return null;
    }
  }
}

/// 单个四象限任务展示视图模型。
class QuadrantTaskView {
  const QuadrantTaskView({
    required this.task,
    required this.quadrant,
    required this.tags,
    required this.effectiveStatus,
    required this.hasChildren,
    required this.isOverdue,
    this.projectName,
    this.projectColor,
    this.progressValue,
    this.subtaskProgressText,
  });

  final Task task;
  final QuadrantType quadrant;
  final List<Tag> tags;
  final TaskStatus effectiveStatus;
  final bool hasChildren;
  final bool isOverdue;
  final String? projectName;
  final int? projectColor;
  final double? progressValue;
  final String? subtaskProgressText;
}

/// 四个象限的任务聚合数据容器。
class QuadrantData {
  const QuadrantData({
    required this.q1UrgentImportant,
    required this.q2NotUrgentImportant,
    required this.q3UrgentUnimportant,
    required this.q4NotUrgentUnimportant,
  });

  final List<QuadrantTaskView> q1UrgentImportant;
  final List<QuadrantTaskView> q2NotUrgentImportant;
  final List<QuadrantTaskView> q3UrgentUnimportant;
  final List<QuadrantTaskView> q4NotUrgentUnimportant;

  List<QuadrantTaskView> tasksOf(QuadrantType type) => forType(type);

  List<QuadrantTaskView> forType(QuadrantType type) {
    switch (type) {
      case QuadrantType.urgentImportant:
        return q1UrgentImportant;
      case QuadrantType.notUrgentImportant:
        return q2NotUrgentImportant;
      case QuadrantType.urgentUnimportant:
        return q3UrgentUnimportant;
      case QuadrantType.notUrgentUnimportant:
        return q4NotUrgentUnimportant;
    }
  }

  int get totalCount =>
      q1UrgentImportant.length +
      q2NotUrgentImportant.length +
      q3UrgentUnimportant.length +
      q4NotUrgentUnimportant.length;

  bool get isEmpty => totalCount == 0;
}

/// 四象限筛选器状态配置。
class QuadrantFilterState {
  const QuadrantFilterState({
    this.selectedProjectIds,
    this.showCompleted = false,
  });

  /// 选中的项目清单 id 集合。null 表示全选/全量范围。
  final Set<String>? selectedProjectIds;

  /// 是否展示已完成任务（默认仅规划待办任务）。
  final bool showCompleted;

  /// 是否处于自定义清单范围筛选模式。
  bool get isCustomScoped => selectedProjectIds != null;

  /// 判断任务是否命中筛选范围。
  bool matches(Task task) {
    if (selectedProjectIds == null) return true;
    return selectedProjectIds!.contains(task.projectId);
  }

  QuadrantFilterState copyWith({
    Set<String>? selectedProjectIds,
    bool clearProjectIds = false,
    bool? showCompleted,
  }) {
    return QuadrantFilterState(
      selectedProjectIds: clearProjectIds
          ? null
          : (selectedProjectIds ?? this.selectedProjectIds),
      showCompleted: showCompleted ?? this.showCompleted,
    );
  }
}

/// 纯函数：根据当前时间基准与任务自身属性判定其所属象限。
QuadrantType classifyTask(Task task, DateTime now) {
  final endOfToday = DateTime(
    now.year,
    now.month,
    now.day,
    23,
    59,
    59,
    999,
  ).millisecondsSinceEpoch;

  final isImportant =
      task.priority == TaskPriority.high ||
      task.priority == TaskPriority.medium;

  // 逾期（< now）或今天截止（<= endOfToday）均视为紧急
  final isUrgent = task.endAt != null && task.endAt! <= endOfToday;

  if (isImportant && isUrgent) {
    return QuadrantType.urgentImportant;
  } else if (isImportant && !isUrgent) {
    return QuadrantType.notUrgentImportant;
  } else if (!isImportant && isUrgent) {
    return QuadrantType.urgentUnimportant;
  } else {
    return QuadrantType.notUrgentUnimportant;
  }
}

/// 纯函数：计算跨象限拖拽放置时，任务需要更新的优先级与截止时间。
///
/// **关键约束**：绝对不触碰任务所属清单 [Task.projectId] 与层级关系 [Task.parentId]。
({TaskPriority priority, int? endAt}) calculateQuadrantMutation(
  QuadrantType target,
  Task task,
  DateTime now,
) {
  final endOfToday = DateTime(
    now.year,
    now.month,
    now.day,
    23,
    59,
    59,
    999,
  ).millisecondsSinceEpoch;

  final isImportant =
      task.priority == TaskPriority.high ||
      task.priority == TaskPriority.medium;

  final isUrgent = task.endAt != null && task.endAt! <= endOfToday;

  switch (target) {
    case QuadrantType.urgentImportant:
      return (
        priority: isImportant ? task.priority : TaskPriority.high,
        endAt: isUrgent ? task.endAt : endOfToday,
      );

    case QuadrantType.notUrgentImportant:
      return (
        priority: isImportant ? task.priority : TaskPriority.high,
        endAt: isUrgent ? null : task.endAt,
      );

    case QuadrantType.urgentUnimportant:
      return (
        priority: isImportant ? TaskPriority.none : task.priority,
        endAt: isUrgent ? task.endAt : endOfToday,
      );

    case QuadrantType.notUrgentUnimportant:
      return (
        priority: isImportant ? TaskPriority.none : task.priority,
        endAt: isUrgent ? null : task.endAt,
      );
  }
}
