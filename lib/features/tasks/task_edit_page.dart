import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../projects/project_providers.dart';
import 'task_providers.dart';

/// Task edit page — card-based layout, TickTick/Microsoft To Do inspired.
///
/// Sections: Title, description, notes, dates, status, tags, project.
/// Project selector is now interactive (was read-only). Status is disabled
/// when the task has children (derived).
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
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

      final repo = ref.read(todoRepositoryProvider);
      final children = await repo.tasks.getDirectChildren(
        loadedState.projectId!,
        widget.taskId,
      );
      if (mounted) setState(() => _hasChildren = children.isNotEmpty);
    } else {
      if (widget.projectId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.projectRequired)));
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
    final colorScheme = theme.colorScheme;
    final formState = ref.watch(taskFormProvider);
    final isEditing = widget.taskId != null;

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
            confirmColor: colorScheme.error,
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
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.save),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──
              _SectionCard(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: l10n.taskTitleHint,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (v) =>
                        ref.read(taskFormProvider.notifier).updateTitle(v),
                    autofocus: true,
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceSm),

              // ── Project selector ──
              _SectionCard(
                children: [_buildProjectPicker(context, l10n, formState)],
              ),
              const SizedBox(height: AppTokens.spaceSm),

              // ── Description + Notes ──
              _SectionCard(
                children: [
                  TextFormField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: l10n.taskDescription,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    maxLines: 3,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    onChanged: (v) => ref
                        .read(taskFormProvider.notifier)
                        .updateDescription(v),
                  ),
                  const Divider(),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: l10n.taskNotes,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    maxLines: 2,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onChanged: (v) =>
                        ref.read(taskFormProvider.notifier).updateNotes(v),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceSm),

              // ── Dates ──
              _SectionCard(
                children: [
                  _buildDateRow(
                    context,
                    l10n,
                    formState.startAt,
                    l10n.taskStartTime,
                    Icons.play_arrow_outlined,
                    isStart: true,
                  ),
                  const Divider(indent: 0),
                  _buildDateRow(
                    context,
                    l10n,
                    formState.endAt,
                    l10n.taskEndTime,
                    Icons.flag_outlined,
                    isStart: false,
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceSm),

              // ── Status ──
              _SectionCard(
                children: [_buildStatusSection(context, l10n, formState)],
              ),
              const SizedBox(height: AppTokens.spaceSm),

              // ── Tags ──
              _SectionCard(
                children: [_buildTagSection(context, l10n, formState)],
              ),
              const SizedBox(height: AppTokens.spaceSm),

              // ── Parent (read-only, if exists) ──
              if (formState.parentId != null)
                _SectionCard(
                  children: [
                    _buildInfoRow(
                      context,
                      l10n.taskParent,
                      formState.parentId!,
                    ),
                  ],
                ),
              const SizedBox(height: AppTokens.spaceXxxl),
            ],
          ),
        ),
      ),
    );
  }

  // ── Project picker ──

  Widget _buildProjectPicker(
    BuildContext context,
    AppLocalizations l10n,
    TaskFormState formState,
  ) {
    final projectsAsync = ref.watch(projectsStreamProvider);

    return projectsAsync.when(
      data: (projects) {
        return DropdownButtonFormField<String>(
          initialValue: formState.projectId,
          decoration: InputDecoration(
            labelText: l10n.taskProject,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          isExpanded: true,
          hint: Text(l10n.selectProject),
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          items: [
            for (final p in projects)
              DropdownMenuItem(
                value: p.id,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(p.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    Text(p.name),
                  ],
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              // 父任务不能跨项目：主动切换项目时清空 parentId，
              // 否则保存时父任务校验会失败（父任务仍属于旧项目）。
              ref
                  .read(taskFormProvider.notifier)
                  .setProjectAndParent(value, null);
            }
          },
        );
      },
      loading: () => const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Text(e.toString()),
    );
  }

  // ── Date row ──

  Widget _buildDateRow(
    BuildContext context,
    AppLocalizations l10n,
    int? value,
    String label,
    IconData icon, {
    required bool isStart,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasValue = value != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        size: 20,
        color: hasValue ? colorScheme.primary : colorScheme.outline,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        hasValue ? formatDateTime(value) : l10n.noDueDate,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: hasValue ? colorScheme.onSurface : colorScheme.outline,
        ),
      ),
      trailing: IconButton(
        icon: Icon(hasValue ? Icons.close : Icons.edit_calendar, size: 20),
        onPressed: hasValue
            ? () {
                if (isStart) {
                  ref.read(taskFormProvider.notifier).updateStartAt(null);
                } else {
                  ref.read(taskFormProvider.notifier).updateEndAt(null);
                }
              }
            : null,
      ),
      onTap: () => _pickDateTime(context, isStart: isStart),
    );
  }

  // ── Status chips ──

  Widget _buildStatusSection(
    BuildContext context,
    AppLocalizations l10n,
    TaskFormState formState,
  ) {
    final isDisabled = _hasChildren;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.spaceXs),
          child: Text(
            l10n.taskStatus,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
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
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
        ),
        if (isDisabled)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.spaceXs),
            child: Text(
              l10n.statusDerivedFromChildren,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  // ── Tags ──

  Widget _buildTagSection(
    BuildContext context,
    AppLocalizations l10n,
    TaskFormState formState,
  ) {
    final tagsAsync = ref.watch(tagsStreamProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.spaceXs),
          child: Text(
            l10n.taskTags,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        tagsAsync.when(
          data: (tags) {
            if (tags.isEmpty) {
              return Text(
                l10n.noTags,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
            );
          },
          loading: () => const SizedBox(
            height: 32,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Text(e.toString()),
        ),
      ],
    );
  }

  // ── Info row ──

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppTokens.spaceSm),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Helpers ──

  String _statusLabel(AppLocalizations l10n, TaskStatus status) =>
      switch (status) {
        TaskStatus.todo => l10n.statusTodo,
        TaskStatus.inProgress => l10n.statusInProgress,
        TaskStatus.done => l10n.statusDone,
        TaskStatus.cancelled => l10n.statusCancelled,
      };

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

    if (mounted) context.pop();
  }
}

/// Tags stream provider (needed by task edit page).
final tagsStreamProvider = StreamProvider<List<Tag>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.tags.watchAll();
});

/// Section card wrapper.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
