// 筛选条（FR-VIEW-06）：状态筛选 + 标签筛选 + 时间段筛选 + 清除按钮。
//
// 横向可滚动紧凑筛选组合；任一筛选条件激活时显示「清除」（clearFilter）。
// 本组件仅搜索页使用（M3 无其他调用方）；不感知 Provider，参数由调用方传入
// （当前筛选状态 + 全部标签 + 回调）。全部颜色/圆角/间距使用 AppTokens。

import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/search/search_providers.dart';
import 'app_menu_item.dart';

/// 筛选条（FR-VIEW-06）。
class TaskFilterBar extends StatelessWidget {
  const TaskFilterBar({
    super.key,
    required this.status,
    required this.tagId,
    required this.range,
    required this.tags,
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceXs,
      ),
      child: Row(
        children: [
          _FilterDropdown(
            label: l10n.filterStatus,
            child: _FilterMenu<TaskStatus?>(
              value: status,
              entries: [
                MapEntry(null, l10n.filterAll),
                for (final s in TaskStatus.values)
                  MapEntry(s, _statusLabel(l10n, s)),
              ],
              onChanged: onStatusChanged,
            ),
          ),
          _FilterDropdown(
            label: l10n.filterTag,
            child: _FilterMenu<String?>(
              // 防御：tagId 指向已删除/不存在的标签时回退「全部」。
              value: tags.any((t) => t.id == tagId) ? tagId : null,
              entries: [
                MapEntry(null, l10n.filterAll),
                for (final tag in tags) MapEntry(tag.id, tag.name),
              ],
              onChanged: onTagChanged,
            ),
          ),
          _FilterDropdown(
            label: l10n.filterTimeRange,
            child: _FilterMenu<TimeRange>(
              value: range,
              entries: [
                for (final r in TimeRange.values)
                  MapEntry(r, _timeRangeLabel(l10n, r)),
              ],
              onChanged: (value) {
                if (value != null) onTimeRangeChanged(value);
              },
            ),
          ),
          if (anyActive)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: Text(l10n.clearFilter),
            ),
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
}

/// 筛选弹出菜单（用户打磨 2026-08：与全局三点菜单同规格紧凑化）。
///
/// 替代 DropdownButton——后者的菜单项（48 高、默认文本样式）不受
/// popupMenuTheme 管辖；本组件菜单项走共享 [AppMenuItem]（高 40 /
/// bodyMedium，容器圆角/描边/底色/内边距由 popupMenuTheme 统一），当前
/// 选中项带 check 图标；触发区显示选中项文字 + 下拉箭头。
class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.value,
    required this.entries,
    required this.onChanged,
  });

  /// 当前选中值（与 [entries] 的 key 比较）。
  final T? value;

  /// 可选项（值 + 文案），首项通常为「全部」。
  final List<MapEntry<T?, String>> entries;

  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedLabel = entries
        .firstWhere((e) => e.key == value, orElse: () => entries.first)
        .value;
    return PopupMenuButton<T>(
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppTokens.spaceXxs),
            child: Text(selectedLabel, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: AppTokens.spaceXxs),
          Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      itemBuilder: (_) => [
        for (final entry in entries)
          AppMenuItem<T>(
            value: entry.key,
            label: entry.value,
            icon: entry.key == value ? Icons.check : null,
          ),
      ],
    );
  }
}

/// 单个筛选下拉的容器（标签 + 下拉，chip 化外观）。
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: AppTokens.spaceXs),
      padding: const EdgeInsets.only(left: AppTokens.spaceSm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: AppTokens.alphaContentMuted),
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
