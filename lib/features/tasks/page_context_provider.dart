import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/repositories/todo_repository.dart' show inboxProjectId;

/// 任务作用域（56-task-scope-page.md §3.1，路由驱动）。
sealed class TaskScope {
  const TaskScope();
}

/// 今日作用域：逾期 + 今天分组列表。
final class TodayTaskScope extends TaskScope {
  const TodayTaskScope();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TodayTaskScope;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// 收集箱作用域：内置收件箱项目（inboxProjectId）下的任务树。
final class InboxTaskScope extends TaskScope {
  const InboxTaskScope();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InboxTaskScope;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// 项目作用域：特定项目清单。
final class ProjectTaskScope extends TaskScope {
  const ProjectTaskScope(this.projectId);

  final String projectId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectTaskScope && projectId == other.projectId;

  @override
  int get hashCode => projectId.hashCode;
}

/// 当前活动页面的精确上下文（用于快速新建任务、全局操作栏联动等）。
///
/// 遵循乔布斯极简交互哲学与高内聚低耦合原则：
/// - 直接复用既有的 [TaskScope]、[inboxProjectId] 与日历选中日期，避免新增重复业务实体；
/// - 提供清晰的只读上下文与响应式通知，让悬浮 Dock 与全局新建能力实现“所见即所建”。
@immutable
class PageContextScope {
  const PageContextScope({
    this.projectId,
    this.focusedDate,
    this.route,
    this.taskScope,
  });

  /// 关联的目标项目 ID（如来自 ProjectTaskScope 或 InboxTaskScope）
  final String? projectId;

  /// 关联的目标聚焦日期（如来自 Calendar 选中日或 TodayTaskScope）
  final DateTime? focusedDate;

  /// 当前路由路径（如 /today, /calendar, /projects/:id）
  final String? route;

  /// 底层对应的 TaskScope（若当前页属于任务清单域）
  final TaskScope? taskScope;

  static const empty = PageContextScope();

  /// 从已有的 TaskScope 构建精准上下文（直接复用 TaskScope，无冗余实体）
  factory PageContextScope.fromTaskScope(TaskScope scope, {String? route}) {
    final projectId = switch (scope) {
      ProjectTaskScope(:final projectId) => projectId,
      InboxTaskScope() => inboxProjectId,
      TodayTaskScope() => null,
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    final focusedDate = switch (scope) {
      TodayTaskScope() => today,
      _ => null,
    };
    return PageContextScope(
      projectId: projectId,
      focusedDate: focusedDate,
      route: route,
      taskScope: scope,
    );
  }

  /// 从日历选中日期构建上下文
  factory PageContextScope.fromCalendarDate(
    DateTime date, {
    String? route = '/calendar',
  }) {
    return PageContextScope(projectId: null, focusedDate: date, route: route);
  }

  PageContextScope copyWith({
    String? projectId,
    DateTime? focusedDate,
    String? route,
    TaskScope? taskScope,
  }) {
    return PageContextScope(
      projectId: projectId ?? this.projectId,
      focusedDate: focusedDate ?? this.focusedDate,
      route: route ?? this.route,
      taskScope: taskScope ?? this.taskScope,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageContextScope &&
          runtimeType == other.runtimeType &&
          projectId == other.projectId &&
          focusedDate == other.focusedDate &&
          route == other.route &&
          taskScope == other.taskScope;

  @override
  int get hashCode => Object.hash(projectId, focusedDate, route, taskScope);
}

/// 页面上下文作用域状态管理器
class PageContextScopeNotifier extends Notifier<PageContextScope> {
  @override
  PageContextScope build() {
    return PageContextScope.empty;
  }

  /// 显式设置当前页面作用域
  void setScope(PageContextScope scope) {
    if (state != scope) {
      state = scope;
    }
  }

  /// 从 TaskScope 更新当前作用域
  void setFromTaskScope(TaskScope scope, {String? route}) {
    final newScope = PageContextScope.fromTaskScope(scope, route: route);
    if (state != newScope) {
      state = newScope;
    }
  }

  /// 从日历选中日期更新当前作用域
  void setCalendarDate(DateTime date, {String? route = '/calendar'}) {
    final newScope = PageContextScope.fromCalendarDate(date, route: route);
    if (state != newScope) {
      state = newScope;
    }
  }

  /// 重置作用域
  void clear() {
    if (state != PageContextScope.empty) {
      state = PageContextScope.empty;
    }
  }
}

/// 全局活动页面上下文作用域 Provider
final pageContextScopeProvider =
    NotifierProvider<PageContextScopeNotifier, PageContextScope>(
      PageContextScopeNotifier.new,
    );
