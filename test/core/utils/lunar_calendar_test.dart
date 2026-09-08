import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/utils/lunar/chinese_holidays.dart';
import 'package:todo/core/utils/lunar/lunar_calendar.dart';
import 'package:todo/core/utils/lunar/lunar_solar_converter.dart';
import 'package:todo/core/utils/lunar/solar_terms.dart';

void main() {
  group('LunarSolarConverter 天文公农历互转测试', () {
    test('2026-02-17 春节 -> 2026年正月初一', () {
      final lunar = LunarSolarConverter.solarToLunar(DateTime(2026, 2, 17));
      expect(lunar.year, 2026);
      expect(lunar.month, 1);
      expect(lunar.day, 1);
      expect(lunar.isLeap, false);
    });

    test('2026-09-25 中秋节 -> 2026年八月十五', () {
      final lunar = LunarSolarConverter.solarToLunar(DateTime(2026, 9, 25));
      expect(lunar.year, 2026);
      expect(lunar.month, 8);
      expect(lunar.day, 15);
      expect(lunar.isLeap, false);
    });

    test('2023-03-22 闰二月初一', () {
      final lunar = LunarSolarConverter.solarToLunar(DateTime(2023, 3, 22));
      expect(lunar.year, 2023);
      expect(lunar.month, 2);
      expect(lunar.day, 1);
      expect(lunar.isLeap, true);
    });

    test('支持 1900 至 2200 宽阔跨度', () {
      final l1900 = LunarSolarConverter.solarToLunar(DateTime(1900, 1, 31));
      expect(l1900.year, 1900);
      expect(l1900.month, 1);
      expect(l1900.day, 1);

      final l2100 = LunarSolarConverter.solarToLunar(DateTime(2100, 2, 9));
      expect(l2100.year, 2100);
      expect(l2100.month, 1);
      expect(l2100.day, 1);

      final l2200 = LunarSolarConverter.solarToLunar(DateTime(2200, 1, 1));
      expect(l2200.year, greaterThanOrEqualTo(2199));
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
  });
}
