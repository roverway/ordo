import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';

/// Calendar view — stubbed for M3+ (month/week views).
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
