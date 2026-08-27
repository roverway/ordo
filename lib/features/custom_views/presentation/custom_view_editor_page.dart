import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/custom_view_models.dart';
import '../../../core/utils/uuid.dart';
import '../../../shared/widgets/modal_side_sheet.dart';
import '../../projects/widgets/project_color_picker_sheet.dart';
import '../providers/custom_view_providers.dart';
import '../widgets/filter_criteria_sheet.dart';
import '../widgets/icon_picker_dialog.dart';

/// 宽屏（≥600dp）下以右侧浮动抽屉（Side Sheet）形式打开自定义视图编辑器。
Future<void> showCustomViewEditorSideSheet(
  BuildContext context, {
  String? viewId,
}) {
  return showModalSideSheet(
    context: context,
    width: AppTokens.sideSheetEditorWidth,
    child: CustomViewEditorPage(viewId: viewId),
  );
}

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
        if (mounted) {
          _navigateBackOrTo('/custom_view/${widget.viewId}');
        }
      } else {
        final created = await ops.createView(
          name: name,
          icon: _icon,
          color: _color,
          layoutMode: _layoutMode,
          panels: _panels,
        );
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          context.go('/custom_view/${created.id}');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _navigateBackOrTo(String fallbackPath) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    try {
      if (context.canPop()) {
        context.pop();
        return;
      }
    } catch (_) {}

    try {
      context.go(fallbackPath);
    } catch (_) {}
  }

  void _handleBack() {
    _navigateBackOrTo('/today');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.viewId != null) {
      ref.listen<AsyncValue<CustomView?>>(
        customViewDetailProvider(widget.viewId!),
        (prev, next) {
          final view = next.value;
          if (!_initialized && view != null) {
            setState(() => _initFromView(view));
          }
        },
      );
      final view = ref.watch(customViewDetailProvider(widget.viewId!)).value;
      if (!_initialized && view != null) {
        _initFromView(view);
      }
    } else if (!_initialized) {
      _initNewDefault(l10n);
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppTokens.surfacePageDark
          : AppTokens.surfacePageLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _handleBack,
        ),
        title: Text(
          widget.viewId == null ? l10n.newCustomView : l10n.editCustomView,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: AppTokens.textHeadingWeight,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppTokens.spaceSm),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.save),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
        children: [
          // ── 1. 基本信息 Hero 卡片 ──
          Container(
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
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名称、图标与颜色选择
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 图标选择徽章
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
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Color(_color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Color(_color).withValues(alpha: 0.3),
                            width: 1.2,
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
                      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Color(_color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.grey[800]! : Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(_color).withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
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
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: l10n.viewName,
                          hintText: l10n.viewNameHint,
                          filled: true,
                          fillColor: isDark
                              ? theme.colorScheme.surfaceContainerHigh
                              : theme.colorScheme.surfaceContainerLowest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusCard,
                            ),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusCard,
                            ),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.spaceSm,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceMd),

                // 布局模式切换
                Row(
                  children: [
                    Text(
                      l10n.viewLayout,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'kanban',
                          label: Text(l10n.layoutKanban),
                          icon: const Icon(Icons.view_kanban, size: 17),
                        ),
                        ButtonSegment(
                          value: 'list',
                          label: Text(l10n.layoutList),
                          icon: const Icon(Icons.view_agenda, size: 17),
                        ),
                      ],
                      selected: {_layoutMode},
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusChip,
                            ),
                          ),
                        ),
                      ),
                      onSelectionChanged: (set) {
                        setState(() => _layoutMode = set.first);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),

          // ── 2. 快速模板预设 ──
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 17,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.presetTemplates,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppTokens.textHeadingWeight,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Wrap(
            spacing: AppTokens.spaceSm,
            children: [
              ActionChip(
                avatar: Icon(
                  Icons.view_column,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                label: Text(l10n.presetStatusKanban),
                backgroundColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.25,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                ),
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
                avatar: const Icon(
                  Icons.flag,
                  size: 15,
                  color: AppTokens.colorPriorityHigh,
                ),
                label: Text(l10n.presetPriorityKanban),
                backgroundColor: AppTokens.colorPriorityHigh.withValues(
                  alpha: 0.1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                ),
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
          const SizedBox(height: AppTokens.spaceLg),

          // ── 3. 面板列表管理 ──
          Row(
            children: [
              Text(
                '${l10n.panelTitle} (${_panels.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppTokens.textHeadingWeight,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _addNewPanel,
                icon: const Icon(Icons.add, size: 17),
                label: Text(l10n.addPanel),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                  ),
                ),
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
              return Container(
                key: ValueKey(panel.id),
                margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTokens.surfaceCardDark
                      : AppTokens.surfaceCard,
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceSm,
                    vertical: 4,
                  ),
                  leading: Icon(
                    Icons.drag_indicator,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  title: Text(
                    panel.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _buildFilterSummary(panel.filter, l10n),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.filterCriteria,
                        icon: Icon(
                          Icons.tune,
                          size: 19,
                          color: theme.colorScheme.primary,
                        ),
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
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editPanelTitle(index),
                      ),
                      IconButton(
                        tooltip: l10n.deletePanel,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
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
          const SizedBox(height: AppTokens.spaceLg),
        ],
      ),
    );
  }

  Widget _buildFilterSummary(FilterCriteria filter, AppLocalizations l10n) {
    final chips = <String>[];
    if (filter.statuses.isNotEmpty) {
      chips.add('${filter.statuses.length} 状态');
    }
    if (filter.priorities.isNotEmpty) {
      chips.add('${filter.priorities.length} 优先级');
    }
    if (filter.projectIds.isNotEmpty) {
      chips.add('${filter.projectIds.length} 项目');
    }
    if (filter.tagIds.isNotEmpty) {
      chips.add('${filter.tagIds.length} 标签');
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
        style: TextStyle(
          fontSize: AppTokens.textCaptionSize,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: chips.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          ),
          child: Text(
            c,
            style: TextStyle(
              fontSize: AppTokens.textMicroSize,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      }).toList(),
    );
  }

  void _addNewPanel() {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        ),
        title: Text(l10n.addPanel),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.panelTitle,
            hintText: l10n.panelTitleHint,
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
