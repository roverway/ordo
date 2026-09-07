import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/todo_repository.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../projects/project_providers.dart';
import '../../../tags/tag_providers.dart';
import '../../../tags/tags_page.dart' show showTagFormDialog;
import '../../task_providers.dart';

/// 标签选择底部弹层（药丸多选 + 新建标签，完成后整体写回表单）。
Future<void> showTaskTagPicker(BuildContext context, WidgetRef ref) async {
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
        TagPickerSheet(initialSelected: formState.selectedTagIds),
  );
  if (result != null && context.mounted) {
    ref.read(taskFormProvider.notifier).setSelectedTags(result);
  }
}

/// 标签快捷设置弹层（任务行左滑按钮入口）：与 [showTaskTagPicker] 同一弹层，
/// 但不走 `taskFormProvider`——每次勾选/取消立即全量写回 DB（即点即改）。
Future<void> showTaskTagQuickPicker(
  BuildContext context,
  WidgetRef ref, {
  required String taskId,
}) async {
  final repo = ref.read(todoRepositoryProvider);
  final currentIds = await repo.tags.tagIdsForTask(taskId);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) => TagPickerSheet(
      initialSelected: currentIds,
      onChanged: (ids) async {
        try {
          await repo.tags.setTaskTags(taskId, ids);
        } on RepositoryException catch (e) {
          if (!sheetContext.mounted) return;
          ScaffoldMessenger.of(
            sheetContext,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
    ),
  );
}

/// 标签弹层：药丸多选 + 新建标签（完成后整体写回表单）。
///
/// [onChanged] 非空时进入「即点即改」模式：每次勾选/取消（含新建标签自动
/// 选中）立即回调当前全量选中集，由调用方负责持久化。
class TagPickerSheet extends ConsumerStatefulWidget {
  const TagPickerSheet({
    super.key,
    required this.initialSelected,
    this.onChanged,
  });

  final List<String> initialSelected;

  /// 即点即改回调（快捷设置模式）；null = 表单模式（仅点「完成」写回）。
  final ValueChanged<List<String>>? onChanged;

  @override
  ConsumerState<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<TagPickerSheet> {
  late final Set<String> _selected = {...widget.initialSelected};

  void _toggle(String tagId) {
    setState(() {
      if (_selected.contains(tagId)) {
        _selected.remove(tagId);
      } else {
        _selected.add(tagId);
      }
    });
    widget.onChanged?.call(_selected.toList());
  }

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
                      onSelected: (_) => _toggle(tag.id),
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
      widget.onChanged?.call(_selected.toList());
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
