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
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/modern_segmented_control.dart';
import 'settings_providers.dart';
import 'widgets/backup_section.dart';

const String appVersion = '1.0.0';

/// 现代极简设置页面（完全复刻 `待办应用改版设计/screens/settings.html` 设计规范）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: SettingsBody(
            onOpenSync: () => context.push('/settings/sync'),
            onOpenTags: () => context.push('/tags'),
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
  });

  final VoidCallback onOpenSync;
  final VoidCallback onOpenTags;

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

        // ── 6. 关于 ──
        const _AboutSection(),
      ],
    );
  }
}

/// 外观配置卡片（主题模式、主题色、语言）
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
                          fontSize: 15,
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
                          fontSize: 12,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.seedColorSubtitle,
                        style: TextStyle(
                          fontSize: 12,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locale.languageCode == 'zh'
                            ? l10n.languageZh
                            : l10n.languageEn,
                        style: TextStyle(
                          fontSize: 12,
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
              borderRadius: BorderRadius.circular(16),
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
                              fontSize: 15,
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
                              fontSize: 12,
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
                        alpha: 0.6,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.showLunarSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: showLunar,
                  onChanged: (val) =>
                      ref.read(calendarShowLunarProvider.notifier).setShowLunar(val),
                ),
              ],
            ),
            const Divider(height: 24),
            // 中国法定节假日及调休开关
            Row(
              children: [
                _IconBadge(
                  icon: Icons.event_available_outlined,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.showHolidays,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.showHolidaysSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: showHolidays,
                  onChanged: (val) =>
                      ref.read(calendarShowHolidaysProvider.notifier).setShowHolidays(val),
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
                top: Radius.circular(16),
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
                                  fontSize: 15,
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
                              fontSize: 12,
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
                        alpha: 0.6,
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
                        fontSize: 15,
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
        bg = colorScheme.primary.withValues(alpha: 0.12);
        fg = colorScheme.primary;
        label = l10n.syncStatusSyncing;
        icon = Icons.sync;
      case SyncStateStatus.success:
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF059669);
        label = l10n.syncStatusSuccess;
        icon = Icons.check_circle_outline;
      case SyncStateStatus.error:
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        fg = const Color(0xFFDC2626);
        label = l10n.syncStatusError;
        icon = Icons.error_outline;
      case SyncStateStatus.idle:
        bg = colorScheme.onSurfaceVariant.withValues(alpha: 0.12);
        fg = colorScheme.onSurfaceVariant;
        label = l10n.syncStatusIdle;
        icon = Icons.cloud_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${l10n.aboutVersion} v$appVersion',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'v$appVersion',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                      fontFamily: 'monospace',
                    ),
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

/// 圆角卡片容器（对齐原型中的 .card 视觉规范）。
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
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
            borderRadius: BorderRadius.circular(100),
            child: Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
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
                  text: '$title: ',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
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
