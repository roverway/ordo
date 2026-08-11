import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';

/// Tags view — stubbed for M3+ (tag chip grid + tag task list).
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
