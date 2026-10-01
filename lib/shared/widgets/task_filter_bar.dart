// 筛选条（FR-VIEW-06）：状态筛选 + 标签筛选 + 时间段筛选 + 清除按钮。
//
// 遵循 Linear 风格极致工业质感与乔布斯无冗余交互哲学：
// - 精致紧凑的极简胶囊药丸（filterChipHeight = 28dp）；
// - 未激活态微透边框卡片，激活态微光品牌色罩染与高亮描边；
// - 下拉浮动菜单采用 Linear 紧凑卡片、圆角、极细微边框与打勾状态。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/search/search_providers.dart';

/// Linear 风格精致筛选条（FR-VIEW-06）。
class TaskFilterBar extends StatelessWidget {
  const TaskFilterBar({
    super.key,
    required this.status,
    required this.tagId,
    required this.range,
    required this.tags,
    this.sortPrinciple,
    this.onSortChanged,
    required this.onStatusChanged,
    required this.onTagChanged,
    required this.onTimeRangeChanged,
    required this.onClear,
  });

  /// 当前状态筛选（null = 全部）。
  final TaskStatus? status;

  /// 当前标签筛选（null = 全部标签）。
  final String? tagId;

  /// 当前时间段筛选。
  final TimeRange range;

  /// 全部标签（下拉选项，调用方解析）。
  final List<Tag> tags;

  /// 排序原则。
  final SearchSortPrinciple? sortPrinciple;

  /// 排序原则变更回调。
  final ValueChanged<SearchSortPrinciple>? onSortChanged;

  /// 状态筛选回调（null 表示「全部」）。
  final ValueChanged<TaskStatus?> onStatusChanged;

  /// 标签筛选回调（null 表示「全部标签」）。
  final ValueChanged<String?> onTagChanged;

  /// 时间段筛选回调。
  final ValueChanged<TimeRange> onTimeRangeChanged;

  /// 清除全部筛选。
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final anyActive = status != null || tagId != null || range != TimeRange.all;

    // 防御：tagId 指向已删除/不存在的标签时回退「全部」。
    final selectedTag = tags.where((t) => t.id == tagId).firstOrNull;
    final validTagId = selectedTag != null ? tagId : null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceXs,
      ),
      child: Row(
        children: [
          // 状态筛选
          _LinearFilterChip<TaskStatus?>(
            label: l10n.filterStatus,
            value: status,
            isActive: status != null,
            selectedText: status != null ? _statusLabel(l10n, status!) : null,
            entries: [
              MapEntry(null, l10n.filterAll),
              for (final s in TaskStatus.values)
                MapEntry(s, _statusLabel(l10n, s)),
            ],
            onChanged: onStatusChanged,
          ),
          const SizedBox(width: AppTokens.spaceXs),

          // 标签筛选
          _LinearFilterChip<String?>(
            label: l10n.filterTag,
            value: validTagId,
            isActive: validTagId != null,
            selectedText: selectedTag?.name,
            entries: [
              MapEntry(null, l10n.filterAll),
              for (final tag in tags) MapEntry(tag.id, tag.name),
            ],
            onChanged: onTagChanged,
          ),
          const SizedBox(width: AppTokens.spaceXs),

          // 时间段筛选
          _LinearFilterChip<TimeRange>(
            label: l10n.filterTimeRange,
            value: range,
            isActive: range != TimeRange.all,
            selectedText: range != TimeRange.all
                ? _timeRangeLabel(l10n, range)
                : null,
            entries: [
              for (final r in TimeRange.values)
                MapEntry(r, _timeRangeLabel(l10n, r)),
            ],
            onChanged: (value) {
              if (value != null) onTimeRangeChanged(value);
            },
          ),
          if (sortPrinciple != null && onSortChanged != null) ...[
            const SizedBox(width: AppTokens.spaceXs),
            _LinearFilterChip<SearchSortPrinciple>(
              label: l10n.localeName == 'zh' ? '排序' : 'Sort',
              value: sortPrinciple,
              isActive: sortPrinciple != SearchSortPrinciple.dueDate,
              selectedText: _sortLabel(l10n, sortPrinciple!),
              entries: [
                MapEntry(
                  SearchSortPrinciple.dueDate,
                  l10n.localeName == 'zh' ? '按截止时间' : 'Due Date',
                ),
                MapEntry(
                  SearchSortPrinciple.priority,
                  l10n.localeName == 'zh' ? '按优先级' : 'Priority',
                ),
                MapEntry(
                  SearchSortPrinciple.createdAt,
                  l10n.localeName == 'zh' ? '按创建时间' : 'Created Date',
                ),
                MapEntry(
                  SearchSortPrinciple.title,
                  l10n.localeName == 'zh' ? '按标题' : 'Title',
                ),
              ],
              onChanged: (val) {
                if (val != null) onSortChanged!(val);
              },
            ),
          ],

          // 清除全部激活筛选的小药丸
          if (anyActive) ...[
            const SizedBox(width: AppTokens.spaceXs),
            _ClearFilterChip(onClear: onClear, label: l10n.clearFilter),
          ],
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, TaskStatus s) => switch (s) {
    TaskStatus.todo => l10n.statusTodo,
    TaskStatus.inProgress => l10n.statusInProgress,
    TaskStatus.done => l10n.statusDone,
    TaskStatus.cancelled => l10n.statusCancelled,
  };

  String _timeRangeLabel(AppLocalizations l10n, TimeRange r) => switch (r) {
    TimeRange.all => l10n.timeRangeAll,
    TimeRange.today => l10n.timeRangeToday,
    TimeRange.week => l10n.timeRangeThisWeek,
    TimeRange.month => l10n.timeRangeThisMonth,
  };

  String _sortLabel(AppLocalizations l10n, SearchSortPrinciple s) =>
      switch (s) {
        SearchSortPrinciple.dueDate =>
          l10n.localeName == 'zh' ? '按截止时间' : 'Due Date',
        SearchSortPrinciple.priority =>
          l10n.localeName == 'zh' ? '按优先级' : 'Priority',
        SearchSortPrinciple.createdAt =>
          l10n.localeName == 'zh' ? '按创建时间' : 'Created Date',
        SearchSortPrinciple.title => l10n.localeName == 'zh' ? '按标题' : 'Title',
      };
}

/// Linear 风格紧凑筛选药丸。
class _LinearFilterChip<T> extends StatelessWidget {
  const _LinearFilterChip({
    required this.label,
    required this.value,
    required this.isActive,
    required this.selectedText,
    required this.entries,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final bool isActive;
  final String? selectedText;
  final List<MapEntry<T?, String>> entries;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isActive
        ? colorScheme.primary.withValues(alpha: AppTokens.alphaBorderEmphasis)
        : (isDark ? AppTokens.borderSubtleDark : AppTokens.borderSubtleLight);

    final bgColor = isActive
        ? colorScheme.primary.withValues(alpha: AppTokens.alphaTintFaint)
        : (isDark
              ? AppTokens.surfaceCardDark.withValues(
                  alpha: AppTokens.alphaCardFrostedDark,
                )
              : AppTokens.surfaceCardLight.withValues(
                  alpha: AppTokens.alphaCardFrostedLight,
                ));

    final textColor = isActive
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Theme(
      data: theme.copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: isDark
              ? AppTokens.surfaceCardDark
              : AppTokens.surfaceCardLight,
          surfaceTintColor: Colors.transparent,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            side: BorderSide(
              color: isDark
                  ? AppTokens.borderSubtleDark
                  : AppTokens.borderSubtleLight,
              width: 1,
            ),
          ),
        ),
      ),
      child: PopupMenuButton<T?>(
        position: PopupMenuPosition.under,
        offset: const Offset(0, 4),
        onSelected: (val) {
          HapticFeedback.selectionClick();
          onChanged(val);
        },
        itemBuilder: (context) => [
          for (final entry in entries)
            PopupMenuItem<T?>(
              value: entry.key,
              height: AppTokens.filterMenuItemHeight,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: AppTokens.textSecondarySize,
                        fontWeight: entry.key == value
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: entry.key == value
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (entry.key == value) ...[
                    const SizedBox(width: AppTokens.spaceXs),
                    Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
        ],
        child: AnimatedContainer(
          duration: AppTokens.motionFast,
          height: AppTokens.filterChipHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTokens.textCaptionSize,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              if (selectedText != null) ...[
                Text(
                  ': ',
                  style: TextStyle(
                    fontSize: AppTokens.textCaptionSize,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                Text(
                  selectedText!,
                  style: TextStyle(
                    fontSize: AppTokens.textCaptionSize,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ],
              const SizedBox(width: AppTokens.spaceXxs),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: textColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linear 风格清除筛选按钮。
class _ClearFilterChip extends StatelessWidget {
  const _ClearFilterChip({required this.onClear, required this.label});

  final VoidCallback onClear;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      onTap: () {
        HapticFeedback.lightImpact();
        onClear();
      },
      child: Container(
        height: AppTokens.filterChipHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(
            alpha: AppTokens.alphaTintSoft,
          ),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.close_rounded,
              size: 12,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppTokens.spaceXxs),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
