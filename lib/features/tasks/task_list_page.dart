import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import '../../core/utils/dates.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/filter_chips_bar.dart';
import '../../shared/widgets/hero_progress_ring.dart';
import '../../shared/widgets/inline_search_bar.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/page_hero_header.dart';
import '../../shared/widgets/scope_switcher_sheet.dart';
import '../../shared/widgets/simple_task_tile.dart';
import '../projects/project_providers.dart';
import '../today/today_providers.dart';
import 'task_providers.dart';
import 'widgets/task_create_sheet.dart';
import 'widgets/task_swipe_wrapper.dart';
import 'widgets/task_tree.dart';

/// 任务作用域（56-task-scope-page.md §3.1，路由驱动）。
sealed class TaskScope {
  const TaskScope();
}

/// 今日作用域：逾期 + 今天分组列表。
final class TodayTaskScope extends TaskScope {
  const TodayTaskScope();
}

/// 收集箱作用域：内置收件箱项目（inboxProjectId）下的任务树。
final class InboxTaskScope extends TaskScope {
  const InboxTaskScope();
}

/// 项目作用域：任务树。
final class ProjectTaskScope extends TaskScope {
  const ProjectTaskScope(this.projectId);

  final String projectId;
}

/// 通用任务页（Task Scope Page）—— modern-minimal 纯净单屏交互。
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key, required this.scope});

  final TaskScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNarrow = AppBreakpoints.isNarrow(context);

    // FAB 显示守卫
    final showFab = switch (scope) {
      TodayTaskScope() => true,
      InboxTaskScope() =>
        ref
            .watch(projectsStreamProvider)
            .maybeWhen(
              data: (projects) => projects.any((p) => p.id == inboxProjectId),
              orElse: () => false,
            ),
      ProjectTaskScope(:final projectId) =>
        ref
            .watch(projectsStreamProvider)
            .maybeWhen(
              data: (projects) => projects.any((p) => p.id == projectId),
              orElse: () => false,
            ),
    };

    return Scaffold(
      body: SafeArea(bottom: false, child: _buildBody(context, ref, isNarrow)),
      floatingActionButton: showFab ? _buildFab(context) : null,
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, bool isNarrow) {
    return switch (scope) {
      TodayTaskScope() => _TodayBody(isNarrow: isNarrow),
      InboxTaskScope() => _ProjectOrInboxBody(
        projectId: inboxProjectId,
        isInbox: true,
        isNarrow: isNarrow,
      ),
      ProjectTaskScope(:final projectId) => _ProjectOrInboxBody(
        projectId: projectId,
        isInbox: false,
        isNarrow: isNarrow,
      ),
    };
  }

  Widget _buildFab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return FloatingActionButton.extended(
      tooltip: l10n.newTask,
      onPressed: () => switch (scope) {
        TodayTaskScope() => TaskCreateSheet.show(context),
        InboxTaskScope() => TaskCreateSheet.show(
          context,
          projectId: inboxProjectId,
        ),
        ProjectTaskScope(:final projectId) => TaskCreateSheet.show(
          context,
          projectId: projectId,
        ),
      },
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      icon: const Icon(Icons.add, size: 20),
      label: Text(
        l10n.newTask,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
    );
  }
}

/// 今日作用域页面 Body（大日期 Hero + 逾期分组 + 今天分组 + 筛选 Chips + 内联搜索）。
class _TodayBody extends ConsumerStatefulWidget {
  const _TodayBody({required this.isNarrow});

  final bool isNarrow;

  @override
  ConsumerState<_TodayBody> createState() => _TodayBodyState();
}

class _TodayBodyState extends ConsumerState<_TodayBody> {
  TaskFilterChipMode _filterMode = TaskFilterChipMode.all;
  bool _isSearchOpen = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewAsync = ref.watch(todayViewProvider);

    return viewAsync.when(
      data: (view) => _buildContent(context, view),
      loading: () => const LoadingView(),
      error: (e, st) {
        logAsyncError(e, st);
        return ErrorView(onRetry: () => ref.invalidate(todayViewProvider));
      },
    );
  }

  Widget _buildContent(BuildContext context, TodayViewData view) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 统计数量（直接使用 TodayViewData 高性能聚合属性）
    final totalCount = view.totalCount;
    final completedCount = view.completedCount;
    final openCount = view.uncompletedCount;

    // 日期格式化
    final now = DateTime.now();
    final isZh = l10n.localeName.startsWith('zh');
    final dateStr = isZh
        ? intl.DateFormat('M月d日').format(now)
        : intl.DateFormat('MMM d').format(now);
    final weekdayStr = isZh
        ? zhWeekdays[now.weekday - 1]
        : intl.DateFormat('EEEE', l10n.localeName).format(now);

    // 筛选与搜索
    List<TodayTaskView> overdueList = view.overdue;
    List<TodayTaskView> todayList = view.today;

    if (_filterMode == TaskFilterChipMode.open) {
      overdueList = overdueList
          .where((v) => v.effectiveStatus != TaskStatus.done)
          .toList();
      todayList = todayList
          .where((v) => v.effectiveStatus != TaskStatus.done)
          .toList();
    } else if (_filterMode == TaskFilterChipMode.done) {
      overdueList = overdueList
          .where((v) => v.effectiveStatus == TaskStatus.done)
          .toList();
      todayList = todayList
          .where((v) => v.effectiveStatus == TaskStatus.done)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      overdueList = overdueList
          .where(
            (v) =>
                v.task.title.toLowerCase().contains(q) ||
                v.task.description.toLowerCase().contains(q),
          )
          .toList();
      todayList = todayList
          .where(
            (v) =>
                v.task.title.toLowerCase().contains(q) ||
                v.task.description.toLowerCase().contains(q),
          )
          .toList();
    }

    final repo = ref.read(todoRepositoryProvider);

    return Column(
      children: [
        // 固定顶部 Hero 头部
        PageHeroHeader(
          title: dateStr,
          onTitleTap: widget.isNarrow
              ? () => showScopeSwitcherSheet(context)
              : null,
          subtitleWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekdayStr,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                ' · ${l10n.overdueSubtitle} ',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${view.overdue.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: view.overdue.isNotEmpty
                      ? AppTokens.colorOverdue
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                ' · ${l10n.completedSubtitle} ',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$completedCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '/$totalCount',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          trailing: HeroProgressRing(
            completed: completedCount,
            total: totalCount,
          ),
        ),

        // 固定筛选 Chips + 内联搜索
        FilterChipsBar(
          selectedMode: _filterMode,
          onModeChanged: (mode) => setState(() => _filterMode = mode),
          allCount: totalCount,
          openCount: openCount,
          doneCount: completedCount,
          isSearchOpen: _isSearchOpen,
          onToggleSearch: () {
            setState(() {
              _isSearchOpen = !_isSearchOpen;
              if (!_isSearchOpen) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
        ),
        InlineSearchBar(
          isOpen: _isSearchOpen,
          controller: _searchController,
          matchCount: overdueList.length + todayList.length,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          onClear: () => setState(() => _searchQuery = ''),
        ),

        // 任务列表滚动区
        Expanded(
          child: CustomScrollView(
            slivers: [
              // 逾期分组
              if (overdueList.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildGroupHeader(
                    title: l10n.overdue,
                    count: overdueList.length,
                    countColor: AppTokens.colorOverdue,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final v = overdueList[index];
                      return TaskSwipeWrapper(
                        key: ValueKey('overdue_${v.task.id}'),
                        task: v.task,
                        hasChildren: v.hasChildren,
                        isDone: v.effectiveStatus == TaskStatus.done,
                        child: SimpleTaskTile(
                          task: v.task,
                          hasChildren: v.hasChildren,
                          isDone: v.effectiveStatus == TaskStatus.done,
                          isOverdue: true,
                          tags: v.tags,
                          projectName: v.projectName,
                          projectColor: v.projectColor,
                          progressValue: v.progressValue,
                          subtaskProgressText: v.subtaskProgressText,
                          onTap: () => context.push('/task/${v.task.id}'),
                          onToggleDone: (done) async {
                            final newStatus = (done ?? false)
                                ? TaskStatus.done
                                : TaskStatus.todo;
                            try {
                              await repo.updateTask(
                                v.task.id,
                                status: newStatus,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.taskUpdateFailed),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      );
                    }, childCount: overdueList.length),
                  ),
                ),
              ],

              // 今天分组
              if (todayList.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildGroupHeader(
                    title: l10n.today,
                    count: todayList.length,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final v = todayList[index];
                      return TaskSwipeWrapper(
                        key: ValueKey('today_${v.task.id}'),
                        task: v.task,
                        hasChildren: v.hasChildren,
                        isDone: v.effectiveStatus == TaskStatus.done,
                        child: SimpleTaskTile(
                          task: v.task,
                          hasChildren: v.hasChildren,
                          isDone: v.effectiveStatus == TaskStatus.done,
                          isOverdue: false,
                          tags: v.tags,
                          projectName: v.projectName,
                          projectColor: v.projectColor,
                          progressValue: v.progressValue,
                          subtaskProgressText: v.subtaskProgressText,
                          onTap: () => context.push('/task/${v.task.id}'),
                          onToggleDone: (done) async {
                            final newStatus = (done ?? false)
                                ? TaskStatus.done
                                : TaskStatus.todo;
                            try {
                              await repo.updateTask(
                                v.task.id,
                                status: newStatus,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.taskUpdateFailed),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      );
                    }, childCount: todayList.length),
                  ),
                ),
              ],

              // 空态提示
              if (overdueList.isEmpty && todayList.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: Icons.done_all_rounded,
                      message: _searchQuery.isNotEmpty
                          ? l10n.searchNoResults
                          : (_filterMode == TaskFilterChipMode.done
                                ? l10n.noCompletedTasks
                                : l10n.emptyToday),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupHeader({
    required String title,
    required int count,
    Color? countColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: countColor ?? colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'monospace',
              fontFeatures: AppTokens.fontTabular,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: countColor ?? colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 收集箱 / 项目作用域 Body（Hero 头部 + 筛选器 + 任务树 TaskTree）。
class _ProjectOrInboxBody extends ConsumerStatefulWidget {
  const _ProjectOrInboxBody({
    required this.projectId,
    required this.isInbox,
    required this.isNarrow,
  });

  final String projectId;
  final bool isInbox;
  final bool isNarrow;

  @override
  ConsumerState<_ProjectOrInboxBody> createState() =>
      _ProjectOrInboxBodyState();
}

class _ProjectOrInboxBodyState extends ConsumerState<_ProjectOrInboxBody> {
  TaskFilterChipMode _filterMode = TaskFilterChipMode.all;
  bool _isSearchOpen = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final projectAsync = ref.watch(projectsStreamProvider);
    final folders = ref.watch(foldersStreamProvider).value ?? const <Folder>[];

    return projectAsync.when(
      data: (projects) {
        final project = projects
            .where((p) => p.id == widget.projectId)
            .firstOrNull;
        if (project == null && !widget.isInbox) {
          return Center(
            child: EmptyState(
              icon: Icons.folder_open_outlined,
              message: l10n.emptyProjects,
            ),
          );
        }
        final title = widget.isInbox
            ? l10n.inbox
            : (project?.name ?? l10n.navProjects);

        final folderName = widget.isInbox
            ? l10n.inbox
            : (folders
                      .where((f) => f.id == project?.folderId)
                      .firstOrNull
                      ?.name ??
                  l10n.ungrouped);

        final summary = ref.watch(projectSummaryProvider(widget.projectId));
        final tasks =
            ref.watch(projectTasksProvider(widget.projectId)).value ??
            const <Task>[];
        final totalCount = summary.totalCount;
        final openCount = summary.uncompletedCount;
        final doneCount = (totalCount - openCount).clamp(0, totalCount);
        final rootCount = tasks.where((t) => t.parentId == null).length;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Column(
          children: [
            PageHeroHeader(
              title: title,
              subtitleWidget: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: folderName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: ' · ',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: l10n.itemCount(rootCount),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: ' · ${l10n.completedSubtitle} ',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: '$doneCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: '/$totalCount',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTitleTap: widget.isNarrow
                  ? () => showScopeSwitcherSheet(context)
                  : null,
              trailing: HeroProgressRing(
                completed: doneCount,
                total: totalCount,
              ),
            ),
            FilterChipsBar(
              selectedMode: _filterMode,
              onModeChanged: (mode) => setState(() => _filterMode = mode),
              allCount: totalCount,
              openCount: openCount,
              doneCount: doneCount,
              isSearchOpen: _isSearchOpen,
              onToggleSearch: () {
                setState(() {
                  _isSearchOpen = !_isSearchOpen;
                  if (!_isSearchOpen) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
            ),
            InlineSearchBar(
              isOpen: _isSearchOpen,
              controller: _searchController,
              matchCount: _searchQuery.isNotEmpty
                  ? tasks
                        .where(
                          (t) =>
                              t.title.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ) ||
                              t.description.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ),
                        )
                        .length
                  : null,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              onClear: () => setState(() => _searchQuery = ''),
            ),
            Expanded(
              child: TaskTree(
                projectId: widget.projectId,
                filterMode: _filterMode,
                searchQuery: _searchQuery,
              ),
            ),
          ],
        );
      },
      loading: () => const LoadingView(),
      error: (e, st) {
        logAsyncError(e, st);
        return ErrorView(onRetry: () => ref.invalidate(projectsStreamProvider));
      },
    );
  }
}
