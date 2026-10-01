import 'package:flutter/material.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';

/// AI 任务建议卡片底部操作栏（放弃与添加待办）。
class ProposalActionBar extends StatelessWidget {
  const ProposalActionBar({
    super.key,
    required this.isPersisted,
    required this.isPersisting,
    required this.isDiscarded,
    this.onConfirm,
    this.onDiscard,
  });

  final bool isPersisted;
  final bool isPersisting;
  final bool isDiscarded;
  final VoidCallback? onConfirm;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final secondaryTextColor = isDark
        ? AppTokens.textMutedDark
        : AppTokens.textMutedLight;

    return Row(
      children: [
        // Discard Action Button
        if (!isPersisted)
          TextButton(
            onPressed: (!isDiscarded && !isPersisting) ? onDiscard : null,
            style: TextButton.styleFrom(
              foregroundColor: secondaryTextColor,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
                vertical: AppTokens.spaceXs,
              ),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              isDiscarded ? l10n.aiDiscardedAction : l10n.aiDiscardAction,
              style: const TextStyle(fontSize: AppTokens.textFootnoteSize),
            ),
          ),
        const Spacer(),

        // Confirm Action Button (hidden if discarded)
        if (!isDiscarded)
          FilledButton(
            onPressed: (!isPersisted && !isPersisting) ? onConfirm : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
                vertical: AppTokens.spaceXs,
              ),
              minimumSize: const Size(0, 36),
            ),
            child: isPersisting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isPersisted ? l10n.aiTaskAddedAction : l10n.aiAddTaskAction,
                    style: const TextStyle(
                      fontSize: AppTokens.textFootnoteSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
      ],
    );
  }
}
