import 'package:flutter/material.dart';

import '../../../core/backup/backup_restore_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// 导入前二次确认与模式选择对话框。
class ImportConfirmDialog extends StatefulWidget {
  const ImportConfirmDialog({
    super.key,
    required this.summary,
    this.sourceTitle,
    required this.onConfirm,
  });

  final BackupSummary summary;
  final String? sourceTitle;
  final Future<void> Function(ImportMode mode) onConfirm;

  static Future<bool?> show(
    BuildContext context, {
    required BackupSummary summary,
    String? sourceTitle,
    required Future<void> Function(ImportMode mode) onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ImportConfirmDialog(
        summary: summary,
        sourceTitle: sourceTitle,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<ImportConfirmDialog> createState() => _ImportConfirmDialogState();
}

class _ImportConfirmDialogState extends State<ImportConfirmDialog> {
  ImportMode _selectedMode = ImportMode.merge;
  bool _isLoading = false;
  String? _errorMessage;

  String _formatDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  Future<void> _handleConfirm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirm(_selectedMode);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.restore_page_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.backupImportDialogTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.sourceTitle != null) ...[
              Text(
                widget.sourceTitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // 摘要卡片（使用标准本地化模板字符串）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Text(
                l10n.backupImportDialogSummary(
                  _formatDateTime(widget.summary.exportedAt),
                  widget.summary.projectCount,
                  widget.summary.taskCount,
                  widget.summary.tagCount,
                  widget.summary.folderCount,
                  widget.summary.customViewCount,
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFFD1D5DB)
                      : const Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 导入模式单选
            _ModeSelectCard(
              title: l10n.backupImportModeMerge,
              subtitle: l10n.backupImportModeMergeDesc,
              isSelected: _selectedMode == ImportMode.merge,
              accentColor: colorScheme.primary,
              onTap: () => setState(() => _selectedMode = ImportMode.merge),
            ),
            const SizedBox(height: 10),

            _ModeSelectCard(
              title: l10n.backupImportModeReplace,
              subtitle: l10n.backupImportModeReplaceDesc,
              isSelected: _selectedMode == ImportMode.replace,
              accentColor: const Color(0xFFEF4444),
              onTap: () => setState(() => _selectedMode = ImportMode.replace),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.backupOperationFailed(_errorMessage!),
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(
            l10n.cancel,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: _selectedMode == ImportMode.replace
                ? const Color(0xFFDC2626)
                : colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusButton),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.backupImportAction),
        ),
      ],
    );
  }
}

class _ModeSelectCard extends StatelessWidget {
  const _ModeSelectCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: isSelected
                    ? accentColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? accentColor
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
