import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/custom_view_models.dart';
import '../../../core/utils/uuid.dart';
import '../../../shared/widgets/modal_side_sheet.dart';
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

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

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
          horizontal: 20,
          vertical: AppTokens.spaceSm,
        ),
        children: [
          // ── 1. 基本信息 ──
          _buildSectionHeader(
            icon: Icons.grid_view_outlined,
            title: l10n.basicInfo,
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
              borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
              border: Border.all(color: borderColor, width: 1.0),
              boxShadow: isDark
                  ? AppTokens.cardShadowDarkList
                  : AppTokens.cardShadowLight,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Color(_color).withValues(alpha: AppTokens.alphaBorderSubtle),
                          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                          border: Border.all(
                            color: Color(_color).withValues(alpha: AppTokens.alphaBorderEmphasis),
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          getCustomViewIcon(_icon),
                          color: Color(_color),
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.viewName,
                            style: TextStyle(
                              fontSize: AppTokens.textSectionLabelSize,
                              fontWeight: AppTokens.textSectionLabelWeight,
                              letterSpacing: AppTokens.textSectionLabelLetterSpacing,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: AppTokens.alphaScrim),
                            ),
                          ),
                          const SizedBox(height: 2),
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(
                              fontSize: AppTokens.textSubtitleSize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.viewNameHint,
                              isDense: true,
                              filled: false,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 6,
                              ),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: borderColor,
                                  width: 1,
                                ),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: borderColor,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final preset in const [
                      0xFF8B5CF6,
                      0xFF10B981,
                      0xFF4A6CF7,
                      0xFF06B6D4,
                      0xFFF59E0B,
                      0xFFEF4444,
                      0xFF64748B,
                    ])
                      InkWell(
                        onTap: () => setState(() => _color = preset),
                        customBorder: const CircleBorder(),
                        child: AnimatedContainer(
                          duration: AppTokens.motionFast,
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Color(preset),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == preset
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: _color == preset
                                ? [
                                    BoxShadow(
                                      color: Color(
                                        preset,
                                      ).withValues(alpha: AppTokens.alphaContentDisabled),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: _color == preset
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── 2. 布局模式 ──
          _buildSectionHeader(
            icon: Icons.splitscreen_outlined,
            title: l10n.viewLayout,
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
              borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
              border: Border.all(color: borderColor, width: 1.0),
              boxShadow: isDark
                  ? AppTokens.cardShadowDarkList
                  : AppTokens.cardShadowLight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.displayMode,
                  style: const TextStyle(
                    fontSize: AppTokens.textSecondarySize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          )
                        : AppTokens.surfaceSubtleLight,
                    borderRadius: BorderRadius.circular(AppTokens.radiusItem),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLayoutToggleItem(
                        mode: 'kanban',
                        label: l10n.layoutKanban,
                        icon: Icons.view_column_outlined,
                        isSelected: _layoutMode == 'kanban',
                      ),
                      const SizedBox(width: 2),
                      _buildLayoutToggleItem(
                        mode: 'list',
                        label: l10n.layoutList,
                        icon: Icons.view_agenda_outlined,
                        isSelected: _layoutMode == 'list',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 3. 快速模板 ──
          _buildSectionHeader(
            icon: Icons.auto_awesome_outlined,
            title: l10n.quickTemplates,
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _panels = createStatusKanbanPanels(
                        titleTodo: l10n.statusTodo,
                        titleInProgress: l10n.statusInProgress,
                        titleDone: l10n.statusDone,
                      );
                    });
                  },
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTokens.surfaceCardDark
                          : AppTokens.surfaceCard,
                      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.view_column_outlined,
                              size: 15,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.statusKanbanName,
                              style: const TextStyle(
                                fontSize: AppTokens.textFootnoteSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          l10n.statusKanbanDesc,
                          style: TextStyle(
                            fontSize: AppTokens.textMicroSize,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _panels = createPriorityKanbanPanels(
                        titleHigh: l10n.priorityHigh,
                        titleMedium: l10n.priorityMedium,
                        titleLow: l10n.priorityLow,
                        titleNone: l10n.priorityNone,
                      );
                    });
                  },
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTokens.surfaceCardDark
                          : AppTokens.surfaceCard,
                      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.flag_outlined,
                              size: 15,
                              color: AppTokens.colorPriorityHigh,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.priorityKanbanName,
                              style: const TextStyle(
                                fontSize: AppTokens.textFootnoteSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          l10n.priorityKanbanDesc,
                          style: TextStyle(
                            fontSize: AppTokens.textMicroSize,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── 4. 面板列表 ──
          _buildSectionHeader(
            icon: Icons.view_column_outlined,
            title: '${l10n.panelTitle} (${_panels.length})',
            trailing: InkWell(
              onTap: _addNewPanel,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        )
                      : AppTokens.surfaceSubtleLight,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      l10n.addPanel,
                      style: TextStyle(
                        fontSize: AppTokens.textFootnoteSize,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 连在一起的整体面板卡片
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
              borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
              border: Border.all(color: borderColor, width: 1.0),
              boxShadow: isDark
                  ? AppTokens.cardShadowDarkList
                  : AppTokens.cardShadowLight,
            ),
            clipBehavior: Clip.antiAlias,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
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
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: index < _panels.length - 1
                          ? BorderSide(color: borderColor, width: 1.0)
                          : BorderSide.none,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Center(
                              child: Icon(
                                Icons.drag_indicator,
                                size: 17,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: AppTokens.alphaBorderEmphasis),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              panel.title,
                              style: const TextStyle(
                                fontSize: AppTokens.textSecondarySize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildFilterSummary(panel.filter, l10n),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: IconButton(
                              tooltip: l10n.filterCriteria,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.tune,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () async {
                                final newCriteria =
                                    await showFilterCriteriaSheet(
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
                          ),
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: IconButton(
                              tooltip: l10n.editPanel,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => _editPanelTitle(index),
                            ),
                          ),
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: IconButton(
                              tooltip: l10n.deletePanel,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
                              onPressed: () {
                                setState(() {
                                  _panels.removeAt(index);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: AppTokens.textFootnoteSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  color: isDark ? Colors.white70 : AppTokens.surfaceSubtleDark,
                ),
              ),
            ],
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildLayoutToggleItem({
    required String mode,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _layoutMode = mode),
      child: AnimatedContainer(
        duration: AppTokens.motionFast,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? colorScheme.surfaceContainerHighest : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTokens.textFootnoteSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSummary(FilterCriteria filter, AppLocalizations l10n) {
    final chips = <String>[];
    if (filter.statuses.isNotEmpty) {
      chips.add(l10n.filterStatusCount(filter.statuses.length));
    }
    if (filter.priorities.isNotEmpty) {
      chips.add(l10n.filterPriorityCount(filter.priorities.length));
    }
    if (filter.projectIds.isNotEmpty) {
      chips.add(l10n.filterProjectCount(filter.projectIds.length));
    }
    if (filter.tagIds.isNotEmpty) {
      chips.add(l10n.filterTagCount(filter.tagIds.length));
    }
    if (filter.dateScope != DateScopeEnum.all) {
      chips.add(filter.dateScope.name);
    }
    if (filter.hierarchyScope != HierarchyScopeEnum.all) {
      chips.add(filter.hierarchyScope.name);
    }

    if (chips.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: AppTokens.alphaContentDisabled),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
        child: Text(
          l10n.allTasksLabel,
          style: TextStyle(
            fontSize: AppTokens.textNanoSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: chips.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: AppTokens.alphaBorderSubtle),
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          ),
          child: Text(
            c,
            style: TextStyle(
              fontSize: AppTokens.textNanoSize,
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
