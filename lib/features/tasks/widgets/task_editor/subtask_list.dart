import 'package:flutter/material.dart';

import '../../../../core/db/tables.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
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
        final totalCount = controller.subtaskRows.length;
        final doneCount = controller.subtaskRows
            .where((r) => r.status == TaskStatus.done)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.subtasks,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                  if (totalCount > 0)
                    Text(
                      '$doneCount/$totalCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: AppTokens.fontTabular,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
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
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onAddSubtaskAndFocus,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          size: 13,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.addSubtask,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
