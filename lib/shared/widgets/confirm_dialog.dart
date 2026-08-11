import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';

/// 级联删除确认对话框（50-ui-ux.md §6.3）。
///
/// 展示标题 + 警告文案 + 确认/取消按钮，符合 squircle 风格。
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  Color? confirmColor,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel ?? l10n.cancel),
        ),
        FilledButton(
          style: confirmColor != null
              ? FilledButton.styleFrom(backgroundColor: confirmColor)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel ?? l10n.confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
