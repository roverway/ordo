import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';

/// 今日视图（M0 骨架页，M3 实现任务分组/逾期标红等）。
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppShell(
      title: l10n.navToday,
      child: EmptyState(icon: Icons.today_outlined, message: l10n.emptyToday),
    );
  }
}
