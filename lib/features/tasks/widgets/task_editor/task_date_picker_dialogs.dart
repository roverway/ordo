import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/tables.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/dates.dart';
import '../../../../shared/widgets/app_frosted_container.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../task_providers.dart';
import '../priority_picker.dart';
import 'task_date_picker_calendar.dart';

/// 日期弹层（流体单层画布设计）：顶部快捷预设 + 起止双卡片 + 内联高密度月历 + 精准时间调节。
Future<void> showTaskDatePicker(BuildContext context, WidgetRef ref) async {
  await showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const TaskDateRangePickerSheet(),
  );
}

class TaskDateRangePickerSheet extends ConsumerStatefulWidget {
  const TaskDateRangePickerSheet({super.key, this.initialIsStart = false});

  final bool initialIsStart;

  @override
  ConsumerState<TaskDateRangePickerSheet> createState() =>
      _TaskDateRangePickerSheetState();
}

class _TaskDateRangePickerSheetState
    extends ConsumerState<TaskDateRangePickerSheet> {
  late bool _isEditingStart;
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _isEditingStart = widget.initialIsStart;
    final formState = ref.read(taskFormProvider);
    final targetMs = _isEditingStart ? formState.startAt : formState.endAt;
    final baseDate = targetMs != null
        ? DateTime.fromMillisecondsSinceEpoch(targetMs, isUtc: true).toLocal()
        : DateTime.now();
    _focusedMonth = DateTime(baseDate.year, baseDate.month);
  }

  void _prevMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  void _selectDay(DateTime day) {
    HapticFeedback.selectionClick();
    final notifier = ref.read(taskFormProvider.notifier);
    final formState = ref.read(taskFormProvider);

    if (_isEditingStart) {
      final currentStart = formState.startAt != null
          ? DateTime.fromMillisecondsSinceEpoch(
              formState.startAt!,
              isUtc: true,
            ).toLocal()
          : null;
      final hour = currentStart?.hour ?? 9;
      final minute = currentStart?.minute ?? 0;
      final newStartDt = DateTime(day.year, day.month, day.day, hour, minute);
      final newStartMs = newStartDt.toUtc().millisecondsSinceEpoch;
      notifier.updateStartAt(newStartMs);

      // 物理顺延：如果截止时间早于新的开始时间，自动同步推移截止时间
      if (formState.endAt != null && formState.endAt! < newStartMs) {
        final newEndDt = DateTime(
          day.year,
          day.month,
          day.day,
          (hour + 1).clamp(0, 23),
          minute,
        );
        notifier.updateEndAt(newEndDt.toUtc().millisecondsSinceEpoch);
      }
    } else {
      final currentEnd = formState.endAt != null
          ? DateTime.fromMillisecondsSinceEpoch(
              formState.endAt!,
              isUtc: true,
            ).toLocal()
          : null;
      final hour = currentEnd?.hour ?? 18;
      final minute = currentEnd?.minute ?? 0;
      final newEndDt = DateTime(day.year, day.month, day.day, hour, minute);
      final newEndMs = newEndDt.toUtc().millisecondsSinceEpoch;
      notifier.updateEndAt(newEndMs);

      // 物理联动：如果开始时间晚于新的截止时间，自动顺延推移开始时间
      if (formState.startAt != null && formState.startAt! > newEndMs) {
        final newStartDt = DateTime(
          day.year,
          day.month,
          day.day,
          (hour - 1).clamp(0, 23),
          minute,
        );
        notifier.updateStartAt(newStartDt.toUtc().millisecondsSinceEpoch);
      }
    }
  }

  void _setTime(TimeOfDay? time) {
    HapticFeedback.selectionClick();
    final notifier = ref.read(taskFormProvider.notifier);
    final formState = ref.read(taskFormProvider);
    final targetMs = _isEditingStart ? formState.startAt : formState.endAt;

    final baseDt = targetMs != null
        ? DateTime.fromMillisecondsSinceEpoch(targetMs, isUtc: true).toLocal()
        : DateTime.now();

    final newDt = time == null
        ? DateTime(baseDt.year, baseDt.month, baseDt.day, 9, 0)
        : DateTime(
            baseDt.year,
            baseDt.month,
            baseDt.day,
            time.hour,
            time.minute,
          );

    final ms = newDt.toUtc().millisecondsSinceEpoch;
    if (_isEditingStart) {
      notifier.updateStartAt(ms);
      if (formState.endAt != null && formState.endAt! < ms) {
        notifier.updateEndAt(
          newDt.add(const Duration(hours: 1)).toUtc().millisecondsSinceEpoch,
        );
      }
    } else {
      notifier.updateEndAt(ms);
      if (formState.startAt != null && formState.startAt! > ms) {
        notifier.updateStartAt(
          newDt
              .subtract(const Duration(hours: 1))
              .toUtc()
              .millisecondsSinceEpoch,
        );
      }
    }
  }

  Future<void> _pickExactTime(BuildContext context) async {
    final formState = ref.read(taskFormProvider);
    final targetMs = _isEditingStart ? formState.startAt : formState.endAt;
    final currentDt = targetMs != null
        ? DateTime.fromMillisecondsSinceEpoch(targetMs, isUtc: true).toLocal()
        : DateTime.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentDt.hour, minute: currentDt.minute),
    );

    if (picked != null) {
      _setTime(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final formState = ref.watch(taskFormProvider);
    final notifier = ref.read(taskFormProvider.notifier);

    final startDt = formState.startAt != null
        ? DateTime.fromMillisecondsSinceEpoch(
            formState.startAt!,
            isUtc: true,
          ).toLocal()
        : null;

    final endDt = formState.endAt != null
        ? DateTime.fromMillisecondsSinceEpoch(
            formState.endAt!,
            isUtc: true,
          ).toLocal()
        : null;

    final activeDt = _isEditingStart ? startDt : endDt;

    return AppFrostedContainer(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusSheet),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMd,
            vertical: AppTokens.spaceSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部微光细短装饰手柄
              Center(
                child: Container(
                  margin: const EdgeInsets.only(
                    top: AppTokens.sheetGrabberMiniMarginTop,
                    bottom: AppTokens.sheetGrabberMiniMarginBottom,
                  ),
                  width: AppTokens.sheetGrabberMiniWidth,
                  height: AppTokens.sheetGrabberMiniHeight,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: AppTokens.alphaTintStrong,
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                ),
              ),

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
              const SizedBox(height: AppTokens.spaceXs),

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
                        setState(() {
                          _isEditingStart = false;
                          _focusedMonth = DateTime(
                            DateTime.now().year,
                            DateTime.now().month,
                          );
                        });
                      },
                    ),
                    const SizedBox(width: AppTokens.spaceXs),
                    DatePresetChip(
                      label: l10n.tomorrow,
                      icon: Icons.wb_sunny_outlined,
                      onTap: () {
                        final tom = DateTime.now().add(const Duration(days: 1));
                        final ms = dateOnlyMs(tom);
                        notifier.updateEndAt(ms);
                        setState(() {
                          _isEditingStart = false;
                          _focusedMonth = DateTime(tom.year, tom.month);
                        });
                      },
                    ),
                    const SizedBox(width: AppTokens.spaceXs),
                    DatePresetChip(
                      label: l10n.thisWeekend,
                      icon: Icons.weekend_outlined,
                      onTap: () {
                        final wk = thisWeekend(DateTime.now());
                        final ms = dateOnlyMs(wk);
                        notifier.updateEndAt(ms);
                        setState(() {
                          _isEditingStart = false;
                          _focusedMonth = DateTime(wk.year, wk.month);
                        });
                      },
                    ),
                    const SizedBox(width: AppTokens.spaceXs),
                    DatePresetChip(
                      label: l10n.nextWeek,
                      icon: Icons.calendar_view_week_outlined,
                      onTap: () {
                        final nx = nextMonday(DateTime.now());
                        final ms = dateOnlyMs(nx);
                        notifier.updateEndAt(ms);
                        setState(() {
                          _isEditingStart = false;
                          _focusedMonth = DateTime(nx.year, nx.month);
                        });
                      },
                    ),
                    const SizedBox(width: AppTokens.spaceXs),
                    DatePresetChip(
                      label: l10n.custom,
                      icon: Icons.edit_calendar_outlined,
                      onTap: () {
                        setState(() {
                          _isEditingStart = false;
                        });
                      },
                    ),
                    if (formState.startAt != null ||
                        formState.endAt != null) ...[
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
              const SizedBox(height: AppTokens.spaceSm),

              // ── 开始时间与截止时间交互卡片行 ──
              Row(
                children: [
                  Expanded(
                    child: DateSettingCard(
                      title: l10n.taskStartTime,
                      icon: Icons.play_circle_outline,
                      valueText: formState.startAt != null
                          ? formatDueDateWithTime(formState.startAt!, l10n)
                          : l10n.noStartTime,
                      hasValue: formState.startAt != null,
                      isSelected: _isEditingStart,
                      onTap: () {
                        setState(() {
                          _isEditingStart = true;
                          if (startDt != null) {
                            _focusedMonth = DateTime(
                              startDt.year,
                              startDt.month,
                            );
                          }
                        });
                      },
                      onClear: formState.startAt != null
                          ? () => notifier.updateStartAt(null)
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  Expanded(
                    child: DateSettingCard(
                      title: l10n.taskEndTime,
                      icon: Icons.flag_outlined,
                      valueText: formState.endAt != null
                          ? formatDueDateWithTime(formState.endAt!, l10n)
                          : l10n.noDueDate,
                      hasValue: formState.endAt != null,
                      isSelected: !_isEditingStart,
                      onTap: () {
                        setState(() {
                          _isEditingStart = false;
                          if (endDt != null) {
                            _focusedMonth = DateTime(endDt.year, endDt.month);
                          }
                        });
                      },
                      onClear: formState.endAt != null
                          ? () => notifier.updateEndAt(null)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceSm),

              // ── 内联高精度现代月历 ──
              InlineCalendarView(
                focusedMonth: _focusedMonth,
                startDt: startDt,
                endDt: endDt,
                isEditingStart: _isEditingStart,
                onPrevMonth: _prevMonth,
                onNextMonth: _nextMonth,
                onSelectDay: _selectDay,
              ),

              const SizedBox(height: AppTokens.spaceSm),

              // ── 内联微调时间段栏 ──
              InlineTimeBar(
                activeDt: activeDt,
                isStart: _isEditingStart,
                onSelectTime: _setTime,
                onPickCustomTime: () => _pickExactTime(context),
              ),
              const SizedBox(height: AppTokens.spaceXs),
            ],
          ),
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
      avatar: Icon(icon, size: AppTokens.iconSizeSmall, color: color),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: AppTokens.textCaptionSize,
        fontWeight: FontWeight.w500,
        color: isDestructive ? colorScheme.error : colorScheme.onSurface,
      ),
      backgroundColor: isDark
          ? AppTokens.surfaceCardDark
          : colorScheme.surfaceContainerHighest.withValues(
              alpha: AppTokens.alphaBorderEmphasis,
            ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        side: BorderSide(
          color: isDark
              ? AppTokens.borderSubtleDark
              : AppTokens.borderSubtleLight,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceXxs,
        vertical: AppTokens.spaceMicro,
      ),
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
    this.isSelected = false,
  });

  final String title;
  final IconData icon;
  final String valueText;
  final bool hasValue;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final borderColor = isSelected
        ? colorScheme.primary.withValues(alpha: AppTokens.alphaBorderEmphasis)
        : (isDark ? AppTokens.borderSubtleDark : AppTokens.borderSubtleLight);

    final bgColor = isSelected
        ? colorScheme.primary.withValues(alpha: AppTokens.alphaTintFaint)
        : (isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: AppTokens.spaceSm,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: AppTokens.menuItemIconSize,
                  color: isSelected || hasValue
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTokens.spaceXs),
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
                      const SizedBox(height: AppTokens.spaceMicro),
                      Text(
                        valueText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: hasValue
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: hasValue
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant.withValues(
                                  alpha: AppTokens.alphaScrim,
                                ),
                          fontSize: AppTokens.textCaptionSize,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasValue && onClear != null)
                  IconButton(
                    tooltip: l10n.clear,
                    icon: const Icon(
                      Icons.close,
                      size: AppTokens.iconSizeSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: onClear,
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    size: AppTokens.iconSizeSmall,
                    color: colorScheme.onSurfaceVariant.withValues(
                      alpha: AppTokens.alphaContentMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 自定义日期 + 时间选择（单层流动画布，避免嵌套弹窗）。
Future<void> pickCustomDateTime(
  BuildContext context,
  TaskFormNotifier notifier, {
  required bool isStart,
}) async {
  await showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => TaskDateRangePickerSheet(initialIsStart: isStart),
  );
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
  final current = ref.read(taskFormProvider).status;
  final picked = await showAppModalBottomSheet<TaskStatus>(
    context: context,
    builder: (sheetContext) => AppModalSheet(
      title: l10n.taskStatus,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          for (final s in TaskStatus.values)
            ListTile(
              leading: Icon(
                statusIcon(s),
                size: AppTokens.iconSizeNormal,
                color: statusColor(s),
              ),
              title: Text(statusLabel(l10n, s)),
              trailing: s == current
                  ? const Icon(
                      Icons.check,
                      size: AppTokens.iconSizeNormal,
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
