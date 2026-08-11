import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';

/// 日历视图（M0 骨架页，M3 实现月/周视图）。
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppShell(
      title: l10n.navCalendar,
      child: EmptyState(
        icon: Icons.calendar_today_outlined,
        message: l10n.emptyCalendar,
      ),
    );
  }
}
