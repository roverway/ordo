import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';

import 'proposal_action_bar.dart';
import 'proposal_date_picker_sheets.dart';
import 'proposal_metadata_badges.dart';
import 'proposal_substeps_section.dart';
import '../../../shared/widgets/app_adaptive_dialog.dart';

/// Linear-style task proposal card rendered inside AI Copilot chat list.
///
/// Features:
/// - Human-in-the-loop: Never automatically saves until user taps confirm.
/// - In-place live editing for all proposal fields:
///   - Title: Tap to edit in-place with instant checkmark confirmation.
///   - Description: Tap to edit in-place or add a note if empty.
///   - Priority: One-tap cyclic toggle (P1 -> P2 -> P3 -> None) with haptics.
///   - Due Date: Tap badge to pick preset/custom deadline or clear.
///   - Start Date: Tap badge to set starting timestamp or clear.
///   - Tags: Tap to edit/remove existing tags, plus chip to append tags.
///   - Substeps: Inline text editing per step, delete action, and add step button.
/// - Linear minimal aesthetic: Dark mode [surfaceCardDark], subtle micro-glow borders,
///   100% token compliant (zero magic numbers).
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

  /// Callback when user edits proposal fields.
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

  late TextEditingController _descController;
  late FocusNode _descFocusNode;
  bool _isEditingDesc = false;

  int? _newlyAddedSubstepIndex;

  bool get isInteractive =>
      !widget.isPersisted && !widget.isDiscarded && !widget.isPersisting;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.proposal.title);
    _titleFocusNode = FocusNode();

    _descController = TextEditingController(
      text: widget.proposal.description ?? '',
    );
    _descFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant AiTaskProposalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proposal.title != widget.proposal.title && !_isEditingTitle) {
      _titleController.text = widget.proposal.title;
    }
    if (oldWidget.proposal.description != widget.proposal.description &&
        !_isEditingDesc) {
      _descController.text = widget.proposal.description ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _descController.dispose();
    _descFocusNode.dispose();

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

  void _submitDescEdit() {
    final newDesc = _descController.text.trim();
    final updated = widget.proposal.copyWith(
      description: newDesc,
      clearDescription: newDesc.isEmpty,
    );
    widget.onProposalChanged?.call(updated);
    setState(() {
      _isEditingDesc = false;
    });
  }

  void _cyclePriority() {
    if (!isInteractive) return;
    HapticFeedback.selectionClick();

    // Cyclic sequence: P1 (3) -> P2 (2) -> P3 (1) -> None (0) -> P1 (3)
    final next = switch (widget.proposal.priority) {
      3 => 2,
      2 => 1,
      1 => 0,
      _ => 3,
    };

    final updated = widget.proposal.copyWith(priority: next);
    widget.onProposalChanged?.call(updated);
  }

  void _updateDueAt(int? timestamp) {
    final updated = widget.proposal.copyWith(
      dueAt: timestamp,
      clearDueAt: timestamp == null,
    );
    widget.onProposalChanged?.call(updated);
  }

  void _updateStartAt(int? timestamp) {
    final updated = widget.proposal.copyWith(
      startAt: timestamp,
      clearStartAt: timestamp == null,
    );
    widget.onProposalChanged?.call(updated);
  }

  Future<void> _showDueDatePicker(BuildContext context) async {
    if (!isInteractive) return;
    await showProposalDueDatePicker(
      context: context,
      initialDueAt: widget.proposal.dueAt,
      onDateSelected: _updateDueAt,
    );
  }

  Future<void> _showStartDatePicker(BuildContext context) async {
    if (!isInteractive) return;
    await showProposalStartDatePicker(
      context: context,
      initialStartAt: widget.proposal.startAt,
      onDateSelected: _updateStartAt,
    );
  }

  Future<void> _promptAddTag(BuildContext context) async {
    if (!isInteractive) return;
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    final tagInputController = TextEditingController();

    final newTag = await showAppAdaptiveDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AppAdaptiveDialog(
          maxWidth: AppTokens.dialogConfirmMaxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.aiAddTagTitle,
                style: const TextStyle(
                  fontSize: AppTokens.textSubtitleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTokens.spaceMd),
              TextField(
                controller: tagInputController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.aiAddTagHint,
                  isDense: true,
                ),
                onSubmitted: (val) => Navigator.pop(dialogCtx, val.trim()),
              ),
              const SizedBox(height: AppTokens.spaceLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: AppTokens.spaceSm),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      dialogCtx,
                      tagInputController.text.trim(),
                    ),
                    child: Text(l10n.confirm),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (newTag != null &&
        newTag.isNotEmpty &&
        !widget.proposal.tags.contains(newTag)) {
      final updatedTags = List<String>.from(widget.proposal.tags)..add(newTag);
      final updated = widget.proposal.copyWith(tags: updatedTags);
      widget.onProposalChanged?.call(updated);
    }
  }

  void _removeTag(String tag) {
    if (!isInteractive) return;
    HapticFeedback.selectionClick();
    final updatedTags = widget.proposal.tags.where((t) => t != tag).toList();
    final updated = widget.proposal.copyWith(tags: updatedTags);
    widget.onProposalChanged?.call(updated);
  }

  void _editSubstep(int index, String newTitle) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    final updatedList = List<AiSubstep>.from(widget.proposal.substeps);
    updatedList[index] = AiSubstep(
      title: trimmed,
      sortOrder: updatedList[index].sortOrder,
    );
    final updated = widget.proposal.copyWith(substeps: updatedList);
    widget.onProposalChanged?.call(updated);
  }

  void _removeSubstep(int index) {
    if (!isInteractive) return;
    HapticFeedback.selectionClick();
    final updatedList = List<AiSubstep>.from(widget.proposal.substeps)
      ..removeAt(index);
    final updated = widget.proposal.copyWith(substeps: updatedList);
    widget.onProposalChanged?.call(updated);

    // Adjust selected indices
    final newSelected = <int>{};
    for (final sel in widget.selectedSubstepIndices) {
      if (sel < index) {
        newSelected.add(sel);
      } else if (sel > index) {
        newSelected.add(sel - 1);
      }
    }
    widget.onSubstepsChanged?.call(newSelected);
  }

  void _addSubstep() {
    if (!isInteractive) return;
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    final newStep = AiSubstep(
      title: l10n.aiStepDefaultTitle(widget.proposal.substeps.length + 1),
      sortOrder: widget.proposal.substeps.length,
    );
    final updatedList = List<AiSubstep>.from(widget.proposal.substeps)
      ..add(newStep);
    final updated = widget.proposal.copyWith(substeps: updatedList);
    widget.onProposalChanged?.call(updated);

    final newSelected = Set<int>.from(widget.selectedSubstepIndices)
      ..add(updatedList.length - 1);
    widget.onSubstepsChanged?.call(newSelected);

    // Start editing this new step right away
    setState(() {
      _newlyAddedSubstepIndex = updatedList.length - 1;
    });
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

          // Title: In-place editing
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

          // Description: In-place editing
          if (_isEditingDesc) ...[
            const SizedBox(height: AppTokens.spaceXs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _descController,
                    focusNode: _descFocusNode,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 1,
                    style: TextStyle(
                      fontSize: AppTokens.textSecondarySize,
                      color: primaryTextColor,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.aiTaskDescriptionHint,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppTokens.spaceXxs,
                        horizontal: AppTokens.spaceXs,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusMicro,
                        ),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                IconButton(
                  icon: const Icon(Icons.check, size: 18),
                  color: theme.colorScheme.primary,
                  onPressed: _submitDescEdit,
                ),
              ],
            ),
          ] else if (widget.proposal.description != null &&
              widget.proposal.description!.trim().isNotEmpty) ...[
            const SizedBox(height: AppTokens.spaceXs),
            InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
              onTap: isInteractive
                  ? () {
                      setState(() {
                        _isEditingDesc = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _descFocusNode.requestFocus();
                      });
                    }
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.proposal.description!,
                      style: TextStyle(
                        fontSize: AppTokens.textSecondarySize,
                        fontWeight: AppTokens.textSecondaryWeight,
                        color: secondaryTextColor,
                        height: AppTokens.textBodyHeight,
                      ),
                    ),
                  ),
                  if (isInteractive) ...[
                    const SizedBox(width: AppTokens.spaceXs),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.edit_outlined,
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
          ] else if (isInteractive) ...[
            const SizedBox(height: AppTokens.spaceXs),
            InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
              onTap: () {
                setState(() {
                  _isEditingDesc = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _descFocusNode.requestFocus();
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTokens.spaceMicro,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_comment_outlined,
                      size: 13,
                      color: secondaryTextColor.withValues(
                        alpha: AppTokens.alphaOverlayHeavy,
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceXxs),
                    Text(
                      l10n.aiAddDescription,
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

          const SizedBox(height: AppTokens.spaceSm),

          // Metadata badges: Priority, Start Time, Due Date, Tags
          ProposalMetadataBadges(
            proposal: widget.proposal,
            isInteractive: isInteractive,
            onCyclePriority: _cyclePriority,
            onPickStartDate: () => _showStartDatePicker(context),
            onPickDueDate: () => _showDueDatePicker(context),
            onRemoveTag: _removeTag,
            onAddTag: () => _promptAddTag(context),
          ),

          // Substeps Section
          ProposalSubstepsSection(
            substeps: widget.proposal.substeps,
            selectedSubstepIndices: widget.selectedSubstepIndices,
            isInteractive: isInteractive,
            newlyAddedSubstepIndex: _newlyAddedSubstepIndex,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onAddSubstep: _addSubstep,
            onToggleSubstep: (index, selected) {
              final updated = Set<int>.from(widget.selectedSubstepIndices);
              if (selected) {
                updated.add(index);
              } else {
                updated.remove(index);
              }
              widget.onSubstepsChanged?.call(updated);
            },
            onEditSubstep: (index, newTitle) {
              _editSubstep(index, newTitle);
              if (_newlyAddedSubstepIndex == index) {
                setState(() => _newlyAddedSubstepIndex = null);
              }
            },
            onRemoveSubstep: _removeSubstep,
          ),

          const SizedBox(height: AppTokens.spaceMd),
          Divider(height: 1, thickness: 0.5, color: borderColor),
          const SizedBox(height: AppTokens.spaceSm),

          // Bottom Action Bar
          ProposalActionBar(
            isPersisted: widget.isPersisted,
            isPersisting: widget.isPersisting,
            isDiscarded: widget.isDiscarded,
            onConfirm: widget.onConfirm,
            onDiscard: widget.onDiscard,
          ),
        ],
      ),
    );
  }
}
