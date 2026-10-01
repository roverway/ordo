import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/db/repositories/todo_repository.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/app_adaptive_dialog.dart';
import '../../shared/widgets/app_modal_sheet.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/page_hero_header.dart';
import '../../shared/widgets/scope_switcher_sheet.dart';
import '../../shared/widgets/staggered_fade_slide.dart';
import 'tag_providers.dart';

/// 标签列表页（FR-TAG-01 / FR-VIEW-04）。
///
/// 遵循 Linear 风格极简工业质感：
/// - 标签项呈现微描边彩色胶囊卡片；
/// - 右侧直接展示该标签下挂载的实时任务总数（等宽数字）；
/// - 行尾菜单提供编辑与删除入口。
class TagsPage extends ConsumerWidget {
  const TagsPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tagsAsync = ref.watch(tagsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: tagsAsync.when(
          data: (tags) {
            final tagCount = tags.length;
            final isZh = l10n.localeName.startsWith('zh');
            final subtitleStr = isZh ? '$tagCount 个标签' : '$tagCount tags';

            return Column(
              children: [
                PageHeroHeader(
                  title: l10n.navTags,
                  showDropdownChevron: true,
                  onTitleTapWithContext: (ctx) => showViewScopeSheet(ctx),
                  subtitle: subtitleStr,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.search,
                        icon: const Icon(Icons.search, size: 20),
                        onPressed: () => context.push('/search'),
                      ),
                      IconButton(
                        tooltip: l10n.newTag,
                        icon: const Icon(Icons.add_rounded, size: 22),
                        onPressed: () => _showNewTagDialog(context, ref),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: tags.isEmpty
                      ? EmptyState(
                          icon: Icons.label_outline,
                          accentColor: AppTokens.colorNavTags,
                          message: l10n.emptyTags,
                          action: FilledButton.icon(
                            onPressed: () => _showNewTagDialog(context, ref),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.newTag),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.spaceMd,
                            vertical: AppTokens.spaceSm,
                          ),
                          itemCount: tags.length,
                          itemBuilder: (context, index) {
                            final tag = tags[index];
                            return StaggeredFadeSlide(
                              index: index,
                              child: _TagListTile(
                                tag: tag,
                                onTap: () => context.push('/tags/${tag.id}'),
                                onMenuEdit: () =>
                                    _showEditTagDialog(context, ref, tag),
                                onMenuDelete: () =>
                                    _showDeleteTagDialog(context, ref, tag),
                              ),
                            );
                          },
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
      ),
      floatingActionButton: null,
    );
  }

  Future<void> _showNewTagDialog(BuildContext context, WidgetRef ref) async {
    final data = await showTagFormDialog(context: context);
    if (data == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(todoRepositoryProvider);
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

/// 新建/编辑标签对话框。
Future<TagFormData?> showTagFormDialog({
  required BuildContext context,
  String? initialName,
  int? initialColor,
}) {
  return showAppAdaptiveDialog<TagFormData>(
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

    return AppAdaptiveDialog(
      maxWidth: 380,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? l10n.editTag : l10n.newTag,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              maxLength: 30,
              decoration: InputDecoration(labelText: l10n.tagName),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.titleRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppTokens.spaceSm),
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
            const SizedBox(height: AppTokens.spaceLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                FilledButton(onPressed: _save, child: Text(l10n.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 标签列表行：Linear 风格带微描边彩色胶囊 + 挂载任务数。
class _TagListTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tagColor = Color(tag.color);

    final tasksCount =
        ref.watch(tagTasksProvider(tag.id)).asData?.value.length ?? 0;

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceXs),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppTokens.surfaceCardDark.withValues(
                  alpha: AppTokens.alphaCardFrostedDark,
                )
              : AppTokens.surfaceCardLight.withValues(
                  alpha: AppTokens.alphaCardFrostedLight,
                ),
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusList),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
                vertical: AppTokens.spaceSm,
              ),
              child: Row(
                children: [
                  // Linear 风格彩色微胶囊徽标
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: tagColor.withValues(
                        alpha: isDark
                            ? AppTokens.alphaTintStrong
                            : AppTokens.alphaBorderSubtle,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                      border: Border.all(
                        color: tagColor.withValues(
                          alpha: isDark
                              ? AppTokens.alphaBorderEmphasis
                              : AppTokens.alphaTintStrong,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tagColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceSm),
                  // 标签名称
                  Expanded(
                    child: Text(
                      tag.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 挂载任务数胶囊（等宽数字）
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: AppTokens.alphaTintFaint,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    child: Text(
                      '$tasksCount',
                      style: TextStyle(
                        fontSize: AppTokens.textMicroSize,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppTokens.fontTabular,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  // 行尾菜单
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
      ),
    );
  }

  void _showRowMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    showAppModalBottomSheet<void>(
      context: context,
      builder: (context) => AppModalSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
      ),
    );
  }
}
