import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import '../../core/utils/dates.dart';
import '../../shared/widgets/app_background_wrapper.dart';
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
import 'task_edit_page.dart';
import 'task_providers.dart';
import 'widgets/task_create_sheet.dart';
import 'widgets/task_swipe_wrapper.dart';
import 'widgets/task_tree.dart';

export 'page_context_provider.dart';
import 'page_context_provider.dart';

/// 通用任务页（Task Scope Page）—— modern-minimal 纯净单屏交互。
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key, required this.scope});

  final TaskScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(pageContextScopeProvider.notifier)
          .setFromTaskScope(
            scope,
            route: switch (scope) {
              ProjectTaskScope(:final projectId) => '/projects/$projectId',
              InboxTaskScope() => '/inbox',
              TodayTaskScope() => '/today',
            },
          );
    });

    final isNarrow = AppBreakpoints.isNarrow(context);

    final projectId = switch (scope) {
      ProjectTaskScope(:final projectId) => projectId,
      InboxTaskScope() => inboxProjectId,
      TodayTaskScope() => null,
    };

    final isDualPane = AppBreakpoints.isDualPane(context);
    final selectedTaskId = ref.watch(desktopSelectedTaskIdProvider);
    final theme = Theme.of(context);

    return AppBackgroundWrapper(
      projectId: projectId,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: (isDualPane && selectedTaskId != null)
              ? Row(
                  children: [
                    Expanded(child: _buildBody(context, ref, isNarrow)),
                    Container(
                      width: 420,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: AppTokens.alphaBorderSubtle,
                            ),
                          ),
                        ),
                      ),
                      child: TaskEditPage(
                        key: ValueKey(selectedTaskId),
                        taskId: selectedTaskId,
                        onClose: () => ref
                            .read(desktopSelectedTaskIdProvider.notifier)
                            .select(null),
                      ),
                    ),
                  ],
                )
              : (isNarrow
                    ? _buildBody(context, ref, isNarrow)
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: _buildBody(context, ref, isNarrow),
                        ),
                      )),
        ),
        floatingActionButton: null,
      ),
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
  double _spotlightOverscroll = 0.0;
  bool _hasTriggeredSpotlight = false;

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
        // 固定顶部 Hero 头部（支持点击展开任务清单组下拉菜单）
        PageHeroHeader(
          title: dateStr,
          showDropdownChevron: true,
          onTitleTapWithContext: (ctx) => showTaskScopeSheet(ctx),
          subtitleWidget: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: weekdayStr,
                  style: TextStyle(
                    fontSize: AppTokens.textCaptionSize,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: ' · ${l10n.overdueSubtitle} ',
                  style: TextStyle(
                    fontSize: AppTokens.textCaptionSize,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                TextSpan(
                  text: '${view.overdue.length}',
                  style: TextStyle(
                    fontSize: AppTokens.textCaptionSize,
                    fontWeight: FontWeight.w700,
                    color: view.overdue.isNotEmpty
                        ? AppTokens.colorOverdue
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                TextSpan(
                  text: ' · ${l10n.completedSubtitle} ',
                  style: TextStyle(
                    fontSize: AppTokens.textCaptionSize,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                TextSpan(
                  text: '$completedCount',
                  style: TextStyle(
                    fontSize: AppTokens.textCaptionSize,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: '/$totalCount',
                  style: TextStyle(
                    fontSize: AppTokens.textCaptionSize,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.isNarrow) ...[
                FilledButton.icon(
                  onPressed: () => TaskCreateSheet.show(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    l10n.newTask,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppTokens.textSecondarySize,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceMd),
              ] else ...[
                IconButton(
                  tooltip: l10n.newTask,
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => TaskCreateSheet.show(context),
                ),
                const SizedBox(width: AppTokens.spaceXs),
              ],
              HeroProgressRing(completed: completedCount, total: totalCount),
            ],
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
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                if (notification.metrics.pixels < -60 &&
                    !_hasTriggeredSpotlight) {
                  _hasTriggeredSpotlight = true;
                  HapticFeedback.mediumImpact();
                  context.push('/search');
                }
              } else if (notification is OverscrollNotification) {
                if (notification.overscroll < 0) {
                  _spotlightOverscroll -= notification.overscroll;
                  if (_spotlightOverscroll > 60 && !_hasTriggeredSpotlight) {
                    _hasTriggeredSpotlight = true;
                    HapticFeedback.mediumImpact();
                    context.push('/search');
                  }
                }
              } else if (notification is ScrollEndNotification) {
                _spotlightOverscroll = 0.0;
                _hasTriggeredSpotlight = false;
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
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
                            isSelected:
                                ref.watch(desktopSelectedTaskIdProvider) ==
                                v.task.id,
                            onTap: () {
                              if (AppBreakpoints.isDualPane(context)) {
                                if (ref
                                    .read(taskFormProvider.notifier)
                                    .hasChanges) {
                                  ref.read(taskFormProvider.notifier).save();
                                }
                                ref
                                    .read(
                                      desktopSelectedTaskIdProvider.notifier,
                                    )
                                    .select(v.task.id);
                              } else {
                                openTaskEdit(context, taskId: v.task.id);
                              }
                            },
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
                            isSelected:
                                ref.watch(desktopSelectedTaskIdProvider) ==
                                v.task.id,
                            onTap: () {
                              if (AppBreakpoints.isDualPane(context)) {
                                if (ref
                                    .read(taskFormProvider.notifier)
                                    .hasChanges) {
                                  ref.read(taskFormProvider.notifier).save();
                                }
                                ref
                                    .read(
                                      desktopSelectedTaskIdProvider.notifier,
                                    )
                                    .select(v.task.id);
                              } else {
                                openTaskEdit(context, taskId: v.task.id);
                              }
                            },
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

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: widget.isNarrow ? 130 : AppTokens.spaceXl,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  MainAxisSize dynamicMainAxisSize(TodayViewData view) => MainAxisSize.min;

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
              fontSize: AppTokens.textSectionLabelSize,
              fontWeight: AppTokens.textSectionLabelWeight,
              letterSpacing: AppTokens.textSectionLabelLetterSpacing,
              color: countColor ?? colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontFeatures: AppTokens.fontTabular,
              fontSize: AppTokens.textSectionLabelSize,
              fontWeight: AppTokens.textSectionLabelWeight,
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
              showDropdownChevron: true,
              subtitleWidget: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: folderName,
                      style: TextStyle(
                        fontSize: AppTokens.textCaptionSize,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: ' · ',
                      style: TextStyle(
                        fontSize: AppTokens.textCaptionSize,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: l10n.itemCount(rootCount),
                      style: TextStyle(
                        fontSize: AppTokens.textCaptionSize,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: ' · ${l10n.completedSubtitle} ',
                      style: TextStyle(
                        fontSize: AppTokens.textCaptionSize,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: '$doneCount',
                      style: TextStyle(
                        fontSize: AppTokens.textCaptionSize,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: '/$totalCount',
                      style: TextStyle(
                        fontSize: AppTokens.textCaptionSize,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTitleTapWithContext: (ctx) => showTaskScopeSheet(ctx),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isNarrow) ...[
                    FilledButton.icon(
                      onPressed: () => TaskCreateSheet.show(
                        context,
                        projectId: widget.isInbox
                            ? inboxProjectId
                            : widget.projectId,
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusPill,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        l10n.newTask,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppTokens.textSecondarySize,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceMd),
                  ] else ...[
                    IconButton(
                      tooltip: l10n.newTask,
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => TaskCreateSheet.show(
                        context,
                        projectId: widget.isInbox
                            ? inboxProjectId
                            : widget.projectId,
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceXs),
                  ],
                  HeroProgressRing(completed: doneCount, total: totalCount),
                ],
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
