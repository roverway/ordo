import 'package:flutter/material.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';

import 'proposal_substep_tile.dart';

/// AI 建议卡片的子步骤列表区域组件。
class ProposalSubstepsSection extends StatelessWidget {
  const ProposalSubstepsSection({
    super.key,
    required this.substeps,
    required this.selectedSubstepIndices,
    required this.isInteractive,
    required this.newlyAddedSubstepIndex,
    required this.borderColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.onAddSubstep,
    required this.onToggleSubstep,
    required this.onEditSubstep,
    required this.onRemoveSubstep,
  });

  final List<AiSubstep> substeps;
  final Set<int> selectedSubstepIndices;
  final bool isInteractive;
  final int? newlyAddedSubstepIndex;
  final Color borderColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final VoidCallback onAddSubstep;
  final void Function(int index, bool selected) onToggleSubstep;
  final void Function(int index, String newTitle) onEditSubstep;
  final ValueChanged<int> onRemoveSubstep;

  @override
  Widget build(BuildContext context) {
    if (substeps.isEmpty && !isInteractive) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
              '${selectedSubstepIndices.length}/${substeps.length}',
              style: TextStyle(
                fontSize: AppTokens.textMicroSize,
                color: secondaryTextColor,
              ),
            ),
            const Spacer(),
            if (isInteractive)
              InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                onTap: onAddSubstep,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceXs,
                    vertical: AppTokens.spaceMicro,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppTokens.spaceXxs),
                      Text(
                        l10n.aiAddSubstepAction,
                        style: TextStyle(
                          fontSize: AppTokens.textMicroSize,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceXs),
        for (int i = 0; i < substeps.length; i++) ...[
          ProposalSubstepTile(
            key: ValueKey(i),
            index: i,
            substep: substeps[i],
            isSelected: selectedSubstepIndices.contains(i),
            isInteractive: isInteractive,
            initialEditing: newlyAddedSubstepIndex == i,
            primaryColor: theme.colorScheme.primary,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onToggle: (checked) => onToggleSubstep(i, checked),
            onTitleSubmitted: (newTitle) => onEditSubstep(i, newTitle),
            onDelete: () => onRemoveSubstep(i),
          ),
          if (i < substeps.length - 1)
            const SizedBox(height: AppTokens.spaceXxs),
        ],
      ],
    );
  }
}
