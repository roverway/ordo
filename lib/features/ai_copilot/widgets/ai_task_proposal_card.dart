import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';

/// Linear-style task proposal card rendered inside AI Copilot chat list.
///
/// Features:
/// - Human-in-the-loop: Never automatically saves until user taps confirm.
/// - Inline title editing & priority quick-toggle before confirming.
/// - Linear minimal aesthetic: Dark mode [surfaceCardDark], subtle micro-glow borders,
///   zero magic numbers (100% token compliant).
/// - Selectable substeps with rounded checkboxes.
/// - Idempotent confirm button: disabled and grayed out once persisted.
class AiTaskProposalCard extends StatefulWidget {
  const AiTaskProposalCard({
    super.key,
    required this.proposal,
    required this.selectedSubstepIndices,
    this.isPersisted = false,
    this.isPersisting = false,
    this.isDiscarded = false,
    this.onSubstepsChanged,
    this.onProposalChanged,
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

  /// Callback when user edits proposal (e.g. title or priority).
  final ValueChanged<AiTaskParseResult>? onProposalChanged;

  /// Callback when user taps "Add to tasks".
  final VoidCallback? onConfirm;

  /// Callback when user taps "Discard".
  final VoidCallback? onDiscard;

  @override
  State<AiTaskProposalCard> createState() => _AiTaskProposalCardState();
}

class _AiTaskProposalCardState extends State<AiTaskProposalCard> {
  late TextEditingController _titleController;
  late FocusNode _titleFocusNode;
  bool _isEditingTitle = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.proposal.title);
    _titleFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant AiTaskProposalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proposal.title != widget.proposal.title && !_isEditingTitle) {
      _titleController.text = widget.proposal.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _submitTitleEdit() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.proposal.title) {
      final updated = widget.proposal.copyWith(title: newTitle);
      widget.onProposalChanged?.call(updated);
    } else {
      _titleController.text = widget.proposal.title;
    }
    setState(() {
      _isEditingTitle = false;
    });
  }

  void _cyclePriority() {
    if (widget.isPersisted || widget.isDiscarded || widget.isPersisting) return;
    HapticFeedback.selectionClick();

    // 3 -> 2 -> 1 -> 0 -> 3
    final cur = widget.proposal.priority;
    final int next;
    if (cur == 3) {
      next = 2;
    } else if (cur == 2) {
      next = 1;
    } else if (cur == 1) {
      next = 0;
    } else {
      next = 3;
    }

    final updated = widget.proposal.copyWith(priority: next);
    widget.onProposalChanged?.call(updated);
  }

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

    final isInteractive = !widget.isPersisted &&
        !widget.isDiscarded &&
        !widget.isPersisting;

    final (priorityLabel, priorityColor) = _priorityInfo(
      context,
      widget.proposal.priority,
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

          // Title (with inline editing capability)
          if (_isEditingTitle)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: AppTokens.textHeadingSize,
                      fontWeight: AppTokens.textHeadingWeight,
                      color: primaryTextColor,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppTokens.spaceXxs,
                      ),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _submitTitleEdit(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  color: theme.colorScheme.primary,
                  onPressed: _submitTitleEdit,
                ),
              ],
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
              onTap: isInteractive
                  ? () {
                      setState(() {
                        _isEditingTitle = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _titleFocusNode.requestFocus();
                      });
                    }
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.proposal.title,
                      style: TextStyle(
                        fontSize: AppTokens.textHeadingSize,
                        fontWeight: AppTokens.textHeadingWeight,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  if (isInteractive) ...[
                    const SizedBox(width: AppTokens.spaceXs),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: secondaryTextColor.withValues(
                          alpha: AppTokens.alphaOverlayHeavy,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Description (optional)
          if (widget.proposal.description != null &&
              widget.proposal.description!.trim().isNotEmpty) ...[
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              widget.proposal.description!,
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
              // Priority badge (Interactive quick-cycle)
              InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                onTap: isInteractive ? _cyclePriority : null,
                child: Tooltip(
                  message: isInteractive ? '点击切换优先级' : priorityLabel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceXs,
                      vertical: AppTokens.spaceMicro,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(
                        alpha: AppTokens.alphaTintSoft,
                      ),
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusMicro),
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

              // Due date badge
              if (widget.proposal.dueAt != null)
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
                        _formatDateTime(widget.proposal.dueAt!),
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
              for (final tag in widget.proposal.tags)
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
          if (widget.proposal.substeps.isNotEmpty) ...[
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
                  '${widget.selectedSubstepIndices.length}/${widget.proposal.substeps.length}',
                  style: TextStyle(
                    fontSize: AppTokens.textMicroSize,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            for (int i = 0; i < widget.proposal.substeps.length; i++) ...[
              _buildSubstepRow(
                context,
                index: i,
                substep: widget.proposal.substeps[i],
                isSelected: widget.selectedSubstepIndices.contains(i),
                isInteractive: isInteractive,
                primaryColor: theme.colorScheme.primary,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
              ),
              if (i < widget.proposal.substeps.length - 1)
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
              if (!widget.isPersisted)
                TextButton(
                  onPressed:
                      (!widget.isDiscarded && !widget.isPersisting)
                          ? widget.onDiscard
                          : null,
                  style: TextButton.styleFrom(
                    foregroundColor: secondaryTextColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceSm,
                      vertical: AppTokens.spaceXs,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(
                    widget.isDiscarded
                        ? l10n.aiDiscardedAction
                        : l10n.aiDiscardAction,
                    style: const TextStyle(
                      fontSize: AppTokens.textFootnoteSize,
                    ),
                  ),
                ),
              const Spacer(),

              // Confirm Action Button (hidden if discarded)
              if (!widget.isDiscarded)
                FilledButton(
                  onPressed:
                      (!widget.isPersisted && !widget.isPersisting)
                          ? widget.onConfirm
                          : null,
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
                      if (widget.isPersisting) ...[
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
                      ] else if (widget.isPersisted) ...[
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
              final newSet = Set<int>.from(widget.selectedSubstepIndices);
              if (isSelected) {
                newSet.remove(index);
              } else {
                newSet.add(index);
              }
              widget.onSubstepsChanged?.call(newSet);
            }
          : null,
      borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceXxs,
          vertical: AppTokens.spaceMicro,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: isSelected,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                ),
                activeColor: primaryColor,
                onChanged: isInteractive
                    ? (val) {
                        final newSet =
                            Set<int>.from(widget.selectedSubstepIndices);
                        if (val == true) {
                          newSet.add(index);
                        } else {
                          newSet.remove(index);
                        }
                        widget.onSubstepsChanged?.call(newSet);
                      }
                    : null,
              ),
            ),
            const SizedBox(width: AppTokens.spaceXs),
            Expanded(
              child: Text(
                substep.title,
                style: TextStyle(
                  fontSize: AppTokens.textBodySize,
                  color: isSelected ? primaryTextColor : secondaryTextColor,
                  decoration: isSelected ? null : TextDecoration.lineThrough,
                  decorationColor: secondaryTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
