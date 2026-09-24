import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_restore_service.dart';
import '../../../core/backup/snapshot_pool_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../settings_providers.dart';
import 'import_confirm_dialog.dart';
import 'snapshot_history_sheet.dart';

/// 设置页：数据导入导出与本地安全快照分组组件。
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _isExporting = false;
  bool _isImporting = false;

  String _formatDefaultFileName() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return 'ordo_backup_$y$m${d}_$h$min$s.ordobak';
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    final l10n = AppLocalizations.of(context);
    try {
      final backupService = ref.read(backupRestoreServiceProvider);
      final bytes = await backupService.exportToBytes();

      final defaultName = _formatDefaultFileName();
      final uri = await FilePicker.saveFile(
        dialogTitle: l10n.backupExportTitle,
        fileName: defaultName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: const ['ordobak'],
      );

      if (uri != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupExportSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupOperationFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    final l10n = AppLocalizations.of(context);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: l10n.backupImportTitle,
        type: FileType.custom,
        allowedExtensions: const ['ordobak'],
      );

      if (file == null) {
        return;
      }

      final Uint8List bytes = await file.readAsBytes();

      final backupService = ref.read(backupRestoreServiceProvider);
      BackupSummary summary;
      try {
        summary = backupService.inspectBackup(bytes);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.backupInvalidFile)));
        }
        return;
      }

      if (!mounted) return;

      final confirmed = await ImportConfirmDialog.show(
        context,
        summary: summary,
        sourceTitle: file.name,
        onConfirm: (mode) async {
          // 导入前通过快照池自动创建前置保护快照
          final pool = ref.read(snapshotPoolServiceProvider);
          await backupService.importBackup(
            bytes,
            mode: mode,
            onBeforeRestore: () async {
              await pool.createSnapshot(
                trigger: SnapshotTriggerType.preRestore,
              );
            },
          );
          ref.invalidate(localSnapshotsProvider);
        },
      );

      if (confirmed == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupImportSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupOperationFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final retentionDays = ref.watch(backupRetentionDaysProvider);
    final snapshotsAsync = ref.watch(localSnapshotsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.settingsSectionBackup),
        _SettingsCard(
          padding: EdgeInsets.zero,
          children: [
            // 导出备份数据
            InkWell(
              onTap: _isExporting ? null : _handleExport,
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
                      icon: Icons.file_upload_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.backupExportTitle,
                            style: const TextStyle(
                              fontSize: AppTokens.textBodySize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.backupExportSubtitle,
                            style: TextStyle(
                              fontSize: AppTokens.textCaptionSize,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isExporting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
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
            const Divider(height: 1, indent: 61),

            // 导入备份文件
            InkWell(
              onTap: _isImporting ? null : _handleImport,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _IconBadge(
                      icon: Icons.file_download_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.backupImportTitle,
                            style: const TextStyle(
                              fontSize: AppTokens.textBodySize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.backupImportSubtitle,
                            style: TextStyle(
                              fontSize: AppTokens.textCaptionSize,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isImporting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
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
            const Divider(height: 1, indent: 61),

            // 本地安全快照入口
            InkWell(
              onTap: () => SnapshotHistorySheet.show(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _IconBadge(
                      icon: Icons.shield_outlined,
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
                                l10n.backupSnapshotPoolTitle,
                                style: const TextStyle(
                                  fontSize: AppTokens.textBodySize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              snapshotsAsync.when(
                                data: (snaps) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: AppTokens.alphaBorderSubtle,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTokens.radiusItem,
                                    ),
                                  ),
                                  child: Text(
                                    '${snaps.length}',
                                    style: TextStyle(
                                      fontSize: AppTokens.textMicroSize,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, _) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            snapshotsAsync.when(
                              data: (snaps) =>
                                  l10n.backupSnapshotPoolSubtitle(snaps.length),
                              loading: () => '正在检查快照...',
                              error: (_, _) => '点击查看本地快照',
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
            const Divider(height: 1, indent: 61),

            // 快照保留天数设置
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _IconBadge(
                    icon: Icons.auto_delete_outlined,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.backupRetentionDaysTitle,
                          style: const TextStyle(
                            fontSize: AppTokens.textBodySize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.backupRetentionDaysSubtitle,
                          style: TextStyle(
                            fontSize: AppTokens.textCaptionSize,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(
                              alpha: AppTokens.alphaTintFaint,
                            )
                          : Colors.black.withValues(
                              alpha: AppTokens.alphaTintFaint,
                            ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusList),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(
                                alpha: AppTokens.alphaTintFaint,
                              )
                            : Colors.black.withValues(
                                alpha: AppTokens.alphaTintFaint,
                              ),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: [3, 7, 14, 30, 90].contains(retentionDays)
                            ? retentionDays
                            : defaultBackupRetentionDays,
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                        isDense: true,
                        style: TextStyle(
                          fontSize: AppTokens.textFootnoteSize,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                        items: const [3, 7, 14, 30, 90].map((days) {
                          return DropdownMenuItem<int>(
                            value: days,
                            child: Text(l10n.backupRetentionDaysOption(days)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            ref
                                .read(backupRetentionDaysProvider.notifier)
                                .setDays(val);
                          }
                        },
                      ),
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
}

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
