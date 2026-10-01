// 新建/重命名文件夹名称弹窗（62-folder-nav.md §6.3）。
//
// 复用 showProjectFormDialog 同款全平台统一居中对话框视觉语言（宽度约束
// [AppTokens.dialogMaxWidth] = 440dp），但仅名称输入（无颜色/描述字段）。
// 只收集并返回名称字符串，落库由调用方接线（抽屉/项目页统一处理）。

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_adaptive_dialog.dart';

/// 打开新建/重命名文件夹名称弹窗。
///
/// - [initialName] 非空 = 重命名模式（预填）。
/// - 返回名称（trim 后）；取消（取消按钮 / 遮罩 / 返回键）返回 null。
Future<String?> showFolderNameDialog({
  required BuildContext context,
  String? initialName,
}) {
  return showAppAdaptiveDialog<String>(
    context: context,
    builder: (dialogContext) => AppAdaptiveDialog(
      maxWidth: AppTokens.dialogMaxWidth,
      child: SingleChildScrollView(
        child: _FolderNameDialog(initialName: initialName),
      ),
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
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      Navigator.of(context).pop(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing ? l10n.renameFolder : l10n.newFolder,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: AppTokens.textTitleWeight,
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          TextFormField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.folderName,
              hintText: l10n.folderNameHint,
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return l10n.titleRequired;
              }
              return null;
            },
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
    );
  }
}
