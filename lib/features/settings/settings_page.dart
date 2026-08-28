import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/desktop_hover_container.dart';
import '../sync_setup/sync_setup_providers.dart';
import 'settings_providers.dart';

/// App version (keep in sync with pubspec.yaml version, not translatable).
const String appVersion = '1.0.0';

/// Settings page: Appearance (theme/language) + About.
///
/// Theme mode (system/light/dark) and language (zh/en) switch instantly
/// and persist via the Drift settings table (docs/64-local-preferences.md).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SettingsBody(onOpenSync: () => context.push('/settings/sync')),
    );
  }
}

/// 设置列表主内容（支持独立页面及宽屏模态侧边抽屉内嵌复用）。
class SettingsBody extends ConsumerWidget {
  const SettingsBody({super.key, required this.onOpenSync});

  final VoidCallback onOpenSync;

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

    return ListView(
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
              title: Text(l10n.syncSettings, style: theme.textTheme.bodyLarge),
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
                  _syncStatusIcon(
                    context,
                    syncState,
                    syncConfigAsync,
                    colorScheme,
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  const Icon(Icons.chevron_right),
                ],
              ),
              // 用 push 而非 go：go('/settings/sync') 会把整个导航栈替换为
              // [settings, sync]，丢掉了进入设置前的任务页（/today 等），
              // 导致从设置页无法返回 —— 用户实测 bug。push 保留完整栈
              // [任务页, settings, sync]，返回箭头一路可用。
              onTap: onOpenSync,
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceXl),
        _SectionHeader(title: l10n.settingsSectionAbout),
        _SettingsCard(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const AppLogo(size: 40),
              title: Text(
                l10n.appTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${l10n.aboutVersion} $appVersion',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
                vertical: AppTokens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  '“${l10n.aboutSlogan}”',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            _BrandMeaningItem(
              title: l10n.aboutBrandZhTitle,
              description: l10n.aboutBrandZhDesc,
            ),
            const SizedBox(height: AppTokens.spaceXs),
            _BrandMeaningItem(
              title: l10n.aboutBrandEnTitle,
              description: l10n.aboutBrandEnDesc,
            ),
          ],
        ),
      ],
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
  /// 未启用/读取失败 → 灰色云朵。无障碍：纯图标补语义标签（NFR-06）。
  Widget _syncStatusIcon(
    BuildContext context,
    SyncState syncState,
    AsyncValue<SyncConfig> configAsync,
    ColorScheme colorScheme,
  ) {
    final (icon, label) = switch (syncState.status) {
      SyncStateStatus.error => (
        Icon(Icons.error_outline, color: colorScheme.error, size: 22),
        AppLocalizations.of(context).syncStatusError,
      ),
      _
          when configAsync.value?.enabled == true &&
              configAsync.value?.lastSyncedAt != null =>
        (
          const Icon(Icons.check_circle, color: AppTokens.colorDone, size: 22),
          AppLocalizations.of(context).syncStatusSuccess,
        ),
      _ => (
        Icon(
          Icons.cloud_outlined,
          color: colorScheme.onSurfaceVariant,
          size: 22,
        ),
        AppLocalizations.of(context).syncStatusIdle,
      ),
    };
    return Semantics(label: label, child: icon);
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
///
/// 66 号外观升级：与任务卡/项目卡统一为「细边框 + 双层弥散阴影」的
/// [DesktopHoverContainer] 语言，替代全局 Material Card 的 elevation 观感。
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DesktopHoverContainer(
      enableHover: false,
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      child: Column(children: children),
    );
  }
}

/// 品牌寓意展示行。
class _BrandMeaningItem extends StatelessWidget {
  const _BrandMeaningItem({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppTokens.spaceSm),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: '$title：',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
