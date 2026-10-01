import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// 内联日历视图组件
class InlineCalendarView extends StatelessWidget {
  const InlineCalendarView({
    super.key,
    required this.focusedMonth,
    required this.startDt,
    required this.endDt,
    required this.isEditingStart,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDay,
  });

  final DateTime focusedMonth;
  final DateTime? startDt;
  final DateTime? endDt;
  final bool isEditingStart;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    ).day;
    // 星期一为1，星期日为7；偏移以星期一为0
    final weekdayOffset = (firstDayOfMonth.weekday - 1) % 7;

    final startDay = startDt != null
        ? DateTime(startDt!.year, startDt!.month, startDt!.day)
        : null;
    final endDay = endDt != null
        ? DateTime(endDt!.year, endDt!.month, endDt!.day)
        : null;

    final monthTitle = '${focusedMonth.year}年 ${focusedMonth.month}月';
    final weekdays = const ['一', '二', '三', '四', '五', '六', '日'];

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceSm),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头部月份与左右切换
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  size: AppTokens.iconSizeNormal,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: onPrevMonth,
              ),
              Text(
                monthTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  size: AppTokens.iconSizeNormal,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceXxs),

          // 星期表头
          Row(
            children: [
              for (final w in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: AppTokens.textMicroSize,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: AppTokens.alphaContentMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceXs),

          // 日期网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: weekdayOffset + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: AppTokens.spaceMicro,
              crossAxisSpacing: AppTokens.spaceMicro,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              if (index < weekdayOffset) {
                return const SizedBox();
              }
              final dayNum = index - weekdayOffset + 1;
              final dayDate = DateTime(
                focusedMonth.year,
                focusedMonth.month,
                dayNum,
              );

              final isToday = dayDate == today;
              final isStart = startDay != null && dayDate == startDay;
              final isEnd = endDay != null && dayDate == endDay;
              final isInRange =
                  startDay != null &&
                  endDay != null &&
                  dayDate.isAfter(startDay) &&
                  dayDate.isBefore(endDay);

              final isEndpoint = isStart || isEnd;

              Color? cellBg;
              BoxDecoration? cellDeco;

              if (isEndpoint) {
                cellDeco = BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                );
              } else if (isInRange) {
                cellDeco = BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: AppTokens.alphaTintSoft,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusXs),
                );
              } else if (isToday) {
                cellDeco = BoxDecoration(
                  border: Border.all(
                    color: colorScheme.primary.withValues(
                      alpha: AppTokens.alphaBorderEmphasis,
                    ),
                    width: 1.0,
                  ),
                  shape: BoxShape.circle,
                );
              }

              final textColor = isEndpoint
                  ? Colors.white
                  : (isToday ? colorScheme.primary : colorScheme.onSurface);

              return InkWell(
                onTap: () => onSelectDay(dayDate),
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                child: Container(
                  decoration: cellDeco,
                  color: cellBg,
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: AppTokens.textCaptionSize,
                      fontWeight: isEndpoint || isToday
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: textColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 内联时间微调栏
class InlineTimeBar extends StatelessWidget {
  const InlineTimeBar({
    super.key,
    required this.activeDt,
    required this.isStart,
    required this.onSelectTime,
    required this.onPickCustomTime,
  });

  final DateTime? activeDt;
  final bool isStart;
  final ValueChanged<TimeOfDay?> onSelectTime;
  final VoidCallback onPickCustomTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final hasTime =
        activeDt != null && (activeDt!.hour != 0 || activeDt!.minute != 0);

    final timeLabel = activeDt != null
        ? '${activeDt!.hour.toString().padLeft(2, '0')}:${activeDt!.minute.toString().padLeft(2, '0')}'
        : '09:00';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceSm,
        vertical: AppTokens.spaceXs,
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: AppTokens.iconSizeSmall,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTokens.spaceXxs),
                  Text(
                    isStart ? '开始时间点' : '截止时间点',
                    style: TextStyle(
                      fontSize: AppTokens.textCaptionSize,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onPickCustomTime,
                borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceSm,
                    vertical: AppTokens.spaceXxs,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(
                      alpha: AppTokens.alphaTintSoft,
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: AppTokens.textCaptionSize,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppTokens.spaceXxs),
                      Icon(
                        Icons.edit_rounded,
                        size: AppTokens.iconSizeMicro,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceXs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _timeChip(
                  context,
                  label: '全天',
                  time: null,
                  isSelected: !hasTime,
                  onTap: () => onSelectTime(null),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                _timeChip(
                  context,
                  label: '09:00',
                  time: const TimeOfDay(hour: 9, minute: 0),
                  isSelected:
                      hasTime && activeDt?.hour == 9 && activeDt?.minute == 0,
                  onTap: () =>
                      onSelectTime(const TimeOfDay(hour: 9, minute: 0)),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                _timeChip(
                  context,
                  label: '14:00',
                  time: const TimeOfDay(hour: 14, minute: 0),
                  isSelected:
                      hasTime && activeDt?.hour == 14 && activeDt?.minute == 0,
                  onTap: () =>
                      onSelectTime(const TimeOfDay(hour: 14, minute: 0)),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                _timeChip(
                  context,
                  label: '18:00',
                  time: const TimeOfDay(hour: 18, minute: 0),
                  isSelected:
                      hasTime && activeDt?.hour == 18 && activeDt?.minute == 0,
                  onTap: () =>
                      onSelectTime(const TimeOfDay(hour: 18, minute: 0)),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                _timeChip(
                  context,
                  label: '21:00',
                  time: const TimeOfDay(hour: 21, minute: 0),
                  isSelected:
                      hasTime && activeDt?.hour == 21 && activeDt?.minute == 0,
                  onTap: () =>
                      onSelectTime(const TimeOfDay(hour: 21, minute: 0)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(
    BuildContext context, {
    required String label,
    required TimeOfDay? time,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: AnimatedContainer(
        duration: AppTokens.motionFast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXxs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: AppTokens.alphaTintSoft)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(
                    alpha: AppTokens.alphaBorderEmphasis,
                  )
                : colorScheme.onSurfaceVariant.withValues(
                    alpha: AppTokens.alphaBorderSubtle,
                  ),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTokens.textMicroSize,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
