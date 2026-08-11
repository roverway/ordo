import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../shared/widgets/app_shell.dart';
import '../projects/project_providers.dart';
import '../tasks/task_providers.dart';

/// Inbox page — the launch home.
///
/// TickTick / Microsoft To Do inspired: clean task list, generous whitespace,
/// soft checkboxes. Shows level-1 tasks from the inbox project.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final inboxProjectAsync = ref.watch(inboxProjectProvider);
    final tasksAsync = ref.watch(inboxTasksProvider);

    final title = inboxProjectAsync.when(
      data: (p) => p.name,
      loading: () => l10n.inbox,
      error: (_, _) => l10n.inbox,
    );

    return AppShell(
      title: title,
      child: tasksAsync.when(
        data: (tasks) {
          final rootTasks = tasks.where((t) => t.parentId == null).toList();
          if (rootTasks.isEmpty) {
            return _buildEmptyState(context, l10n, ref);
          }
          return _buildTaskList(context, l10n, ref, rootTasks);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 40,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppTokens.spaceXl),
            Text(
              l10n.emptyInbox,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceLg),
            FilledButton.icon(
              onPressed: () => _goNewTask(context),
              icon: const Icon(Icons.add, size: 20),
              label: Text(l10n.addTask),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
    List<Task> rootTasks,
  ) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMd,
            vertical: AppTokens.spaceSm,
          ),
          itemCount: rootTasks.length,
          itemBuilder: (context, index) {
            final task = rootTasks[index];
            return _InboxTaskTile(
              task: task,
              onToggleDone: (value) => _toggleDone(ref, task, value),
              onTap: () => context.push('/task/${task.id}'),
            );
          },
        ),
        Positioned(
          right: AppTokens.spaceMd,
          bottom: AppTokens.spaceMd,
          child: FloatingActionButton(
            tooltip: l10n.newTask,
            onPressed: () => _goNewTask(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _goNewTask(BuildContext context) {
    // Inbox tasks: no explicit projectId is needed since createTask defaults
    // to inboxProjectId when absent. But the task edit page requires projectId
    // so we pass 'inbox' explicitly.
    context.push('/task/new?projectId=inbox');
  }

  Future<void> _toggleDone(WidgetRef ref, Task task, bool? value) async {
    final repo = ref.read(todoRepositoryProvider);
    final newStatus = value == true ? TaskStatus.done : TaskStatus.todo;
    try {
      await repo.updateTask(task.id, status: newStatus);
    } catch (_) {
      // Silently fail toggle — status will revert via stream.
    }
  }
}

/// A single inbox task row: checkbox + title + optional due date.
class _InboxTaskTile extends StatelessWidget {
  const _InboxTaskTile({
    required this.task,
    required this.onToggleDone,
    required this.onTap,
  });

  final Task task;
  final ValueChanged<bool?> onToggleDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDone = task.status == TaskStatus.done;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: AppTokens.spaceXs,
            ),
            child: Row(
              children: [
                // Checkbox
                SizedBox(
                  width: AppTokens.touchTarget,
                  height: AppTokens.touchTarget,
                  child: Checkbox(value: isDone, onChanged: onToggleDone),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                // Title + due date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: isDone
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.endAt != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppTokens.spaceXxs,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: _dueDateColor(task.endAt!, colorScheme),
                              ),
                              const SizedBox(width: AppTokens.spaceXxs),
                              Text(
                                formatDueDate(task.endAt!, AppLocalizations.of(context)),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _dueDateColor(
                                    task.endAt!,
                                    colorScheme,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Chevron
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.outline.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _dueDateColor(int endAtMs, ColorScheme colorScheme) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (task.status != TaskStatus.done && endAtMs < now) {
      return AppTokens.colorOverdue;
    }
    return colorScheme.onSurfaceVariant;
  }
}
