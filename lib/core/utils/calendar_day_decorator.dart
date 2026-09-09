import 'lunar/chinese_holidays.dart';
import 'lunar/lunar_calendar.dart';

/// 日历单元格的装饰信息（副文本、右上角标、议程描述等）。
class CalendarDayDecoration {
  const CalendarDayDecoration({
    this.subText,
    this.isSpecialSubText = false,
    this.badgeText,
    this.isRestBadge = false,
    this.isWorkdayBadge = false,
    this.agendaDescription,
  });

  /// 格子日期下方的副文本（如 "初八", "中秋", "白露"）
  final String? subText;

  /// 副文本是否为特殊节日/节气（用于视觉强调色）
  final bool isSpecialSubText;

  /// 格子右上角徽标文字（如 "休", "班"）
  final String? badgeText;

  /// 是否为休假徽标
  final bool isRestBadge;

  /// 是否为调休补班徽标
  final bool isWorkdayBadge;

  /// 议程列表中显示的完整补充描述（如 "农历七月廿七 · 白露" 或 "国庆节"）
  final String? agendaDescription;

  /// 空装饰（纯公历展示模式）
  static const CalendarDayDecoration empty = CalendarDayDecoration();
}

/// 日历单元格信息装饰器管道（解耦 UI 渲染层与具体的历法/节日算法）。
class CalendarDayDecorator {
  const CalendarDayDecorator._();

  /// 根据用户的偏好开关 [showLunar] 与 [showHolidays]，获取指定公历日的装饰信息。
  static CalendarDayDecoration decorate({
    required DateTime date,
    required bool showLunar,
    required bool showHolidays,
  }) {
    if (!showLunar && !showHolidays) {
      return CalendarDayDecoration.empty;
    }

    final info = LunarCalendar.getDayInfo(date);

    String? subText;
    bool isSpecial = false;
    String? agendaDesc;

    if (showLunar) {
      subText = info.displayText;
      isSpecial = info.isSpecialDay;
      agendaDesc = info.agendaDescription;
    } else if (showHolidays) {
      // 仅开启节假日时：若当日为法定节假日，提供对应的节日描述（如“国庆节”）
      if (info.holidayName != null) {
        agendaDesc = info.holidayName;
      }
    }

    String? badgeText;
    bool isRest = false;
    bool isWork = false;

    if (showHolidays) {
      switch (info.workStatus) {
        case DayWorkStatus.rest:
          badgeText = '休';
          isRest = true;
          break;
        case DayWorkStatus.workday:
          badgeText = '班';
          isWork = true;
          break;
        case DayWorkStatus.none:
          break;
      }
    }

    return CalendarDayDecoration(
      subText: subText,
      isSpecialSubText: isSpecial,
      badgeText: badgeText,
      isRestBadge: isRest,
      isWorkdayBadge: isWork,
      agendaDescription: agendaDesc,
    );
  }
}
