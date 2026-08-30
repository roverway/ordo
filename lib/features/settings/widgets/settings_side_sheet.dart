import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/modal_side_sheet.dart';
import '../../sync_setup/sync_setup_page.dart';
import '../../tags/tags_page.dart';
import '../settings_page.dart';

/// 宽屏（≥600dp）弹出右侧透明模态设置面板（Side Sheet）。
Future<void> showSettingsSideSheet(BuildContext context) {
  return showModalSideSheet(
    context: context,
    width: AppTokens.sideSheetWidth,
    child: Builder(
      builder: (sheetContext) => _SettingsSheetNavigator(
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    ),
  );
}

class _SettingsSheetNavigator extends StatefulWidget {
  const _SettingsSheetNavigator({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_SettingsSheetNavigator> createState() =>
      _SettingsSheetNavigatorState();
}

class _SettingsSheetNavigatorState extends State<_SettingsSheetNavigator> {
  bool _showingSync = false;
  bool _showingTags = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_showingSync) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.cancel,
            onPressed: () => setState(() => _showingSync = false),
          ),
          title: Text(l10n.syncSettings),
        ),
        body: const SyncSetupBody(),
      );
    }

    if (_showingTags) {
      return TagsPage(onBack: () => setState(() => _showingTags = false));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          onPressed: widget.onClose,
        ),
      ),
      body: SettingsBody(
        onOpenSync: () => setState(() => _showingSync = true),
        onOpenTags: () => setState(() => _showingTags = true),
      ),
    );
  }
}
