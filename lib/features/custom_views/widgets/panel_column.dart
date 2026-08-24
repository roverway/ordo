import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/custom_view_models.dart';
import '../../projects/project_providers.dart';
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
        return Container(
          decoration: BoxDecoration(
            color: isHovered
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: Border.all(
              color: isHovered
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isHovered ? 2 : 1,
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
              const Divider(height: 1),

              // ── 任务列表区 ──
              Expanded(
                child: panelTasksAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text(err.toString())),
                  data: (data) {
                    if (data.tasks.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.spaceMd),
                          child: Text(
                            l10n.noTasksInPanel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppTokens.spaceSm),
                      itemCount: data.tasks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppTokens.spaceXs),
                      itemBuilder: (context, index) {
                        final task = data.tasks[index];
                        final project = projectsMap[task.projectId];
                        return _buildTaskCard(
                          context,
                          ref,
                          theme,
                          l10n,
                          task,
                          project,
                        );
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
        width: 320,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceXs),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      child: Row(
        children: [
          // 面板标题
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    panel.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTokens.textHeadingWeight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                  ),
                  child: Text(
                    count.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 排序按钮
          PopupMenuButton<String>(
            tooltip: l10n.sortBy,
            icon: const Icon(Icons.sort, size: 20),
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
                value: 'sortOrder',
                checked: panel.sortBy == 'sortOrder',
                child: Text(l10n.sortOrderManual),
              ),
              CheckedPopupMenuItem<String>(
                value: 'priority',
                checked: panel.sortBy == 'priority',
                child: Text(l10n.sortOrderPriority),
              ),
              CheckedPopupMenuItem<String>(
                value: 'endAt',
                checked: panel.sortBy == 'endAt',
                child: Text(l10n.sortOrderDueDate),
              ),
              CheckedPopupMenuItem<String>(
                value: 'title',
                checked: panel.sortBy == 'title',
                child: Text(l10n.sortOrderTitle),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'toggle_direction',
                child: Row(
                  children: [
                    Icon(
                      panel.sortDirection == 'asc'
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 18,
                    ),
                    const SizedBox(width: AppTokens.spaceXs),
                    Text(
                      panel.sortDirection == 'asc'
                          ? l10n.sortAsc
                          : l10n.sortDesc,
                    ),
                  ],
                ),
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
              size: 20,
              color: panel.filter.hasActiveFilter
                  ? theme.colorScheme.primary
                  : null,
            ),
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
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (val) {
                if (val == 'delete') {
                  onDeletePanel?.call();
                } else if (val == 'edit_title') {
                  _showEditTitleDialog(context, l10n);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'edit_title',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: AppTokens.spaceXs),
                      Text(l10n.editPanel),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: AppTokens.spaceXs),
                      Text(
                        l10n.deletePanel,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ),
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
        title: Text(l10n.editPanel),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.panelTitle),
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

  Widget _buildTaskCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations l10n,
    Task task,
    Project? project,
  ) {
    final isDone = task.status == TaskStatus.done;
    final isDark = theme.brightness == Brightness.dark;

    final card = Material(
      color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      elevation: 1,
      child: InkWell(
        onTap: () => context.push('/task/${task.id}'),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 状态勾选 + 标题
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final repo = ref.read(todoRepositoryProvider);
                      final children = await repo.tasks.getDirectChildren(
                        task.projectId,
                        task.id,
                      );
                      if (children.isNotEmpty) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.parentTaskDerivedStatusNotice),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }
                      final newStatus = isDone
                          ? TaskStatus.todo
                          : TaskStatus.done;
                      await repo.updateTask(task.id, status: newStatus);
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(
                        top: 2,
                        right: AppTokens.spaceXs,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? AppTokens.checkboxDoneFill
                            : Colors.transparent,
                        border: Border.all(
                          color: isDone
                              ? AppTokens.checkboxDoneFill
                              : theme.colorScheme.outline,
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: AppTokens.colorOnCheck,
                            )
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (task.priority != TaskPriority.none) ...[
                    const SizedBox(width: AppTokens.spaceXs),
                    _buildPriorityFlag(task.priority),
                  ],
                ],
              ),

              // 项目与日期芯片
              if (project != null || task.endAt != null) ...[
                const SizedBox(height: AppTokens.spaceXs),
                Wrap(
                  spacing: AppTokens.spaceXs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (project != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Color(project.color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusChip,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 3,
                              backgroundColor: Color(project.color),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              project.name,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Color(project.color),
                                fontWeight: FontWeight.w500,
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
    );

    // 支持桌面直接拖拽与移动端长按拖拽
    final isMobile =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

    final feedback = Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      child: SizedBox(width: 280, child: Opacity(opacity: 0.85, child: card)),
    );

    if (isMobile) {
      return LongPressDraggable<Task>(
        data: task,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.3, child: card),
        child: card,
      );
    }

    return Draggable<Task>(
      data: task,
      feedback: feedback,
      childWhenDragging: Opacity(opacity: 0.3, child: card),
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
    return Icon(Icons.flag, size: 16, color: color);
  }

  Widget _buildDueDateBadge(BuildContext context, ThemeData theme, int endAt) {
    final now = DateTime.now();
    final dueDate = DateTime.fromMillisecondsSinceEpoch(endAt).toLocal();
    final isOverdue = dueDate.isBefore(DateTime(now.year, now.month, now.day));

    final dateStr = '${dueDate.month}/${dueDate.day}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 12,
          color: isOverdue
              ? AppTokens.colorOverdue
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 2),
        Text(
          dateStr,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isOverdue
                ? AppTokens.colorOverdue
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAddButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceXs),
      child: InkWell(
        onTap: () {
          final queryParams = <String, String>{};
          if (panel.filter.projectIds.length == 1) {
            queryParams['projectId'] = panel.filter.projectIds.first;
          }
          final uri = Uri(path: '/task/new', queryParameters: queryParams);
          context.push(uri.toString());
        },
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceSm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppTokens.spaceXs),
              Text(
                l10n.newTask,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
