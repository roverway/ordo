import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/custom_view_models.dart';
import '../../../core/utils/uuid.dart';
import '../../projects/widgets/project_color_picker_sheet.dart';
import '../providers/custom_view_providers.dart';
import '../widgets/filter_criteria_sheet.dart';
import '../widgets/icon_picker_dialog.dart';

/// 自定义视图新建与编辑页面。
class CustomViewEditorPage extends ConsumerStatefulWidget {
  const CustomViewEditorPage({super.key, this.viewId});

  /// 为空表示新建视图；非空表示编辑已有视图。
  final String? viewId;

  @override
  ConsumerState<CustomViewEditorPage> createState() =>
      _CustomViewEditorPageState();
}

class _CustomViewEditorPageState extends ConsumerState<CustomViewEditorPage> {
  late TextEditingController _nameController;
  String _icon = 'dashboard_outlined';
  int _color = 0xFF4A6CF7;
  String _layoutMode = 'kanban';
  List<CustomViewPanelConfig> _panels = [];
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initFromView(CustomView view) {
    if (_initialized) return;
    _nameController.text = view.name;
    _icon = view.icon;
    _color = view.color;
    _layoutMode = view.layoutMode;
    _panels = decodePanelsJson(view.panelsJson);
    _initialized = true;
  }

  void _initNewDefault(AppLocalizations l10n) {
    if (_initialized) return;
    _nameController.text = '';
    // 默认提供状态看板的三栏预设
    _panels = createStatusKanbanPanels(
      titleTodo: l10n.statusTodo,
      titleInProgress: l10n.statusInProgress,
      titleDone: l10n.statusDone,
    );
    _initialized = true;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final ops = ref.read(customViewOperationsProvider);

    try {
      if (widget.viewId != null) {
        await ops.updateView(
          widget.viewId!,
          name: name,
          icon: _icon,
          color: _color,
          layoutMode: _layoutMode,
          panels: _panels,
        );
      } else {
        final created = await ops.createView(
          name: name,
          icon: _icon,
          color: _color,
          layoutMode: _layoutMode,
          panels: _panels,
        );
        if (mounted) {
          context.pushReplacement('/custom_view/${created.id}');
          return;
        }
      }
      if (mounted) {
        context.pop();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (widget.viewId != null) {
      final viewAsync = ref.watch(customViewDetailProvider(widget.viewId!));
      final view = viewAsync.value;
      if (view != null) {
        _initFromView(view);
      }
    } else {
      _initNewDefault(l10n);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.viewId == null ? l10n.newCustomView : l10n.editCustomView,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppTokens.spaceSm),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          // ── 基本信息卡片 ──
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名称与图标/颜色
                  Row(
                    children: [
                      // 图标选择器
                      InkWell(
                        onTap: () async {
                          final selected = await showCustomViewIconPicker(
                            context,
                            currentIcon: _icon,
                            color: _color,
                          );
                          if (selected != null) {
                            setState(() => _icon = selected);
                          }
                        },
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusCard,
                        ),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(_color).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusCard,
                            ),
                          ),
                          child: Icon(
                            getCustomViewIcon(_icon),
                            color: Color(_color),
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.spaceSm),

                      // 颜色选择器圆点
                      InkWell(
                        onTap: () async {
                          final selectedColor = await showProjectColorPicker(
                            context: context,
                            current: Color(_color),
                          );
                          if (selectedColor != null) {
                            setState(() => _color = selectedColor.toARGB32());
                          }
                        },
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusChip,
                        ),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(_color),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.spaceSm),

                      // 视图名称输入框
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: l10n.viewName,
                            hintText: l10n.viewNameHint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusCard,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.spaceSm,
                              vertical: AppTokens.spaceSm,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.spaceMd),

                  // 布局模式
                  Row(
                    children: [
                      Text(
                        l10n.viewLayout,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'kanban',
                            label: Text(l10n.layoutKanban),
                            icon: const Icon(
                              Icons.view_kanban_outlined,
                              size: 18,
                            ),
                          ),
                          ButtonSegment(
                            value: 'list',
                            label: Text(l10n.layoutList),
                            icon: const Icon(
                              Icons.view_agenda_outlined,
                              size: 18,
                            ),
                          ),
                        ],
                        selected: {_layoutMode},
                        onSelectionChanged: (set) {
                          setState(() => _layoutMode = set.first);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),

          // ── 快速模板预设 ──
          Row(
            children: [
              Text(
                l10n.presetTemplates,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Wrap(
            spacing: AppTokens.spaceSm,
            children: [
              ActionChip(
                avatar: const Icon(Icons.auto_awesome, size: 16),
                label: Text(l10n.presetStatusKanban),
                onPressed: () {
                  setState(() {
                    _panels = createStatusKanbanPanels(
                      titleTodo: l10n.statusTodo,
                      titleInProgress: l10n.statusInProgress,
                      titleDone: l10n.statusDone,
                    );
                  });
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.flag_outlined, size: 16),
                label: Text(l10n.presetPriorityKanban),
                onPressed: () {
                  setState(() {
                    _panels = createPriorityKanbanPanels(
                      titleHigh: l10n.priorityHigh,
                      titleMedium: l10n.priorityMedium,
                      titleLow: l10n.priorityLow,
                      titleNone: l10n.priorityNone,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceMd),

          // ── 面板列表管理 ──
          Row(
            children: [
              Text(
                '${l10n.panelTitle} (${_panels.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: AppTokens.textHeadingWeight,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _addNewPanel,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addPanel),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),

          // 面板排序列表
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _panels.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _panels.removeAt(oldIndex);
                _panels.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final panel = _panels[index];
              return Card(
                key: ValueKey(panel.id),
                margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                ),
                child: ListTile(
                  leading: const Icon(Icons.drag_handle),
                  title: Text(
                    panel.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: _buildFilterSummary(panel.filter, l10n),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.filterCriteria,
                        icon: const Icon(Icons.tune),
                        onPressed: () async {
                          final newCriteria = await showFilterCriteriaSheet(
                            context: context,
                            initialCriteria: panel.filter,
                          );
                          if (newCriteria != null) {
                            setState(() {
                              _panels[index] = panel.copyWith(
                                filter: newCriteria,
                              );
                            });
                          }
                        },
                      ),
                      IconButton(
                        tooltip: l10n.editPanel,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editPanelTitle(index),
                      ),
                      IconButton(
                        tooltip: l10n.deletePanel,
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () {
                          setState(() {
                            _panels.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSummary(FilterCriteria filter, AppLocalizations l10n) {
    final chips = <String>[];
    if (filter.statuses.isNotEmpty) {
      chips.add('${filter.statuses.length} 个状态');
    }
    if (filter.priorities.isNotEmpty) {
      chips.add('${filter.priorities.length} 个优先级');
    }
    if (filter.projectIds.isNotEmpty) {
      chips.add('${filter.projectIds.length} 个项目');
    }
    if (filter.tagIds.isNotEmpty) {
      chips.add('${filter.tagIds.length} 个标签');
    }
    if (filter.dateScope != DateScopeEnum.all) {
      chips.add(filter.dateScope.name);
    }
    if (filter.hierarchyScope != HierarchyScopeEnum.all) {
      chips.add(filter.hierarchyScope.name);
    }

    if (chips.isEmpty) {
      return Text(
        '全部任务',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    return Text(
      chips.join(' · '),
      style: TextStyle(color: Theme.of(context).colorScheme.primary),
    );
  }

  void _addNewPanel() {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.addPanel),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.panelTitle,
            hintText: l10n.panelTitleHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                setState(() {
                  _panels.add(
                    CustomViewPanelConfig(
                      id: newUuid(),
                      title: title,
                      filter: const FilterCriteria(),
                    ),
                  );
                });
              }
              Navigator.of(dialogCtx).pop();
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _editPanelTitle(int index) {
    final l10n = AppLocalizations.of(context);
    final panel = _panels[index];
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
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                setState(() {
                  _panels[index] = panel.copyWith(title: title);
                });
              }
              Navigator.of(dialogCtx).pop();
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }
}
