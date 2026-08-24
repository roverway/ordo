import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// 可供选择的预设图标列表（name -> IconData）。
const Map<String, IconData> kCustomViewIcons = {
  'dashboard_outlined': Icons.dashboard_outlined,
  'view_kanban_outlined': Icons.view_kanban_outlined,
  'view_column_outlined': Icons.view_column_outlined,
  'view_week_outlined': Icons.view_week_outlined,
  'filter_alt_outlined': Icons.filter_alt_outlined,
  'grid_view_outlined': Icons.grid_view_outlined,
  'star_outline': Icons.star_outline,
  'flag_outlined': Icons.flag_outlined,
  'checklist_outlined': Icons.checklist_outlined,
  'list_alt_outlined': Icons.list_alt_outlined,
  'label_outline': Icons.label_outline,
  'folder_outlined': Icons.folder_outlined,
  'layers_outlined': Icons.layers_outlined,
  'schedule_outlined': Icons.schedule_outlined,
  'bolt_outlined': Icons.bolt_outlined,
  'task_alt_outlined': Icons.task_alt_outlined,
};

/// 获取自定义视图 IconData（带容错）。
IconData getCustomViewIcon(String? name) {
  if (name == null || !kCustomViewIcons.containsKey(name)) {
    return Icons.dashboard_outlined;
  }
  return kCustomViewIcons[name]!;
}

/// 打开图标选择弹窗。
Future<String?> showCustomViewIconPicker(
  BuildContext context, {
  required String currentIcon,
  required int color,
}) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.viewIcon),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        ),
        content: SizedBox(
          width: 320,
          child: Wrap(
            spacing: AppTokens.spaceSm,
            runSpacing: AppTokens.spaceSm,
            alignment: WrapAlignment.center,
            children: kCustomViewIcons.entries.map((entry) {
              final isSelected = entry.key == currentIcon;
              return InkWell(
                onTap: () => Navigator.of(dialogContext).pop(entry.key),
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Color(color).withValues(alpha: 0.15)
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                    border: isSelected
                        ? Border.all(color: Color(color), width: 2)
                        : null,
                  ),
                  child: Icon(
                    entry.value,
                    color: isSelected
                        ? Color(color)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      );
    },
  );
}
