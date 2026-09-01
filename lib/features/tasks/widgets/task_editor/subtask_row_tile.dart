import 'package:flutter/material.dart';

import '../../../../core/db/tables.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/motion.dart';
import 'task_editor_controller.dart';

/// 子任务行展现模式（状态机）：浏览态（只读文本点击切换）与编辑态（TextField 输入）。
enum SubtaskTileDisplayMode { viewing, editing }

/// 单条子任务交互行。
class SubtaskRowTile extends StatefulWidget {
  const SubtaskRowTile({
    super.key,
    required this.index,
    required this.row,
    required this.onRemove,
    required this.onSubmitted,
    required this.onChanged,
    required this.onToggleStatus,
  });

  final int index;
  final SubtaskRow row;
  final VoidCallback onRemove;
  final VoidCallback onSubmitted;
  final VoidCallback onChanged;
  final VoidCallback onToggleStatus;

  @override
  State<SubtaskRowTile> createState() => _SubtaskRowTileState();
}

class _SubtaskRowTileState extends State<SubtaskRowTile> {
  late SubtaskTileDisplayMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.row.isNew
        ? SubtaskTileDisplayMode.editing
        : SubtaskTileDisplayMode.viewing;
    widget.row.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant SubtaskRowTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.focusNode != widget.row.focusNode) {
      oldWidget.row.focusNode.removeListener(_handleFocusChange);
      widget.row.focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    widget.row.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (!widget.row.focusNode.hasFocus && !widget.row.isNew) {
      if (_mode != SubtaskTileDisplayMode.viewing && mounted) {
        setState(() => _mode = SubtaskTileDisplayMode.viewing);
      }
    }
  }

  void _switchToEditing() {
    setState(() => _mode = SubtaskTileDisplayMode.editing);
    widget.row.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDone = widget.row.status == TaskStatus.done;
    final isEditing =
        _mode == SubtaskTileDisplayMode.editing || widget.row.isNew;

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 复选框：方形圆角（22x22，圆角 6px）
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 10.0),
            child: SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: isDone,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: BorderSide(
                  color: isDone
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.34),
                  width: 1.5,
                ),
                activeColor: theme.colorScheme.onSurface,
                checkColor: theme.colorScheme.surface,
                onChanged: (_) => widget.onToggleStatus(),
              ),
            ),
          ),
          // 内容区：已完成子任务变灰并降低透明度（与任务浏览列表一致）。
          Expanded(
            child: AnimatedOpacity(
              opacity: isDone ? AppTokens.doneContentOpacity : 1.0,
              duration: motionFast(context),
              curve: motionCurve(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: isEditing
                        ? TextField(
                            controller: widget.row.controller,
                            focusNode: widget.row.focusNode,
                            maxLines: null,
                            scrollPadding: EdgeInsets.zero,
                            style: isDone
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  )
                                : theme.textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: l10n.subtaskHint,
                              border: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                            ),
                            onSubmitted: (_) => widget.onSubmitted(),
                            onChanged: (_) => widget.onChanged(),
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _switchToEditing,
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Text(
                                widget.row.controller.text.isEmpty
                                    ? l10n.subtaskHint
                                    : widget.row.controller.text,
                                style: widget.row.controller.text.isEmpty
                                    ? theme.textTheme.bodyMedium?.copyWith(
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      )
                                    : theme.textTheme.bodyMedium?.copyWith(
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isDone
                                            ? theme.colorScheme.onSurfaceVariant
                                            : null,
                                      ),
                              ),
                            ),
                          ),
                  ),
                  // 拖拽排序把手（无障碍：语义标签 + 扩大按压区，NFR-06）。
                  Semantics(
                    button: true,
                    label: l10n.dragReorder,
                    child: ReorderableDragStartListener(
                      index: widget.index,
                      child: const SizedBox(
                        width: AppTokens.touchTarget,
                        height: AppTokens.touchTarget,
                        child: Center(child: Icon(Icons.drag_handle, size: 18)),
                      ),
                    ),
                  ),
                  // 删除按钮（无障碍：扩大至 44dp 触控区）。
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: AppTokens.touchTarget,
                      minHeight: AppTokens.touchTarget,
                    ),
                    onPressed: widget.onRemove,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
