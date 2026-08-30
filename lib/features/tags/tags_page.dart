import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/todo_repository.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import '../../shared/widgets/adaptive_leading_navigation.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/staggered_fade_slide.dart';
import '../projects/project_providers.dart';
import 'tag_providers.dart';

/// 标签列表页（FR-TAG-01 / FR-VIEW-04）。
///
/// 列表按名称（不区分大小写）排序；行 = 颜色圆点 + 名称，点击进入标签详情；
/// 行尾菜单提供「编辑 / 删除」（bottom sheet 风格，参照 task_row）；
/// FAB 新建标签，空态展示 [EmptyState]。
class TagsPage extends ConsumerWidget {
  const TagsPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canPop = context.canPop() || onBack != null;
    final narrow = AppBreakpoints.isNarrow(context);
    final tagsAsync = ref.watch(tagsStreamProvider);

    return Scaffold(
      drawer: (narrow && !canPop) ? const AppDrawer() : null,
      appBar: AppBar(
        leading: AdaptiveLeadingNavigation(onBack: onBack),
        automaticallyImplyLeading: false,
        title: Text(l10n.navTags),
        actions: [
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search, size: 22),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return EmptyState(
              icon: Icons.label_outline,
              accentColor: AppTokens.colorNavTags,
              message: l10n.emptyTags,
              action: FilledButton.icon(
                onPressed: () => _showNewTagDialog(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l10n.newTag),
              ),
            );
          }
          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                  vertical: AppTokens.spaceSm,
                ),
                itemCount: tags.length,
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  // B 批：逐项错落入场（仅首次 build；长列表超出上限自动平铺）。
                  return StaggeredFadeSlide(
                    index: index,
                    child: _TagListTile(
                      tag: tag,
                      onTap: () => context.push('/tags/${tag.id}'),
                      onMenuEdit: () => _showEditTagDialog(context, ref, tag),
                      onMenuDelete: () =>
                          _showDeleteTagDialog(context, ref, tag),
                    ),
                  );
                },
              ),
              Positioned(
                right: AppTokens.spaceMd,
                bottom: AppTokens.spaceMd,
                child: FloatingActionButton(
                  onPressed: () => _showNewTagDialog(context, ref),
                  tooltip: l10n.newTag,
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (e, st) {
          logAsyncError(e, st);
          return ErrorView(onRetry: () => ref.invalidate(tagsStreamProvider));
        },
      ),
    );
  }

  Future<void> _showNewTagDialog(BuildContext context, WidgetRef ref) async {
    final data = await showTagFormDialog(context: context);
    if (data == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(todoRepositoryProvider);
    // 重名预检（FR-TAG-01：不区分大小写唯一），走 ARB 文案（AGENTS.md §3-8），
    // 不直接展示 Repository 的硬编码中文异常。
    final existing = await repo.tags.getByName(data.name);
    if (existing != null) {
      if (!context.mounted) return;
      _showError(context, l10n.tagNameDuplicate);
      return;
    }
    try {
      await repo.createTag(name: data.name, color: data.color);
    } on RepositoryException catch (e) {
      if (!context.mounted) return;
      // 兜底（UI 已硬限制长度，正常不可达）。
      _showError(context, e.message);
    }
  }

  Future<void> _showEditTagDialog(
    BuildContext context,
    WidgetRef ref,
    Tag tag,
  ) async {
    final data = await showTagFormDialog(
      context: context,
      initialName: tag.name,
      initialColor: tag.color,
    );
    if (data == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(todoRepositoryProvider);
    // 重名预检（排除自身）。
    final existing = await repo.tags.getByName(data.name);
    if (existing != null && existing.id != tag.id) {
      if (!context.mounted) return;
      _showError(context, l10n.tagNameDuplicate);
      return;
    }
    try {
      await repo.updateTag(tag.id, name: data.name, color: data.color);
    } on RepositoryException catch (e) {
      if (!context.mounted) return;
      _showError(context, e.message);
    }
  }

  Future<void> _showDeleteTagDialog(
    BuildContext context,
    WidgetRef ref,
    Tag tag,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteTag,
      message: '${l10n.deleteTagConfirm(tag.name)}\n${l10n.deleteTagWarning}',
      confirmLabel: l10n.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirmed && context.mounted) {
      await ref.read(todoRepositoryProvider).deleteTag(tag.id);
    }
  }

  /// 以 SnackBar 展示错误文案（调用方传入已本地化的消息）。
  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 标签表单返回数据。
class TagFormData {
  TagFormData({required this.name, required this.color});

  final String name;
  final int color;
}

/// 新建/编辑标签对话框（样式参照 project_form_dialog.dart）。
///
/// 名称校验：非空（`titleRequired` 通用 key）+ 长度上限 30（`maxLength` 硬限制）。
Future<TagFormData?> showTagFormDialog({
  required BuildContext context,
  String? initialName,
  int? initialColor,
}) {
  return showDialog<TagFormData>(
    context: context,
    builder: (context) =>
        _TagFormDialog(initialName: initialName, initialColor: initialColor),
  );
}

class _TagFormDialog extends ConsumerStatefulWidget {
  const _TagFormDialog({this.initialName, this.initialColor});

  final String? initialName;
  final int? initialColor;

  @override
  ConsumerState<_TagFormDialog> createState() => _TagFormDialogState();
}

class _TagFormDialogState extends ConsumerState<_TagFormDialog> {
  late final TextEditingController _nameController;
  late Color _selectedColor;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedColor = Color(
      widget.initialColor ?? AppTokens.presetColors.first.toARGB32(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(
        TagFormData(
          name: _nameController.text.trim(),
          color: _selectedColor.toARGB32(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.initialName != null;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        isEditing ? l10n.editTag : l10n.newTag,
        style: theme.textTheme.titleLarge,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标签名称。
            TextFormField(
              controller: _nameController,
              autofocus: true,
              maxLength: 30, // FR-TAG-01：名称长度 1–30（UI 层硬限制）。
              decoration: InputDecoration(labelText: l10n.tagName),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.titleRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppTokens.spaceSm),
            // 颜色选择器。
            Text(l10n.tagColor, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppTokens.spaceXs),
            Wrap(
              spacing: AppTokens.spaceXs,
              runSpacing: AppTokens.spaceXs,
              children: AppTokens.presetColors.map((color) {
                final isSelected =
                    color.toARGB32() == _selectedColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: AppTokens.motionFast,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}

/// 标签列表行：颜色圆点 + 名称 + 行尾菜单（编辑/删除，bottom sheet 风格）。
class _TagListTile extends StatelessWidget {
  const _TagListTile({
    required this.tag,
    required this.onTap,
    required this.onMenuEdit,
    required this.onMenuDelete,
  });

  final Tag tag;
  final VoidCallback onTap;
  final VoidCallback onMenuEdit;
  final VoidCallback onMenuDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: AppTokens.spaceXs,
            ),
            child: Row(
              children: [
                // 颜色圆点。
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(tag.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                // 名称。
                Expanded(
                  child: Text(
                    tag.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 行尾菜单。
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onPressed: () => _showRowMenu(context),
                  tooltip: l10n.rowActions,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: AppTokens.touchTarget,
                    minHeight: AppTokens.touchTarget,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRowMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusDialog),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTokens.spaceXs),
            ListTile(
              leading: const Icon(Icons.edit, size: 20),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                onMenuEdit();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.delete_outlined,
                size: 20,
                color: colorScheme.error,
              ),
              title: Text(
                l10n.delete,
                style: TextStyle(color: colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                onMenuDelete();
              },
            ),
            const SizedBox(height: AppTokens.spaceXs),
          ],
        ),
      ),
    );
  }
}
