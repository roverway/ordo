import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../projects/project_providers.dart';
import 'task_providers.dart';

/// 任务编辑页（50-ui-ux.md §5.6）。
///
/// 字段：标题（必填）、描述、备注、开始时间、截止时间、状态、标签多选。
/// 有子任务时状态控件禁用。
class TaskEditPage extends ConsumerStatefulWidget {
  const TaskEditPage({super.key, this.taskId, this.projectId, this.parentId});

  final String? taskId;
  final String? projectId;
  final String? parentId;

  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _notesController;
  bool _hasChildren = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _notesController = TextEditingController();

    // 延迟加载，等 Provider 初始化完成。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (_initialized) return;
    _initialized = true;

    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(taskFormProvider.notifier);

    if (widget.taskId != null) {
      await notifier.loadTask(widget.taskId!);
      final loadedState = ref.read(taskFormProvider);
      _titleController.text = loadedState.title;
      _descController.text = loadedState.description;
      _notesController.text = loadedState.notes;

      // 检查是否有子任务。
      final repo = ref.read(todoRepositoryProvider);
      final children = await repo.tasks.getDirectChildren(
        loadedState.projectId!,
        widget.taskId,
      );
      if (mounted) {
        setState(() => _hasChildren = children.isNotEmpty);
      }
    } else {
      // 新建模式：重置表单（防止复用上一个任务的陈旧状态，审查发现 Bug 2），
      // 再设置 projectId 和 parentId。
      if (widget.projectId == null) {
        // 深链兜底：/task/new 缺 projectId 时退回项目列表（审查发现 Bug 7）。
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.projectRequired)),
          );
          context.go('/projects');
        }
        return;
      }
      notifier.resetForNew(widget.projectId!, widget.parentId);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final formState = ref.watch(taskFormProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);
    final isEditing = widget.taskId != null;

    // PopScope 处理未保存返回提示（50-ui-ux.md §8）。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final notifier = ref.read(taskFormProvider.notifier);
        if (notifier.hasChanges) {
          final discard = await showConfirmDialog(
            context: context,
            title: l10n.unsavedChanges,
            message: l10n.unsavedChangesConfirm,
            confirmLabel: l10n.discard,
            confirmColor: theme.colorScheme.error,
          );
          if (discard && context.mounted) {
            ref.read(taskFormProvider.notifier).reset();
            context.pop();
          }
        } else {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? l10n.edit : l10n.newTask),
          actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题（必填）。
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '${l10n.taskTitle} *',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    ref.read(taskFormProvider.notifier).updateTitle(v),
                autofocus: true,
              ),
              const SizedBox(height: AppTokens.spaceMd),

              // 描述。
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: l10n.taskDescription,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (v) =>
                    ref.read(taskFormProvider.notifier).updateDescription(v),
              ),
              const SizedBox(height: AppTokens.spaceMd),

              // 备注。
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: l10n.taskNotes,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (v) =>
                    ref.read(taskFormProvider.notifier).updateNotes(v),
              ),
              const SizedBox(height: AppTokens.spaceLg),

              // 时间选择。
              _buildTimeSection(context, l10n, formState),
              const SizedBox(height: AppTokens.spaceLg),

              // 状态选择。
              _buildStatusSection(context, l10n, formState),
              const SizedBox(height: AppTokens.spaceLg),

              // 标签多选。
              _buildTagSection(context, l10n, formState, tagsAsync),
              const SizedBox(height: AppTokens.spaceLg),

              // 所属项目（只读）。
              if (formState.projectId != null)
                _buildInfoRow(
                  context,
                  l10n.taskProject,
                  _getProjectName(ref, formState.projectId!),
                ),

              // 父任务（只读）。
              if (formState.parentId != null)
                _buildInfoRow(context, l10n.taskParent, formState.parentId!),

              const SizedBox(height: AppTokens.spaceXxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSection(
    BuildContext context,
    AppLocalizations l10n,
    TaskFormState formState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.taskStartTime, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppTokens.spaceXs),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDateTime(context, isStart: true),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  formState.startAt != null
                      ? _formatDateTime(formState.startAt!)
                      : l10n.startDate,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDateTime(context, isStart: false),
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(
                  formState.endAt != null
                      ? _formatDateTime(formState.endAt!)
                      : l10n.taskEndTime,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    AppLocalizations l10n,
    TaskFormState formState,
  ) {
    final isDisabled = _hasChildren;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.taskStatus, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppTokens.spaceXs),
        AbsorbPointer(
          absorbing: isDisabled,
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: Wrap(
              spacing: AppTokens.spaceXs,
              runSpacing: AppTokens.spaceXs,
              children: TaskStatus.values.map((status) {
                final isSelected = formState.status == status;
                return ChoiceChip(
                  label: Text(_statusLabel(l10n, status)),
                  selected: isSelected,
                  onSelected: isDisabled
                      ? null
                      : (_) => ref
                            .read(taskFormProvider.notifier)
                            .updateStatus(status),
                );
              }).toList(),
            ),
          ),
        ),
        if (isDisabled)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.spaceXxs),
            child: Text(
              l10n.statusDerivedFromChildren,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTagSection(
    BuildContext context,
    AppLocalizations l10n,
    TaskFormState formState,
    AsyncValue<List<Tag>> tagsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.taskTags, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppTokens.spaceXs),
        tagsAsync.when(
          data: (tags) {
            if (tags.isEmpty) {
              return Text(
                l10n.noTags,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Wrap(
              spacing: AppTokens.spaceXs,
              runSpacing: AppTokens.spaceXs,
              children: tags.map((tag) {
                final isSelected = formState.selectedTagIds.contains(tag.id);
                return FilterChip(
                  label: Text(tag.name),
                  selected: isSelected,
                  onSelected: (_) =>
                      ref.read(taskFormProvider.notifier).toggleTag(tag.id),
                  avatar: isSelected
                      ? null
                      : Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(tag.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                  selectedColor: Color(tag.color).withValues(alpha: 0.2),
                );
              }).toList(),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text(e.toString()),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppTokens.spaceSm),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, TaskStatus status) =>
      switch (status) {
        TaskStatus.todo => l10n.statusTodo,
        TaskStatus.inProgress => l10n.statusInProgress,
        TaskStatus.done => l10n.statusDone,
        TaskStatus.cancelled => l10n.statusCancelled,
      };

  String _formatDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getProjectName(WidgetRef ref, String projectId) {
    final projectsAsync = ref.read(projectsStreamProvider);
    return projectsAsync.when(
      data: (projects) {
        final p = projects.where((p) => p.id == projectId).firstOrNull;
        return p?.name ?? '';
      },
      loading: () => '',
      error: (_, _) => '',
    );
  }

  Future<void> _pickDateTime(
    BuildContext context, {
    required bool isStart,
  }) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final ms = dt.toUtc().millisecondsSinceEpoch;

    if (isStart) {
      ref.read(taskFormProvider.notifier).updateStartAt(ms);
    } else {
      ref.read(taskFormProvider.notifier).updateEndAt(ms);
    }
  }

  Future<void> _save() async {
    final notifier = ref.read(taskFormProvider.notifier);
    final errorKey = await notifier.save();

    if (!mounted) return;

    if (errorKey != null) {
      final l10n = AppLocalizations.of(context);
      final message = switch (errorKey) {
        'title_required' => l10n.titleRequired,
        'end_time_before_start' => l10n.endTimeBeforeStart,
        _ => errorKey,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (mounted) {
      context.pop();
    }
  }
}

/// 标签列表 StreamProvider（供任务编辑页使用）。
final tagsStreamProvider = StreamProvider<List<Tag>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.tags.watchAll();
});
