import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import 'app_adaptive_dialog.dart';

/// 级联删除/操作确认对话框（50-ui-ux.md §6.3）。
///
/// 展示标题 + 警告文案 + 确认/取消按钮，符合 Liquid Glass squircle 风格。
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  Color? confirmColor,
  bool isDestructive = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final effectiveConfirmColor =
      confirmColor ?? (isDestructive ? theme.colorScheme.error : null);

  final result = await showAppAdaptiveDialog<bool>(
    context: context,
    builder: (dialogContext) => AppAdaptiveDialog(
      maxWidth: AppTokens.dialogConfirmMaxWidth,
      padding: const EdgeInsets.all(AppTokens.spaceXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
              fontWeight: AppTokens.textTitleWeight,
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            message,
            style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(cancelLabel ?? l10n.cancel),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              FilledButton(
                style: effectiveConfirmColor != null
                    ? FilledButton.styleFrom(
                        backgroundColor: effectiveConfirmColor,
                      )
                    : null,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel ?? l10n.confirm),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
