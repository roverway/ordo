import 'package:flutter/material.dart';

import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/priority_color.dart';
import '../../../shared/widgets/app_modal_sheet.dart';

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
  return showAppModalBottomSheet<TaskPriority>(
    context: context,
    builder: (sheetContext) => AppModalSheet(
      title: l10n.priority,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
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
