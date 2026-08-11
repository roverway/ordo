import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';

/// Today view — shows tasks due today (stub, M3+ implementation).
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
