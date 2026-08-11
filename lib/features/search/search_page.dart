import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/empty_state.dart';

/// Search page — stubbed for M3+ (search bar + result list).
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.search)),
      body: EmptyState(icon: Icons.search, message: l10n.emptySearch),
    );
  }
}
