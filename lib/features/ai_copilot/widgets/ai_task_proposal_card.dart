import 'package:flutter/material.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';

/// Linear-style task proposal card rendered inside AI Copilot chat list.
///
/// Features:
/// - Human-in-the-loop: Never automatically saves until user taps confirm.
/// - Linear minimal aesthetic: Dark mode [surfaceCardDark], subtle micro-glow borders,
///   zero magic numbers (100% token compliant).
/// - Selectable substeps with rounded checkboxes.
/// - Idempotent confirm button: disabled and grayed out once persisted.
class AiTaskProposalCard extends StatelessWidget {
  const AiTaskProposalCard({
    super.key,
    required this.proposal,
    required this.selectedSubstepIndices,
    this.isPersisted = false,
    this.isPersisting = false,
    this.isDiscarded = false,
    this.onSubstepsChanged,
    this.onConfirm,
    this.onDiscard,
  });

  /// The parsed task proposal data.
  final AiTaskParseResult proposal;

  /// Indices of currently selected substeps.
  final Set<int> selectedSubstepIndices;

  /// Whether task has been saved into database.
  final bool isPersisted;

  /// Whether persistence request is currently running.
  final bool isPersisting;

  /// Whether user chose to discard this proposal.
  final bool isDiscarded;

  /// Callback when substeps selection changes.
  final ValueChanged<Set<int>>? onSubstepsChanged;

  /// Callback when user taps "Add to tasks".
  final VoidCallback? onConfirm;

  /// Callback when user taps "Discard".
  final VoidCallback? onDiscard;

  String _formatDateTime(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  (String, Color) _priorityInfo(BuildContext context, int priority) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return switch (priority) {
      3 => (isZh ? 'P1 · 重要紧急' : 'P1 · Urgent', AppTokens.colorPriorityHigh),
      2 => (isZh ? 'P2 · 适中' : 'P2 · Medium', AppTokens.colorPriorityMedium),
      1 => (isZh ? 'P3 · 低优' : 'P3 · Low', AppTokens.colorPriorityLow),
      _ => (isZh ? '无优先级' : 'None', AppTokens.textMutedDark),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final cardBg = isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;
    final shadows = isDark
        ? AppTokens.cardShadowDarkList
        : AppTokens.cardShadowLight;

    final primaryTextColor = isDark
        ? AppTokens.textPrimaryDark
        : AppTokens.textPrimaryLight;
    final secondaryTextColor = isDark
        ? AppTokens.textMutedDark
        : AppTokens.textMutedLight;

    final (priorityLabel, priorityColor) = _priorityInfo(
      context,
      proposal.priority,
    );

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: shadows,
      ),
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Category eyebrow badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceXs,
                  vertical: AppTokens.spaceMicro,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: AppTokens.alphaTintSoft,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                ),
                child: Text(
                  l10n.aiTaskProposalTitle,
                  style: TextStyle(
                    fontSize: AppTokens.textMicroSize,
                    fontWeight: AppTokens.textMicroWeight,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),

          // Title
          Text(
            proposal.title,
            style: TextStyle(
              fontSize: AppTokens.textHeadingSize,
              fontWeight: AppTokens.textHeadingWeight,
              color: primaryTextColor,
            ),
          ),

          // Description (optional)
          if (proposal.description != null &&
              proposal.description!.trim().isNotEmpty) ...[
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              proposal.description!,
              style: TextStyle(
                fontSize: AppTokens.textSecondarySize,
                fontWeight: AppTokens.textSecondaryWeight,
                color: secondaryTextColor,
                height: AppTokens.textBodyHeight,
              ),
            ),
          ],

          const SizedBox(height: AppTokens.spaceSm),

          // Metadata badges: Priority, Due Date, Tags
          Wrap(
            spacing: AppTokens.spaceXs,
            runSpacing: AppTokens.spaceXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Priority badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceXs,
                  vertical: AppTokens.spaceMicro,
                ),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(
                    alpha: AppTokens.alphaTintSoft,
                  ),
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

              // Due date badge
              if (proposal.dueAt != null)
                Container(
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
                        _formatDateTime(proposal.dueAt!),
                        style: TextStyle(
                          fontSize: AppTokens.textMicroSize,
                          fontWeight: AppTokens.textMicroWeight,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

              // Tags
              for (final tag in proposal.tags)
                Container(
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
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      fontWeight: AppTokens.textMicroWeight,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
            ],
          ),

          // Substeps Section
          if (proposal.substeps.isNotEmpty) ...[
            const SizedBox(height: AppTokens.spaceMd),
            Divider(height: 1, thickness: 0.5, color: borderColor),
            const SizedBox(height: AppTokens.spaceSm),
            Row(
              children: [
                Text(
                  l10n.aiSubstepsTitle,
                  style: TextStyle(
                    fontSize: AppTokens.textFootnoteSize,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                Text(
                  '${selectedSubstepIndices.length}/${proposal.substeps.length}',
                  style: TextStyle(
                    fontSize: AppTokens.textMicroSize,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            for (int i = 0; i < proposal.substeps.length; i++) ...[
              _buildSubstepRow(
                context,
                index: i,
                substep: proposal.substeps[i],
                isSelected: selectedSubstepIndices.contains(i),
                isInteractive: !isPersisted && !isDiscarded && !isPersisting,
                primaryColor: theme.colorScheme.primary,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
              ),
              if (i < proposal.substeps.length - 1)
                const SizedBox(height: AppTokens.spaceXxs),
            ],
          ],

          const SizedBox(height: AppTokens.spaceMd),
          Divider(height: 1, thickness: 0.5, color: borderColor),
          const SizedBox(height: AppTokens.spaceSm),

          // Bottom Action Bar
          Row(
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
                    style: const TextStyle(
                      fontSize: AppTokens.textFootnoteSize,
                    ),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPersisting) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: AppTokens.spaceXs),
                        Text(
                          l10n.aiTaskAddingAction,
                          style: const TextStyle(
                            fontSize: AppTokens.textFootnoteSize,
                          ),
                        ),
                      ] else if (isPersisted) ...[
                        const Icon(Icons.check, size: 16),
                        const SizedBox(width: AppTokens.spaceXxs),
                        Text(
                          l10n.aiTaskAddedAction,
                          style: const TextStyle(
                            fontSize: AppTokens.textFootnoteSize,
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.add_task, size: 16),
                        const SizedBox(width: AppTokens.spaceXxs),
                        Text(
                          l10n.aiAddTaskAction,
                          style: const TextStyle(
                            fontSize: AppTokens.textFootnoteSize,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubstepRow(
    BuildContext context, {
    required int index,
    required AiSubstep substep,
    required bool isSelected,
    required bool isInteractive,
    required Color primaryColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return InkWell(
      onTap: isInteractive
          ? () {
              final newSet = Set<int>.from(selectedSubstepIndices);
              if (isSelected) {
                newSet.remove(index);
              } else {
                newSet.add(index);
              }
              onSubstepsChanged?.call(newSet);
            }
          : null,
      borderRadius: BorderRadius.circular(AppTokens.radiusXs),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.spaceXxs,
          horizontal: AppTokens.spaceXxs,
        ),
        child: Row(
          children: [
            SizedBox(
              width: AppTokens.checkboxTapTargetSize,
              height: AppTokens.checkboxTapTargetSize,
              child: Checkbox(
                value: isSelected,
                shape: AppTokens.checkboxShape,
                onChanged: isInteractive
                    ? (checked) {
                        final newSet = Set<int>.from(selectedSubstepIndices);
                        if (checked == true) {
                          newSet.add(index);
                        } else {
                          newSet.remove(index);
                        }
                        onSubstepsChanged?.call(newSet);
                      }
                    : null,
              ),
            ),
            const SizedBox(width: AppTokens.checkboxToTitleGap),
            Expanded(
              child: Text(
                substep.title,
                style: TextStyle(
                  fontSize: AppTokens.textBodySize,
                  color: isInteractive ? primaryTextColor : secondaryTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
