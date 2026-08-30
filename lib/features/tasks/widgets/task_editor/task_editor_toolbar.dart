import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/tables.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/priority_color.dart';
import '../../../../core/utils/dates.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../tags/tag_providers.dart';
import '../../task_providers.dart';
import 'tag_picker_sheet.dart';
import 'task_date_picker_dialogs.dart';
import 'task_editor_controller.dart';

/// 底部工具栏：[日期] [状态] [标签] [优先级] [附件占位禁用]（D5/D6/D7）。
class TaskEditorToolbar extends ConsumerWidget {
  const TaskEditorToolbar({super.key, this.statusDisabled = false});

  /// 状态按钮是否禁用（有子任务时状态由子任务派生，AGENTS.md §3-2）。
  final bool statusDisabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasDate = ref.watch(
      taskFormProvider.select((s) => s.startAt != null || s.endAt != null),
    );
    final hasTags = ref.watch(
      taskFormProvider.select((s) => s.selectedTagIds.isNotEmpty),
    );
    final status = ref.watch(taskFormProvider.select((s) => s.status));
    final priority = ref.watch(taskFormProvider.select((s) => s.priority));

    return SizedBox(
      height: AppTokens.touchTarget,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarAction(
            tooltip: l10n.dateAndReminder,
            icon: Icons.calendar_today_outlined,
            active: hasDate,
            onTap: () => showTaskDatePicker(context, ref),
          ),
          _ToolbarAction(
            tooltip: statusDisabled
                ? l10n.statusDerivedFromChildren
                : statusLabel(l10n, status),
            icon: statusIcon(status),
            iconColor: statusColor(status),
            active: status != TaskStatus.todo,
            enabled: !statusDisabled,
            onTap: statusDisabled
                ? null
                : () => showTaskStatusPicker(context, ref),
          ),
          _ToolbarAction(
            tooltip: l10n.taskTags,
            icon: Icons.label_outline,
            active: hasTags,
            onTap: () => showTaskTagPicker(context, ref),
          ),
          _ToolbarAction(
            tooltip: l10n.priority,
            icon: Icons.flag_outlined,
            iconColor: priorityColor(priority),
            active: priority != TaskPriority.none,
            onTap: () => showTaskPriorityPicker(context, ref),
          ),
          // 附件占位（v1 数据模型无附件字段，D5）。
          _ToolbarAction(
            tooltip: l10n.attachmentComingSoon,
            icon: Icons.attach_file,
            enabled: false,
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.tooltip,
    required this.icon,
    this.active = false,
    this.enabled = true,
    this.iconColor,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final bool enabled;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        iconColor ??
        (active
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        onPressed: enabled ? onTap : null,
      ),
    );
  }
}

/// 描述与备注区（细粒度局部组件，输入描述/备注时不触发整树 build）。
class TaskDescriptionNotesSection extends StatelessWidget {
  const TaskDescriptionNotesSection({super.key, required this.controller});

  final TaskEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          children: [
            Consumer(
              builder: (context, ref, _) {
                return TextField(
                  controller: controller.descriptionController,
                  maxLines: 3,
                  scrollPadding: EdgeInsets.zero,
                  decoration: InputDecoration(labelText: l10n.taskDescription),
                  onChanged: (v) =>
                      ref.read(taskFormProvider.notifier).updateDescription(v),
                );
              },
            ),
            if (controller.showNotes) ...[
              const SizedBox(height: AppTokens.spaceSm),
              Consumer(
                builder: (context, ref, _) {
                  return TextField(
                    controller: controller.notesController,
                    maxLines: 2,
                    scrollPadding: EdgeInsets.zero,
                    decoration: InputDecoration(labelText: l10n.taskNotes),
                    onChanged: (v) =>
                        ref.read(taskFormProvider.notifier).updateNotes(v),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 日期展示行（细粒度订阅 startAt / endAt）。
class TaskDateDisplay extends ConsumerWidget {
  const TaskDateDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDate = ref.watch(
      taskFormProvider.select((s) => s.startAt != null || s.endAt != null),
    );
    if (!hasDate) return const SizedBox.shrink();

    final startAt = ref.watch(taskFormProvider.select((s) => s.startAt));
    final endAt = ref.watch(taskFormProvider.select((s) => s.endAt));
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.spaceXs),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTokens.spaceXxs),
          Expanded(
            child: Text(
              formatDateRange(startAt, endAt, l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 已选标签 chips（细粒度订阅 selectedTagIds）。
class TaskSelectedTagChips extends ConsumerWidget {
  const TaskSelectedTagChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTagIds = ref.watch(
      taskFormProvider.select((s) => s.selectedTagIds),
    );
    if (selectedTagIds.isEmpty) return const SizedBox.shrink();

    final tags = ref.watch(tagsStreamProvider).value ?? const <Tag>[];
    final selectedTags = [
      for (final id in selectedTagIds)
        if (tags.any((t) => t.id == id)) tags.firstWhere((t) => t.id == id),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.spaceXs),
      child: Wrap(
        spacing: AppTokens.spaceXs,
        runSpacing: AppTokens.spaceXs,
        children: [for (final tag in selectedTags) TagChip(tag: tag)],
      ),
    );
  }
}
