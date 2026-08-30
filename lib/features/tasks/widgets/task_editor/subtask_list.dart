import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import 'subtask_row_tile.dart';
import 'task_editor_controller.dart';

/// 子任务管理区（D3/D9）：
/// - 列表：ReorderableListView.builder，每个项为 [SubtaskRowTile]
/// - 底部：+ 添加子任务按钮（点击追加一行新子任务并自动请求焦点）
class SubtaskList extends StatelessWidget {
  const SubtaskList({
    super.key,
    required this.controller,
    required this.onAddSubtaskAndFocus,
    required this.onConfirmRemoveSubtask,
  });

  final TaskEditorController controller;
  final VoidCallback onAddSubtaskAndFocus;
  final void Function(SubtaskRow) onConfirmRemoveSubtask;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.subtasks,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (controller.subtaskRows.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: controller.subtaskRows.length,
                onReorder: controller.reorderSubtasks,
                itemBuilder: (context, index) {
                  final row = controller.subtaskRows[index];
                  return SubtaskRowTile(
                    key: ObjectKey(row),
                    index: index,
                    row: row,
                    onRemove: () => onConfirmRemoveSubtask(row),
                    onSubmitted: onAddSubtaskAndFocus,
                    onChanged: controller.notifySubtasksChanged,
                    onToggleStatus: () => controller.toggleSubtaskStatus(row),
                  );
                },
              ),
            TextButton.icon(
              onPressed: onAddSubtaskAndFocus,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addSubtask),
            ),
          ],
        );
      },
    );
  }
}
