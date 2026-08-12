import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../sync_setup/sync_setup_providers.dart';
import 'settings_providers.dart';

/// App version (keep in sync with pubspec.yaml version, not translatable).
const String appVersion = '1.0.0';

/// Settings page: Appearance (theme/language) + About.
///
/// Theme mode (system/light/dark) and language (zh/en) switch instantly
/// and persist via SharedPreferences (FR-SET-01 / FR-SET-02).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    // 同步状态（全局 Notifier，仅内存）+ 当前配置（含持久化的 lastSyncedAt），
    // 供入口小图标/副标题展示；配置读取失败时回退灰色云朵，不影响设置页其余功能。
    final syncState = ref.watch(syncStateProvider);
    final syncConfigAsync = ref.watch(syncConfigProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          _SectionHeader(title: l10n.settingsSectionAppearance),
          _SettingsCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.themeMode, style: theme.textTheme.bodyLarge),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(l10n.themeModeSystem),
                        icon: const Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(l10n.themeModeLight),
                        icon: const Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(l10n.themeModeDark),
                        icon: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(selection.first),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.language, style: theme.textTheme.bodyLarge),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                  child: SegmentedButton<Locale>(
                    segments: [
                      ButtonSegment(
                        value: const Locale('zh'),
                        label: Text(l10n.languageZh),
                      ),
                      ButtonSegment(
                        value: const Locale('en'),
                        label: Text(l10n.languageEn),
                      ),
                    ],
                    selected: {locale},
                    onSelectionChanged: (selection) => ref
                        .read(localeProvider.notifier)
                        .setLocale(selection.first),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceXl),
          _SectionHeader(title: l10n.sync),
          _SettingsCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.syncSettings,
                  style: theme.textTheme.bodyLarge,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                  child: Text(
                    _syncStatusSubtitle(l10n, syncConfigAsync),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _syncStatusIcon(syncState, syncConfigAsync, colorScheme),
                    const SizedBox(width: AppTokens.spaceXs),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => context.go('/settings/sync'),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceXl),
          _SectionHeader(title: l10n.settingsSectionAbout),
          _SettingsCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.appTitle),
                subtitle: Text(
                  l10n.aboutVersion,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Text(
                  appVersion,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 同步入口副标题：有上次同步时间则显示，否则「尚未配置同步」。
  String _syncStatusSubtitle(
    AppLocalizations l10n,
    AsyncValue<SyncConfig> configAsync,
  ) {
    final lastSynced = configAsync.value?.lastSyncedAt;
    if (lastSynced != null) {
      return l10n.syncLastSyncedAt(formatDateTime(lastSynced));
    }
    return l10n.syncNotConfigured;
  }

  /// 同步入口状态小图标：error → 红色感叹；enabled 且最近成功 → 绿色勾；
  /// 未启用/读取失败 → 灰色云朵。
  Widget _syncStatusIcon(
    SyncState syncState,
    AsyncValue<SyncConfig> configAsync,
    ColorScheme colorScheme,
  ) {
    if (syncState.status == SyncStateStatus.error) {
      return Icon(Icons.error_outline, color: colorScheme.error, size: 22);
    }
    final config = configAsync.value;
    if (config != null && config.enabled && config.lastSyncedAt != null) {
      return const Icon(
        Icons.check_circle,
        color: AppTokens.colorDone,
        size: 22,
      );
    }
    return Icon(
      Icons.cloud_outlined,
      color: colorScheme.onSurfaceVariant,
      size: 22,
    );
  }
}

/// Settings section label.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceXs,
        vertical: AppTokens.spaceXs,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Card wrapper for a settings group.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(children: children),
      ),
    );
  }
}
