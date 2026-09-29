import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ai/models/ai_task_parse_result.dart';
import '../../../core/theme/app_tokens.dart';

/// An isolated widget representing a single substep row in [AiTaskProposalCard].
///
/// Encapsulates inline text editing state and text controllers locally so
/// typing or focusing a substep does not trigger an entire proposal card rebuild.
class ProposalSubstepTile extends StatefulWidget {
  const ProposalSubstepTile({
    super.key,
    required this.index,
    required this.substep,
    required this.isSelected,
    required this.isInteractive,
    required this.primaryColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.onToggle,
    required this.onTitleSubmitted,
    required this.onDelete,
    this.initialEditing = false,
  });

  final int index;
  final AiSubstep substep;
  final bool isSelected;
  final bool isInteractive;
  final Color primaryColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onTitleSubmitted;
  final VoidCallback onDelete;
  final bool initialEditing;

  @override
  State<ProposalSubstepTile> createState() => _ProposalSubstepTileState();
}

class _ProposalSubstepTileState extends State<ProposalSubstepTile> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialEditing;
    _controller = TextEditingController(text: widget.substep.title);
    _focusNode = FocusNode();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProposalSubstepTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.substep.title != widget.substep.title && !_isEditing) {
      _controller.text = widget.substep.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitEdit(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      widget.onTitleSubmitted(trimmed);
    } else {
      _controller.text = widget.substep.title;
    }
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          // Checkbox matching design token radius
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: widget.isSelected,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: widget.isInteractive
                  ? (checked) {
                      HapticFeedback.selectionClick();
                      widget.onToggle(checked ?? false);
                    }
                  : null,
            ),
          ),
          const SizedBox(width: AppTokens.spaceXs),

          // Substep title: inline editing or display
          if (_isEditing) ...[
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                style: TextStyle(
                  fontSize: AppTokens.textSecondarySize,
                  color: widget.primaryTextColor,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppTokens.spaceXxs,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: widget.primaryColor),
                  ),
                ),
                onSubmitted: _submitEdit,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check, size: 16),
              color: widget.primaryColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () => _submitEdit(_controller.text),
            ),
          ] else ...[
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                onTap: widget.isInteractive
                    ? () {
                        setState(() {
                          _isEditing = true;
                          _controller.text = widget.substep.title;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _focusNode.requestFocus();
                          }
                        });
                      }
                    : null,
                child: Text(
                  widget.substep.title,
                  style: TextStyle(
                    fontSize: AppTokens.textSecondarySize,
                    color: widget.isSelected
                        ? widget.primaryTextColor
                        : widget.secondaryTextColor,
                    decoration: widget.isSelected
                        ? null
                        : TextDecoration.lineThrough,
                  ),
                ),
              ),
            ),
            if (widget.isInteractive) ...[
              InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onDelete();
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.spaceMicro),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: widget.secondaryTextColor.withValues(
                      alpha: AppTokens.alphaOverlayHeavy,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
