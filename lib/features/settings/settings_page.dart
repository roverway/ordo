import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/sync_setup/sync_setup_providers.dart';
import '../../features/tags/tag_providers.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/modern_segmented_control.dart';
import 'settings_providers.dart';

const String appVersion = '1.0.0';

/// 预设主题色列表（对齐设计稿 8 色双环光晕色板）
const List<Color> _presetColors = [
  Color(0xFF4A6CF7), // 经典蓝
  Color(0xFF7C3AED), // 优雅紫
  Color(0xFFEC4899), // 活力粉
  Color(0xFFEF4444), // 珊瑚红
  Color(0xFFF97316), // 暖阳橙
  Color(0xFF10B981), // 薄荷绿
  Color(0xFF06B6D4), // 湖水青
  Color(0xFF64748B), // 石板灰
];

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
            onOpenSync: () => context.push('/sync/setup'),
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
                onOpenSync: () => context.push('/sync/setup'),
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
class SettingsBody extends ConsumerWidget {
  const SettingsBody({
    super.key,
    required this.onOpenSync,
    required this.onOpenTags,
  });

  final VoidCallback onOpenSync;
  final VoidCallback onOpenTags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final syncState = ref.watch(syncStateProvider);
    final syncConfigAsync = ref.watch(syncConfigProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isZh = locale.languageCode == 'zh';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ── 1. 外观 ──
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
                  color: const Color(0xFFEAB308),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    l10n.themeMode,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 主题模式现代胶囊分段器
            ModernSegmentedControl<ThemeMode>(
              selectedValue: themeMode,
              onChanged: (mode) =>
                  ref.read(themeModeProvider.notifier).setThemeMode(mode),
              items: [
                ModernSegmentItem(
                  value: ThemeMode.system,
                  label: l10n.themeModeSystem,
                  icon: Icons.brightness_auto_outlined,
                ),
                ModernSegmentItem(
                  value: ThemeMode.light,
                  label: l10n.themeModeLight,
                  icon: Icons.wb_sunny_outlined,
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
            const SizedBox(height: 14),

            // 主题色标题行
            Row(
              children: [
                const _IconBadge(
                  icon: Icons.palette_outlined,
                  color: Color(0xFFEC4899),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    l10n.themeColor,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 主题色调色板
            const _ThemeColorPicker(),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // 语言标题行与切换器
            Row(
              children: [
                const _IconBadge(
                  icon: Icons.language_outlined,
                  color: Color(0xFF3B82F6),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    l10n.language,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 语言分段胶囊
                ModernSegmentedControl<Locale>(
                  isExpanded: false,
                  selectedValue: locale,
                  onChanged: (newLocale) =>
                      ref.read(localeProvider.notifier).setLocale(newLocale),
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

        const SizedBox(height: 20),

        // ── 2. 任务与标签 ──
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
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const _IconBadge(
                      icon: Icons.local_offer_outlined,
                      color: Color(0xFF8B5CF6),
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
                      size: 18,
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

        const SizedBox(height: 20),

        // ── 3. 同步 ──
        _SectionHeader(title: l10n.sync),
        _SettingsCard(
          padding: EdgeInsets.zero,
          children: [
            InkWell(
              onTap: onOpenSync,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const _IconBadge(
                      icon: Icons.cloud_sync_outlined,
                      color: Color(0xFF0D9488),
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
                              _buildSyncStatusBadge(l10n, syncState.status),
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
                      size: 18,
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
                      activeTrackColor: const Color(0xFF10B981),
                      activeThumbColor: Colors.white,
                      value:
                          syncConfigAsync.value?.autoOnStart == true ||
                          syncConfigAsync.value?.autoOnEdit == true,
                      onChanged: (val) async {
                        final config = syncConfigAsync.value;
                        if (config != null) {
                          await saveSyncConfig(
                            ref,
                            config.copyWith(autoOnStart: val, autoOnEdit: val),
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

        const SizedBox(height: 20),

        // ── 4. 关于 ──
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(color: colorScheme.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“',
                    style: TextStyle(
                      fontSize: 20,
                      height: 0.8,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isZh
                        ? '让行动自然流淌，在秩序中专注当下。'
                        : 'Let action flow naturally, stay focused in order.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 品牌内涵列表 (To, Do, Todo)
            _AboutMeaningRow(
              letter: 'T',
              word: 'To',
              meaning: isZh
                  ? '目标与方向，始于清晰的意图'
                  : 'Target & direction, starting with clear intent',
            ),
            const SizedBox(height: 8),
            _AboutMeaningRow(
              letter: 'D',
              word: 'Do',
              meaning: isZh
                  ? '行动与执行，专注于当下的推进'
                  : 'Action & execution, focusing on present progress',
            ),
            const SizedBox(height: 8),
            _AboutMeaningRow(
              letter: '∞',
              word: 'Todo',
              meaning: isZh
                  ? '秩序与循环，连接目标与完成的闭环'
                  : 'Order & loop, closing the cycle of goals and completion',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncStatusBadge(AppLocalizations l10n, SyncStateStatus status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case SyncStateStatus.syncing:
        bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
        fg = const Color(0xFF2563EB);
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
        bg = Colors.grey.withValues(alpha: 0.12);
        fg = Colors.grey.shade700;
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
      final dt = DateTime.fromMillisecondsSinceEpoch(syncState.lastSyncedAt!);
      final timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$target · ${l10n.syncLastSyncedAt(timeStr)}';
    }
    return target;
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
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 17, color: color),
    );
  }
}

/// 主题色双环光晕选择器（8色网格，完全复刻 .c-opt 双环选中态）。
class _ThemeColorPicker extends ConsumerWidget {
  const _ThemeColorPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSeed = ref.watch(themeSeedColorProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _presetColors.map((color) {
            final isSelected = color.toARGB32() == currentSeed.toARGB32();

            return InkWell(
              onTap: () =>
                  ref.read(themeSeedColorProvider.notifier).setSeedColor(color),
              borderRadius: BorderRadius.circular(100),
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: color.withValues(alpha: 0.4),
                          width: 2.5,
                        )
                      : null,
                ),
                child: Container(
                  width: isSelected ? 26 : 30,
                  height: isSelected ? 26 : 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// 品牌内涵行（微型首字母高亮徽章 + 词语 + 释义）。
class _AboutMeaningRow extends StatelessWidget {
  const _AboutMeaningRow({
    required this.letter,
    required this.word,
    required this.meaning,
  });

  final String letter;
  final String word;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$word · ',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            meaning,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
