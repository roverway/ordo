import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';

/// 项目列表视图（M0 骨架页，M2 实现项目卡片与任务树）。
class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppShell(
      title: l10n.navProjects,
      child: EmptyState(
        icon: Icons.folder_outlined,
        message: l10n.emptyProjects,
      ),
    );
  }
}
