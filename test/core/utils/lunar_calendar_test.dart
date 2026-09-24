import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/utils/calendar_day_decorator.dart';
import 'package:ordo/core/utils/lunar/chinese_holidays.dart';
import 'package:ordo/core/utils/lunar/lunar_calendar.dart';
import 'package:ordo/core/utils/lunar/lunar_solar_converter.dart';
import 'package:ordo/core/utils/lunar/solar_terms.dart';

void main() {
  group('LunarSolarConverter 天文公农历互转测试', () {
    test('2026-02-17 春节 -> 2026年正月初一', () {
      final lunar = LunarSolarConverter.solarToLunar(DateTime(2026, 2, 17));
      expect(lunar.year, 2026);
      expect(lunar.month, 1);
      expect(lunar.day, 1);
      expect(lunar.isLeap, isFalse);
    });

    test('2026-09-25 中秋节 -> 2026年八月十五', () {
      final lunar = LunarSolarConverter.solarToLunar(DateTime(2026, 9, 25));
      expect(lunar.year, 2026);
      expect(lunar.month, 8);
      expect(lunar.day, 15);
      expect(lunar.isLeap, isFalse);
    });

    test('2023-03-22 闰二月初一', () {
      final lunar = LunarSolarConverter.solarToLunar(DateTime(2023, 3, 22));
      expect(lunar.year, 2023);
      expect(lunar.month, 2);
      expect(lunar.day, 1);
      expect(lunar.isLeap, isTrue);
    });

    test('支持 1900 至 2200 宽阔跨度', () {
      final lunar1900 = LunarSolarConverter.solarToLunar(DateTime(1900, 1, 31));
      expect(lunar1900.year, 1900);
      expect(lunar1900.month, 1);
      expect(lunar1900.day, 1);

      final lunar2199 = LunarSolarConverter.solarToLunar(
        DateTime(2199, 12, 31),
      );
      expect(lunar2199.year >= 2199, isTrue);
    });
  });

  group('SolarTermsCalculator 二十四节气测试', () {
    test('2026-09-07 命中白露', () {
      final term = SolarTermsCalculator.getSolarTerm(DateTime(2026, 9, 7));
      expect(term, '白露');
    });

    test('2026-03-20 命中春分', () {
      final term = SolarTermsCalculator.getSolarTerm(DateTime(2026, 3, 20));
      expect(term, '春分');
    });

    test('2026-06-21 命中夏至', () {
      final term = SolarTermsCalculator.getSolarTerm(DateTime(2026, 6, 21));
      expect(term, '夏至');
    });

    test('普通日期无节气返回 null', () {
      final term = SolarTermsCalculator.getSolarTerm(DateTime(2026, 9, 10));
      expect(term, isNull);
    });
  });

  group('ChineseHolidays 法定节假日与调休测试', () {
    test('2026-10-01 国庆节为 rest (休)', () {
      expect(
        ChineseHolidays.getWorkStatus(DateTime(2026, 10, 1)),
        DayWorkStatus.rest,
      );
      expect(ChineseHolidays.getHolidayName(DateTime(2026, 10, 1)), '国庆节');
    });

    test('2026-02-15 春节调休补班为 workday (班)', () {
      expect(
        ChineseHolidays.getWorkStatus(DateTime(2026, 2, 15)),
        DayWorkStatus.workday,
      );
    });

    test('2026-09-27 中秋连休周日为 rest (休) 而非 workday (班)', () {
      expect(
        ChineseHolidays.getWorkStatus(DateTime(2026, 9, 27)),
        DayWorkStatus.rest,
      );
    });

    test('支持动态注入自定义/未来年份节假日 (2028+)', () {
      ChineseHolidays.setCustomHolidays(
        {20281001: DayWorkStatus.rest},
        {20281001: '国庆节'},
      );
      expect(
        ChineseHolidays.getWorkStatus(DateTime(2028, 10, 1)),
        DayWorkStatus.rest,
      );
      expect(ChineseHolidays.getHolidayName(DateTime(2028, 10, 1)), '国庆节');
    });
  });

  group('LunarCalendar 统一门面与格式化测试', () {
    test('2026-02-16 除夕', () {
      final info = LunarCalendar.getDayInfo(DateTime(2026, 2, 16));
      expect(info.traditionalFestival, '除夕');
      expect(info.workStatus, DayWorkStatus.rest);
      expect(info.displayText, '除夕');
    });

    test('2026-09-07 白露副文本与议程描述', () {
      final info = LunarCalendar.getDayInfo(DateTime(2026, 9, 7));
      expect(info.solarTerm, '白露');
      expect(info.displayText, '白露');
      expect(info.agendaDescription, contains('白露'));
    });

    test('2026-09-25 中秋节', () {
      final info = LunarCalendar.getDayInfo(DateTime(2026, 9, 25));
      expect(info.traditionalFestival, '中秋节');
      expect(info.displayText, '中秋');
      expect(info.agendaDescription, contains('中秋节'));
    });

    test('2027年春节与除夕精确识别：2-5除夕，2-6春节，2-7初二', () {
      final eve = LunarCalendar.getDayInfo(DateTime(2027, 2, 5));
      expect(eve.traditionalFestival, '除夕');
      expect(eve.displayText, '除夕');
      expect(eve.workStatus, DayWorkStatus.rest);

      final springFestival = LunarCalendar.getDayInfo(DateTime(2027, 2, 6));
      expect(springFestival.traditionalFestival, '春节');
      expect(springFestival.displayText, '春节');
      expect(springFestival.workStatus, DayWorkStatus.rest);

      final dayTwo = LunarCalendar.getDayInfo(DateTime(2027, 2, 7));
      expect(dayTwo.traditionalFestival, isNull);
      expect(dayTwo.displayText, '初二');
      expect(dayTwo.workStatus, DayWorkStatus.rest);
    });

    test('动态注入假日时自动刷新 LunarCalendar 缓存', () {
      final testDate = DateTime(2029, 5, 1);
      // 先查询并触发缓存
      final initialInfo = LunarCalendar.getDayInfo(testDate);
      expect(initialInfo.workStatus, DayWorkStatus.none);

      // 动态注入 2029 劳动节
      ChineseHolidays.setCustomHolidays(
        {20290501: DayWorkStatus.rest},
        {20290501: '劳动节'},
      );

      // 缓存应已自动失效并返回最新注入信息
      final updatedInfo = LunarCalendar.getDayInfo(testDate);
      expect(updatedInfo.workStatus, DayWorkStatus.rest);
      expect(updatedInfo.holidayName, '劳动节');
    });

    test('CalendarDayDecorator 解耦测试：仅开节假日且无农历时展示法定节日描述', () {
      final decoration = CalendarDayDecorator.decorate(
        date: DateTime(2026, 10, 1),
        showLunar: false,
        showHolidays: true,
      );
      expect(decoration.subText, isNull);
      expect(decoration.badgeText, '休');
      expect(decoration.isRestBadge, isTrue);
      expect(decoration.agendaDescription, '国庆节');
    });
  });
}
