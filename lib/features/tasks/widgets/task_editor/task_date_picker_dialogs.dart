import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/tables.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/dates.dart';
import '../../task_providers.dart';
import '../priority_picker.dart';

/// 日期弹层（Linear + Things 3 风格）：顶部快捷预设胶囊 + 开始/截止时间交互卡片。
Future<void> showTaskDatePicker(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) => const TaskDateRangePickerSheet(),
  );
}

class TaskDateRangePickerSheet extends ConsumerWidget {
  const TaskDateRangePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final formState = ref.watch(taskFormProvider);
    final notifier = ref.read(taskFormProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 顶部栏：标题 + 完成 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.dateAndReminder,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTokens.textTitleWeight,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.done),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceSm),

            // ── 快捷预设胶囊行（Things 3 / Linear 式）──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DatePresetChip(
                    label: l10n.today,
                    icon: Icons.today,
                    onTap: () {
                      final ms = dateOnlyMs(DateTime.now());
                      notifier.updateEndAt(ms);
                    },
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  DatePresetChip(
                    label: l10n.tomorrow,
                    icon: Icons.wb_sunny_outlined,
                    onTap: () {
                      final ms = dateOnlyMs(
                        DateTime.now().add(const Duration(days: 1)),
                      );
                      notifier.updateEndAt(ms);
                    },
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  DatePresetChip(
                    label: l10n.thisWeekend,
                    icon: Icons.weekend_outlined,
                    onTap: () {
                      final ms = dateOnlyMs(thisWeekend(DateTime.now()));
                      notifier.updateEndAt(ms);
                    },
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  DatePresetChip(
                    label: l10n.nextWeek,
                    icon: Icons.calendar_view_week_outlined,
                    onTap: () {
                      final ms = dateOnlyMs(nextMonday(DateTime.now()));
                      notifier.updateEndAt(ms);
                    },
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  DatePresetChip(
                    label: l10n.custom,
                    icon: Icons.edit_calendar_outlined,
                    onTap: () =>
                        pickCustomDateTime(context, notifier, isStart: false),
                  ),
                  if (formState.startAt != null || formState.endAt != null) ...[
                    const SizedBox(width: AppTokens.spaceXs),
                    DatePresetChip(
                      label: l10n.clear,
                      icon: Icons.clear,
                      isDestructive: true,
                      onTap: () {
                        notifier.updateStartAt(null);
                        notifier.updateEndAt(null);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),

            // ── 开始时间卡片 ──
            DateSettingCard(
              title: l10n.taskStartTime,
              icon: Icons.play_circle_outline,
              valueText: formState.startAt != null
                  ? formatDueDate(formState.startAt!, l10n)
                  : l10n.noStartTime,
              hasValue: formState.startAt != null,
              onTap: () => pickCustomDateTime(context, notifier, isStart: true),
              onClear: formState.startAt != null
                  ? () => notifier.updateStartAt(null)
                  : null,
            ),
            const SizedBox(height: AppTokens.spaceSm),

            // ── 截止时间卡片 ──
            DateSettingCard(
              title: l10n.taskEndTime,
              icon: Icons.flag_outlined,
              valueText: formState.endAt != null
                  ? formatDueDate(formState.endAt!, l10n)
                  : l10n.noDueDate,
              hasValue: formState.endAt != null,
              onTap: () =>
                  pickCustomDateTime(context, notifier, isStart: false),
              onClear: formState.endAt != null
                  ? () => notifier.updateEndAt(null)
                  : null,
            ),
            const SizedBox(height: AppTokens.spaceSm),
          ],
        ),
      ),
    );
  }
}

class DatePresetChip extends StatelessWidget {
  const DatePresetChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.primary;

    return ActionChip(
      avatar: Icon(icon, size: 15, color: color),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: AppTokens.textCaptionSize,
        fontWeight: FontWeight.w500,
        color: isDestructive ? colorScheme.error : colorScheme.onSurface,
      ),
      backgroundColor: isDark
          ? AppTokens.surfaceCardDark
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        side: BorderSide(
          color: isDark
              ? AppTokens.borderSubtleDark
              : AppTokens.borderSubtleLight,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: onTap,
    );
  }
}

class DateSettingCard extends StatelessWidget {
  const DateSettingCard({
    super.key,
    required this.title,
    required this.icon,
    required this.valueText,
    required this.hasValue,
    required this.onTap,
    this.onClear,
  });

  final String title;
  final IconData icon;
  final String valueText;
  final bool hasValue;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(
          color: isDark
              ? AppTokens.borderSubtleDark
              : AppTokens.borderSubtleLight,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceMd,
              vertical: AppTokens.spaceSm,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: hasValue
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: AppTokens.textMicroSize,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        valueText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: hasValue
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: hasValue
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasValue && onClear != null)
                  IconButton(
                    tooltip: l10n.clear,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClear,
                  )
                else
                  const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 自定义日期 + 时间选择（复用编辑页 showDatePicker + showTimePicker 逻辑）。
Future<void> pickCustomDateTime(
  BuildContext context,
  TaskFormNotifier notifier, {
  required bool isStart,
}) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
  );
  if (date == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now),
  );
  if (time == null || !context.mounted) return;
  final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  final ms = dt.toUtc().millisecondsSinceEpoch;
  if (isStart) {
    notifier.updateStartAt(ms);
  } else {
    notifier.updateEndAt(ms);
  }
}

/// 状态图标（工具栏 + 状态弹层共用）。
IconData statusIcon(TaskStatus status) => switch (status) {
  TaskStatus.todo => Icons.radio_button_unchecked,
  TaskStatus.inProgress => Icons.circle,
  TaskStatus.done => Icons.check_circle,
  TaskStatus.cancelled => Icons.cancel_outlined,
};

/// 状态颜色（工具栏 + 状态弹层共用）。
Color statusColor(TaskStatus status) => switch (status) {
  TaskStatus.todo => AppTokens.colorCancelled,
  TaskStatus.inProgress => AppTokens.colorInProgress,
  TaskStatus.done => AppTokens.colorDone,
  TaskStatus.cancelled => AppTokens.colorCancelled,
};

/// 状态本地化名称。
String statusLabel(AppLocalizations l10n, TaskStatus status) =>
    switch (status) {
      TaskStatus.todo => l10n.statusTodo,
      TaskStatus.inProgress => l10n.statusInProgress,
      TaskStatus.done => l10n.statusDone,
      TaskStatus.cancelled => l10n.statusCancelled,
    };

/// 状态弹层：4 状态（todo/inProgress/done/cancelled），当前项蓝色对勾。
Future<void> showTaskStatusPicker(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final current = ref.read(taskFormProvider).status;
  final picked = await showModalBottomSheet<TaskStatus>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppTokens.spaceXs),
          ListTile(
            title: Text(
              l10n.taskStatus,
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                fontWeight: AppTokens.textTitleWeight,
              ),
            ),
          ),
          const Divider(),
          for (final s in TaskStatus.values)
            ListTile(
              leading: Icon(statusIcon(s), size: 20, color: statusColor(s)),
              title: Text(statusLabel(l10n, s)),
              trailing: s == current
                  ? const Icon(
                      Icons.check,
                      size: 20,
                      color: AppTokens.colorInProgress,
                    )
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(s),
            ),
          const SizedBox(height: AppTokens.spaceXs),
        ],
      ),
    ),
  );
  if (picked != null && context.mounted) {
    ref.read(taskFormProvider.notifier).updateStatus(picked);
  }
}

/// 优先级弹层（滴答式 红/橙/蓝/无，复用 priority_picker）。
Future<void> showTaskPriorityPicker(BuildContext context, WidgetRef ref) async {
  final formState = ref.read(taskFormProvider);
  final picked = await showPriorityPicker(context, current: formState.priority);
  if (picked != null && context.mounted) {
    ref.read(taskFormProvider.notifier).updatePriority(picked);
  }
}

/// 日期型时间的 09:00 约定（与日历「点日期新建」一致，UTC 毫秒）。
int dateOnlyMs(DateTime day) =>
    DateTime(day.year, day.month, day.day, 9).toUtc().millisecondsSinceEpoch;

/// 下一个周一（今天为周一时取下周）。
DateTime nextMonday(DateTime today) {
  final days = (8 - today.weekday) % 7;
  return today.add(Duration(days: days == 0 ? 7 : days));
}

/// 本周末（周六）。
DateTime thisWeekend(DateTime today) {
  final daysUntilSaturday = (DateTime.saturday - today.weekday + 7) % 7;
  return today.add(
    Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday),
  );
}
