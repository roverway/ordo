import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';

/// 任务行快捷操作选单底部弹窗。
Future<void> showTaskRowActionsSheet({
  required BuildContext context,
  required int depth,
  required ValueChanged<String> onMenuAction,
}) {
  final l10n = AppLocalizations.of(context);
  final colorScheme = Theme.of(context).colorScheme;
  return showAppModalBottomSheet<void>(
    context: context,
    builder: (context) => AppModalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, size: 20),
            title: Text(l10n.edit),
            onTap: () {
              Navigator.pop(context);
              onMenuAction('edit');
            },
          ),
          if (depth < 2)
            ListTile(
              leading: const Icon(Icons.subdirectory_arrow_right, size: 20),
              title: Text(l10n.newSubtask),
              onTap: () {
                Navigator.pop(context);
                onMenuAction('newSubtask');
              },
            ),
          ListTile(
            leading: const Icon(Icons.arrow_upward, size: 20),
            title: Text(l10n.moveUp),
            onTap: () {
              Navigator.pop(context);
              onMenuAction('moveUp');
            },
          ),
          ListTile(
            leading: const Icon(Icons.arrow_downward, size: 20),
            title: Text(l10n.moveDown),
            onTap: () {
              Navigator.pop(context);
              onMenuAction('moveDown');
            },
          ),
          if (depth < 2)
            ListTile(
              leading: const Icon(Icons.arrow_right, size: 20),
              title: Text(l10n.indent),
              onTap: () {
                Navigator.pop(context);
                onMenuAction('indent');
              },
            ),
          if (depth > 0)
            ListTile(
              leading: const Icon(Icons.arrow_left, size: 20),
              title: Text(l10n.outdent),
              onTap: () {
                Navigator.pop(context);
                onMenuAction('outdent');
              },
            ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_outlined,
              size: 20,
              color: colorScheme.error,
            ),
            title: Text(
              l10n.delete,
              style: TextStyle(color: colorScheme.error),
            ),
            onTap: () {
              Navigator.pop(context);
              onMenuAction('delete');
            },
          ),
        ],
      ),
    ),
  );
}
