import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/priority_color.dart';
import '../../../core/utils/dates.dart';
import '../../projects/project_providers.dart';
import '../../tags/tag_providers.dart';
import '../task_providers.dart';
import 'task_editor/project_picker_sheet.dart';
import 'task_editor/tag_picker_sheet.dart';
import 'task_editor/task_date_picker_dialogs.dart';

/// 新建任务弹窗的胶囊选项栏（项目选择、开始时间、截止时间）。
class TaskCreatePillRow extends ConsumerWidget {
  const TaskCreatePillRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final startAt = ref.watch(taskFormProvider.select((s) => s.startAt));
    final endAt = ref.watch(taskFormProvider.select((s) => s.endAt));
    final projectId = ref.watch(taskFormProvider.select((s) => s.projectId));
    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final currentProject = projects.where((p) => p.id == projectId).firstOrNull;

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // 项目 Pill
          _buildPillButton(
            onTap: () => showTaskProjectPicker(context, ref),
            leading: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: currentProject != null
                    ? Color(currentProject.color)
                    : AppTokens.colorCancelled,
                shape: BoxShape.circle,
              ),
            ),
            label: currentProject?.name ?? l10n.inbox,
            borderColor: borderColor,
            colorScheme: colorScheme,
            isDark: isDark,
          ),

          const SizedBox(width: AppTokens.spaceSm),

          // 起止时间 Pill
          _buildSchedulePill(
            context: context,
            ref: ref,
            hasValue: startAt != null || endAt != null,
            label: (startAt != null || endAt != null)
                ? formatScheduleDisplay(startAt, endAt, l10n)
                : l10n.taskDateRange,
            icon: Icons.calendar_today_outlined,
            borderColor: borderColor,
            colorScheme: colorScheme,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required VoidCallback onTap,
    required Widget leading,
    required String label,
    required Color borderColor,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest.withValues(
                  alpha: AppTokens.alphaBorderEmphasis,
                )
              : AppTokens.surfaceSubtleLight,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulePill({
    required BuildContext context,
    required WidgetRef ref,
    required bool hasValue,
    required String label,
    required IconData icon,
    required Color borderColor,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => showTaskDatePicker(context, ref),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: hasValue
              ? colorScheme.primary.withValues(alpha: AppTokens.alphaTintSoft)
              : (isDark
                    ? colorScheme.surfaceContainerHighest.withValues(
                        alpha: AppTokens.alphaBorderEmphasis,
                      )
                    : AppTokens.surfaceSubtleLight),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(
            color: hasValue
                ? colorScheme.primary.withValues(
                    alpha: AppTokens.alphaBorderEmphasis,
                  )
                : borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: hasValue
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                color: hasValue ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 新建任务弹窗的优先级选择器。
class TaskCreatePriorityRow extends ConsumerWidget {
  const TaskCreatePriorityRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final priority = ref.watch(taskFormProvider.select((s) => s.priority));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4.0),
      child: Row(
        children: [
          Icon(
            Icons.flag_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            l10n.priority,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: AppTokens.textFootnoteSize,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest.withValues(
                      alpha: AppTokens.alphaContentMuted,
                    )
                  : colorScheme.onSurface.withValues(
                      alpha: AppTokens.alphaTintFaint,
                    ),
              borderRadius: BorderRadius.circular(AppTokens.radiusList),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in [
                  TaskPriority.none,
                  TaskPriority.low,
                  TaskPriority.medium,
                  TaskPriority.high,
                ])
                  InkWell(
                    onTap: () =>
                        ref.read(taskFormProvider.notifier).updatePriority(p),
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: priority == p
                            ? (p == TaskPriority.none
                                  ? colorScheme.surface
                                  : priorityColor(p).withValues(
                                      alpha: AppTokens.alphaTintStrong,
                                    ))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusChip,
                        ),
                        border: priority == p && p != TaskPriority.none
                            ? Border.all(
                                color: priorityColor(p).withValues(
                                  alpha: AppTokens.alphaContentDisabled,
                                ),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Text(
                        _getPriorityLabel(l10n, p),
                        style: TextStyle(
                          fontSize: AppTokens.textCaptionSize,
                          fontWeight: priority == p
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: priority == p
                              ? (p == TaskPriority.none
                                    ? colorScheme.onSurface
                                    : priorityColor(p))
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPriorityLabel(AppLocalizations l10n, TaskPriority p) =>
      switch (p) {
        TaskPriority.high => l10n.priorityHigh,
        TaskPriority.medium => l10n.priorityMedium,
        TaskPriority.low => l10n.priorityLow,
        TaskPriority.none => l10n.priorityNone,
      };
}

/// 新建任务弹窗的标签选择行。
class TaskCreateTagRow extends ConsumerWidget {
  const TaskCreateTagRow({required this.borderColor, super.key});

  final Color borderColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final selectedTagIds = ref.watch(
      taskFormProvider.select((s) => s.selectedTagIds),
    );
    final tags = ref.watch(tagsStreamProvider).value ?? const <Tag>[];

    return InkWell(
      onTap: () => showTaskTagPicker(context, ref),
      borderRadius: BorderRadius.circular(AppTokens.radiusList),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4.0),
        child: Row(
          children: [
            Icon(
              Icons.label_outline,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              l10n.taskTags,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: AppTokens.textFootnoteSize,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedTagIds.isEmpty)
                  Text(
                    l10n.notAdded,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: AppTokens.alphaContentMuted,
                      ),
                      fontSize: AppTokens.textFootnoteSize,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final id in selectedTagIds)
                        if (tags.any((t) => t.id == id))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusPill,
                              ),
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      tags.firstWhere((t) => t.id == id).color,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tags.firstWhere((t) => t.id == id).name,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: AppTokens.textMicroSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                const SizedBox(width: 6),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
