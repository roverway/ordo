// 新建任务底部弹窗（滴答式，55-ui-redesign-proposal.md §4.1 D2 定稿）。
//
// 结构：
// - 顶部行：当前清单名 + 下拉箭头（「移动到」清单选择：搜索 + 列表 + 当前项对勾
//   + 「+ 添加项目」）；右侧优先级旗帜图标 + 三点菜单（描述/备注）。
// - 标题输入：18–20sp / w600，无边框，占位符任务标题，自动聚焦。
// - 选项行：[图标] 文字 …… 右侧值/箭头：
//   日期与提醒（今天/明天/下周/自定义/清除）、优先级（红/橙/蓝/无）、标签（药丸多选+新建）。
// - 子任务区（轻量）：圆形复选框 + 拖拽排序 + 新增行；仅 1 级任务（parentId 为空）展示。
// - 自动保存：关闭/失去焦点时保存；标题校验与编辑页一致（复用 taskFormProvider.save），
//   内容全空则直接关闭不落库。
//
// FAB 接线由协调方负责（本批不改 app_shell/router），只交付 `TaskCreateSheet.show(...)` API。
// 保存逻辑复用 task_providers 现有路径，禁止重复实现。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/todo_repository.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dates.dart';
import '../../projects/project_providers.dart';
import '../../projects/widgets/project_form_dialog.dart';
import '../../tags/tag_providers.dart';
import '../../tags/tags_page.dart' show showTagFormDialog;
import '../task_providers.dart';
import 'priority_picker.dart';

/// 新建任务底部弹窗。
class TaskCreateSheet extends ConsumerStatefulWidget {
  const TaskCreateSheet({
    super.key,
    this.projectId,
    this.parentId,
    this.initialStartAt,
    this.initialEndAt,
  });

  final String? projectId;
  final String? parentId;

  /// 预填开始/截止时间（UTC 毫秒，日历「点日期新建」传入）。
  final int? initialStartAt;
  final int? initialEndAt;

  /// 打开新建任务底部弹窗（滴答式，isScrollControlled + viewInsets 适配键盘）。
  ///
  /// - [projectId] 缺省时默认落入内置收件箱（产品决策 #3）；
  /// - [parentId] 非空 = 创建子任务（此时不展示子任务区，层级受 3 级上限约束）。
  static Future<void> show(
    BuildContext context, {
    String? projectId,
    String? parentId,
    int? initialStartAt,
    int? initialEndAt,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // 关闭走 PopScope 拦截 → 自动保存 → 手动 pop；拖拽下滑与拦截逻辑冲突，
      // 显式关闭（避免 canPop:false 时拖拽「滑下去又弹回」的割裂感）。
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusDialog),
        ),
      ),
      builder: (sheetContext) => Padding(
        // 键盘弹出时弹窗整体上移，内容区保持输入可见（55-ui-redesign §4.1）。
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: TaskCreateSheet(
          projectId: projectId,
          parentId: parentId,
          initialStartAt: initialStartAt,
          initialEndAt: initialEndAt,
        ),
      ),
    );
  }

  @override
  ConsumerState<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends ConsumerState<TaskCreateSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _notesController = TextEditingController();
  final List<TextEditingController> _subtaskControllers = [];
  bool _showDescription = false;
  bool _showNotes = false;
  bool _isSaving = false;
  bool _initialized = false;

  /// 自动保存完成后置 true，放行 PopScope 的 pop（canPop 由状态驱动）。
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    // 首帧后初始化表单（Riverpod 禁止在 initState 中写 provider，
    // 与 task_edit_page._loadData 的 addPostFrameCallback 模式一致）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _initForm());
  }

  /// 初始化表单：同步复位 + 解析项目（缺省收件箱，幂等 ensure，产品决策 #3）。
  ///
  /// 顺序修复（评审问题 2）：先在首帧后**同步** `resetForNew`（projectId 用
  /// widget 传入值或内置收件箱固定 id [inboxProjectId]，无需任何 await），
  /// 再在 inbox ensure future 解析完成后仅用 [setProjectAndParent] 校正项目
  /// 字段——该方法保留表单其余字段（标题/优先级/日期等），不会清空用户
  /// 已输入内容。避免「await 期间输入被 resetForNew 静默清空」的丢数据窗口。
  Future<void> _initForm() async {
    if (_initialized) return;
    _initialized = true;
    final notifier = ref.read(taskFormProvider.notifier);

    // 1. 同步复位（可立即输入）：缺省项目用收件箱固定 id，幂等语义不变。
    final initialProjectId = widget.projectId ?? inboxProjectId;
    notifier.resetForNew(initialProjectId, widget.parentId);
    if (widget.initialStartAt != null) {
      notifier.updateStartAt(widget.initialStartAt);
    }
    if (widget.initialEndAt != null) {
      notifier.updateEndAt(widget.initialEndAt);
    }

    // 2. 缺省项目时确保收件箱行存在（幂等），解析完成后仅校正项目字段。
    if (widget.projectId == null) {
      try {
        final inbox = await ref.read(inboxProjectProvider.future);
        notifier.setProjectAndParent(inbox.id, widget.parentId);
      } catch (_) {
        // ensure 失败极罕见（SQLite 本地库）：表单已按收件箱 id 初始化，
        // 保存时若行缺失会经 RepositoryException 走 SnackBar，不静默丢数据。
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _notesController.dispose();
    for (final c in _subtaskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formState = ref.watch(taskFormProvider);
    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final projectName = projects
        .where((p) => p.id == formState.projectId)
        .firstOrNull
        ?.name;

    return PopScope(
      // 拦截系统返回/遮罩点击 → 自动保存后关闭；校验失败则留在弹窗。
      // 保存成功后通过 _allowPop 放行（否则 Navigator.pop 会被自身拦截，弹窗无法关闭）。
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceMd,
          AppTokens.spaceSm,
          AppTokens.spaceMd,
          AppTokens.spaceLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context, l10n, formState, projectName),
            const SizedBox(height: AppTokens.spaceXs),
            _buildTitleField(context, l10n),
            const SizedBox(height: AppTokens.spaceXs),
            _buildOptionRows(context, l10n, formState),
            if (_showDescription || _showNotes) ...[
              const SizedBox(height: AppTokens.spaceSm),
              _buildDescriptionNotes(context, l10n),
            ],
            if (widget.parentId == null) ...[
              const SizedBox(height: AppTokens.spaceXs),
              _buildSubtasks(context, l10n),
            ],
          ],
        ),
      ),
    );
  }

  // ── 顶部行：清单名 + 优先级旗帜 + 三点菜单 ────────────────────────

  Widget _buildTopBar(
    BuildContext context,
    AppLocalizations l10n,
    TaskFormState formState,
    String? projectName,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // 清单名 + 下拉箭头（「移动到」清单选择）。
        InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          onTap: _pickProject,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppTokens.spaceXs,
              horizontal: AppTokens.spaceXxs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    projectName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTokens.textTitleWeight,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXxs),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        // 优先级旗帜（按当前值着色）。
        IconButton(
          tooltip: l10n.priority,
          icon: Icon(
            Icons.flag_outlined,
            size: 20,
            color: priorityColor(formState.priority),
          ),
          onPressed: _pickPriority,
        ),
        // 三点菜单：显示/隐藏描述与备注。
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          tooltip: l10n.rowActions,
          onSelected: (value) => setState(() {
            if (value == 'description') _showDescription = !_showDescription;
            if (value == 'notes') _showNotes = !_showNotes;
          }),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'description',
              child: Text(l10n.taskDescription),
            ),
            PopupMenuItem(value: 'notes', child: Text(l10n.taskNotes)),
          ],
        ),
      ],
    );
  }

  // ── 标题输入（无边框，自动聚焦）──────────────────────────────────

  Widget _buildTitleField(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return TextField(
      controller: _titleController,
      autofocus: true,
      // 规格：18–20sp / w600（titleLarge = textTitleSize 18 / textTitleWeight w600）。
      style: theme.textTheme.titleLarge,
      decoration: InputDecoration(
        hintText: l10n.taskTitle,
        border: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      textInputAction: TextInputAction.next,
      onChanged: (v) => ref.read(taskFormProvider.notifier).updateTitle(v),
    );
  }

  // ── 选项行：日期与提醒 / 优先级 / 标签 ────────────────────────────

  Widget _buildOptionRows(
    BuildContext context,
    AppLocalizations l10n,
    TaskFormState formState,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tags = ref.watch(tagsStreamProvider).value ?? const <Tag>[];
    final selectedNames = formState.selectedTagIds
        .map((id) => tags.where((t) => t.id == id).firstOrNull?.name)
        .whereType<String>()
        .toList();

    final dateText = formState.startAt != null || formState.endAt != null
        ? formatDateRange(formState.startAt, formState.endAt, l10n)
        : l10n.noDueDate;

    return Column(
      children: [
        _buildOptionRow(
          context: context,
          icon: Icons.calendar_today_outlined,
          label: l10n.dateAndReminder,
          trailing: Text(
            dateText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: _pickDueDate,
        ),
        const Divider(height: 1),
        _buildOptionRow(
          context: context,
          icon: Icons.flag_outlined,
          label: l10n.priority,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_outlined,
                size: 16,
                color: priorityColor(formState.priority),
              ),
              const SizedBox(width: AppTokens.spaceXxs),
              Text(
                priorityLabel(l10n, formState.priority),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          onTap: _pickPriority,
        ),
        const Divider(height: 1),
        _buildOptionRow(
          context: context,
          icon: Icons.label_outline,
          label: l10n.taskTags,
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              selectedNames.isEmpty ? l10n.noTags : selectedNames.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          onTap: _pickTags,
        ),
      ],
    );
  }

  Widget _buildOptionRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusList),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceSm),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
            trailing,
            const SizedBox(width: AppTokens.spaceXxs),
            Icon(Icons.chevron_right, size: 18, color: colorScheme.outline),
          ],
        ),
      ),
    );
  }

  // ── 描述/备注（三点菜单开关）─────────────────────────────────────

  Widget _buildDescriptionNotes(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        if (_showDescription)
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.taskDescription),
            onChanged: (v) =>
                ref.read(taskFormProvider.notifier).updateDescription(v),
          ),
        if (_showNotes) ...[
          const SizedBox(height: AppTokens.spaceSm),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.taskNotes),
            onChanged: (v) =>
                ref.read(taskFormProvider.notifier).updateNotes(v),
          ),
        ],
      ],
    );
  }

  // ── 子任务区（轻量：复选框 + 拖拽排序 + 新增行）──────────────────

  Widget _buildSubtasks(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.subtasks,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (_subtaskControllers.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _subtaskControllers.length,
            onReorder: _reorderSubtasks,
            itemBuilder: (context, index) {
              final controller = _subtaskControllers[index];
              return Row(
                key: ObjectKey(controller),
                children: [
                  // 圆形复选框（装饰：新建子任务默认未完成）。
                  const SizedBox(
                    width: AppTokens.touchTarget,
                    height: AppTokens.touchTarget,
                    child: Checkbox(value: false, onChanged: null),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: l10n.subtaskHint,
                        border: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _addSubtask(),
                    ),
                  ),
                  // 拖拽排序把手。
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(AppTokens.spaceXs),
                      child: Icon(Icons.drag_handle, size: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _removeSubtask(controller),
                  ),
                ],
              );
            },
          ),
        TextButton.icon(
          onPressed: _addSubtask,
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.addSubtask),
        ),
      ],
    );
  }

  void _addSubtask() {
    setState(() => _subtaskControllers.add(TextEditingController()));
  }

  void _removeSubtask(TextEditingController controller) {
    setState(() => _subtaskControllers.remove(controller));
    controller.dispose();
  }

  void _reorderSubtasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final controller = _subtaskControllers.removeAt(oldIndex);
      _subtaskControllers.insert(newIndex, controller);
    });
  }

  // ── 各选项的弹层交互 ─────────────────────────────────────────────

  /// 「移动到」清单选择：搜索 + 列表（当前项对勾）+ 添加项目。
  Future<void> _pickProject() async {
    final formState = ref.read(taskFormProvider);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusDialog),
        ),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _ProjectPickerSheet(currentProjectId: formState.projectId ?? ''),
      ),
    );
    if (result != null && mounted) {
      // 父任务不能跨项目：切换项目时清空 parentId（与编辑页一致）。
      ref.read(taskFormProvider.notifier).setProjectAndParent(result, null);
    }
  }

  /// 优先级选择（滴答式 红/橙/蓝/无）。
  Future<void> _pickPriority() async {
    final formState = ref.read(taskFormProvider);
    final picked = await showPriorityPicker(
      context,
      current: formState.priority,
    );
    if (picked != null && mounted) {
      ref.read(taskFormProvider.notifier).updatePriority(picked);
    }
  }

  /// 日期与提醒：今天/明天/下周/自定义/清除（仅写 endAt 截止时间）。
  Future<void> _pickDueDate() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<_DueDateChoice>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusDialog),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTokens.spaceXs),
            ListTile(
              title: Text(
                l10n.dateAndReminder,
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: AppTokens.textTitleWeight,
                ),
              ),
            ),
            const Divider(),
            for (final c in _DueDateChoice.values)
              ListTile(
                title: Text(_dueDateChoiceLabel(l10n, c)),
                onTap: () => Navigator.of(sheetContext).pop(c),
              ),
            const SizedBox(height: AppTokens.spaceXs),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case _DueDateChoice.clear:
        ref.read(taskFormProvider.notifier).updateEndAt(null);
      case _DueDateChoice.custom:
        await _pickCustomDateTime();
      case _DueDateChoice.today:
      case _DueDateChoice.tomorrow:
      case _DueDateChoice.nextWeek:
        final now = DateTime.now();
        final base = switch (choice) {
          _DueDateChoice.today => now,
          _DueDateChoice.tomorrow => now.add(const Duration(days: 1)),
          _DueDateChoice.nextWeek => _nextMonday(now),
          _ => now,
        };
        ref.read(taskFormProvider.notifier).updateEndAt(_dateOnlyMs(base));
    }
  }

  /// 自定义日期 + 时间（复用编辑页 showDatePicker + showTimePicker 逻辑）。
  Future<void> _pickCustomDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    ref
        .read(taskFormProvider.notifier)
        .updateEndAt(dt.toUtc().millisecondsSinceEpoch);
  }

  /// 标签：药丸多选 + 新建（弹层内会话选择，完成后整体写回表单）。
  Future<void> _pickTags() async {
    final formState = ref.read(taskFormProvider);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusDialog),
        ),
      ),
      builder: (sheetContext) =>
          _TagPickerSheet(initialSelected: formState.selectedTagIds),
    );
    if (result != null && mounted) {
      ref.read(taskFormProvider.notifier).setSelectedTags(result);
    }
  }

  // ── 自动保存 ─────────────────────────────────────────────────────

  /// 关闭时自动保存（复用 taskFormProvider.save）。
  ///
  /// - 内容全空（标题/描述/备注/时间/优先级/标签/子任务均无）→ 直接关闭不落库；
  /// - 有内容但标题为空 → SnackBar 提示（与编辑页校验一致），留在弹窗；
  /// - 保存成功后批量创建子任务，再关闭。
  Future<void> _saveAndClose() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context);
    // 首帧后初始化尚未完成时，先完成初始化再校验/保存（幂等）。
    await _initForm();
    if (!mounted) return;
    final notifier = ref.read(taskFormProvider.notifier);
    final formState = ref.read(taskFormProvider);

    final hasContent =
        formState.title.trim().isNotEmpty ||
        formState.description.isNotEmpty ||
        formState.notes.isNotEmpty ||
        formState.startAt != null ||
        formState.endAt != null ||
        formState.priority != TaskPriority.none ||
        formState.selectedTagIds.isNotEmpty ||
        _subtaskControllers.any((c) => c.text.trim().isNotEmpty);

    if (!hasContent) {
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.of(context).pop();
      }
      return;
    }
    if (formState.title.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.titleRequired)));
      return;
    }

    setState(() => _isSaving = true);
    final errorKey = await notifier.save();
    if (!mounted) return;
    if (errorKey != null) {
      final message = switch (errorKey) {
        'title_required' => l10n.titleRequired,
        'end_time_before_start' => l10n.endTimeBeforeStart,
        _ => errorKey,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _isSaving = false);
      return;
    }

    await _createSubtasks();
    if (mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  /// 保存成功后批量创建非空子任务（复用 repo.createTask，parentId 指向新任务）。
  Future<void> _createSubtasks() async {
    final repo = ref.read(todoRepositoryProvider);
    final formState = ref.read(taskFormProvider);
    final parentId = formState.id;
    if (parentId == null) return;
    try {
      for (final controller in _subtaskControllers) {
        final title = controller.text.trim();
        if (title.isEmpty) continue;
        await repo.createTask(
          projectId: formState.projectId,
          parentId: parentId,
          title: title,
        );
      }
    } on RepositoryException catch (e) {
      // 父任务已保存，子任务失败仅提示（与编辑页兜底行为一致）。
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  // ── 小工具 ───────────────────────────────────────────────────────

  /// 日期型时间的 09:00 约定（与日历「点日期新建」一致，UTC 毫秒）。
  int _dateOnlyMs(DateTime day) =>
      DateTime(day.year, day.month, day.day, 9).toUtc().millisecondsSinceEpoch;

  /// 下一个周一（今天为周一时取下周）。
  DateTime _nextMonday(DateTime today) {
    final days = (8 - today.weekday) % 7;
    return today.add(Duration(days: days == 0 ? 7 : days));
  }
}

/// 日期预设选项。
enum _DueDateChoice { today, tomorrow, nextWeek, custom, clear }

String _dueDateChoiceLabel(AppLocalizations l10n, _DueDateChoice choice) =>
    switch (choice) {
      _DueDateChoice.today => l10n.today,
      _DueDateChoice.tomorrow => l10n.tomorrow,
      _DueDateChoice.nextWeek => l10n.nextWeek,
      _DueDateChoice.custom => l10n.custom,
      _DueDateChoice.clear => l10n.clear,
    };

/// 「移动到」清单选择弹层：搜索框 + 清单列表（当前项对勾）+ 添加项目。
class _ProjectPickerSheet extends ConsumerStatefulWidget {
  const _ProjectPickerSheet({required this.currentProjectId});

  final String currentProjectId;

  @override
  ConsumerState<_ProjectPickerSheet> createState() =>
      _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends ConsumerState<_ProjectPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final filtered = projects
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // 「移动到」标题（ticktick-design-analysis §3.5）。
                Expanded(
                  child: Text(
                    l10n.moveTo,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTokens.textTitleWeight,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceMd),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Row(
              children: [
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l10n.searchProjects,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final project = filtered[index];
                  final isCurrent = project.id == widget.currentProjectId;
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(project.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isCurrent
                        ? const Icon(
                            Icons.check,
                            size: 20,
                            color: AppTokens.colorInProgress,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(project.id),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.add, size: 20),
              title: Text(l10n.addProject),
              onTap: _createProject,
            ),
            const SizedBox(height: AppTokens.spaceXs),
          ],
        ),
      ),
    );
  }

  /// 「+ 添加项目」：复用项目表单弹窗，创建后自动选中。
  Future<void> _createProject() async {
    final data = await showProjectFormDialog(context: context);
    if (data == null || !mounted) return;
    final repo = ref.read(todoRepositoryProvider);
    final project = await repo.createProject(
      name: data.name,
      color: data.color,
      description: data.description,
    );
    if (!mounted) return;
    Navigator.of(context).pop(project.id);
  }
}

/// 标签弹层：药丸多选 + 新建标签（完成后整体写回表单）。
class _TagPickerSheet extends ConsumerStatefulWidget {
  const _TagPickerSheet({required this.initialSelected});

  final List<String> initialSelected;

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  late final Set<String> _selected = {...widget.initialSelected};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tags = ref.watch(tagsStreamProvider).value ?? const <Tag>[];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    l10n.taskTags,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTokens.textTitleWeight,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_selected.toList()),
                  child: Text(l10n.done),
                ),
              ],
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                  vertical: AppTokens.spaceXs,
                ),
                child: Wrap(
                  spacing: AppTokens.spaceXs,
                  runSpacing: AppTokens.spaceXs,
                  children: tags.map((tag) {
                    final isSelected = _selected.contains(tag.id);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: isSelected,
                      onSelected: (_) => setState(() {
                        if (isSelected) {
                          _selected.remove(tag.id);
                        } else {
                          _selected.add(tag.id);
                        }
                      }),
                      avatar: isSelected
                          ? null
                          : Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Color(tag.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                      selectedColor: Color(tag.color).withValues(alpha: 0.15),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.add, size: 20),
              title: Text(l10n.newTag),
              onTap: _createTag,
            ),
            const SizedBox(height: AppTokens.spaceXs),
          ],
        ),
      ),
    );
  }

  /// 新建标签（复用 tags_page 的表单弹窗，重名预检走 ARB 文案）。
  Future<void> _createTag() async {
    final data = await showTagFormDialog(context: context);
    if (data == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(todoRepositoryProvider);
    final existing = await repo.tags.getByName(data.name);
    if (existing != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.tagNameDuplicate)));
      return;
    }
    try {
      final tag = await repo.createTag(name: data.name, color: data.color);
      if (!mounted) return;
      setState(() => _selected.add(tag.id));
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
