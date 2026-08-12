import 'package:flutter/material.dart';

import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// 优先级旗帜颜色（滴答式 红/橙/蓝/无，55-ui-redesign §4.1）。
///
/// 「无」用中性灰（[AppTokens.colorCancelled]）而非透明——顶部栏旗帜在无优先级时
/// 仍需可见可点（滴答清单为灰色旗帜），避免图标隐形导致入口丢失。
Color priorityColor(TaskPriority priority) => switch (priority) {
  TaskPriority.high => AppTokens.colorPriorityHigh,
  TaskPriority.medium => AppTokens.colorPriorityMedium,
  TaskPriority.low => AppTokens.colorPriorityLow,
  TaskPriority.none => AppTokens.colorCancelled,
};

/// 优先级本地化名称。
String priorityLabel(AppLocalizations l10n, TaskPriority priority) =>
    switch (priority) {
      TaskPriority.high => l10n.priorityHigh,
      TaskPriority.medium => l10n.priorityMedium,
      TaskPriority.low => l10n.priorityLow,
      TaskPriority.none => l10n.priorityNone,
    };

/// 底部弹层优先级选择器（新建弹窗/编辑页共用）。
///
/// 滴答式 4 档：高（红）/中（橙）/低（蓝）/无；当前项蓝色对勾。
Future<TaskPriority?> showPriorityPicker(
  BuildContext context, {
  required TaskPriority current,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<TaskPriority>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppTokens.spaceXs),
          ListTile(
            title: Text(
              l10n.priority,
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                fontWeight: AppTokens.textTitleWeight,
              ),
            ),
          ),
          const Divider(),
          for (final p in TaskPriority.values)
            ListTile(
              leading: Icon(
                Icons.flag_outlined,
                size: 20,
                color: priorityColor(p),
              ),
              title: Text(priorityLabel(l10n, p)),
              trailing: p == current
                  ? const Icon(
                      Icons.check,
                      size: 20,
                      color: AppTokens.colorInProgress,
                    )
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(p),
            ),
          const SizedBox(height: AppTokens.spaceXs),
        ],
      ),
    ),
  );
}
