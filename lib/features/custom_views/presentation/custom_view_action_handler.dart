import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/custom_view_models.dart';
import '../../projects/project_providers.dart';
import '../providers/custom_view_providers.dart';

/// 自定义视图动作处理器（解耦 UI 渲染与复杂业务判定/弹窗编排）。
class CustomViewActionHandler {
  const CustomViewActionHandler(this.ref);

  final WidgetRef ref;

  void updatePanel(CustomView view, int index, CustomViewPanelConfig updated) {
    final panels = List<CustomViewPanelConfig>.from(
      decodePanelsJson(view.panelsJson),
    );
    panels[index] = updated;
    ref.read(customViewOperationsProvider).updateView(view.id, panels: panels);
  }

  void deletePanel(CustomView view, int index) {
    final panels = List<CustomViewPanelConfig>.from(
      decodePanelsJson(view.panelsJson),
    );
    panels.removeAt(index);
    ref.read(customViewOperationsProvider).updateView(view.id, panels: panels);
  }

  Future<void> handleTaskDrop({
    required BuildContext context,
    required CustomView view,
    required Task task,
    required CustomViewPanelConfig targetPanel,
  }) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(todoRepositoryProvider);
    final ops = ref.read(customViewOperationsProvider);

    // 查找 sourcePanel
    final panels = decodePanelsJson(view.panelsJson);
    CustomViewPanelConfig? sourcePanel;
    for (final p in panels) {
      if (p.id != targetPanel.id) {
        sourcePanel = p;
        break;
      }
    }
    sourcePanel ??= targetPanel;

    // 检查是否有子任务（AGENTS.md 硬性约束：派生状态）
    final children = await repo.tasks.getDirectChildren(
      task.projectId,
      task.id,
    );
    final hasSubtasks = children.isNotEmpty;

    final result = await ops.handleTaskDroppedBetweenPanels(
      task: task,
      sourcePanel: sourcePanel,
      targetPanel: targetPanel,
      hasSubtasks: hasSubtasks,
    );

    if (!context.mounted) return;

    if (result.actionType == PanelDropActionType.derivedStatusBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? l10n.parentTaskDerivedStatusNotice),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result.actionType == PanelDropActionType.requiresConfirmation) {
      _showConfirmationDialog(context, task, targetPanel, result);
    }
  }

  void _showConfirmationDialog(
    BuildContext context,
    Task task,
    CustomViewPanelConfig targetPanel,
    PanelDropResult result,
  ) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(todoRepositoryProvider);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        ),
        title: Text(l10n.confirm),
        content: Text(l10n.customViewMoveConfirmMessage(targetPanel.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.cancel),
          ),
          if (result.targetStatus != null)
            FilledButton.tonal(
              onPressed: () async {
                await repo.updateTask(task.id, status: result.targetStatus!);
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: Text(
                l10n.customViewModifyStatusTo(result.targetStatus!.name),
              ),
            ),
          if (result.targetPriority != null)
            FilledButton.tonal(
              onPressed: () async {
                await repo.updateTask(
                  task.id,
                  priority: result.targetPriority!,
                );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: Text(
                l10n.customViewModifyPriorityTo(result.targetPriority!.name),
              ),
            ),
          if (result.targetProjectId != null)
            FilledButton.tonal(
              onPressed: () async {
                await repo.moveTaskToProject(task.id, result.targetProjectId!);
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: Text(l10n.customViewModifyProject),
            ),
        ],
      ),
    );
  }

  Future<void> confirmDeleteView(BuildContext context, CustomView view) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        ),
        title: Text(l10n.deleteCustomView),
        content: Text(l10n.deleteCustomViewConfirm(view.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(customViewOperationsProvider).deleteView(view.id);
      if (context.mounted) {
        context.go('/today');
      }
    }
  }
}
