import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../core/utils/custom_view_models.dart';
import '../../projects/project_providers.dart';
import '../../tags/tag_providers.dart';

/// 弹出筛选规则编辑弹窗 / 底部表单。
Future<FilterCriteria?> showFilterCriteriaSheet({
  required BuildContext context,
  required FilterCriteria initialCriteria,
}) {
  if (AppBreakpoints.isWide(context)) {
    return showDialog<FilterCriteria>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
          child: _FilterCriteriaForm(
            initialCriteria: initialCriteria,
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
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => _FilterCriteriaForm(
        initialCriteria: initialCriteria,
        scrollController: scrollController,
        onClose: (result) => Navigator.of(sheetContext).pop(result),
      ),
    ),
  );
}

class _FilterCriteriaForm extends ConsumerStatefulWidget {
  const _FilterCriteriaForm({
    required this.initialCriteria,
    required this.onClose,
    this.scrollController,
  });

  final FilterCriteria initialCriteria;
  final ScrollController? scrollController;
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
  late TextEditingController _searchController;

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
    _searchController = TextEditingController(
      text: widget.initialCriteria.searchQuery ?? '',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  FilterCriteria _buildCriteria() {
    final search = _searchController.text.trim();
    return FilterCriteria(
      folderIds: _folderIds,
      projectIds: _projectIds,
      tagIds: _tagIds,
      tagMatchAll: _tagMatchAll,
      priorities: _priorities,
      statuses: _statuses,
      dateScope: _dateScope,
      hierarchyScope: _hierarchyScope,
      searchQuery: search.isEmpty ? null : search,
    );
  }

  void _reset() {
    setState(() {
      _folderIds = [];
      _projectIds = [];
      _tagIds = [];
      _tagMatchAll = false;
      _priorities = [];
      _statuses = [];
      _dateScope = DateScopeEnum.all;
      _hierarchyScope = HierarchyScopeEnum.all;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(projectsStreamProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);

    final projects = projectsAsync.value ?? const <Project>[];
    final folders = foldersAsync.value ?? const <Folder>[];
    final tags = tagsAsync.value ?? const <Tag>[];

    return Column(
      children: [
        // 头部导航条
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMd,
            vertical: AppTokens.spaceSm,
          ),
          child: Row(
            children: [
              Text(
                l10n.filterCriteria,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: AppTokens.textHeadingWeight,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: _reset, child: Text(l10n.resetFilter)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => widget.onClose(null),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 滚动表单体
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            children: [
              // 文本搜索
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceSm,
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.spaceMd),

              // 状态筛选
              _buildSectionHeader(l10n.filterByStatus),
              Wrap(
                spacing: AppTokens.spaceXs,
                children: [
                  _buildChoiceChip(
                    label: l10n.statusTodo,
                    selected: _statuses.contains(TaskStatus.todo),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _statuses.add(TaskStatus.todo)
                            : _statuses.remove(TaskStatus.todo);
                      });
                    },
                  ),
                  _buildChoiceChip(
                    label: l10n.statusInProgress,
                    selected: _statuses.contains(TaskStatus.inProgress),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _statuses.add(TaskStatus.inProgress)
                            : _statuses.remove(TaskStatus.inProgress);
                      });
                    },
                  ),
                  _buildChoiceChip(
                    label: l10n.statusDone,
                    selected: _statuses.contains(TaskStatus.done),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _statuses.add(TaskStatus.done)
                            : _statuses.remove(TaskStatus.done);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceMd),

              // 优先级筛选
              _buildSectionHeader(l10n.filterByPriority),
              Wrap(
                spacing: AppTokens.spaceXs,
                children: [
                  _buildChoiceChip(
                    label: l10n.priorityHigh,
                    color: AppTokens.colorPriorityHigh,
                    selected: _priorities.contains(TaskPriority.high),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _priorities.add(TaskPriority.high)
                            : _priorities.remove(TaskPriority.high);
                      });
                    },
                  ),
                  _buildChoiceChip(
                    label: l10n.priorityMedium,
                    color: AppTokens.colorPriorityMedium,
                    selected: _priorities.contains(TaskPriority.medium),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _priorities.add(TaskPriority.medium)
                            : _priorities.remove(TaskPriority.medium);
                      });
                    },
                  ),
                  _buildChoiceChip(
                    label: l10n.priorityLow,
                    color: AppTokens.colorPriorityLow,
                    selected: _priorities.contains(TaskPriority.low),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _priorities.add(TaskPriority.low)
                            : _priorities.remove(TaskPriority.low);
                      });
                    },
                  ),
                  _buildChoiceChip(
                    label: l10n.priorityNone,
                    selected: _priorities.contains(TaskPriority.none),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _priorities.add(TaskPriority.none)
                            : _priorities.remove(TaskPriority.none);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceMd),

              // 日期范围
              _buildSectionHeader(l10n.filterByDate),
              Wrap(
                spacing: AppTokens.spaceXs,
                runSpacing: AppTokens.spaceXs,
                children: [
                  _buildSingleChoiceChip(
                    label: l10n.dateScopeAll,
                    selected: _dateScope == DateScopeEnum.all,
                    onSelected: () =>
                        setState(() => _dateScope = DateScopeEnum.all),
                  ),
                  _buildSingleChoiceChip(
                    label: l10n.dateScopeToday,
                    selected: _dateScope == DateScopeEnum.today,
                    onSelected: () =>
                        setState(() => _dateScope = DateScopeEnum.today),
                  ),
                  _buildSingleChoiceChip(
                    label: l10n.dateScopeTomorrow,
                    selected: _dateScope == DateScopeEnum.tomorrow,
                    onSelected: () =>
                        setState(() => _dateScope = DateScopeEnum.tomorrow),
                  ),
                  _buildSingleChoiceChip(
                    label: l10n.dateScopeThisWeek,
                    selected: _dateScope == DateScopeEnum.thisWeek,
                    onSelected: () =>
                        setState(() => _dateScope = DateScopeEnum.thisWeek),
                  ),
                  _buildSingleChoiceChip(
                    label: l10n.dateScopeOverdue,
                    selected: _dateScope == DateScopeEnum.overdue,
                    onSelected: () =>
                        setState(() => _dateScope = DateScopeEnum.overdue),
                  ),
                  _buildSingleChoiceChip(
                    label: l10n.dateScopeNoDate,
                    selected: _dateScope == DateScopeEnum.noDate,
                    onSelected: () =>
                        setState(() => _dateScope = DateScopeEnum.noDate),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceMd),

              // 任务层级
              _buildSectionHeader(l10n.filterByHierarchy),
              Wrap(
                spacing: AppTokens.spaceXs,
                children: [
                  _buildSingleChoiceChip(
                    label: l10n.hierarchyAll,
                    selected: _hierarchyScope == HierarchyScopeEnum.all,
                    onSelected: () => setState(
                      () => _hierarchyScope = HierarchyScopeEnum.all,
                    ),
                  ),
                  _buildSingleChoiceChip(
                    label: l10n.hierarchyRootOnly,
                    selected: _hierarchyScope == HierarchyScopeEnum.rootOnly,
                    onSelected: () => setState(
                      () => _hierarchyScope = HierarchyScopeEnum.rootOnly,
                    ),
                  ),
                  _buildSingleChoiceChip(
                    label: l10n.hierarchySubtasksOnly,
                    selected:
                        _hierarchyScope == HierarchyScopeEnum.subtasksOnly,
                    onSelected: () => setState(
                      () => _hierarchyScope = HierarchyScopeEnum.subtasksOnly,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceMd),

              // 所属项目
              if (projects.isNotEmpty) ...[
                _buildSectionHeader(l10n.filterByProject),
                Wrap(
                  spacing: AppTokens.spaceXs,
                  runSpacing: AppTokens.spaceXs,
                  children: projects.map((p) {
                    final isSelected = _projectIds.contains(p.id);
                    return FilterChip(
                      label: Text(p.name),
                      avatar: CircleAvatar(
                        radius: 5,
                        backgroundColor: Color(p.color),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          selected
                              ? _projectIds.add(p.id)
                              : _projectIds.remove(p.id);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppTokens.spaceMd),
              ],

              // 标签筛选
              if (tags.isNotEmpty) ...[
                Row(
                  children: [
                    _buildSectionHeader(l10n.filterByTag),
                    const Spacer(),
                    Text(
                      _tagMatchAll ? l10n.tagMatchAll : l10n.tagMatchAny,
                      style: theme.textTheme.bodySmall,
                    ),
                    Switch(
                      value: _tagMatchAll,
                      onChanged: (val) => setState(() => _tagMatchAll = val),
                    ),
                  ],
                ),
                Wrap(
                  spacing: AppTokens.spaceXs,
                  runSpacing: AppTokens.spaceXs,
                  children: tags.map((t) {
                    final isSelected = _tagIds.contains(t.id);
                    return FilterChip(
                      label: Text(t.name),
                      avatar: CircleAvatar(
                        radius: 5,
                        backgroundColor: Color(t.color),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          selected ? _tagIds.add(t.id) : _tagIds.remove(t.id);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppTokens.spaceMd),
              ],

              // 文件夹筛选
              if (folders.isNotEmpty) ...[
                _buildSectionHeader(l10n.filterByFolder),
                Wrap(
                  spacing: AppTokens.spaceXs,
                  runSpacing: AppTokens.spaceXs,
                  children: [
                    FilterChip(
                      label: Text(l10n.ungrouped),
                      selected: _folderIds.contains('unassigned'),
                      onSelected: (selected) {
                        setState(() {
                          selected
                              ? _folderIds.add('unassigned')
                              : _folderIds.remove('unassigned');
                        });
                      },
                    ),
                    ...folders.map((f) {
                      final isSelected = _folderIds.contains(f.id);
                      return FilterChip(
                        label: Text(f.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            selected
                                ? _folderIds.add(f.id)
                                : _folderIds.remove(f.id);
                          });
                        },
                      );
                    }),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // 底部应用按钮
        Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => widget.onClose(_buildCriteria()),
              child: Text(l10n.applyFilter),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceXs),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    Color? color,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      avatar: color != null
          ? CircleAvatar(radius: 5, backgroundColor: color)
          : null,
      selected: selected,
      onSelected: onSelected,
    );
  }

  Widget _buildSingleChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
