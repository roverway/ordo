import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// 新建任务弹窗内的单条子任务行实体数据模型。
class SubtaskDraftRow {
  SubtaskDraftRow({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;
  bool isDone = false;
}

/// 新建任务弹窗的子任务列表与添加组件。
class TaskCreateSubtasksSection extends StatelessWidget {
  const TaskCreateSubtasksSection({
    required this.subtaskRows,
    required this.borderColor,
    required this.onToggleDone,
    required this.onRemove,
    required this.onAddSubtask,
    super.key,
  });

  final List<SubtaskDraftRow> subtaskRows;
  final Color borderColor;
  final void Function(int index) onToggleDone;
  final void Function(int index) onRemove;
  final VoidCallback onAddSubtask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 14, bottom: 4),
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                l10n.subtasks,
                style: TextStyle(
                  fontSize: AppTokens.textMicroSize,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant.withValues(
                    alpha: AppTokens.alphaScrim,
                  ),
                ),
              ),
              if (subtaskRows.isNotEmpty)
                Text(
                  l10n.itemCount(subtaskRows.length),
                  style: TextStyle(
                    fontSize: AppTokens.textMicroSize,
                    fontFeatures: AppTokens.fontTabular,
                    color: colorScheme.onSurfaceVariant.withValues(
                      alpha: AppTokens.alphaScrim,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 已添加的子任务列表
        for (var i = 0; i < subtaskRows.length; i++)
          _buildSubtaskItem(context, i, subtaskRows[i], colorScheme, l10n),

        // 添加子任务按钮 / 行
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusList),
            onTap: onAddSubtask,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                      border: Border.all(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: AppTokens.alphaBorderEmphasis,
                        ),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 12,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: AppTokens.alphaContentMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.addSubtask,
                      style: TextStyle(
                        fontSize: AppTokens.textSecondarySize,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: AppTokens.alphaContentDisabled,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtaskItem(
    BuildContext context,
    int index,
    SubtaskDraftRow row,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => onToggleDone(index),
            child: Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: row.isDone ? colorScheme.onSurface : colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                border: Border.all(
                  color: row.isDone
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withValues(
                          alpha: AppTokens.alphaBorderEmphasis,
                        ),
                  width: 1.5,
                ),
              ),
              child: row.isDone
                  ? Icon(Icons.check, size: 11, color: colorScheme.surface)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: row.controller.text.isNotEmpty && !row.focusNode.hasFocus
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      row.focusNode.requestFocus();
                    },
                    child: Text(
                      row.controller.text,
                      style: TextStyle(
                        fontSize: AppTokens.textSecondarySize,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        decoration: row.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        color: row.isDone
                            ? colorScheme.onSurfaceVariant.withValues(
                                alpha: AppTokens.alphaContentMuted,
                              )
                            : colorScheme.onSurface,
                      ),
                    ),
                  )
                : TextField(
                    controller: row.controller,
                    focusNode: row.focusNode,
                    maxLines: null,
                    style: TextStyle(
                      fontSize: AppTokens.textSecondarySize,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      decoration: row.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: row.isDone
                          ? colorScheme.onSurfaceVariant.withValues(
                              alpha: AppTokens.alphaContentMuted,
                            )
                          : colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.subtasks,
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: AppTokens.alphaContentDisabled,
                        ),
                        fontSize: AppTokens.textSecondarySize,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusChip),
            onTap: () => onRemove(index),
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: Icon(
                Icons.close,
                size: 14,
                color: colorScheme.onSurfaceVariant.withValues(
                  alpha: AppTokens.alphaContentDisabled,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
