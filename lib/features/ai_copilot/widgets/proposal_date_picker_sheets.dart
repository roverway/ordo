import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';

/// 唤起 AI 任务建议的截止时间设置底部面板。
Future<void> showProposalDueDatePicker({
  required BuildContext context,
  required int? initialDueAt,
  required ValueChanged<int?> onDateSelected,
}) async {
  HapticFeedback.selectionClick();
  final l10n = AppLocalizations.of(context);
  final now = DateTime.now();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (bottomSheetContext) {
      final theme = Theme.of(bottomSheetContext);
      final isDark = theme.brightness == Brightness.dark;
      final sheetBg = isDark
          ? AppTokens.surfaceCardDark
          : AppTokens.surfaceCard;
      final borderColor = isDark
          ? AppTokens.borderSubtleDark
          : AppTokens.borderSubtleLight;

      return Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusCard),
          ),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTokens.borderSubtleDark
                        : AppTokens.borderSubtleLight,
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                l10n.aiSetDueDate,
                style: TextStyle(
                  fontSize: AppTokens.textBodySize,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Wrap(
                spacing: AppTokens.spaceXs,
                runSpacing: AppTokens.spaceXs,
                children: [
                  ActionChip(
                    label: Text(l10n.aiPresetToday18),
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      final dt = DateTime(now.year, now.month, now.day, 18, 0);
                      onDateSelected(dt.millisecondsSinceEpoch);
                    },
                  ),
                  ActionChip(
                    label: Text(l10n.aiPresetTonight21),
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      final dt = DateTime(now.year, now.month, now.day, 21, 0);
                      onDateSelected(dt.millisecondsSinceEpoch);
                    },
                  ),
                  ActionChip(
                    label: Text(l10n.aiPresetTomorrow09),
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      final dt = DateTime(
                        now.year,
                        now.month,
                        now.day + 1,
                        9,
                        0,
                      );
                      onDateSelected(dt.millisecondsSinceEpoch);
                    },
                  ),
                  ActionChip(
                    label: Text(l10n.aiPresetThisFriday18),
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      final days = (DateTime.friday - now.weekday + 7) % 7;
                      final targetDay = days == 0 ? 7 : days;
                      final dt = DateTime(
                        now.year,
                        now.month,
                        now.day + targetDay,
                        18,
                        0,
                      );
                      onDateSelected(dt.millisecondsSinceEpoch);
                    },
                  ),
                  ActionChip(
                    label: Text(l10n.aiPresetNextMonday09),
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      final days = (DateTime.monday - now.weekday + 7) % 7;
                      final targetDay = days == 0 ? 7 : days;
                      final dt = DateTime(
                        now.year,
                        now.month,
                        now.day + targetDay,
                        9,
                        0,
                      );
                      onDateSelected(dt.millisecondsSinceEpoch);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceSm),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(bottomSheetContext);
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: initialDueAt != null
                        ? DateTime.fromMillisecondsSinceEpoch(initialDueAt)
                        : now,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 3650)),
                  );
                  if (pickedDate == null || !context.mounted) return;
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 18, minute: 0),
                  );
                  if (!context.mounted) return;
                  final hour = pickedTime?.hour ?? 18;
                  final minute = pickedTime?.minute ?? 0;
                  final finalDt = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    hour,
                    minute,
                  );
                  onDateSelected(finalDt.millisecondsSinceEpoch);
                },
                icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                label: Text(l10n.aiCustomDateTime),
              ),
              if (initialDueAt != null) ...[
                const SizedBox(height: AppTokens.spaceXs),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    onDateSelected(null);
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: Text(l10n.aiClearDueDate),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTokens.colorDanger,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// 唤起 AI 任务建议的开始时间设置底部面板。
Future<void> showProposalStartDatePicker({
  required BuildContext context,
  required int? initialStartAt,
  required ValueChanged<int?> onDateSelected,
}) async {
  HapticFeedback.selectionClick();
  final l10n = AppLocalizations.of(context);
  final now = DateTime.now();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (bottomSheetContext) {
      final theme = Theme.of(bottomSheetContext);
      final isDark = theme.brightness == Brightness.dark;
      final sheetBg = isDark
          ? AppTokens.surfaceCardDark
          : AppTokens.surfaceCard;
      final borderColor = isDark
          ? AppTokens.borderSubtleDark
          : AppTokens.borderSubtleLight;

      return Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTokens.radiusCard),
          ),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTokens.borderSubtleDark
                        : AppTokens.borderSubtleLight,
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                l10n.aiSetStartDate,
                style: TextStyle(
                  fontSize: AppTokens.textBodySize,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Wrap(
                spacing: AppTokens.spaceXs,
                runSpacing: AppTokens.spaceXs,
                children: [
                  ActionChip(
                    label: Text(l10n.aiPresetNow),
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      onDateSelected(now.millisecondsSinceEpoch);
                    },
                  ),
                  ActionChip(
                    label: Text(l10n.aiPresetToday14),
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      final dt = DateTime(now.year, now.month, now.day, 14, 0);
                      onDateSelected(dt.millisecondsSinceEpoch);
                    },
                  ),
                  ActionChip(
                    label: Text(l10n.aiPresetTomorrow09),
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      final dt = DateTime(
                        now.year,
                        now.month,
                        now.day + 1,
                        9,
                        0,
                      );
                      onDateSelected(dt.millisecondsSinceEpoch);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceSm),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(bottomSheetContext);
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: initialStartAt != null
                        ? DateTime.fromMillisecondsSinceEpoch(initialStartAt)
                        : now,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 3650)),
                  );
                  if (pickedDate == null || !context.mounted) return;
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (!context.mounted) return;
                  final hour = pickedTime?.hour ?? 9;
                  final minute = pickedTime?.minute ?? 0;
                  final finalDt = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    hour,
                    minute,
                  );
                  onDateSelected(finalDt.millisecondsSinceEpoch);
                },
                icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                label: Text(l10n.aiCustomDateTime),
              ),
              if (initialStartAt != null) ...[
                const SizedBox(height: AppTokens.spaceXs),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    onDateSelected(null);
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: Text(l10n.aiClearStartDate),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTokens.colorDanger,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
