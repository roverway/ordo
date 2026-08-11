import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';

/// 标签视图（M0 骨架页，M3 实现标签 chip 网格与标签任务列表）。
class TagsPage extends StatelessWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppShell(
      title: l10n.navTags,
      child: EmptyState(icon: Icons.label_outline, message: l10n.emptyTags),
    );
  }
}
