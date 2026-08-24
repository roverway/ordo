import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../core/utils/custom_view_models.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../projects/project_providers.dart';
import '../providers/custom_view_providers.dart';
import '../widgets/icon_picker_dialog.dart';
import '../widgets/panel_column.dart';

/// 自定义视图主页面（支持多栏看板与多 Tab 响应式切换）。
class CustomViewPage extends ConsumerStatefulWidget {
  const CustomViewPage({super.key, required this.viewId});

  final String viewId;

  @override
  ConsumerState<CustomViewPage> createState() => _CustomViewPageState();
}

class _CustomViewPageState extends ConsumerState<CustomViewPage> {
  // 本地临时面板状态（支持在视图页微调面板筛选与排序）
  List<CustomViewPanelConfig>? _localPanels;

  List<CustomViewPanelConfig> _getEffectivePanels(CustomView view) {
    return _localPanels ?? decodePanelsJson(view.panelsJson);
  }

  void _onUpdatePanel(
    CustomView view,
    int index,
    CustomViewPanelConfig updated,
  ) {
    final panels = List<CustomViewPanelConfig>.from(_getEffectivePanels(view));
    panels[index] = updated;
    setState(() => _localPanels = panels);

    // 异步持久化至数据库
    ref.read(customViewOperationsProvider).updateView(view.id, panels: panels);
  }

  void _onDeletePanel(CustomView view, int index) {
    final panels = List<CustomViewPanelConfig>.from(_getEffectivePanels(view));
    panels.removeAt(index);
    setState(() => _localPanels = panels);

    ref.read(customViewOperationsProvider).updateView(view.id, panels: panels);
  }

  Future<void> _handleTaskDrop({
    required CustomView view,
    required Task task,
    required CustomViewPanelConfig targetPanel,
  }) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(todoRepositoryProvider);
    final ops = ref.read(customViewOperationsProvider);

    // 查找 sourcePanel
    final panels = _getEffectivePanels(view);
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

    if (!mounted) return;

    if (result.actionType == PanelDropActionType.derivedStatusBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? l10n.parentTaskDerivedStatusNotice),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result.actionType == PanelDropActionType.requiresConfirmation) {
      _showConfirmationDialog(task, targetPanel, result);
    }
  }

  void _showConfirmationDialog(
    Task task,
    CustomViewPanelConfig targetPanel,
    PanelDropResult result,
  ) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(todoRepositoryProvider);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.confirm),
        content: Text('移动到「${targetPanel.title}」面板，请确认要修改的任务属性：'),
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
              child: Text('修改状态为 ${result.targetStatus!.name}'),
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
              child: Text('修改优先级为 ${result.targetPriority!.name}'),
            ),
          if (result.targetProjectId != null)
            FilledButton.tonal(
              onPressed: () async {
                await repo.moveTaskToProject(task.id, result.targetProjectId!);
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: const Text('修改所属项目'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteView(CustomView view) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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

    if (confirmed == true) {
      await ref.read(customViewOperationsProvider).deleteView(view.id);
      if (mounted) {
        context.go('/today');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isWide = AppBreakpoints.isWide(context);

    final viewAsync = ref.watch(customViewDetailProvider(widget.viewId));

    return viewAsync.when(
      loading: () => const Scaffold(
        drawer: AppDrawer(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(),
        body: Center(child: Text(err.toString())),
      ),
      data: (CustomView? view) {
        if (view == null) {
          return Scaffold(
            drawer: const AppDrawer(),
            appBar: AppBar(title: Text(l10n.customViews)),
            body: Center(child: Text(l10n.noCustomViews)),
          );
        }

        final panels = _getEffectivePanels(view);

        // 如果视图没有面板，提供空状态与引导添加面板
        if (panels.isEmpty) {
          return Scaffold(
            drawer: const AppDrawer(),
            appBar: AppBar(
              title: Row(
                children: [
                  Icon(getCustomViewIcon(view.icon), color: Color(view.color)),
                  const SizedBox(width: AppTokens.spaceSm),
                  Text(view.name),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: l10n.editCustomView,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/custom_view/${view.id}/edit'),
                ),
              ],
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dashboard_customize_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceMd),
                  Text(l10n.noTasksInPanel, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppTokens.spaceSm),
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/custom_view/${view.id}/edit'),
                    icon: const Icon(Icons.tune),
                    label: Text(l10n.editCustomView),
                  ),
                ],
              ),
            ),
          );
        }

        // 宽屏模式（≥600dp）或指定 kanban 布局时：横向多列看板
        if (isWide || view.layoutMode == 'kanban') {
          return Scaffold(
            drawer: const AppDrawer(),
            appBar: AppBar(
              title: Row(
                children: [
                  Icon(getCustomViewIcon(view.icon), color: Color(view.color)),
                  const SizedBox(width: AppTokens.spaceSm),
                  Text(view.name),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: l10n.editCustomView,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/custom_view/${view.id}/edit'),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'delete') {
                      _confirmDeleteView(view);
                    }
                  },
                  itemBuilder: (ctx) => [
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
                            l10n.deleteCustomView,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppTokens.spaceSm,
                horizontal: AppTokens.spaceSm,
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: panels.length,
                itemBuilder: (context, index) {
                  final panel = panels[index];
                  return PanelColumn(
                    key: ValueKey(panel.id),
                    panel: panel,
                    isKanban: true,
                    onUpdatePanel: (updated) =>
                        _onUpdatePanel(view, index, updated),
                    onDeletePanel: () => _onDeletePanel(view, index),
                    onTaskDropped: (task, targetPanel) => _handleTaskDrop(
                      view: view,
                      task: task,
                      targetPanel: targetPanel,
                    ),
                  );
                },
              ),
            ),
          );
        }

        // 窄屏列表模式：顶部 TabBar + PageView
        return DefaultTabController(
          length: panels.length,
          child: Scaffold(
            drawer: const AppDrawer(),
            appBar: AppBar(
              title: Row(
                children: [
                  Icon(getCustomViewIcon(view.icon), color: Color(view.color)),
                  const SizedBox(width: AppTokens.spaceSm),
                  Text(view.name),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: l10n.editCustomView,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/custom_view/${view.id}/edit'),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'delete') {
                      _confirmDeleteView(view);
                    }
                  },
                  itemBuilder: (ctx) => [
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
                            l10n.deleteCustomView,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              bottom: TabBar(
                isScrollable: panels.length > 3,
                tabAlignment: panels.length > 3 ? TabAlignment.start : null,
                tabs: panels.map((p) => Tab(text: p.title)).toList(),
              ),
            ),
            body: TabBarView(
              children: panels.asMap().entries.map((entry) {
                final index = entry.key;
                final panel = entry.value;
                return PanelColumn(
                  key: ValueKey(panel.id),
                  panel: panel,
                  isKanban: false,
                  onUpdatePanel: (updated) =>
                      _onUpdatePanel(view, index, updated),
                  onDeletePanel: () => _onDeletePanel(view, index),
                  onTaskDropped: (task, targetPanel) => _handleTaskDrop(
                    view: view,
                    task: task,
                    targetPanel: targetPanel,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
