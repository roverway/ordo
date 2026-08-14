// 新建/重命名文件夹名称弹窗（62-folder-nav.md §6.3）。
//
// 复用 showProjectFormDialog 同款视觉语言（移动端底部弹窗 / 桌面端居中
// 对话框），但仅名称输入（无颜色/描述字段）。只收集并返回名称字符串，
// 落库由调用方接线（抽屉/项目页统一处理）。

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_breakpoints.dart';

/// 打开新建/重命名文件夹名称弹窗。
///
/// - [initialName] 非空 = 重命名模式（预填）。
/// - 返回名称（trim 后）；取消（取消按钮 / 遮罩 / 返回键）返回 null。
Future<String?> showFolderNameDialog({
  required BuildContext context,
  String? initialName,
}) {
  if (AppBreakpoints.isWide(context)) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _FolderNameDialog(initialName: initialName),
    );
  }
  return showModalBottomSheet<String>(
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
      child: _FolderNameDialog(initialName: initialName),
    ),
  );
}

/// 名称弹窗主体：标题 + 名称输入 + 取消/保存（弹窗与对话框共用）。
class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({this.initialName});

  final String? initialName;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.initialName != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      // 底部弹窗形态底部留出操作区边距；对话框形态由 Dialog 自带 padding。
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceMd,
        AppTokens.spaceLg,
        AppTokens.spaceMd,
        AppTokens.spaceSm,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? l10n.renameFolder : l10n.newFolder,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppTokens.spaceLg),
            // 名称输入：[图标] 行内无边框输入，hint 即字段名（对齐项目表单）。
            Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 22,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    maxLength: _nameMaxLength,
                    // 紧凑行内不展示字符计数器（评审 #2 同款取舍）。
                    buildCounter: _hideCounter,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: l10n.folderName,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return l10n.titleRequired;
                      // 防御：maxLength 已拦截输入，但预填/程序赋值仍可能超长，
                      // 避免落库时抛未捕获 RepositoryException（name 上限 50）。
                      if (v.length > _nameMaxLength) {
                        return l10n.nameTooLong(_nameMaxLength);
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceMd),
            // 操作区：取消 + 保存（D4 显式保存风格）。
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                FilledButton(onPressed: _save, child: Text(l10n.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 隐藏字段右下角字符计数器（与项目表单同款，评审 #2）。
  static Widget? _hideCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}

/// 文件夹名称长度上限（与 tables.dart Folders.name `withLength(min: 1, max: 50)` 对齐）。
const int _nameMaxLength = 50;
