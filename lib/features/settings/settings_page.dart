import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../features/sync_setup/sync_setup_providers.dart';
import '../../features/tags/tag_providers.dart';
import '../../shared/widgets/app_background_wrapper.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/modern_segmented_control.dart';
import 'settings_providers.dart';
import 'widgets/backup_section.dart';
import 'widgets/wallpaper_picker_sheet.dart';

const String appVersion = '1.0.0';

/// 现代极简设置页面（完全复刻 `待办应用改版设计/screens/settings.html` 设计规范）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return AppBackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            l10n.settings,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: AppTokens.textTitleSize,
            ),
          ),
          centerTitle: false,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: SettingsBody(
              onOpenSync: () => context.push('/settings/sync'),
              onOpenTags: () => context.push('/tags'),
              onOpenHelp: () => context.push('/settings/help'),
            ),
          ),
        ),
      ),
    );
  }
}

/// 侧边栏/浮层内嵌使用的设置抽屉（桌面端大屏右侧展开或弹窗）。
class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Drawer(
      width: 440,
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
                vertical: AppTokens.spaceXs,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  Text(
                    l10n.settings,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SettingsBody(
                onOpenSync: () => context.push('/settings/sync'),
                onOpenTags: () => context.push('/tags'),
                onOpenHelp: () => context.push('/settings/help'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置列表主内容（支持独立页面及宽屏内嵌复用）。
class SettingsBody extends StatelessWidget {
  const SettingsBody({
    super.key,
    required this.onOpenSync,
    required this.onOpenTags,
    this.onOpenHelp,
  });

  final VoidCallback onOpenSync;
  final VoidCallback onOpenTags;
  final VoidCallback? onOpenHelp;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ── 1. 外观 ──
        const _AppearanceSection(),
        const SizedBox(height: 20),

        // ── 2. 数据与标签 ──
        _TagsSection(onOpenTags: onOpenTags),
        const SizedBox(height: 20),

        // ── 3. 日历 ──
        const _CalendarSection(),
        const SizedBox(height: 20),

        // ── 4. 同步 ──
        _SyncSection(onOpenSync: onOpenSync),
        const SizedBox(height: 20),

        // ── 5. 数据导入导出与安全备份 ──
        const BackupSection(),
        const SizedBox(height: 20),

        // ── 6. 使用帮助 ──
        _HelpSection(onOpenHelp: onOpenHelp),
        const SizedBox(height: 20),

        // ── 7. 关于 ──
        const _AboutSection(),
      ],
    );
  }
}

/// 外观配置卡片（主题模式、主题色、语言、全局背景）
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.settingsSectionAppearance),
        _SettingsCard(
          children: [
            // 主题模式标题行
            Row(
              children: [
                _IconBadge(
                  icon: themeMode == ThemeMode.dark
                      ? Icons.dark_mode_outlined
                      : Icons.wb_sunny_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.themeMode,
                        style: const TextStyle(
                          fontSize: AppTokens.textBodySize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        switch (themeMode) {
                          ThemeMode.system => l10n.themeModeSystem,
                          ThemeMode.light => l10n.themeModeLight,
                          ThemeMode.dark => l10n.themeModeDark,
                        },
                        style: TextStyle(
                          fontSize: AppTokens.textCaptionSize,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 主题模式胶囊切换器 (跟随系统 / 浅色 / 深色)
            ModernSegmentedControl<ThemeMode>(
              selectedValue: themeMode,
              indicatorColor: colorScheme.primary,
              selectedTextColor: colorScheme.onPrimary,
              onChanged: (val) =>
                  ref.read(themeModeProvider.notifier).setThemeMode(val),
              items: [
                ModernSegmentItem(
                  value: ThemeMode.system,
                  label: l10n.themeModeSystem,
                  icon: Icons.brightness_auto_outlined,
                ),
                ModernSegmentItem(
                  value: ThemeMode.light,
                  label: l10n.themeModeLight,
                  icon: Icons.light_mode_outlined,
                ),
                ModernSegmentItem(
                  value: ThemeMode.dark,
                  label: l10n.themeModeDark,
                  icon: Icons.dark_mode_outlined,
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 主题色选择标题行
            Row(
              children: [
                _IconBadge(
                  icon: Icons.palette_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.themeColor,
                        style: const TextStyle(
                          fontSize: AppTokens.textBodySize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.seedColorSubtitle,
                        style: TextStyle(
                          fontSize: AppTokens.textCaptionSize,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 8 色双环光晕色板
            const _ThemeColorPicker(),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 全局背景壁纸行
            const _GlobalWallpaperRow(),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 语言选择行
            Row(
              children: [
                _IconBadge(icon: Icons.language, color: colorScheme.primary),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.language,
                        style: const TextStyle(
                          fontSize: AppTokens.textBodySize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locale.languageCode == 'zh'
                            ? l10n.languageZh
                            : l10n.languageEn,
                        style: TextStyle(
                          fontSize: AppTokens.textCaptionSize,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ModernSegmentedControl<Locale>(
                  isExpanded: false,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 14),
                  selectedValue: locale.languageCode == 'en'
                      ? const Locale('en')
                      : const Locale('zh'),
                  indicatorColor: colorScheme.primary,
                  selectedTextColor: colorScheme.onPrimary,
                  onChanged: (val) =>
                      ref.read(localeProvider.notifier).setLocale(val),
                  items: [
                    ModernSegmentItem(
                      value: const Locale('zh'),
                      label: l10n.languageZh,
                    ),
                    ModernSegmentItem(
                      value: const Locale('en'),
                      label: l10n.languageEn,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// 全局背景壁纸设置行
class _GlobalWallpaperRow extends ConsumerWidget {
  const _GlobalWallpaperRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final appBgConfig = ref.watch(appBackgroundConfigProvider);

    return InkWell(
      onTap: () async {
        final result = await showWallpaperPickerSheet(
          context: context,
          initialConfig: appBgConfig,
          isGlobal: true,
        );
        if (result != null) {
          await ref
              .read(appBackgroundConfigProvider.notifier)
              .setConfig(result);
        }
      },
      borderRadius: BorderRadius.circular(AppTokens.radiusList),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _IconBadge(
              icon: Icons.wallpaper_outlined,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.wallpaperTitleApp,
                    style: const TextStyle(
                      fontSize: AppTokens.textBodySize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    appBgConfig.isEffective
                        ? l10n.wallpaperActive
                        : l10n.wallpaperDefaultPure,
                    style: TextStyle(
                      fontSize: AppTokens.textCaptionSize,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            WallpaperThumbnail(
              config: appBgConfig,
              width: 38,
              height: 38,
              borderRadius: AppTokens.radiusChip,
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colorScheme.onSurfaceVariant.withValues(
                alpha: AppTokens.alphaContentMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 标签管理入口卡片
class _TagsSection extends ConsumerWidget {
  const _TagsSection({required this.onOpenTags});

  final VoidCallback onOpenTags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tagsAsync = ref.watch(tagsStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.taskTags),
        _SettingsCard(
          padding: EdgeInsets.zero,
          children: [
            InkWell(
              onTap: onOpenTags,
              borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _IconBadge(
                      icon: Icons.local_offer_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.taskTags,
                            style: const TextStyle(
                              fontSize: AppTokens.textBodySize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tagsAsync.hasValue
                                ? ((tagsAsync.value?.isEmpty ?? true)
                                      ? l10n.emptyTags
                                      : l10n.manageTagsSubtitle(
                                          tagsAsync.value!.length,
                                        ))
                                : l10n.emptyTags,
                            style: TextStyle(
                              fontSize: AppTokens.textCaptionSize,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: AppTokens.alphaContentMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 日历配置卡片（农历、法定假日）
class _CalendarSection extends ConsumerWidget {
  const _CalendarSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final showLunar = ref.watch(calendarShowLunarProvider);
    final showHolidays = ref.watch(calendarShowHolidaysProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.settingsSectionCalendar),
        _SettingsCard(
          children: [
            // 中国农历开关
            Row(
              children: [
                _IconBadge(
                  icon: Icons.calendar_month_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.showLunar,
                        style: const TextStyle(
                          fontSize: AppTokens.textBodySize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.showLunarSubtitle,
                        style: TextStyle(
                          fontSize: AppTokens.textCaptionSize,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: showLunar,
                  onChanged: (val) => ref
                      .read(calendarShowLunarProvider.notifier)
                      .setShowLunar(val),
                ),
              ],
            ),
            const Divider(height: 24),
            // 中国法定节假日及调休开关
            Row(
              children: [
                _IconBadge(
                  icon: Icons.event_available_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.showHolidays,
                        style: const TextStyle(
                          fontSize: AppTokens.textBodySize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.showHolidaysSubtitle,
                        style: TextStyle(
                          fontSize: AppTokens.textCaptionSize,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: showHolidays,
                  onChanged: (val) => ref
                      .read(calendarShowHolidaysProvider.notifier)
                      .setShowHolidays(val),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// 同步配置卡片
class _SyncSection extends ConsumerWidget {
  const _SyncSection({required this.onOpenSync});

  final VoidCallback onOpenSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final syncState = ref.watch(syncStateProvider);
    final syncConfigAsync = ref.watch(syncConfigProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.sync),
        _SettingsCard(
          padding: EdgeInsets.zero,
          children: [
            InkWell(
              onTap: onOpenSync,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTokens.radiusDialog),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _IconBadge(
                      icon: Icons.cloud_sync_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                l10n.syncSettings,
                                style: const TextStyle(
                                  fontSize: AppTokens.textBodySize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildSyncStatusBadge(
                                l10n,
                                colorScheme,
                                syncState.status,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatSyncSubtitle(
                              l10n,
                              syncState,
                              syncConfigAsync.value,
                            ),
                            style: TextStyle(
                              fontSize: AppTokens.textCaptionSize,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: AppTokens.alphaContentMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.syncAutoOnStart,
                      style: const TextStyle(
                        fontSize: AppTokens.textBodySize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.88,
                    child: Switch(
                      activeTrackColor: colorScheme.primary,
                      activeThumbColor: colorScheme.onPrimary,
                      value: syncConfigAsync.value?.autoOnStart == true,
                      onChanged: (val) async {
                        final config = syncConfigAsync.value;
                        if (config != null) {
                          await saveSyncConfig(
                            ref,
                            config.copyWith(autoOnStart: val),
                          );
                          ref.invalidate(syncConfigProvider);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncStatusBadge(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    SyncStateStatus status,
  ) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case SyncStateStatus.syncing:
        bg = colorScheme.primary.withValues(alpha: AppTokens.alphaBorderSubtle);
        fg = colorScheme.primary;
        label = l10n.syncStatusSyncing;
        icon = Icons.sync;
      case SyncStateStatus.success:
        bg = AppTokens.colorSuccess.withValues(
          alpha: AppTokens.alphaBorderSubtle,
        );
        fg = AppTokens.colorSuccessText;
        label = l10n.syncStatusSuccess;
        icon = Icons.check_circle_outline;
      case SyncStateStatus.error:
        bg = AppTokens.colorDanger.withValues(
          alpha: AppTokens.alphaBorderSubtle,
        );
        fg = AppTokens.colorDangerText;
        label = l10n.syncStatusError;
        icon = Icons.error_outline;
      case SyncStateStatus.idle:
        bg = colorScheme.onSurfaceVariant.withValues(
          alpha: AppTokens.alphaBorderSubtle,
        );
        fg = colorScheme.onSurfaceVariant;
        label = l10n.syncStatusIdle;
        icon = Icons.cloud_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTokens.textMicroSize,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSyncSubtitle(
    AppLocalizations l10n,
    SyncState syncState,
    SyncConfig? config,
  ) {
    if (config == null || !config.enabled) {
      return l10n.syncNotConfigured;
    }
    final target = config.type == RemoteType.webdav
        ? l10n.syncTypeNutstore
        : l10n.syncTypeS3;
    if (syncState.status == SyncStateStatus.syncing) {
      return '$target · ${l10n.syncStatusSyncing}';
    }
    if (syncState.lastSyncedAt != null) {
      final timeStr = formatDateTime(syncState.lastSyncedAt!);
      return '$target · ${l10n.syncLastSyncedAt(timeStr)}';
    }
    return target;
  }
}

/// 使用帮助卡片
class _HelpSection extends StatelessWidget {
  const _HelpSection({this.onOpenHelp});

  final VoidCallback? onOpenHelp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.settingsHelp),
        _SettingsCard(
          padding: EdgeInsets.zero,
          children: [
            InkWell(
              onTap: () {
                if (onOpenHelp != null) {
                  onOpenHelp!();
                } else {
                  context.push('/settings/help');
                }
              },
              borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _IconBadge(
                      icon: Icons.menu_book_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsHelp,
                            style: const TextStyle(
                              fontSize: AppTokens.textBodySize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.settingsHelpSubtitle,
                            style: TextStyle(
                              fontSize: AppTokens.textCaptionSize,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: AppTokens.alphaContentMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 关于应用卡片（独立无状态组件）
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.settingsSectionAbout),
        _SettingsCard(
          children: [
            Row(
              children: [
                const AppLogo(size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: const TextStyle(
                          fontSize: AppTokens.textSubtitleSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${l10n.aboutVersion} v$appVersion',
                        style: TextStyle(
                          fontSize: AppTokens.textCaptionSize,
                          fontFeatures: AppTokens.fontTabular,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Slogan 引用框
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
                vertical: AppTokens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(
                  alpha: AppTokens.alphaTintFaint,
                ),
                borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                border: Border.all(
                  color: colorScheme.primary.withValues(
                    alpha: AppTokens.alphaTintStrong,
                  ),
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
          ],
        ),
      ],
    );
  }
}

/// 分组小标题（全大写微字号、加宽字距，完全对齐原型 .scap）。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: AppTokens.textSectionLabelSize,
          fontWeight: AppTokens.textSectionLabelWeight,
          letterSpacing: AppTokens.textSectionLabelLetterSpacing,
          color: isDark
              ? AppTokens.checkboxDisabledFgDark
              : AppTokens.checkboxDisabledFgLight,
        ),
      ),
    );
  }
}

/// 圆角卡片容器（对齐原型中的 .card 视觉规范，当存在壁纸时自动启用半透明与磨砂毛玻璃）。
class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasWallpaper = ref.watch(appBackgroundConfigProvider).isEffective;

    final baseCardColor = isDark
        ? AppTokens.surfaceCardDark
        : AppTokens.surfaceCardLight;
    final cardColor = hasWallpaper
        ? baseCardColor.withValues(
            alpha: isDark
                ? AppTokens.alphaCardFrostedDark
                : AppTokens.alphaCardFrostedLight,
          )
        : baseCardColor;

    final borderColor = isDark
        ? Colors.white.withValues(
            alpha: hasWallpaper
                ? AppTokens.alphaTintStrong
                : AppTokens.alphaTintFaint,
          )
        : Colors.black.withValues(
            alpha: hasWallpaper
                ? AppTokens.alphaTintSoft
                : AppTokens.alphaTintFaint,
          );

    if (hasWallpaper) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark
                    ? AppTokens.alphaBorderEmphasis
                    : AppTokens.alphaTintFaint,
              ),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppTokens.blurFrostedGlass,
              sigmaY: AppTokens.blurFrostedGlass,
            ),
            child: Material(
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
                side: BorderSide(color: borderColor, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark
                  ? AppTokens.alphaBorderEmphasis
                  : AppTokens.alphaTintFaint,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
          side: BorderSide(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// 彩色图标徽标（32x32，圆角 9dp，微透明底色）。
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: AppTokens.alphaBorderSubtle),
        borderRadius: BorderRadius.circular(AppTokens.radiusList),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 17, color: effectiveColor),
    );
  }
}

/// 主题色双环光晕选择器（8色网格，完全复刻 .c-opt 双环选中态，采用全应用统一主题色体系）。
class _ThemeColorPicker extends ConsumerWidget {
  const _ThemeColorPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSeed = ref.watch(themeSeedColorProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: AppTokens.themePalettes.map((palette) {
        final color = palette.color;
        final isSelected = color.toARGB32() == currentSeed.toARGB32();
        final name = palette.localizedName(context);

        return Tooltip(
          message: name,
          child: InkWell(
            onTap: () =>
                ref.read(themeSeedColorProvider.notifier).setSeedColor(color),
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            child: Container(
              width: 28,
              height: 28,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: color, width: 2) : null,
              ),
              child: Container(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 品牌内涵图文单元
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
        Icon(Icons.auto_awesome, size: 16, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppTokens.textCaptionSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: AppTokens.textMicroSize,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
