import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/custom_view_models.dart';
import '../../../shared/widgets/animated_strikethrough.dart';
import '../../../shared/widgets/app_menu_item.dart';
import '../../projects/project_providers.dart';
import '../../tasks/task_edit_page.dart';
import '../../tasks/widgets/task_create_sheet.dart';
import '../providers/custom_view_providers.dart';
import 'filter_criteria_sheet.dart';

/// 单个筛选面板列组件（支持看板横向滚动与窄屏单面板展示）。
class PanelColumn extends ConsumerWidget {
  const PanelColumn({
    super.key,
    required this.panel,
    this.onUpdatePanel,
    this.onDeletePanel,
    this.onTaskDropped,
    this.isKanban = true,
  });

  final CustomViewPanelConfig panel;
  final ValueChanged<CustomViewPanelConfig>? onUpdatePanel;
  final VoidCallback? onDeletePanel;
  final void Function(Task task, CustomViewPanelConfig targetPanel)?
  onTaskDropped;
  final bool isKanban;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final panelTasksAsync = ref.watch(panelTasksProvider(panel));
    final projectsMap =
        ref.watch(allProjectsMapProvider).value ?? const <String, Project>{};

    final content = DragTarget<Task>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        onTaskDropped?.call(details.data, panel);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        final isDark = theme.brightness == Brightness.dark;

        final isNarrow = !isKanban;
        return Container(
          decoration: isNarrow
              ? null
              : BoxDecoration(
                  color: isHovered
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: AppTokens.alphaTintStrong,
                        )
                      // 凹陷面：比页面底沉一档的列井，浅深双模式对称取自令牌。
                      : (isDark
                            ? AppTokens.surfaceSunkenDark
                            : AppTokens.surfaceSunkenLight),
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                  border: Border.all(
                    color: isHovered
                        ? theme.colorScheme.primary
                        : (isDark
                              ? AppTokens.borderSubtleDark
                              : AppTokens.borderSubtleLight),
                    width: isHovered ? 1.5 : 1,
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 面板头部 ──
              _buildHeader(
                context,
                theme,
                l10n,
                panelTasksAsync.value?.totalCount ?? 0,
              ),

              // ── 任务列表区 ──
              Expanded(
                child: panelTasksAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.spaceMd),
                      child: Text(
                        err.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                  data: (data) {
                    if (data.tasks.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.spaceMd,
                            vertical: AppTokens.spaceLg,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 36,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.35),
                              ),
                              const SizedBox(height: AppTokens.spaceXs),
                              Text(
                                l10n.noTasksInPanel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceSm,
                        vertical: AppTokens.spaceXs,
                      ),
                      itemCount: data.tasks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppTokens.spaceXs),
                      itemBuilder: (context, index) {
                        final task = data.tasks[index];
                        final project = projectsMap[task.projectId];
                        return KanbanTaskCard(task: task, project: project);
                      },
                    );
                  },
                ),
              ),

              // ── 底部快速新建任务按钮 ──
              _buildQuickAddButton(context, theme, l10n),
            ],
          ),
        );
      },
    );

    if (isKanban) {
      return SizedBox(
        width: 310,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceXs,
            vertical: AppTokens.spaceXs,
          ),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceSm),
      child: content,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    int count,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceMd,
        AppTokens.spaceSm,
        AppTokens.spaceXs,
        AppTokens.spaceXs,
      ),
      child: Row(
        children: [
          // 面板标题 + 数量 Badge
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    panel.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: AppTokens.textHeadingWeight,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                  ),
                  child: Text(
                    count.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 排序按钮
          PopupMenuButton<String>(
            tooltip: l10n.sortBy,
            icon: Icon(
              Icons.swap_vert,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            padding: EdgeInsets.zero,
            onSelected: (val) {
              if (val == 'toggle_direction') {
                final newDir = panel.sortDirection == 'asc' ? 'desc' : 'asc';
                onUpdatePanel?.call(panel.copyWith(sortDirection: newDir));
              } else {
                onUpdatePanel?.call(panel.copyWith(sortBy: val));
              }
            },
            itemBuilder: (ctx) => [
              CheckedPopupMenuItem<String>(
                height: AppTokens.menuItemHeight,
                value: 'sortOrder',
                checked: panel.sortBy == 'sortOrder',
                child: Text(l10n.sortOrderManual),
              ),
              CheckedPopupMenuItem<String>(
                height: AppTokens.menuItemHeight,
                value: 'priority',
                checked: panel.sortBy == 'priority',
                child: Text(l10n.sortOrderPriority),
              ),
              CheckedPopupMenuItem<String>(
                height: AppTokens.menuItemHeight,
                value: 'endAt',
                checked: panel.sortBy == 'endAt',
                child: Text(l10n.sortOrderDueDate),
              ),
              CheckedPopupMenuItem<String>(
                height: AppTokens.menuItemHeight,
                value: 'title',
                checked: panel.sortBy == 'title',
                child: Text(l10n.sortOrderTitle),
              ),
              const PopupMenuDivider(),
              AppMenuItem<String>(
                value: 'toggle_direction',
                icon: panel.sortDirection == 'asc'
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                label: panel.sortDirection == 'asc'
                    ? l10n.sortAsc
                    : l10n.sortDesc,
              ),
            ],
          ),

          // 筛选按钮
          IconButton(
            tooltip: l10n.filterCriteria,
            icon: Icon(
              panel.filter.hasActiveFilter
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
              size: 19,
              color: panel.filter.hasActiveFilter
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () async {
              final newCriteria = await showFilterCriteriaSheet(
                context: context,
                initialCriteria: panel.filter,
              );
              if (newCriteria != null) {
                onUpdatePanel?.call(panel.copyWith(filter: newCriteria));
              }
            },
          ),

          // 更多操作
          if (onDeletePanel != null)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              onSelected: (val) {
                if (val == 'delete') {
                  onDeletePanel?.call();
                } else if (val == 'edit_title') {
                  _showEditTitleDialog(context, l10n);
                }
              },
              itemBuilder: (ctx) => [
                AppMenuItem(
                  value: 'edit_title',
                  icon: Icons.edit_outlined,
                  label: l10n.editPanel,
                ),
                AppMenuItem(
                  value: 'delete',
                  icon: Icons.delete_outline,
                  label: l10n.deletePanel,
                  destructive: true,
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showEditTitleDialog(BuildContext context, AppLocalizations l10n) {
    final controller = TextEditingController(text: panel.title);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        ),
        title: Text(l10n.editPanel),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.panelTitle,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                onUpdatePanel?.call(panel.copyWith(title: newTitle));
              }
              Navigator.of(dialogCtx).pop();
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceSm,
        AppTokens.spaceXs,
        AppTokens.spaceSm,
        AppTokens.spaceSm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            TaskCreateSheet.show(
              context,
              projectId: panel.filter.projectIds.length == 1
                  ? panel.filter.projectIds.first
                  : null,
              initialPriority: panel.filter.priorities.length == 1
                  ? panel.filter.priorities.first
                  : null,
              initialTagIds: panel.filter.tagIds.isNotEmpty
                  ? panel.filter.tagIds
                  : null,
            );
          },
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusButton),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? AppTokens.borderSubtleDark
                    : AppTokens.borderSubtleLight,
                width: 1.0,
              ),
              color: theme.brightness == Brightness.dark
                  ? AppTokens.surfaceCardDark
                  : AppTokens.surfaceCard,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 17, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  l10n.newTask,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 看板卡片组件（[ConsumerWidget]）。
///
/// 独立抽离以隔离单个卡片的局部构建、派生状态交互与拖拽包装，避免在 [PanelColumn] 中内联膨胀。
class KanbanTaskCard extends ConsumerWidget {
  const KanbanTaskCard({super.key, required this.task, this.project});

  final Task task;
  final Project? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDone = task.status == TaskStatus.done;
    final isDark = theme.brightness == Brightness.dark;

    final card = Container(
      decoration: BoxDecoration(
        color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(
          color: isDark
              ? AppTokens.borderSubtleDark
              : AppTokens.borderSubtleLight,
          width: 1.0,
        ),
        boxShadow: isDark
            ? AppTokens.cardShadowDarkList
            : AppTokens.cardShadowLight,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: InkWell(
          onTap: () => openTaskEdit(context, taskId: task.id),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 状态勾选 + 标题 + 优先级
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标准 Checkbox（全 app 唯一勾选形态：主题层圆形 +
                    // checkboxDoneFill 蓝填充；紧凑卡内用 shrinkWrap 触控区）。
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 1,
                        right: AppTokens.spaceXs,
                      ),
                      child: Checkbox(
                        key: ValueKey('kanban_checkbox_${task.id}'),
                        value: isDone,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                        onChanged: (value) async {
                          final repo = ref.read(todoRepositoryProvider);
                          final children = await repo.tasks.getDirectChildren(
                            task.projectId,
                            task.id,
                          );
                          if (children.isNotEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.parentTaskDerivedStatusNotice,
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            return;
                          }
                          final newStatus = value == true
                              ? TaskStatus.done
                              : TaskStatus.todo;
                          await repo.updateTask(task.id, status: newStatus);
                        },
                      ),
                    ),
                    Expanded(
                      child: AnimatedStrikethrough(
                        text: task.title,
                        isDone: isDone,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDone
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (task.priority != TaskPriority.none) ...[
                      const SizedBox(width: AppTokens.spaceXs),
                      _buildPriorityFlag(task.priority),
                    ],
                  ],
                ),

                // 项目徽章与日期
                if (project != null || task.endAt != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (project != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Color(
                              project!.color,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusChip,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 3,
                                backgroundColor: Color(project!.color),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                project!.name,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Color(project!.color),
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppTokens.textMicroSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (task.endAt != null)
                        _buildDueDateBadge(context, theme, task.endAt!),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final isMobile =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

    final feedback = Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 290, child: Opacity(opacity: 0.9, child: card)),
    );

    if (isMobile) {
      return LongPressDraggable<Task>(
        data: task,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: card,
      );
    }

    return Draggable<Task>(
      data: task,
      feedback: feedback,
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Widget _buildPriorityFlag(TaskPriority priority) {
    Color color;
    switch (priority) {
      case TaskPriority.high:
        color = AppTokens.colorPriorityHigh;
      case TaskPriority.medium:
        color = AppTokens.colorPriorityMedium;
      case TaskPriority.low:
        color = AppTokens.colorPriorityLow;
      case TaskPriority.none:
        return const SizedBox.shrink();
    }
    return Icon(Icons.flag_outlined, size: 15, color: color);
  }

  Widget _buildDueDateBadge(BuildContext context, ThemeData theme, int endAt) {
    final now = DateTime.now();
    final dueDate = DateTime.fromMillisecondsSinceEpoch(endAt).toLocal();
    final isOverdue = dueDate.isBefore(DateTime(now.year, now.month, now.day));

    final dateStr = '${dueDate.month}/${dueDate.day}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isOverdue
            ? AppTokens.colorOverdue.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 11,
            color: isOverdue
                ? AppTokens.colorOverdue
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            dateStr,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: AppTokens.textMicroSize,
              color: isOverdue
                  ? AppTokens.colorOverdue
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
