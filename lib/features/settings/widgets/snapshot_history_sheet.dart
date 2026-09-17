import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_restore_service.dart';
import '../../../core/backup/snapshot_pool_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../settings_providers.dart';
import 'import_confirm_dialog.dart';

/// 本地安全快照历史管理底栏 Sheet。
class SnapshotHistorySheet extends ConsumerStatefulWidget {
  const SnapshotHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SnapshotHistorySheet(),
    );
  }

  @override
  ConsumerState<SnapshotHistorySheet> createState() =>
      _SnapshotHistorySheetState();
}

class _SnapshotHistorySheetState extends ConsumerState<SnapshotHistorySheet> {
  bool _isCreating = false;

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  Future<void> _createManualSnapshot() async {
    setState(() => _isCreating = true);
    final l10n = AppLocalizations.of(context);
    final pool = ref.read(snapshotPoolServiceProvider);
    try {
      await pool.createSnapshot(trigger: SnapshotTriggerType.manual);
      ref.invalidate(localSnapshotsProvider);
      if (mounted) {
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
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _handleRestore(LocalSnapshotInfo snap) async {
    final l10n = AppLocalizations.of(context);
    final pool = ref.read(snapshotPoolServiceProvider);
    final file = File(snap.filePath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupInvalidFile)));
      }
      return;
    }

    final bytes = await file.readAsBytes();
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
      sourceTitle: l10n.backupSnapshotPoint(
        _formatDateTime(snap.createdAt),
        snap.triggerType.localizedLabel(l10n),
      ),
      onConfirm: (mode) async {
        await pool.restoreFromSnapshot(snap.filePath, mode: mode);
        ref.invalidate(localSnapshotsProvider);
      },
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.backupImportSuccess)));
    }
  }

  Future<void> _handleDelete(LocalSnapshotInfo snap) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        ),
        title: Text(
          l10n.backupDeleteAction,
          style: const TextStyle(
            fontSize: AppTokens.textSubtitleSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.deleteProjectConfirm(_formatDateTime(snap.createdAt)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.colorDanger,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final pool = ref.read(snapshotPoolServiceProvider);
      await pool.deleteSnapshot(snap.filePath);
      ref.invalidate(localSnapshotsProvider);
    }
  }

  Color _badgeColorForTrigger(SnapshotTriggerType trigger, ColorScheme cs) {
    return switch (trigger) {
      SnapshotTriggerType.dailyAuto => AppTokens.colorInfo,
      SnapshotTriggerType.preSync => AppTokens.colorSuccess,
      SnapshotTriggerType.preRestore => AppTokens.colorWarning,
      SnapshotTriggerType.manual => cs.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final snapshotsAsync = ref.watch(localSnapshotsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.surfaceDark : AppTokens.surfaceCardLight,
        borderRadius: AppTokens.sheetTopBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppTokens.alphaBorderEmphasis,
            ),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部小横条指示器
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(
                          alpha: AppTokens.alphaBorderEmphasis,
                        )
                      : Colors.black.withValues(
                          alpha: AppTokens.alphaTintStrong,
                        ),
                  borderRadius: BorderRadius.circular(
                    AppTokens.sheetGrabberRadius,
                  ),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(
                        alpha: AppTokens.alphaBorderSubtle,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusItem),
                    ),
                    child: Icon(
                      Icons.history_toggle_off_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.backupSnapshotSheetTitle,
                          style: const TextStyle(
                            fontSize: AppTokens.textSubtitleSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.backupSnapshotPoolSubtitle(
                            snapshotsAsync.value?.length ?? 0,
                          ),
                          style: TextStyle(
                            fontSize: AppTokens.textMicroSize,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _isCreating ? null : _createManualSnapshot,
                    icon: _isCreating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_rounded, size: 16),
                    label: Text(
                      l10n.backupCreateSnapshotManual,
                      style: const TextStyle(
                        fontSize: AppTokens.textCaptionSize,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusChip,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 列表
            Flexible(
              child: snapshotsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(l10n.backupOperationFailed(err.toString())),
                  ),
                ),
                data: (snapshots) {
                  if (snapshots.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 48,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.backupSnapshotEmpty,
                              style: TextStyle(
                                fontSize: AppTokens.textSecondarySize,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: snapshots.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final snap = snapshots[index];
                      final badgeColor = _badgeColorForTrigger(
                        snap.triggerType,
                        colorScheme,
                      );
                      final sizeKb = (snap.sizeBytes / 1024).toStringAsFixed(1);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTokens.surfaceSubtleDark
                              : AppTokens.surfaceCard,
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusCard,
                          ),
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
                        child: Row(
                          children: [
                            // 触发类型指示标
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(
                                  alpha: AppTokens.alphaTintStrong,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusChip,
                                ),
                              ),
                              child: Text(
                                snap.triggerType.localizedLabel(l10n),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppTokens.textNanoSize,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDateTime(snap.createdAt),
                                    style: const TextStyle(
                                      fontSize: AppTokens.textFootnoteSize,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${snap.projectCount} · ${snap.taskCount} · $sizeKb KB',
                                    style: TextStyle(
                                      fontSize: AppTokens.textMicroSize,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 4),

                            // 还原按钮（去掉文本以节省空间）
                            IconButton(
                              icon: Icon(
                                Icons.settings_backup_restore_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              onPressed: () => _handleRestore(snap),
                              visualDensity: VisualDensity.compact,
                              tooltip: l10n.backupRestoreButton,
                            ),

                            // 删除按钮
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              onPressed: () => _handleDelete(snap),
                              visualDensity: VisualDensity.compact,
                              tooltip: l10n.backupDeleteAction,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension SnapshotTriggerTypeL10n on SnapshotTriggerType {
  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      SnapshotTriggerType.dailyAuto => l10n.snapshotTriggerDaily,
      SnapshotTriggerType.preSync => l10n.snapshotTriggerPreSync,
      SnapshotTriggerType.preRestore => l10n.snapshotTriggerPreRestore,
      SnapshotTriggerType.manual => l10n.snapshotTriggerManual,
    };
  }
}
