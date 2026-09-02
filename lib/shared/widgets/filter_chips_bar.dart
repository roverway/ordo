import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 任务状态筛选模式（全部 / 进行中 / 已完成）。
enum TaskFilterChipMode { all, open, done }

/// 现代极简风格的任务筛选 Chips 条 + 尾部内联搜索切换按钮。
///
/// 见于 `home.html` / `tasklist.html`。
class FilterChipsBar extends StatelessWidget {
  const FilterChipsBar({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    required this.allCount,
    required this.openCount,
    required this.doneCount,
    required this.isSearchOpen,
    required this.onToggleSearch,
  });

  final TaskFilterChipMode selectedMode;
  final ValueChanged<TaskFilterChipMode> onModeChanged;
  final int allCount;
  final int openCount;
  final int doneCount;
  final bool isSearchOpen;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _buildChip(
            context,
            mode: TaskFilterChipMode.all,
            label: '全部',
            count: allCount,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
            mode: TaskFilterChipMode.open,
            label: '进行中',
            count: openCount,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
            mode: TaskFilterChipMode.done,
            label: '已完成',
            count: doneCount,
          ),
          const Spacer(),
          // 搜索按钮
          InkWell(
            onTap: onToggleSearch,
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: AppTokens.motionFast,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSearchOpen
                    ? colorScheme.onSurface
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                Icons.search_rounded,
                size: 17,
                color: isSearchOpen
                    ? colorScheme.surface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required TaskFilterChipMode mode,
    required String label,
    required int count,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = selectedMode == mode;

    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: AppTokens.motionFast,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.onSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? colorScheme.onSurface
                : colorScheme.onSurface.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.surface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontFeatures: AppTokens.fontTabular,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? colorScheme.surface.withValues(alpha: 0.8)
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
