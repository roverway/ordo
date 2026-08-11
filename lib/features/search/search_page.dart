import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/empty_state.dart';

/// 搜索页（M0 占位页，M3 实现搜索框 + 结果列表）。
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
