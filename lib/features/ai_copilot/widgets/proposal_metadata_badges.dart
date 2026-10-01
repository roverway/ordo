import 'package:flutter/material.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';

/// AI 建议卡片的元数据徽标组（优先级、起止时间、标签集合及快速操作）。
class ProposalMetadataBadges extends StatelessWidget {
  const ProposalMetadataBadges({
    super.key,
    required this.proposal,
    required this.isInteractive,
    required this.onCyclePriority,
    required this.onPickStartDate,
    required this.onPickDueDate,
    required this.onRemoveTag,
    required this.onAddTag,
  });

  final AiTaskParseResult proposal;
  final bool isInteractive;
  final VoidCallback onCyclePriority;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickDueDate;
  final ValueChanged<String> onRemoveTag;
  final VoidCallback onAddTag;

  static String formatDateTime(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  static (String, Color) priorityInfo(AppLocalizations l10n, int priority) {
    return switch (priority) {
      3 => (l10n.aiPriorityP1, AppTokens.colorPriorityHigh),
      2 => (l10n.aiPriorityP2, AppTokens.colorPriorityMedium),
      1 => (l10n.aiPriorityP3, AppTokens.colorPriorityLow),
      _ => (l10n.aiPriorityNone, AppTokens.textMutedDark),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;
    final secondaryTextColor = isDark
        ? AppTokens.textMutedDark
        : AppTokens.textMutedLight;

    final (priorityLabel, priorityColor) = priorityInfo(
      l10n,
      proposal.priority,
    );

    return Wrap(
      spacing: AppTokens.spaceXs,
      runSpacing: AppTokens.spaceXs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Priority badge (Interactive cyclic toggle)
        InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
          onTap: isInteractive ? onCyclePriority : null,
          child: Tooltip(
            message: isInteractive ? l10n.aiTapToCyclePriority : priorityLabel,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXs,
                vertical: AppTokens.spaceMicro,
              ),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: AppTokens.alphaTintSoft),
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                border: Border.all(
                  color: priorityColor.withValues(
                    alpha: AppTokens.alphaBorderSubtle,
                  ),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceXxs),
                  Text(
                    priorityLabel,
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      fontWeight: AppTokens.textMicroWeight,
                      color: priorityColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Start date badge (Tap to set/change)
        if (proposal.startAt != null)
          InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
            onTap: onPickStartDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXs,
                vertical: AppTokens.spaceMicro,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTokens.surfaceSubtleDark
                    : AppTokens.surfaceSubtleLight,
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                border: Border.all(color: borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: AppTokens.textMicroSize + 2,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: AppTokens.spaceXxs),
                  Text(
                    l10n.aiStartPrefix(formatDateTime(proposal.startAt!)),
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      fontWeight: AppTokens.textMicroWeight,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (isInteractive)
          InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
            onTap: onPickStartDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXs,
                vertical: AppTokens.spaceMicro,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                border: Border.all(
                  color: borderColor,
                  width: 0.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_outlined,
                    size: 13,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: AppTokens.spaceXxs),
                  Text(
                    l10n.aiAddStartAction,
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Due date badge (Tap to set/change)
        if (proposal.dueAt != null)
          InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
            onTap: onPickDueDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXs,
                vertical: AppTokens.spaceMicro,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTokens.surfaceSubtleDark
                    : AppTokens.surfaceSubtleLight,
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                border: Border.all(color: borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: AppTokens.textMicroSize + 2,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: AppTokens.spaceXxs),
                  Text(
                    formatDateTime(proposal.dueAt!),
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      fontWeight: AppTokens.textMicroWeight,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (isInteractive)
          InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
            onTap: onPickDueDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXs,
                vertical: AppTokens.spaceMicro,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                border: Border.all(color: borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 13,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: AppTokens.spaceXxs),
                  Text(
                    l10n.aiAddDueAction,
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Tags
        for (final tag in proposal.tags)
          Container(
            padding: const EdgeInsets.only(
              left: AppTokens.spaceXs,
              right: AppTokens.spaceXxs,
              top: AppTokens.spaceMicro,
              bottom: AppTokens.spaceMicro,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTokens.surfaceSubtleDark
                  : AppTokens.surfaceSubtleLight,
              borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: AppTokens.textMicroSize,
                    fontWeight: AppTokens.textMicroWeight,
                    color: secondaryTextColor,
                  ),
                ),
                if (isInteractive) ...[
                  const SizedBox(width: AppTokens.spaceXxs),
                  InkWell(
                    onTap: () => onRemoveTag(tag),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: secondaryTextColor.withValues(
                        alpha: AppTokens.alphaOverlayHeavy,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Add Tag action chip
        if (isInteractive)
          InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
            onTap: onAddTag,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXs,
                vertical: AppTokens.spaceMicro,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                border: Border.all(color: borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tag, size: 13, color: secondaryTextColor),
                  const SizedBox(width: AppTokens.spaceXxs),
                  Text(
                    l10n.aiAddTagAction,
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
