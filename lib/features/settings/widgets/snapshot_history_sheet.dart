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
        snap.triggerType.label,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.backupDeleteAction,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              backgroundColor: const Color(0xFFEF4444),
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
      SnapshotTriggerType.dailyAuto => const Color(0xFF3B82F6),
      SnapshotTriggerType.preSync => const Color(0xFF10B981),
      SnapshotTriggerType.preRestore => const Color(0xFFF59E0B),
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
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
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
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.backupSnapshotPoolSubtitle(
                            snapshotsAsync.value?.length ?? 0,
                          ),
                          style: TextStyle(
                            fontSize: 11,
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
                      style: const TextStyle(fontSize: 12),
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
                                fontSize: 14,
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
                              ? const Color(0xFF222228)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
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
                                color: badgeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                snap.triggerType.label,
                                style: TextStyle(
                                  fontSize: 10,
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${snap.projectCount} · ${snap.taskCount} · $sizeKb KB',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 还原按钮
                            TextButton.icon(
                              onPressed: () => _handleRestore(snap),
                              icon: Icon(
                                Icons.settings_backup_restore_rounded,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              label: Text(
                                l10n.backupRestoreButton,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
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
