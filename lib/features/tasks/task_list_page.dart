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
import '../../core/utils/motion.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/app_menu_item.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/simple_task_tile.dart';
import '../../shared/widgets/staggered_fade_slide.dart';
import '../projects/project_providers.dart';
import '../projects/widgets/project_form_dialog.dart';
import '../today/today_providers.dart';
import 'task_edit_page.dart';
import 'task_providers.dart';
import 'widgets/task_create_sheet.dart';
import 'widgets/task_tree.dart';

/// 任务作用域（56-task-scope-page.md §3.1，路由驱动）。
///
/// 今日 / 收件箱 / 项目三个任务类入口统一渲染为 [TaskListPage]，仅作用域不同。
sealed class TaskScope {
  const TaskScope();
}

/// 今日作用域：逾期 + 今天分组列表（FR-VIEW-01）。
final class TodayTaskScope extends TaskScope {
  const TodayTaskScope();
}

/// 收件箱作用域：内置收件箱项目（inboxProjectId）下的任务树
/// （Bug 3 修复：/inbox 与项目页一致渲染 TaskTree，不再有扁平列表双入口）。
final class InboxTaskScope extends TaskScope {
  const InboxTaskScope();
}

/// 项目作用域：任务树（3 级，拖拽/展开折叠，D1）。
final class ProjectTaskScope extends TaskScope {
  const ProjectTaskScope(this.projectId);

  final String projectId;
}

/// 通用任务页（Task Scope Page）。
///
/// - AppShell 壳内（需求 2：项目作用域下汉堡/底栏/Rail 常驻）。
/// - 标题随作用域动态（今日 = `navToday`；收件箱/项目 = 对应项目名）。
/// - AppBar actions：项目作用域追加编辑/删除；今日/收件箱为默认搜索/设置。
/// - FAB 统一走 `TaskCreateSheet`（今日缺省收件箱；收件箱/项目显式传 projectId）。
/// - 删除项目后跳转 `/today`（D5，新默认首页）。
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key, required this.scope});

  final TaskScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final String title = switch (scope) {
      TodayTaskScope() => l10n.navToday,
      InboxTaskScope() =>
        ref
            .watch(inboxProjectProvider)
            .when(
              data: (p) => p.name,
              loading: () => l10n.inbox,
              error: (_, _) => l10n.inbox,
            ),
      ProjectTaskScope(:final projectId) =>
        ref
            .watch(projectsStreamProvider)
            .when(
              data: (projects) =>
                  projects.where((p) => p.id == projectId).firstOrNull?.name ??
                  l10n.navProjects,
              loading: () => l10n.navProjects,
              error: (_, _) => l10n.navProjects,
            ),
    };

    // 项目作用域：AppBar 追加编辑/删除（D2）。
    final actions = switch (scope) {
      ProjectTaskScope(:final projectId) =>
        ref
            .watch(projectsStreamProvider)
            .when(
              data: (projects) {
                final project = projects
                    .where((p) => p.id == projectId)
                    .firstOrNull;
                if (project == null) return const <Widget>[];
                // 编辑/删除收纳进三点菜单（用户打磨：AppBar 只留一个 more_vert）；
                // 「显示已完成任务」为首项（可勾选开关，与编辑/删除间用 Divider 分隔）。
                final hideDone = ref.watch(hideCompletedTasksProvider);
                return [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      // 显式 switch：未来新增菜单项不会落入默认分支误触发删除。
                      switch (value) {
                        case 'toggleCompleted':
                          ref
                              .read(hideCompletedTasksProvider.notifier)
                              .toggle();
                        case 'edit':
                          _editProject(context, ref, project);
                        case 'delete':
                          _deleteProject(context, ref, project);
                      }
                    },
                    itemBuilder: (context) => [
                      // 名称随状态表达**可执行动作**：显示中 →「隐藏已完成任务」，
                      // 已隐藏 →「显示已完成任务」；眼睛图标同态（睁/闭眼）。
                      AppMenuItem<String>(
                        value: 'toggleCompleted',
                        icon: hideDone
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        label: hideDone
                            ? l10n.showCompletedTasks
                            : l10n.hideCompletedTasks,
                      ),
                      const PopupMenuDivider(),
                      AppMenuItem<String>(
                        value: 'edit',
                        icon: Icons.edit_outlined,
                        label: l10n.edit,
                      ),
                      AppMenuItem<String>(
                        value: 'delete',
                        icon: Icons.delete_outlined,
                        label: l10n.delete,
                        destructive: true,
                      ),
                    ],
                  ),
                ];
              },
              loading: () => const <Widget>[],
              error: (_, _) => const <Widget>[],
            ),
      _ => const <Widget>[],
    };

    // FAB 显示条件（56-task-scope-page.md §3.2）：今日/收件箱/项目均在
    // **data 态**显示（loading/error 隐藏，与旧页面只在 data 态渲染 FAB 一致）。
    final showFab = switch (scope) {
      TodayTaskScope() => true,
      // 与项目作用域同款守卫：仅 data 态显示。收件箱项目行由 ensureInboxProject
      // 幂等保证存在，故 data 态恒为 true——空收件箱也保留 FAB（TaskTree 空态
      // 文案「还没有任务，点击下方按钮新建」依赖底部 FAB，旧版空态「添加任务」
      // 按钮已移除）。
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

    final narrow = AppBreakpoints.isNarrow(context);
    return Scaffold(
      drawer: narrow ? const AppDrawer() : null,
      appBar: AppBar(
        leading: narrow
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: l10n.openDrawer,
                  icon: const Icon(Icons.menu, size: 22),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search, size: 22),
            onPressed: () => context.push('/search'),
          ),
          ...actions,
        ],
      ),
      body: _buildBody(context, ref),
      floatingActionButton: showFab ? _buildFab(context) : null,
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    return switch (scope) {
      TodayTaskScope() => const _TodayBody(),
      InboxTaskScope() => TaskTree(projectId: inboxProjectId),
      ProjectTaskScope(:final projectId) => _ProjectBody(projectId: projectId),
    };
  }

  Widget _buildFab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
      backgroundColor: isDark ? Colors.white : Colors.black,
      foregroundColor: isDark ? Colors.black : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      icon: const Icon(Icons.add, size: 18),
      label: Text(
        l10n.newTask,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
    );
  }

  Future<void> _editProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final result = await showProjectFormDialog(
      context: context,
      initialName: project.name,
      initialColor: project.color,
      initialDescription: project.description,
    );
    if (result != null && context.mounted) {
      await ref
          .read(todoRepositoryProvider)
          .updateProject(
            project.id,
            name: result.name,
            color: result.color,
            description: result.description,
          );
    }
  }

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteProject,
      message: l10n.deleteProjectConfirm(project.name),
      confirmLabel: l10n.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirmed && context.mounted) {
      await ref.read(todoRepositoryProvider).deleteProject(project.id);
      if (context.mounted) {
        context.go('/today');
      }
    }
  }
}

enum _TodayFilter { all, active, completed }

/// 今日作用域 body（从 today_page.dart 抽取，行为不变）。
class _TodayBody extends ConsumerStatefulWidget {
  const _TodayBody();

  @override
  ConsumerState<_TodayBody> createState() => _TodayBodyState();
}

class _TodayBodyState extends ConsumerState<_TodayBody> {
  _TodayFilter _selectedFilter = _TodayFilter.all;

  @override
  Widget build(BuildContext context) {
    final viewAsync = ref.watch(todayViewProvider);

    return viewAsync.when(
      data: (view) {
        return _buildContent(context, view);
      },
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
    final isDark = theme.brightness == Brightness.dark;

    // 1. Calculate counts
    final totalCount = view.overdue.length + view.today.length;
    final completedCount = (view.overdue + view.today)
        .where((v) => v.effectiveStatus == TaskStatus.done)
        .length;
    final activeCount = totalCount - completedCount;

    // 2. Date Formatting
    final now = DateTime.now();
    final isZh = l10n.localeName.startsWith('zh');
    final dateStr = isZh
        ? intl.DateFormat('M月d日').format(now)
        : intl.DateFormat('MMM d').format(now);
    final weekdayStr = isZh
        ? zhWeekdays[now.weekday - 1]
        : intl.DateFormat('EEEE', l10n.localeName).format(now);

    // 3. Filter views based on selection
    final List<TodayTaskView> filteredOverdue;
    final List<TodayTaskView> filteredToday;

    switch (_selectedFilter) {
      case _TodayFilter.active:
        filteredOverdue = view.overdue
            .where((v) => v.effectiveStatus != TaskStatus.done)
            .toList();
        filteredToday = view.today
            .where((v) => v.effectiveStatus != TaskStatus.done)
            .toList();
        break;
      case _TodayFilter.completed:
        filteredOverdue = view.overdue
            .where((v) => v.effectiveStatus == TaskStatus.done)
            .toList();
        filteredToday = view.today
            .where((v) => v.effectiveStatus == TaskStatus.done)
            .toList();
        break;
      case _TodayFilter.all:
        filteredOverdue = view.overdue;
        filteredToday = view.today;
        break;
    }

    final repo = ref.read(todoRepositoryProvider);
    final progressVal = totalCount == 0 ? 0.0 : completedCount / totalCount;

    var tileIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero: 大日期 + 逾期/完成统计 + 进度环
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          dateStr,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 31,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          weekdayStr,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Subtitle: 逾期 2 · 已完成 1/8
                    Row(
                      children: [
                        Text(
                          '${l10n.overdue} ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${view.overdue.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTokens.colorOverdue,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          ' · ${l10n.statusDone} ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '$completedCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '/$totalCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 62x62 进度环
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 62,
                    height: 62,
                    child: CircularProgressIndicator(
                      value: progressVal,
                      strokeWidth: 3.0,
                      strokeCap: StrokeCap.round,
                      backgroundColor: isDark
                          ? AppTokens.borderSubtleDark
                          : AppTokens.borderSubtleLight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    '$completedCount/$totalCount',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      fontFeatures: AppTokens.fontTabular,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 筛选 chips：全部 / 进行中 / 已完成
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip(
                label: '全部',
                count: totalCount,
                filter: _TodayFilter.all,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: '进行中',
                count: activeCount,
                filter: _TodayFilter.active,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: '已完成',
                count: completedCount,
                filter: _TodayFilter.completed,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 任务列表
        Expanded(
          child: filteredOverdue.isEmpty && filteredToday.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.wb_sunny_outlined,
                    accentColor: AppTokens.colorNavToday,
                    message: l10n.emptyToday,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  children: [
                    if (filteredOverdue.isNotEmpty) ...[
                      _SectionHeader(
                        title: l10n.overdue,
                        color: AppTokens.colorOverdue,
                        count: filteredOverdue.length,
                        isError: true,
                      ),
                      for (final v in filteredOverdue)
                        StaggeredFadeSlide(
                          key: ValueKey('overdue-${v.task.id}'),
                          index: tileIndex++,
                          child: _buildTile(context, repo, v),
                        ),
                    ],
                    if (filteredToday.isNotEmpty) ...[
                      _SectionHeader(
                        title: l10n.today,
                        color: colorScheme.onSurfaceVariant,
                        count: filteredToday.length,
                        isError: false,
                      ),
                      for (final v in filteredToday)
                        StaggeredFadeSlide(
                          key: ValueKey('today-${v.task.id}'),
                          index: tileIndex++,
                          child: _buildTile(context, repo, v),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required _TodayFilter filter,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedFilter == filter;

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.onSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? colorScheme.onSurface : borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? colorScheme.surface
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? colorScheme.surface.withValues(alpha: 0.7)
                    : colorScheme.onSurfaceVariant,
                fontSize: 11.5,
                fontFeatures: AppTokens.fontTabular,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    TodoRepository repo,
    TodayTaskView view,
  ) {
    final task = view.task;
    return SimpleTaskTile(
      task: task,
      hasChildren: view.hasChildren,
      isDone: view.effectiveStatus == TaskStatus.done,
      isOverdue: view.isOverdue,
      tags: view.tags,
      projectName: view.projectName,
      projectColor: view.projectColor,
      progressValue: view.progressValue,
      subtaskProgressText: view.subtaskProgressText,
      onTap: () => openTaskEdit(context, taskId: task.id),
      onToggleDone: view.hasChildren
          ? null
          : (_) => repo.updateTask(
              task.id,
              status: view.effectiveStatus == TaskStatus.done
                  ? TaskStatus.todo
                  : TaskStatus.done,
            ),
    );
  }
}

/// 项目作用域 body：任务树（3 级，拖拽/展开折叠）。
///
/// 项目不存在（已被删除/深链失效）时显示空态；任务树自带空态/加载/错误。
class _ProjectBody extends ConsumerWidget {
  const _ProjectBody({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projectsAsync = ref.watch(projectsStreamProvider);

    return projectsAsync.when(
      data: (projects) {
        final exists = projects.any((p) => p.id == projectId);
        if (!exists) {
          return EmptyState(
            icon: Icons.folder_outlined,
            message: l10n.emptyProjects,
          );
        }
        return TaskTree(projectId: projectId);
      },
      loading: () => const LoadingView(),
      error: (e, st) {
        logAsyncError(e, st);
        return ErrorView(onRetry: () => ref.invalidate(projectsStreamProvider));
      },
    );
  }
}

/// 分组标题：逾期组红色（[AppTokens.colorOverdue]），今天组弱色。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.color,
    this.count,
    this.isError = false,
  });

  final String title;
  final Color color;
  final int? count;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: color,
            ),
          ),
          if (count != null)
            Text(
              '$count',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isError ? AppTokens.colorOverdue : color,
                fontFeatures: AppTokens.fontTabular,
              ),
            ),
        ],
      ),
    );
  }
}

/// FAB 按压回弹（docs/63-motion-polish.md §5 I）。
///
/// 按压时 scale 缩至 [AppTokens.fabPressScale]，抬手沿 [motionBounceCurve]
/// 回弹（motionFast）；FloatingActionButton 自带的 Material 涟漪保留。
/// reduced motion：时长归零 → 不缩放（无位移，纯点击）。
class _BouncingFab extends StatefulWidget {
  const _BouncingFab({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_BouncingFab> createState() => _BouncingFabState();
}

class _BouncingFabState extends State<_BouncingFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scale = Tween<double>(begin: 1.0, end: 1.0).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _controller.duration = motionFast(context);
    _scale = Tween<double>(begin: 1.0, end: AppTokens.fabPressScale).animate(
      CurvedAnimation(parent: _controller, curve: motionBounceCurve(context)),
    );
  }

  void _onDown(PointerDownEvent _) {
    if (!mounted || _controller.duration == Duration.zero) return;
    _controller.forward();
  }

  void _onUp(PointerEvent _) {
    if (!mounted || _controller.duration == Duration.zero) return;
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: ScaleTransition(
        scale: _scale,
        child: FloatingActionButton(
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          child: widget.child,
        ),
      ),
    );
  }
}
