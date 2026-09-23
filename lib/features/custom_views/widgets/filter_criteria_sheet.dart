import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../core/utils/custom_view_models.dart';
import '../../../shared/widgets/settings_card.dart';
import '../../../shared/widgets/unified_hierarchical_folder_selector.dart';
import '../../projects/project_providers.dart';
import '../../tags/tag_providers.dart';
import '../../tasks/task_providers.dart';

/// 弹出筛选规则编辑弹窗 / 底部抽屉表单。
///
/// 完全遵照设计原型与 FILTER_DESIGN_SPEC.md 规范：
/// 1. 彻底移除顶部搜索框，释放空间，沉浸专注；
/// 2. 顶部 Header 包含「筛选规则」标题、动态选中计数徽标、右上角「重置筛选」与关闭按钮；
/// 3. 四象限与自定义视图完全统一的单圆角矩形层级容器 UnifiedHierarchicalFolderContainer；
/// 4. 底部吸底主胶囊大按钮（48dp 高度，24dp 圆角）；
/// 5. 完全对齐当前设置页面的 SettingsCard 圆角矩形风格与 AppTokens 设计系统。
Future<FilterCriteria?> showFilterCriteriaSheet({
  required BuildContext context,
  required FilterCriteria initialCriteria,
}) {
  if (AppBreakpoints.isWide(context)) {
    return showDialog<FilterCriteria>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
          child: _FilterCriteriaForm(
            initialCriteria: initialCriteria,
            isSheet: false,
            onClose: (result) => Navigator.of(dialogContext).pop(result),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<FilterCriteria>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).colorScheme.surface,
          borderRadius: AppTokens.sheetTopBorderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppTokens.alphaTintStrong),
              blurRadius: 36,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: _FilterCriteriaForm(
          initialCriteria: initialCriteria,
          scrollController: scrollController,
          isSheet: true,
          onClose: (result) => Navigator.of(sheetContext).pop(result),
        ),
      ),
    ),
  );
}

class _FilterCriteriaForm extends ConsumerStatefulWidget {
  const _FilterCriteriaForm({
    required this.initialCriteria,
    required this.onClose,
    this.scrollController,
    required this.isSheet,
  });

  final FilterCriteria initialCriteria;
  final ScrollController? scrollController;
  final bool isSheet;
  final ValueChanged<FilterCriteria?> onClose;

  @override
  ConsumerState<_FilterCriteriaForm> createState() =>
      _FilterCriteriaFormState();
}

class _FilterCriteriaFormState extends ConsumerState<_FilterCriteriaForm> {
  late List<String> _folderIds;
  late List<String> _projectIds;
  late List<String> _tagIds;
  late bool _tagMatchAll;
  late List<TaskPriority> _priorities;
  late List<TaskStatus> _statuses;
  late DateScopeEnum _dateScope;
  late HierarchyScopeEnum _hierarchyScope;

  @override
  void initState() {
    super.initState();
    _folderIds = List.from(widget.initialCriteria.folderIds);
    _projectIds = List.from(widget.initialCriteria.projectIds);
    _tagIds = List.from(widget.initialCriteria.tagIds);
    _tagMatchAll = widget.initialCriteria.tagMatchAll;
    _priorities = List.from(widget.initialCriteria.priorities);
    _statuses = List.from(widget.initialCriteria.statuses);
    _dateScope = widget.initialCriteria.dateScope;
    _hierarchyScope = widget.initialCriteria.hierarchyScope;
  }

  int get _activeFilterCount {
    var count = 0;
    count += _statuses.length;
    count += _priorities.length;
    if (_dateScope != DateScopeEnum.all) count++;
    if (_hierarchyScope != HierarchyScopeEnum.all) count++;
    count += _projectIds.length;
    count += _tagIds.length;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _folderIds.clear();
      _projectIds.clear();
      _tagIds.clear();
      _tagMatchAll = false;
      _priorities.clear();
      _statuses.clear();
      _dateScope = DateScopeEnum.all;
      _hierarchyScope = HierarchyScopeEnum.all;
    });
  }

  void _applyFilters() {
    final result = widget.initialCriteria.copyWith(
      folderIds: _folderIds,
      projectIds: _projectIds,
      tagIds: _tagIds,
      tagMatchAll: _tagMatchAll,
      priorities: _priorities,
      statuses: _statuses,
      dateScope: _dateScope,
      hierarchyScope: _hierarchyScope,
    );
    widget.onClose(result);
  }

  void _toggleGroupProjects(List<String> groupProjectIds, bool selectAll) {
    setState(() {
      if (selectAll) {
        for (final id in groupProjectIds) {
          if (!_projectIds.contains(id)) {
            _projectIds.add(id);
          }
        }
      } else {
        _projectIds.removeWhere(groupProjectIds.contains);
      }
    });
  }

  void _toggleSingleProject(String projectId) {
    setState(() {
      if (_projectIds.contains(projectId)) {
        _projectIds.remove(projectId);
      } else {
        _projectIds.add(projectId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final tagsAsync = ref.watch(tagsStreamProvider);
    final tags = tagsAsync.value ?? const <Tag>[];

    final groupingAsync = ref.watch(projectsByFolderProvider);
    final inboxProjectAsync = ref.watch(inboxProjectProvider);

    final dividerColor = isDark
        ? AppTokens.borderSubtleNeutralDark
        : AppTokens.slate100;

    final activeCount = _activeFilterCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部拖拽手柄 (仅 Sheet 模式)
        if (widget.isSheet)
          Center(
            child: Container(
              width: AppTokens.sheetGrabberWidth,
              height: AppTokens.sheetGrabberHeight,
              margin: const EdgeInsets.only(
                top: AppTokens.spaceSm,
                bottom: AppTokens.spaceXxs,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTokens.slate600
                    : AppTokens.slate300,
                borderRadius: BorderRadius.circular(
                  AppTokens.sheetGrabberRadius,
                ),
              ),
            ),
          ),

        // 1. 顶部 Header 栏：标题 + 动态计数徽标 + 重置筛选 + 关闭
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceLg,
            vertical: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.filterCriteria,
                    style: TextStyle(
                      fontSize: AppTokens.textTitleSize,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTokens.textPrimaryDark
                          : AppTokens.slate900,
                    ),
                  ),
                  if (activeCount > 0) ...[
                    const SizedBox(width: AppTokens.spaceXs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTokens.surfaceSubtleDark
                            : AppTokens.slate100,
                        borderRadius: BorderRadius.circular(AppTokens.radiusItem),
                      ),
                      child: Text(
                        '已选 $activeCount 项',
                        style: TextStyle(
                          fontSize: AppTokens.textMicroSize,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTokens.textPrimaryDark
                              : AppTokens.slate900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _resetFilters,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.resetFilter,
                      style: TextStyle(
                        fontSize: AppTokens.textFootnoteSize,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppTokens.textMutedDark
                            : AppTokens.slate500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => widget.onClose(null),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark
                          ? AppTokens.textMutedDark
                          : AppTokens.slate500,
                    ),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                  ),
                ],
              ),
            ],
          ),
        ),

        Divider(height: 1, thickness: 0.8, color: dividerColor),

        // 2. 可滚动的主体内容
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceLg,
              vertical: AppTokens.spaceMd,
            ),
            children: [
              // 卡片 1: 状态 (Status) 与 优先级 (Priority)
              SettingsCard(
                padding: const EdgeInsets.all(14),
                children: [
                  // 状态 Header
                  _buildSectionHeader(
                    icon: Icons.check_circle_outline,
                    title: l10n.filterByStatus,
                    isDark: isDark,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HierarchicalChip(
                        label: l10n.statusTodo,
                        isSelected: _statuses.contains(TaskStatus.todo),
                        onTap: () {
                          setState(() {
                            _statuses.contains(TaskStatus.todo)
                                ? _statuses.remove(TaskStatus.todo)
                                : _statuses.add(TaskStatus.todo);
                          });
                        },
                      ),
                      HierarchicalChip(
                        label: l10n.statusInProgress,
                        isSelected: _statuses.contains(TaskStatus.inProgress),
                        onTap: () {
                          setState(() {
                            _statuses.contains(TaskStatus.inProgress)
                                ? _statuses.remove(TaskStatus.inProgress)
                                : _statuses.add(TaskStatus.inProgress);
                          });
                        },
                      ),
                      HierarchicalChip(
                        label: l10n.statusDone,
                        isSelected: _statuses.contains(TaskStatus.done),
                        leadingDotColor: AppTokens.colorSuccess,
                        onTap: () {
                          setState(() {
                            _statuses.contains(TaskStatus.done)
                                ? _statuses.remove(TaskStatus.done)
                                : _statuses.add(TaskStatus.done);
                          });
                        },
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: 1,
                      thickness: 0.8,
                      color: isDark
                          ? AppTokens.borderSubtleNeutralDark
                          : AppTokens.slate200,
                    ),
                  ),

                  // 优先级 Header
                  _buildSectionHeader(
                    icon: Icons.flag_outlined,
                    title: l10n.filterByPriority,
                    isDark: isDark,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HierarchicalChip(
                        label: l10n.priorityHigh,
                        isSelected: _priorities.contains(TaskPriority.high),
                        leadingDotColor: AppTokens.colorPriorityHigh,
                        onTap: () {
                          setState(() {
                            _priorities.contains(TaskPriority.high)
                                ? _priorities.remove(TaskPriority.high)
                                : _priorities.add(TaskPriority.high);
                          });
                        },
                      ),
                      HierarchicalChip(
                        label: l10n.priorityMedium,
                        isSelected: _priorities.contains(TaskPriority.medium),
                        leadingDotColor: AppTokens.colorPriorityMedium,
                        onTap: () {
                          setState(() {
                            _priorities.contains(TaskPriority.medium)
                                ? _priorities.remove(TaskPriority.medium)
                                : _priorities.add(TaskPriority.medium);
                          });
                        },
                      ),
                      HierarchicalChip(
                        label: l10n.priorityLow,
                        isSelected: _priorities.contains(TaskPriority.low),
                        leadingDotColor: AppTokens.colorPriorityLow,
                        onTap: () {
                          setState(() {
                            _priorities.contains(TaskPriority.low)
                                ? _priorities.remove(TaskPriority.low)
                                : _priorities.add(TaskPriority.low);
                          });
                        },
                      ),
                      HierarchicalChip(
                        label: l10n.priorityNone,
                        isSelected: _priorities.contains(TaskPriority.none),
                        onTap: () {
                          setState(() {
                            _priorities.contains(TaskPriority.none)
                                ? _priorities.remove(TaskPriority.none)
                                : _priorities.add(TaskPriority.none);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 卡片 2: 日期范围 (Date Range) 与 任务层级 (Task Level)
              SettingsCard(
                padding: const EdgeInsets.all(14),
                children: [
                  _buildSectionHeader(
                    icon: Icons.calendar_month_outlined,
                    title: l10n.filterByDate,
                    isDark: isDark,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HierarchicalChip(
                        label: l10n.dateScopeAll,
                        isSelected: _dateScope == DateScopeEnum.all,
                        onTap: () =>
                            setState(() => _dateScope = DateScopeEnum.all),
                      ),
                      HierarchicalChip(
                        label: l10n.dateScopeToday,
                        isSelected: _dateScope == DateScopeEnum.today,
                        onTap: () =>
                            setState(() => _dateScope = DateScopeEnum.today),
                      ),
                      HierarchicalChip(
                        label: l10n.dateScopeTomorrow,
                        isSelected: _dateScope == DateScopeEnum.tomorrow,
                        onTap: () =>
                            setState(() => _dateScope = DateScopeEnum.tomorrow),
                      ),
                      HierarchicalChip(
                        label: l10n.dateScopeThisWeek,
                        isSelected: _dateScope == DateScopeEnum.thisWeek,
                        onTap: () =>
                            setState(() => _dateScope = DateScopeEnum.thisWeek),
                      ),
                      HierarchicalChip(
                        label: l10n.dateScopeOverdue,
                        isSelected: _dateScope == DateScopeEnum.overdue,
                        onTap: () =>
                            setState(() => _dateScope = DateScopeEnum.overdue),
                      ),
                      HierarchicalChip(
                        label: l10n.dateScopeNoDate,
                        isSelected: _dateScope == DateScopeEnum.noDate,
                        onTap: () =>
                            setState(() => _dateScope = DateScopeEnum.noDate),
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      height: 1,
                      thickness: 0.8,
                      color: isDark
                          ? AppTokens.borderSubtleNeutralDark
                          : AppTokens.slate200,
                    ),
                  ),

                  _buildSectionHeader(
                    icon: Icons.account_tree_outlined,
                    title: l10n.filterByHierarchy,
                    isDark: isDark,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HierarchicalChip(
                        label: l10n.hierarchyAll,
                        isSelected: _hierarchyScope == HierarchyScopeEnum.all,
                        onTap: () => setState(
                          () => _hierarchyScope = HierarchyScopeEnum.all,
                        ),
                      ),
                      HierarchicalChip(
                        label: l10n.hierarchyRootOnly,
                        isSelected:
                            _hierarchyScope == HierarchyScopeEnum.rootOnly,
                        onTap: () => setState(
                          () => _hierarchyScope = HierarchyScopeEnum.rootOnly,
                        ),
                      ),
                      HierarchicalChip(
                        label: l10n.hierarchySubtasksOnly,
                        isSelected:
                            _hierarchyScope == HierarchyScopeEnum.subtasksOnly,
                        onTap: () => setState(
                          () =>
                              _hierarchyScope = HierarchyScopeEnum.subtasksOnly,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 卡片 3: 清单与文件夹 (统一层级架构 UnifiedHierarchicalFolderContainer)
              groupingAsync.when(
                data: (grouping) {
                  final inbox = inboxProjectAsync.value;
                  final unassignedProjects = <Project>[
                    ?inbox,
                    ...grouping.ungrouped,
                  ];

                  if (unassignedProjects.isEmpty && grouping.folders.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 9),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_copy_outlined,
                              size: 15,
                              color: isDark
                                  ? AppTokens.textMutedDark
                                  : AppTokens.slate600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '清单与文件夹',
                              style: TextStyle(
                                fontSize: AppTokens.textFootnoteSize,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTokens.textPrimaryDark
                                    : AppTokens.slate700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      UnifiedHierarchicalFolderContainer(
                        unassignedProjects: unassignedProjects,
                        folders: grouping.folders,
                        folderProjects: grouping.folderProjects,
                        selectedProjectIds: _projectIds.toSet(),
                        onToggleProject: _toggleSingleProject,
                        onToggleGroup: _toggleGroupProjects,
                        unassignedTitle: '顶层与独立清单',
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              // 卡片 4: 标签 (Tags with OR/AND toggle)
              if (tags.isNotEmpty)
                SettingsCard(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_offer_outlined,
                              size: 15,
                              color: isDark
                                  ? AppTokens.textMutedDark
                                  : AppTokens.slate600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.filterByTag,
                              style: TextStyle(
                                fontSize: AppTokens.textFootnoteSize,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTokens.textPrimaryDark
                                    : AppTokens.slate700,
                              ),
                            ),
                          ],
                        ),

                        // OR / AND 切换器
                        InkWell(
                          onTap: () {
                            setState(() => _tagMatchAll = !_tagMatchAll);
                          },
                          borderRadius: BorderRadius.circular(AppTokens.radiusXs),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _tagMatchAll
                                      ? '匹配全部选中标签（AND）'
                                      : '匹配任一选中标签（OR）',
                                  style: TextStyle(
                                    fontSize: AppTokens.textMicroSize,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppTokens.textMutedDark
                                        : AppTokens.slate500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  height: 22,
                                  width: 36,
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: Switch.adaptive(
                                      value: _tagMatchAll,
                                      activeTrackColor: isDark
                                          ? colorScheme.primary
                                          : AppTokens.slate900,
                                      onChanged: (val) {
                                        setState(() => _tagMatchAll = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((t) {
                        final isSelected = _tagIds.contains(t.id);
                        return HierarchicalChip(
                          label: t.name,
                          isSelected: isSelected,
                          leadingDotColor: Color(t.color),
                          onTap: () {
                            setState(() {
                              isSelected
                                  ? _tagIds.remove(t.id)
                                  : _tagIds.add(t.id);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),

              const SizedBox(height: AppTokens.spaceMd),
            ],
          ),
        ),

        // 3. 底部吸底主胶囊大按钮 (Apply Filter Action)
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceLg,
            12,
            AppTokens.spaceLg,
            18,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTokens.surfaceCardDark : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppTokens.borderSubtleNeutralDark
                    : AppTokens.slate100,
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: AppTokens.alphaTintFaint),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? colorScheme.primary
                    : AppTokens.slate900,
                foregroundColor: isDark ? colorScheme.onPrimary : Colors.white,
                shape: RoundedCornerShape(24),
                elevation: 3,
                shadowColor: (isDark ? Colors.black : AppTokens.slate900)
                    .withValues(alpha: AppTokens.alphaBorderEmphasis),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.applyFilter,
                    style: const TextStyle(
                      fontSize: AppTokens.textBodySize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (activeCount > 0)
                    Text(
                      ' (已选 $activeCount 项)',
                      style: const TextStyle(
                        fontSize: AppTokens.textBodySize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isDark ? AppTokens.textMutedDark : AppTokens.slate600,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: AppTokens.textFootnoteSize,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppTokens.textPrimaryDark
                  : AppTokens.slate700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 兼容旧版辅助圆角组件。
class RoundedCornerShape extends RoundedRectangleBorder {
  RoundedCornerShape(double radius)
    : super(borderRadius: BorderRadius.circular(radius));
}
